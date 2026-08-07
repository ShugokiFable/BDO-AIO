# BDO-AIO state

**Date:** 2026-08-07
**Version in tree:** `2.2.8`
**Publish:** public GitHub/LL/Undertow = **v2.2.0**. Nothing since is published.
**PAZ:** `C:\Program Files (x86)\Steam\steamapps\common\Black Desert Online\PAZ`

## Status: restore safety warnings + Body UNCUT removed

### 2.2.8 — vanilla restore / body-size footgun
Users must restore vanilla before many game updates (launcher wall). Characters above
stock Max get clamped on load; presets can be overwritten. Launcher now warns on body-size
menu and **[R] → [1]**, requires confirm, snapshots Customization presets to `backup\`,
and prints post-restore order: update → re-inject caps → only then log oversized chars.

### 2.2.7 — Body UNCUT removed
`[2] -> [B] Body UNCUT` is **gone**. Folder-level BasicCutType cannot be fixed via
PartCutGen exclusions. See `dev/PARTCUT-MECHANICS.md`. Cleavage/Look 7 shelved; use
Midnight outfits for open windows.

Normal feature set: Midnight deploy, censorship tiers, genital packs, body size, pubic
hair, slot hide, PartCutGen, Meta Injector.

## If the game still has a modified partcutdesc

Run `[4]` PartCutGen then `[5]` Meta Injector. `[4]` regenerates `partcutdesc.xml` from the
staged exclusions, which drops any hand edit. `[R] -> [1]` restores vanilla meta outright
(remember body-size re-inject order).

## Do not repeat

1. Verify class prefixes against `bdo_aio.ps1` `$Script:FemaleClasses` before any test.
   `phw` is **Sorceress**; Ranger is `pew`.
2. Do not blank DXT1 or `*_cull*` textures — see `dev/TEXTURE-BLANKING-RULES.md`.
3. Do not re-add exclusion-based Body UNCUT for vanilla outfits. Structurally cannot work.
4. Do not load oversized body characters under vanilla Max (game update path).
