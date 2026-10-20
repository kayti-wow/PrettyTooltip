"""Run PrettyTooltip's tests outside the game.

Every fixture in tests/fixtures (a tooltip captured with /ptip capture) is run
through the addon as the game would, in Lua 5.1, and the model its reader
makes and what its renderer draws are compared against the expected outputs in
tests/outputs. Every file in tests/unit holds checks against parts of the addon
loaded on their own.

python tests/run.py              run everything
python tests/run.py -k frost     only tests whose name holds "frost"
python tests/run.py --update     accept the current output as the expected
python tests/run.py --notes      also list what each fixture lacked an answer for
python tests/run.py --coverage   also report which lines and functions the tests ran
python tests/run.py --profile    also count the frame calls each fixture's read and render make
"""

import difflib
import locale
import os
import re
import shutil
import subprocess
import sys
from argparse import ArgumentParser
from pathlib import Path

try:
    from lupa import lua51
except ImportError:
    sys.exit("The tests need lupa, a Lua runtime for Python: pip install -r tests/requirements.txt")

# The game's Lua knows only ASCII letters (upper, lower, %a, %u); Python sets the
# system's own character locale, under which Lua would change UTF-8 bytes too.
locale.setlocale(locale.LC_CTYPE, "C")
# Failures can show text in any language, whatever the console's encoding.
sys.stdout.reconfigure(errors="backslashreplace")

TESTS = Path(__file__).resolve().parent
ROOT = TESTS.parent
HARNESS = TESTS / "harness"
FIXTURES = TESTS / "fixtures"
OUTPUTS = TESTS / "outputs"
UNIT = TESTS / "unit"
LOCALES = TESTS / "locales"
# The game's strings by language (tools/make_strings.py), as Lua source the
# harness loads in each fixture's language.
GAME_STRINGS = {path.stem: path.read_text(encoding="utf-8") for path in sorted(LOCALES.glob("*.lua"))}

# Lines run by any test, by file, while --coverage is given.
COVERAGE: dict[str, set[int]] | None = None
STRICT = False


# The .toc each game loads: Forever's, and retail's, which the game picks by its suffix.
FOREVER_TOC = "PrettyTooltip.toc"
RETAIL_TOC = "PrettyTooltip_Mainline.toc"


def addon_files(locale: str = "enUS", toc: str = FOREVER_TOC) -> list[str]:
    """The addon's Lua files, in the order the .toc loads them on a client in that language. [TextLocale]
    in a path names the client's language, and a file it names that is missing is skipped, as the client
    skips it. A file with [AllowLoadTextLocale ptBR, ptPT] after its name loads only in those languages."""
    files = []
    for line in (ROOT / toc).read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("#"):
            continue
        condition = re.search(r"\s+\[(\w+)\s*([^\]]*)\]$", line)
        if condition:
            line = line[:condition.start()]
            if condition.group(1) != "AllowLoadTextLocale":
                sys.exit(f"The tests cannot load .toc lines with this condition yet: {condition.group(0).strip()}")
            if locale not in re.split(r"[,\s]+", condition.group(2).strip()):
                continue
        if "[TextLocale]" in line:
            line = line.replace("[TextLocale]", locale)
            if not (ROOT / line.replace("\\", "/")).exists():
                continue
        if "[" in line:
            sys.exit(f"The tests cannot read this .toc line: {line}")
        if line.endswith(".lua"):
            files.append(line.replace("\\", "/"))
    return files


def every_source() -> list[str]:
    """Every Lua file a test may load: each .toc's, and each language's own file."""
    files = addon_files()
    files += [name for name in addon_files(toc=RETAIL_TOC) if name not in files]
    files += [path.relative_to(ROOT).as_posix() for path in sorted((ROOT / "Locale").glob("*.lua"))
              if path.relative_to(ROOT).as_posix() not in files]
    return files


