#!/usr/bin/env python3
"""
BDO character-creation body size limit patcher (Resorepless-style).

Extracts *customizationboneparamdesc* files from live PAZ (via pad00000.meta + ice_decipher),
raises Min/Default/Max for body bones, writes into files_to_patch for Meta Injector.

Three rules, all derived from the live game data (see PART_NOTES below):

1. Never write Default. Vanilla Default is per-class and anisotropic
   (e.g. Calf "1.10 0.88 1.00"); overwriting it with one uniform number
   rewrites the class's authored proportions and stretches bodies.
2. Never touch a bone's HeightAxis component. The game declares it per tag
   (HeightAxis="X" on Thigh/Calf/Pelvis/Spine/arms; Hip and Breast have none).
   That axis is bone length -- raising it makes limbs and torsos longer.
3. Only ever widen. A component is raised toward the requested max and never
   lowered below what the game already allowed.
"""
from __future__ import annotations

import argparse
import ctypes
import math
import pathlib
import re
import sys

# Only girth-meaningful groups are supported. Length/height groups (legs, spine,
# arms) were dropped in 2.1.0: their sliders scale bone length, which produced
# absurd proportions, and they are children of Pelvis so they already inherit
# its scale.
#
# butt == hip + pelvis on purpose. Measured on the live client (75 body files):
# 33 of them lock Bip01 L/R Hip Max to <= 1.00 -- the butt slider physically
# cannot move on those classes -- and in all 33 the Pelvis still has headroom.
# Patching Hip alone therefore does nothing for ~44% of classes, which matches
# the long-standing community reports that the butt slider is dead on newer
# classes. Pelvis is the bone that actually carries the shape.
BONE_GROUPS = {
    "breasts": ["Bip01 L Breast", "Bip01 R Breast"],
    "thighs": ["Bip01 L Thigh", "Bip01 R Thigh"],
    "butt": ["Bip01 L Hip", "Bip01 R Hip", "Bip01 Pelvis"],
}

# Old config values that used to be separate groups.
PART_ALIASES = {
    "pelvis": "butt",
    "ass": "butt",
    "hips": "butt",
    "hip": "butt",
    "breast": "breasts",
    "thigh": "thighs",
}

# Removed in 2.1.0 -- accepted from old configs, reported, then ignored.
RETIRED_PARTS = ("legs", "spine", "arms")

