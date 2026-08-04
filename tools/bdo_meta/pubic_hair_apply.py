#!/usr/bin/env python3
"""
Pubic hair overlays with NATIVE + optional EXPERIMENTAL-REUSE.

NATIVE: exact class bin (pbw/pdw/pew/phw/pww) onto matching base DDS.
EXPERIMENTAL / --all-classes: same-size donor bin on other nude DDS + new-female synthesize.
--classes: comma list of class prefixes to apply (e.g. phw,pdkl). Empty = all.

Shai (plw_) is skipped.
"""
from __future__ import annotations

import argparse
import pathlib
import shutil
import struct
import sys

from body_atlas import atlas_owners, resolve_class_bodies
from class_coverage import FEMALE_CLASSES
from inject_stage_builder import load_known_meta, route_missing_generated_files

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
    data = path.read_bytes()
    out = []
    if len(data) % 8 == 0 and len(data) > 0:
        for i in range(0, len(data), 8):
            off, length = struct.unpack_from("<ii", data, i)
            if off < 0 or length <= 0:
                continue
            out.append((off, length))
        if out:
            return out
    for i in range(0, len(data) - 7, 8):
        off, length = struct.unpack_from("<II", data, i)
        if length == 0 or length > 10_000_000:
            continue
        out.append((int(off), int(length)))
    return out


