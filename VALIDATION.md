# Validation

BDO-AIO 2.0.6 is tool-validated against the current read-only NA game metadata. Structural validation is not runtime confirmation.

## Evidence baseline

- Live `pad00000.meta`: 44,570,140 bytes, SHA-256 `3DEFCF742F8A390D02C9F3E9ACE45F8A3C0097A6668D2200A3DDFBF0E49B6B20`, timestamp 2026-08-01 12:22:06.
- Client region: `service.ini` reports `TYPE=NA`; Meta Patcher is therefore skipped.
- Full snapshot inventory before archiving: 42,109 files, 2,316,714,088 bytes.

## Source and control gates

- Python unit tests: PASS, 25 tests.
- Python compileall: PASS for `tools/bdo_meta` and the Midnight deployer.
- PowerShell parser: PASS for `bdo_aio.ps1`.
- Midnight non-interactive test: PASS with stdin closed; `--yes` deploy completes without a second ENTER.
- Male donor regression: PASS; Dosa, Wukong, Archer, Hashashin, Sage, and Wizard revamp output counts are zero while native male packs remain available.
- Experimental uninstall: marker required; unrelated/unverifiable proxy filenames are skipped.

## Current tool gate

- Meta Injector 1.4.1 SHA-256 `766BF9A050637AC3CF55956084B923974DD3B55C9D5B0F290E13C24C66BF9B6A`.
- PartCutGen 1.1.0 SHA-256 `7066B5A599CBF35445F9153B68AD56B17EC1C61B598CAF0F400A1A8EC700D9C5`.
- OptiScaler 0.9.4-final SHA-256 `FBFB6676B829DAD7E020FB830586A16AA0EC6ADD78016DB48EF12E2AE1803231`; isolated experimental opt-in only.
- NVIDIA Profile Inspector 3.0.2.1 SHA-256 `1EBD8129B3C564BF226291FB3344819FD59668066F0C5E03334A69A04A62859E`; the newer 3.0.2.2 is prerelease.
- Meta Patcher 1.1.0 is not bundled and is not used for this detected NA client.

## Semantic generation gates

- Body-size live rerun: PASS, 75 files, 17,562 attribute edits; every file retained its exact extracted byte length and every edited field remained a complete three-component vector, including source trailing padding.
- Full Midnight/XYZW canonical dry run: PASS, 41,800 candidates, 41,460 winners, 340 deterministic overrides, 0 invalid/current-meta failures, 0 skipped collections. Longest source path was 256 characters; canonical stage maximum was 151.
- Restored-feature combined dry run: PASS, 3,361 candidates, 3,360 winners, one deterministic override, 35 intentional `_add` entries, 0 invalid/current-meta failures.
- Live heisha regeneration: PASS, underwear 1,794 files with 26 Wukong paths; armor 39,280 files with 553 Wukong paths.
- Genital combined generation: PASS, 80 files; all female donors plus exactly six native male class folders and no unsupported male donor output.
- Slot hide: PASS, 2,753 models selected for the tested classes (plus metadata files).
- Pubic native/donor and expanded censorship: PASS; intentional `_add` routing preserved and 451 censorship outputs generated.

## Runtime boundary

- The installed game and live PAZ were inspected read-only.
- No game, launcher, Meta Injector, Meta Patcher, PartCutGen, or experimental client DLL was launched.
- The reported body-slider crash, Midnight menu interaction, and full in-game stack require the user's isolated retest.
