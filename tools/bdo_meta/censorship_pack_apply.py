#!/usr/bin/env python3
"""
Apply Resorepless-style censorship-removal texture packs + expanded live-PAZ scan.

Tiers:
  off      - do nothing
  minimal  - panties under some tamer/ranger armors (3 files)
  medium   - + upper undercovers / more armor decals (legacy list)
  high     - same textures as medium
  expanded - legacy medium + BEST-EFFORT blank of under-armor / decal textures
             found in live PAZ for ALL classes (including new outfits). Requires --paz.

Expanded matches character/texture names that look like built-in underwear paint
(decals, under-layers, cull masks). Blanks keep exact original file size for inject.
"""
from __future__ import annotations

import argparse
import pathlib
import shutil
import sys

from body_size_patcher import IceDecipher, MetaFile, extract_block

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
    "pbw_00_ub_0054_dm.dds",
    "pew_02_lb_0001.dds",
]

# Name tokens that usually mean painted-on underwear / under-layer censorship.
# Keep this fairly tight: blanking every "*_dec*" would also kill normal outfit logos.
EXPAND_NAME_ANY = (
    "underup",
    "_under_",
    "underwear",
    "_uw_",  # rare as texture under character/texture
    "_cull",  # classic Resorepless cull under-layer maps
    # decals that look like under-armor paint (class + lb/ub + dec)
    "_lb_",
    "_ub_",
)
EXPAND_NAME_SKIP = (
    "_n.dds",
    "_sp.dds",
    "_m.dds",
    "_ao.dds",
    "_w.dds",
)


def log(m: str) -> None:
    print(m, flush=True)


def blank_keep_size(original: bytes) -> bytes:
    """Zero image payload after DDS header; keep exact size for Meta Injector."""
    if len(original) < 128:
        return bytes(len(original))  # tiny stubs already blank-ish
    # DDS magic
    if original[:4] == b"DDS ":
        header_len = 128
        # DX10 extended header
        if len(original) >= 148 and original[84:88] == b"DX10":
            header_len = 148
        return original[:header_len] + bytes(len(original) - header_len)
    # unknown format — full zero of same size
    return bytes(len(original))


def is_expand_candidate(folder: str, name: str) -> bool:
    folder_l = folder.replace("\\", "/").lower()
    name_l = name.lower()
    if not name_l.endswith(".dds"):
        return False
    if "character/texture" not in folder_l:
        if not folder_l.endswith("texture") and "/texture" not in folder_l:
            return False
    # skip Shai
    if name_l.startswith("plw_"):
        return False
    # skip pure maps
    if any(name_l.endswith(s) for s in EXPAND_NAME_SKIP):
        return False
    # under-layer / underwear texture names
    if any(t in name_l for t in ("underup", "_under_", "underwear", "_uw_")):
        return True
    if "_cull" in name_l and ("_lb_" in name_l or "_ub_" in name_l or "_sho_" in name_l):
        return True
    # lower/upper body *dec* (classic panty/underpaint decals) — not cloak/logo-only random dec
    if "_dec" in name_l and ("_lb_" in name_l or "_ub_" in name_l or "under" in name_l):
        return True
    return False


def copy_legacy(pack: pathlib.Path, tex_out: pathlib.Path, names: list[str]) -> tuple[int, int]:
    ok = miss = 0
    for name in names:
        src = pack / name
        if not src.is_file():
            hits = list(pack.glob(name))
            if not hits:
                log(f"  [MISS legacy] {name}")
                miss += 1
                continue
            src = hits[0]
        shutil.copy2(src, tex_out / src.name)
        ok += 1
        log(f"  [LEGACY] {src.name}")
    return ok, miss


def expand_from_paz(
    paz: pathlib.Path, tex_out: pathlib.Path, dll: pathlib.Path
) -> tuple[int, int]:
    ice = IceDecipher(dll)
    log(f"Scanning live PAZ for under-armor / decal textures: {paz}")
    meta = MetaFile(paz, ice)
    ok = skip = 0
    seen: set[str] = set()
    for block in meta.fileBlocks:
        folder = block.folderName or ""
        name = block.fileName or ""
        if not is_expand_candidate(folder, name):
            continue
        key = name.lower()
        if key in seen:
            continue
        seen.add(key)
        dest = tex_out / name
        # prefer exact-size blank over re-extract when legacy already wrote
        if dest.is_file() and dest.stat().st_size == block.size:
            log(f"  [SKIP already] {name}")
            skip += 1
            continue
        try:
            data = extract_block(paz, block, ice)
            if not data:
                # fall back: zero buffer of meta size
                blank = bytes(block.size if block.size > 0 else 176)
            else:
                # pad/truncate to declared size
                if block.size > 0:
                    if len(data) < block.size:
                        data = data + bytes(block.size - len(data))
                    elif len(data) > block.size:
                        data = data[: block.size]
                blank = blank_keep_size(data)
                if block.size > 0 and len(blank) != block.size:
                    blank = blank[: block.size] if len(blank) > block.size else blank + bytes(block.size - len(blank))
            dest.write_bytes(blank)
            ok += 1
            log(f"  [EXPAND] {name} ({len(blank)} bytes)")
        except Exception as e:
            log(f"  [FAIL expand] {name}: {e}")
            skip += 1
    return ok, skip


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--tier",
        required=True,
        choices=["off", "minimal", "medium", "high", "expanded"],
    )
    ap.add_argument("--pack-root", required=True, help="Folder with censorship DDS files")
    ap.add_argument("--out", required=True, help="files_to_patch/_censorship_<tier>")
    ap.add_argument("--paz", default="", help="Live PAZ folder (required for expanded tier)")
    args = ap.parse_args()

    if args.tier == "off":
        log("Tier off — nothing to write.")
        return 0

    pack = pathlib.Path(args.pack_root)
    out = pathlib.Path(args.out)
    if out.exists():
        shutil.rmtree(out)
    tex = out / "character" / "texture"
    tex.mkdir(parents=True)

    ok = miss = 0
    expand_ok = expand_skip = 0

    if args.tier == "minimal":
        ok, miss = copy_legacy(pack, tex, MINIMAL_FILES)
    elif args.tier in ("medium", "high"):
        ok, miss = copy_legacy(pack, tex, MEDIUM_HIGH_FILES)
    else:  # expanded
        ok, miss = copy_legacy(pack, tex, MEDIUM_HIGH_FILES)
        if not args.paz:
            log("[FATAL] --paz required for expanded tier")
            return 2
        paz = pathlib.Path(args.paz)
        dll = pathlib.Path(__file__).resolve().parent / "ice_decipher.dll"
        if not dll.is_file():
            log(f"[FATAL] missing {dll}")
            return 3
        expand_ok, expand_skip = expand_from_paz(paz, tex, dll)

    (out / "README.txt").write_text(
        f"Censorship removal tier: {args.tier}\n"
        f"Legacy textures copied: {ok}  missing: {miss}\n"
        f"Expanded blanks: {expand_ok}  skip/fail: {expand_skip}\n"
        "LEGACY = classic Resorepless outfit textures (old classes best).\n"
        "EXPANDED = live PAZ scan for *_dec* / under* / cull under-armor maps (all classes).\n"
        "Combine with Midnight armor/underwear hide. Not perfect on every pearl outfit.\n"
        "Run Meta Injector after placing under files_to_patch.\n",
        encoding="utf-8",
    )
    log(f"Done. legacy_ok={ok} expand_ok={expand_ok} out={out}")
    total = ok + expand_ok
    return 0 if total else 1


if __name__ == "__main__":
    sys.exit(main())
