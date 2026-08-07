# Undertow â€” update resource checklist (BDO-AIO v2.2.8)

Existing resource:  
https://www.undertow.club/downloads/bdo-aio-â€”-midnight-nude-hide-meta-injector-wizard.9468/

Category: **Mods â†’ MMOs â†’ Other**

---

## File to attach

| Field | Value |
|-------|--------|
| **Attach this file** | `C:\Users\karlo\Documents\Apps\BDO-AIO-v2.2.8-full.7z` |
| Backup copy | `Z:\Backup\BDO-mods-assets\BDO-AIO-v2.2.8-full.7z` |
| Version string | `2.2.8` |
| SHA256 | 2cc24893083102f3f84667a9d40ac0d5663350dcce9e6a7497e6af2b62e620e4 |

Optional: also attach the `.sha256` text file.

### Do **not** attach

| Wrong file | Why |
|------------|-----|
| Source-only git zip | Missing `pack\` Midnight content |
| Personal `config.json` | Machine paths |
| Live game `PAZ` / `files_to_patch` | Illegal / huge |

Mirror:  
https://github.com/ShugokiFable/BDO-AIO/releases/download/v2.2.8/BDO-AIO-v2.2.8-full.7z

---

## Title (keep consistent)

```text
BDO-AIO v2.2.8 â€” Midnight nude/hide + Meta Injector wizard (NA/EU)
```

If the site locks the title, put **v2.2.8** in the version field and changelog body.

### Version

```text
2.2.8
```

### Tag line

```text
Windows AIO for Black Desert Online: Midnight deploy, underwear/armor hide, Suzu nude, XYZW collections, safe censorship (DXT5 only), body Max ceilings, restore-safe body-size warnings, pubic/genital options, PartCutGen + Meta Injector. Adult. Own risk.
```

### External URL

```text
https://github.com/ShugokiFable/BDO-AIO
```

---

## Description / changelog paste (HTML or plain as the form allows)

```text
BDO-AIO v2.2.8 (2026-08-07)

One-folder Windows installer for Black Desert Online PC (PAZ / Meta Injector).
NOT Skyrim. Adult / NSFW visual client mods.

WHAT'S NEW IN 2.2.8
- Vanilla restore safety for body-size users (critical for game updates):
  * Many PA patches stall if pad00000.meta / injected PAZ are still modded
  * Menu [R] -> [1] restores vanilla so the launcher can update
  * Characters saved ABOVE stock Max are CLAMPED when loaded under vanilla
  * Clamped body is re-saved; Beauty Album / Customization presets can be
    overwritten with the same bad data
  * Re-raising Max later does NOT restore the old shape (salon = pearls)
  * SAFE FREE ORDER: save presets while modded -> restore vanilla -> update
    -> do NOT log oversized chars while vanilla -> re-inject body size +
    Meta Inject FIRST -> only then log those characters
  * On restore: copy-only snapshot of Documents\Black Desert\Customization
    into backup\Customization-* under the AIO folder
- Explicit confirm + post-restore next-steps list in the menu
- Still includes all of 2.2.0:
  * Safe censorship blanks (live PAZ, DXT5/DXT3 only, never DXT1, never *_cull*)
  * Genital packs: nude body PAC only (no underwear overwrite)
  * Body Max ceilings + Midnight wizard

KNOWN LIMIT
- Built-in shorts that are modelled geometry or DXT1 base maps need a remeshed
  outfit (XYZW collections), not texture censorship.

UPGRADE
1. Download BDO-AIO-v2.2.8-full.7z
2. Extract; run START.bat -> 9 verify pack
3. If you used old censorship: [R] restore vanilla meta first, then re-wizard
   (body-size: re-inject Max caps BEFORE logging oversized characters)
4. PartCutGen -> Meta Injector

INCLUDES
- Midnight XYZW pack, PartCutGen, Meta Injector 1.4.1
- RESTORED: body Max, slot hide, pubic hair, censorship tiers, genitals
- GameOption profiles + NVIDIA .nip
- Optional EXPERIMENTAL OptiScaler (menu X) â€” NOT SAFE

Requires: BDO PC PAZ, Python 3, BDO Toolkit 1.3.0 (not bundled).

Credits: CREDITS.md
GitHub: https://github.com/ShugokiFable/BDO-AIO/releases/tag/v2.2.8
```

---

## Requirements / Compatibility (plain text if separate fields)

**Requirements**

```text
Black Desert Online PC (primarily NA/EU)
Python 3
BDO Toolkit 1.3.0 (required by Meta Injector â€” not bundled)
Live game PAZ folder with pad00000.meta
```

**Compatibility**

```text
Must match your live client patch; re-deploy + re-inject after official updates.
Before many patches: restore vanilla ([R]->[1]) so the launcher can update, then re-mod.
Body-size: re-inject Max ceilings BEFORE loading characters saved above stock Max.
Censorship blanks: live DXT5/DXT3 only.
```
