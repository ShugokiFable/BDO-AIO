# Publish status — public sites vs local tree

**Checked:** 2026-08-07  
**Local working copy:** `C:\Users\karlo\Documents\Apps\BDO-AIO` → **2.2.8**  
**Git publish clone:** `C:\Users\karlo\Documents\Apps\BDO-AIO-git-push` → target **v2.2.8** on `main`

---

## Public channels

| Channel | URL | Target |
|---------|-----|--------|
| **GitHub** | https://github.com/ShugokiFable/BDO-AIO | Release **v2.2.8** + `BDO-AIO-v2.2.8-full.7z` |
| **LoversLab** | https://www.loverslab.com/files/file/50558-bdo-aio-—-midnight-nudehide-meta-injector-wizard-black-desert-online/ | Same full.7z (manual upload) |
| **Undertow** | https://www.undertow.club/downloads/bdo-aio-—-midnight-nude-hide-meta-injector-wizard.9468/ | Same full.7z (manual upload) |
| **Nexus** | — | **Not used** |

Paste sheets: `docs/LOVERSLAB-RESOURCE.md`, `docs/UNDERTOW-RESOURCE.md`.

---

## What ships in 2.2.8 (user-facing)

- All of **2.2.0**: safe censorship, genital nude-only, body Max presets, Midnight wizard  
- **New:** vanilla restore safety for body-size / game-update path (warnings, confirm, Customization snapshot, next steps)  
- Body UNCUT experimental wave (2.2.1–2.2.6) was **never public** and is **removed** (2.2.7); not advertised as a feature  

## Do not ship as features

- Free cleavage / Zereth remesh promises  
- Body UNCUT menu (removed)  
- Personal `config.json`, `backup\`, live PAZ  

## Maintainer notes

- Working tree is **not** a git root; publish via `BDO-AIO-git-push`  
- Full offline payload = `BDO-AIO-v*-full.7z` (see `dev/BACKUP.md`)  
- After publish: update this file + copy full.7z to `Z:\Backup\BDO-mods-assets\`  
