#!/usr/bin/env python3
"""
Scan a BDO PAZ folder for stock vs Meta-Injector-modded state + AIO staged packs.

Signals (Meta Injector / BDO Toolkit):
  - Backups named pad00000[{ver}][{stamp}].meta.backup next to pad00000.meta
  - Current meta vs latest backup (byte hash) → MODDED if different after inject
  - files_to_patch inventory (AIO folders + total files)
  - Optional experimental DLL markers in game root (parent of PAZ)

Exit 0 always when scan completes (status is informational).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys
from datetime import datetime, timezone

# AIO-known staged package prefixes under files_to_patch
AIO_PREFIXES = (
    "_body_size_limits",
    "_slot_hide_",
    "_pubic_hair_",
    "_censorship_",
    "_genital_",
)

BACKUP_RE = re.compile(
    r"^pad00000\[(?P<ver>[^\]]*)\]\[(?P<tag>[^\]]*)\]\.meta\.backup$",
    re.IGNORECASE,
)

EXPERIMENTAL_MARKERS = (
    "BDO-AIO-EXPERIMENTAL-DLSS.txt",
    "OptiScaler.ini",
    "OptiScaler.dll",
    "dxgi.dll",  # may be stock or proxy — only count with marker
)


def log(m: str) -> None:
    print(m, flush=True)


def sha256_file(path: pathlib.Path, limit: int | None = None) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        if limit is None:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        else:
            h.update(f.read(limit))
    return h.hexdigest()


def find_backups(paz: pathlib.Path) -> list[dict]:
    out = []
    for p in paz.iterdir():
        if not p.is_file():
            continue
        m = BACKUP_RE.match(p.name)
        if not m:
            # also accept plain *.meta.backup
            if p.name.lower().endswith(".meta.backup"):
                out.append(
                    {
                        "path": str(p),
                        "name": p.name,
                        "ver": "?",
                        "tag": "?",
                        "size": p.stat().st_size,
                        "mtime": datetime.fromtimestamp(p.stat().st_mtime, tz=timezone.utc).isoformat(),
                    }
                )
            continue
        st = p.stat()
        out.append(
            {
                "path": str(p),
                "name": p.name,
                "ver": m.group("ver"),
                "tag": m.group("tag"),
                "size": st.st_size,
                "mtime": datetime.fromtimestamp(st.st_mtime, tz=timezone.utc).isoformat(),
            }
        )
    # newest first
    out.sort(key=lambda x: x["mtime"], reverse=True)
    return out


def inventory_files_to_patch(ftp: pathlib.Path) -> dict:
    if not ftp.is_dir():
        return {"exists": False, "total_files": 0, "aio_packages": [], "other_top": []}
    aio = []
    other = []
    total = 0
    for child in sorted(ftp.iterdir(), key=lambda p: p.name.lower()):
        if child.name.startswith("."):
            continue
        nfiles = 0
        if child.is_dir():
            nfiles = sum(1 for _ in child.rglob("*") if _.is_file())
        elif child.is_file():
            nfiles = 1
        total += nfiles
        is_aio = any(
            child.name == pref.rstrip("_") or child.name.startswith(pref)
            for pref in AIO_PREFIXES
        )
        entry = {"name": child.name, "files": nfiles, "is_dir": child.is_dir()}
        if is_aio:
            aio.append(entry)
        else:
            # Midnight deploy is usually loose character/ tree or _00_* packs
            other.append(entry)
    return {
        "exists": True,
        "total_files": total,
        "aio_packages": aio,
        "other_top": other[:40],
        "other_top_count": len(other),
    }


def experimental_status(game_root: pathlib.Path) -> dict:
    if not game_root.is_dir():
        return {"checked": False, "installed": False, "markers": []}
    markers = []
    for name in EXPERIMENTAL_MARKERS:
        p = game_root / name
        if p.is_file():
            markers.append(name)
    # proxy heuristics: marker file is authoritative
    installed = (game_root / "BDO-AIO-EXPERIMENTAL-DLSS.txt").is_file()
    if not installed and (game_root / "OptiScaler.ini").is_file():
        installed = True
        markers.append("OptiScaler.ini (no marker file)")
    return {"checked": True, "installed": installed, "markers": markers}


def classify_meta(
    meta_path: pathlib.Path,
    backups: list[dict],
) -> dict:
    """
    STOCK     — no inject backups; treat as stock (or never injected with this injector)
    MODDED    — backup exists and current meta hash != latest backup hash
    RESTORED  — backup exists and current meta matches latest backup (after Restore Backup)
    UNKNOWN   — meta missing / unreadable
    """
    if not meta_path.is_file():
        return {
            "state": "UNKNOWN",
            "detail": "pad00000.meta missing",
            "meta_sha256": None,
            "meta_size": None,
            "latest_backup": None,
            "matches_latest_backup": None,
        }

    st = meta_path.stat()
    meta_hash = sha256_file(meta_path)
    meta_size = st.st_size
    meta_mtime = datetime.fromtimestamp(st.st_mtime, tz=timezone.utc).isoformat()

    if not backups:
        return {
            "state": "STOCK",
            "detail": "No Meta Injector *.meta.backup found — meta looks unpatched by injector (or backups deleted)",
            "meta_sha256": meta_hash,
            "meta_size": meta_size,
            "meta_mtime": meta_mtime,
            "latest_backup": None,
            "matches_latest_backup": None,
        }

    latest = backups[0]
    bpath = pathlib.Path(latest["path"])
    try:
        bhash = sha256_file(bpath)
    except OSError as e:
        return {
            "state": "UNKNOWN",
            "detail": f"Could not read backup: {e}",
            "meta_sha256": meta_hash,
            "meta_size": meta_size,
            "meta_mtime": meta_mtime,
            "latest_backup": latest,
            "matches_latest_backup": None,
        }

    match = meta_hash == bhash
    if match:
        state = "RESTORED"
        detail = (
            "Current pad00000.meta matches latest injector backup "
            f"({latest['name']}) — looks restored / not currently injected"
        )
    else:
        state = "MODDED"
        detail = (
            "Current pad00000.meta DIFFERS from latest injector backup "
            f"({latest['name']}) — Meta Injector patches are applied"
        )

    return {
        "state": state,
        "detail": detail,
        "meta_sha256": meta_hash,
        "meta_size": meta_size,
        "meta_mtime": meta_mtime,
        "latest_backup": latest,
        "latest_backup_sha256": bhash,
        "matches_latest_backup": match,
        "backup_count": len(backups),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Scan BDO PAZ for stock vs modded meta + AIO stage")
    ap.add_argument("--paz", required=True, help="Game PAZ folder (pad00000.meta inside)")
    ap.add_argument("--json", action="store_true", help="Emit JSON only")
    ap.add_argument(
        "--write-status",
        default="",
        help="Optional path to write BDO-AIO-paz-status.json (default: <PAZ>/BDO-AIO-paz-status.json if 'auto')",
    )
    args = ap.parse_args()

    paz = pathlib.Path(args.paz)
    meta = paz / "pad00000.meta"
    ftp = paz / "files_to_patch"
    game_root = paz.parent

    backups = find_backups(paz) if paz.is_dir() else []
    meta_info = classify_meta(meta, backups)
    ftp_info = inventory_files_to_patch(ftp)
    exp = experimental_status(game_root)

    # overall user-facing summary
    staged = ftp_info.get("total_files", 0) > 0
    meta_state = meta_info["state"]

    if meta_state == "MODDED" and staged:
        overall = "INJECTED + STAGED"
        overall_detail = "Meta is modded (injector applied) and files_to_patch still has content."
    elif meta_state == "MODDED" and not staged:
        overall = "INJECTED (no stage folder content)"
        overall_detail = "Meta is modded but files_to_patch is empty/missing — inject was applied earlier."
    elif meta_state in ("STOCK", "RESTORED") and staged:
        overall = "STAGED only (not injected yet)"
        overall_detail = "files_to_patch has mods ready — run Meta Injector to apply into pad00000.meta."
    elif meta_state == "RESTORED" and not staged:
        overall = "RESTORED / clean meta"
        overall_detail = "Meta matches injector backup; no staged packs."
    elif meta_state == "STOCK" and not staged:
        overall = "STOCK (clean)"
        overall_detail = "No injector backups and no files_to_patch content."
    else:
        overall = meta_state
        overall_detail = meta_info.get("detail", "")

    report = {
        "scanned_at": datetime.now(timezone.utc).isoformat(),
        "paz": str(paz),
        "overall": overall,
        "overall_detail": overall_detail,
        "meta": meta_info,
        "backups": backups,
        "files_to_patch": ftp_info,
        "experimental_dlss": exp,
    }

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        log("=== BDO PAZ STATUS SCAN ===")
        log(f"PAZ: {paz}")
        log("")
        log(f"OVERALL: {overall}")
        log(f"  {overall_detail}")
        log("")
        log(f"META: {meta_info['state']}")
        log(f"  {meta_info.get('detail', '')}")
        if meta_info.get("meta_size"):
            log(f"  pad00000.meta size={meta_info['meta_size']}  mtime={meta_info.get('meta_mtime')}")
            log(f"  sha256={meta_info.get('meta_sha256')}")
        log(f"  injector backups found: {len(backups)}")
        for b in backups[:5]:
            log(f"    - {b['name']}  ({b['size']} bytes, {b['mtime']})")
        if len(backups) > 5:
            log(f"    … +{len(backups) - 5} more")
        log("")
        log("FILES_TO_PATCH (staged for inject):")
        if not ftp_info["exists"]:
            log("  (missing)")
        else:
            log(f"  total files: {ftp_info['total_files']}")
            if ftp_info["aio_packages"]:
                log("  AIO packages:")
                for p in ftp_info["aio_packages"]:
                    log(f"    - {p['name']}  ({p['files']} files)")
            else:
                log("  AIO packages: (none detected by name)")
            if ftp_info["other_top"]:
                log("  Other top-level (e.g. Midnight):")
                for p in ftp_info["other_top"][:15]:
                    log(f"    - {p['name']}  ({p['files']} files)")
                if ftp_info.get("other_top_count", 0) > 15:
                    log(f"    … +{ftp_info['other_top_count'] - 15} more")
        log("")
        log("EXPERIMENTAL client inject (game root):")
        if exp.get("installed"):
            log("  INSTALLED  markers: " + ", ".join(exp.get("markers") or []))
        else:
            log("  not installed (no AIO experimental marker)")
        log("")
        log("Legend:")
        log("  STOCK    = no Meta Injector backup; treat as stock meta")
        log("  MODDED   = meta differs from latest *.meta.backup (patches applied)")
        log("  RESTORED = meta matches latest backup (injector Restore Backup)")
        log("  STAGED   = files under files_to_patch ready for inject")

    write_path = args.write_status
    if write_path == "auto":
        write_path = str(paz / "BDO-AIO-paz-status.json")
    if write_path:
        pathlib.Path(write_path).write_text(json.dumps(report, indent=2), encoding="utf-8")
        if not args.json:
            log(f"Wrote status: {write_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
