from __future__ import annotations

import pathlib
import re
import unittest

from body_atlas import (
    alias_stem,
    atlas_owners,
    read_pac_atlas,
    replace_pac_stem,
    resolve_class_bodies,
    texture_variants,
)
from pubic_hair_apply import parse_style_map

PACK = pathlib.Path(__file__).resolve().parents[2] / "pack" / "midnight_xyzw"
NUDE_ROOTS = [PACK / "_00_suzu_nude", PACK / "_00_thegreatsage_nude"]
HAVE_PACK = all(r.is_dir() for r in NUDE_ROOTS)


class AtlasStemTests(unittest.TestCase):
    def test_reads_the_single_embedded_stem(self) -> None:
        data = b"\x00\x01PHW_01_Nude_0001\x00padding"
        stem, offset = read_pac_atlas(data)
        self.assertEqual(stem, "PHW_01_Nude_0001")
        self.assertEqual(offset, 2)

    def test_rejects_a_pac_with_no_stem(self) -> None:
        with self.assertRaisesRegex(ValueError, "no nude atlas stem"):
            read_pac_atlas(b"nothing useful here")

    def test_rejects_an_ambiguous_pac(self) -> None:
        with self.assertRaisesRegex(ValueError, "several nude atlases"):
            read_pac_atlas(b"PHW_01_Nude_0001 and PWW_01_Nude_0001")

    def test_rejects_a_repeated_stem_instead_of_renaming_one(self) -> None:
        with self.assertRaisesRegex(ValueError, "occurs 2 times"):
            read_pac_atlas(b"PHW_01_Nude_0001 x PHW_01_Nude_0001")


class NoPacRenamingTests(unittest.TestCase):
    """Renaming a PAC's material made Maehwa/Woosa/Deadeye invisible in game.

    The embedded string is a MATERIAL name resolved through the engine's material
    registry, not a texture path, so pointing it at an invented name leaves the
    mesh with nothing bound. The generator must never write a PAC.
    """

    def test_generator_does_not_import_the_renaming_helpers(self) -> None:
        source = (pathlib.Path(__file__).resolve().parent / "pubic_hair_apply.py").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("replace_pac_stem", source)
        self.assertNotIn("alias_stem", source)

    def test_generator_never_writes_a_pac(self) -> None:
        source = (pathlib.Path(__file__).resolve().parent / "pubic_hair_apply.py").read_text(
            encoding="utf-8"
        )
        # ".pac" as a filename EXTENSION - not struct.pack_into / packed /
        # pack-related identifiers, which legitimately contain the substring.
        self.assertIsNone(re.search(r"\.pac(?!\w)", source))


class AliasTests(unittest.TestCase):
    def test_alias_preserves_byte_length(self) -> None:
        for index in (1, 9, 10, 99):
            alias = alias_stem("PHW_01_Nude_0001", index)
            self.assertEqual(len(alias), len("PHW_01_Nude_0001"))

    def test_alias_keeps_the_variant_and_slot_suffix(self) -> None:
        self.assertEqual(alias_stem("PHW_01_Nude_0001", 1), "x01_01_Nude_0001")
        self.assertEqual(alias_stem("PBW_00_Nude_0001", 7), "x07_00_Nude_0001")

    def test_aliases_are_unique_and_stable(self) -> None:
        made = [alias_stem("PHW_01_Nude_0001", i) for i in range(1, 40)]
        self.assertEqual(len(set(made)), len(made))
        self.assertEqual(made[0], alias_stem("PHW_01_Nude_0001", 1))

    def test_rejects_an_index_too_wide_for_the_prefix(self) -> None:
        with self.assertRaises(ValueError):
            alias_stem("PHW_01_Nude_0001", 100)


class ReplaceTests(unittest.TestCase):
    def test_replacement_preserves_length_and_hits_once(self) -> None:
        data = b"head PHW_01_Nude_0001 tail"
        out = replace_pac_stem(data, "PHW_01_Nude_0001", "x01_01_Nude_0001")
        self.assertEqual(len(out), len(data))
        self.assertIn(b"x01_01_Nude_0001", out)
        self.assertNotIn(b"PHW_01_Nude_0001", out)

    def test_rejects_length_change(self) -> None:
        with self.assertRaisesRegex(ValueError, "byte length"):
            replace_pac_stem(b"PHW_01_Nude_0001", "PHW_01_Nude_0001", "TOO_SHORT")

    def test_rejects_when_the_stem_is_absent(self) -> None:
        with self.assertRaisesRegex(ValueError, "found 0"):
            replace_pac_stem(b"nothing", "PHW_01_Nude_0001", "x01_01_Nude_0001")


