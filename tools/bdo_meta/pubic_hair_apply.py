#!/usr/bin/env python3
"""
Apply Resorepless-style pubic hair overlays onto nude body DDS textures.

Method (from Resorepless reconstructDDS):
  - start from a base nude .dds (from Midnight pack or files_to_patch)
  - patch byte ranges from style .bin using offsets.bin

LEGACY: best on older female nude textures that match bin names
(pbw/pdw/pew/phw/pww ...). New classes without matching bins are skipped.
"""
from __future__ import annotations

import argparse
import pathlib
import shutil
import struct
import sys

STYLES = [
    "shaved",
    "shaved_innie",
    "full_bush",
    "full_bush_2",
    "full_bush_3",
    "medium_bush",
    "medium_bush2",
    "small_bush",
    "small_bush_2",
    "thin_landing_strip",
    "wide_landing_strip",
    "trimmed",
    "wider_trimmed",
]


def log(msg: str) -> None:
    print(msg, flush=True)


def load_offsets(path: pathlib.Path) -> list[tuple[int, int]]:
    """PubicHairOffset is two ints (value=offset, length) little-endian."""
    data = path.read_bytes()
    # try 8-byte pairs (int,int)
    out = []
    if len(data) % 8 == 0 and len(data) > 0:
        for i in range(0, len(data), 8):
            off, length = struct.unpack_from("<ii", data, i)
            if off < 0 or length <= 0:
                continue
            out.append((off, length))
        if out:
            return out
    # fallback 8-byte uint
    out = []
    for i in range(0, len(data) - 7, 8):
        off, length = struct.unpack_from("<II", data, i)
        if length == 0 or length > 10_000_000:
            continue
        out.append((int(off), int(length)))
    return out


def apply_bin_to_dds(dds_path: pathlib.Path, bin_path: pathlib.Path, offsets: list[tuple[int, int]], dest: pathlib.Path) -> bool:
    dds = bytearray(dds_path.read_bytes())
    blob = bin_path.read_bytes()
    bi = 0
    for off, length in offsets:
        if off + length > len(dds):
            return False
        if bi + length > len(blob):
            return False
        dds[off : off + length] = blob[bi : bi + length]
        bi += length
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(dds)
    return True


def find_base_dds(roots: list[pathlib.Path], name: str) -> pathlib.Path | None:
    for root in roots:
        if not root.exists():
            continue
        # direct
        p = root / name
        if p.is_file():
            return p
        # recursive
        hits = list(root.rglob(name))
        if hits:
            return hits[0]
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", required=True, choices=STYLES)
    ap.add_argument("--hair-root", required=True, help="Folder containing style subdirs + offsets.bin")
    ap.add_argument(
        "--base-roots",
        required=True,
        help="Semicolon-separated folders to find base nude DDS (Midnight pack paths)",
    )
    ap.add_argument("--out", required=True, help="Output folder (files_to_patch/_pubic_hair/<style>)")
    args = ap.parse_args()

    hair_root = pathlib.Path(args.hair_root)
    style_dir = hair_root / args.style
    offsets_path = hair_root / "offsets.bin"
    if not style_dir.is_dir():
        log(f"[FATAL] missing style folder: {style_dir}")
        return 2
    if not offsets_path.is_file():
        log(f"[FATAL] missing {offsets_path}")
        return 3

    offsets = load_offsets(offsets_path)
    if not offsets:
        log("[FATAL] could not parse offsets.bin")
        return 4
    log(f"Loaded {len(offsets)} patch ranges from offsets.bin")

    base_roots = [pathlib.Path(p) for p in args.base_roots.split(";") if p.strip()]
    out_dir = pathlib.Path(args.out)
    out_tex = out_dir / "character" / "texture"
    out_tex.mkdir(parents=True, exist_ok=True)

    bins = list(style_dir.glob("*.bin"))
    if not bins:
        log(f"[FATAL] no .bin in {style_dir}")
        return 5

    ok = 0
    skip = 0
    for b in bins:
        # pbw_00_nude_0001.bin -> pbw_00_nude_0001.dds
        dds_name = b.stem + ".dds"
        base = find_base_dds(base_roots, dds_name)
        if base is None:
            log(f"  [SKIP] no base DDS for {dds_name}")
            skip += 1
            continue
        dest = out_tex / dds_name
        if apply_bin_to_dds(base, b, offsets, dest):
            log(f"  [OK] {dds_name}  (from {base})")
            ok += 1
        else:
            log(f"  [FAIL] merge {dds_name} (size mismatch — base texture may be different resolution)")
            skip += 1

    # also copy any full DDS already in style folder
    for dds in style_dir.glob("*.dds"):
        dest = out_tex / dds.name
        shutil.copy2(dds, dest)
        log(f"  [COPY] {dds.name}")
        ok += 1

    readme = out_dir / "README.txt"
    readme.write_text(
        f"Pubic hair style: {args.style}\n"
        f"Applied textures: {ok}\n"
        f"Skipped: {skip}\n"
        "LEGACY: only textures that match old Resorepless bin names.\n"
        "Put under files_to_patch and run Meta Injector. Use with nude body mod.\n",
        encoding="utf-8",
    )
    log(f"Done. ok={ok} skip={skip} out={out_dir}")
    return 0 if ok > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
