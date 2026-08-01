from __future__ import annotations

import unittest

from body_size_patcher import fmt_vector, patch_xml_bytes


class BodySizePatcherTests(unittest.TestCase):
    def setUp(self) -> None:
        self.values = {
            "Bip01 L Breast": {"min": 0.7, "default": 1.1, "max": 3.0},
        }

    def test_vector_format_matches_fixed_width_game_shape(self) -> None:
        self.assertEqual(fmt_vector(0.7), b"0.70 0.70 0.70")
        self.assertEqual(fmt_vector(-2.0), b"-2.0 -2.0 -2.0")
        self.assertEqual(fmt_vector(10.0), b"10.0 10.0 10.0")

    def test_patch_is_byte_and_length_preserving(self) -> None:
        raw = (
            b'<ParamDesc Min="0.70 0.70 0.70" Max="1.30 1.55 1.55" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, edits, tags = patch_xml_bytes(raw, self.values)
        self.assertEqual(len(patched), len(raw))
        self.assertEqual(edits, 3)
        self.assertEqual(tags, 1)
        self.assertIn(b'Min="0.70 0.70 0.70"', patched)
        self.assertIn(b'Max="3.00 3.00 3.00"', patched)
        self.assertIn(b'Default="1.10 1.10 1.10"', patched)

    def test_does_not_reach_back_into_a_previous_tag(self) -> None:
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.20 1.20 1.20" Default="1.00 1.00 1.00"/>'
            b'<ParamDesc BoneName="Bip01 L Breast"/>'
        )
        with self.assertRaisesRegex(ValueError, "expected a Min"):
            patch_xml_bytes(raw, self.values)

    def test_patches_duplicate_source_attributes_consistently(self) -> None:
        raw = (
            b'<ParamDesc Min="0.70 0.70 0.70" Min="0.70 0.70 0.70" '
            b'Max="1.30 1.55 1.55" Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, edits, tags = patch_xml_bytes(raw, self.values)
        self.assertEqual(len(patched), len(raw))
        self.assertEqual(tags, 1)
        self.assertEqual(edits, 4)
        self.assertEqual(patched.count(b'Min="0.70 0.70 0.70"'), 2)

    def test_rejects_scalar_source_instead_of_shipping_it(self) -> None:
        raw = b'<ParamDesc Min="0.7" Max="3.0" Default="1.1" BoneName="Bip01 L Breast"/>'
        with self.assertRaisesRegex(ValueError, "three-component numeric vector"):
            patch_xml_bytes(raw, self.values)


if __name__ == "__main__":
    unittest.main()
