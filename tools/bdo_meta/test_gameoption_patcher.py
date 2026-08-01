from __future__ import annotations

import pathlib
import tempfile
import unittest

from gameoption_patcher import apply, patched_bytes, read_profile


class GameOptionPatcherTests(unittest.TestCase):
    def test_patch_preserves_unknown_hardware_and_user_lines(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            source, profile, output = root / "GameOption.txt", root / "quality.patch", root / "out.txt"
            source.write_bytes(
                b"version = 4\r\nadaptorList = 3077020889\r\nwidth = 2560\r\n"
                b"graphicOption = 7\r\ntextureQuality = 2\r\nselfEffectAlpha = 0.75\r\n"
            )
            profile.write_text("width = 1920\ngraphicOption = 9\ntextureQuality = 0\n", encoding="utf-8")

            result = apply(source, profile, output)

            self.assertEqual(source.read_bytes().splitlines()[1], b"adaptorList = 3077020889")
            self.assertEqual(
                output.read_bytes(),
                b"version = 4\r\nadaptorList = 3077020889\r\nwidth = 1920\r\n"
                b"graphicOption = 9\r\ntextureQuality = 0\r\nselfEffectAlpha = 0.75\r\n",
            )
            self.assertEqual(result["changed"], ["width", "graphicOption", "textureQuality"])

    def test_missing_current_client_key_fails_without_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            source, profile = root / "GameOption.txt", root / "quality.patch"
            source.write_text("width = 1920\n", encoding="ascii")
            profile.write_text("width = 1920\nSSAO = 1\n", encoding="ascii")
            with self.assertRaisesRegex(ValueError, "ssao"):
                patched_bytes(source.read_bytes(), read_profile(profile))

    def test_shipped_profiles_use_current_saved_remastered_and_high_values(self) -> None:
        profiles = pathlib.Path(__file__).resolve().parents[2] / "graphics"
        shipped = sorted(profiles.glob("GameOption_*.patch"))
        self.assertEqual(len(shipped), 3)
        for profile in shipped:
            values = read_profile(profile)
            self.assertEqual(values["graphicoption"], "9")
            self.assertEqual(values["texturequality"], "0")


if __name__ == "__main__":
    unittest.main()
