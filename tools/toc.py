"""The addon's .toc files, as the tests, the package check, deploy.py, and the tools read them.

Forever loads PrettyTooltip_Camelot.toc and retail PrettyTooltip_Mainline.toc; each game picks its own by the
suffix. A load line is a path, with backslashes, and may end in a condition: [AllowLoadTextLocale deDE] loads
it only on clients in those languages. [TextLocale] in a path names the client's language. The lines between
#@debug@ and #@end-debug@ are for development builds; the packager leaves them out of a release.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FOREVER = "PrettyTooltip_Camelot.toc"
RETAIL = "PrettyTooltip_Mainline.toc"
TOCS = (FOREVER, RETAIL)

CONDITION = re.compile(r"^(.+?)\s+\[(\w+)\s*([^\]]*)\]$")


def read(name: str, root: Path = ROOT) -> str:
    return (root / name).read_text(encoding="utf-8-sig")


def entries(text: str, *, debug: bool = True) -> list[str]:
    """A .toc's load lines, in order, each with its condition and its path with forward slashes.
    debug=False leaves out the development lines, as a release does."""
    found, in_debug = [], False
    for line in text.splitlines():
        line = line.strip()
        if line == "#@debug@":
            in_debug = True
        elif line == "#@end-debug@":
            in_debug = False
        elif line and not line.startswith("#") and (debug or not in_debug):
            found.append(line.replace("\\", "/"))
    return found


def split(entry: str) -> tuple[str, set[str] | None]:
    """A load line's path, and the languages it loads in (None: every one)."""
    match = CONDITION.match(entry)
    if not match:
        return entry, None
    if match[2] != "AllowLoadTextLocale":
        raise ValueError(f"unsupported .toc condition: {entry}")
    return match[1], set(re.split(r"[,\s]+", match[3].strip()))


def load_order(lines: list[str], locale: str, root: Path | None = None) -> list[str]:
    """The Lua files a client in that language loads, in order. With root given, a [TextLocale] file that is
    missing is skipped, as the client skips it."""
    files = []
    for entry in lines:
        path, locales = split(entry)
        if locales is not None and locale not in locales:
            continue
        if "[TextLocale]" in path:
            path = path.replace("[TextLocale]", locale)
            if root is not None and not (root / path).exists():
                continue
        if "[" in path or not path.endswith(".lua"):
            raise ValueError(f"unsupported .toc entry: {entry}")
        files.append(path)
    return files


def every_file(lines: list[str], root: Path = ROOT) -> list[str]:
    """Every Lua file the lines load in any language, in order, each once."""
    files = []
    for entry in lines:
        path, _ = split(entry)
        if "[TextLocale]" in path:
            found = sorted(match.relative_to(root).as_posix() for match in root.glob(path.replace("[TextLocale]", "*")))
        else:
            found = [path] if path.endswith(".lua") else []
        files += [name for name in found if name not in files]
    return files


def every_addon_file(root: Path = ROOT) -> list[str]:
    """Every Lua file either .toc loads, in any language, Forever's first, each once."""
    files = []
    for name in TOCS:
        files += [path for path in every_file(entries(read(name, root)), root) if path not in files]
    return files
