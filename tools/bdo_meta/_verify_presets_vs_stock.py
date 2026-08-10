#!/usr/bin/env python3
"""Verify the v2.4.0 axis matrix and optionally audit live PAZ descriptors in memory."""
from __future__ import annotations

import argparse
import pathlib
import re

import body_size_patcher as bsp


EXPECTED = {
    "breasts.x": 1.55,
    "breasts.y": 1.55,
    "breasts.z": 1.55,
    "thighs.y": 1.35,
    "thighs.z": 1.35,
    "butt.x": 1.20,
    "butt.y": 1.20,
    "butt.z": 1.20,
    "pelvis.y": 1.40,
    "pelvis.z": 1.40,
    "belly.x": 1.28,
    "belly.z": 1.45,
}

# Highest values observed in the restored 75-descriptor audit. A Recommended
# value need not exceed every class peak because the patcher is widen-only.
OBSERVED_PEAKS = {
    "breasts.x": 1.30,
    "breasts.y": 1.55,
    "breasts.z": 1.55,
    "thighs.y": 1.35,
    "thighs.z": 1.35,
    "butt.x": 1.35,
    "butt.y": 1.35,
    "butt.z": 1.35,
    "pelvis.y": 1.40,
    "pelvis.z": 1.40,
    "belly.x": 1.20,
    "belly.z": 1.35,
}

_MIN_DEFAULT = re.compile(rb'\b(?:Min|Default)\s*=\s*"[^"]*"', re.IGNORECASE)
_MAX_ATTR = re.compile(rb'\bMax\s*=\s*"([^"]*)"', re.IGNORECASE)


def target_vectors(raw: bytes) -> dict[str, list[tuple[float, float, float]]]:
    found: dict[str, list[tuple[float, float, float]]] = {}
    for match in bsp._TAG_WITH_BONE.finditer(raw):
        tag = match.group(0)
        bone_match = bsp._BONE_ATTR.search(tag)
        max_match = _MAX_ATTR.search(tag)
        if bone_match is None or max_match is None:
            continue
        bone = bone_match.group(1).decode("ascii", "replace")
        if bone not in {item for bones in bsp.REGION_BONES.values() for item in bones}:
            continue
        values = tuple(float(item) for item in max_match.group(1).split())
        if len(values) == 3:
            found.setdefault(bone, []).append(values)
    return found


def audit_live(paz: pathlib.Path) -> int:
    dll = pathlib.Path(bsp.__file__).resolve().parent / "ice_decipher.dll"
    if not dll.exists():
        print(f"FAILED: missing {dll}")
        return 2
    ice = bsp.IceDecipher(dll)
    meta = bsp.MetaFile(paz, ice)
    matches = [
        block
        for block in meta.fileBlocks
        if block.fileName and "customizationboneparamdesc" in block.fileName.lower()
    ]
    bones = bsp.build_bone_axis_values(bsp.RECOMMENDED_AXES)
    changed_files = 0
    edits = 0
    tags = 0
    violations: list[str] = []

    for block in matches:
        raw = bsp.extract_block(paz, block, ice)
        patched, file_edits, file_tags = bsp.patch_xml_bytes(raw, bones)
        if len(raw) != len(patched):
            violations.append(f"{block.fileName}: byte length changed")
        if _MIN_DEFAULT.findall(raw) != _MIN_DEFAULT.findall(patched):
            violations.append(f"{block.fileName}: Min or Default changed")
        before = target_vectors(raw)
        after = target_vectors(patched)
        for bone in before:
            if bone not in after or len(before[bone]) != len(after[bone]):
                violations.append(f"{block.fileName}: target tag set changed for {bone}")
                continue
            for old, new in zip(before[bone], after[bone]):
                if bone in ("Bip01 L Thigh", "Bip01 R Thigh", "Bip01 Pelvis") and old[0] != new[0]:
                    violations.append(f"{block.fileName}: protected X changed for {bone}")
                if bone == "Bip01 Spine" and old[1] != new[1]:
                    violations.append(f"{block.fileName}: protected Spine Y changed")
                if any(new[index] + 1e-9 < old[index] for index in range(3)):
                    violations.append(f"{block.fileName}: widen-only violation for {bone}")
        if file_edits:
            changed_files += 1
        edits += file_edits
        tags += file_tags

    print("\nREAD-ONLY LIVE PAZ AUDIT")
    print(f"  descriptors={len(matches)} changed_in_memory={changed_files} target_tags={tags} Max_edits={edits}")
    print(f"  violations={len(violations)}")
    for item in violations[:20]:
        print(f"  - {item}")
    if len(matches) != 75:
        print(f"FAILED: expected 75 descriptors, found {len(matches)}")
        return 1
    return 1 if violations else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--paz", type=pathlib.Path, help="Optional live PAZ folder for an in-memory read-only audit")
    args = parser.parse_args()

    print("V2.4.0 RECOMMENDED AXIS MATRIX")
    if bsp.RECOMMENDED_AXES != EXPECTED:
        print(f"FAILED matrix: {bsp.RECOMMENDED_AXES!r}")
        return 1
    for key, value in EXPECTED.items():
        stock = OBSERVED_PEAKS[key]
        relation = "above" if value > stock else "equal" if value == stock else "below (widen-only preserves higher classes)"
        print(f"  {key:12s} recommended={value:.2f} observed_peak={stock:.2f}  {relation}")

    if EXPECTED["belly.z"] <= OBSERVED_PEAKS["belly.z"]:
        print("FAILED: Belly Z must exceed the observed 1.35 peak")
        return 1
    if EXPECTED["belly.x"] <= OBSERVED_PEAKS["belly.x"]:
        print("FAILED: Belly X must exceed the observed 1.20 peak")
        return 1
    if args.paz:
        result = audit_live(args.paz)
        if result:
            return result
    print("\nPASS: axis matrix and requested live audit are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
