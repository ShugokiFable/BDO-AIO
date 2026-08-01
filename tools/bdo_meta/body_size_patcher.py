#!/usr/bin/env python3
"""
BDO character-creation body size limit patcher (Resorepless-style).

Extracts *customizationboneparamdesc* files from live PAZ (via pad00000.meta + ice_decipher),
raises Min/Default/Max for body bones, writes into files_to_patch for Meta Injector.

Vanilla defaults (Resorepless): Min=0.90 Default=1.00 Max=1.25
Recommended max around 2.5 (same note as old tool). Breast size may not affect Tamer.
"""
from __future__ import annotations

import argparse
import ctypes
import math
import pathlib
import re
import sys
# Bone groups matching Resorepless size_patcher
BONE_GROUPS = {
    "breasts": ["Bip01 L Breast", "Bip01 R Breast"],
    "butt": ["Bip01 L Hip", "Bip01 R Hip"],
    "thighs": ["Bip01 L Thigh", "Bip01 R Thigh"],
    "legs": ["Bip01 L Calf", "Bip01 R Calf"],
    "pelvis": ["Bip01 Pelvis"],
    "spine": ["Bip01 Spine"],
    "arms": [
        "Bip01 L UpperArm",
        "Bip01 R UpperArm",
        "Bip01 L Forearm",
        "Bip01 R Forearm",
    ],
}

DEFAULTS = {"min": 0.90, "default": 1.00, "max": 1.25}

PRESETS = {
    "vanilla": {"min": 0.90, "default": 1.00, "max": 1.25},
    "mild": {"min": 0.85, "default": 1.00, "max": 1.75},
    "high": {"min": 0.80, "default": 1.05, "max": 2.50},
    "extreme": {"min": 0.70, "default": 1.10, "max": 3.00},
}


def log(msg: str) -> None:
    print(msg, flush=True)


class IceDecipher:
    def __init__(self, dll_path: pathlib.Path):
        self.lib = ctypes.CDLL(str(dll_path))
        self.lib.decrypt_inplace.argtypes = [ctypes.POINTER(ctypes.c_ubyte), ctypes.c_int]
        self.lib.decrypt_inplace.restype = None

    def decrypt(self, encrypted_data: bytes) -> bytes:
        buf = (ctypes.c_ubyte * len(encrypted_data)).from_buffer_copy(encrypted_data)
        self.lib.decrypt_inplace(buf, len(encrypted_data))
        return bytes(buf)


class FileBlock:
    __slots__ = (
        "hash",
        "folderNum",
        "fileNum",
        "pazNum",
        "fileOffset",
        "zsize",
        "size",
        "folderName",
        "fileName",
    )

    def __init__(self, f):
        self.hash = int.from_bytes(f.read(4), "little")
        self.folderNum = int.from_bytes(f.read(4), "little")
        self.fileNum = int.from_bytes(f.read(4), "little")
        self.pazNum = int.from_bytes(f.read(4), "little")
        self.fileOffset = int.from_bytes(f.read(4), "little")
        self.zsize = int.from_bytes(f.read(4), "little")
        self.size = int.from_bytes(f.read(4), "little")
        self.folderName = ""
        self.fileName = ""


def decode_name(raw: bytes) -> str:
    try:
        return raw.decode("ascii")
    except UnicodeDecodeError:
        try:
            return raw.decode("euc-kr")
        except UnicodeDecodeError:
            return raw.decode("latin-1", errors="replace")


