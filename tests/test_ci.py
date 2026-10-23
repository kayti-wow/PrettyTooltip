"""Checks that CI rejects broken packages and cannot silently bless baselines."""

import contextlib
import io
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from zipfile import ZIP_STORED, ZipFile

import check_package
import run as regression


class PackageChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = check_package.ROOT
        cls.files = {"LICENSE": (root / "LICENSE").read_bytes()}
        toc = check_package.toc
        for toc_name in check_package.TOCS:
            # As a release has it: without the debug block.
            text = re.sub(r"#@debug@.*?#@end-debug@", "", toc.read(toc_name, root), flags=re.DOTALL)
            cls.files[toc_name] = text.encode("utf-8")
            for entry in toc.entries(text):
                name = toc.split(entry)[0]
                cls.files[name] = (root / name).read_bytes()
        for path in (root / "art").glob("*.tga"):
            cls.files[path.relative_to(root).as_posix()] = path.read_bytes()

    def check_archive(self, files):
        buffer = io.BytesIO()
        with ZipFile(buffer, "w", ZIP_STORED) as archive:
            for name, content in files.items():
                archive.writestr(f"PrettyTooltip/{name}", content)
        with ZipFile(buffer) as archive:
            return check_package.check_contents(archive)

    def test_release_contents_and_startup(self):
        entries, sources = self.check_archive(self.files)
        with contextlib.redirect_stdout(io.StringIO()):
            check_package.check_startup(entries, sources)

    def test_missing_locale(self):
        files = dict(self.files)
        del files["Locale/koKR.lua"]
        with self.assertRaisesRegex(ValueError, "missing packaged files.*koKR"):
            self.check_archive(files)

    def test_wrong_filename_case(self):
        files = dict(self.files)
        files["Locale/kokr.lua"] = files.pop("Locale/koKR.lua")
        with self.assertRaisesRegex(ValueError, "missing packaged files.*koKR"):
            self.check_archive(files)

    def test_missing_texture(self):
        files = dict(self.files)
        del files["art/logo.tga"]
        with self.assertRaisesRegex(ValueError, "missing packaged files.*logo"):
            self.check_archive(files)

    def test_changed_locale_condition(self):
        files = dict(self.files)
        files[check_package.TOC] = files[check_package.TOC].replace(b"AllowLoadTextLocale koKR", b"AllowLoadTextLocale enUS")
        with self.assertRaisesRegex(ValueError, "locale conditions differ"):
            self.check_archive(files)

    def test_missing_retail_toc(self):
        files = dict(self.files)
        del files[check_package.RETAIL_TOC]
        with self.assertRaisesRegex(ValueError, "missing PrettyTooltip_Mainline.toc"):
            self.check_archive(files)

    def test_retail_toc_loading_classic_data(self):
        entries, sources = self.check_archive(self.files)
        entries[check_package.RETAIL_TOC] = ["Core/Util.lua"] + entries[check_package.TOC]
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(ValueError, "retail flag does not match"):
                check_package.check_startup(entries, sources)

    def test_debug_capture_leak(self):
        files = dict(self.files)
        files["UI/Capture.lua"] = b"-- debug code"
        with self.assertRaisesRegex(ValueError, "development file leaked"):
            self.check_archive(files)

    def test_broken_packaged_lua(self):
        entries, sources = self.check_archive(self.files)
        sources["PrettyTooltip.lua"] = "local = broken"
        with self.assertRaisesRegex(ValueError, "Lua syntax error"):
            check_package.check_startup(entries, sources)

    def test_broken_packaged_startup(self):
        entries, sources = self.check_archive(self.files)
        sources["Locale/koKR.lua"] = "error('broken locale startup')"
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(ValueError, "startup failed for koKR"):
                check_package.check_startup(entries, sources)


class TocChecks(unittest.TestCase):
    """tools/toc.py, which the tests, the package check, deploy.py, and the tools read the .toc files with."""
    TEXT = "\n".join(["## Interface: 1", "Core\\Util.lua", "Locale\\deDE.lua [AllowLoadTextLocale deDE]",
                      "Locale\\Portuguese.lua [AllowLoadTextLocale ptBR, ptPT]", "#@debug@", "UI\\Capture.lua",
                      "#@end-debug@", "PrettyTooltip.lua"])

    def test_load_order_by_language(self):
        toc = check_package.toc
        entries = toc.entries(self.TEXT)
        self.assertEqual(toc.load_order(entries, "enUS"), ["Core/Util.lua", "UI/Capture.lua", "PrettyTooltip.lua"])
        self.assertEqual(toc.load_order(entries, "ptPT"),
                         ["Core/Util.lua", "Locale/Portuguese.lua", "UI/Capture.lua", "PrettyTooltip.lua"])

    def test_release_leaves_out_debug_lines(self):
        toc = check_package.toc
        self.assertNotIn("UI/Capture.lua", toc.load_order(toc.entries(self.TEXT, debug=False), "enUS"))

    def test_unknown_condition_is_rejected(self):
        toc = check_package.toc
        with self.assertRaisesRegex(ValueError, "unsupported .toc condition"):
            toc.load_order(toc.entries("Core\\Util.lua [AllowLoadGameType mainline]"), "enUS")

    def test_both_games_tocs_are_read(self):
        files = check_package.toc.every_addon_file()
        self.assertIn("Data/Disenchant.lua", files)
        self.assertIn("Retail/Retail.lua", files)
        self.assertIn("Retail/Locale/deDE.lua", files)


class StrictChecks(unittest.TestCase):
    def test_missing_baseline_is_rejected_without_writing(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(regression, "OUTPUTS", Path(temporary)), patch.object(regression, "STRICT", True):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertFalse(regression.compare("missing", "new output", [], False, False))
            self.assertEqual(list(Path(temporary).iterdir()), [])

    def test_missing_lint_is_a_failure(self):
        with patch.object(regression, "STRICT", True), patch.dict(regression.os.environ, {"LUACHECK": ""}):
            with patch.object(regression.shutil, "which", return_value=None):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(regression.run_lint(), [False])


if __name__ == "__main__":
    unittest.main()
