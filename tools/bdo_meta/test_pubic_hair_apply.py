import pathlib
import struct
import tempfile
import unittest

from pubic_hair_apply import apply_bin_to_dds


def dds_header(*, fourcc: bytes, bpp: int, masks: tuple[int, int, int, int]) -> bytes:
    data = bytearray(128)
    data[:4] = b"DDS "
    struct.pack_into("<I", data, 4, 124)
    struct.pack_into("<I", data, 12, 4)
    struct.pack_into("<I", data, 16, 4)
    struct.pack_into("<I", data, 28, 1)
    struct.pack_into("<I", data, 76, 32)
    struct.pack_into("<I", data, 80, 0x4 if fourcc else 0x41)
    data[84:88] = fourcc
    struct.pack_into("<I", data, 88, bpp)
    struct.pack_into("<4I", data, 92, *masks)
    return bytes(data)


class PubicHairApplyTests(unittest.TestCase):
    def test_translates_dxt1_overlay_to_uncompressed_dds(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            base = root / "base.dds"
            selected = root / "selected.bin"
            neutral = root / "neutral.bin"
            output = root / "output.dds"
            base.write_bytes(
                dds_header(
                    fourcc=b"\0\0\0\0",
                    bpp=32,
                    masks=(0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000),
                )
                + bytes((10, 20, 30, 255)) * 16
            )
            selected.write_bytes(struct.pack("<HHI", 0xF800, 0, 0))
            neutral.write_bytes(struct.pack("<HHI", 0, 0, 0))

            self.assertTrue(
                apply_bin_to_dds(base, selected, [(128, 8)], output, neutral)
            )
            self.assertEqual(output.read_bytes()[128:], bytes((10, 20, 255, 255)) * 16)

    def test_keeps_original_dxt1_patch_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            base = root / "base.dds"
            selected = root / "selected.bin"
            output = root / "output.dds"
            original = b"12345678"
            replacement = b"ABCDEFGH"
            base.write_bytes(
                dds_header(fourcc=b"DXT1", bpp=0, masks=(0, 0, 0, 0)) + original
            )
            selected.write_bytes(replacement)

            self.assertTrue(apply_bin_to_dds(base, selected, [(128, 8)], output))
            self.assertEqual(output.read_bytes()[128:], replacement)


if __name__ == "__main__":
    unittest.main()