class MetaFile:
    def __init__(self, paz_folder: pathlib.Path, ice: IceDecipher):
        meta_path = paz_folder / "pad00000.meta"
        if not meta_path.exists():
            raise FileNotFoundError(f"Missing {meta_path}")
        with open(meta_path, "rb") as f:
            self._read(f, ice)

    def _read(self, f, ice: IceDecipher):
        f.seek(4)
        paz_count = int.from_bytes(f.read(4), "little")
        f.seek(12 * paz_count, 1)
        expected = int.from_bytes(f.read(4), "little")
        start = f.tell()

        while True:
            if int.from_bytes(f.read(4), "little") == 631490897:
                break
        f.seek(-4, 1)
        middle = f.tell()

        self.fileBlocks = []
        block_end = 0
        f.seek(middle)
        while len(self.fileBlocks) < expected:
            b = FileBlock(f)
            if b.fileNum < 0 or b.fileNum >= expected:
                break
            self.fileBlocks.append(b)
            block_end = f.tell()
        remaining = expected - len(self.fileBlocks)

        if remaining > 0:
            f.seek(middle)
            blocks = []
            while remaining > 0:
                if (f.tell() - 28) < start:
                    break
                f.seek(-28, 1)
                b = FileBlock(f)
                if b.fileNum < 0 or b.fileNum >= expected:
                    break
                blocks.append(b)
                f.seek(-28, 1)
            self.fileBlocks = blocks + self.fileBlocks

        f.seek(block_end)
        length = int.from_bytes(f.read(4), "little")
        decrypted = ice.decrypt(f.read(length))
        folders = self._split_folders(decrypted)
        for b in self.fileBlocks:
            if 0 <= b.folderNum < len(folders):
                b.folderName = folders[b.folderNum]

        enc_len = int.from_bytes(f.read(4), "little")
        names = ice.decrypt(f.read(enc_len)).split(b"\x00")
        for b in self.fileBlocks:
            if 0 <= b.fileNum < len(names):
                b.fileName = decode_name(names[b.fileNum])

        log(f"  Meta blocks: {len(self.fileBlocks)}  folders: {len(folders)}  names: {len(names)}")

    def _split_folders(self, decrypted: bytes):
        folders = []
        offset = 8
        length = len(decrypted)
        while offset < length:
            begin = offset
            while offset < length and decrypted[offset] != 0:
                offset += 1
            s = decrypted[begin:offset] if offset < length else decrypted[begin:]
            folders.append(decode_name(s))
            offset += 9
        return folders


def u32(data: bytes, off: int) -> int:
    return int.from_bytes(data[off : off + 4], "little")


# BDO custom LZ (from bdo-data-extractor internal/paz/lz.go)
_LIT_LEN = [4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0]


def _parse_file_header(data: bytes):
    if data[0] & 0x02:
        return u32(data, 5), u32(data, 1), 9  # decomp, comp, header
    return data[2], data[1], 3


def _parse_block_header(h: int):
    t = h & 0x03
    if t == 0x03:
        if (h & 0x7F) == 3:
            return h >> 15, ((h >> 7) & 0xFF) + 3, 4
        return (h >> 7) & 0x1FFFF, ((h >> 2) & 0x1F) + 2, 3
    if t == 0x02:
        return (h & 0xFFFF) >> 6, ((h >> 2) & 0xF) + 3, 2
    if t == 0x01:
        return (h & 0xFFFF) >> 2, 3, 2
    return (h & 0xFF) >> 2, 3, 1


def bdo_lz_decompress(data: bytes, original_size: int) -> bytes:
    if not data:
        return b""
    flags = data[0]
    target, comp_len, header_size = _parse_file_header(data)
    if len(data) < comp_len:
        comp_len = len(data)
    data = data[:comp_len]
    if flags & 0x01 == 0:
        end = min(header_size + target, len(data))
        return data[header_size:end]
    out = bytearray(target)
    in_idx, out_idx = header_size, 0
    group = 1
    n = len(data)
    while out_idx < target and in_idx < n:
        if group == 1:
            if in_idx + 4 > n:
                break
            group = u32(data, in_idx)
            in_idx += 4
        if group & 1:
            if in_idx + 4 > n:
                break
            h = u32(data, in_idx)
            dist, length, step = _parse_block_header(h)
            in_idx += step
            if out_idx < dist or out_idx + length > target:
                break
            src = out_idx - dist
            for k in range(length):
                out[out_idx + k] = out[src + k]
            out_idx += length
            group >>= 1
        else:
            lit = _LIT_LEN[group & 0xF]
            if out_idx + 4 > target or in_idx + 4 > n:
                break
            out[out_idx : out_idx + 4] = data[in_idx : in_idx + 4]
            out_idx += lit
            in_idx += lit
            group >>= lit
    while out_idx < target:
        if group == 1:
            if in_idx + 4 <= n:
                in_idx += 4
            group = 0x80000000
        if in_idx >= n:
            break
        out[out_idx] = data[in_idx]
        out_idx += 1
        in_idx += 1
        group >>= 1
    return bytes(out[:out_idx])


def extract_block(paz_folder: pathlib.Path, block: FileBlock, ice: IceDecipher | None = None) -> bytes:
    """Match bdo-data-extractor Archive.Content: ICE decrypt + custom LZ as needed."""
    paz_path = paz_folder / f"PAD{block.pazNum:05d}.PAZ"
    if not paz_path.exists():
        paz_path = paz_folder / f"pad{block.pazNum:05d}.paz"
    with open(paz_path, "rb") as f:
        f.seek(block.fileOffset)
        comp = block.zsize if block.zsize > 0 else block.size
        data = f.read(comp)

    if block.zsize == block.size or block.zsize == 0:
        return data

    needs_decrypt = True
    if len(data) % 8 != 0:
        needs_decrypt = False
    elif len(data) >= 4 and data[:4] == b"PABR":
        needs_decrypt = False
    if needs_decrypt and ice is not None:
        data = ice.decrypt(data)

    is_container = (
        len(data) > 9
        and data[0] in (0x6E, 0x6F)
        and u32(data, 5) == block.size
    )
    if is_container:
        return bdo_lz_decompress(data, block.size)
    if block.size <= len(data):
        return data[: block.size]
    return data


