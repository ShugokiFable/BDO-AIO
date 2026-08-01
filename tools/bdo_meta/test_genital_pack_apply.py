from __future__ import annotations

import pathlib
import tempfile
import unittest

from genital_pack_apply import pick_female_donor, pick_male_native


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


if __name__ == "__main__":
    unittest.main()
