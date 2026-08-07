# Validation

BDO-AIO 2.0.9 is tool-validated as a restored pubic-texture hotfix. Structural/tool validation is not runtime confirmation.

## 2.0.9 restored pubic-texture hotfix

- User runtime evidence: contradicted for full bush on Witch or Sorceress; patching completed without an error, but the tested character appeared shaved.
- Selection/config: PASS; `full_bush`, native prefixes `pbw,pdw,pew,phw,pww`, and experimental reuse off.
- PAC material binding: PASS; Sorceress embeds `phw_01_nude_0001`, Witch embeds `pww_01_nude_0001`.
- Canonical staging: PASS; generated pubic DDS files beat Midnight clean DDS files at priority 700 versus 100.
- Injection chronology: PASS as evidence only; live `pad00000.meta` was newer than the generated pubic output and differed from its latest backup.
- Root cause: restored ranges end at byte 11,184,948 and contain 637,596 bytes of DXT1 blocks. Midnight uses compatible 11,184,952-byte DXT1 files for Tamer/Dark Knight but 89,478,612-byte 32-bit files for Ranger/Sorceress/Witch. The old length-only check falsely accepted the incompatible larger layout.
- Exact DXT1 path: PASS; a real Tamer regeneration is byte-identical to the previously generated known-good output, SHA-256 `A058B7622264F000396225337A170B7FC33A51A671F7A649E46EA0DFD449D674`.
- 32-bit translation path: PASS; selected and shaved DXT1 blocks are decoded and their style delta is applied to matching pixels across the existing mip chain.
- Real Sorceress/Witch dry run: PASS using read-only Midnight inputs. Both outputs retained 89,478,612 bytes, byte-identical 128-byte headers, unchanged alpha, and changed only the expected pubic UV area on the top mip (`x=1664..2435`, `y=2088..2995` maximum observed bounds).
- Visual texture inspection: PASS; the generated Sorceress comparison visibly changed clean-shaven source art to full bush without replacing the surrounding 4K skin.
- Python tests: PASS, 32.
- Cleanup: PASS; the temporary two-DDS validation tree and preview were deleted.
- Runtime status: **tool-validated**. User must regenerate full bush, rerun Meta Injector, and confirm in game. 3D vagina remains user-untested.

## 2.0.8 Meta Injector hotfix

- User PartCutGen log: PASS; 1,679 exclusions processed and `partcutdesc.xml` saved. Three optional patterns matching zero files are informational.
- User Meta Injector screenshot: reproduced root cause in source; the stage-builder's stdout joined the function return and made `$stage` a `System.Object[]`.
- Windows PowerShell parser: PASS.
- Windows PowerShell regression: PASS; two simulated builder-output lines remain visible while the returned stage is exactly one `System.String` equal to `X:\BDO_AIO_INJECT`.
- Meta Injector launch argument: one explicit quoted string, `-files "<stage>"`.
- Python unit tests: PASS, 30 tests.
- Live boundary: no game, launcher, PartCutGen, Meta Injector, or PAZ file was launched or modified by this validation.

## Evidence baseline

- Parent authority: clean v2.0.6 commit `ad1534c`; complete 2.0.7 rollback snapshot created before edits.
- Live `pad00000.meta`: 44,570,140 bytes, SHA-256 `3DEFCF742F8A390D02C9F3E9ACE45F8A3C0097A6668D2200A3DDFBF0E49B6B20`, timestamp 2026-08-01 12:22:06.
- Client region: `service.ini` reports `TYPE=NA`; Meta Patcher remains skipped.
- Installed-client option bytecode inspected read-only: Remastered UI index 7 maps to saved `graphicOption = 9`; Ultra maps to `8`; the High texture UI index maps to saved `textureQuality = 0`.
- Live user `GameOption.txt` inspected read-only: 2,707 bytes and 117 lines, including current keys absent from the removed 2.0.6 templates.

## Source and control gates

- Python unit tests: PASS, 30 tests.
- Exact Python compile: PASS, 17 shipped AIO/Midnight Python files compiled without writing caches into the release tree.
- PowerShell parser: PASS for `bdo_aio.ps1` under Windows PowerShell syntax.
- Personal-path and credential-shaped text scan: PASS after sanitizing release documentation.
- Generated `__pycache__` directories: none in the release tree.

## Graphics semantic gates

- Removed three destructive complete-file templates, including the Ultra screenshot preset.
- Added 1080p, 1440p, and DLDSR 4K Remastered merge patches; all assert saved `graphicOption = 9` and High `textureQuality = 0`.
- All three patches dry-run and write successfully against a scratch copy of the current live file.
- For each output, every non-profile key and line is byte-for-byte preserved; key inventory is identical and the current test outputs remain 2,707 bytes.
- Missing or duplicate current-client keys fail closed; writes use a same-directory temporary file and atomic replace after a complete backup is created by the AIO.
- No invented hidden BDO engine settings are shipped. Adapter/display identity, window mode, HDR, audio, UI, camera, account values, and unknown/current keys are not touched.

## Genital PAC/material gates

- All 22 bundled PACs contain exactly one parsed nude-material stem and resolve to a matching diffuse DDS among the 18 bundled texture files.
- Every matching DDS passes magic, 124-byte header, and non-zero-dimension validation.
- Female native plus every opt-in female donor: PASS, 51 generated files, 93,659,923 bytes.
- Native male normal: PASS, 18 generated files, 7,422,441 bytes.
- Native male hard: PASS, 18 generated files, 6,596,347 bytes.
- Combined all-female plus six-native-male run: PASS, 50 PAC outputs, 17 deduplicated DDS outputs.
- Combined canonical injector dry run: PASS, 67 candidates/winners, 25 intentional new meta entries, 0 overrides, 0 invalid/current-meta failures, 1 ignored tool README.
- Exact old material relationships verified, including female `PHW_01` sharing, Ninja `PHM_00`, normal Wizard `PWM_01`, and hard Wizard `PWM_00`.

## Current tool gate

- Meta Injector 1.4.1 SHA-256 `766BF9A050637AC3CF55956084B923974DD3B55C9D5B0F290E13C24C66BF9B6A`.
- PartCutGen 1.1.0 SHA-256 `7066B5A599CBF35445F9153B68AD56B17EC1C61B598CAF0F400A1A8EC700D9C5`.
- NVIDIA Profile Inspector 3.0.2.1 SHA-256 `1EBD8129B3C564BF226291FB3344819FD59668066F0C5E03334A69A04A62859E`; current official upstream release at audit time.
- OptiScaler 0.9.4-final SHA-256 `FBFB6676B829DAD7E020FB830586A16AA0EC6ADD78016DB48EF12E2AE1803231`; isolated experimental opt-in only.
- Meta Patcher 1.1.0 is not bundled and is not used for this detected NA client.

## Preserved 2.0.6 gates

- Body-size live rerun: 75 files, 17,562 attribute edits with exact source field widths.
- Full Midnight/XYZW canonical dry run: 41,800 candidates, 41,460 winners, 340 deterministic overrides, 0 invalid/current-meta failures, and 0 skipped collections.
- Live heisha Wukong regeneration, slot hide, pubic/native donor, censorship, Midnight non-interactive mode, and experimental ownership-safe uninstall remain covered by the unchanged code and regression suite.

## Runtime boundary

- The installed game, live PAZ, and user GameOption were read only.
- No game, launcher, Meta Injector, Meta Patcher, PartCutGen, NVIDIA Profile Inspector, or experimental client DLL was launched.
- Black-character rendering, genital mesh fit/UV appearance, graphics appearance/FPS, and full patch workflow require the user's isolated in-game retest.
