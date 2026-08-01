from __future__ import annotations

import pathlib
import tempfile
import unittest

from censorship_pack_apply import blank_keep_size, copy_legacy, is_expand_candidate


class CensorshipPackTests(unittest.TestCase):
    def test_accepts_exact_character_texture_path(self) -> None:
        self.assertTrue(is_expand_candidate("character/texture/", "pew_00_underup_0009.dds"))

    def test_rejects_thumbnail_false_positive(self) -> None:
        self.assertFalse(
            is_expand_candidate("character/texture_thumbnail/", "pew_00_underup_0009.dds")
        )

    def test_rejects_age_ambiguous_names(self) -> None:
        self.assertFalse(is_expand_candidate("character/texture", "nbw_child_underup.dds"))
        self.assertFalse(is_expand_candidate("character/texture", "plw_00_underup.dds"))
        self.assertFalse(is_expand_candidate("character/texture", "#en#plw_00_uw_0000.dds"))

    def test_live_meta_filter_does_not_emit_stale_legacy_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            pack = root / "pack"
            out = root / "out"
            pack.mkdir()
            out.mkdir()
            (pack / "stale.dds").write_bytes(b"DDS data")
            ok, missing = copy_legacy(pack, out, ["stale.dds"], {"current.dds"})
            self.assertEqual((ok, missing), (0, 1))
            self.assertFalse((out / "stale.dds").exists())

    def test_refuses_to_emit_zeroed_non_dds_garbage(self) -> None:
        with self.assertRaisesRegex(ValueError, "valid DDS"):
            blank_keep_size(bytes(824))


if __name__ == "__main__":
    unittest.main()
