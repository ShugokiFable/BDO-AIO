# BDO body / underwear mod ecosystem (research, 2026)

This is a field map for the AIO maintainers. It is **not** a download mirror of third-party NSFW content.

## What is still maintained

| Project | Status | Notes |
|---------|--------|--------|
| **[midnightxyzw/heisha](https://github.com/midnightxyzw/heisha)** | **Best current** | Last public release **0.4.1 (2025-12-25)**. Underwear hide + armor hide + nude base through **Seraph**. Regenerates from live PAZ when patches break injects. |
| **Suzu (Undertow)** | Historical / per-class | Original high-quality nude bodies. Many class pages old; later classes often only appear via Midnight + Discord ports. |
| **TheGreatSage (Discord)** | Active mesh fixer | Improved Suzu meshes; Midnight credits them for body mesh fixes + Seraph mesh. |
| **Resorepless 3.6f** | **Abandoned (~2018)** | Missing modern classes. **Do not use** as primary base. Midnight removed it in v0.2.0 (2024). |
| **Meta Injector + PartCutGen** | Still required | End-user inject path. PartCutGen mandatory since ~2024 (no hard-coded partcut). |
| **PACtool / 3D Converter / PAZ Browser** | Creator tools | Mesh export/import, not needed for pure “hide underwear” regen. |

## Class coverage (heisha / your pack, through Seraph)

From heisha `src/README.md` class IDs (female / male). Your local `pack` underwear set includes the prefixes below.

### Female (underwear hide + nude base intended)

| ID | Class | Notes |
|----|--------|--------|
| PHW | Sorceress | |
| PEW | Ranger | |
| PBW | Tamer | |
| PVW | Valkyrie | |
| PWW | Witch | |
| PGW | Guardian | |
| PKW | Old Maehwa (legacy outfits) | |
| PNW | Kunoichi | |
| PLW | **Shai** | **Explicitly excluded** by Midnight (no nude/underwear path) |
| PDW | Dark Knight | |
| PCW | Mystic | |
| PSW | Lahn | |
| PPW | Nova | |
| PKWW | Maehwa | |
| PFW | Corsair | |
| PQW | Drakania | |
| PKOW | Maegu | |
| PMYF | Woosa | |
| PNYW | Scholar | |
| PWGE | Deadeye | Added ~0.3.0 (Dec 2024) |
| PDKL | **Seraph** | Added **0.4.0** (Dec 2025) |

### Male (underwear / armor hide; nude less complete)

Warrior, Berserker (+beast), Musa, Wizard (old/revamp), Archer, Ninja, Striker, Hashashin, Sage, etc. (see heisha table).

### After a game patch

If Meta Injector fails on `.pac` files, regenerators are expected to:

```text
# inside heisha dev env (setupenv.cmd)
run.cmd -i <game\PAZ> -o .\PAZ\midnight_xyzw -m all
```

Then redeploy via AIO / midnight_xyzw.cmd.

As of this research pass, **Seraph is the newest PC class** in public NA material; no later class body pack was found as a public drop-in.

## Why old “everything is abandoned” feeling is only half true

- **Single monolithic nude pack** (Resorepless style) died.
- **Pipeline** moved to: **script-generated hide meshes** + **ported Suzu/TheGreatSage nude** + **PartCutGen**.
- Gaps appear when:
  1. A **new class** ships and Midnight has not cut a release yet.
  2. A **new pearl outfit** adds meshes not covered by armor-remove patterns.
  3. **Shai** (policy skip).
  4. **Male nude** quality lags females.

## Can we make underwear removal ourselves?

### Underwear hide only — **yes, feasible**

Underwear removal in Midnight is **not** a full custom body. Local pack samples show underwear `.pac` stubs ≈ **1 KB** (empty/dummy mesh) plus blank/transparent AO `.dds` textures.

**Pipeline to support a new class when game files exist:**

1. **Locate class underwear assets** in live client (names like `p???_*_uw_*.pac` / textures under `character\`).
2. **List winners** via Meta / PAZ index (or regenerate with heisha `run.cmd` against live PAZ).
3. Emit **dummy PAC + blank texture** overrides into `files_to_patch`.
4. Run **PartCutGen** then **Meta Injector**.

**Tools needed:**

| Need | For underwear hide | For quality nude body |
|------|--------------------|------------------------|
| Live game PAZ + `pad00000.meta` | **Yes** | Yes |
| Meta Injector + PartCutGen | **Yes** | Yes |
| Dummy/blank PAC + blank DDS templates | **Yes** | Partial |
| heisha `src` regenerator (`run.cmd`) | **Best path** | Armor hide + lists |
| PAZ Browser / QuickBMS extract | Helpful | Helpful |
| PACtool + 3D Converter + Blender | **No** | **Yes** |
| Artist time (weights, UVs, jiggle) | **No** | **Yes** |

You do **not** need a full PAZ extract of the whole game just to hide underwear if you can resolve filenames from meta + inject overrides — but **you do need the live client** so names/sizes match the current patch.

### “Reuse another class body” for missing nude — **technically possible, usually ugly**

Copying `pww_00_nude` → new class prefix:

- Skeleton / bone names / proportions differ.
- Common results: **stretched limbs, broken cloth cut, neck seams, missing parts**.
- Acceptable only as a **temporary placeholder** until a real mesh (Suzu/TheGreatSage style) exists.

### Full custom nude for a new class — **not a pure “script me a body” job**

Requires mesh work, skinning, textures, part-cut tuning, per-outfit armor-cut fixes. That is creator work + the tools above, not something the AIO menu can invent from nothing.

## Other tools worth knowing (not all bundled)

| Tool | Role |
|------|------|
| Meta Injector | Apply `files_to_patch` |
| PartCutGen | Rebuild part-cut exclusion (required) |
| PAZ Browser | Browse/extract PAZ content |
| PACtool | PAC ↔ DAE mesh pipeline |
| 3D Converter | Mesh conversion helper used by old kits |
| NVIDIA Profile Inspector | Driver profile (bundled in AIO) |
| OptiScaler | **Experimental** upscale inject (NOT SAFE) |
| RenoDX / ReShade addon | HDR/post — different category |

## Community / legal

- NSFW BDO content is mostly **Undertow + private Discord**, not Reddit (subreddit bans lewd images).
- Redistributing full nude packs on GitHub Releases can hit **DMCA / ToS** issues; keep credits; prefer linking generators + user-supplied packs.
- Client mods always risk **bans / patch breaks**.

## Practical recommendation for BDO-AIO

1. Keep shipping / pointing at **heisha ≥ 0.4.1** for body/underwear through Seraph.
2. After each major BDO patch: regenerate with heisha `run.cmd` if inject fails.
3. For a **brand-new class** before Midnight updates: first ship **underwear-only dummy** regen against live PAZ; defer nude mesh until a real body exists.
4. Do **not** promise stealth / anti-cheat evasion.

## Sources

- https://github.com/midnightxyzw/heisha (README + PAZ notes + commits through 2025-12-25)
- Local pack inventory under `pack/midnight_xyzw` (class prefixes, dummy underwear PAC sizes)
- Undertow historical Suzu threads/downloads (older class-by-class bodies)
