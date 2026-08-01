#!/usr/bin/env python3
"""
Genital packs with NATIVE RESTORED and optional female EXPERIMENTAL-REUSE.

NATIVE RESTORED: Resorepless 3D vagina / penis PACs for classes that have them.
EXPERIMENTAL-REUSE: for missing females (esp. Seraph, Deadeye, …),
  copy a preferred donor mesh renamed to that class's nude/uw filenames.
  This replaces the high-quality Midnight/TGS body PAC for that class — labeled.

--new-females: only Seraph/Deadeye/Woosa/… (no native PAC). Implies donor reuse.
--all-classes: every female class; reuse where native missing. Males remain native-only.
Default / --native-only: classic NATIVE only.

Shai is skipped (same policy as Midnight).
"""
from __future__ import annotations

import argparse
import pathlib
import re
import shutil
import struct
import sys

from class_coverage import (
    FEMALE_CLASSES,
    FEMALE_DONOR_ORDER,
    MALE_CLASSES,
    NEW_FEMALE_PREFIXES,
    female_folder,
    male_folder,
    preferred_female_genital_donor,
)
from inject_stage_builder import load_known_meta, route_missing_generated_files


def log(m: str) -> None:
    print(m, flush=True)


def find_pac(pack: pathlib.Path, name: str) -> pathlib.Path | None:
    for p in (pack / "female" / name, pack / "male" / "normal" / name, pack / "male" / "hard" / name):
        if p.is_file():
            return p
    hits = list(pack.rglob(name))
    return hits[0] if hits else None


def pick_female_donor(
    pack: pathlib.Path, want_prefix: str, allow_reuse: bool
) -> tuple[pathlib.Path, str, bool]:
    """Return (src_pac, donor_prefix, is_native). Donor path only if allow_reuse."""
    native = FEMALE_CLASSES[want_prefix][2]
    if native:
        p = find_pac(pack, native)
        if p:
            return p, want_prefix, True
    if not allow_reuse:
        raise FileNotFoundError(f"no NATIVE female PAC for {want_prefix} (reuse off)")

    # Preferred donor for new females first
    preferred = preferred_female_genital_donor(want_prefix)
    order: list[str] = []
    if preferred:
        order.append(preferred)
    for d in FEMALE_DONOR_ORDER:
        if d not in order:
            order.append(d)

    for d in order:
        n = FEMALE_CLASSES.get(d, (None, None, None))[2]
        if not n:
            continue
        p = find_pac(pack, n)
        if p:
            return p, d, False
    any_p = list((pack / "female").glob("*.pac"))
    if any_p:
        return any_p[0], "unknown", False
    raise FileNotFoundError("no female donor PAC")


def pick_male_native(
    pack: pathlib.Path, want_prefix: str, style: str
) -> tuple[pathlib.Path, str, bool]:
    native_name = MALE_CLASSES.get(want_prefix, (None, None, None))[2]
    style_dir = pack / "male" / style
    if native_name:
        p = style_dir / native_name
        if p.is_file():
            return p, want_prefix, True
    raise FileNotFoundError(f"no NATIVE male PAC for {want_prefix}")


_PAC_MATERIAL = re.compile(rb"(?i)([a-z]{2,5}_\d{2}_nude_\d{4})")


def pac_material_stem(pac: pathlib.Path) -> str:
    """Return the one authored DDS stem embedded in a restored body PAC."""
    stems = {match.decode("ascii").lower() for match in _PAC_MATERIAL.findall(pac.read_bytes())}
    if len(stems) != 1:
        raise ValueError(f"{pac.name}: expected one embedded nude material, found {sorted(stems)}")
    return stems.pop()


def validate_dds(path: pathlib.Path) -> None:
    with path.open("rb") as stream:
        header = stream.read(128)
    if len(header) < 128 or header[:4] != b"DDS " or struct.unpack_from("<I", header, 4)[0] != 124:
        raise ValueError(f"{path.name}: invalid DDS header")
    height, width = struct.unpack_from("<II", header, 12)
    if not width or not height:
        raise ValueError(f"{path.name}: invalid DDS dimensions {width}x{height}")