# Per-part MAX CEILINGS only (widen Max=; never write Default/Min).
#
# Live vanilla Max is NOT one number for every part (restored NA client scan):
#   breasts ~1.25 | thighs peak ~1.10-1.15 | hips ~1.00 or 1.10 | pelvis ~1.20
# "vanilla" preset ≈ those stock ceilings (1.25 / 1.15 / 1.10). Widen-only.
# recommended = user no-clip unlock. high/extreme may clip outfits (client-only).
PRESETS = {
    "vanilla": {"breasts": 1.25, "thighs": 1.15, "butt": 1.10},
    "recommended": {"breasts": 1.37, "thighs": 1.30, "butt": 1.18},
    "high": {"breasts": 1.65, "thighs": 1.40, "butt": 1.19},
    "extreme": {"breasts": 2.00, "thighs": 1.45, "butt": 1.20},
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
_HEIGHT_AXIS_ATTR = re.compile(rb"\bHeightAxis\s*=\s*\"([^\"]*)\"", re.IGNORECASE)
_VECTOR_NUMBER = rb"[+-]?(?:\d+(?:\.\d*)?|\.\d+)"
_VECTOR_VALUE = re.compile(
    rb"\s*" + _VECTOR_NUMBER + rb"\s+" + _VECTOR_NUMBER + rb"\s+" + _VECTOR_NUMBER + rb"\s*"
)

_AXIS_INDEX = {"X": 0, "Y": 1, "Z": 2}


def height_axis_index(tag: bytes) -> int | None:
    """Component index the game marks as bone length, or None if the bone has no length axis.

    The game states this per ParamDesc: HeightAxis="X" on Thigh/Calf/Pelvis/Spine/
    UpperArm/Forearm, and an absent-or-empty HeightAxis on Hip and Breast.
    Never guess it -- a wrong axis is what stretches a character instead of
    thickening it.
    """
    match = _HEIGHT_AXIS_ATTR.search(tag)
    if match is None:
        return None
    return _AXIS_INDEX.get(match.group(1).strip().upper().decode("ascii", "replace"))


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


def fit_field(new_text: str, old_value: bytes) -> bytes:
    """Fit a rebuilt vector into the source field, preserving its exact byte width."""
    vector = new_text.encode("ascii")
    leading = len(old_value) - len(old_value.lstrip())
    if leading + len(vector) > len(old_value):
        raise ValueError(
            f"body size vector needs {leading + len(vector)} bytes but source field has {len(old_value)}"
        )
    return (b" " * leading) + vector + (b" " * (len(old_value) - leading - len(vector)))


def fmt_vector_for_field(v: float, old_value: bytes) -> bytes:
    """Fit a uniform vector to the source field, preserving its exact byte width."""
    return fit_field(fmt_vector(v).decode("ascii"), old_value)


def widen_vector(old_value: bytes, limit: float, skip_index: int | None, raise_it: bool) -> bytes | None:
    """Widen the girth components of one Min/Max vector; return None if nothing changed.

    skip_index is the game-declared HeightAxis component, which is left exactly as
    the game shipped it. Components already past the limit are left alone too, so
    the patch can only ever widen a class's existing range.
    """
    components = old_value.split()
    if len(components) != 3:
        raise ValueError(f"expected a three-component vector, got {old_value!r}")

    out: list[str] = []
    changed = False
    for index, raw_component in enumerate(components):
        text = raw_component.decode("ascii")
        if index == skip_index:
            out.append(text)
            continue
        current = float(text)
        if (limit > current) if raise_it else (limit < current):
            out.append(fmt_vector_component(limit))
            changed = True
        else:
            out.append(text)

    if not changed:
        return None
    return fit_field(" ".join(out), old_value)


def patch_xml_bytes(raw: bytes, bone_values: dict[str, dict[str, float]]) -> tuple[bytes, int, int]:
    """Patch only complete ParamDesc tags while preserving every other byte and file size.

    Default is deliberately never written -- see the module docstring.
    """
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
        skip_index = height_axis_index(tag)
        patched = tag
        for attr, key, raise_it in ((b"Min", "min", False), (b"Max", "max", True)):
            limit = values.get(key)
            if limit is None:
                continue
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
                new_value = widen_vector(old_value, limit, skip_index, raise_it)
                if new_value is None:
                    continue
                patched = patched[: attr_match.start(2)] + new_value + patched[attr_match.end(2) :]
                changes += 1
        return patched

    patched = _TAG_WITH_BONE.sub(patch_tag, raw)
    if len(patched) != len(raw):
        raise ValueError(f"refusing output size change ({len(raw)} -> {len(patched)} bytes)")
    return patched, changes, matched_tags


def resolve_part(name: str) -> str | None:
    """Map a user/config part name onto a supported group, or None if unsupported."""
    name = name.strip().lower()
    name = PART_ALIASES.get(name, name)
    return name if name in BONE_GROUPS else None


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
        choices=list(PRESETS.keys()),
        default="recommended",
        help="Per-part max values; override any part with --parts name:max",
    )
    ap.add_argument(
        "--parts",
        default="breasts,thighs,butt",
        help="Comma list of breasts,thighs,butt -- each optionally as name:max (e.g. breasts:2.0)",
    )
    ap.add_argument("--min", type=float, default=None, help="Optional lower bound to widen down to (default: leave vanilla Min alone)")
    ap.add_argument("--max", type=float, default=None, help="Max for every selected part that has no name:max override")
    ap.add_argument("--default", type=float, default=None, help=argparse.SUPPRESS)
    ap.add_argument("--list-only", action="store_true", help="Only list matching meta files")
    args = ap.parse_args()

    if args.default is not None:
        log("[WARN] --default is ignored since 2.1.0: the game's per-class Default is left untouched.")

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

    preset_max = PRESETS[args.preset]
    parts: dict[str, dict[str, float]] = {}
    retired: list[str] = []
    unknown: list[str] = []

    for token in args.parts.split(","):
        token = token.strip()
        if not token:
            continue
        name, _, override = token.partition(":")
        part = resolve_part(name)
        if part is None:
            (retired if name.strip().lower() in RETIRED_PARTS else unknown).append(name.strip())
            continue
        if override.strip():
            try:
                limit = float(override)
            except ValueError:
                log(f"[FATAL] {name}: '{override}' is not a number")
                return 4
        else:
            limit = args.max if args.max is not None else preset_max[part]
        # Merge rather than overwrite: 'butt' and the old 'pelvis' can both appear.
        current = parts.setdefault(part, {"max": limit})
        current["max"] = max(current["max"], limit)
        if args.min is not None:
            current["min"] = args.min

    if retired:
        log(f"[NOTE] Dropped in 2.1.0 (scaled bone length, not girth): {', '.join(sorted(set(retired)))}")
    if unknown:
        log(f"[WARN] Unknown parts ignored: {', '.join(sorted(set(unknown)))}")
    if not parts:
        log(f"[FATAL] No supported body parts selected. Supported: {', '.join(BONE_GROUPS)}")
        return 5

    for part, vals in parts.items():
        if not (1.0 <= vals["max"] <= 99.0):
            log(f"[FATAL] {part}: max {vals['max']} must be between 1.0 and 99.0")
            return 4
        if args.min is not None and not (0.01 <= args.min <= 1.0):
            log(f"[FATAL] min {args.min} must be between 0.01 and 1.0")
            return 4

    bone_values = build_bone_values(parts)
    log("Applying (Default untouched, HeightAxis untouched, widen-only):")
    for part, vals in parts.items():
        bound = f" min={vals['min']}" if "min" in vals else ""
        log(f"  {part:8s} max={vals['max']}{bound}  bones: {', '.join(BONE_GROUPS[part])}")

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
        if tag_count == 0:
            log(f"  [SKIP] no selected body bones in {block.fileName}")
            continue
        if n == 0:
            log(f"  [SKIP] {block.fileName}: {tag_count} bone tags already allow the requested range")
            continue
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
