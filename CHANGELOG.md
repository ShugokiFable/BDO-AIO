# Changelog

## v2.0.7 - 2026-08-01

### Work record
- AI application: Codex desktop
- Parent: v2.0.6 (`ad1534c`)
- Task: repair genital PAC/UV texture deployment and replace destructive graphics-file copying with safe Remastered-quality 1080p/1440p/4K patches
- Runtime status at start: **contradicted** (user reports black characters and broken graphics settings)
- Authority state: unchanged until the isolated full snapshot passes validation

### Genital PAC/material repair
- Read the nude material stem embedded in each restored PAC and deploy that exact authored diffuse/normal/material texture set under its original filename.
- Removed donor texture renaming: renaming a PAC for another female class does not rewrite its internal material binding or UV atlas.
- Fixed native PAC mismatches already present in the old packs: Mystic, Valkyrie, Kunoichi, Lahn, and Maehwa use `PHW_01`; Ninja uses `PHM_00`; normal Wizard uses `PWM_01`; hard Wizard uses `PWM_00`.
- Validate PAC material count, matching diffuse DDS presence, DDS magic/header, and non-zero dimensions; fail the generator instead of deploying a black/untextured body.
- Kept female donor reuse opt-in and kept all male choices native-only.

### Safe current-client graphics patches
- Removed all three stale complete `GameOption.txt` replacements and the Ultra screenshot profile.
- Removed the unused hardcoded `GameOptionGraphicsPath.txt` placeholder; the AIO resolves the Windows Documents folder directly.
- Added maximum-quality Remastered merge patches for 1920x1080, 2560x1440, and optional 3840x2160 DLDSR.
- Added an atomic line-preserving patcher that refuses duplicate/missing keys and preserves adapter identity, window mode, HDR, audio, UI, camera, gamma/contrast, account settings, ordering, line endings, and unknown/new client fields.
- Corrected current-client enum values from installed 2026 Lua bytecode: the Remastered UI entry saves `graphicOption = 9`, Ultra saves `8`, and High textures save `textureQuality = 0`. The stale 2.0.6 files incorrectly forced `7` and low textures (`2`).
- Use only current, locally verified GameOption keys; no fake ray tracing, DLSS, FSR2/3, Lumen, LOD, shadow, bloom, or other invented hidden-engine keys.
- Keep the current NVIDIA Profile Inspector 3.0.2.1 profile separate and optional; its documented driver-level texture quality settings do not replace GameOption.

### Validation added
- Added regression tests for line-preserving GameOption merges, fail-closed missing keys, and the shipped Remastered/High values.
- Added regression tests for original PAC material filenames and missing-diffuse failure.
- Validated all 22 bundled genital PACs against all 18 bundled DDS files and generated every female donor, male-normal, and male-hard combination against current read-only NA metadata.

## v2.0.6 - 2026-08-01

### Midnight deploy
- Added a non-interactive `--yes` mode to the bundled Midnight deployer and pass it from the AIO after the existing `Deploy now?` confirmation.
- Removed the stale second XYZW/path-length warning. XYZW stays enabled when selected and continues through the canonical short-path injection stage.
- Fixed the Full Wizard to call the same PartCutGen and canonical Meta Injector functions as menus 4/5 instead of bypassing the 2.0.5 injection fix.

### Body-slider crash fix, completed
- Preserve each live vector attribute's exact byte width, including the trailing padding now present on some `Default` fields.
- Fresh live reproduction now passes all 75 files and 17,562 attribute edits with every output byte-length identical to its source.

### Current class coverage and donor safety
- Regenerated heisha 0.4.1 armor/underwear hides from the live 2026-08-01 NA `pad00000.meta`.
- Added 26 Wukong underwear files and 553 Wukong armor files under the verified live prefix `34_pgms`; Dosa coverage remains present.
- Female donor reuse remains available. Male genital packs are now strictly native-only; Archer, Hashashin, Sage, Dosa, Wukong, and the Wizard revamp never receive a borrowed penis mesh.