def new_runtime():
    """A fresh Lua 5.1 with the harness loaded, so no test sees another's state."""
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    load = lua.eval("function(source, name) return assert(loadstring(source, '@' .. name))() end")
    harness = {name: load((HARNESS / f"{name}.lua").read_text(encoding="utf-8"), f"harness/{name}.lua")
               for name in ("serialize", "wow", "main")}
    # Every world gets the game's strings, without the entry points passing them on.
    with_strings = lua.eval("function(makeWorld, strings) return function(fixture, enums, report)"
                            " return makeWorld(fixture, enums, report, strings) end end")
    harness["wow"] = with_strings(harness["wow"], lua_table(lua, GAME_STRINGS))
    if COVERAGE is not None:
        harness["hits"] = lua.table()
        harness["main"].track(harness["hits"])
    return lua, load, harness


def collect_coverage(harness) -> None:
    if COVERAGE is None:
        return
    for source, lines in harness["hits"].items():
        COVERAGE.setdefault(source.lstrip("@"), set()).update(int(line) for line in lines.keys())


def lua_table(lua, mapping):
    table = lua.table()
    for key, value in mapping.items():
        table[key] = value
    return table


def sources_table(lua, files):
    return lua_table(lua, {name: (ROOT / name).read_text(encoding="utf-8") for name in files})


def default_enums(load):
    path = HARNESS / "enums.lua"
    if not path.exists():
        return None
    return load(path.read_text(encoding="utf-8"), "harness/enums.lua")


def show_diff(expected: str, got: str, name: str) -> None:
    diff = difflib.unified_diff(expected.splitlines(), got.splitlines(), f"outputs/{name}.txt", "now",
                                lineterm="", n=2)
    for line in diff:
        print("    " + line)


def compare(name: str, text: str, notes, update: bool, show_notes: bool) -> bool:
    """Checks text against outputs/<name>.txt, or writes it there when it is
    new or --update is given."""
    expected_path = OUTPUTS / f"{name}.txt"
    if STRICT and not expected_path.exists():
        print(f"FAIL {name}: missing expected output; review and generate it locally first")
        return False
    if update or not expected_path.exists():
        expected_path.parent.mkdir(parents=True, exist_ok=True)
        expected_path.write_text(text, encoding="utf-8", newline="\n")
        print(f"{'updated' if update else 'new'} {name}")
        ok = True
    else:
        expected = expected_path.read_text(encoding="utf-8")
        ok = expected == text
        print(f"{'ok' if ok else 'FAIL'} {name}")
        if not ok:
            show_diff(expected, text, name)
    if show_notes or not ok:
        for note in notes:
            print(f"    note {note}")
    return ok


def variant_names(load) -> dict[str, list[str]]:
    """The variants in tests/variants.lua, by type of tooltip."""
    path = TESTS / "variants.lua"
    if not path.exists():
        return {}
    variants = load(path.read_text(encoding="utf-8"), "variants.lua")
    return {tooltip_type: sorted(byName.keys()) for tooltip_type, byName in variants.items()}


def run_fixture(path: Path, files, args, retail=False) -> list[bool]:
    """The fixture with the default settings, then with each variant its type
    of tooltip has. Each run gets a fresh runtime, as a run changes the fixture's data.
    retail: read and drawn with the retail .toc's files, which must not fail;
    the fixtures are Forever's tooltips, so there is no expected output."""
    results = []
    _, load, _ = new_runtime()
    fixture = load(path.read_text(encoding="utf-8"), f"fixtures/{path.name}")
    # Fixtures imported before the rename name it kind.
    tooltip_type = fixture.tooltipType or fixture.kind
    variants = [None] if retail else [None] + variant_names(load).get(tooltip_type, [])
    for variant in variants:
        name = path.stem if variant is None else f"{path.stem}.{variant}"
        if retail:
            name = f"retail/{name}"
        lua, load, harness = new_runtime()
        fixture = load(path.read_text(encoding="utf-8"), f"fixtures/{path.name}")
        enums = fixture.enums or default_enums(load)
        # The files the fixture's client loads, by its language.
        client = fixture.client
        files = addon_files(client.locale if client and client.locale else "enUS",
                            RETAIL_TOC if retail else FOREVER_TOC)
        if enums is None:
            print(f"FAIL {name}: no enums; capture it again with the current /ptip capture, then import it")
            results.append(False)
            continue
        options = {"profile": args.profile and variant is None}
        if variant is not None:
            chosen = load((TESTS / "variants.lua").read_text(encoding="utf-8"), "variants.lua")[tooltip_type][variant]
            options["settings"], options["native"] = chosen.settings, chosen.native
        try:
            text, notes, profile_text = harness["main"].fixture(
                fixture, enums, lua_table(lua, dict(enumerate(files, 1))), sources_table(lua, files),
                harness["serialize"], harness["wow"], lua_table(lua, options))
        except Exception as error:  # A Lua error, with its traceback.
            print(f"FAIL {name}: {error}")
            results.append(False)
            continue
        collect_coverage(harness)
        if retail:
            print(f"ok {name}")
            results.append(True)
            continue
        results.append(compare(name, text, list(notes.values()), args.update, args.notes))
        if options["profile"] and profile_text:
            print("    " + profile_text.replace("\n", "\n    "))
    return results


