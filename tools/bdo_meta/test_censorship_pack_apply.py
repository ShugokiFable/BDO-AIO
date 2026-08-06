from __future__ import annotations

import pathlib
import tempfile
import unittest

from censorship_pack_apply import (
    transparent_payload,
    blank_keep_size,
    copy_legacy,
    is_expand_candidate,
    legacy_reject_reason,
)

DDPF_ALPHAPIXELS = 0x1
DDPF_FOURCC = 0x4


def dds(
    width: int,
    height: int,
    payload: int,
    fourcc: bytes = b"DXT1",
    pf_flags: int = DDPF_FOURCC,
) -> bytes:
    """Smallest buffer that parses as the DDS header the code reads."""
    head = bytearray(128)
    head[0:4] = b"DDS "
    head[12:16] = height.to_bytes(4, "little")
    head[16:20] = width.to_bytes(4, "little")
    head[80:84] = pf_flags.to_bytes(4, "little")
    head[84:88] = fourcc
    return bytes(head) + bytes(payload)


class TransparentPayloadTests(unittest.TestCase):
    """A blank is only a removal if it decodes to TRANSPARENT, not to black."""

    def test_dxt5_and_dxt3_zero_their_alpha(self) -> None:
        for fourcc in (b"DXT5", b"DXT3"):
            out, note = transparent_payload(dds(1024, 1024, 64, fourcc))
            self.assertIsNotNone(out)
            self.assertEqual(out[128:], bytes(64), note)

    def test_dxt1_is_always_refused(self) -> None:
        """Measured twice on the live client, both times meshes broke: zeroed DXT1 is
        opaque black, and BC1's genuine transparent encoding still discarded meshes --
        first across all 157 DXT1 maps, then with only the 2018 pack's 15 hand-picked
        names. BDO uses DXT1 for base diffuse maps, and an alpha-tested base map that
        is fully transparent takes the mesh with it."""
        out, reason = transparent_payload(dds(1024, 1024, 24, b"DXT1"))
        self.assertIsNone(out)
        self.assertIn("DXT1", reason)

    def test_size_is_always_preserved(self) -> None:
        for fourcc in (b"DXT3", b"DXT5"):
            src = dds(1024, 1024, 96, fourcc)
            out, _ = transparent_payload(src)
            self.assertEqual(len(out), len(src))

    def test_uncompressed_needs_an_alpha_channel(self) -> None:
        out, _ = transparent_payload(dds(64, 64, 64, b"RGBA", DDPF_ALPHAPIXELS))
        self.assertIsNotNone(out)
        out, reason = transparent_payload(dds(64, 64, 64, b"RGBA", 0))
        self.assertIsNone(out)
        self.assertIn("alpha", reason)


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
            ok, missing = copy_legacy(pack, out, ["stale.dds"], {"current.dds": 8})
            self.assertEqual((ok, missing), (0, 1))
            self.assertFalse((out / "stale.dds").exists())

    def test_rejects_the_4x4_stub_that_flattens_a_body_map(self) -> None:
        """pew_00_lb_0033_dec.dds is 152 B / 4x4 against a 1398256 B live texture.
        It erases the painted shorts and smears one dead colour over the whole
        lower body -- the 'no ass, no crotch, broken mesh' report."""
        reason = legacy_reject_reason(dds(4, 4, 24), "pew_00_lb_0033_dec.dds", 1398256)
        self.assertIn("stub", reason or "")

    def test_rejects_a_mipless_2018_texture_against_a_mipped_live_one(self) -> None:
        """1024^2 DXT1 flat = 524416 B; the live client ships the mipped 699192 B."""
        reason = legacy_reject_reason(dds(1024, 1024, 524288), "pdw_02_lb_0005.dds", 699192)
        self.assertIn("stale", reason or "")

    def test_rejects_a_clip_mask_from_the_legacy_list_too(self) -> None:
        reason = legacy_reject_reason(dds(1024, 1024, 699064), "pdw_00_sho_0002_cull.dds", 699192)
        self.assertEqual(reason, "geometry clip mask")

    def test_accepts_a_legacy_file_that_still_matches_the_live_texture(self) -> None:
        payload = 699192 - 128
        self.assertIsNone(
            legacy_reject_reason(dds(1024, 1024, payload), "pbw_00_ub_0054.dds", 699192)
        )

    def test_without_a_live_meta_only_structural_rules_apply(self) -> None:
        self.assertIsNone(legacy_reject_reason(dds(1024, 1024, 4096), "pbw_00_ub_0054.dds", None))
        self.assertIsNotNone(legacy_reject_reason(dds(4, 4, 24), "pew_02_lb_0001.dds", None))

    def test_refuses_to_emit_zeroed_non_dds_garbage(self) -> None:
        with self.assertRaisesRegex(ValueError, "valid DDS"):
            blank_keep_size(bytes(824))


if __name__ == "__main__":
    unittest.main()
