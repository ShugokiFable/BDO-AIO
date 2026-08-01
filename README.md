# BDO Modding AIO (2026)

Easy Windows menu for Black Desert Online client modding:

- Midnight deploy → PartCutGen → Meta Injector  
- GameOption graphics profiles  
- NVIDIA Profile Inspector `.nip` import  
- Optional **EXPERIMENTAL / NOT SAFE** OptiScaler (menu **X**)

Double-click **`START.bat`**.

## GitHub clone vs full offline folder

| Source | What you get |
|--------|----------------|
| **This git repo** | Scripts, docs, GameOption profiles, `.nip`, NPI tool |
| **`pack\`** | **Not in git** (~1.8 GB Midnight content) — add locally; see [`pack/README.md`](pack/README.md) |
| **`experimental/dlss` binaries** | **Not in git** — add OptiScaler/Streamline yourself if you use menu **X** |

If you already have a full offline `BDO-AIO` folder (with `pack\` filled), just use that. Git is for the tool + small assets.

## Feature labels (important)

| Label | Meaning |
|-------|---------|
| **MODERN** | Midnight / Meta Injector 2026 pipeline (recommended) |
| **RESTORED** | Classic Resorepless-era feature, re-wired in this AIO |
| **EXPERIMENTAL** | From-scratch in BDO-AIO only — **not** a classic restore |

Full table: [`docs/FEATURE-LABELS.md`](docs/FEATURE-LABELS.md)

## Full options (menu 2)

### MODERN
| Area | Options |
|------|---------|
| Gender | Female / Male / Both |
| Armor hide | All / Pearl / Free / Underwear-only |
| Collections | XYZW outfit packs on/off |

### RESTORED (classic)
| Area | Options |
|------|---------|
| **Body size limits** | Min / Default / Max presets **or custom numbers** + custom part list |
| **Slot hide** | Gloves / boots / helmets / weapons / stockings |
| **Pubic hair** | Style + **per-class pick** (ALL / native / new females / custom list) |
| **Censorship tiers** | minimal / medium / high texture packs |
| **3D vagina / penis** | Female donor reuse is optional; male penis meshes are native-only (six supported classes) |

### EXPERIMENTAL-REUSE (opt-in, not native art)
| Area | Options |
|------|---------|
| **New females genitals + pubic** | Options hub **[F]** — Seraph/Deadeye/Woosa/… preferred donors + synthesized pubic DDS |
| Donor mesh/bin for missing females | Also asked inside Options **[6]** / **[V]**; default **OFF**; never applied to Dosa/Wukong males |

### EXPERIMENTAL (from-scratch only)
| Area | Options |
|------|---------|
| **Main menu [X]** | OptiScaler / DLSS-style inject — **NOT SAFE**, separate folder `experimental\dlss\` |

Body size → `files_to_patch\_body_size_limits\` then Meta Inject. Beauty salon or new character for slider max. Tamer breasts often ignore size limits (classic issue).

The 2.0.6 body generator writes only complete three-component vectors and preserves the exact byte width of each live source attribute, including current trailing padding. It aborts instead of producing a partial or size-changing XML file.

## End user (quick start)

1. Clone or extract this folder (prefer the **full** GitHub release for Midnight + experimental binaries).
2. Fill **`pack\`** with a Midnight PAZ pack (see `pack/README.md`) if not already present.
3. Install **Python 3** once if needed: `winget install Python.Python.3.12`. The AIO detects `python.exe`, the `py` launcher, and normal per-user installs.
4. Double-click **`START.bat`**
5. Press **`6`** (Full Wizard) for Midnight + optional RESTORED batch
6. Or press **`A`** later to apply all configured RESTORED choices only
7. Select your game **`PAZ`** folder (`pad00000.meta` inside)
8. Finish **PartCutGen**, then **Meta Injector**. AIO 2.0.6 builds a canonical short-path stage first; it does not delete XYZW collections.
9. Optional: **`G`** GameOption · **`N`** NVIDIA .nip · **`X`** EXPERIMENTAL official OptiScaler bundle
10. Check inject state: **`S`** scan PAZ (stock / staged / injected / restored)  
11. Troubleshooting: **`R`** restore/clean · after game patches **`H`** heisha regen helper

After every official game patch: **H** (if inject breaks) then wizard again.  
If you used **X**, expect breakage after patches — uninstall via **X** or **R**.

### Menu X — EXPERIMENTAL DLSS (NOT SAFE)

BDO only exposes weak FSR-class upscaling. Menu **X** can install **OptiScaler + Streamline** into the game folder so you can try **DLSS / FSR3 / XeSS**.

| | |
|--|--|
| Status | **EXPERIMENTAL — NOT SAFE** |
| Risks | Bans, crashes, black screens, ToS, anti-cheat, driver/game patch breakage |
| Not for | Main accounts you care about |
| Safer path | Menu **G** + **N** only |
| Not included | SkyrimUpscaler (wrong game) |

Install requires typing **`YES`**, then a second confirm (default **No**).

## Folder layout (publish this entire tree)

```text
BDO-AIO/
  START.bat              <- entry point
  bdo_aio.ps1            <- menu + wizard
  config.example.json    <- sanitized settings template
  config.json            <- generated user settings (ignored; do not publish)
  README.md
  CREDITS.md
  DESIGN.md
  PUBLISH.md
  pack/                  <- REQUIRED mod content (~1.5-2 GB)
    midnight_xyzw.cmd
    midnight_xyzw/
    Meta Injector.exe
    PartCutGen.exe
  graphics/              <- GameOption max-quality profiles
    GameOption_Remastered_1440p.txt
    GameOption_Remastered_DLDSR_4K.txt
    GameOption_Ultra_Screenshot_DLDSR_4K.txt
    README.txt
    nvidia/
      Black_Desert_Max_Quality.nip
      README.txt
  tools/
    nvidiaProfileInspector/
      nvidiaProfileInspector.exe   <- bundled when shipping
  experimental/                  <- OPTIONAL, DANGEROUS
    dlss/
      WARNING.txt                <- read this
      README.txt
      OptiScaler/                <- OptiScaler 0.9.4
      Streamline/                <- NVIDIA Streamline DLLs
