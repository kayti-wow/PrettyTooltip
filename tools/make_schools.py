"""Writes Data/Schools.lua: each class spell's magic school, by its English name and every rank's spell ID.

The spells and their schools come from WoW Forever's own client tables, as
tools/forever_spells.py reads them from wago.tools: every spell a class learns
(SkillLineAbility, talents included) and its SchoolMask. Every rank of a spell
shares its name, so the table needs one entry per spell, the school most of
its ranks have, with each rank's ID: a spell's tooltip names its rank by ID,
and the addon asks a client in another language for the first rank's name. Physical spells are left out: they have no
school tint. So are pet spells, and the "Effect" and "(Passive)" helpers
spells hand their work to.

With --retail it writes Data/SchoolsRetail.lua from retail's tables instead:
every spell on a class's skill line or in its talent trees, hero talents
included. Retail has no ranks, so a name lists every spell ID that bears it.
Retail mixes schools more than Forever: RETAIL_MIXES picks one tint for a mix
of two the palette has no blend for, and a mix of three or more (Chaos,
Cosmic, Elemental) is left out, for the spell's wording to decide.

python tools/make_schools.py                       newest Forever build
python tools/make_schools.py --build 1.60.1.70450  a specific build
python tools/make_schools.py --offline             tables already downloaded
python tools/make_schools.py --retail              newest retail build
python tools/make_schools.py --retail --build 12.1.5.70448
"""

import json
import sys
from argparse import ArgumentParser
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# SchoolMask bits, as the game numbers them, in the order a tie between ranks
# is settled.
BITS = [(2, "Holy"), (4, "Fire"), (8, "Nature"), (16, "Frost"), (32, "Shadow"), (64, "Arcane")]
# Masks naming more than one school that the palette has a tint for.
BLENDS = {2 | 4: "Holyfire", 4 | 16: "Frostfire"}

# Schools the data cannot give: a name two classes give to spells of different
# schools, as the table holds one, and a spell the data leaves without one.
BY_HAND = {
    # The priest's is Holy, the shaman's Nature.
    "Cure Disease": "Nature",
    # A curse the client gives no school; tinted as the warlock's other banes.
    "Bane of Havoc": "Shadow",
    # A paladin spell against the undead the client, as Classic's, files as Nature.
    "Turn Undead": "Holy",
}


# Retail's mixes of two schools, by the tint that suits the spells that use them.
RETAIL_MIXES = {
    8 | 64: "Arcane",  # Astral: a balance druid's Starsurge and Starfall.
    4 | 32: "Shadow",  # Shadowflame: a warlock's Demonbolt and Shadowburn.
    8 | 32: "Shadow",  # Plague.
    16 | 64: "Arcane",  # Spellfrost: an evoker's Azure Sweep.
}
RETAIL_CLASSES = {"Death Knight", "Demon Hunter", "Druid", "Evoker", "Hunter", "Mage", "Monk", "Paladin", "Priest",
                  "Rogue", "Shaman", "Warlock", "Warrior"}
RETAIL_TABLES = ["SpellName", "SpellMisc", "SkillLine", "SkillLineAbility", "ChrSpecialization", "TraitTreeLoadout",
                 "TraitNode", "TraitNodeXTraitNodeEntry", "TraitNodeEntry", "TraitDefinition"]


def retail_school_of(mask):
    mask &= ~1
    if mask in BLENDS:
        return BLENDS[mask]
    if bin(mask).count("1") > 2:
        return None
    return RETAIL_MIXES.get(mask) or school_of(mask)


def school_of(mask):
    if mask in BLENDS:
        return BLENDS[mask]
    for bit, school in BITS:
        if mask & bit:
            return school
    return None


def helper(name):
    return name.endswith(" Effect") or "(Passive" in name


def retail_spells(fs, build, offline):
    """Each retail class spell's name and school: those on a class's skill line,
    and those its talent trees teach or change."""
    t = fs.load_tables(RETAIL_TABLES, build, fs.CACHE, offline)
    lines = {r["ID"] for r in t["SkillLine"] if r["CategoryID"] == "7" and r["DisplayName_lang"] in RETAIL_CLASSES}
    ids = {r["Spell"] for r in t["SkillLineAbility"] if r["SkillLine"] in lines}
    classes = {r["ID"] for r in t["ChrSpecialization"] if r["ClassID"] not in ("", "0")}
    trees = {r["TraitTreeID"] for r in t["TraitTreeLoadout"] if r["ChrSpecializationID"] in classes}
    nodes = {r["ID"] for r in t["TraitNode"] if r["TraitTreeID"] in trees}
    entries = {r["TraitNodeEntryID"] for r in t["TraitNodeXTraitNodeEntry"] if r["TraitNodeID"] in nodes}
    definitions = {r["TraitDefinitionID"] for r in t["TraitNodeEntry"] if r["ID"] in entries}
    for r in t["TraitDefinition"]:
        if r["ID"] in definitions:
            ids |= {r[key] for key in ("SpellID", "OverridesSpellID", "VisibleSpellID") if r[key] not in ("", "0")}
    names = {r["ID"]: r["Name_lang"] for r in t["SpellName"]}
    masks = {r["SpellID"]: int(r["SchoolMask"] or 0) for r in t["SpellMisc"] if r["DifficultyID"] == "0"}
    return [(int(spell_id), names[spell_id], retail_school_of(masks.get(spell_id, 0)))
            for spell_id in ids if names.get(spell_id)]