def copy_material_textures(
    pack: pathlib.Path, out: pathlib.Path, pac: pathlib.Path, label: str
) -> list[str]:
    """Copy the PAC's authored texture set without changing its material names."""
    stem = pac_material_stem(pac)
    sources = sorted(
        p for p in (pack / "texture").glob("*.dds")
        if p.stem.lower() == stem or p.stem.lower().startswith(stem + "_")
    )
    if not any(p.stem.lower() == stem for p in sources):
        raise FileNotFoundError(f"{pac.name}: missing diffuse texture {stem}.dds")
    tex_out = out / "character" / "texture"
    tex_out.mkdir(parents=True, exist_ok=True)
    notes: list[str] = []
    for src in sources:
        validate_dds(src)
        shutil.copy2(src, tex_out / src.name)
        notes.append(f"[{label} material {stem}] {src.name}")
        log(notes[-1])
    return notes


def copy_female_class(
    pack: pathlib.Path, out: pathlib.Path, prefix: str, allow_reuse: bool
) -> list[str]:
    notes = []
    folder = female_folder(prefix)
    dest_dir = out / folder
    dest_dir.mkdir(parents=True, exist_ok=True)
    src, donor, native = pick_female_donor(pack, prefix, allow_reuse)
    # Midnight / injector common names
    targets = [
        f"{prefix}_00_nude_0001.pac",
        f"{prefix}_00_uw_0001.pac",
    ]
    # Do not copy the donor's original filename into the target-class folder.
    # The game references the target names; adding the donor name creates an
    # unreferenced meta entry and previously inflated every reuse package.
    for t in targets:
        shutil.copy2(src, dest_dir / t)
    tag = "NATIVE" if native else f"EXPERIMENTAL-REUSE from {donor}"
    notes.append(f"[F {tag}] {prefix} ({FEMALE_CLASSES[prefix][1]}) <- {src.name}")
    log(notes[-1])
    notes.extend(copy_material_textures(pack, out, src, "F"))
    return notes