def _dxt1_pixels(block: bytes) -> list[tuple[int, int, int]]:
    """Decode one DXT1 block to 16 RGB pixels."""
    c0, c1, indices = struct.unpack("<HHI", block)

    def rgb565(value: int) -> tuple[int, int, int]:
        return (
            ((value >> 11) & 31) * 255 // 31,
            ((value >> 5) & 63) * 255 // 63,
            (value & 31) * 255 // 31,
        )

    a = rgb565(c0)
    b = rgb565(c1)
    if c0 > c1:
        palette = [
            a,
            b,
            tuple((2 * x + y) // 3 for x, y in zip(a, b)),
            tuple((x + 2 * y) // 3 for x, y in zip(a, b)),
        ]
    else:
        palette = [a, b, tuple((x + y) // 2 for x, y in zip(a, b)), (0, 0, 0)]
    return [palette[(indices >> (2 * i)) & 3] for i in range(16)]


def _dds_header(data: bytes) -> tuple[int, int, int, bytes, int, tuple[int, int, int]] | None:
    if len(data) < 128 or data[:4] != b"DDS " or struct.unpack_from("<I", data, 4)[0] != 124:
        return None
    height, width = struct.unpack_from("<II", data, 12)
    mips = struct.unpack_from("<I", data, 28)[0]
    return (
        width,
        height,
        max(1, mips),
        data[84:88],
        struct.unpack_from("<I", data, 88)[0],
        struct.unpack_from("<III", data, 92),
    )


def _mips(width: int, height: int, count: int, dxt1: bool) -> list[tuple[int, int, int, int, int]]:
    """Return (offset, size, width, height, blocks-per-row) for each mip."""
    out = []
    offset = 128
    for level in range(count):
        w = max(1, width >> level)
        h = max(1, height >> level)
        blocks_w = max(1, (w + 3) // 4)
        size = blocks_w * max(1, (h + 3) // 4) * 8 if dxt1 else w * h * 4
        out.append((offset, size, w, h, blocks_w))
        offset += size
    return out


def _apply_dxt1_delta_to_rgba(
    dds: bytearray,
    selected: bytes,
    neutral: bytes,
    offsets: list[tuple[int, int]],
    width: int,
    height: int,
    mip_count: int,
    masks: tuple[int, int, int],
) -> bool:
    """Translate restored DXT1 blocks onto a same-size 32-bit DDS mip chain."""
    if any(mask.bit_count() != 8 for mask in masks):
        return False
    shifts = tuple((mask & -mask).bit_length() - 1 for mask in masks)
    compressed = _mips(width, height, mip_count, True)
    raw = _mips(width, height, mip_count, False)
    if raw[-1][0] + raw[-1][1] != len(dds):
        return False

    blob_offset = 0
    for patch_offset, length in offsets:
        if blob_offset + length > len(selected) or blob_offset + length > len(neutral):
            return False
        for block_number in range(length // 8):
            source_offset = patch_offset + block_number * 8
            mip_index = next(
                (
                    i
                    for i, (start, size, _, _, _) in enumerate(compressed)
                    if start <= source_offset and source_offset + 8 <= start + size
                ),
                None,
            )
            if mip_index is None:
                return False
            start, _, mip_width, mip_height, blocks_w = compressed[mip_index]
            block_index = (source_offset - start) // 8
            block_y, block_x = divmod(block_index, blocks_w)
            source = blob_offset + block_number * 8
            chosen = _dxt1_pixels(selected[source : source + 8])
            clean = _dxt1_pixels(neutral[source : source + 8])
            raw_start = raw[mip_index][0]
            for pixel_index, (chosen_rgb, clean_rgb) in enumerate(zip(chosen, clean)):
                x = block_x * 4 + pixel_index % 4
                y = block_y * 4 + pixel_index // 4
                if x >= mip_width or y >= mip_height:
                    continue
                delta = tuple(a - b for a, b in zip(chosen_rgb, clean_rgb))
                if max(abs(value) for value in delta) <= 2:
                    continue
                target = raw_start + (y * mip_width + x) * 4
                packed = struct.unpack_from("<I", dds, target)[0]
                for mask, shift, change in zip(masks, shifts, delta):
                    value = (packed & mask) >> shift
                    value = max(0, min(255, value + change))
                    packed = (packed & ~mask) | (value << shift)
                struct.pack_into("<I", dds, target, packed)
        blob_offset += length
    return blob_offset == len(selected) == len(neutral)


def apply_bin_to_dds(
    dds_path: pathlib.Path,
    bin_path: pathlib.Path,
    offsets: list[tuple[int, int]],
    dest: pathlib.Path,
    neutral_bin_path: pathlib.Path | None = None,
) -> bool:
    dds = bytearray(dds_path.read_bytes())
    blob = bin_path.read_bytes()
    if sum(length for _, length in offsets) != len(blob):
        return False
    header = _dds_header(dds)
    if header is None:
        return False
    width, height, mip_count, fourcc, bpp, masks = header
    if fourcc != b"DXT1":
        if bpp != 32 or neutral_bin_path is None or not neutral_bin_path.is_file():
            return False
        if not _apply_dxt1_delta_to_rgba(
            dds, blob, neutral_bin_path.read_bytes(), offsets, width, height, mip_count, masks
        ):
            return False
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(dds)
        return True
    compressed = _mips(width, height, mip_count, True)
    if compressed[-1][0] + compressed[-1][1] != len(dds):
        return False

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


def collect_base_dds(roots: list[pathlib.Path]) -> list[pathlib.Path]:
    found: dict[str, pathlib.Path] = {}
    for root in roots:
        if not root.exists():
            continue
        for p in root.rglob("*.dds"):
            n = p.name.lower()
            if "nude" not in n:
                continue
            if n.endswith("_n.dds") or n.endswith("_sp.dds") or n.endswith("_m.dds"):
                continue
            if p.name not in found:
                found[p.name] = p
    return list(found.values())


def find_base_by_stem(bases: list[pathlib.Path], stem: str) -> pathlib.Path | None:
    want = (stem + ".dds").lower()
    for b in bases:
        if b.name.lower() == want:
            return b
    for b in bases:
        if b.stem.lower() == stem.lower():
            return b
    return None


def parse_style_map(raw_styles: str, raw_classes: str, single_style: str | None) -> dict[str, str]:
    """Build {class_prefix: style}.

    `--styles pnw=full_bush,pcw=trimmed` is the real interface. `--style X
    --classes a,b` is the older shape and expands to the same map. An empty
    selection stays empty -- it is never silently widened to every class.
    """
    out: dict[str, str] = {}
    for token in raw_styles.replace(";", ",").split(","):
        token = token.strip()
        if not token:
            continue
        prefix, _, style = token.partition("=")
        prefix = prefix.strip().lower()
        style = style.strip().lower()
        if not prefix or not style:
            raise ValueError(f"bad --styles entry {token!r}; expected prefix=style")
        if style not in STYLES:
            raise ValueError(f"unknown style {style!r} for {prefix}")
        out[prefix] = style
    if out:
        return out
    if single_style:
        for token in raw_classes.replace(";", ",").split(","):
            token = token.strip().lower()
            if token:
                out[token] = single_style
    return out


def style_dds_for_atlas(
    atlas_base: pathlib.Path,
    style_dir: pathlib.Path,
    hair_root: pathlib.Path,
    offsets: list[tuple[int, int]],
    dest: pathlib.Path,
) -> tuple[bool, str]:
    """Apply a style's hair bin onto one atlas texture. Returns (ok, note)."""
    bins = {b.stem.lower(): b for b in style_dir.glob("*.bin")}
    if not bins:
        return False, f"no .bin in {style_dir.name}"

    stem = atlas_base.stem.lower()
    ordered: list[pathlib.Path] = []
    if stem in bins:  # exact atlas match -- correct UVs by construction
        ordered.append(bins[stem])
    size = atlas_base.stat().st_size
    for bstem, bpath in sorted(bins.items()):
        if bpath in ordered:
            continue
        sibling = atlas_base.parent / (bstem + ".dds")
        if sibling.is_file() and sibling.stat().st_size == size:
            ordered.append(bpath)

    for bpath in ordered:
        neutral = hair_root / "shaved" / bpath.name
        if apply_bin_to_dds(atlas_base, bpath, offsets, dest, neutral):
            kind = "exact" if bpath.stem.lower() == stem else "same-size donor"
            return True, f"{atlas_base.name} + {bpath.name} ({kind})"
    return False, f"no compatible hair bin for {atlas_base.name} ({size} bytes)"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", default=None, choices=STYLES)
    ap.add_argument("--hair-root", required=True)
    ap.add_argument("--base-roots", required=True, help="Semicolon-separated Midnight nude roots")
    ap.add_argument("--out", required=True)
    ap.add_argument("--paz", required=True, help="Live PAZ folder used to route genuinely new files through _add")
    ap.add_argument(
        "--classes",
        default="",
        help="Comma class prefixes to apply (e.g. phw,pdkl,pww). Empty = all females",
    )
    ap.add_argument(
        "--styles",
        default="",
        help="Per-class styles: prefix=style,prefix=style (e.g. pnw=full_bush,pcw=trimmed)",
    )
    # Accepted and ignored; the atlas is now read from each PAC instead of guessed.
    for dead in ("--all-classes", "--new-females", "--native-only"):
        ap.add_argument(dead, action="store_true", default=False, help=argparse.SUPPRESS)
    args = ap.parse_args()

    try:
        style_map = parse_style_map(args.styles, args.classes, args.style)
    except ValueError as exc:
        log(f"[FATAL] {exc}")
        return 2

    if not style_map:
        log("[FATAL] No classes selected. Pass --styles prefix=style[,prefix=style].")
        log("        An empty selection is never treated as ALL.")
        return 6

    for prefix in [p for p in sorted(style_map) if p not in FEMALE_CLASSES]:
        log(f"  [WARN] unknown female prefix ignored: {prefix}")
        style_map.pop(prefix)
    if not style_map:
        log("[FATAL] No known female classes left after validation.")
        return 6

    hair_root = pathlib.Path(args.hair_root)
    offsets_path = hair_root / "offsets.bin"
    if not offsets_path.is_file():
        log(f"[FATAL] missing {offsets_path}")
        return 3
    for style in sorted(set(style_map.values())):
        if not (hair_root / style).is_dir():
            log(f"[FATAL] missing style folder: {hair_root / style}")
            return 2

    offsets = load_offsets(offsets_path)
    if not offsets:
        log("[FATAL] could not parse offsets.bin")
        return 4
    log(f"Loaded {len(offsets)} patch ranges")

    base_roots = [pathlib.Path(p) for p in args.base_roots.split(";") if p.strip()]
    bodies, problems = resolve_class_bodies(base_roots)
    for problem in problems:
        log(f"  [WARN] unreadable body PAC {problem}")
    if not bodies:
        log("[FATAL] no female nude body PACs found under the given base roots")
        return 5
    owners = atlas_owners(bodies)
    log(f"Resolved {len(bodies)} female body PACs across {len(owners)} texture atlases")

    bases = collect_base_dds(base_roots)
    texture_files = list(bases)
    for root in base_roots:
        tex_dir = root / "character" / "texture"
        if tex_dir.is_dir():
            texture_files.extend(tex_dir.glob("*.dds"))
    texture_files = list({p.resolve(): p for p in texture_files}.values())

    out_dir = pathlib.Path(args.out)
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_tex = out_dir / "character" / "texture"
    out_tex.mkdir(parents=True, exist_ok=True)

    known_meta = load_known_meta(pathlib.Path(args.paz))

    # Group selected classes by (atlas, style): classes that share an atlas AND
    # want the same style share one generated texture instead of duplicating it.
    groups: dict[tuple[str, str], list[str]] = {}
    for prefix in sorted(style_map):
        body = bodies.get(prefix)
        if body is None:
            log(f"  [SKIP no-body] {prefix}: no nude body PAC in the pack")
            continue
        groups.setdefault((body.atlas_key, style_map[prefix]), []).append(prefix)

    ok = 0
    skip = 0
    report: list[str] = []

    for (atlas_key, style), members in sorted(groups.items()):
        atlas_base = find_base_by_stem(bases, atlas_key)
        sharers = owners.get(atlas_key, [])
        outsiders = [p for p in sharers if p not in style_map]
        names = ", ".join(members)
        if atlas_base is None:
            log(f"  [SKIP no-texture] {names}: {atlas_key}.dds not in the nude pack")
            skip += len(members)
            continue

        # A texture can only carry ONE look. If any class on this atlas was not
        # selected, or selected classes asked for different styles, there is no
        # safe way to give them different hair: the earlier attempt to rename the
        # PAC's material to a private name made those bodies invisible in game,
        # because the string is a MATERIAL name resolved through the engine's
        # material registry, not a texture path a new DDS can satisfy.
        styles_here = {s for (k, s) in groups if k == atlas_key}
        if outsiders or len(styles_here) > 1:
            log(f"  [SKIP shared-texture] {names}: renders from {atlas_key}, shared with "
                f"{len(sharers)} class(es).")
            if outsiders:
                log(f"      not selected, would also change: {', '.join(outsiders)}")
            if len(styles_here) > 1:
                log(f"      conflicting styles requested on it: {', '.join(sorted(styles_here))}")
            log(f"      To style this body, select ALL of: {', '.join(sharers)} with one style.")
            report.append(
                f"SKIPPED-SHARED {names} atlas={atlas_key} sharers={','.join(sharers)}"
            )
            skip += len(members)
            continue

        style_dir = hair_root / style
        dest = out_tex / f"{atlas_key}.dds"
        good, note = style_dds_for_atlas(atlas_base, style_dir, hair_root, offsets, dest)
        if not good:
            log(f"  [SKIP] {names}: {note}")
            skip += len(members)
            continue
        kind = "PRIVATE-ATLAS" if len(sharers) == 1 else "WHOLE-SHARED-GROUP"
        log(f"  [{kind}] {names} <- {note} [{style}]")
        report.append(f"{kind} {atlas_key}.dds <- {note} [{style}] for {names}")
        ok += 1

    added = route_missing_generated_files(out_dir, known_meta)
    for internal in added:
        log(f"  [ADD new meta entry] {internal}")
        report.append(f"ADD new meta entry {internal}")

    shared_note = [
        f"{key}: {', '.join(who)}" for key, who in sorted(owners.items()) if len(who) > 1
    ]
    picked = ", ".join(f"{p}={style_map[p]}" for p in sorted(style_map))

    (out_dir / ".README.txt").write_text(
        "Pubic hair (per-class)\n"
        f"selection={picked}\n"
        f"Applied groups: {ok}  Skipped: {skip}\n"
        f"New meta entries: {len(added)}\n"
        "\n"
        "PRIVATE-ATLAS = class owns its texture; styled in place.\n"
        "WHOLE-SHARED-GROUP = every class on a shared texture was selected with one\n"
        "style, so the shared texture was styled once for all of them.\n"
        "SKIPPED-SHARED = the class renders from a texture other classes also use,\n"
        "and they were not all selected with the same style. No PAC is ever renamed:\n"
        "doing that made those bodies invisible in game.\n"
        "\n"
        "Shared atlases in this pack:\n  " + "\n  ".join(shared_note) + "\n\n"
        + "\n".join(report)
        + "\n",
        encoding="utf-8",
    )
    log(f"Done. groups={ok} skipped={skip} out={out_dir}")
    return 0 if ok > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