def forever_spells(fs, build, offline):
    tables = fs.load_tables(fs.FOREVER_TABLES, build, fs.CACHE, offline)
    client = fs.Client(build, tables)
    # The class mounts are on the mounts skill line, with every other mount;
    # those are physical, and left out with the rest.
    members, _ = fs.class_spells(tables, client, fs.SKIP_LINES - {"Mounts"})
    return [(spell_id, client.names.get(spell_id), school_of(client.info(spell_id)["school"]))
            for (_, spell_id), line in members.items() if not line.startswith("Pet:")]


def main():
    parser = ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--build", help="build, e.g. 1.60.1.70450 (default: newest on wago.tools)")
    parser.add_argument("--retail", action="store_true", help="write retail's table, Data/SchoolsRetail.lua")
    parser.add_argument("--offline", action="store_true", help="use only tables already downloaded")
    args = parser.parse_args()

    # The builder beside this script, without leaving a __pycache__ in tools/.
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import forever_spells as fs

    if args.retail:
        build = args.build
        if not build and args.offline:
            cached = sorted((p.name for p in Path(fs.CACHE).iterdir() if p.is_dir()), key=fs.version_key)
            build = next((b for b in reversed(cached) if int(b.split(".")[0]) >= 10), None)
        elif not build:
            products = json.loads(fs.get(f"{fs.WAGO}/api/builds"))
            build = max((b["version"] for b in products.get("wow", [])), key=fs.version_key, default=None)
        if not build:
            sys.exit("No retail build found. Pass --build.")
        write(retail_spells(fs, build, args.offline), {}, "SchoolsRetail.lua", exact=True, header=[
            "-- Each retail class spell's magic school, by its English name and the spell",
            "-- IDs that bear it; physical spells, and those of three schools or more, are",
            "-- left out. Generated by tools/make_schools.py --retail from retail's client",
            f"-- spell tables (build {build}). Run it again when retail changes spells.",
        ])
        return

    build = args.build
    if not build:
        if args.offline:
            cached = sorted((p.name for p in Path(fs.CACHE).iterdir() if p.is_dir()), key=fs.version_key)
            build = next((b for b in reversed(cached) if b.startswith("1.6")), None)
        else:
            build, _ = fs.newest_builds()
    if not build:
        sys.exit("No Forever build found. Pass --build.")
    write(forever_spells(fs, build, args.offline), BY_HAND, "Schools.lua", header=[
        "-- Each class spell's magic school, which every rank shares, by its English",
        "-- name and its ranks' spell IDs, the first rank first; physical spells are",
        "-- left out. Generated by tools/make_schools.py from WoW Forever's client spell",
        f"-- tables (build {build}). Run it again when Forever adds spells.",
    ])


def write(spells, by_hand, file_name, header, exact=False):
    """Writes the table: each name's school, the one most of its spells have.
    exact: a name lists only the spell IDs of that school, as retail's spells
    of one name are separate spells, not ranks."""
    found, ranks = defaultdict(Counter), defaultdict(set)
    for spell_id, name, school in spells:
        if not name or helper(name):
            continue
        found[name][school] += 1
        ranks[name].add((spell_id, school))
    order = {school: index for index, (_, school) in enumerate(BITS)}
    schools, mixed = defaultdict(set), []
    for name, counts in found.items():
        # Most ranks win; a tie goes to a school over none, then in BITS order.
        school = max(counts, key=lambda s: (counts[s], s is not None, -order.get(s, len(order))))
        school = by_hand.get(name, school)
        if len(counts) > 1:
            mixed.append(f"{name} {dict(counts)}, kept {school}" + (" (by hand)" if name in by_hand else ""))
        if school:
            schools[school].add(name)
            ranks[name] = {spell_id for spell_id, own in ranks[name] if own == school or not exact}

    lines = header + [
        "local _, ns = ...",
        "",
        "local SCHOOLS = {",
    ]
    for school in sorted(schools):
        lines.append(f"    {school} = {{")
        for name in sorted(schools[school]):
            ids = ", ".join(str(spell_id) for spell_id in sorted(ranks[name]))
            lines.append(f"        [{json.dumps(name)}] = {{ {ids} }},")
        lines.append("    },")
    lines += [
        "}",
        "",
        "local byID = {}",
        "for school, spells in pairs(SCHOOLS) do",
        "    for _, ranks in pairs(spells) do",
        "        for _, spellID in ipairs(ranks) do byID[spellID] = school end",
        "    end",
        "end",
        "",
        "-- A class spell's school, by its spell ID where the tooltip has one, else by",
        "-- its name on this client, as a macro names it; the names are asked for at",
        "-- the first use.",
        "local byName",
        "function ns.spellSchool(name, spellID)",
        "    if spellID and byID[spellID] then return byID[spellID] end",
        "    if not byName then",
        "        byName = {}",
        "        for school, spells in pairs(SCHOOLS) do",
        "            for english, ranks in pairs(spells) do",
        "                byName[ns.Game.localSpellName(ranks[1], english)] = school",
        "            end",
        "        end",
        "    end",
        "    return name and byName[name]",
        "end",
        "",
    ]
    (ROOT / "Data" / file_name).write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{sum(len(names) for names in schools.values())} spells written to Data/{file_name}")
    if mixed:
        print(f"{len(mixed)} spells with ranks in different schools:")
        for line in sorted(mixed):
            print("  " + line)


if __name__ == "__main__":
    main()
