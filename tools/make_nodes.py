"""Writes Data/Nodes.lua: what each herb and ore node holds, with the chance
and count of each, and how many times it can be gathered; and
Data/Skinning.lua: what each skinnable creature gives when skinned.

The drops come from CMaNGOS's Classic database (1.12.1), the same loot tables
Wowhead shows: a node's ungrouped rows roll on their own, a group gives one of
its items, those without a chance sharing what is left, and a reference rolls a
shared list. A node can be gathered from a number of times in a range, its taps
(a vein two to four times, a herb once). Quest-only and conditional drops are
left out. The nodes are those Tooltips/Object.lua knows. Creatures sharing the
same skinning loot share one list.

python tools/make_nodes.py            download if missing, then write
python tools/make_nodes.py --refresh  download again
"""

import gzip
import re
import tempfile
import urllib.request
from argparse import ArgumentParser
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(tempfile.gettempdir()) / "prettytooltip-nodes"
DATABASE = "https://raw.githubusercontent.com/cmangos/classic-db/master/Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
TABLES = {"gameobject_template", "gameobject_loot_template", "reference_loot_template", "item_template",
          "creature_template", "skinning_loot_template"}
CHEST = 3


def fetch(refresh):
    path = CACHE / "classic.sql.gz"
    if refresh or not path.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(DATABASE, headers={"User-Agent": "PrettyTooltip tools/make_nodes.py"})
        with urllib.request.urlopen(request, timeout=300) as response:
            path.write_bytes(response.read())
    return path


def values(text):
    """The rows of one INSERT's VALUES list, each a list of field strings."""
    rows, row, field, in_string, escaped, depth = [], [], "", False, False, 0
    for char in text:
        if in_string:
            if escaped:
                field, escaped = field + char, False
            elif char == "\\":
                escaped = True
            elif char == "'":
                in_string = False
            else:
                field += char
        elif char == "'":
            in_string = True
        elif char == "(":
            depth += 1
            row, field = [], ""
        elif char == ")":
            depth -= 1
            row.append(field)
            rows.append(row)
        elif char == "," and depth == 1:
            row.append(field)
            field = ""
        elif depth == 1:
            field += char
    return rows


def read_tables(path):
    """{table: [row as {column: value}]} for the tables in TABLES."""
    columns, rows, current = {}, defaultdict(list), None
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = re.match(r"CREATE TABLE `(\w+)`", line)
            if match:
                current = match.group(1) if match.group(1) in TABLES else None
                if current:
                    columns[current] = []
                continue
            if current and line.strip().startswith("`"):
                columns[current].append(line.strip().split("`")[1])
                continue
            match = re.match(r"INSERT INTO `(\w+)` VALUES (.*);\s*$", line, re.S)
            if match and match.group(1) in TABLES:
                rows[match.group(1)] += values(match.group(2))
    return {table: [dict(zip(columns[table], row)) for row in rows[table]] for table in TABLES}


def chances(rows, references, factor=1.0, out=None, counts=None):
    """{item: chance from 0 to 1} for a loot list, and {item: (min, max)} each
    roll gives."""
    out = out if out is not None else defaultdict(float)
    counts = counts if counts is not None else {}
    groups = defaultdict(list)
    for row in rows:
        # Quest-only drops have a negative chance; conditional ones a condition.
        if float(row["ChanceOrQuestChance"]) < 0 or int(row["condition_id"]):
            continue
        groups[int(row["groupid"])].append(row)
    for group, members in groups.items():
        explicit = sum(float(m["ChanceOrQuestChance"]) for m in members)
        equal = [m for m in members if float(m["ChanceOrQuestChance"]) == 0]
        share = (100 - explicit) / len(equal) if group and equal else 100
        for member in members:
            chance = float(member["ChanceOrQuestChance"]) or share
            ref = int(member["mincountOrRef"])
            if ref < 0:
                chances(references[-ref], references, factor * chance / 100, out, counts)
            else:
                out[int(member["item"])] += factor * chance / 100
                counts[int(member["item"])] = (ref, int(member["maxcount"]))
    return out, counts


def nodes():
    """The herb and ore nodes Tooltips/Object.lua lists."""
    text = (ROOT / "Tooltips" / "Object.lua").read_text(encoding="utf-8")
    block = text[text.index("local NODES = {"):text.index("\n}\n", text.index("local NODES = {"))]
    return re.findall(r'\["([^"]+)"\] = \{ \d+, \d+ \}', block)


def percent(chance):
    value = min(chance, 1) * 100
    text = f"{value:.1f}" if value < 10 else f"{value:.0f}"
    return text[:-2] if text.endswith(".0") else text


def rounded(chance):
    """A chance as a tooltip should give it: to 5% above 10%, to 1% above 1%,
    else to half a percent; a creature's measured 61% and another's 60% are
    the same to a player, and the same list in the data."""
    value = chance * 100
    step = 5 if value >= 10 else 1 if value >= 1 else .5
    return max(step, round(value / step) * step) / 100


