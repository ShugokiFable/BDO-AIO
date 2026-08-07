# BDO-AIO state

**Date:** 2026-08-07
**Version in tree:** `2.2.7`
**Publish:** public GitHub/LL/Undertow = **v2.2.0**. Nothing since is published.
**PAZ:** `C:\Program Files (x86)\Steam\steamapps\common\Black Desert Online\PAZ`

## Status: Body UNCUT removed, partcut research shelved

`[2] -> [B] Body UNCUT` is **gone** from the launcher (2.2.7). It could never work on
vanilla garments: they are cut by folder, and PartCutGen exclusions only affect per-file
cuts. See `dev/PARTCUT-MECHANICS.md` for the measured mechanism, the working replacement
(`tools/bdo_meta/partcut_recut.py`), and where the Ranger Look 7 hunt stopped.

The app is back to its normal feature set: Midnight deploy, censorship tiers, genital
packs, body size, pubic hair, slot hide, PartCutGen, Meta Injector.

## If the game still has a modified partcutdesc

Run `[4]` PartCutGen then `[5]` Meta Injector. `[4]` regenerates `partcutdesc.xml` from the
staged exclusions, which drops any hand edit. `[R] -> [1]` restores vanilla meta outright.

## Do not repeat

1. Verify class prefixes against `bdo_aio.ps1` `$Script:FemaleClasses` before any test.
   `phw` is **Sorceress**; Ranger is `pew`.
2. Do not blank DXT1 or `*_cull*` textures — see `dev/TEXTURE-BLANKING-RULES.md`.
3. Do not re-add exclusion-based Body UNCUT for vanilla outfits. Structurally cannot work.
