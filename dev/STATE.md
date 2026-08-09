# BDO-AIO state

**Date:** 2026-08-09
**Version in tree:** `2.3.0`
**Release:** **v2.3.0**. LL/Undertow require manual upload of the matching GitHub full.7z.
**PAZ:** `C:\Program Files (x86)\Steam\steamapps\common\Black Desert Online\PAZ`

## Status: safe belly slider + restore safety warnings

`belly` restores the original Lower Back and Belly control (`Bip01 Spine`) with
baseline/recommended/high/extreme Max ceilings of 1.10/1.20/1.25/1.30. X torso
length, Default, Min, and already-larger class values remain untouched.

### 2.2.8 â€” vanilla restore / body-size footgun
Users must restore vanilla before many game updates (launcher wall). Characters above
stock Max get clamped on load; presets can be overwritten. Launcher now warns on body-size
menu and **[R] â†’ [1]**, requires confirm, snapshots Customization presets to `backup\`,
and prints post-restore order: update â†’ re-inject caps â†’ only then log oversized chars.

### 2.2.7 â€” Body UNCUT removed
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
2. Do not blank DXT1 or `*_cull*` textures â€” see `dev/TEXTURE-BLANKING-RULES.md`.
3. Do not re-add exclusion-based Body UNCUT for vanilla outfits. Structurally cannot work.
4. Do not load oversized body characters under vanilla Max (game update path).
