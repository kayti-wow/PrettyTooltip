"""Turn tooltips captured with /ptip capture into test fixtures.

Reads PrettyTooltip's saved variables, which the game writes on /reload or
logout, and writes each capture to tests/fixtures/<name>.lua. Lines the item
rewrite changed get the game's own text back, so the tests run the rewrite
themselves. The player's and other players' names are replaced unless
--keep-names is given. The newest capture's enums are saved as
tests/harness/enums.lua, for fixtures captured before captures carried them. A capture retail made is
named retail-<name>, which tells the tests to replay it with retail's files.

python tests/import_captures.py "C:/Program Files (x86)/World of Warcraft/_classic_beta_"
python tests/import_captures.py <path to SavedVariables/PrettyTooltip.lua> --only frostbolt-r3
python tests/import_captures.py <path> --rename hl-r3=holy-light-r5
"""

import re
import sys
from argparse import ArgumentParser
from pathlib import Path

try:
    from lupa import lua51
except ImportError:
    sys.exit("Importing needs lupa, a Lua runtime for Python: pip install -r tests/requirements.txt")

TESTS = Path(__file__).resolve().parent
FIXTURES = TESTS / "fixtures"
HARNESS = TESTS / "harness"

# Run in Lua: the captures come back as Lua tables, and stay them until written.
PREPARE = r"""
return function(capture, keepNames)
    -- The game's own text on lines the item rewrite changed.
    local function restore(entry)
        for _, line in ipairs(entry.data and entry.data.lines or {}) do
            if line.prettyTooltipOriginal then
                line.leftText = line.prettyTooltipOriginal
                line.prettyTooltipOriginal, line.prettyTooltipDisplay, line.prettyTooltipLite = nil, nil, nil
            end
        end
    end
    -- Captured before the rename, the type of tooltip was named kind.
    if capture.kind ~= nil and capture.tooltipType == nil then
        capture.tooltipType, capture.kind = capture.kind, nil
    end
    restore(capture)
    for _, comparison in ipairs(capture.comparisons or {}) do restore(comparison) end
    if keepNames then return capture end

    -- Names to replace: the player's, and those of players the capture shows.
    local names = {}
    local function answer(entry, fn, key)
        local byArgs = entry.calls and entry.calls[fn]
        local results = byArgs and byArgs[key]
        return results and results[1]
    end
    local function collect(entry)
        local playerName = answer(entry, "UnitName", "player")
        if type(playerName) == "string" then names[playerName] = "Player" end
        for _, unit in ipairs({ "mouseover", "mouseovertarget" }) do
            local isPlayer = answer(entry, "UnitIsPlayer", unit)
            local name = answer(entry, "UnitName", unit)
            if isPlayer and type(name) == "string" and not names[name] then
                names[name] = unit == "mouseover" and "Somebody" or "Someone"
            end
            local guild = answer(entry, "GetGuildInfo", unit)
            if isPlayer and type(guild) == "string" then names[guild] = "Some Guild" end
        end
    end
    collect(capture)
    for _, comparison in ipairs(capture.comparisons or {}) do collect(comparison) end

    local function scrub(value, seen)
        if type(value) == "string" then
            for name, stand in pairs(names) do
                value = value:gsub(name:gsub("%p", "%%%0"), stand)
            end
            return value
        end
        if type(value) ~= "table" or seen[value] then return value end
        seen[value] = true
        local renamed = {}
        for key, item in pairs(value) do
            local newKey = type(key) == "string" and scrub(key, seen) or key
            renamed[newKey] = scrub(item, seen)
        end
        return renamed
    end
    return scrub(capture, {})
end
"""


# What tests/run.py names a capture retail made.
RETAIL_PREFIX = "retail-"


def is_retail(capture) -> bool:
    """Whether retail made the capture: by the .toc it says it loaded, or, before captures said so, by its
    client's version, as Forever's is 1.x."""
    client = capture.client
    if client is not None and client.retail is not None:
        return client.retail is True
    version = str(client.version) if client is not None and client.version else ""
    return version.split(".")[0].isdigit() and int(version.split(".")[0]) >= 2


def find_saved_variables(path: Path) -> Path:
    if path.is_file():
        return path
    found = sorted(path.glob("WTF/Account/*/SavedVariables/PrettyTooltip.lua"))
    if not found:
        sys.exit(f"No PrettyTooltip saved variables under {path}; pass the file itself.")
    if len(found) > 1:
        print("Several accounts have captures; using " + str(found[0]) + ". Pass the file to choose.")
    return found[0]


def main() -> None:
    parser = ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("source", type=Path, help="SavedVariables/PrettyTooltip.lua, or the WoW folder holding WTF")
    parser.add_argument("--only", nargs="+", default=[], help="import only these captures")
    parser.add_argument("--rename", nargs="+", default=[], metavar="OLD=NEW", help="save a capture under another name")
    parser.add_argument("--keep-names", action="store_true", help="keep player and guild names as captured")
    args = parser.parse_args()

    renames = dict(item.split("=", 1) for item in args.rename)
    saved = find_saved_variables(args.source)
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    load = lua.eval("function(source, name) return assert(loadstring(source, '@' .. name))() end")
    serialize = load((HARNESS / "serialize.lua").read_text(encoding="utf-8"), "harness/serialize.lua")
    prepare = load(PREPARE, "prepare")
    # The saved variables file only assigns tables; run it with nothing else in reach.
    sandboxed = lua.eval("""function(source)
        local env = {}
        local chunk = assert(loadstring(source, '@SavedVariables'))
        setfenv(chunk, env)
        chunk()
        return env
    end""")
    captures = sandboxed(saved.read_text(encoding="utf-8")).PrettyTooltipCaptures
    if captures is None:
        sys.exit(f"{saved} holds no captures; capture with /ptip capture <name>, then /reload.")

    FIXTURES.mkdir(exist_ok=True)
    newest_enums, newest_time = None, ""
    imported = 0
    for name in sorted(captures.keys()):
        if args.only and name not in args.only:
            continue
        capture = prepare(captures[name], args.keep_names)
        target = renames.get(name, name)
        if is_retail(capture) and not target.startswith(RETAIL_PREFIX):
            target = RETAIL_PREFIX + target
        if not re.fullmatch(r"[\w-]+", target):
            print(f"Skipped {name}: {target!r} is not a usable file name.")
            continue
        header = f"-- Captured with /ptip capture {name}"
        if capture.captured:
            header += f" on {capture.captured}"
        (FIXTURES / f"{target}.lua").write_text(f"{header}.\nreturn {serialize.lua(capture)}\n",
                                                 encoding="utf-8", newline="\n")
        print(f"Wrote tests/fixtures/{target}.lua ({capture.tooltipType or 'lines only'})")
        imported += 1
        if capture.enums is not None and (capture.captured or "") >= newest_time:
            newest_enums, newest_time = capture.enums, capture.captured or ""
    if newest_enums is not None:
        (HARNESS / "enums.lua").write_text(f"return {serialize.lua(newest_enums)}\n", encoding="utf-8", newline="\n")
        print("Wrote tests/harness/enums.lua")
    print(f"{imported} imported. Run python tests/run.py; new fixtures get their first expected outputs.")


if __name__ == "__main__":
    main()
