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

from class_coverage import (
    FEMALE_CLASSES,
    NEW_FEMALE_PREFIXES,
    NEW_FEMALE_PUBIC_BASE,
    preferred_female_pubic_base,
    prefix_from_filename,
)
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

BIN_STEMS = [
    "pbw_00_nude_0001",
    "pdw_00_nude_0001",
    "pew_01_nude_0001",
    "phw_01_nude_0001",
    "pww_01_nude_0001",
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


def apply_bin_to_dds(
    dds_path: pathlib.Path,
    bin_path: pathlib.Path,
    offsets: list[tuple[int, int]],
    dest: pathlib.Path,
) -> bool:
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


def pick_bin_for_base(
    base: pathlib.Path,
    bins: dict[str, pathlib.Path],
    bin_sizes: dict[str, int],
) -> pathlib.Path | None:
    stem = base.stem.lower()
    if stem in bins:
        return bins[stem]
    sz = base.stat().st_size
    for bstem, bsz in bin_sizes.items():
        if bsz == sz and bstem in bins:
            return bins[bstem]
    return None


def parse_class_filter(raw: str) -> set[str] | None:
    """None = no filter (all). Empty after parse treated as None."""
    if not raw or not raw.strip():
        return None
    parts = {p.strip().lower() for p in raw.replace(";", ",").split(",") if p.strip()}
    return parts or None


def class_allowed(prefix: str | None, filt: set[str] | None) -> bool:
    if filt is None:
        return True
    if not prefix:
        return False
    return prefix in filt


def synthesize_new_female(
    prefix: str,
    bases: list[pathlib.Path],
    bins: dict[str, pathlib.Path],
    bin_sizes: dict[str, int],
    offsets: list[tuple[int, int]],
    out_tex: pathlib.Path,
) -> list[str]:
    notes: list[str] = []
    donor_stem = preferred_female_pubic_base(prefix)
    if not donor_stem:
        log(f"  [SKIP new-F no-map] {prefix}")
        return notes

    base = find_base_by_stem(bases, donor_stem)
    if not base:
        log(f"  [SKIP new-F no-base] {prefix} needs {donor_stem}.dds in Midnight nude pack")
        return notes

    bpath = pick_bin_for_base(base, bins, bin_sizes)
    tried: list[pathlib.Path] = []
    if bpath:
        tried.append(bpath)
    for bp in bins.values():
        if bp not in tried:
            tried.append(bp)

    out_names = [
        f"{prefix}_00_nude_0001.dds",
        f"{prefix}_01_nude_0001.dds",
    ]
    if "_01_" in donor_stem:
        out_names = [
            f"{prefix}_01_nude_0001.dds",
            f"{prefix}_00_nude_0001.dds",
        ]

    applied_any = False
    for bpath in tried:
        dest0 = out_tex / out_names[0]
        if apply_bin_to_dds(base, bpath, offsets, dest0):
            notes.append(
                f"EXPERIMENTAL-REUSE new-female {out_names[0]} <- {base.name} + {bpath.name} ({prefix})"
            )
            log(f"  [EXPERIMENTAL-REUSE new-F] {out_names[0]} <- {base.name} + {bpath.name}")
            for extra in out_names[1:]:
                shutil.copy2(dest0, out_tex / extra)
                log(f"  [EXPERIMENTAL-REUSE new-F] {extra} (clone)")
                notes.append(f"EXPERIMENTAL-REUSE new-female {extra} (clone of {out_names[0]})")
            applied_any = True
            break
    if not applied_any:
        log(f"  [SKIP new-F size/UV] {prefix} base={base.name} ({base.stat().st_size} bytes)")
    return notes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", required=True, choices=STYLES)
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
        "--all-classes",
        action="store_true",
        default=False,
        help="EXPERIMENTAL: same-size donor bin on other nudes + new-female synthesize",
    )
    ap.add_argument(
        "--new-females",
        action="store_true",
        default=False,
        help="EXPERIMENTAL: synthesize pubic DDS for new females (filtered by --classes)",
    )
    ap.add_argument(
        "--native-only",
        action="store_true",
        default=False,
        help="RESTORED only — exact class bins only (default when reuse flags omitted)",
    )
    args = ap.parse_args()
    new_females = bool(args.new_females)
    allow_reuse = (bool(args.all_classes) or new_females) and not bool(args.native_only)
    class_filt = parse_class_filter(args.classes)
    if class_filt:
        log(f"Class filter: {', '.join(sorted(class_filt))}")
        # warn unknown
        for p in sorted(class_filt):
            if p not in FEMALE_CLASSES and p != "plw":
                log(f"  [WARN] unknown female prefix in filter: {p}")

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
    log(f"Loaded {len(offsets)} patch ranges")

    base_roots = [pathlib.Path(p) for p in args.base_roots.split(";") if p.strip()]
    bases = collect_base_dds(base_roots)
    log(f"Found {len(bases)} candidate nude DDS bases")

    bins = {b.stem.lower(): b for b in style_dir.glob("*.bin")}
    if not bins:
        log(f"[FATAL] no .bin in {style_dir}")
        return 5

    bin_sizes: dict[str, int] = {}
    for stem, bpath in bins.items():
        dds_name = stem + ".dds"
        for base in bases:
            if base.name.lower() == dds_name:
                bin_sizes[stem] = base.stat().st_size
                break

    out_dir = pathlib.Path(args.out)
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_tex = out_dir / "character" / "texture"
    out_tex.mkdir(parents=True, exist_ok=True)

    ok = 0
    skip = 0
    report: list[str] = []

    # 1) NATIVE exact name matches (skip when --new-females only)
    if not new_females:
        for stem, bpath in bins.items():
            pref = prefix_from_filename(stem + ".dds")
            if not class_allowed(pref, class_filt):
                log(f"  [SKIP filter] NATIVE {stem} ({pref})")
                skip += 1
                continue
            dds_name = stem + ".dds"
            base = next((b for b in bases if b.name.lower() == dds_name), None)
            if not base:
                continue
            dest = out_tex / base.name
            if apply_bin_to_dds(base, bpath, offsets, dest):
                log(f"  [NATIVE] {base.name}")
                report.append(f"NATIVE {base.name} <- {bpath.name}")
                ok += 1
                bin_sizes[stem] = base.stat().st_size
            else:
                log(f"  [FAIL native] {base.name}")
                skip += 1

    # 2) EXPERIMENTAL-REUSE: other nude DDS same size (all-classes, not new-females-only)
    if allow_reuse and not new_females:
        size_to_bin: dict[int, pathlib.Path] = {}
        for stem, sz in bin_sizes.items():
            if stem in bins:
                size_to_bin[sz] = bins[stem]
        for base in bases:
            dest = out_tex / base.name
            if dest.is_file():
                continue
            if base.name.lower().startswith("plw_"):
                log(f"  [SKIP Shai] {base.name}")
                skip += 1
                continue
            pref = prefix_from_filename(base.name)
            if not class_allowed(pref, class_filt):
                continue
            sz = base.stat().st_size
            donor = size_to_bin.get(sz)
            tried = [donor] if donor else list(bins.values())
            applied = False
            for bpath in tried:
                if bpath is None:
                    continue
                if apply_bin_to_dds(base, bpath, offsets, dest):
                    log(f"  [EXPERIMENTAL-REUSE] {base.name} <- {bpath.name}")
                    report.append(f"EXPERIMENTAL-REUSE {base.name} <- {bpath.name}")
                    ok += 1
                    applied = True
                    break
            if not applied:
                log(f"  [SKIP size/UV] {base.name} ({sz} bytes)")
                skip += 1

    # 3) NEW FEMALES: invent class-named textures from preferred donor bases
    if new_females or (allow_reuse and args.all_classes):
        targets = [p for p in NEW_FEMALE_PREFIXES if class_allowed(p, class_filt)]
        log("=== NEW FEMALES pubic synthesize (EXPERIMENTAL-REUSE) ===")
        log(f"  classes: {', '.join(targets) if targets else '(none after filter)'}")
        for pref in targets:
            already = any(
                (out_tex / n).is_file()
                for n in (f"{pref}_00_nude_0001.dds", f"{pref}_01_nude_0001.dds")
            )
            if already and not new_females:
                log(f"  [SKIP new-F already] {pref}")
                continue
            notes = synthesize_new_female(pref, bases, bins, bin_sizes, offsets, out_tex)
            if notes:
                report.extend(notes)
                ok += len(notes)
            else:
                skip += 1

    # only copy style preview dds if we applied something (or no filter)
    for dds in style_dir.glob("*.dds"):
        shutil.copy2(dds, out_tex / dds.name)
        log(f"  [COPY] {dds.name}")
        ok += 1

    if new_females:
        mode = "NEW-FEMALES EXPERIMENTAL-REUSE"
    elif allow_reuse:
        mode = "NATIVE + EXPERIMENTAL-REUSE"
    else:
        mode = "NATIVE only (RESTORED)"
    filt_s = ",".join(sorted(class_filt)) if class_filt else "ALL"

    added = route_missing_generated_files(out_dir, load_known_meta(pathlib.Path(args.paz)))
    for internal in added:
        log(f"  [ADD new meta entry] {internal}")
        report.append(f"ADD new meta entry {internal}")

    (out_dir / ".README.txt").write_text(
        f"Pubic hair style: {args.style}\n"
        f"mode={mode}\n"
        f"classes={filt_s}\n"
        f"Applied: {ok}  Skipped: {skip}\n"
        f"New meta entries: {len(added)}\n"
        "NATIVE = exact class bin (RESTORED)\n"
        "EXPERIMENTAL-REUSE = same-size / new-female synthesized DDS (may look wrong if UVs differ)\n"
        f"New female map: {NEW_FEMALE_PUBIC_BASE}\n"
        "Shai skipped when detected (plw_).\n"
        + "\n".join(report)
        + "\n",
        encoding="utf-8",
    )
    log(f"Done. mode={mode} classes={filt_s} ok={ok} skip={skip} out={out_dir}")
    return 0 if ok > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
