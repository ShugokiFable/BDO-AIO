#!/usr/bin/env python3
"""Assert unlock presets sit above typical stock Max ceilings."""
from __future__ import annotations

from body_size_patcher import PRESETS

# Typical stock Max from restored live PAZ scan (medians / majority)
STOCK = {
    "breasts": 1.25,  # majority tags 1.25
    "thighs": 1.15,  # peak median ~1.15
    "butt": 1.10,  # hip Max median ~1.10 (butt group is hip+pelvis)
}

# Caveats for honest reporting (not failures of the product)
CAVEATS = [
    "Some classes already ship breast Max Y/Z up to 1.55; widen-only never lowers them.",
    "Some classes already ship thigh girth Max 1.35; recommended 1.30 is a no-op there.",
    "Pelvis stock peak median ~1.20; recommended butt 1.18 mainly unlocks HIPS (1.00/1.10), not pelvis.",
]


def main() -> int:
    print("PRESET TABLE")
    for name, parts in PRESETS.items():
        print(
            f"  {name:12s}  breasts={parts['breasts']:.2f}  "
            f"thighs={parts['thighs']:.2f}  butt={parts['butt']:.2f}"
        )

    print("\nVS TYPICAL STOCK MAX (breasts 1.25 / thighs 1.15 / hips 1.10)")
    failed = 0
    for name in ("recommended", "high", "extreme"):
        p = PRESETS[name]
        for part in ("breasts", "thighs", "butt"):
            delta = p[part] - STOCK[part]
            ok = p[part] > STOCK[part] + 1e-9
            status = "HIGHER" if ok else "NOT HIGHER"
            if not ok:
                failed += 1
            print(
                f"  {name:12s} {part:8s}  preset={p[part]:.2f}  "
                f"stock={STOCK[part]:.2f}  delta={delta:+.2f}  {status}"
            )

    print("\nORDERING (each step >= previous)")
    order = ["vanilla", "recommended", "high", "extreme"]
    for a, b in zip(order, order[1:]):
        for part in ("breasts", "thighs", "butt"):
            ok = PRESETS[b][part] >= PRESETS[a][part] - 1e-9
            if not ok:
                failed += 1
            print(
                f"  {a} -> {b}  {part}: {PRESETS[a][part]:.2f} -> "
                f"{PRESETS[b][part]:.2f}  {'OK' if ok else 'BAD'}"
            )

    print("\nCAVEATS (class variance; widen-only)")
    for c in CAVEATS:
        print(f"  - {c}")

    if failed:
        print(f"\nFAILED checks: {failed}")
        return 1
    print("\nALL unlock presets are higher than typical stock Max ceilings.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
