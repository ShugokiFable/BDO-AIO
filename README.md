# BDO Modding AIO

**Current tree: v2.4.2. Latest release: [v2.4.2](https://github.com/ShugokiFable/BDO-AIO/releases/tag/v2.4.2).**
Windows menu for **Black Desert Online** client mods (PAZ / Meta Injector). **Not Skyrim.**

| Download | What you get |
|----------|----------------|
| **[Full offline `.7z` (recommended)](https://github.com/ShugokiFable/BDO-AIO/releases/latest)** | Scripts + **`pack\`** Midnight (~1.8 GB) + injectors - use this |
| This git `main` branch | Scripts + docs + tools only - **no** Midnight meshes unless you add `pack\` yourself |

Double-click **`START.bat`**.

---

## What it does

- **Midnight** deploy -> **PartCutGen** -> **Meta Injector**
- Underwear / armor hide, Suzu + TheGreatSage nude bases, optional **XYZW** skimpy collections
- **RESTORED** options: body Max ceilings, slot hide, pubic hair, censorship texture tiers, authored 3D vagina/penis
- **Vanilla restore safety** for body-size users (required before many game updates)
- GameOption max-quality profiles + NVIDIA `.nip` import
- Optional **EXPERIMENTAL / NOT SAFE** OptiScaler (menu **X**)

### Feature labels

| Label | Meaning |
|-------|---------|
| **MODERN** | Midnight / Meta Injector 2026 pipeline |
| **RESTORED** | Classic Resorepless-era feature, re-wired here |
| **EXPERIMENTAL** | From-scratch in this AIO only - not a classic restore |

Details: [`docs/FEATURE-LABELS.md`](docs/FEATURE-LABELS.md)

---

## Options (menu 2)

### MODERN
| Area | Options |
|------|---------|
| Gender | Female / Male / Both |
| Armor hide | All / Pearl / Free / Underwear-only |
| Collections | XYZW outfit packs on/off |

### RESTORED
| Area | Options |
|------|---------|
| **Body size (Max ceilings only)** | **Recommended** or per-axis **Custom** for five regions. Recommended: breasts X/Y/Z 1.55; thighs Y/Z 1.35; butt cheeks X/Y/Z 1.20; front pelvis/groin Y/Z 1.40; belly X 1.28 and Z 1.45. Thigh X, Pelvis X, and Belly Y stay untouched. Belly X is the sole intentional `HeightAxis` exception and can lengthen the lower torso. Only Max widens; Min/Default and higher class values remain. Restore once before an exact Recommended test if an older injection used breasts above 1.55 or widened Belly Y. |
| **Slot hide** | Gloves / boots / helmets / weapons / stockings |
| **Pubic hair** | Per-class styles; shared-atlas classes share one style; texture-only |
| **Censorship tiers** | Live-client **DXT5/DXT3** transparent blanks only. **Never DXT1**, never `*_cull*`, never 2018 stubs. Default **off**. Mesh/DXT1 built-in shorts need an XYZW remesh - see [`dev/TEXTURE-BLANKING-RULES.md`](dev/TEXTURE-BLANKING-RULES.md). |
| **3D vagina / penis** | Authored meshes only (10 female + 6 male). **Nude body PAC only** - does not overwrite Midnight underwear hide. |

### Not supported
| Area | Reason |
|------|--------|
| Genitals on classes with no authored mesh | Reusing another class's PAC steals that class's body *and* skin |
| Separate pubic style per shared-atlas class | 13 females share one texture; material rename made bodies invisible |
| Pubic hair on Corsair | No matching hair bin size |
| "Strip every outfit" via texture censorship | Safe only for DXT5 overlays; geometry shorts need remeshes |

### EXPERIMENTAL
| Area | Options |
|------|---------|
| Main menu **[X]** | OptiScaler / DLSS-style inject - **NOT SAFE** |

---

## Quick start

1. Download the latest **`BDO-AIO-v*-full.7z`** from [Releases](https://github.com/ShugokiFable/BDO-AIO/releases/latest) (or use this repo + fill `pack\`).
2. Extract to a short path; install **Python 3** if needed (`winget install Python.Python.3.12`).
3. **`START.bat`** -> **`9`** verify pack (~1.5-2 GB under `pack\`).
4. **`6`** Full Wizard (or configure options first) -> pick live **PAZ** (`pad00000.meta` inside).
5. Finish **PartCutGen**, then **Meta Injector**.
6. Optional: **`G`** GameOption . **`N`** NVIDIA .nip . **`X`** OptiScaler (not safe).
7. Before many official patches (launcher "wall" / stuck update): **`R` -> [1]** restore vanilla, let the launcher update, then re-apply AIO. **Body-size users:** do **not** log characters saved above stock Max while the client is vanilla - the game clamps and re-saves them (and can overwrite Beauty Album presets). Re-inject body size **first**, then play. AIO snapshots `Documents\Black Desert\Customization` into `backup\` on restore.
8. After a successful re-mod: **`H`** (heisha regen if inject breaks) then wizard again if needed. If an old censorship inject left holes: **`R`** restore vanilla meta, then re-apply (same body-size order as above).

**Requires separately:** [BDO Toolkit 1.3.0](https://www.undertow.club/) for Meta Injector 1.4.1 (not bundled).

---

## Why `pack/` is not in git

~1.8 GB / 40k+ files. Full offline payload ships as **`BDO-AIO-v*-full.7z`** on Releases. Source-only clone is incomplete without that archive or a local `pack\`.

---

## Layout (full offline tree)

```text
BDO-AIO/
  START.bat              <- run this
  bdo_aio.ps1
  README.md / CREDITS.md / CHANGELOG.md
  config.example.json    <- ship this; config.json is local-only
  pack/                  <- REQUIRED (~1.5-2 GB) in full releases
  graphics/              <- GameOption patches + nvidia .nip
  tools/                 <- bdo_meta, NPI, restored assets
  experimental/dlss/     <- optional, dangerous
  docs/                  <- feature labels / ecosystem notes
  dev/                   <- maintainer / AI notes (not needed to play)
```

---

## Pipeline

```text
NA/EU: Deploy -> PartCutGen -> Meta Injector -> Launch
Other regions: same, then Meta Patcher only if your region needs it (not bundled)
```

Meta Injector is launched via a short-path canonical stage so deep XYZW trees do not hit Windows path limits.

---

## Changelog (latest)

### v2.4.2

- Fixes mods silently reverting with the game reporting **corrupted files**. Nothing was corrupt: `pad00000.meta` carries the client version at offset 0, an inject left it reading an older version than the installed client, and the launcher re-downloaded ~1 GB of patches and replaced the meta.
- Meta Injector runs now record the client version **before** injecting and re-check it after. On a mismatch the AIO says **DO NOT LAUNCH**.
- New `verify` step proves every block resolves inside an archive that exists, before you launch.
- Restoring a vanilla snapshot taken on a **different client version** is now refused - it causes the same wipe.
- After a game patch: let the launcher finish, start the game once, re-snapshot vanilla, then re-apply.
- No body-slider values, packs, or pipeline behaviour changed from v2.4.1.

### v2.4.1

- Wording hotfix: **Butt cheeks** means cheek shape/roundness, while **Front pelvis/groin Z** is the main overall pelvis/ass-size control.
- No body-slider values or mappings changed from v2.4.0.

### v2.4.0
- Simplified body limits to **Recommended**, **Custom**, and **Keep current**.
- Five independent regions with 12 explicit axis ceilings, including separate butt cheeks and front pelvis/groin.
- Custom breast help explains X projection, Y width, Z height, stock 1.30/1.55/1.55 caps, and balanced/equal-additive examples.
- Schema-2 migration, Max-only enforcement, atomic generation, and read-only 75-descriptor validation.

### v2.3.1 candidate
- Fixes the last Lower Back and Belly depth slider receiving no extra travel on classes whose stock Z maximum is already **1.35**.
- Corrected belly ceilings: baseline **1.35**, recommended **1.45**, high **1.60**, extreme **1.75**.
- No vanilla restore is needed when raising an existing belly cap; regenerate and inject again.

### v2.3.0
- **Lower Back and Belly restored safely:** new `belly` Max control targets only `Bip01 Spine`. Its X torso-length axis remains untouched; Y/Z girth is widen-only.
- Conservative belly ceilings: baseline **1.10**, recommended **1.20**, high **1.25**, extreme **1.30**.
- Named presets gain belly automatically. Existing custom specs stay unchanged; reopen body-size configuration to opt in.

### v2.2.8
- **Vanilla restore safety (body size):** game updates often need **[R] -> [1]** first. Characters saved above stock Max are **clamped** if loaded while vanilla; Beauty Album presets can be overwritten. Warnings + confirm + Customization snapshot to `backup\`. Re-inject Max ceilings **before** logging those characters.
- Still includes all of **2.2.0** below.

### v2.2.0
- **Censorship rewrite:** live PAZ blanks; DXT5/DXT3 only; never DXT1; never `*_cull*`; no 2018 4x4 stubs.
- **Genitals:** nude body only - no underwear-hide overwrite.
- **Body Max** presets with per-part clip warnings.
- Clearer recovery menu; genital picker = authored meshes only.
- Upgrade: restore vanilla meta before re-applying a smaller censorship set.

Full history: **[`CHANGELOG.md`](CHANGELOG.md)** . version notes: **[`VERSION.md`](VERSION.md)**

---

## Credits

**[`CREDITS.md`](CREDITS.md)** - keep in every zip. This AIO is a wrapper; meshes/tools belong to Midnight/heisha, Suzu, TheGreatSage, XYZW authors, Meta Injector/PartCutGen authors, Resorepless lineage, Orbmu2k (NPI), OptiScaler/NVIDIA (experimental), and this repo's menu/tooling.

**Black Desert Online** (c) Pearl Abyss. Client mods can break after patches and may violate ToS - use at your own risk.
