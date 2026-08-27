# BDO-AIO state

**Date:** 2026-08-27
**Version in tree / on `main`:** `2.4.2`
**Latest GitHub *release*:** `v2.4.1` - 2.4.2 source is pushed, no release archive built yet.
**PAZ:** `<STEAM>\steamapps\common\Black Desert Online\Paz`

## Status: client-version rollback fixed; user's game is clean vanilla

A client patch (3412 -> 3418) plus an inject run left the meta reporting an older
client version than the one installed. The launcher treated that as a rollback,
re-downloaded ~1 GB of patches and replaced `pad00000.meta`, wiping the injection and
leaving 1.65 GB of orphaned archives. The visible symptom was "corrupted files".
Nothing was corrupt. PartCutGen was suspected and cleared.

2.4.2 records the client version before injecting and re-checks it after, refuses to
restore a snapshot from a different client version, and adds `verify`. Full write-up:
`dev/CLIENT-PATCH-RULES.md`.

## Live machine state (2026-08-27)

- `pad00000.meta` verified: 861,376 blocks, 0 missing archives, 0 overruns, version 3418.
- Vanilla snapshot exists again (`pad00000.BDOAIO-VANILLA.meta`, `meta_version: 3418`).
  There was **none at all** before - any restore would have needed a Steam repair.
- 19 orphaned `PAD6133x-6135x.PAZ` deleted, 1.65 GB reclaimed.
- `files_to_patch` still holds the user's five stages plus a freshly generated
  `_PartCutGen/character/partcutdesc.xml`.
- **Mods are not currently applied.** The pipeline has not been re-run since the patch.

## Next

1. User re-runs deploy -> PartCutGen -> Meta Injector.
2. Watch for `Client version before inject: 3418` and the post-inject check. If it
   reports a mismatch, Meta Injector reproduces the bug and it is worth reporting to
   that tool's author - the AIO can only detect it, not prevent it.

## Do not repeat

1. Verify class prefixes against `$Script:FemaleClasses` - `phw` is Sorceress, `pew` is
   Ranger. Assuming otherwise invalidated an entire test campaign.
2. Never blank DXT1 or `*_cull*` textures - `dev/TEXTURE-BLANKING-RULES.md`.
3. Judge injected/vanilla state from the **meta**, never from folders or stray archives
   on disk. Two guards used disk artefacts as a proxy and both were wrong.
4. Never restore a vanilla snapshot taken under a different client version.
