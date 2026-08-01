#!/usr/bin/env python3
"""
Pubic hair overlays with best-effort multi-class coverage.

NATIVE: exact class bin (pbw/pdw/pew/phw/pww) onto matching base DDS.
EXPERIMENTAL: if another nude DDS has the SAME file size as a known base,
  reuse that bin (UV layout must match size or merge fails safely).

Also scans Midnight pack for all *nude*.dds body textures and tries every
compatible bin donor.
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

# bin stem -> typical authored base size (bytes) when known
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
            # skip pure normal/spec-only maps for primary try; still allow _n later only if named nude
            if n.endswith("_n.dds") or n.endswith("_sp.dds") or n.endswith("_m.dds"):
                continue
            # prefer larger / first
            if p.name not in found:
                found[p.name] = p
    return list(found.values())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", required=True, choices=STYLES)
    ap.add_argument("--hair-root", required=True)
    ap.add_argument("--base-roots", required=True, help="Semicolon-separated Midnight nude roots")
    ap.add_argument("--out", required=True)
    ap.add_argument(
        "--all-classes",
        action="store_true",
        default=False,
        help="EXPERIMENTAL: same-size donor bin on other nudes",
    )
    ap.add_argument(
        "--native-only",
        action="store_true",
        default=False,
        help="RESTORED only — exact class bins only (default when --all-classes omitted)",
    )
    args = ap.parse_args()
    # Safe default: NATIVE only. Donor reuse only with explicit --all-classes.
    allow_reuse = bool(args.all_classes) and not bool(args.native_only)

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

    # map bin stem -> bin path
    bins = {b.stem.lower(): b for b in style_dir.glob("*.bin")}
    if not bins:
        log(f"[FATAL] no .bin in {style_dir}")
        return 5

    # measure expected size per bin by finding matching base or using first successful
    bin_sizes: dict[str, int] = {}
    for stem, bpath in bins.items():
        dds_name = stem + ".dds"
        for base in bases:
            if base.name.lower() == dds_name:
                bin_sizes[stem] = base.stat().st_size
                break

    out_dir = pathlib.Path(args.out)
    out_tex = out_dir / "character" / "texture"
    out_tex.mkdir(parents=True, exist_ok=True)

    ok = 0
    skip = 0
    report = []

    # 1) NATIVE exact name matches
    for stem, bpath in bins.items():
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

    # 2) EXPERIMENTAL-REUSE: any other nude DDS with same size as a known bin base
    if allow_reuse:
        size_to_bin: dict[int, pathlib.Path] = {}
        for stem, sz in bin_sizes.items():
            if stem in bins:
                size_to_bin[sz] = bins[stem]
        # if we never measured, try each bin against each dds size by trial
        for base in bases:
            dest = out_tex / base.name
            if dest.is_file():
                continue  # already native
            # skip Shai-ish tiny if desired
            if base.name.lower().startswith("plw_"):
                log(f"  [SKIP Shai] {base.name}")
                skip += 1
                continue
            sz = base.stat().st_size
            donor = size_to_bin.get(sz)
            tried = []
            if donor:
                tried = [donor]
            else:
                tried = list(bins.values())
            applied = False
            for bpath in tried:
                if apply_bin_to_dds(base, bpath, offsets, dest):
                    log(f"  [EXPERIMENTAL-REUSE] {base.name} <- {bpath.name}")
                    report.append(f"EXPERIMENTAL-REUSE {base.name} <- {bpath.name}")
                    ok += 1
                    applied = True
                    break
            if not applied:
                log(f"  [SKIP size/UV] {base.name} ({sz} bytes)")
                skip += 1

    for dds in style_dir.glob("*.dds"):
        shutil.copy2(dds, out_tex / dds.name)
        log(f"  [COPY] {dds.name}")
        ok += 1

    mode = "NATIVE + EXPERIMENTAL-REUSE" if allow_reuse else "NATIVE only (RESTORED)"
    (out_dir / "README.txt").write_text(
        f"Pubic hair style: {args.style}\n"
        f"mode={mode}\n"
        f"Applied: {ok}  Skipped: {skip}\n"
        "NATIVE = exact class bin (RESTORED)\n"
        "EXPERIMENTAL-REUSE = same-size nude DDS used a donor bin (may look wrong if UVs differ)\n"
        "Shai skipped when detected (plw_).\n"
        + "\n".join(report)
        + "\n",
        encoding="utf-8",
    )
    log(f"Done. mode={mode} ok={ok} skip={skip} out={out_dir}")
    return 0 if ok > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