def copy_male_class(
    pack: pathlib.Path, out: pathlib.Path, prefix: str, style: str
) -> list[str]:
    notes = []
    if prefix not in MALE_CLASSES:
        return notes
    folder = male_folder(prefix)
    dest_dir = out / folder
    dest_dir.mkdir(parents=True, exist_ok=True)
    src, donor, native = pick_male_native(pack, prefix, style)
    for t in (f"{prefix}_00_nude_0001.pac", f"{prefix}_00_uw_0001.pac"):
        shutil.copy2(src, dest_dir / t)
    tag = "NATIVE" if native else f"EXPERIMENTAL-REUSE from {donor}"
    notes.append(f"[M {style} {tag}] {prefix} ({MALE_CLASSES[prefix][1]}) <- {src.name}")
    log(notes[-1])
    notes.extend(copy_material_textures(pack, out, src, "M"))
    return notes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack-root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--paz", required=True, help="Live PAZ folder used to route genuinely new files through _add")
    ap.add_argument("--female-3d-vagina", choices=["on", "off"], default="off")
    ap.add_argument(
        "--male-penis",
        default="none",
        help="none|normal|hard OR warrior=hard,striker=normal OR all=normal",
    )
    ap.add_argument(
        "--all-classes",
        action="store_true",
        default=False,
        help="EXPERIMENTAL: donor mesh reuse for females with no native pack; males stay native-only",
    )
    ap.add_argument(
        "--new-females",
        action="store_true",
        default=False,
        help="EXPERIMENTAL: only new females (Seraph/Deadeye/…) via preferred donor meshes",
    )
    ap.add_argument(
        "--native-only",
        action="store_true",
        default=False,
        help="RESTORED only — never donor-reuse (default when reuse flags omitted)",
    )
    ap.add_argument(
        "--female-classes",
        default="",
        help="Comma female prefixes to include (e.g. phw,pdkl). Empty = all relevant",
    )
    ap.add_argument(
        "--male-classes",
        default="",
        help="Comma male prefixes for all= style (e.g. phm,pcm). Empty = all relevant",
    )
    args = ap.parse_args()

    new_females = bool(args.new_females)
    allow_female_reuse = (bool(args.all_classes) or new_females) and not bool(args.native_only)
    if new_females:
        female_on = True
    else:
        female_on = args.female_3d_vagina == "on"

    female_filt = {
        p.strip().lower()
        for p in args.female_classes.replace(";", ",").split(",")
        if p.strip()
    } or None
    male_filt = {
        p.strip().lower()
        for p in args.male_classes.replace(";", ",").split(",")
        if p.strip()
    } or None

    pack = pathlib.Path(args.pack_root)
    out = pathlib.Path(args.out)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    report: list[str] = []
    failures: list[str] = []
    if new_females:
        mode = "NEW-FEMALES EXPERIMENTAL-REUSE only"
    elif allow_female_reuse:
        mode = "NATIVE + FEMALE EXPERIMENTAL-REUSE"
    else:
        mode = "NATIVE only (RESTORED)"
    if female_filt:
        log(f"Female class filter: {', '.join(sorted(female_filt))}")
    if male_filt:
        log(f"Male class filter: {', '.join(sorted(male_filt))}")

    if female_on:
        log(f"=== Female 3D vagina ({mode}) ===")
        if new_females:
            targets = list(NEW_FEMALE_PREFIXES)
        else:
            targets = list(FEMALE_CLASSES.keys())
        if female_filt is not None:
            targets = [p for p in targets if p in female_filt]
        log(f"  targets: {', '.join(targets) if targets else '(none)'}")
        for pref in targets:
            if not new_females and not allow_female_reuse and not FEMALE_CLASSES[pref][2]:
                continue
            if new_females and pref not in NEW_FEMALE_PREFIXES:
                continue
            try:
                notes = copy_female_class(pack, out, pref, allow_reuse=True if new_females else allow_female_reuse)
                report.extend(notes)
            except Exception as e:
                log(f"  [FAIL F] {pref}: {e}")
                failures.append(f"female {pref}: {e}")

    # male map (skipped in --new-females mode)
    penis_map: dict[str, str] = {}
    if not new_females:
        raw = args.male_penis.strip().lower()
        if raw in ("none",):
            pass
        elif raw in ("normal", "hard") or raw.startswith("all="):
            style = raw.split("=", 1)[-1] if raw.startswith("all=") else raw
            for pref in MALE_CLASSES:
                if male_filt is not None and pref not in male_filt:
                    continue
                if MALE_CLASSES[pref][2]:
                    penis_map[pref] = style
        else:
            name_to_pref = {v[1].lower(): k for k, v in MALE_CLASSES.items()}
            name_to_pref.update(
                {
                    "warrior": "phm",
                    "berserker": "pgm",
                    "musa": "pkm",
                    "wizard": "pwm",
                    "ninja": "pnm",
                    "striker": "pcm",
                    "archer": "pem",
                    "hashashin": "pam",
                    "sage": "ppm",
                }
            )
            for part in raw.split(","):
                part = part.strip()
                if not part or "=" not in part:
                    continue
                k, v = part.split("=", 1)
                k, v = k.strip().lower(), v.strip().lower()
                if v not in ("none", "normal", "hard") or v == "none":
                    continue
                pref = name_to_pref.get(k, k if k in MALE_CLASSES else None)
                if pref:
                    if male_filt is not None and pref not in male_filt:
                        continue
                    if pref in MALE_CLASSES and MALE_CLASSES[pref][2]:
                        penis_map[pref] = v
                    else:
                        log(f"  [SKIP M no-native] {pref}")

    if penis_map:
        log(f"=== Male penis ({mode}) ===")
        for pref, style in penis_map.items():
            try:
                notes = copy_male_class(pack, out, pref, style)
                report.extend(notes)
            except Exception as e:
                log(f"  [FAIL M] {pref}: {e}")
                failures.append(f"male {pref}: {e}")

    added = route_missing_generated_files(out, load_known_meta(pathlib.Path(args.paz)))
    for internal in added:
        log(f"  [ADD new meta entry] {internal}")
        report.append(f"[ADD new meta entry] {internal}")

    readme = out / ".README.txt"
    readme.write_text(
        "Genital pack apply\n"
        "==================\n"
        f"mode={mode}\n"
        "NATIVE = original Resorepless mesh for that class (RESTORED)\n"
        "EXPERIMENTAL-REUSE = donor mesh renamed for missing class (may clip/mismatch)\n"
        "NEW FEMALES: replaces Midnight/TGS nude PAC for that class with a donor genital body.\n"
        "Shai is not included.\n\n"
        f"new_females={new_females}\n"
        f"female_3d_vagina={args.female_3d_vagina}\n"
        f"male_penis={args.male_penis}\n"
        f"allow_female_reuse={allow_female_reuse}\n"
        "male_reuse=False\n"
        f"entries={len(report)}\n\n"
        f"failures={len(failures)}\n"
        + "\n".join(report)
        + ("\n\nFAILURES\n" + "\n".join(failures) if failures else "")
        + "\n\nUse with Midnight underwear hide. Meta Inject + PartCutGen.\n",
        encoding="utf-8",
    )
    log(f"Done. mode={mode} report_lines={len(report)} out={out}")
    if failures:
        return 2
    return 0 if report else 1


if __name__ == "__main__":
    sys.exit(main())
