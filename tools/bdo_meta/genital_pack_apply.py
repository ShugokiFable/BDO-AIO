#!/usr/bin/env python3
"""
Genital packs with NATIVE RESTORED and optional EXPERIMENTAL-REUSE.

NATIVE RESTORED: Resorepless 3D vagina / penis PACs for classes that have them.
EXPERIMENTAL-REUSE: for missing classes (esp. new females: Seraph, Deadeye, …),
  copy a preferred donor mesh renamed to that class's nude/uw filenames.
  This replaces the high-quality Midnight/TGS body PAC for that class — labeled.

--new-females: only Seraph/Deadeye/Woosa/… (no native PAC). Implies donor reuse.
--all-classes: every class; reuse where native missing.
Default / --native-only: classic NATIVE only.

Shai is skipped (same policy as Midnight).
"""
from __future__ import annotations

import argparse
import pathlib
import shutil
import sys

from class_coverage import (
    FEMALE_CLASSES,
    FEMALE_DONOR_ORDER,
    MALE_CLASSES,
    MALE_DONOR_ORDER,
    NEW_FEMALE_PREFIXES,
    female_folder,
    male_folder,
    preferred_female_genital_donor,
)


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


def pick_male_donor(
    pack: pathlib.Path, want_prefix: str, style: str, allow_reuse: bool
) -> tuple[pathlib.Path, str, bool]:
    native_name = MALE_CLASSES.get(want_prefix, (None, None, None))[2]
    style_dir = pack / "male" / style
    if native_name:
        p = style_dir / native_name
        if p.is_file():
            return p, want_prefix, True
    if not allow_reuse:
        raise FileNotFoundError(f"no NATIVE male PAC for {want_prefix} (reuse off)")
    for d in MALE_DONOR_ORDER:
        n = MALE_CLASSES[d][2]
        if not n:
            continue
        p = style_dir / n
        if p.is_file():
            return p, d, False
    any_p = list(style_dir.glob("*.pac"))
    if any_p:
        return any_p[0], "unknown", False
    raise FileNotFoundError(f"no male {style} donor PAC")


def copy_female_textures(
    pack: pathlib.Path, out: pathlib.Path, prefix: str, donor: str, native: bool
) -> list[str]:
    """Copy genital-pack textures; when reusing, also rename donor maps to target prefix."""
    notes: list[str] = []
    tex_src = pack / "texture"
    if not tex_src.is_dir():
        return notes
    tex_out = out / "character" / "texture"
    tex_out.mkdir(parents=True, exist_ok=True)

    # Prefer exact-prefix textures; fall back to donor-named maps
    candidates: list[pathlib.Path] = []
    for p in tex_src.glob("*nude*"):
        n = p.name.lower()
        if n.startswith(prefix + "_"):
            candidates.append(p)
    if not candidates and not native:
        for p in tex_src.glob("*nude*"):
            n = p.name.lower()
            if n.startswith(donor + "_"):
                candidates.append(p)

    for src in candidates:
        name = src.name
        if not native and name.lower().startswith(donor + "_"):
            # rewrite donor prefix -> target class prefix
            dest_name = prefix + name[len(donor) :]
        else:
            dest_name = name
        shutil.copy2(src, tex_out / dest_name)
        tag = "NATIVE" if native else f"EXPERIMENTAL-REUSE tex from {donor}"
        notes.append(f"[F tex {tag}] {dest_name}")
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
    # also keep donor legacy name when reusing (some tools look for original)
    if not native and donor != prefix:
        targets.append(src.name)
    for t in targets:
        shutil.copy2(src, dest_dir / t)
    tag = "NATIVE" if native else f"EXPERIMENTAL-REUSE from {donor}"
    notes.append(f"[F {tag}] {prefix} ({FEMALE_CLASSES[prefix][1]}) <- {src.name}")
    log(notes[-1])
    notes.extend(copy_female_textures(pack, out, prefix, donor, native))
    return notes


