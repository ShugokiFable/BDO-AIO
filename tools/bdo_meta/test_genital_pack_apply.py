from __future__ import annotations

import pathlib
import struct
import tempfile
import unittest

from genital_pack_apply import (
    copy_female_class,
    copy_male_class,
    copy_material_textures,
    pac_material_stem,
    pick_female_donor,
    pick_male_native,
)


def write_dds(path: pathlib.Path) -> None:
    header = bytearray(128)
    header[:4] = b"DDS "
    struct.pack_into("<I", header, 4, 124)
    struct.pack_into("<II", header, 12, 4, 4)
    path.write_bytes(header)


class GenitalDonorScopeTests(unittest.TestCase):
    def test_a_class_without_an_authored_mesh_is_refused(self) -> None:
        """Reuse gave Seraph another class's body AND skin; it is no longer allowed."""
        with tempfile.TemporaryDirectory() as temp:
            pack = pathlib.Path(temp)
            female = pack / "female"
            female.mkdir()
            (female / "pww_00_nude_0001.pac").write_bytes(b"female")
            with self.assertRaisesRegex(FileNotFoundError, "no authored 3D-vagina mesh"):
                pick_female_donor(pack, "pdkl")

    def test_a_class_with_an_authored_mesh_uses_its_own(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = pathlib.Path(temp)
            female = pack / "female"
            female.mkdir()
            (female / "pww_00_nude_0001.pac").write_bytes(b"female")
            source, donor, native = pick_female_donor(pack, "pww")
            self.assertEqual((source.name, donor, native), ("pww_00_nude_0001.pac", "pww", True))

    def test_no_female_class_can_borrow_another_classes_mesh(self) -> None:
        from class_coverage import FEMALE_CLASSES

        with tempfile.TemporaryDirectory() as temp:
            pack = pathlib.Path(temp)
            female = pack / "female"
            female.mkdir()
            # Every authored mesh is present, so a fallback would be easy to hit.
            for native in {v[2] for v in FEMALE_CLASSES.values() if v[2]}:
                (female / native).write_bytes(b"x")
            for prefix, meta in FEMALE_CLASSES.items():
                if meta[2]:
                    _, donor, native = pick_female_donor(pack, prefix)
                    self.assertEqual(donor, prefix, prefix)
                    self.assertTrue(native, prefix)
                else:
                    with self.assertRaises(FileNotFoundError, msg=prefix):
                        pick_female_donor(pack, prefix)


class UnderwearPathTests(unittest.TestCase):
    """Underwear hide path vs nude body path.

    Verified against the live game index: armor/38_underwear/ is the real
    underwear slot. Genital packs must NOT write *_uw_0001.pac there — that
    overwrites Midnight's dummy hide and holes the body under skirts.
    """

    def test_folders_are_separate(self) -> None:
        from class_coverage import (
            female_folder,
            female_underwear_folder,
            male_folder,
            male_underwear_folder,
        )

        self.assertTrue(female_folder("pww").endswith("/nude"))
        self.assertTrue(female_underwear_folder("pww").endswith("/armor/38_underwear"))
        self.assertTrue(male_folder("phm").endswith("/nude"))
        self.assertTrue(male_underwear_folder("phm").endswith("/armor/38_underwear"))
        self.assertNotIn("/nude", female_underwear_folder("pww"))
        self.assertNotIn("/nude", male_underwear_folder("phm"))

    def test_female_genital_writes_nude_only_never_underwear(self) -> None:
        """Genital PAC on uw_0001 beat Midnight's 1 KB dummy (pri 600 > 100)."""
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            pack, out = root / "pack", root / "out"
            female = pack / "female"
            female.mkdir(parents=True)
            (pack / "texture").mkdir(parents=True)
            # Witch native mesh + matching material texture
            (female / "pww_00_nude_0001.pac").write_bytes(b"mesh PWW_01_Nude_0001 body")
            write_dds(pack / "texture" / "pww_01_nude_0001.dds")

            copy_female_class(pack, out, "pww")

            nude = list(out.rglob("pww_00_nude_0001.pac"))
            uw = list(out.rglob("*uw_0001.pac"))
            self.assertEqual(len(nude), 1, nude)
            self.assertTrue(any("/nude/" in str(p).replace("\\", "/") or p.parent.name == "nude" for p in nude))
            self.assertEqual(uw, [], "genital must not emit underwear PAC (breaks Midnight hide)")

    def test_male_genital_writes_nude_only_never_underwear(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            pack, out = root / "pack", root / "out"
            male = pack / "male" / "normal"
            male.mkdir(parents=True)
            (pack / "texture").mkdir(parents=True)
            (male / "phm_00_nude_0001.pac").write_bytes(b"mesh PHM_00_Nude_0001 body")
            write_dds(pack / "texture" / "phm_00_nude_0001.dds")

            copy_male_class(pack, out, "phm", "normal")

            nude = list(out.rglob("phm_00_nude_0001.pac"))
            uw = list(out.rglob("*uw_0001.pac"))
            self.assertEqual(len(nude), 1, nude)
            self.assertEqual(uw, [], "male genital must not emit underwear PAC")

    def test_wukong_never_falls_back_to_a_male_donor(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = pathlib.Path(temp)
            male = pack / "male" / "normal"
            male.mkdir(parents=True)
            (male / "phm_00_nude_0001.pac").write_bytes(b"warrior")
            with self.assertRaisesRegex(FileNotFoundError, "no NATIVE male PAC for pgms"):
                pick_male_native(pack, "pgms", "normal")

    def test_material_textures_keep_the_pac_authored_names(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            pack, out = root / "pack", root / "out"
            (pack / "texture").mkdir(parents=True)
            pac = pack / "female" / "pcw_00_nude_0001.pac"
            pac.parent.mkdir()
            pac.write_bytes(b"mesh PHW_01_Nude_0001 material")
            write_dds(pack / "texture" / "phw_01_nude_0001.dds")
            write_dds(pack / "texture" / "phw_01_nude_0001_n.dds")

            notes = copy_material_textures(pack, out, pac, "F")

            self.assertEqual(pac_material_stem(pac), "phw_01_nude_0001")
            self.assertEqual(
                sorted(p.name for p in (out / "character" / "texture").iterdir()),
                ["phw_01_nude_0001.dds", "phw_01_nude_0001_n.dds"],
            )
            self.assertTrue(any("phw_01_nude_0001" in note for note in notes))

    def test_missing_embedded_diffuse_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            pack = root / "pack"
            (pack / "texture").mkdir(parents=True)
            pac = pack / "male" / "normal" / "pnm_00_nude_0001.pac"
            pac.parent.mkdir(parents=True)
            pac.write_bytes(b"mesh PHM_00_Nude_0001 material")
            with self.assertRaisesRegex(FileNotFoundError, "phm_00_nude_0001.dds"):
                copy_material_textures(pack, root / "out", pac, "M")


if __name__ == "__main__":
    unittest.main()