```

## NVIDIA driver profile (menu N)

Imports **`graphics\nvidia\Black_Desert_Max_Quality.nip`** for `blackdesert64.exe`.

Uses, in order:
1. Path saved in `config.json` (`npiPath`)
2. Bundled `tools\nvidiaProfileInspector\nvidiaProfileInspector.exe`
3. Auto-detect (e.g. `Documents\Apps\NvidiaProfileInspector\`)
4. Browse / manual path

Command used: `nvidiaProfileInspector.exe -silentImport "....nip"`

## Graphics profiles (menu G)

Applies to: `Documents\Black Desert\GameOption.txt`  
(backs up your old file first)

| Profile | Use |
|---------|-----|
| Remastered 1440p | Safe native gameplay |
| Remastered DLDSR 4K | Best IQ on 1440p (enable NVIDIA DSR 2.25x first) |
| Ultra Screenshot DLDSR 4K | Screenshots/video only — not for grinding |

## What is bundled vs not

| Bundled | Not bundled (user side) |
|---------|-------------------------|
| Midnight mod content | BDO game install / PAZ |
| Meta Injector | Python 3 (system, for mod deploy) |
| PartCutGen | Live GameOption.txt path under Documents |
| Graphics GameOption profiles | |
| Easy menu / wizard | |

**Required external dependency:** bundled Meta Injector 1.4.1 requires **BDO Toolkit 1.3.0**. The AIO checks for it before injection.

**Region-specific step:** the Meta Patcher author's FAQ says it is for official regions that block mods—currently every official region **except NA/EU**. AIO reads `service.ini`: it skips Meta Patcher on NA/EU, offers it only for another detected region, and does not guess when the region is unknown. It is not bundled; obtain it from the original author only if your region needs it.

Official tool pages: [Meta Injector 1.4.1](https://www.undertow.club/downloads/meta-injector.4367/) and [Meta Patcher 1.1.0](https://www.undertow.club/downloads/meta-patcher.7829/).

**Redundant or creator-only, therefore not bundled:** PAZ Browser/Unpacker, PACtool, 3D Converter, the abandoned Resorepless UI, and the old 0.3.0 pack.

## 2.0.6 deploy and injection path

Meta Injector 1.4.1 is a .NET Framework application whose recursive source scan can hit Windows path limits when many organizer layers are nested. AIO 2.0.6:

1. reads every file in `files_to_patch`;
2. mirrors Meta Injector's `_` / `.` organizer-marker rules;
3. resolves same-game-path overrides deterministically;
4. validates normal files against the current live `pad00000.meta`;
5. creates a flat canonical stage and mounts temporary short drive roots;
6. launches Meta Injector with its supported `-files` argument.

Midnight deploy also receives `--yes` from the AIO, so the single AIO confirmation is sufficient and deploy no longer waits for a hidden second Enter. The live-regenerated hide pack adds Wukong armor/underwear paths without borrowing a male genital body.

No XYZW collection is removed. Truly invalid or obsolete game paths stop the run and are reported instead of being mislabeled as path-length failures.

## Publisher checklist

1. Run menu **`[9] Verify pack integrity`** — pack should be ~1.5–2 GB, not a few MB.
2. Confirm **`pack\`** has: `midnight_xyzw.cmd`, `midnight_xyzw\`, `PartCutGen.exe`, `Meta Injector.exe`
3. Keep **`CREDITS.md`** in every release
4. Confirm `config.json` is not in the release and `config.example.json` has no personal paths
5. Zip the whole `BDO-AIO` folder (do not zip only scripts without `pack\`)
6. Prefer **7-Zip** solid archive; warn users extract path has no weird permissions

## Pipeline

```text
NA/EU: Deploy -> PartCutGen -> canonical stage -> Meta Injector -> Launch game
Other official regions: Deploy -> PartCutGen -> canonical stage -> Meta Injector -> Meta Patcher (when required) -> Launch game
```

## Risk

Client mods can break after patches and may violate game ToS. Use at your own risk.

## Credits

See **CREDITS.md**. Content authors: Midnight Xyzw, Suzu, TheGreatSage, Meta Injector / PartCutGen authors.