def write_skinning(tables, items, references):
    skinning = defaultdict(list)
    for row in tables["skinning_loot_template"]:
        skinning[int(row["entry"])].append(row)
    lists, creatures, names = [], {}, {}
    for row in tables["creature_template"]:
        loot_id = int(row["SkinningLootId"])
        if loot_id <= 0 or loot_id not in skinning:
            continue
        drops, counts = chances(skinning[loot_id], references)
        if not drops:
            continue
        drops = {item: rounded(chance) for item, chance in drops.items()}
        ordered = sorted(drops.items(), key=lambda pair: (-pair[1], items.get(pair[0], "")))
        text = ", ".join(f"{{ {item}, {percent(chance)}, {counts[item][0]}, {counts[item][1]} }}"
                         for item, chance in ordered)
        for item, _ in ordered:
            names[item] = items.get(item, "?")
        if text not in lists:
            lists.append(text)
        creatures[int(row["Entry"])] = lists.index(text) + 1
    lines = [
        "-- What each skinnable creature gives when skinned, by creature ID: an index into",
        "-- the lists of drops, each { item ID, chance in percent, count from, to }, the",
        "-- likeliest first, and each item's name. Generated by tools/make_nodes.py from",
        "-- CMaNGOS's Classic database (1.12.1); quest-only drops are left out, and",
        "-- chances are rounded, so creatures that differ by a point share a list.",
        "-- Forever only: retail's .toc leaves this file out.",
        "local _, ns = ...",
        'ns.provideData("skinningLoot")',
        "",
        "local ITEMS = {",
    ]
    lines += [f'    [{item}] = "{names[item]}",' for item in sorted(names)]
    lines += ["}", "", "local LOOT = {"]
    lines += [f"    {{ {text} }}," for text in lists]
    lines += ["}", "", "local CREATURES = {"]
    ids = sorted(creatures)
    for first in range(0, len(ids), 8):
        lines.append("    " + " ".join(f"[{i}] = {creatures[i]}," for i in ids[first:first + 8]))
    lines += [
        "}", "",
        "-- A creature's drops when skinned, as { item ID, name, chance, count from, to }, or nil.",
        "ns.skinningLoot = function(creatureID)",
        "    local loot = LOOT[CREATURES[creatureID] or 0]",
        "    if not loot then return end",
        "    local drops = {}",
        "    for index, drop in ipairs(loot) do",
        "        drops[index] = { drop[1], ITEMS[drop[1]], drop[2], drop[3], drop[4] }",
        "    end",
        "    return drops",
        "end", "",
    ]
    (ROOT / "Data" / "Skinning.lua").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{len(creatures)} skinnable creatures, {len(lists)} loot lists written to Data/Skinning.lua")


def main():
    parser = ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--refresh", action="store_true", help="download the database again")
    args = parser.parse_args()

    tables = read_tables(fetch(args.refresh))
    items = {int(row["entry"]): row["name"] for row in tables["item_template"]}
    loot, references = defaultdict(list), defaultdict(list)
    for row in tables["gameobject_loot_template"]:
        loot[int(row["entry"])].append(row)
    for row in tables["reference_loot_template"]:
        references[int(row["entry"])].append(row)
    templates, taps = defaultdict(set), defaultdict(list)
    for row in tables["gameobject_template"]:
        if int(row["type"]) == CHEST and int(row["data1"]) in loot:
            templates[row["name"]].add(int(row["data1"]))
            # A chest's data4 and data5 are how often it restocks: a node's taps.
            taps[row["name"]].append((max(1, int(row["data4"])), max(1, int(row["data5"]))))

    lines = [
        "-- What each herb and ore node holds: taps, the times it can be gathered from,",
        "-- and each drop as { item ID, name, chance in percent, count per tap from,",
        "-- to }, the likeliest first. Generated by tools/make_nodes.py from CMaNGOS's",
        "-- Classic database (1.12.1); quest-only drops are left out.",
        "-- Forever only: retail's .toc leaves this file out.",
        "local _, ns = ...",
        'ns.provideData("nodeLoot")',
        "",
        "ns.nodeLoot = {",
    ]
    missing, written = [], 0
    for name in nodes():
        if not templates.get(name):
            missing.append(name)
            continue
        # A node's spawns can have their own tables; the first is the usual one.
        drops, counts = chances(loot[min(templates[name])], references)
        ordered = sorted(drops.items(), key=lambda pair: (-pair[1], items.get(pair[0], "")))
        low, high = max(set(taps[name]), key=taps[name].count)
        parts = ", ".join(f'{{ {item}, "{items.get(item, "?")}", {percent(chance)}, {counts[item][0]}, {counts[item][1]} }}'
                          for item, chance in ordered)
        lines.append(f'    ["{name}"] = {{ taps = {{ {low}, {high} }}, {parts} }},')
        written += 1
    lines += ["}", ""]
    (ROOT / "Data" / "Nodes.lua").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{written} nodes written to Data/Nodes.lua")
    if missing:
        print("not in the database:", ", ".join(missing))
    write_skinning(tables, items, references)


if __name__ == "__main__":
    main()