### Region-correct tool workflow
- Detect the installed client region from `service.ini`.
- Skip Meta Patcher on NA/EU as directed by the author's FAQ. Other detected official regions may be offered the separately downloaded tool; unknown regions are never guessed.
- Meta Injector 1.4.1 and PartCutGen 1.1.0 remain the current bundled heisha workflow. Meta Patcher is not bundled.

### Experimental DLL cleanup
- Removed the redundant DLSS Enabler installer, loose `version.dll`, zzDLL upgrade swaps, and DirectStorage injection.
- Menu X now offers only the unmodified official OptiScaler 0.9.4 bundle and remains explicitly unsupported/unsafe for BDO.
- Uninstall refuses filename-only deletion without the AIO install marker and will not remove an unrelated or unverifiable proxy DLL.

## v2.0.5 - 2026-08-01

### Work record
- AI application: Codex desktop
- Model: GPT-5
- Reasoning mode: high
- Parent: v2.0.4 (`783202e`)
- Task: fix the body-slider crash, replace the path-length skip with a real unlimited-content staging strategy, classify failed patch inputs, and audit redundant tools
- Intended files: `bdo_aio.ps1`, `tools/bdo_meta/body_size_patcher.py`, path/injection helpers, tests, release/control documentation
- Runtime status at start: **contradicted** (user reports slider-only crash)

### Body slider crash fix
- Replaced scalar XML edits such as `Min="0.7"` with the three-component vectors BDO actually stores, such as `Min="0.70 0.70 0.70"`.
- Patch only the matching `BoneName` tag, including duplicate attributes, without normalizing BDO's non-standard XML dialect.
- Preserve the byte length of every extracted `customizationboneparamdesc.xml`; abort the entire generator on malformed/scalar source instead of emitting a partial patch.
- Live-PAZ reproduction: 75 files, 6,786 attribute edits, every output exactly the original byte length.

### No-delete injection path
- Replaced the v2.0.4 MAX_PATH warning/deletion flow with `inject_stage_builder.py`.
- Canonicalize Meta Injector 1.4.1 organizer markers, flatten non-game layers, resolve overrides deterministically, and invoke the injector through temporary short drive roots with its official `-files` argument.
- Keep all Midnight XYZW collections. No collection is deleted or skipped for path length.
- Validate normal paths against the current live meta; preserve `_add` and `_legacy` semantics.
- Migrate old unmarked pubic style folders and old generated new-class files into correct organizer/`_add` staging automatically.

### Failed-file fixes
- Pubic style folders now use an underscore organizer marker, and generated README files use Meta Injector's dot-ignore marker.
- New-class pubic/genital files absent from current meta are intentionally routed through `_add`, not reported as failures.
- Removed redundant donor-named PAC copies from new-class genital output.
- Exact expanded-censorship scan now excludes `texture_thumbnail`, stale legacy names, Shai/child/age-ambiguous names, and non-DDS decode failures.
- Stored ICE-encrypted DDS entries are decrypted and magic-validated before output.
- Pubic composited nude DDS deterministically wins collisions with plain nude textures carried by genital packs.

### Suite reliability and tool audit
- Detect Python through `python.exe`, the `py` launcher, or normal per-user installs.
- Apply-all now reports and returns generator failures instead of claiming success.
- Removed dead Resorepless and PAZ Unpacker launchers plus the obsolete path-length deletion helper.
- Meta Injector 1.4.1 now preflights its exact BDO Toolkit 1.3.0 dependency.
- Meta Patcher 1.1.0 is correctly treated as a separate optional/client-dependent correcting pass and offered when present.
- `config.json` is now generated/ignored; `config.example.json` is the sanitized public template.

## v2.0.4

### Meta Injector path-length guard
- Pre-check `files_to_patch` for Windows **MAX_PATH (~260)** before launching Meta Injector
- Warns when XYZW collections create deep paths under Program Files
- Offers to delete `_midnight_xyzw\_01_xyzw_collections` before inject
- Tool: `tools/bdo_meta/path_length_check.py`

## v2.0.3

### PAZ stock vs modded status scan
- Main menu **[S]** + status line on main screen: detect whether `pad00000.meta` is **STOCK / MODDED / RESTORED**
- Uses Meta Injector `pad00000[*][*].meta.backup` files + hash compare to current meta
- Lists **staged** `files_to_patch` AIO packages vs Midnight content
- Flags experimental OptiScaler/DLSS marker in game root
- Tool: `tools/bdo_meta/paz_status_scan.py --paz <PAZ> [--json] [--write-status auto]`