class StyleMapTests(unittest.TestCase):
    def test_per_class_styles(self) -> None:
        got = parse_style_map("pnw=full_bush,pcw=trimmed", "", None)
        self.assertEqual(got, {"pnw": "full_bush", "pcw": "trimmed"})

    def test_legacy_single_style_expands(self) -> None:
        got = parse_style_map("", "pnw,pcw", "full_bush")
        self.assertEqual(got, {"pnw": "full_bush", "pcw": "full_bush"})

    def test_empty_selection_stays_empty_and_never_becomes_all(self) -> None:
        self.assertEqual(parse_style_map("", "", None), {})
        self.assertEqual(parse_style_map("", "", "full_bush"), {})
        self.assertEqual(parse_style_map("   ", "  ", None), {})

    def test_rejects_unknown_style(self) -> None:
        with self.assertRaisesRegex(ValueError, "unknown style"):
            parse_style_map("pnw=mohawk", "", None)

    def test_rejects_malformed_entry(self) -> None:
        with self.assertRaisesRegex(ValueError, "expected prefix=style"):
            parse_style_map("pnw", "", None)


class TextureVariantTests(unittest.TestCase):
    def test_collects_sibling_maps_but_not_other_atlases(self) -> None:
        files = [
            pathlib.Path("phw_01_nude_0001.dds"),
            pathlib.Path("phw_01_nude_0001_n.dds"),
            pathlib.Path("phw_01_nude_0001_w.dds"),
            pathlib.Path("pww_01_nude_0001.dds"),
            pathlib.Path("phw_01_nude_0002.dds"),
        ]
        got = [p.name for p in texture_variants(files, "phw_01_nude_0001")]
        self.assertEqual(
            got,
            ["phw_01_nude_0001.dds", "phw_01_nude_0001_n.dds", "phw_01_nude_0001_w.dds"],
        )


@unittest.skipUnless(HAVE_PACK, "Midnight nude pack not present")
class RealPackTests(unittest.TestCase):
    """The facts this whole design rests on, asserted against the shipped pack."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.bodies, cls.problems = resolve_class_bodies(NUDE_ROOTS)
        cls.owners = atlas_owners(cls.bodies)

    def test_every_body_pac_parses(self) -> None:
        self.assertEqual(self.problems, [])
        self.assertGreaterEqual(len(self.bodies), 19)

    def test_one_atlas_is_shared_by_most_classes(self) -> None:
        shared = {k: v for k, v in self.owners.items() if len(v) > 1}
        self.assertEqual(list(shared), ["phw_01_nude_0001"])
        self.assertGreaterEqual(len(shared["phw_01_nude_0001"]), 13)

    def test_kunoichi_renders_from_the_sorceress_atlas(self) -> None:
        """The exact reason a Kunoichi-only run used to change 12 other classes."""
        self.assertEqual(self.bodies["pnw"].atlas_key, "phw_01_nude_0001")

    def test_guardian_owns_its_atlas(self) -> None:
        self.assertEqual(self.bodies["pgw"].atlas_key, "pgw_01_nude_0001")
        self.assertEqual(self.owners["pgw_01_nude_0001"], ["pgw"])

    def test_source_precedence_is_explicit_not_glob_order(self) -> None:
        # Tamer and Deadeye only exist in Suzu; the rest come from TheGreatSage.
        self.assertEqual(self.bodies["pbw"].source, "_00_suzu_nude")
        self.assertEqual(self.bodies["pwge"].source, "_00_suzu_nude")
        self.assertEqual(self.bodies["pnw"].source, "_00_thegreatsage_nude")

    def test_every_real_pac_can_be_aliased_without_resizing(self) -> None:
        for index, (prefix, body) in enumerate(sorted(self.bodies.items()), start=1):
            raw = body.pac_path.read_bytes()
            alias = alias_stem(body.atlas_stem, index)
            out = replace_pac_stem(raw, body.atlas_stem, alias)
            self.assertEqual(len(out), len(raw), prefix)
            self.assertEqual(sum(a != b for a, b in zip(raw, out)), 3, prefix)


if __name__ == "__main__":
    unittest.main()
