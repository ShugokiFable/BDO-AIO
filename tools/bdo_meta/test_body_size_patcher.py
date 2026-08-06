from __future__ import annotations

import unittest

from body_size_patcher import (
    BONE_GROUPS,
    PRESETS,
    build_bone_values,
    fmt_vector,
    height_axis_index,
    patch_xml_bytes,
    resolve_part,
)


class BodySizePatcherTests(unittest.TestCase):
    def setUp(self) -> None:
        self.values = {
            "Bip01 L Breast": {"max": 3.0, "min": 0.7},
        }

    def test_vector_format_matches_fixed_width_game_shape(self) -> None:
        self.assertEqual(fmt_vector(0.7), b"0.70 0.70 0.70")
        self.assertEqual(fmt_vector(-2.0), b"-2.0 -2.0 -2.0")
        self.assertEqual(fmt_vector(10.0), b"10.0 10.0 10.0")

    def test_patch_is_byte_and_length_preserving(self) -> None:
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.30 1.55 1.55" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, edits, tags = patch_xml_bytes(raw, self.values)
        self.assertEqual(len(patched), len(raw))
        self.assertEqual(tags, 1)
        self.assertEqual(edits, 2)
        self.assertIn(b'Min="0.70 0.70 0.70"', patched)
        self.assertIn(b'Max="3.00 3.00 3.00"', patched)

    def test_never_writes_default(self) -> None:
        """Vanilla Default is per-class and anisotropic; overwriting it stretches bodies."""
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.10 1.00 1.00" '
            b'Default="0.97 0.90 0.90" BoneName="Bip01 L Thigh" '
            b'HeightAxis="X" WeightAxis01="Y" WeightAxis02="Z"/>'
        )
        patched, _, tags = patch_xml_bytes(raw, {"Bip01 L Thigh": {"max": 1.5}})
        self.assertEqual(tags, 1)
        self.assertIn(b'Default="0.97 0.90 0.90"', patched)

    def test_leaves_the_declared_height_axis_alone(self) -> None:
        """HeightAxis="X" is bone length -- raising it makes the character taller."""
        raw = (
            b'<ParamDesc Min="0.90 0.88 0.88" Max="1.10 1.00 1.00" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Thigh" '
            b'HeightAxis="X" WeightAxis01="Y" WeightAxis02="Z"/>'
        )
        patched, edits, tags = patch_xml_bytes(raw, {"Bip01 L Thigh": {"max": 1.5}})
        self.assertEqual((edits, tags), (1, 1))
        self.assertEqual(len(patched), len(raw))
        # X (length) untouched at 1.10; Y and Z (girth) widened.
        self.assertIn(b'Max="1.10 1.50 1.50"', patched)

    def test_bones_without_a_height_axis_widen_on_all_three(self) -> None:
        """Hip and Breast declare no HeightAxis -- every component is girth."""
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.00 1.00 1.00" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Hip" '
            b'WeightAxis01="Y" WeightAxis02="Z" WeightAxis03="X"/>'
        )
        patched, _, tags = patch_xml_bytes(raw, {"Bip01 L Hip": {"max": 1.25}})
        self.assertEqual(tags, 1)
        self.assertIn(b'Max="1.25 1.25 1.25"', patched)

    def test_only_widens_never_shrinks_an_existing_range(self) -> None:
        raw = (
            b'<ParamDesc Min="0.70 0.70 0.70" Max="1.30 1.55 1.55" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, edits, _ = patch_xml_bytes(raw, {"Bip01 L Breast": {"max": 1.40}})
        self.assertEqual(len(patched), len(raw))
        # 1.55 already exceeds the request and stays; only 1.30 is raised.
        self.assertIn(b'Max="1.40 1.55 1.55"', patched)
        self.assertEqual(edits, 1)

    def test_reports_no_edits_when_the_range_is_already_wide_enough(self) -> None:
        raw = (
            b'<ParamDesc Min="0.70 0.70 0.70" Max="2.00 2.00 2.00" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, edits, tags = patch_xml_bytes(raw, {"Bip01 L Breast": {"max": 1.50}})
        self.assertEqual((edits, tags), (0, 1))
        self.assertEqual(patched, raw)

    def test_unselected_bones_are_byte_identical(self) -> None:
        """Selecting breasts must not move calves, spine, or anything else."""
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.10 1.00 1.00" Default="1.10 0.88 1.00"'
            b' BoneName="Bip01 L Calf" HeightAxis="X"/>'
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.05 1.10 1.10" Default="0.98 0.95 0.90"'
            b' BoneName="Bip01 Spine" HeightAxis="X"/>'
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.25 1.25 1.25" Default="1.00 1.00 1.00"'
            b' BoneName="Bip01 L Breast"/>'
        )
        patched, _, tags = patch_xml_bytes(raw, {"Bip01 L Breast": {"max": 2.0}})
        self.assertEqual(tags, 1)
        self.assertIn(b'Max="1.10 1.00 1.00" Default="1.10 0.88 1.00"', patched)
        self.assertIn(b'Max="1.05 1.10 1.10" Default="0.98 0.95 0.90"', patched)
        self.assertIn(b'Max="2.00 2.00 2.00"', patched)

    def test_preserves_current_game_trailing_field_padding(self) -> None:
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.30 1.30 1.30 " '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, _, tags = patch_xml_bytes(raw, self.values)
        self.assertEqual(len(patched), len(raw))
        self.assertEqual(tags, 1)
        self.assertIn(b'Max="3.00 3.00 3.00 "', patched)

    def test_does_not_reach_back_into_a_previous_tag(self) -> None:
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.20 1.20 1.20" Default="1.00 1.00 1.00"/>'
            b'<ParamDesc BoneName="Bip01 L Breast"/>'
        )
        with self.assertRaisesRegex(ValueError, "expected a Min"):
            patch_xml_bytes(raw, self.values)

    def test_patches_duplicate_source_attributes_consistently(self) -> None:
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Min="0.90 0.90 0.90" '
            b'Max="1.30 1.55 1.55" Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, edits, tags = patch_xml_bytes(raw, self.values)
        self.assertEqual(len(patched), len(raw))
        self.assertEqual(tags, 1)
        self.assertEqual(edits, 3)
        self.assertEqual(patched.count(b'Min="0.70 0.70 0.70"'), 2)

    def test_rejects_scalar_source_instead_of_shipping_it(self) -> None:
        raw = b'<ParamDesc Min="0.7" Max="3.0" Default="1.1" BoneName="Bip01 L Breast"/>'
        with self.assertRaisesRegex(ValueError, "three-component numeric vector"):
            patch_xml_bytes(raw, self.values)


