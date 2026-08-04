#!/usr/bin/env python3
"""Resolve each female class's real nude body PAC and the texture atlas it references.

Measured on the Midnight pack: 13 of 19 female nude PACs reference ONE texture,
`PHW_01_Nude_0001`. Only Tamer, Guardian, Dark Knight, Corsair, Ranger and Witch
own a private atlas. That is why per-class pubic hair "did not work": styling the
shared DDS styles every class riding it, no matter what the class filter said.

The fix is a class-private material alias. Each PAC embeds its atlas name exactly
once, so it can be renamed in place with a same-byte-length token, letting a class
point at its own copy of the texture. Nothing here guesses: the atlas is read out
of the PAC, never inferred from a filename or a donor table.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from class_coverage import FEMALE_CLASSES

# Stems look like PHW_01_Nude_0001 / PBW_00_Nude_0001 (mixed case in the PAC).
NUDE_STEM = re.compile(rb"([A-Za-z]{2,5}_\d{2}_[Nn]ude_\d{4})")

# Explicit source precedence -- never filesystem/glob order. TheGreatSage is the
# primary clean source; Suzu supplies the classes it does not carry (Tamer, Deadeye).
SOURCE_PRECEDENCE = ("_00_thegreatsage_nude", "_00_suzu_nude")

# Shai is excluded from nude/genital work by Midnight policy.
SKIPPED_PREFIXES = frozenset({"plw"})


@dataclass(frozen=True)
class ClassBody:
    prefix: str
    folder: str
    pac_path: Path
    internal_pac: str
    atlas_stem: str  # exactly as embedded, original case
    stem_offset: int
    source: str

    @property
    def atlas_key(self) -> str:
        return self.atlas_stem.lower()


def read_pac_atlas(pac_bytes: bytes) -> tuple[str, int]:
    """Return the single embedded nude atlas stem and its offset.

    Raises if a PAC has zero or several distinct stems -- an ambiguous PAC must
    never be renamed on a guess.
    """
    matches = list(NUDE_STEM.finditer(pac_bytes))
    if not matches:
        raise ValueError("no nude atlas stem found")
    distinct = {m.group(1) for m in matches}
    if len(distinct) != 1:
        names = ", ".join(sorted(d.decode("ascii", "replace") for d in distinct))
        raise ValueError(f"ambiguous PAC references several nude atlases: {names}")
    if len(matches) != 1:
        raise ValueError(f"atlas stem occurs {len(matches)} times; expected exactly once")
    return matches[0].group(1).decode("ascii"), matches[0].start()


def _internal_path(pac: Path) -> str:
    parts = pac.parts
    if "character" not in parts:
        raise ValueError(f"{pac} is not under a character/ tree")
    return "/".join(parts[parts.index("character") :])


def resolve_class_bodies(base_roots: list[Path]) -> tuple[dict[str, ClassBody], list[str]]:
    """Map class prefix -> its authoritative nude body PAC, using explicit precedence."""
    ranked: dict[str, tuple[int, Path, str]] = {}
    for root in base_roots:
        if not root.exists():
            continue
        source = root.name
        rank = (
            SOURCE_PRECEDENCE.index(source)
            if source in SOURCE_PRECEDENCE
            else len(SOURCE_PRECEDENCE)
        )
        for pac in root.rglob("*.pac"):
            parts = pac.parts
            if "1_pc" not in parts or "nude" not in parts:
                continue
            folder = parts[parts.index("1_pc") + 1]
            prefix = folder.split("_", 1)[1] if "_" in folder else folder
            if prefix in SKIPPED_PREFIXES or prefix not in FEMALE_CLASSES:
                continue
            current = ranked.get(prefix)
            if current is None or rank < current[0]:
                ranked[prefix] = (rank, pac, source)

    bodies: dict[str, ClassBody] = {}
    problems: list[str] = []
    for prefix, (_, pac, source) in sorted(ranked.items()):
        try:
            stem, offset = read_pac_atlas(pac.read_bytes())
        except ValueError as exc:
            problems.append(f"{prefix}: {pac.name}: {exc}")
            continue
        folder = pac.parts[pac.parts.index("1_pc") + 1]
        bodies[prefix] = ClassBody(
            prefix=prefix,
            folder=folder,
            pac_path=pac,
            internal_pac=_internal_path(pac),
            atlas_stem=stem,
            stem_offset=offset,
            source=source,
        )
    return bodies, problems


def atlas_owners(bodies: dict[str, ClassBody]) -> dict[str, list[str]]:
    """atlas key -> every class prefix that renders from it."""
    owners: dict[str, list[str]] = {}
    for prefix, body in bodies.items():
        owners.setdefault(body.atlas_key, []).append(prefix)
    for key in owners:
        owners[key].sort()
    return owners


def alias_stem(atlas_stem: str, index: int) -> str:
    """Class-private stem with the SAME byte length as the atlas stem it replaces.

    `PHW_01_Nude_0001` -> `x07_01_Nude_0001`. The prefix width is taken from the
    source stem, so the rename can be applied without resizing the PAC.
    """
    if index < 1:
        raise ValueError("alias index starts at 1")
    prefix, _, suffix = atlas_stem.partition("_")
    width = len(prefix)
    if width < 2:
        raise ValueError(f"atlas prefix {prefix!r} is too short to alias")
    token = "x" + str(index).zfill(width - 1)
    if len(token) != width:
        raise ValueError(f"alias index {index} does not fit a {width}-character prefix")
    out = f"{token}_{suffix}"
    if len(out.encode("ascii")) != len(atlas_stem.encode("ascii")):
        raise ValueError("alias length does not match the source stem")
    return out


def replace_pac_stem(pac_bytes: bytes, old_stem: str, new_stem: str) -> bytes:
    """Rename the embedded atlas, preserving total PAC length exactly."""
    old = old_stem.encode("ascii")
    new = new_stem.encode("ascii")
    if len(old) != len(new):
        raise ValueError(f"{old_stem} and {new_stem} differ in byte length")
    count = pac_bytes.count(old)
    if count != 1:
        raise ValueError(f"expected exactly one {old_stem}, found {count}")
    out = pac_bytes.replace(old, new, 1)
    if len(out) != len(pac_bytes):
        raise ValueError("PAC length changed")
    return out


def texture_variants(texture_dir_files: list[Path], atlas_key: str) -> list[Path]:
    """Every shipped map for an atlas: the base plus _n / _w / _sp / _m siblings.

    The engine derives these from the material name, so an aliased class needs
    renamed copies of all of them or it loses its normal/detail maps.
    """
    out = []
    for path in texture_dir_files:
        name = path.name.lower()
        if not name.endswith(".dds"):
            continue
        stem = name[:-4]
        if stem == atlas_key or stem.startswith(atlas_key + "_"):
            out.append(path)
    return sorted(out, key=lambda p: p.name.lower())
