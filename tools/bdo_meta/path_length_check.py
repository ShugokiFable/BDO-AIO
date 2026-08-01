#!/usr/bin/env python3
"""
Check files_to_patch (or any folder) for Windows MAX_PATH issues.

Meta Injector / older Win32 APIs fail near 260 characters full path length.
Steam BDO under Program Files (x86) already uses ~70 chars before files_to_patch.

Exit 2 if any path >= --limit (default 240 warning threshold).
"""
from __future__ import annotations

import argparse
import pathlib
import sys


def log(m: str) -> None:
    print(m, flush=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True, help="Usually <PAZ>/files_to_patch")
    ap.add_argument("--limit", type=int, default=240, help="Warn if full path length >= this")
    ap.add_argument("--hard", type=int, default=260, help="Hard fail count if length >= this")
    ap.add_argument(
        "--delete-over",
        type=int,
        default=0,
        help="If >0, DELETE files with full path length >= this (dangerous; for recovery)",
    )
    args = ap.parse_args()
    root = pathlib.Path(args.root)
    if not root.is_dir():
        log(f"[FATAL] not a directory: {root}")
        return 1

    warn = []
    hard = []
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        n = len(str(p))
        if n >= args.hard:
            hard.append((n, p))
        elif n >= args.limit:
            warn.append((n, p))

    hard.sort(reverse=True)
    warn.sort(reverse=True)

    log(f"Root: {root}")
    log(f"Paths >= {args.hard} (hard): {len(hard)}")
    log(f"Paths >= {args.limit} (warn): {len(warn)}")
    for n, p in hard[:20]:
        log(f"  HARD {n}: {p}")
    if len(hard) > 20:
        log(f"  … +{len(hard) - 20} more hard")
    for n, p in warn[:10]:
        log(f"  WARN {n}: {p}")

    deleted = 0
    if args.delete_over > 0:
        victims = [p for n, p in hard + warn if n >= args.delete_over]
        log(f"Deleting {len(victims)} files with path length >= {args.delete_over} ...")
        for p in victims:
            try:
                p.unlink()
                deleted += 1
            except OSError as e:
                log(f"  [FAIL delete] {p}: {e}")
        log(f"Deleted: {deleted}")

    if hard:
        log("")
        log("FIX tips:")
        log("  1. Turn OFF XYZW collections in AIO Midnight options (main cause).")
        log("  2. Delete files_to_patch\\_midnight_xyzw\\_01_xyzw_collections")
        log("  3. Re-deploy Midnight without collections, re-run PartCutGen + Meta Injector.")
        log("  4. Or move the game out of Program Files to a shorter path (e.g. D:\\BDO).")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
