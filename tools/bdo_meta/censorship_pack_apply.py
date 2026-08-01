#!/usr/bin/env python3
"""
Apply Resorepless-style censorship-removal texture packs.

Tiers:
  off     - do nothing
  minimal - panties under some tamer/ranger armors (3 files)
  medium  - + upper undercovers / more armor decals (full censorship list)
  high    - same textures as medium (model pants hide is covered by Midnight armor hide)
"""
from __future__ import annotations

import argparse
import pathlib
import shutil
import sys

# From Resorepless global.c censorshipTextureFiles + minimal set
MINIMAL_FILES = [
    "pbw_00_lb_0018.dds",
    "pbw_00_ub_0054.dds",
    "pbw_00_ub_0054_dec.dds",
]

MEDIUM_HIGH_FILES = [
    "pnw_00_ub_0001_dec.dds",
    "pdw_00_lb_0001_dec.dds",
    "pdw_03_lb_0001.dds",
    "pdw_03_lb_0001_dm.dds",
    "pdw_03_ub_0001.dds",
    "pdw_03_ub_0001_dm.dds",
    "pdw_02_ub_0006.dds",
    "pdw_02_ub_0006_dm.dds",
    "pdw_02_lb_0006.dds",
    "pdw_02_lb_0006_dm.dds",
    "pdw_02_lb_0002_dec.dds",
    "pdw_02_lb_0002_dec_dm.dds",
    "pdw_00_sho_0002_cull.dds",
    "pdw_00_underup_0002.dds",
    "pdw_00_underup_0002_dec.dds",
    "pdw_02_sho_0004.dds",
    "pdw_02_sho_0004_dm.dds",
    "pdw_02_lb_0005.dds",
    "pdw_02_lb_0005_dm.dds",
    "pnw_00_lb_0002_dec.dds",
    "pbw_00_ub_0054.dds",
    "pbw_00_ub_0054_dec.dds",
    "pew_00_lb_0033_dec.dds",
    "pbw_00_lb_0018.dds",
    "pdw_00_cloak_0002_dec.dds",
    # extras present in folder
    "pbw_00_ub_0054_dm.dds",
    "pew_02_lb_0001.dds",
]


def log(m: str) -> None:
    print(m, flush=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tier", required=True, choices=["off", "minimal", "medium", "high"])
    ap.add_argument("--pack-root", required=True, help="Folder with censorship DDS files")
    ap.add_argument("--out", required=True, help="files_to_patch/_censorship_<tier>")
    args = ap.parse_args()

    if args.tier == "off":
        log("Tier off — nothing to write.")
        return 0

    pack = pathlib.Path(args.pack_root)
    out = pathlib.Path(args.out)
    tex = out / "character" / "texture"
    tex.mkdir(parents=True, exist_ok=True)

    if args.tier == "minimal":
        names = MINIMAL_FILES
    else:
        names = MEDIUM_HIGH_FILES

    ok = 0
    miss = 0
    for name in names:
        src = pack / name
        if not src.is_file():
            # try case-insensitive
            hits = list(pack.glob(name))
            if not hits:
                log(f"  [MISS] {name}")
                miss += 1
                continue
            src = hits[0]
        shutil.copy2(src, tex / src.name)
        ok += 1
        log(f"  [OK] {src.name}")

    (out / "README.txt").write_text(
        f"Censorship removal tier: {args.tier}\n"
        f"Textures copied: {ok}\n"
        f"Missing: {miss}\n"
        "LEGACY Resorepless pack — best on older outfits (Tamer/Ranger/DK etc.).\n"
        "Combine with Midnight armor/underwear hide for modern classes.\n"
        "Run Meta Injector after placing under files_to_patch.\n",
        encoding="utf-8",
    )
    log(f"Done. ok={ok} miss={miss} out={out}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
