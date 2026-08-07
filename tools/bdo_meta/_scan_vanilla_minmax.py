#!/usr/bin/env python3
"""Report vanilla Min / Default / Max for body bones from live restored PAZ."""
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


def parse_vec(s: str) -> list[float] | None:
    try:
        comps = [float(x) for x in s.split()]
    except ValueError:
        return None
    return comps if len(comps) == 3 else None


def main() -> int:
    ice = bsp.IceDecipher(Path(__file__).resolve().parent / "ice_decipher.dll")
    meta = bsp.MetaFile(PAZ, ice)
    matches = [
        b
        for b in meta.fileBlocks
        if b.fileName and "customizationboneparamdesc" in b.fileName.lower()
    ]
    data: dict[str, dict[str, list[list[float]]]] = defaultdict(
        lambda: {"min": [], "default": [], "max": []}
    )
    samples: dict[str, str] = {}

    for block in matches:
        try:
            raw = bsp.extract_block(PAZ, block, ice)
        except Exception:
            continue
        for m in tag_re.finditer(raw):
            tag = m.group(0)
            attrs = {
                k.decode("ascii", "ignore").lower(): v.decode("ascii", "ignore")
                for k, v in attr_re.findall(tag)
            }
            bone = attrs.get("bonename", "")
            if bone.lower() not in TARGETS:
                continue
            for field in ("min", "default", "max"):
                vec = parse_vec(attrs.get(field, ""))
                if vec:
                    data[bone][field].append(vec)
            if bone not in samples:
                samples[bone] = tag.decode("ascii", "ignore")[:220]

    print("WHAT THESE NUMBERS ARE")
    print("  Min / Default / Max are bone SCALE multipliers in customizationboneparamdesc.")
    print("  Default ~1.0 is neutral body. Max is the ceiling the beauty-salon slider can reach.")
    print("  This is NOT a 0-100 UI unit and not '0 to 1 only'.")
    print()

    for bone in sorted(data, key=str.lower):
        print(f"=== {bone} ===")
        for field in ("min", "default", "max"):
            rows = data[bone][field]
            if not rows:
                print(f"  {field}: NO DATA")
                continue
            peaks = [max(r) for r in rows]
            print(
                f"  {field:7s} n={len(rows):3d}  "
                f"peak med={statistics.median(peaks):.3f}  "
                f"peak range=[{min(peaks):.3f}, {max(peaks):.3f}]  "
                f"comp-med=({statistics.median([r[0] for r in rows]):.3f}, "
                f"{statistics.median([r[1] for r in rows]):.3f}, "
                f"{statistics.median([r[2] for r in rows]):.3f})"
            )
            top = Counter(tuple(round(v, 3) for v in r) for r in rows).most_common(4)
            print(f"          top: {top}")
        print(f"  sample tag: {samples.get(bone, '')}")
        print()

    # One-line group answer for the user
    print("=== SIMPLE ANSWER (median peak Max after vanilla restore) ===")
    groups = {
        "breasts": ["Bip01 L Breast", "Bip01 R Breast"],
        "thighs": ["Bip01 L Thigh", "Bip01 R Thigh"],
        "hips": ["Bip01 L Hip", "Bip01 R Hip"],
        "pelvis": ["Bip01 Pelvis"],
    }
    for g, bones in groups.items():
        rows = []
        for b in bones:
            for k, v in data.items():
                if k.lower() == b.lower():
                    rows.extend(v["max"])
        if not rows:
            continue
        peaks = [max(r) for r in rows]
        print(
            f"  {g:8s} Max peak median={statistics.median(peaks):.3f}  "
            f"[{min(peaks):.3f} .. {max(peaks):.3f}]"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