_TAG_WITH_BONE = re.compile(rb"<[^<>]*\bBoneName\s*=\s*\"[^\"]+\"[^<>]*>", re.IGNORECASE)
_BONE_ATTR = re.compile(rb"\bBoneName\s*=\s*\"([^\"]+)\"", re.IGNORECASE)
_VECTOR_NUMBER = rb"[+-]?(?:\d+(?:\.\d*)?|\.\d+)"
_VECTOR_VALUE = re.compile(
    rb"\s*" + _VECTOR_NUMBER + rb"\s+" + _VECTOR_NUMBER + rb"\s+" + _VECTOR_NUMBER + rb"\s*"
)


def fmt_vector_component(v: float) -> str:
    """Use the fixed-width numeric convention from Resorepless (4 chars/component)."""
    if not math.isfinite(v):
        raise ValueError("body size values must be finite")
    if -10.0 < v < 0.0:
        text = f"{v:.1f}"
    elif 0.0 <= v < 10.0:
        text = f"{v:.2f}"
    elif 10.0 <= v < 100.0:
        text = f"{v:.1f}"
    else:
        raise ValueError(f"body size value {v} cannot be represented safely")
    if len(text) != 4:
        raise ValueError(f"body size value {v} does not fit the 4-byte game field")
    return text


def fmt_vector(v: float) -> bytes:
    component = fmt_vector_component(v)
    return f"{component} {component} {component}".encode("ascii")


def fmt_vector_for_field(v: float, old_value: bytes) -> bytes:
    """Fit a valid vector to the source field, preserving its exact byte width."""
    vector = fmt_vector(v)
    leading = len(old_value) - len(old_value.lstrip())
    if leading + len(vector) > len(old_value):
        raise ValueError(
            f"body size vector needs {leading + len(vector)} bytes but source field has {len(old_value)}"
        )
    return (b" " * leading) + vector + (b" " * (len(old_value) - leading - len(vector)))


def patch_xml_bytes(raw: bytes, bone_values: dict[str, dict[str, float]]) -> tuple[bytes, int, int]:
    """Patch only complete ParamDesc tags while preserving every other byte and file size."""
    changes = 0
    matched_tags = 0

    def patch_tag(tag_match: re.Match[bytes]) -> bytes:
        nonlocal changes, matched_tags
        tag = tag_match.group(0)
        bone_match = _BONE_ATTR.search(tag)
        if bone_match is None:
            return tag
        try:
            bone = bone_match.group(1).decode("ascii")
        except UnicodeDecodeError:
            return tag
        values = bone_values.get(bone)
        if values is None:
            return tag
        matched_tags += 1
        patched = tag
        for attr, key in ((b"Min", "min"), (b"Default", "default"), (b"Max", "max")):
            attr_pattern = re.compile(rb"(\b" + attr + rb"\s*=\s*\")([^\"]*)(\")", re.IGNORECASE)
            matches = list(attr_pattern.finditer(patched))
            if not matches:
                raise ValueError(f'{bone}: expected a {attr.decode("ascii")} attribute in its tag')
            for attr_match in reversed(matches):
                old_value = attr_match.group(2)
                if _VECTOR_VALUE.fullmatch(old_value) is None:
                    raise ValueError(
                        f'{bone}: {attr.decode("ascii")} is not a three-component numeric vector: {old_value!r}'
                    )
                new_value = fmt_vector_for_field(values[key], old_value)
                patched = patched[: attr_match.start(2)] + new_value + patched[attr_match.end(2) :]
                changes += 1
        return patched

    patched = _TAG_WITH_BONE.sub(patch_tag, raw)
    if len(patched) != len(raw):
        raise ValueError(f"refusing output size change ({len(raw)} -> {len(patched)} bytes)")
    return patched, changes, matched_tags


def build_bone_values(parts: dict[str, dict[str, float]]) -> dict[str, dict[str, float]]:
    bone_values: dict[str, dict[str, float]] = {}
    for part, vals in parts.items():
        if part not in BONE_GROUPS:
            continue
        for bone in BONE_GROUPS[part]:
            bone_values[bone] = vals
    return bone_values


