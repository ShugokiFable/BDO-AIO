# BDO body / underwear mod ecosystem (research, 2026)

This is a field map for the AIO maintainers. It is **not** a download mirror of third-party NSFW content.

## What is still maintained

| Project | Status | Notes |
|---------|--------|--------|
| **[midnightxyzw/heisha](https://github.com/midnightxyzw/heisha)** | **Best current** | Latest public release **0.4.1 (2025-12-25)**; upstream main/tag still match. Its generator discovers armor/underwear names from live PAZ metadata, so AIO 2.0.6 regenerated current Wukong hides even though the bundled 0.4.1 output predates Wukong. |
| **Suzu (Undertow)** | Historical / per-class | Original high-quality nude bodies. Many class pages old; later classes often only appear via Midnight + Discord ports. |
| **TheGreatSage (Discord)** | Active mesh fixer | Improved Suzu meshes; Midnight credits them for body mesh fixes + Seraph mesh. |
| **Resorepless 3.6f** | **Abandoned (~2018)** | Missing modern classes. **Do not use** as primary base. Midnight removed it in v0.2.0 (2024). |
| **Meta Injector 1.4.1 + PartCutGen 1.1.0** | Current heisha workflow | End-user inject path. The copies bundled in AIO are byte-identical to the current heisha 0.4.1 PAZ pack. |
| **Meta Patcher 1.1.0** | Region-specific | The author's FAQ says official regions other than NA/EU need its correcting pass. The inspected install is `TYPE=NA`, so AIO skips it. Latest public author release remains 1.1.0 (2022-08-11). |
| **PACtool / 3D Converter / PAZ Browser** | Creator tools | Mesh export/import, not needed for pure “hide underwear” regen. |

## Class coverage (heisha / AIO 2.0.6 live regeneration)

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

Warrior, Berserker (+beast), Musa, Wizard (old/revamp), Archer, Ninja, Striker, Hashashin, Sage, Dosa (`31_prsa`), and Wukong (`34_pgms`) are present in the regenerated hide data. Wukong contributes 26 underwear files and 553 armor files.

This does **not** establish male genital compatibility. Penis packs remain native-only for Warrior, Berserker, Musa, Wizard, Ninja, and Striker. Dosa and Wukong receive no borrowed male body.

### After a game patch

If Meta Injector fails on `.pac` files, regenerators are expected to:

```text
# inside heisha dev env (setupenv.cmd)
run.cmd -i <game\PAZ> -o .\PAZ\midnight_xyzw -m all
```

Then redeploy via AIO / midnight_xyzw.cmd.

As of this research pass, Wukong is present in the live NA client and official class roster. No verified Wukong nude/genital body pack was found as a public drop-in; only armor/underwear hide paths were safely regenerated.

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
| NVIDIA Profile Inspector 3.0.2.1 | Current stable driver-profile tool bundled in AIO; 3.0.2.2 is a prerelease, so it is not an automatic upgrade. |
| OptiScaler 0.9.4 | Current stable official bundle; **experimental and unsupported for BDO**. AIO no longer layers DLSS Enabler, zzDLL swaps, or DirectStorage over it. |
| RenoDX / ReShade addon | HDR/post — different category |

## Community / legal

- NSFW BDO content is mostly **Undertow + private Discord**, not Reddit (subreddit bans lewd images).
- Redistributing full nude packs on GitHub Releases can hit **copyright / ToS** issues. Undertow reported removing specified BDO posts after a March 2026 request made on Pearl Abyss's behalf; keep public source releases separate from private full local packages.
- Client mods always risk **bans / patch breaks**.

## Practical recommendation for BDO-AIO

1. Keep **heisha 0.4.1** as the generator source, but regenerate armor/underwear names from current live metadata after new classes or major patches.
2. After each major BDO patch: regenerate with heisha `run.cmd` if inject fails.
3. For a **brand-new class** before Midnight updates: first ship **underwear-only dummy** regen against live PAZ; defer nude mesh until a real body exists.
4. Do **not** promise stealth / anti-cheat evasion.

## Sources

- https://github.com/midnightxyzw/heisha (README + PAZ notes + commits through 2025-12-25)
- https://www.undertow.club/downloads/meta-patcher.7829/field?field=FAQ (NA/EU exclusion)
- https://www.undertow.club/threads/announcement-regarding-black-desert-online-modding-posts.28370/ (March 2026 copyright-removal announcement)
- https://www.naeu.playblackdesert.com/en-us/GameInfo/Class?classType=33 (current official class roster)
- Local pack inventory under `pack/midnight_xyzw` (class prefixes, dummy underwear PAC sizes)
- Undertow historical Suzu threads/downloads (older class-by-class bodies)