def run_samples(files, args, retail=False) -> list[bool]:
    """Every sample the style editor shows, against outputs/samples/; with
    retail, drawn with the retail .toc's files, which must not fail."""
    lua, load, harness = new_runtime()
    enums = default_enums(load)
    if enums is None:
        print("FAIL samples: no tests/harness/enums.lua; import a capture first")
        return [False]
    try:
        samples, notes = harness["main"].samples(enums, lua_table(lua, dict(enumerate(files, 1))),
                                                  sources_table(lua, files), harness["serialize"], harness["wow"])
    except Exception as error:
        print(f"FAIL {'retail/' if retail else ''}samples: {error}")
        return [False]
    collect_coverage(harness)
    if retail:
        print(f"ok retail/samples ({len(samples)} drawn)")
        return [True]
    results = []
    for sample in samples.values():
        name = f"samples/{sample.name}"
        if args.pattern in name:
            results.append(compare(name, sample.text, [], args.update, False))
    if args.notes:
        for note in notes.values():
            print(f"    note {note}")
    return results


def run_lint() -> list[bool]:
    """luacheck over the addon, by .luacheckrc, when it can be found: on the
    PATH, or where the LUACHECK environment variable points."""
    luacheck = os.environ.get("LUACHECK") or shutil.which("luacheck")
    if not luacheck:
        if STRICT:
            print("FAIL lint: luacheck not found (required in strict mode)")
            return [False]
        print("skipped lint: luacheck not found (set LUACHECK to its path, or put it on the PATH)")
        return []
    finished = subprocess.run([luacheck, ".", "--no-color", "--codes", "--quiet"], cwd=ROOT,
                              capture_output=True, text=True)
    ok = finished.returncode == 0
    print(f"{'ok' if ok else 'FAIL'} lint")
    if not ok:
        print("    " + (finished.stdout + finished.stderr).strip().replace("\n", "\n    "))
    return [ok]


def run_unit(path: Path, tocs: dict[str, list[str]], show_notes: bool) -> bool:
    """tocs: each .toc's files in load order, by the client it serves, for test.tocs."""
    lua, load, harness = new_runtime()
    lists = lua_table(lua, {client: lua_table(lua, dict(enumerate(files, 1))) for client, files in tocs.items()})
    try:
        results, notes = harness["main"].unit(path.read_text(encoding="utf-8"), f"unit/{path.name}",
                                                sources_table(lua, every_source()), harness["serialize"],
                                                harness["wow"], lists, default_enums(load))
    except Exception as error:
        print(f"FAIL unit/{path.stem}: {error}")
        return False
    collect_coverage(harness)
    all_ok = True
    for result in results.values():
        if result.ok:
            continue
        all_ok = False
        print(f"FAIL unit/{path.stem}: {result.name}")
        print("    expected: " + result.expected.replace("\n", "\n              "))
        print("    got:      " + result.got.replace("\n", "\n              "))
    if all_ok:
        print(f"ok unit/{path.stem} ({len(results)} checks)")
    if show_notes:
        for note in notes.values():
            print(f"    note {note}")
    return all_ok