class BodyPartSelectionTests(unittest.TestCase):
    def test_only_three_groups_are_supported(self) -> None:
        self.assertEqual(set(BONE_GROUPS), {"breasts", "thighs", "butt"})

    def test_butt_covers_hip_and_pelvis(self) -> None:
        """33 of 75 live body files lock Hip Max at <=1.00; Pelvis carries the shape."""
        self.assertIn("Bip01 Pelvis", BONE_GROUPS["butt"])
        self.assertIn("Bip01 L Hip", BONE_GROUPS["butt"])
        self.assertIn("Bip01 R Hip", BONE_GROUPS["butt"])

    def test_pelvis_and_ass_resolve_onto_butt(self) -> None:
        self.assertEqual(resolve_part("pelvis"), "butt")
        self.assertEqual(resolve_part("ass"), "butt")
        self.assertEqual(resolve_part("BUTT"), "butt")

    def test_retired_groups_no_longer_resolve(self) -> None:
        for name in ("legs", "spine", "arms"):
            self.assertIsNone(resolve_part(name))

    def test_recommended_preset_matches_the_documented_ratio(self) -> None:
        self.assertEqual(
            PRESETS["recommended"], {"breasts": 1.37, "thighs": 1.30, "butt": 1.18}
        )

    def test_all_presets_keep_butt_at_or_below_hard_cap(self) -> None:
        """BDO lower-cheek mesh pyramids above 1.18; no shipped preset exceeds it."""
        for name, parts in PRESETS.items():
            self.assertLessEqual(
                parts["butt"],
                1.18 if name != "vanilla" else 1.25,
                msg=f"{name} butt {parts['butt']} exceeds allowed cap",
            )
        self.assertEqual(PRESETS["vanilla"]["butt"], 1.25)
        for name in ("mild", "recommended", "extreme"):
            self.assertEqual(PRESETS[name]["butt"], 1.18)

    def test_selection_never_leaks_into_unselected_bones(self) -> None:
        bones = build_bone_values({"breasts": {"max": 2.0}})
        self.assertEqual(set(bones), {"Bip01 L Breast", "Bip01 R Breast"})
        for leaked in ("Bip01 L Calf", "Bip01 Spine", "Bip01 Pelvis", "Bip01 L Thigh"):
            self.assertNotIn(leaked, bones)


class HeightAxisTests(unittest.TestCase):
    def test_reads_the_axis_the_game_declares(self) -> None:
        self.assertEqual(height_axis_index(b'<ParamDesc HeightAxis="X"/>'), 0)
        self.assertEqual(height_axis_index(b'<ParamDesc HeightAxis="Y"/>'), 1)
        self.assertEqual(height_axis_index(b'<ParamDesc HeightAxis="Z"/>'), 2)

    def test_absent_or_empty_height_axis_means_pure_girth(self) -> None:
        self.assertIsNone(height_axis_index(b'<ParamDesc WeightAxis01="Y"/>'))
        self.assertIsNone(height_axis_index(b'<ParamDesc HeightAxis=""/>'))


if __name__ == "__main__":
    unittest.main()