def main() -> int:
    ap = argparse.ArgumentParser(description="Patch BDO customization bone size limits")
    ap.add_argument("--paz", required=True, help="Game PAZ folder")
    ap.add_argument(
        "--out",
        default="",
        help="Output root for files_to_patch (default: <PAZ>/files_to_patch/_body_size_limits)",
    )
    ap.add_argument(
        "--preset",
        choices=list(PRESETS.keys()) + ["custom"],
        default="high",
        help="Preset base values; 'custom' requires --min/--default/--max",
    )
    ap.add_argument("--parts", default="breasts,butt,thighs,legs,pelvis,spine,arms", help="Comma list of body parts")
    ap.add_argument("--min", type=float, default=None)
    ap.add_argument("--default", type=float, default=None)
    ap.add_argument("--max", type=float, default=None)
    ap.add_argument("--list-only", action="store_true", help="Only list matching meta files")
    args = ap.parse_args()

    paz = pathlib.Path(args.paz)
    tool_dir = pathlib.Path(__file__).resolve().parent
    dll = tool_dir / "ice_decipher.dll"
    if not dll.exists():
        log(f"[FATAL] Missing {dll}")
        return 2

    ice = IceDecipher(dll)
    log(f"Reading meta from {paz} ...")
    try:
        meta = MetaFile(paz, ice)
    except FileNotFoundError as e:
        log(f"[FATAL] {e}")
        return 2
    except Exception as e:
        log(f"[FATAL] failed to read meta: {e}")
        return 2

    matches = [
        b
        for b in meta.fileBlocks
        if b.fileName and "customizationboneparamdesc" in b.fileName.lower()
    ]
    log(f"Found {len(matches)} customizationboneparamdesc file(s)")
    for b in matches[:30]:
        log(f"  {b.folderName}/{b.fileName}  paz={b.pazNum} size={b.size}")
    if args.list_only:
        return 0 if matches else 1

    if not matches:
        log("[FATAL] No customizationboneparamdesc files found. Game format may have changed.")
        return 3

    if args.preset == "custom":
        if args.min is None or args.default is None or args.max is None:
            log("[FATAL] --preset custom requires --min, --default, and --max")
            return 4
        base = {"min": args.min, "default": args.default, "max": args.max}
    else:
        base = PRESETS[args.preset].copy()
        if args.min is not None:
            base["min"] = args.min
        if args.default is not None:
            base["default"] = args.default
        if args.max is not None:
            base["max"] = args.max

    if not (base["min"] < base["default"] < base["max"]):
        log("[FATAL] Require min < default < max")
        return 4

    part_names = [p.strip().lower() for p in args.parts.split(",") if p.strip()]
    parts = {p: base.copy() for p in part_names if p in BONE_GROUPS}
    if not parts:
        log("[FATAL] No valid body parts selected")
        return 5

    bone_values = build_bone_values(parts)
    log(f"Applying values min={base['min']} default={base['default']} max={base['max']}")
    log(f"Parts: {', '.join(parts.keys())}")

    out_root = pathlib.Path(args.out) if args.out else (paz / "files_to_patch" / "_body_size_limits")
    total_changes = 0
    written = 0

    for block in matches:
        try:
            raw = extract_block(paz, block, ice)
        except Exception as e:
            log(f"  [SKIP] extract failed {block.fileName}: {e}")
            continue

        if b"bonename" not in raw.lower():
            log(f"  [SKIP] no BoneName in {block.fileName} head={raw[:40]!r}")
            continue
        try:
            patched, n, tag_count = patch_xml_bytes(raw, bone_values)
        except ValueError as e:
            log(f"  [FATAL] unsafe source {block.fileName}: {e}")
            return 6
        if n == 0 or tag_count == 0:
            log(f"  [SKIP] no selected body bones in {block.fileName}")
            continue
        if n < tag_count * 3:
            log(f"  [FATAL] validation mismatch in {block.fileName}: tags={tag_count} edits={n}")
            return 6
        total_changes += n

        rel = pathlib.Path(block.folderName) / block.fileName
        dest = out_root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(patched)
        written += 1
        log(f"  wrote {rel}  ({tag_count} vector tags, {n} attribute edits, {len(patched)} bytes preserved)")

    log(f"Done. files={written} attribute_edits={total_changes}")
    log(f"Output: {out_root}")
    log("Next: run PartCutGen if needed, then Meta Injector. Re-create or beauty-edit character to see size limits.")
    return 0 if written else 6


if __name__ == "__main__":
    sys.exit(main())
