"""Copy PrettyTooltip's game files into a World of Warcraft AddOns folder."""

import sys
from argparse import ArgumentParser
from pathlib import Path
from shutil import copy2

# The .toc reader the tests and tools share, beside this script, without a __pycache__ there.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent / "tools"))
import toc  # noqa: E402

# Forever's AddOns folder, and retail's beside it. One folder serves both games:
# each loads its own .toc, by its suffix (Forever counts as Mainline too, so it
# needs _Camelot, which it ranks first).
DEFAULT_ADDONS_DIR = Path(r"D:\Programs\World of Warcraft\_classic_beta_\Interface\AddOns")
RETAIL_ADDONS_DIR = Path(r"D:\Programs\World of Warcraft\_retail_\Interface\AddOns")


def game_files(source: Path) -> list[str]:
    """Each .toc, every Lua file either loads in any language, and every texture."""
    files = list(toc.TOCS) + toc.every_addon_file(source)
    files += sorted(path.relative_to(source).as_posix() for path in (source / "art").glob("*.tga"))
    return files


def main() -> None:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument(
        "--addons-dir",
        type=Path,
        help=f"World of Warcraft Interface/AddOns folder (default: {DEFAULT_ADDONS_DIR})",
    )
    parser.add_argument("--retail", action="store_true", help=f"copy into retail's: {RETAIL_ADDONS_DIR}")
    args = parser.parse_args()
    addons_dir = args.addons_dir or (RETAIL_ADDONS_DIR if args.retail else DEFAULT_ADDONS_DIR)

    source = Path(__file__).resolve().parent
    if not addons_dir.is_dir():
        parser.error(f"AddOns folder does not exist: {addons_dir}")

    destination = addons_dir / "PrettyTooltip"
    destination.mkdir(exist_ok=True)
    for name in game_files(source):
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        copy2(source / name, target)
        print(f"Installed {target}")


if __name__ == "__main__":
    main()
