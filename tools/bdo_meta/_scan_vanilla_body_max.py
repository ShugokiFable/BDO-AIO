#!/usr/bin/env python3
"""One-shot: report live vanilla Max ranges for body-size bones."""
from __future__ import annotations

import re
import statistics
from collections import Counter, defaultdict
from pathlib import Path

import body_size_patcher as bsp

PAZ = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Black Desert Online\PAZ")
TARGETS = {
    "bip01 l breast",
    "bip01 r breast",
    "bip01 l thigh",
    "bip01 r thigh",
    "bip01 l hip",
    "bip01 r hip",
    "bip01 pelvis",
}

tag_re = re.compile(rb"<ParamDesc\b[^>]*?>", re.I)
attr_re = re.compile(rb'(\w+)="([^"]*)"')


def main() -> int:
    ice = bsp.IceDecipher(Path(__file__).resolve().parent / "ice_decipher.dll")
    meta = bsp.MetaFile(PAZ, ice)
    matches = [
        b
        for b in meta.fileBlocks
        if b.fileName and "customizationboneparamdesc" in b.fileName.lower()
    ]
    print(f"customizationboneparamdesc files: {len(matches)}")

    stats: dict[str, list[list[float]]] = defaultdict(list)
    height: dict[str, Counter] = defaultdict(Counter)
    parse_fail = 0
    files_ok = 0

    for block in matches:
        try:
            raw = bsp.extract_block(PAZ, block, ice)
        except Exception as e:
            print(f"extract fail {block.fileName}: {e}")
            continue
        if b"bonename" not in raw.lower():
            continue
        files_ok += 1
        for m in tag_re.finditer(raw):
            attrs = {
                k.decode("ascii", "ignore").lower(): v.decode("ascii", "ignore")
                for k, v in attr_re.findall(m.group(0))
            }
            bone = attrs.get("bonename", "")
            if bone.lower() not in TARGETS:
                continue
            max_s = attrs.get("max", "").strip()
            try:
                comps = [float(x) for x in max_s.split()]
            except ValueError:
                parse_fail += 1
                continue
            if len(comps) != 3:
                parse_fail += 1
                continue
            stats[bone].append(comps)
            height[bone][attrs.get("heightaxis", "").strip() or "(none)"] += 1

    print(f"files with BoneName tags: {files_ok}, bad Max tags: {parse_fail}")

    for bone in sorted(stats.keys(), key=str.lower):
        rows = stats[bone]
        xs = [r[0] for r in rows]
        ys = [r[1] for r in rows]
        zs = [r[2] for r in rows]
        peaks = [max(r) for r in rows]
        print(f"\n=== {bone}  n={len(rows)} ===")
        print(f"  Max.X  min={min(xs):.4f}  median={statistics.median(xs):.4f}  max={max(xs):.4f}")
        print(f"  Max.Y  min={min(ys):.4f}  median={statistics.median(ys):.4f}  max={max(ys):.4f}")
        print(f"  Max.Z  min={min(zs):.4f}  median={statistics.median(zs):.4f}  max={max(zs):.4f}")
        print(
            f"  peak(max of XYZ)  min={min(peaks):.4f}  "
            f"median={statistics.median(peaks):.4f}  max={max(peaks):.4f}"
        )
        print(f"  HeightAxis: {dict(height[bone])}")
        c = Counter(tuple(round(v, 4) for v in r) for r in rows)
        print("  top Max triples:")
        for t, n in c.most_common(10):
            print(f"    {t}  x{n}")

    print("\n===== GROUP SUMMARY =====")
    groups = {
        "breasts": ["Bip01 L Breast", "Bip01 R Breast"],
        "thighs": ["Bip01 L Thigh", "Bip01 R Thigh"],
        "hips": ["Bip01 L Hip", "Bip01 R Hip"],
        "pelvis": ["Bip01 Pelvis"],
    }
    for g, bones in groups.items():
        rows: list[list[float]] = []
        for b in bones:
            # case-insensitive lookup
            for k, v in stats.items():
                if k.lower() == b.lower():
                    rows.extend(v)
        if not rows:
            print(f"{g}: NO DATA")
            continue
        peaks = [max(r) for r in rows]
        le1 = sum(1 for p in peaks if p <= 1.0001)
        le125 = sum(1 for p in peaks if p <= 1.2501)
        print(
            f"{g:8s} peak Max: min={min(peaks):.4f} median={statistics.median(peaks):.4f} "
            f"max={max(peaks):.4f}  n={len(rows)}"
        )
        print(f"         peak<=1.00: {le1}/{len(rows)}   peak<=1.25: {le125}/{len(rows)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
