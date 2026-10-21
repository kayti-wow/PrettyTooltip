"""Writes tests/locales/<locale>.lua: the game's own strings the addon names, in each language.

Every client defines the game's strings (ITEM_MIN_LEVEL, DURABILITY_TEMPLATE, ...) as globals in its own
language; the addon reads tooltips through them. The tests run without the game, so they load these files in
the fixture's language instead. They are for the tests only: the game has its own.

The strings come from WoW Forever's GlobalStrings table on wago.tools, in each language
(https://wago.tools/db2/GlobalStrings/csv?build=<version>&locale=<locale>). A file holds the strings the addon
reads: the game globals .luacheckrc lists, every string a name in a quoted string ending in "_" begins (as
"TOOLTIP_ITEM_STAT_", for a family the addon reads through _G), and the strings tests/unit names. The values are
kept as the table has them: the body of a Lua string, escapes and all, as the game's own GlobalStrings.lua writes
them.

python tools/make_strings.py                       newest Forever build
python tools/make_strings.py --build 1.60.1.70450  a specific build
python tools/make_strings.py --offline             tables already downloaded
"""

import csv
import io
import os
import re
import sys
from argparse import ArgumentParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "tests" / "locales"
LOCALES = ["enUS", "deDE", "frFR", "esES", "esMX", "ptBR", "koKR", "zhCN", "zhTW", "ruRU"]
# A name, not a field (ns.Stats.CATEGORIES is the addon's own).
NAME = re.compile(r"(?<![A-Za-z0-9_.])[A-Z][A-Z0-9_]{2,}(?![A-Za-z0-9_])")


def addon_files():
    """The addon's Lua files, as Forever's .toc and retail's list them, without any load condition after the
    name, and each language's file where a path names the client's language ([TextLocale])."""
    files = []
    for toc in ("PrettyTooltip_Camelot.toc", "PrettyTooltip_Mainline.toc"):
        for line in (ROOT / toc).read_text(encoding="utf-8").splitlines():
            line = line.strip().replace("\\", "/")
            if "[TextLocale]" in line:
                paths = sorted(ROOT.glob(line.replace("[TextLocale]", "*")))
            else:
                line = re.sub(r"\s*\[.*$", "", line)
                paths = [ROOT / line] if line and not line.startswith("#") and line.endswith(".lua") else []
            files += [path for path in paths if path not in files]
    return files


def names_used():
    """The names of game strings the addon and the unit tests read, and the prefixes of families it reads.
    Only the globals .luacheckrc declares count from the addon: its own constants share names with
    game strings (CATEGORY, COMMAND), and a test must not find a global where the game has none."""
    found = set(re.findall(r'"([A-Z][A-Z0-9_]{2,})"', (ROOT / ".luacheckrc").read_text(encoding="utf-8")))
    for path in addon_files():
        found.update(re.findall(r'"([A-Z][A-Z0-9_]+_)"', path.read_text(encoding="utf-8")))
    # The tests' code, not their text ("INVTYPE_WEAPONMAINHAND" there is an item's recorded data)
    # nor their own locals.
    for path in sorted((ROOT / "tests" / "unit").glob("*.lua")):
        code = re.sub(r'--[^\n]*|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', "", path.read_text(encoding="utf-8"))
        local = {name.strip() for names in re.findall(r"\blocal\s+([\w\s,]+?)\s*=", code) for name in names.split(",")}
        found.update(set(NAME.findall(code)) - local)
    return found


def load_strings(fs, build, locale, offline):
    """{name: value} of the build's GlobalStrings in one language, cached beside forever_spells' tables."""
    path = os.path.join(fs.CACHE, build, f"GlobalStrings.{locale}.csv")
    if os.path.exists(path):
        data = open(path, "rb").read()
    else:
        if offline:
            raise FileNotFoundError(f"{path} is not downloaded (run without --offline)")
        print(f"  downloading GlobalStrings {build} {locale}", file=sys.stderr)
        data = fs.get(f"{fs.WAGO}/db2/GlobalStrings/csv?build={build}&locale={locale}")
        if not data.strip() or data.lstrip()[:1] == b"<" or b"BaseTag" not in data.split(b"\n", 1)[0]:
            raise ValueError(f"wago.tools returned no GlobalStrings for {locale} at {build}")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path + ".part", "wb") as f:
            f.write(data)
        os.replace(path + ".part", path)
    rows = csv.DictReader(io.StringIO(data.decode("utf-8-sig")))
    return {row["BaseTag"]: row["TagText_lang"] for row in rows}


def lua_body(value):
    """The value inside double quotes: its escapes kept, a bare quote or line break escaped."""
    out, index = [], 0
    while index < len(value):
        char = value[index]
        if char == "\\" and index + 1 < len(value):
            out.append(value[index:index + 2])
            index += 2
            continue
        out.append({'"': '\\"', "\n": "\\n", "\r": "\\r"}.get(char, char))
        index += 1
    return "".join(out)


def main():
    parser = ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--build", help="Forever build, e.g. 1.60.1.70450 (default: newest on wago.tools)")
    parser.add_argument("--offline", action="store_true", help="use only tables already downloaded")
    args = parser.parse_args()

    # The downloader beside this script, without leaving a __pycache__ in tools/.
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import forever_spells as fs

    build = args.build
    if not build:
        if args.offline:
            cached = sorted((p.name for p in Path(fs.CACHE).iterdir() if p.is_dir()), key=fs.version_key)
            build = next((b for b in reversed(cached) if b.startswith("1.6")), None)
        else:
            build, _ = fs.newest_builds()
    if not build:
        sys.exit("No Forever build found. Pass --build.")

    used = names_used()
    prefixes = tuple(name for name in used if name.endswith("_"))
    OUT.mkdir(parents=True, exist_ok=True)
    for locale in LOCALES:
        strings = load_strings(fs, build, locale, args.offline)
        chosen = sorted(name for name in strings if name in used or name.startswith(prefixes))
        lines = [
            f"-- The game's strings the addon names, in {locale}. Generated by tools/make_strings.py",
            f"-- from WoW Forever's GlobalStrings (build {build}); the tests load them in the fixture's language.",
            "return {",
        ]
        lines += [f'    ["{name}"] = "{lua_body(strings[name])}",' for name in chosen]
        lines += ["}", ""]
        (OUT / f"{locale}.lua").write_text("\n".join(lines), encoding="utf-8", newline="\n")
        print(f"{len(chosen)} strings written to tests/locales/{locale}.lua")


if __name__ == "__main__":
    main()
