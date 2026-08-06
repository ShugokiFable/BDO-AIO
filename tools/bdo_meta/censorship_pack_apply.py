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

Expanded matches exact character/texture entries that look like built-in underwear
paint (decals, under-layers). Geometry clip masks (*_cull*) are never blanked —
zeroing them culls the whole body under the garment. Blanks keep the original file size.

Every tier is gated by legacy_reject_reason(). The Resorepless pack is a ~2018
artifact and most of its files no longer describe the live texture they would
replace; copying one anyway does not remove censorship, it destroys the map the
body renders through. On a 2026 client medium/high emit about 2 of 27 files.

This tool never installs a nude body -- that is Midnight (Suzu / TheGreatSage) and
the genital packs. Censorship removal only swaps textures, so a wrong map produces
a hole, never bare skin.
"""
from __future__ import annotations

import argparse
import pathlib
import struct
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

# Never blanked, whatever else the name matches.
#
# "*_cull*" is a geometry clip mask, not painted-on censorship. blank_keep_size
# holds the declared size but a zeroed DXT1 payload decodes to solid black, and a
# black clip mask culls the entire body region under the garment -- the body
# renders with a hole while separately-materialled pieces (boots) stay put. This
# is what broke Ranger set 0274 in 2.1.3. Cull maps that genuinely need changing
# are hand-authored images shipped through MEDIUM_HIGH_FILES.
EXPAND_NAME_NEVER = ("_cull",)

# Adult-only safety boundary. These names are never emitted by this tool even if
# a loose texture token happens to match them.
AGE_AMBIGUOUS_NAME_TOKENS = ("child", "kid", "shai", "#na#")


def log(m: str) -> None:
    print(m, flush=True)


def blank_keep_size(original: bytes) -> bytes:
    """Zero image payload after DDS header; keep exact size for Meta Injector."""
    if len(original) < 128:
        raise ValueError("archive content is not a valid DDS payload")
    # DDS magic
    if original[:4] == b"DDS ":
        header_len = 128
        # DX10 extended header
        if len(original) >= 148 and original[84:88] == b"DX10":
            header_len = 148
        return original[:header_len] + bytes(len(original) - header_len)
    # unknown format — full zero of same size
    raise ValueError("archive content is not a valid DDS payload")


# DXT1 IS NEVER TOUCHED. Measured twice on the live client, both times meshes broke:
#
#   1. Zeroing a DXT1 block leaves color0 == color1 == 0 at index 0, which decodes to
#      OPAQUE BLACK -- it paints over the body instead of revealing it.
#   2. BC1 does have a transparent encoding (color0 <= color1 puts the block in
#      3-colour mode where index 3 is transparent; `00 00 01 00 FF FF FF FF`, exactly
#      what the 2018 Resorepless pack shipped in its stubs). Writing that at the live
#      size still broke meshes -- first across all 157 DXT1 maps in the scan, then
#      again with only the pack's 15 hand-picked names.
#
# So the block was right and the idea was still wrong: transparency only removes a
# painted layer when the shader treats the map as an overlay. BDO uses DXT1 for base
# diffuse maps, and an alpha-tested base map that is fully transparent discards the
# whole mesh. Only alpha-carrying formats can be blanked safely.


def transparent_payload(data: bytes) -> tuple[bytes | None, str]:
    """Return (same-size DDS that decodes to fully transparent, note).

    (None, reason) when the pixel format cannot be blanked safely.
    """
    if data[:4] != b"DDS ":
        return None, "not a DDS payload"
    header_len = 148 if len(data) >= 148 and data[84:88] == b"DX10" else 128
    if len(data) < header_len:
        return None, "truncated DDS header"
    head, body = data[:header_len], data[header_len:]
    pf_flags = struct.unpack_from("<I", data, 80)[0]
    if pf_flags & 0x4:  # DDPF_FOURCC
        fourcc = data[84:88]
        if fourcc in (b"DXT3", b"DXT5"):
            # 16-byte blocks. A zeroed alpha block gives alpha0 = alpha1 = 0 and every
            # index 0, i.e. alpha 0 across the block.
            return head + bytes(len(body)), "DXT5/DXT3 alpha zeroed"
        if fourcc == b"DXT1":
            return None, "DXT1 base map -- blanking it discards the mesh (measured twice)"
        return None, f"{fourcc.decode('ascii', 'replace')} has no transparent encoding"
    if pf_flags & 0x1:  # DDPF_ALPHAPIXELS, uncompressed
        return head + bytes(len(body)), "uncompressed alpha zeroed"
    return None, "uncompressed without an alpha channel"


def decode_archive_dds(data: bytes, ice: IceDecipher) -> bytes:
    """Handle stored DDS entries that remain ICE-encrypted in the PAZ."""
    if data[:4] == b"DDS ":
        return data
    if data and len(data) % 8 == 0:
        decrypted = ice.decrypt(data)
        if decrypted[:4] == b"DDS ":
            return decrypted
    raise ValueError("live archive entry did not decode to DDS")


def is_expand_candidate(folder: str, name: str) -> bool:
    folder_l = folder.replace("\\", "/").strip("/").lower()
    name_l = name.lower()
    if not name_l.endswith(".dds"):
        return False
    # Meta Injector maintains the complete path. Thumbnail and similarly named
    # folders are not interchangeable with character/texture.
    if folder_l != "character/texture":
        return False
    if "plw_" in name_l or any(token in name_l for token in AGE_AMBIGUOUS_NAME_TOKENS):
        return False
    # skip pure maps
    if any(name_l.endswith(s) for s in EXPAND_NAME_SKIP):
        return False
    # clip masks must never be blanked, even when another rule below matches
    if any(t in name_l for t in EXPAND_NAME_NEVER):
        return False
    # under-layer / underwear texture names
    if any(t in name_l for t in ("underup", "_under_", "underwear", "_uw_")):
        return True
    # lower/upper body *dec* (classic panty/underpaint decals) — not cloak/logo-only random dec
    if "_dec" in name_l and ("_lb_" in name_l or "_ub_" in name_l or "under" in name_l):
        return True
    return False


def dds_dimensions(data: bytes) -> tuple[int, int]:
    """(width, height) from a DDS header. (0, 0) when the buffer is not a DDS."""
    if len(data) < 128 or data[:4] != b"DDS ":
        return 0, 0
    height, width = struct.unpack_from("<II", data, 12)
    return width, height


def legacy_reject_reason(data: bytes, name: str, live_size: int | None) -> str | None:
    """Why this Resorepless-pack file must not overwrite the live texture, or None.

    The pack is a ~2018 artifact. On a 2026 client most of its entries no longer
    describe the texture they would replace, and copying one anyway does not remove
    censorship -- it destroys the map the body renders through.
    """
    if data[:4] != b"DDS ":
        return "not a DDS file"
    if "_cull" in name.lower():
        # Same rule the expanded scan already follows: a clip mask decides which body
        # texels survive under the garment. Swapping in a different image culls the
        # wrong region.
        return "geometry clip mask"
    width, height = dds_dimensions(data)
    if width <= 4 or height <= 4 or len(data) < 256:
        # 4x4 DXT stubs. They do erase the painted-on underwear, but the flat block is
        # then smeared across the whole UV, so the body under the garment renders as a
        # single dead colour instead of skin.
        return f"{width}x{height} stub ({len(data)} B) would flatten the whole map"
    if live_size is not None and live_size != len(data):
        # Usually a missing mip chain (1024^2 DXT1 = 524416 B flat vs 699192 B mipped),
        # sometimes different dimensions or a DXT1 file over a DXT5 slot.
        return f"stale: pack {len(data)} B vs live {live_size} B"
    return None


def copy_legacy(
    pack: pathlib.Path,
    tex_out: pathlib.Path,
    names: list[str],
    live: dict[str, int] | None = None,
) -> tuple[int, int]:
    ok = miss = 0
    for name in names:
        if live is not None and name.lower() not in live:
            log(f"  [STALE legacy] {name} is absent from live character/texture")
            miss += 1
            continue
        src = pack / name
        if not src.is_file():
            hits = list(pack.glob(name))
            if not hits:
                log(f"  [MISS legacy] {name}")
                miss += 1
                continue
            src = hits[0]
        data = src.read_bytes()
        reason = legacy_reject_reason(data, src.name, live.get(name.lower()) if live else None)
        if reason is not None:
            log(f"  [UNSAFE legacy] {src.name}: {reason}")
            miss += 1
            continue
        shutil.copy2(src, tex_out / src.name)
        ok += 1
        log(f"  [LEGACY] {src.name}")
    return ok, miss


def expand_from_paz(
    paz: pathlib.Path,
    tex_out: pathlib.Path,
    meta: MetaFile,
    ice: IceDecipher,
    only_names: set[str] | None = None,
) -> tuple[int, int]:
    """Build the censorship blank from the LIVE texture, never from the 2018 pack.

    only_names=None  -> expanded tier: every entry is_expand_candidate() matches.
    only_names={...} -> minimal/medium/high: just those names, generated from the
                        current client so dimensions, format and mip chain are right.
    """
    if only_names is None:
        log(f"Scanning live PAZ for under-armor / decal textures: {paz}")
    else:
        log(f"Rebuilding {len(only_names)} legacy target(s) from the live PAZ: {paz}")
    ok = skip = 0
    seen: set[str] = set()
    for block in meta.fileBlocks:
        folder = block.folderName or ""
        name = block.fileName or ""
        if only_names is None:
            if not is_expand_candidate(folder, name):
                continue
        else:
            if folder.replace("\\", "/").strip("/").lower() != "character/texture":
                continue
            if name.lower() not in only_names:
                continue
            # the clip-mask and age rules are not optional just because a name was
            # hand-listed by the 2018 pack
            if any(t in name.lower() for t in EXPAND_NAME_NEVER):
                log(f"  [SKIP clip-mask] {name}")
                skip += 1
                continue
            if "plw_" in name.lower() or any(
                t in name.lower() for t in AGE_AMBIGUOUS_NAME_TOKENS
            ):
                continue
        key = f"{folder.strip('/').lower()}/{name.lower()}"
        if key in seen:
            continue
        seen.add(key)
        dest = tex_out / name
        # an authored pack image already written for this name wins over a blank
        if dest.is_file():
            log(f"  [SKIP already] {name}")
            skip += 1
            continue
        try:
            data = decode_archive_dds(extract_block(paz, block, ice), ice)
            if not data:
                log(f"  [SKIP empty] {name}: live block decoded to nothing")
                skip += 1
                continue
            # pad/truncate to declared size before encoding, so the block count matches
            if block.size > 0:
                if len(data) < block.size:
                    data = data + bytes(block.size - len(data))
                elif len(data) > block.size:
                    data = data[: block.size]
            blank, note = transparent_payload(data)
            if blank is None:
                log(f"  [SKIP format] {name}: {note}")
                skip += 1
                continue
            if block.size > 0 and len(blank) != block.size:
                log(f"  [SKIP size] {name}: encoded {len(blank)} B != declared {block.size} B")
                skip += 1
                continue
            dest.write_bytes(blank)
            ok += 1
            log(f"  [EXPAND] {name} ({len(blank)} bytes, {note})")
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

    paz: pathlib.Path | None = pathlib.Path(args.paz) if args.paz else None
    meta: MetaFile | None = None
    ice: IceDecipher | None = None
    live: dict[str, int] | None = None
    if paz is not None:
        dll = pathlib.Path(__file__).resolve().parent / "ice_decipher.dll"
        if not dll.is_file():
            log(f"[FATAL] missing {dll}")
            return 3
        ice = IceDecipher(dll)
        meta = MetaFile(paz, ice)
        live = {
            (block.fileName or "").lower(): block.size
            for block in meta.fileBlocks
            if (block.folderName or "").replace("\\", "/").strip("/").lower()
            == "character/texture"
            and block.fileName
        }

    targets = MINIMAL_FILES if args.tier == "minimal" else MEDIUM_HIGH_FILES
    # Authored pack images first: a hand-painted repaint beats a blank when the file
    # still matches the live texture. Everything it refuses is then rebuilt from the
    # live client, which is the only source that still has the right size and format.
    ok, miss = copy_legacy(pack, tex, targets, live)
    if paz is None or meta is None or ice is None:
        log("[FATAL] --paz is required: blanks are generated from the live client")
        return 2
    expand_ok, expand_skip = expand_from_paz(
        paz, tex, meta, ice, only_names={n.lower() for n in targets}
    )
    if args.tier == "expanded":
        scan_ok, scan_skip = expand_from_paz(paz, tex, meta, ice)
        expand_ok += scan_ok
        expand_skip += scan_skip

    # A leading dot is an explicit Meta Injector 1.4.1 ignore marker.
    (out / ".README.txt").write_text(
        f"Censorship removal tier: {args.tier}\n"
        f"Legacy textures copied: {ok}  missing: {miss}\n"
        f"Expanded blanks: {expand_ok}  skip/fail: {expand_skip}\n"
        "LEGACY = authored Resorepless repaints, kept only when they still match live.\n"
        "EXPAND = transparent blank rebuilt FROM the live client (right size/format/mips).\n"
        "Only DXT5/DXT3 are blanked; zeroing a DXT1 would paint black, so it is skipped.\n"
        "Clip masks (*_cull*) are never touched.\n"
        "This removes painted-on underwear only -- the nude body comes from Midnight.\n"
        "Run Meta Injector after placing under files_to_patch.\n",
        encoding="utf-8",
    )
    log(f"Done. legacy_ok={ok} expand_ok={expand_ok} out={out}")
    total = ok + expand_ok
    return 0 if total else 1


if __name__ == "__main__":
    sys.exit(main())
