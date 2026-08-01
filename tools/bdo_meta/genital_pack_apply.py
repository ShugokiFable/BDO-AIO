#!/usr/bin/env python3
"""
Apply LEGACY Resorepless genital packs (3D vagina female nudes / male penis nudes).

- female: copy 3D vagina nude PACs + related textures into character paths
- male: per-class penis style none|normal|hard — copy PAC as nude + as underwear override

These are 2018-era meshes. New classes (Seraph, Deadeye, Agent, …) are not included.
Skin-tone mismatch on penises is a known Resorepless limitation.
"""
from __future__ import annotations

import argparse
import pathlib
import shutil
import sys

# prefix -> game folder under character/model/1_pc/
FEMALE_PAC_FOLDERS = {
    "pbw": "5_pbw",
    "pcw": "16_pcw",
    "pdw": "15_pdw",
    "pew": "3_pew",
    "phw": "2_phw",
    "pkww": "22_pkww",
    "pnw": "13_pnw",
    "psw": "17_psw",
    "pvw": "7_pvw",
    "pww": "8_pww",
}

MALE_PAC_FOLDERS = {
    "phm": "1_phm",
    "pgm": "4_pgm",
    "pkm": "6_pkm",
    "pwm": "8_pwm",
    "pnm": "13_pnm",
    "pcm": "16_pcm",
}

MALE_CLASSES = ["warrior", "berserker", "musa", "wizard", "ninja", "striker"]
MALE_PREFIX = {
    "warrior": "phm",
    "berserker": "pgm",
    "musa": "pkm",
    "wizard": "pwm",
    "ninja": "pnm",
    "striker": "pcm",
}


def log(m: str) -> None:
    print(m, flush=True)


def prefix_of(name: str) -> str | None:
    n = name.lower()
    for p in sorted(list(FEMALE_PAC_FOLDERS) + list(MALE_PAC_FOLDERS), key=len, reverse=True):
        if n.startswith(p + "_"):
            return p
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack-root", required=True, help="tools/genital_packs")
    ap.add_argument("--out", required=True, help="files_to_patch/_genital_legacy")
    ap.add_argument("--female-3d-vagina", choices=["on", "off"], default="off")
    ap.add_argument(
        "--male-penis",
        default="none",
        help="Global default: none|normal|hard  OR per-class map warrior=hard,striker=normal",
    )
    args = ap.parse_args()

    pack = pathlib.Path(args.pack_root)
    out = pathlib.Path(args.out)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    copied = 0

    # Female 3D vagina nudes
    if args.female_3d_vagina == "on":
        fem_dir = pack / "female"
        tex_dir = pack / "texture"
        for pac in fem_dir.glob("*.pac"):
            pref = prefix_of(pac.name)
            if not pref or pref not in FEMALE_PAC_FOLDERS:
                log(f"  [SKIP female pac] {pac.name}")
                continue
            folder = FEMALE_PAC_FOLDERS[pref]
            dest_dir = out / "character" / "model" / "1_pc" / folder / "nude"
            dest_dir.mkdir(parents=True, exist_ok=True)
            # keep original nude filename
            shutil.copy2(pac, dest_dir / pac.name)
            # also as common uw override name if pattern fits
            base = pac.name.lower().replace("_noalpha", "")
            # e.g. pbw_00_nude_0001.pac -> pbw_00_uw_0001.pac
            uw_name = base.replace("_nude_", "_uw_")
            shutil.copy2(pac, dest_dir / uw_name)
            log(f"  [F] {pac.name} -> {folder}/nude/")
            copied += 2

        # textures + normals
        tex_out = out / "character" / "texture"
        tex_out.mkdir(parents=True, exist_ok=True)
        for dds in tex_dir.glob("*nude*.dds"):
            # female-ish: skip pure male small maps if only male prefixes
            n = dds.name.lower()
            if any(n.startswith(p + "_") for p in MALE_PAC_FOLDERS) and not any(
                n.startswith(p + "_") for p in FEMALE_PAC_FOLDERS
            ):
                continue
            if any(n.startswith(p + "_") for p in FEMALE_PAC_FOLDERS) or n.startswith("phw_") or n.startswith("pew_"):
                shutil.copy2(dds, tex_out / dds.name)
                log(f"  [F tex] {dds.name}")
                copied += 1

    # Male penis types
    # parse map
    penis_map: dict[str, str] = {}
    raw = args.male_penis.strip().lower()
    if raw in ("none", "normal", "hard"):
        if raw != "none":
            for c in MALE_CLASSES:
                penis_map[c] = raw
    else:
        for part in raw.split(","):
            part = part.strip()
            if not part or "=" not in part:
                continue
            k, v = part.split("=", 1)
            k, v = k.strip().lower(), v.strip().lower()
            if k in MALE_PREFIX and v in ("none", "normal", "hard"):
                if v != "none":
                    penis_map[k] = v

    for cls, style in penis_map.items():
        pref = MALE_PREFIX[cls]
        src_dir = pack / "male" / style
        pac_name = f"{pref}_00_nude_0001.pac"
        src = src_dir / pac_name
        if not src.is_file():
            log(f"  [MISS] {src}")
            continue
        folder = MALE_PAC_FOLDERS[pref]
        dest_dir = out / "character" / "model" / "1_pc" / folder / "nude"
        dest_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest_dir / pac_name)
        # underwear override (classic Resorepless rename)
        shutil.copy2(src, dest_dir / f"{pref}_00_uw_0001.pac")
        log(f"  [M {style}] {cls}: {pac_name}")
        copied += 2

        # male nude texture if present
        tex_out = out / "character" / "texture"
        tex_out.mkdir(parents=True, exist_ok=True)
        for tname in (f"{pref}_00_nude_0001.dds", f"{pref}_01_nude_0001.dds"):
            tsrc = pack / "texture" / tname
            if tsrc.is_file():
                shutil.copy2(tsrc, tex_out / tname)
                log(f"  [M tex] {tname}")
                copied += 1

    (out / "README.txt").write_text(
        "LEGACY genital pack (Resorepless-era meshes).\n"
        f"female_3d_vagina={args.female_3d_vagina}\n"
        f"male_penis={args.male_penis}\n"
        f"files_copied={copied}\n"
        "Known issues: skin tone mismatch on penises; missing new classes; may need PartCutGen.\n"
        "Use with underwear removal / nude mods. Meta Inject after deploy.\n",
        encoding="utf-8",
    )
    log(f"Done. files_copied={copied} out={out}")
    return 0 if copied else 1


if __name__ == "__main__":
    sys.exit(main())
