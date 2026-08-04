#!/usr/bin/env python3
"""Back up and restore the live BDO meta, and clean up injected PAZ files.

Meta Injector does not edit the game's original PAZ archives. It appends NEW
PAD*.PAZ files and rewrites pad00000.meta to point at them. So restoring a
pre-inject pad00000.meta returns the game to vanilla, and the appended PAZ files
become orphaned dead weight (they are still on disk, just referenced by nothing).

That is why "restore the meta" alone can look like it did nothing: the multi-GB
injected PAZ files stay behind, and any later inject re-applies from whatever is
still sitting in files_to_patch.

Safety rules:
  * A PAZ file is only ever deleted when it is BOTH unreferenced by the restored
    meta AND numbered above the highest number that meta references. Vanilla ships
    unreferenced low-numbered archives; those are never touched.
  * The oldest backup is treated as the pristine one -- a newer backup can be a
    backup of an already-injected meta.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import shutil
import sys
import tempfile

from body_size_patcher import IceDecipher, MetaFile

AIO_BACKUP_NAME = "pad00000.BDOAIO-VANILLA.meta"
AIO_BACKUP_INFO = "pad00000.BDOAIO-VANILLA.json"
PAZ_FILE = re.compile(r"^pad(\d{5})\.paz$", re.IGNORECASE)


def log(msg: str) -> None:
    print(msg, flush=True)


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def referenced_paz(meta_path: pathlib.Path, ice: IceDecipher) -> set[int]:
    """PAZ numbers a meta file points at. Parsed via a temp copy, name-independent."""
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-meta-"))
    try:
        shutil.copy2(meta_path, tmp / "pad00000.meta")
        meta = MetaFile(tmp, ice)
        return {b.pazNum for b in meta.fileBlocks}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def find_backups(paz: pathlib.Path) -> list[pathlib.Path]:
    """Meta Injector backups plus our own, oldest first."""
    found = [p for p in paz.glob("*.meta.backup") if p.is_file()]
    found.sort(key=lambda p: (p.stat().st_mtime, p.name))
    aio = paz / AIO_BACKUP_NAME
    if aio.is_file():
        found.insert(0, aio)
    return found


def orphan_paz(paz: pathlib.Path, keep: set[int]) -> list[pathlib.Path]:
    if not keep:
        return []
    ceiling = max(keep)
    out = []
    for path in paz.iterdir():
        match = PAZ_FILE.match(path.name)
        if not match:
            continue
        number = int(match.group(1))
        if number not in keep and number > ceiling:
            out.append(path)
    return sorted(out, key=lambda p: p.name.lower())


def human(n: int) -> str:
    return f"{n / (1024 ** 3):.2f} GB" if n >= 1024 ** 3 else f"{n / (1024 ** 2):.1f} MB"


def cmd_scan(paz: pathlib.Path, ice: IceDecipher) -> int:
    current = paz / "pad00000.meta"
    if not current.is_file():
        log(f"[FATAL] {current} not found")
        return 2

    cur_refs = referenced_paz(current, ice)
    log(f"current meta      : {current.stat().st_size} bytes, {len(cur_refs)} PAZ referenced, max {max(cur_refs)}")

    backups = find_backups(paz)
    if not backups:
        log("backups           : NONE FOUND")
        log("")
        log("[WARN] No pre-inject meta backup exists. Run the 'backup' command BEFORE")
        log("       your next inject, or a restore will need Steam/launcher repair.")
        return 1

    log(f"backups           : {len(backups)} (oldest first)")
    pristine = backups[0]
    for path in backups:
        refs = referenced_paz(path, ice)
        mark = "  <== will be used (oldest)" if path == pristine else ""
        log(f"  {path.name}  {len(refs)} PAZ, max {max(refs)}{mark}")

    keep = referenced_paz(pristine, ice)
    injected = sorted(cur_refs - keep)
    orphans = orphan_paz(paz, keep)
    total = sum(p.stat().st_size for p in orphans)
    log("")
    log(f"injected PAZ refs : {len(injected)}" + (f"  {injected[:6]}{'...' if len(injected) > 6 else ''}" if injected else ""))
    log(f"deletable PAZ     : {len(orphans)}  ({human(total)})")
    if not injected and not orphans:
        log("state             : VANILLA (meta references nothing extra)")
    else:
        log("state             : INJECTED")
    return 0


def cmd_backup(paz: pathlib.Path, ice: IceDecipher, force: bool) -> int:
    target = paz / AIO_BACKUP_NAME
    if target.is_file() and not force:
        log(f"[OK] AIO vanilla backup already exists: {target.name}")
        return 0

    backups = find_backups(paz)
    candidates = [p for p in backups if p.name != AIO_BACKUP_NAME]
    current = paz / "pad00000.meta"
    cur_refs = referenced_paz(current, ice)

    if candidates:
        source = candidates[0]
        why = "oldest Meta Injector backup"
    else:
        source = current
        why = "current meta"

    src_refs = referenced_paz(source, ice)
    if source == current and len(cur_refs) != len(src_refs):
        log("[FATAL] unexpected mismatch reading the current meta")
        return 3
    if source == current and (paz / "BDO_AIO_INJECT").exists():
        log("[FATAL] Refusing to snapshot the current meta as 'vanilla': this game has")
        log("        already been injected and no pre-inject backup exists.")
        log("        Verify/repair the game first, then run backup again.")
        return 4

    shutil.copy2(source, target)
    info = {
        "source": source.name,
        "reason": why,
        "sha256": sha256(target),
        "bytes": target.stat().st_size,
        "paz_referenced": len(src_refs),
        "paz_max": max(src_refs),
    }
    (paz / AIO_BACKUP_INFO).write_text(json.dumps(info, indent=2), encoding="utf-8")
    log(f"[OK] vanilla meta snapshot written from {why}: {target.name}")
    log(f"     sha256={info['sha256'][:16]}...  {len(src_refs)} PAZ referenced, max {info['paz_max']}")
    return 0


def cmd_restore(paz: pathlib.Path, ice: IceDecipher, delete_paz: bool, apply: bool) -> int:
    current = paz / "pad00000.meta"
    backups = find_backups(paz)
    if not backups:
        log("[FATAL] No backup found. Cannot restore without a pre-inject pad00000.meta.")
        log("        Use the Steam or Pearl Abyss launcher to verify/repair game files.")
        return 2

    pristine = backups[0]
    keep = referenced_paz(pristine, ice)
    cur_refs = referenced_paz(current, ice)
    injected = sorted(cur_refs - keep)
    missing = sorted(keep - cur_refs)
    orphans = orphan_paz(paz, keep)
    total = sum(p.stat().st_size for p in orphans)

    log(f"restore source    : {pristine.name}")
    log(f"  references      : {len(keep)} PAZ, max {max(keep)}")
    log(f"  current adds    : {len(injected)} injected PAZ reference(s)")
    if missing:
        log(f"  [WARN] backup references {len(missing)} PAZ the current meta does not.")
        log("         The backup may be older than a game patch; verify game files if the game misbehaves.")
    log(f"  deletable PAZ   : {len(orphans)} ({human(total)})")
    for path in orphans[:12]:
        log(f"      {path.name}  {human(path.stat().st_size)}")
    if len(orphans) > 12:
        log(f"      ... and {len(orphans) - 12} more")

    if not apply:
        log("")
        log("DRY RUN -- nothing changed. Re-run with --apply to perform the restore.")
        return 0

    safety = paz / "pad00000.pre-restore.meta"
    shutil.copy2(current, safety)
    log(f"  saved current meta as {safety.name} (in case you want it back)")

    shutil.copy2(pristine, current)
    log(f"[OK] pad00000.meta restored from {pristine.name}")

    removed = 0
    freed = 0
    if delete_paz:
        for path in orphans:
            size = path.stat().st_size
            try:
                path.unlink()
                removed += 1
                freed += size
            except OSError as exc:
                log(f"  [WARN] could not delete {path.name}: {exc}")
        log(f"[OK] removed {removed} injected PAZ file(s), freed {human(freed)}")
    elif orphans:
        log(f"[NOTE] {len(orphans)} injected PAZ file(s) left on disk ({human(total)}).")

    stage = paz / "BDO_AIO_INJECT"
    if stage.exists():
        shutil.rmtree(stage, ignore_errors=True)
        log("[OK] removed BDO_AIO_INJECT stage folder")

    after = referenced_paz(current, ice)
    if after == keep:
        log("[VERIFIED] restored meta references exactly the backup's PAZ set.")
        return 0
    log("[FATAL] post-restore verification failed")
    return 5


def main() -> int:
    ap = argparse.ArgumentParser(description="Back up / restore the live BDO meta")
    ap.add_argument("command", choices=["scan", "backup", "restore"])
    ap.add_argument("--paz", required=True)
    ap.add_argument("--apply", action="store_true", help="restore: actually write (default is a dry run)")
    ap.add_argument("--keep-paz", action="store_true", help="restore: leave injected PAZ files on disk")
    ap.add_argument("--force", action="store_true", help="backup: overwrite an existing AIO snapshot")
    args = ap.parse_args()

    paz = pathlib.Path(args.paz)
    if not paz.is_dir():
        log(f"[FATAL] not a folder: {paz}")
        return 2
    dll = pathlib.Path(__file__).resolve().parent / "ice_decipher.dll"
    if not dll.is_file():
        log(f"[FATAL] missing {dll}")
        return 2
    ice = IceDecipher(dll)

    if args.command == "scan":
        return cmd_scan(paz, ice)
    if args.command == "backup":
        return cmd_backup(paz, ice, args.force)
    return cmd_restore(paz, ice, not args.keep_paz, args.apply)


if __name__ == "__main__":
    sys.exit(main())
