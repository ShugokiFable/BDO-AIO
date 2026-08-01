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

## Full options (menu 2)

| Area | Options |
|------|---------|
| Gender | Female / Male / Both |
| Armor hide | All / Pearl / Free / Underwear-only |
| Collections | XYZW outfit packs on/off |
| **Body size limits** | Raise char-create **Max** for breasts, butt, thighs, arms, legs, pelvis, spine (Resorepless-style). Presets: vanilla / mild / **high (2.5)** / extreme |
| Legacy | Optional launch of old Resorepless.exe + PAZ Unpacker from `Z:\Backup\BDO` if present |

Body size patch writes `files_to_patch\_body_size_limits\` then you Meta Inject. **Beauty salon or new character** required to see bigger slider range. Tamer breasts often ignore this (same as old tool).

## End user (quick start)

1. Clone or extract this folder.
2. Fill **`pack\`** with a Midnight PAZ pack (see `pack/README.md`) if not already present.
3. Install **Python 3** once if needed: `winget install Python.Python.3.12`
4. Double-click **`START.bat`**
5. Press **`6`** (Full Wizard) for mods
6. Select your game **`PAZ`** folder (`pad00000.meta` inside)
7. Pick gender / armor options / optional collections
8. Finish **PartCutGen**, then **Meta Injector**
9. Optional: press **`G`** to apply a GameOption graphics profile  
10. Optional: press **`N`** to import `Black_Desert_Max_Quality.nip` via NVIDIA Profile Inspector  
11. Optional **advanced only**: press **`X`** for **EXPERIMENTAL / NOT SAFE** OptiScaler DLSS-style upscaling  
12. Start Black Desert

After every official game patch: re-run the mod wizard. Re-import **N** after big NVIDIA driver updates if settings reset.  
If you used **X**, expect breakage after patches — uninstall via **X** if the game fails to start.

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
  config.json            <- user settings only (safe defaults)
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
      optional/                  <- DLSS Enabler setup + alt version.dll
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

**Not included on purpose:** Meta Patcher, BDOToolkit, PAZ Browser, PACtool, 3D Converter, Resorepless, old 0.3.0 pack.

## Publisher checklist

1. Run menu **`[9] Verify pack integrity`** — pack should be ~1.5–2 GB, not a few MB.
2. Confirm **`pack\`** has: `midnight_xyzw.cmd`, `midnight_xyzw\`, `PartCutGen.exe`, `Meta Injector.exe`
3. Keep **`CREDITS.md`** in every release
4. Reset `config.json` `pazFolder` to `""` before zip (no personal game paths)
5. Zip the whole `BDO-AIO` folder (do not zip only scripts without `pack\`)
6. Prefer **7-Zip** solid archive; warn users extract path has no weird permissions

## Pipeline

```text
Deploy from pack  ->  PartCutGen  ->  Meta Injector  ->  Launch game
```

## Risk

Client mods can break after patches and may violate game ToS. Use at your own risk.

## Credits

See **CREDITS.md**. Content authors: Midnight Xyzw, Suzu, TheGreatSage, Meta Injector / PartCutGen authors.