def copy_male_class(
    pack: pathlib.Path, out: pathlib.Path, prefix: str, style: str, allow_reuse: bool
) -> list[str]:
    notes = []
    if prefix not in MALE_CLASSES:
        return notes
    folder = male_folder(prefix)
    dest_dir = out / folder
    dest_dir.mkdir(parents=True, exist_ok=True)
    src, donor, native = pick_male_donor(pack, prefix, style, allow_reuse)
    for t in (f"{prefix}_00_nude_0001.pac", f"{prefix}_00_uw_0001.pac"):
        shutil.copy2(src, dest_dir / t)
    tag = "NATIVE" if native else f"EXPERIMENTAL-REUSE from {donor}"
    notes.append(f"[M {style} {tag}] {prefix} ({MALE_CLASSES[prefix][1]}) <- {src.name}")
    log(notes[-1])
    tex_out = out / "character" / "texture"
    tex_out.mkdir(parents=True, exist_ok=True)
    for tname in (f"{prefix}_00_nude_0001.dds", f"{donor}_00_nude_0001.dds", f"{donor}_01_nude_0001.dds"):
        tsrc = pack / "texture" / tname
        if tsrc.is_file():
            dest_name = f"{prefix}_00_nude_0001.dds" if "_nude_" in tname else tname
            if tname.startswith(donor) and donor != prefix:
                dest_name = f"{prefix}_00_nude_0001.dds"
            shutil.copy2(tsrc, tex_out / dest_name)
            log(f"  [M tex] {dest_name}")
    return notes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack-root", required=True)
    ap.add_argument("--out", required=True)
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
        help="EXPERIMENTAL: donor mesh reuse for every class with no native pack",
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
    allow_reuse = (bool(args.all_classes) or new_females) and not bool(args.native_only)
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
    if new_females:
        mode = "NEW-FEMALES EXPERIMENTAL-REUSE only"
    elif allow_reuse:
        mode = "NATIVE + EXPERIMENTAL-REUSE"
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
            if not new_females and not allow_reuse and not FEMALE_CLASSES[pref][2]:
                continue
            if new_females and pref not in NEW_FEMALE_PREFIXES:
                continue
            try:
                notes = copy_female_class(pack, out, pref, allow_reuse=True if new_females else allow_reuse)
                report.extend(notes)
            except Exception as e:
                log(f"  [FAIL F] {pref}: {e}")

        # always also dump native pack textures that match classic classes (when not new-only)
        if not new_females:
            tex_out = out / "character" / "texture"
            tex_out.mkdir(parents=True, exist_ok=True)
            for dds in (pack / "texture").glob("*nude*.dds"):
                n = dds.name.lower()
                if any(n.startswith(p + "_") for p in FEMALE_CLASSES if FEMALE_CLASSES[p][2]):
                    if female_filt is not None and not any(n.startswith(p + "_") for p in female_filt):
                        continue
                    dest = tex_out / dds.name
                    if not dest.exists():
                        shutil.copy2(dds, dest)
                        log(f"  [F tex native] {dds.name}")

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
                if allow_reuse or MALE_CLASSES[pref][2]:
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
                    if allow_reuse or (pref in MALE_CLASSES and MALE_CLASSES[pref][2]):
                        penis_map[pref] = v
                    else:
                        log(f"  [SKIP M no-native] {pref}")

    if penis_map:
        log(f"=== Male penis ({mode}) ===")
        for pref, style in penis_map.items():
            try:
                notes = copy_male_class(pack, out, pref, style, allow_reuse)
                report.extend(notes)
            except Exception as e:
                log(f"  [FAIL M] {pref}: {e}")

    readme = out / "README.txt"
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
        f"allow_reuse={allow_reuse}\n"
        f"entries={len(report)}\n\n"
        + "\n".join(report)
        + "\n\nUse with Midnight underwear hide. Meta Inject + PartCutGen.\n",
        encoding="utf-8",
    )
    log(f"Done. mode={mode} report_lines={len(report)} out={out}")
    return 0 if report else 1


if __name__ == "__main__":
    sys.exit(main())
