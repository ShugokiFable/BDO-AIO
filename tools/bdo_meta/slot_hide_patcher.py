#!/usr/bin/env python3
"""
Hide optional equipment slots by dummy-PAC injection (Resorepless-style granular toggles).

Slots:
  gloves   - character model folders with 11_hand, or _hand_ in name
  boots    - 12_foot / 14_sho / _sho_ / _foot_
  helmets  - 13_hel / _hel_
  weapons  - path contains /weapon/
  stockings- path/name with stocking (best-effort)

Uses live PAZ meta (ICE) + dummy.pac. Writes under files_to_patch/_slot_hide_<slot>/
Also writes .partcutdesc_exclusions.txt lines for PartCutGen.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

# reuse meta + extract helpers from body_size_patcher
from body_size_patcher import IceDecipher, MetaFile


SLOT_RULES = {
    "gloves": {
        "folder_any": ["11_hand"],
        "name_any": ["_hand_"],
        "name_not": ["_uw_"],
    },
    "boots": {
        "folder_any": ["12_foot", "14_sho"],
        "name_any": ["_sho_", "_foot_"],
        "name_not": ["_uw_"],
    },
    "helmets": {
        "folder_any": ["13_hel"],
        "name_any": ["_hel_"],
        "name_not": ["_uw_", "hair"],
    },
    "weapons": {
        "folder_any": ["/weapon/", "\\weapon\\", "/weapon"],
        "name_any": [],
        "name_not": [],
    },
    "stockings": {
        "folder_any": ["stocking", "stockings"],
        "name_any": ["stocking", "_stk_", "_stock"],
        "name_not": [],
    },
}


def log(msg: str) -> None:
    print(msg, flush=True)


def match_slot(block, slot: str) -> bool:
    rules = SLOT_RULES[slot]
    folder = (block.folderName or "").replace("\\", "/").lower()
    name = (block.fileName or "").lower()
    if not name.endswith(".pac"):
        return False
    # only player character models
    if "1_pc" not in folder and "1_pc" not in folder.replace("\\", "/"):
        # folderName may already be relative
        if "character/model" not in folder:
            return False
        if "1_pc" not in folder:
            return False
    # skip Shai
    if "14_plw" in folder or name.startswith("plw_"):
        return False

    for bad in rules.get("name_not", []):
        if bad in name or bad in folder:
            return False

    for tok in rules.get("folder_any", []):
        if tok.replace("\\", "/").lower() in folder:
            return True
    for tok in rules.get("name_any", []):
        if tok.lower() in name:
            return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--paz", required=True)
    ap.add_argument("--out", default="", help="files_to_patch root (default: PAZ/files_to_patch)")
    ap.add_argument(
        "--slots",
        required=True,
        help="Comma list: gloves,boots,helmets,weapons,stockings",
    )
    ap.add_argument("--gender", choices=["F", "M", "B"], default="B")
    ap.add_argument(
        "--classes",
        default="",
        help="Optional comma list of class prefixes to limit hide "
        "(e.g. phw,pdkl,phm). Empty = all classes matching gender.",
    )
    args = ap.parse_args()

    slots = [s.strip().lower() for s in args.slots.split(",") if s.strip()]
    for s in slots:
        if s not in SLOT_RULES:
            log(f"[FATAL] unknown slot: {s}")
            return 2
    class_filter = [c.strip().lower() for c in args.classes.split(",") if c.strip()]

    paz = pathlib.Path(args.paz)
    tool_dir = pathlib.Path(__file__).resolve().parent
    dll = tool_dir / "ice_decipher.dll"
    dummy = tool_dir / "dummy.pac"
    if not dll.exists() or not dummy.exists():
        log("[FATAL] need ice_decipher.dll and dummy.pac next to this script")
        return 3

    ice = IceDecipher(dll)
    log(f"Reading meta from {paz} ...")
    try:
        meta = MetaFile(paz, ice)
    except FileNotFoundError as e:
        log(f"[FATAL] {e}")
        return 4
    except Exception as e:
        log(f"[FATAL] failed to read pad00000.meta: {e}")
        return 4
    if class_filter:
        log(f"Class filter: {', '.join(class_filter)}")

    out_root = pathlib.Path(args.out) if args.out else (paz / "files_to_patch")
    dummy_bytes = dummy.read_bytes()

    female_tokens = (
        "_phw", "_pew", "_pbw", "_pvw", "_pww", "_pgw", "_pkw", "_pnw", "_plw",
        "_pdw", "_pcw", "_psw", "_ppw", "_pkww", "_pfw", "_pqw", "_pkow", "_pmyf",
        "_pnyw", "_pwge", "_pdkl",
        "phw_", "pew_", "pbw_", "pvw_", "pww_", "pgw_", "pnw_", "pdw_", "pcw_",
        "psw_", "ppw_", "pkww", "pfw_", "pqw_", "pkow", "pmyf", "pnyw", "pwge", "pdkl",
    )
    male_tokens = (
        "_phm", "_pgm", "_pkm", "_pwm", "_pwmm", "_pnm", "_pcm", "_pam", "_ppm",
        "phm_", "pgm_", "pkm_", "pwm_", "pwmm", "pnm_", "pcm_", "pam_", "ppm_",
        "_pem", "pem_",
    )

    def matches_class_filter(path_l: str) -> bool:
        if not class_filter:
            return True
        for pref in class_filter:
            # folder ids like 33_pdkl or file names pdkl_00_...
            if f"_{pref}" in path_l or f"/{pref}" in path_l or path_l.startswith(pref) or f"{pref}_" in path_l:
                return True
            # folder segment 2_phw
            if f"_{pref}/" in path_l or f"_{pref}\\" in path_l:
                return True
        return False

    total = 0
    for slot in slots:
        out_dir = out_root / f"_slot_hide_{slot}"
        if out_dir.exists():
            # clean previous generated
            for p in out_dir.rglob("*"):
                if p.is_file():
                    p.unlink()
        out_dir.mkdir(parents=True, exist_ok=True)
        exclusion_lines = []
        count = 0
        for block in meta.fileBlocks:
            if not match_slot(block, slot):
                continue
            folder = (block.folderName or "").replace("\\", "/").lower()
            name = (block.fileName or "").lower()
            path_l = folder + "/" + name
            if not matches_class_filter(path_l):
                continue
            if args.gender == "F":
                if not any(t in path_l for t in female_tokens):
                    # weapons may not include class in folder the same way — still allow if female class folder id
                    if slot != "weapons" or not any(t.strip("_") in path_l for t in female_tokens):
                        if "1_pc/" in path_l:
                            # class folders like 2_phw
                            if not any(x in path_l for x in ("_phw", "_pew", "_pbw", "_pvw", "_pww", "_pgw", "_pnw", "_pdw", "_pcw", "_psw", "_ppw", "pkww", "_pfw", "_pqw", "pkow", "pmyf", "pnyw", "pwge", "pdkl", "22_pk", "27_pk", "28_pm", "29_pn", "32_pw", "33_pd")):
                                continue
            elif args.gender == "M":
                if not any(t in path_l for t in male_tokens):
                    if "1_pc/" in path_l and not any(
                        x in path_l
                        for x in ("_phm", "_pgm", "_pkm", "_pwm", "_pnm", "_pcm", "_pam", "_ppm", "_pem", "pwmm")
                    ):
                        continue

            rel = pathlib.Path(block.folderName) / block.fileName
            dest = out_dir / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(dummy_bytes)
            # partcut exclusion style path
            excl = str(rel).replace("\\", "/")
            if excl.startswith("character/model/"):
                excl = excl[len("character/model/") :]
            if excl.endswith(".pac"):
                excl = excl[:-4]
            exclusion_lines.append(excl)
            count += 1

        with open(out_dir / ".partcutdesc_exclusions.txt", "w", encoding="utf-8") as f:
            f.write("\n".join(exclusion_lines) + ("\n" if exclusion_lines else ""))
        with open(out_dir / ".README.txt", "w", encoding="utf-8") as f:
            f.write(
                f"Slot hide: {slot}\n"
                f"Models hidden: {count}\n"
                f"Gender filter: {args.gender}\n"
                f"Class filter: {', '.join(class_filter) if class_filter else 'ALL'}\n"
                "Run PartCutGen then Meta Injector.\n"
            )
        log(f"[{slot}] hid {count} .pac models -> {out_dir}")
        total += count

    log(f"Done. total_models={total}")
    return 0 if total > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
