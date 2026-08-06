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

    def test_never_blanks_a_geometry_clip_mask(self) -> None:
        """A zeroed cull map decodes to solid black and culls the body under the
        garment -- this is what removed Ranger set 0274's legs in 2.1.3."""
        for name in (
            "pew_00_ub_0274_cull.dds",
            "pew_00_ub_0274_cull_d.dds",
            "pew_00_ub_0274_dm_cull.dds",
            "pdw_00_lb_0002_cull.dds",
            "pdw_00_ub_0002_01_cull_em.dds",
            "pww_00_sho_0268_cull_dm.dds",
            "pgms_00_sho_0001_cull.dds",
        ):
            self.assertFalse(
                is_expand_candidate("character/texture", name), f"{name} must stay vanilla"
            )

    def test_still_blanks_the_underwear_decals_the_tier_is_for(self) -> None:
        for name in (
            "pew_00_uw_0011_dec.dds",
            "pew_00_underup_0004.dds",
            "pew_00_lb_0033_dec.dds",
        ):
            self.assertTrue(is_expand_candidate("character/texture", name), name)

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