# Lines that hold no statement of their own: blank, comments, and the closing
# words and brackets of blocks and tables.
NOT_CODE = re.compile(r"^\s*(--.*)?$|^\s*(end|else|do|then|repeat)?[\s,;)}\]]*(--.*)?$")
DEFINITION = re.compile(r"^(?:local\s+)?function\s+([\w.:]+)|^local\s+(\w+)\s*=\s*function\b")


def report_coverage(files) -> None:
    """Each file's share of code lines the tests ran, and its top-level
    functions no test entered. Code lines are counted from the text, so the
    share is close, not exact."""
    print("\nCoverage (code lines run by any test):")
    total_run = total_code = 0
    untouched = []
    for name in files:
        lines = (ROOT / name).read_text(encoding="utf-8").splitlines()
        hit = COVERAGE.get(name, set())
        code = [number for number, text in enumerate(lines, 1) if not NOT_CODE.match(text)]
        run = [number for number in code if number in hit]
        total_run += len(run)
        total_code += len(code)
        print(f"  {name:32} {100 * len(run) / max(1, len(code)):5.1f}%  ({len(run)} of {len(code)})")
        # A top-level function runs to the next one; it was entered when any
        # line after its first ran.
        starts = [(number, match.group(1) or match.group(2)) for number, text in enumerate(lines, 1)
                  if (match := DEFINITION.match(text))]
        for index, (start, function) in enumerate(starts):
            stop = starts[index + 1][0] if index + 1 < len(starts) else len(lines) + 1
            body = [number for number in code if start < number < stop]
            if body and not any(number in hit for number in body):
                untouched.append(f"{name}:{start} {function} ({len(body)} lines)")
    print(f"  {'all':32} {100 * total_run / max(1, total_code):5.1f}%  ({total_run} of {total_code})")
    if untouched:
        print("\nTop-level functions no test entered:")
        for line in untouched:
            print("  " + line)


def main() -> None:
    parser = ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("-k", dest="pattern", default="", help="only tests whose name holds this")
    parser.add_argument("--update", action="store_true", help="accept the current output as the expected")
    parser.add_argument("--notes", action="store_true", help="list what each fixture lacked an answer for")
    parser.add_argument("--coverage", action="store_true", help="report which lines and functions the tests ran")
    parser.add_argument("--profile", action="store_true", help="count the frame calls each read and render make")
    parser.add_argument("--strict", action="store_true", help="require lint and existing expected outputs; never create baselines")
    args = parser.parse_args()
    if args.strict and args.update:
        parser.error("--strict cannot be combined with --update")
    global COVERAGE, STRICT
    STRICT = args.strict
    if args.coverage:
        COVERAGE = {}

    files, retail_files = addon_files(), addon_files(toc=RETAIL_TOC)
    tocs = {"forever": files, "retail": retail_files}
    results = run_lint() if args.strict or not args.pattern or args.pattern in "lint" else []
    for path in sorted(UNIT.glob("*.lua")):
        if args.pattern in path.stem:
            results.append(run_unit(path, tocs, args.notes))
    for path in sorted(FIXTURES.glob("*.lua")):
        if args.pattern in path.stem:
            results += run_fixture(path, files, args)
        if args.pattern in f"retail/{path.stem}" and not args.update:
            results += run_fixture(path, retail_files, args, retail=True)
    if not args.pattern or "samples" in args.pattern or any(
            args.pattern in name for name in ("item", "spell", "object", "unit", "aura", "quest")):
        results += run_samples(files, args)
    if (not args.pattern or "retail" in args.pattern) and not args.update:
        results += run_samples(retail_files, args, retail=True)
    passed = results.count(True)
    print(f"\n{passed} passed, {len(results) - passed} failed")
    if COVERAGE is not None:
        report_coverage(files)
    sys.exit(1 if passed < len(results) else 0)


if __name__ == "__main__":
    main()
