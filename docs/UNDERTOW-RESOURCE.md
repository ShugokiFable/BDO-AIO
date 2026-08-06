# Undertow — update resource checklist (BDO-AIO v2.2.0)

Existing resource:  
https://www.undertow.club/downloads/bdo-aio-—-midnight-nude-hide-meta-injector-wizard.9468/

Category: **Mods → MMOs → Other**

---

## File to attach

| Field | Value |
|-------|--------|
| **Attach this file** | `C:\Users\karlo\Documents\Apps\BDO-AIO-v2.2.0-full.7z` |
| Backup copy | `Z:\Backup\BDO-mods-assets\BDO-AIO-v2.2.0-full.7z` |
| Version string | `2.2.0` |
| SHA256 | `92ec485695bbc3a2707b83816d7aa90f3784faa2f444b18785ba8dd6e7874e40` |

Optional: also attach the `.sha256` text file.

### Do **not** attach

| Wrong file | Why |
|------------|-----|
| Source-only git zip | Missing `pack\` Midnight content |
| Personal `config.json` | Machine paths |
| Live game `PAZ` / `files_to_patch` | Illegal / huge |

Mirror:  
https://github.com/ShugokiFable/BDO-AIO/releases/download/v2.2.0/BDO-AIO-v2.2.0-full.7z

---

## Title (keep consistent)

```text
BDO-AIO v2.2.0 — Midnight nude/hide + Meta Injector wizard (NA/EU)
```

If the site locks the title, put **v2.2.0** in the version field and changelog body.

### Version

```text
2.2.0
```

### Tag line

```text
Windows AIO for Black Desert Online: Midnight deploy, underwear/armor hide, Suzu nude, XYZW collections, safe censorship (DXT5 only), body Max ceilings, pubic/genital options, PartCutGen + Meta Injector. Adult. Own risk.
```

### External URL

```text
https://github.com/ShugokiFable/BDO-AIO
```

---

## Description / changelog paste (HTML or plain as the form allows)

```text
BDO-AIO v2.2.0 (2026-08-06)

One-folder Windows installer for Black Desert Online PC (PAZ / Meta Injector).
NOT Skyrim. Adult / NSFW visual client mods.

WHAT'S NEW IN 2.2.0
- Censorship removal rewritten for the 2026 client:
  * Blanks rebuilt from YOUR live PAZ (not 2018 Resorepless stubs)
  * Only DXT5/DXT3 overlays go fully transparent (body can show)
  * DXT1 never blanked (kills meshes on modern client)
  * Clip masks (*_cull*) never blanked
  * Default remains OFF
- 3D vagina / penis: nude body PAC only — no longer overwrites Midnight underwear hide
- Body size Max ceilings: vanilla 1.25/1.15/1.10, recommended 1.37/1.30/1.18,
  high 1.65/1.40/1.19, extreme 2.00/1.45/1.20 (per-part clip warnings)
- Clearer recovery menu; genital class list = authored meshes only
- Full rules: TEXTURE-BLANKING-RULES.md in the zip

KNOWN LIMIT
- Built-in shorts that are modelled geometry or DXT1 base maps need a remeshed
  outfit (XYZW collections), not texture censorship.

UPGRADE
1. Download BDO-AIO-v2.2.0-full.7z
2. Extract; run START.bat → 9 verify pack
3. If you used old censorship: [R] restore vanilla meta first, then re-wizard
4. PartCutGen → Meta Injector

INCLUDES
- Midnight XYZW pack, PartCutGen, Meta Injector 1.4.1
- RESTORED: body Max, slot hide, pubic hair, censorship tiers, genitals
- GameOption profiles + NVIDIA .nip
- Optional EXPERIMENTAL OptiScaler (menu X) — NOT SAFE

Requires: BDO PC PAZ, Python 3, BDO Toolkit 1.3.0 (not bundled).

Credits: CREDITS.md
GitHub: https://github.com/ShugokiFable/BDO-AIO/releases/tag/v2.2.0
```

---

## Requirements / Compatibility (plain text if separate fields)

**Requirements**

```text
Black Desert Online PC (primarily NA/EU)
Python 3
BDO Toolkit 1.3.0 (required by Meta Injector — not bundled)
Live game PAZ folder with pad00000.meta
```

**Compatibility**

```text
Client must match your live patch. After every official BDO update, re-deploy and re-inject.
Armor/underwear hide lists are regenerated against live PAZ metadata on the Midnight path.
Censorship blanks are generated from the live client formats (DXT5/DXT3 only).
```
