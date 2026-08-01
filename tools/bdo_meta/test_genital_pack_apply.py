from __future__ import annotations

import pathlib
import struct
import tempfile
import unittest

from genital_pack_apply import copy_material_textures, pac_material_stem, pick_female_donor, pick_male_native


def write_dds(path: pathlib.Path) -> None:
    header = bytearray(128)
    header[:4] = b"DDS "
    struct.pack_into("<I", header, 4, 124)
    struct.pack_into("<II", header, 12, 4, 4)
    path.write_bytes(header)


class GenitalDonorScopeTests(unittest.TestCase):
    def test_female_reuse_still_uses_a_real_female_donor(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = pathlib.Path(temp)
            female = pack / "female"
            female.mkdir()
            (female / "pww_00_nude_0001.pac").write_bytes(b"female")
            source, donor, native = pick_female_donor(pack, "pdkl", allow_reuse=True)
            self.assertEqual((source.name, donor, native), ("pww_00_nude_0001.pac", "pww", False))

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
