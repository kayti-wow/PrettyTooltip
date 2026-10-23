"""Writes Data/SpellRanks.lua: every class spell rank's spell power
coefficients and the level it is learned at, by spell ID.

The numbers come from a WoW Forever spell database, which
tools/forever_spells.py builds from the client's own spell tables on
wago.tools, with the scaling Blizzard's development notes state the client
lacks. For each ability rank it lists the effects that carry its scaling,
those of the spells it triggers (a missile, an area tick) included, as direct
or periodic, and as damage, healing, or an absorb. Pet spells and the physical
classes are left out. EXTRA adds the spells the database lacks, by hand.

python tools/make_coefficients.py                       newest Forever build
python tools/make_coefficients.py --build 1.60.1.70425  a specific build
python tools/make_coefficients.py --offline             tables already downloaded
python tools/make_coefficients.py forever_spells.json   a database saved before
"""

import json
import sys
from argparse import ArgumentParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLASSES = ["priest", "druid", "paladin", "shaman", "mage", "warlock"]

# Spells the database lacks: name, class, the coefficients every rank shares
# (direct, over time), whether they are the cast time rule's estimate, and each
# rank's spell ID and learned level. The school database knows them as class
# spells, so without an entry they would show no breakdown at all.
EXTRA = [
    ("Mana Burn", "priest", .857, None, True, [(8129, 24), (8131, 32), (10874, 40), (10875, 48), (10876, 56)]),
]


def shares(spell, spells):
    """A rank's direct and over-time coefficients, each None where it gains
    nothing that way, and whether it scales with healing.

    The tooltip shows one amount of each kind, so a kind takes its largest
    coefficient: Binding Heal lists its heal for each of its two targets, and
    a part may carry no coefficient beside the one that does. A spell that
    both damages and heals, as Holy Shock, names its damage first, and the
    damage decides. One tick, as Bane of Doom's after a minute, reads as an
    amount at once; so does a pulse without a tick count, as a totem's, whose
    tooltip gives the amount of one pulse."""
    parts = [part for part in spell.get("parts", []) if part["kind"] in ("direct", "periodic")]
    counted = [part for part in parts if part.get("inTotal")]

    def coefficient(part):
        return spells[str(part["spell"])]["effects"][part["effectIndex"]].get("spCoef") or 0

    # Hellfire's area tick is listed as an ability of its own; with nothing
    # else to go by, it is the spell's.
    if not any(coefficient(part) > 0 for part in counted):
        counted = parts
    scaling = [part for part in counted if coefficient(part) > 0]
    damage = any(part["category"] == "damage" for part in scaling)
    # The kinds of what it deals, a kind that gains nothing kept at 0, as
    # Fireball's burn: the tooltip shows it gains no spell power.
    categories = {"damage"} if damage else {part["category"] for part in scaling}
    chosen = [part for part in counted if part["category"] in categories]
    direct = periodic = None
    for part in chosen:
        ticks = part.get("ticks")
        if part["kind"] == "periodic" and ticks and ticks > 1:
            periodic = max(periodic or 0, round(coefficient(part) * ticks, 4))
        else:
            direct = max(direct or 0, coefficient(part))
    if not scaling:
        return None, None, False
    return direct, periodic, not damage


def is_pet_spell(spell):
    tree = spell.get("tree") or ""
    return tree.startswith("Pet:") or tree == "Beast Training"


def entry(spell_id, level, direct, periodic, heals=False, estimate=False):
    flags = (", heals = true" if heals else "") + (", estimate = true" if estimate else "")
    return f"    [{spell_id}] = {{ {level}, {number(direct)}, {number(periodic)}{flags} }},"


def number(value):
    if value is None:
        return "nil"
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return text if not text.startswith("0.") else text[1:]


def main():
    parser = ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("database", type=Path, nargs="?", help="a forever_spells.json to read instead of building one")
    parser.add_argument("--build", help="Forever build, e.g. 1.60.1.70425 (default: newest on wago.tools)")
    parser.add_argument("--offline", action="store_true", help="use only tables already downloaded")
    args = parser.parse_args()

    if args.database:
        data = json.loads(args.database.read_text(encoding="utf-8"))
    else:
        # The builder beside this script, without leaving a __pycache__ in tools/.
        sys.dont_write_bytecode = True
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import forever_spells
        data = forever_spells.database(args.build, no_era=True, offline=args.offline)
    meta, spells = data["meta"], data["spells"]
    hotfixes = f", hotfixes through {meta['hotfixesThrough']}" if meta.get("hotfixesThrough") else ""
    lines = [
        "-- Each class spell rank's spell power coefficients and the level it is",
        "-- learned at, by spell ID: { level, direct, over time }, a coefficient nil",
        "-- where the rank has no such effect. heals: it scales with healing, as a",
        "-- heal or absorb; estimate: the cast time rule's value, not the client's.",
        "-- Generated by tools/make_coefficients.py from a WoW Forever spell database",
        f"-- (client {meta['clientBuild']}{hotfixes}) and its list of",
        "-- the spells the database lacks. Run it again when Forever changes spells.",
        "-- Forever only: retail's .toc leaves this file out.",
        "local _, ns = ...",
        "",
        "ns.spellRanks = {",
    ]
    spell_count, rank_count, written = 0, 0, set()
    # Each spell's ranks in order, for what names a spell but not its ID.
    by_name = {}
    for cls in CLASSES:
        for name, rank_ids in sorted(data["abilities"].get(cls, {}).items()):
            ranks = []
            for rank_id in rank_ids:
                spell = spells[str(rank_id)]
                if is_pet_spell(spell):
                    break
                direct, periodic, heals = shares(spell, spells)
                if direct is None and periodic is None:
                    continue
                level = (spell.get("levels") or {}).get("spell") or 0
                ranks.append(entry(rank_id, level, direct, periodic, heals=heals))
                written.add(rank_id)
            if ranks:
                # Every rank, in order, so a rank's number still finds its ID.
                by_name[name] = list(rank_ids)
                spell_count, rank_count = spell_count + 1, rank_count + len(ranks)
                lines.append(f"    -- {name} ({cls.capitalize()})")
                lines += ranks
    lines.append("    -- Not in the database: by hand, in tools/make_coefficients.py.")
    for name, cls, direct, periodic, estimate, extra_ranks in EXTRA:
        lines.append(f"    -- {name} ({cls.capitalize()})")
        for spell_id, level in extra_ranks:
            # The database wins; an extra it now has must be dropped from EXTRA.
            if spell_id in written or str(spell_id) in spells:
                raise SystemExit(f"{name} {spell_id} is in the database now; remove it from EXTRA")
            by_name.setdefault(name, []).append(spell_id)
            lines.append(entry(spell_id, level, direct, periodic, estimate=estimate))
        spell_count, rank_count = spell_count + 1, rank_count + len(extra_ranks)
    lines += ["}", "", "-- By name, each rank's spell ID in rank order: for a spell named without its ID.",
              "ns.spellRankByName = {"]
    for name in sorted(by_name):
        lines.append(f"    [{json.dumps(name)}] = {{ {', '.join(map(str, by_name[name]))} }},")
    lines += ["}", ""]
    (ROOT / "Data" / "SpellRanks.lua").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{spell_count} spells, {rank_count} ranks written to Data/SpellRanks.lua")


if __name__ == "__main__":
    main()
