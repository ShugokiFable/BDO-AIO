#!/usr/bin/env python3
"""Patch verified GameOption keys without replacing the user's complete file."""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import tempfile


_LINE = re.compile(
    rb"^([ \t]*)([A-Za-z][A-Za-z0-9_]*)([ \t]*=[ \t]*)(.*?)([ \t]*)(\r?\n)?$"
)


def read_profile(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for number, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"{path.name}:{number}: expected key = value")
        key, value = (part.strip() for part in line.split("=", 1))
        folded = key.lower()
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", key) or not value:
            raise ValueError(f"{path.name}:{number}: invalid key/value")
        if folded in values:
            raise ValueError(f"{path.name}:{number}: duplicate key {key}")
        values[folded] = value
    if not values:
        raise ValueError(f"{path.name}: profile is empty")
    return values


def patched_bytes(source: bytes, values: dict[str, str]) -> tuple[bytes, list[str]]:
    lines = source.splitlines(keepends=True)
    seen: dict[str, int] = {}
    changed: list[str] = []
    output: list[bytes] = []
    for line in lines:
        match = _LINE.match(line)
        if not match:
            output.append(line)
            continue
        key = match.group(2).decode("ascii")
        folded = key.lower()
        if folded in seen:
            raise ValueError(f"GameOption.txt contains duplicate key {key}")
        seen[folded] = 1
        if folded not in values:
            output.append(line)
            continue
        replacement = values[folded].encode("ascii")
        old = match.group(4).strip()
        output.append(match.group(1) + match.group(2) + match.group(3) + replacement + match.group(5) + (match.group(6) or b""))
        if old != replacement:
            changed.append(key)
    missing = sorted(set(values) - set(seen))
    if missing:
        raise ValueError("GameOption.txt is missing required current-client keys: " + ", ".join(missing))
    return b"".join(output), changed


def apply(source: pathlib.Path, profile: pathlib.Path, output: pathlib.Path | None) -> dict[str, object]:
    original = source.read_bytes()
    patched, changed = patched_bytes(original, read_profile(profile))
    if output is not None:
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=output.name + ".", suffix=".tmp", delete=False) as temp:
            temp.write(patched)
            temp.flush()
            os.fsync(temp.fileno())
            temp_path = pathlib.Path(temp.name)
        try:
            os.replace(temp_path, output)
        finally:
            temp_path.unlink(missing_ok=True)
    return {
        "source_bytes": len(original),
        "output_bytes": len(patched),
        "changed": changed,
        "preserved_lines": len(original.splitlines()) - len(changed),
        "written": str(output) if output else None,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--game-option", required=True, type=pathlib.Path)
    parser.add_argument("--profile", required=True, type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, help="omit for a read-only validation/dry run")
    args = parser.parse_args()
    print(json.dumps(apply(args.game_option, args.profile, args.output), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
