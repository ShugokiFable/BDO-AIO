# BDO Modding AIO

**Current version: [v2.2.0](https://github.com/ShugokiFable/BDO-AIO/releases/tag/v2.2.0)**  
Windows menu for **Black Desert Online** client mods (PAZ / Meta Injector). **Not Skyrim.**

| Download | What you get |
|----------|----------------|
| **[Full offline `.7z` (recommended)](https://github.com/ShugokiFable/BDO-AIO/releases/latest)** | Scripts + **`pack\`** Midnight (~1.8 GB) + injectors — use this |
| This git `main` branch | Scripts + docs + tools only — **no** Midnight meshes unless you add `pack\` yourself |

Double-click **`START.bat`**.

---

## What it does

- **Midnight** deploy → **PartCutGen** → **Meta Injector**
- Underwear / armor hide, Suzu + TheGreatSage nude bases, optional **XYZW** skimpy collections
- **RESTORED** options: body Max ceilings, slot hide, pubic hair, censorship texture tiers, authored 3D vagina/penis
- GameOption max-quality profiles + NVIDIA `.nip` import
- Optional **EXPERIMENTAL / NOT SAFE** OptiScaler (menu **X**)

### Feature labels

| Label | Meaning |
|-------|---------|
| **MODERN** | Midnight / Meta Injector 2026 pipeline |
| **RESTORED** | Classic Resorepless-era feature, re-wired here |
| **EXPERIMENTAL** | From-scratch in this AIO only — not a classic restore |

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
| **Body size (Max ceilings only)** | Stock Max is **per part** (not all 1.25). **vanilla** 1.25/1.15/1.10 · **recommended** 1.37/1.30/1.18 · **high** 1.65/1.40/1.19 · **extreme** 2.00/1.45/1.20. Above recommended: breasts may clip outfits, thighs may collide, butt may pyramid. Never writes Default; never HeightAxis. |
| **Slot hide** | Gloves / boots / helmets / weapons / stockings |
| **Pubic hair** | Per-class styles; shared-atlas classes share one style; texture-only |
| **Censorship tiers** | Live-client **DXT5/DXT3** transparent blanks only. **Never DXT1**, never `*_cull*`, never 2018 stubs. Default **off**. Mesh/DXT1 built-in shorts need an XYZW remesh — see [`TEXTURE-BLANKING-RULES.md`](TEXTURE-BLANKING-RULES.md). |
| **3D vagina / penis** | Authored meshes only (10 female + 6 male). **Nude body PAC only** — does not overwrite Midnight underwear hide. |

### Not supported
| Area | Reason |
|------|--------|
| Genitals on classes with no authored mesh | Reusing another class’s PAC steals that class’s body *and* skin |
| Separate pubic style per shared-atlas class | 13 females share one texture; material rename made bodies invisible |
| Pubic hair on Corsair | No matching hair bin size |
| “Strip every outfit” via texture censorship | Safe only for DXT5 overlays; geometry shorts need remeshes |

### EXPERIMENTAL
| Area | Options |
|------|---------|
| Main menu **[X]** | OptiScaler / DLSS-style inject — **NOT SAFE** |

---

## Quick start

1. Download **`BDO-AIO-v2.2.0-full.7z`** from [Releases](https://github.com/ShugokiFable/BDO-AIO/releases/latest) (or use this repo + fill `pack\`).
2. Extract to a short path; install **Python 3** if needed (`winget install Python.Python.3.12`).
3. **`START.bat`** → **`9`** verify pack (~1.5–2 GB under `pack\`).
4. **`6`** Full Wizard (or configure options first) → pick live **PAZ** (`pad00000.meta` inside).
5. Finish **PartCutGen**, then **Meta Injector**.
6. Optional: **`G`** GameOption · **`N`** NVIDIA .nip · **`X`** OptiScaler (not safe).
7. After official game patches: **`H`** (heisha regen if inject breaks) then wizard again.
8. If an old censorship inject left holes: **`R`** restore vanilla meta, then re-apply.

**Requires separately:** [BDO Toolkit 1.3.0](https://www.undertow.club/) for Meta Injector 1.4.1 (not bundled).

---

## Why `pack/` is not in git

~1.8 GB / 40k+ files. Full offline payload ships as **`BDO-AIO-v*-full.7z`** on Releases. Source-only clone is incomplete without that archive or a local `pack\`.

---

## Layout (full offline tree)

```text
BDO-AIO/
  START.bat
  bdo_aio.ps1
  config.example.json    <- ship this; config.json is local-only
  TEXTURE-BLANKING-RULES.md
  pack/                  <- REQUIRED (~1.5–2 GB) in full releases
  graphics/              <- GameOption patches + nvidia .nip
  tools/                 <- bdo_meta, NPI, restored assets
  experimental/dlss/     <- optional, dangerous
```

---

## Pipeline

```text
NA/EU: Deploy → PartCutGen → Meta Injector → Launch
Other regions: same, then Meta Patcher only if your region needs it (not bundled)
```

Meta Injector is launched via a short-path canonical stage so deep XYZW trees do not hit Windows path limits.

---

## Changelog (latest)

### v2.2.0
- **Censorship rewrite:** live PAZ blanks; DXT5/DXT3 only; never DXT1; never `*_cull*`; no 2018 4×4 stubs.
- **Genitals:** nude body only — no underwear-hide overwrite.
- **Body Max** presets with per-part clip warnings.
- Clearer recovery menu; genital picker = authored meshes only.
- Upgrade: restore vanilla meta before re-applying a smaller censorship set.

Full history: **[`CHANGELOG.md`](CHANGELOG.md)** · version notes: **[`VERSION.md`](VERSION.md)**

---

## Credits

**[`CREDITS.md`](CREDITS.md)** — keep in every zip. This AIO is a wrapper; meshes/tools belong to Midnight/heisha, Suzu, TheGreatSage, XYZW authors, Meta Injector/PartCutGen authors, Resorepless lineage, Orbmu2k (NPI), OptiScaler/NVIDIA (experimental), and this repo’s menu/tooling.

**Black Desert Online** © Pearl Abyss. Client mods can break after patches and may violate ToS — use at your own risk.
