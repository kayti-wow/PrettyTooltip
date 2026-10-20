"""Copy PrettyTooltip's game files into a World of Warcraft AddOns folder."""

import re
from argparse import ArgumentParser
from pathlib import Path
from shutil import copy2


DEFAULT_ADDONS_DIR = Path(
    r"D:\Programs\World of Warcraft\_classic_beta_\Interface\AddOns"
)
# Forever's .toc, and retail's, which the retail game picks by its suffix; the
# same folder serves both, so a --addons-dir for either game works.
TOCS = ["PrettyTooltip.toc", "PrettyTooltip_Mainline.toc"]


def game_files(source: Path) -> list[str]:
    """Each .toc, the Lua files they load, in order, and every texture. A path with [TextLocale] in it
    names the client's language, so every language's file is copied, as is a file only some clients load
    ([AllowLoadTextLocale ptBR, ptPT] after its name)."""
    files = list(TOCS)
    for toc in TOCS:
        for line in (source / toc).read_text(encoding="utf-8").splitlines():
            line = re.sub(r"\s+\[[^\]]*\]$", "", line.strip())
            if not line or line.startswith("#") or not line.endswith(".lua"):
                continue
            line = line.replace("\\", "/")
            if "[TextLocale]" in line:
                matches = sorted(path.relative_to(source).as_posix()
                                 for path in source.glob(line.replace("[TextLocale]", "*")))
                files += [name for name in matches if name not in files]
            elif line not in files:
                files.append(line)
    files += sorted(path.relative_to(source).as_posix() for path in (source / "art").glob("*.tga"))
    return files


def main() -> None:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument(
        "--addons-dir",
        type=Path,
        default=DEFAULT_ADDONS_DIR,
        help="World of Warcraft Interface/AddOns folder",
    )
    args = parser.parse_args()

    source = Path(__file__).resolve().parent
    if not args.addons_dir.is_dir():
        parser.error(f"AddOns folder does not exist: {args.addons_dir}")

    destination = args.addons_dir / "PrettyTooltip"
    destination.mkdir(exist_ok=True)
    for name in game_files(source):
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        copy2(source / name, target)
        print(f"Installed {target}")


if __name__ == "__main__":
    main()
