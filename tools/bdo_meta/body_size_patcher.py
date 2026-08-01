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


def fmt_num(v: float) -> str:
    # keep compact float similar to game XML
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    if "." not in s:
        s += ".0"
    return s


def patch_xml_text(text: str, bone_values: dict[str, dict[str, float]]) -> tuple[str, int]:
    """
    Patch Min/Default/Max that precede each BoneName in customizationboneparamdesc style XML.
    Strategy: for each BoneName="X", find the nearest preceding Min/Default/Max attributes in the same element-ish window.
    """
    changes = 0
    # Match blocks that contain BoneName="..."
    # Work line-oriented + window: many BDO files are one long line; use regex on full text.

    def repl_bone(match: re.Match) -> str:
        nonlocal changes
        chunk = match.group(0)
        bone = match.group(1)
        if bone not in bone_values:
            return chunk
        vals = bone_values[bone]

        def set_attr(src: str, attr: str, value: float) -> str:
            nonlocal changes
            pat = re.compile(rf'({attr}\s*=\s*")([^"]*)(")', re.IGNORECASE)

            def r(m):
                nonlocal changes
                changes += 1
                return m.group(1) + fmt_num(value) + m.group(3)

            new_src, n = pat.subn(r, src, count=1)
            return new_src if n else src

        # Only rewrite Min/Default/Max that appear BEFORE BoneName in this chunk
        # Split at BoneName
        pre, post = chunk.rsplit(f'BoneName="{bone}"', 1)
        pre = set_attr(pre, "Min", vals["min"])
        pre = set_attr(pre, "Default", vals["default"])
        pre = set_attr(pre, "Max", vals["max"])
        return pre + f'BoneName="{bone}"' + post

    # Each "element" often looks like ... Min=".." Default=".." Max=".." ... BoneName=".."
    pattern = re.compile(
        r'(?:Min\s*=\s*"[^"]*"\s*)?(?:Default\s*=\s*"[^"]*"\s*)?(?:Max\s*=\s*"[^"]*"\s*)?'
        r'(?:[^>]{0,400}?)BoneName\s*=\s*"([^"]+)"',
        re.IGNORECASE | re.DOTALL,
    )
    # Simpler robust approach: for each target bone, find BoneName="bone" and search backward for attrs
    out = text
    for bone, vals in bone_values.items():
        # find all occurrences
        idx = 0
        while True:
            m = re.search(rf'BoneName\s*=\s*"{re.escape(bone)}"', out[idx:], re.IGNORECASE)
            if not m:
                break
            abs_start = idx + m.start()
            # look back up to 800 chars for Min/Default/Max
            window_start = max(0, abs_start - 800)
            window = out[window_start:abs_start]
            new_window = window

            def replace_last(attr: str, value: float, src: str) -> str:
                nonlocal changes
                matches = list(re.finditer(rf'{attr}\s*=\s*"[^"]*"', src, re.IGNORECASE))
                if not matches:
                    return src
                last = matches[-1]
                changes += 1
                return src[: last.start()] + f'{attr}="{fmt_num(value)}"' + src[last.end() :]

            # preserve original attribute casing by reading match text
            for attr_key, val_key in (("Min", "min"), ("Default", "default"), ("Max", "max")):
                matches = list(re.finditer(rf'({attr_key})\s*=\s*"[^"]*"', new_window, re.IGNORECASE))
                if matches:
                    last = matches[-1]
                    attr_name = last.group(1)
                    new_window = (
                        new_window[: last.start()]
                        + f'{attr_name}="{fmt_num(vals[val_key])}"'
                        + new_window[last.end() :]
                    )
                    changes += 1

            out = out[:window_start] + new_window + out[abs_start:]
            idx = window_start + len(new_window) + len(m.group(0))

    return out, changes


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
    ap.add_argument("--preset", choices=list(PRESETS.keys()), default="high")
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
    meta = MetaFile(paz, ice)

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

        text = None
        for enc in ("utf-8", "utf-16", "utf-16-le", "cp949", "latin-1"):
            try:
                cand = raw.decode(enc)
                if "BoneName" in cand or "bonename" in cand.lower():
                    text = cand
                    break
                if text is None and ("Min" in cand or "<?xml" in cand or "<!--" in cand):
                    text = cand
            except Exception:
                pass
        if text is None:
            log(f"  [SKIP] cannot decode {block.fileName} (len={len(raw)})")
            continue

        if "BoneName" not in text and "bonename" not in text.lower():
            log(f"  [SKIP] no BoneName in {block.fileName} head={raw[:40]!r}")
            continue

        patched, n = patch_xml_text(text, bone_values)
        if n == 0:
            log(f"  [WARN] 0 attribute writes in {block.fileName}")
        total_changes += n

        rel = pathlib.Path(block.folderName) / block.fileName
        dest = out_root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        # write utf-8 without BOM (game often accepts; if original was utf-16 we still try utf-8 first)
        dest.write_bytes(patched.encode("utf-8"))
        written += 1
        log(f"  wrote {rel}  ({n} edits)")

    log(f"Done. files={written} attribute_edits={total_changes}")
    log(f"Output: {out_root}")
    log("Next: run PartCutGen if needed, then Meta Injector. Re-create or beauty-edit character to see size limits.")
    return 0 if written else 6


if __name__ == "__main__":
    sys.exit(main())