## v2.0.2

### Per-class pubic hair / female genitals
- Options **[6]** pubic: pick **which females** get the style (ALL / native bins / new females / custom multi-select / type prefixes)
- Options **[V]** female 3D vagina: same per-class picker
- Options **[F]** new-females package: choose which of Seraph/Deadeye/… to apply
- CLI: `pubic_hair_apply.py --classes phw,pdkl` · `genital_pack_apply.py --female-classes …`
- Config: `pubicHairClasses`, `genitalFemaleClasses` (empty = all)

## v2.0.1

### Hotfix (post-2.0.0 audit)
- **Apply-all RESTORED** fixed for custom body size (`--preset custom` was invalid; now uses effective min/default/max)
- `body_size_patcher.py` accepts `--preset custom` with required `--min/--default/--max`
- Slot hide / body size: clean fatal when `pad00000.meta` missing (no stack trace)
- Expanded censorship name match tightened (underpaint lb/ub + under/cull; less logo collateral)
- `config.json` template includes `slotHideClasses` + `heishaRoot`
- Apply-all genitals: pack presence check; new-females folders when reuse enabled

## v2.0.0

### Censorship expansion
- New tier **expanded**: legacy medium pack + live PAZ scan for under-armor / decal textures on all classes/outfits

### Polish
- **[A] Apply ALL RESTORED choices** (body → slots → pubic → censorship → genitals; optional new-females)
- Full wizard can run RESTORED batch after Midnight
- **Per-class slot hide** (`slotHideClasses` / `--classes phw,pdkl`)
- **[H] Post-patch regen helper** (heisha `run.cmd` guidance)
- **[R] Restore / clean** AIO folders, experimental DLLs, backup restore, verify-game notes

### Experimental upscale pack
- Bundled **upgrades/**: newer DLSS (nvngx), AMD FidelityFX/FSR, DirectStorage 1.4
- Installer can **swap FSR** (`fsr31` + upgraded amd_fidelityfx_*) and optional DStorage
- Full offline release includes OptiScaler + Streamline + upgrades

## v1.4.2

### NEW FEMALES genitals + pubic [EXPERIMENTAL-REUSE]
- Options hub **[F]**: Seraph, Deadeye, Woosa, Maegu, Scholar, Nova, Corsair, Drakania, Guardian
- Preferred per-class genital donors + renamed textures
- Pubic: synthesize class-named nude DDS from preferred Midnight base + hair bin
- CLI: `--new-females` on `genital_pack_apply.py` / `pubic_hair_apply.py`
- Outputs: `_genital_EXPERIMENTAL_new_females`, `_pubic_hair_EXPERIMENTAL_new_females\<style>`
- Honesty: replaces TGS/Suzu nude PAC for those classes — not original art

## v1.4.1

### Donor reuse is experimental and separated
- Genitals / pubic hair default to **NATIVE (RESTORED)** only
- **EXPERIMENTAL-REUSE** (donor mesh/bin for missing classes) is **opt-in** in Options **[6]** / **[V]**
- Separate `files_to_patch` folders: `_…_RESTORED_native` vs `_…_EXPERIMENTAL_reuse`
- Python CLIs: `--native-only` (default) vs `--all-classes` (experimental reuse)
- Config keys: `pubicHairReuse`, `genitalReuse` (default `false`)
- Docs/README/FEATURE-LABELS updated to match the app

## v1.4.0

Best-effort all-class coverage for genital/pubic packs with NATIVE vs EXPERIMENTAL-REUSE labeling.

## v1.3.5

Honesty labels (MODERN / RESTORED / EXPERIMENTAL) in app and docs.

## v1.3.0

Censorship tier packs and legacy penis / 3D vagina menus.

## v1.2.0

Body size limits, slot hide, pubic hair (easy RESTORED set).

## v1.1.0

Presets + custom body size values.

## v1.0.0

Initial AIO: Midnight wizard, GameOption, NVIDIA .nip, optional EXPERIMENTAL DLSS hub.
