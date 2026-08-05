# Changelog

## v2.1.2 - 2026-08-05 - crash fix after genital generation

### Crash after a successful genital run
`Apply-GenitalPacks` still referenced `$reuse` in its success message after the
variable was removed in 2.1.1, so the launcher threw
`The variable '$reuse' cannot be retrieved because it has not been set` and
exited **after** the packs had already been written correctly. The generated
output was fine; only the closing message crashed.

### Static guard so this cannot recur
New `tools/bdo_meta/test_launcher_static.ps1` walks the launcher's AST and fails
when a variable is read but never assigned in its function, or when a called
function does not exist. Verified against the real bug: reintroducing the
`$reuse` reference makes it fail with the exact line number. This is the second
stale-reference bug of this kind, so it is now covered by a test.

### Wording
Removed every remaining EXPERIMENTAL-REUSE label from the menus. Cross-class
genital reuse no longer exists, so offering it in text was misleading -- one menu
still read "EXPERIMENTAL-REUSE only if you opted in" on a run where nothing of
the sort was possible.

### Note on PartCutGen "matched 0 files"
Three exclusion patterns in the bundled Midnight pack match nothing
(`pwge_00_lb_0001_dm`, `pdw_00_ub_0002_mul*`, `pdw_00_ub_0002_mul_na*`). These
are informational: PartCutGen finished with `Saving ... DONE` and wrote
`partcutdesc.xml`. Nothing to fix on the AIO side.

## v2.1.1 - 2026-08-04 - genital packs restricted to authored meshes

### Work record
- Task: audit 3D vagina / penis for the failure that made new-class bodies vanish
- Runtime status: **tool-validated** against the shipped pack and the live game
  index — not yet in-game confirmed

### Genitals do NOT have the invisible-body bug
Checked every generated PAC against the textures the pack ships: **0 missing
materials**. Nothing is renamed to an invented material name, so no body can lose
its material the way the pubic alias attempt did. Males were already safe — they
never had donor reuse, and the 6 classes without an authored mesh are skipped.

### But female donor reuse was wrong in a different way
A genital PAC is a whole body: it carries the mesh **and** the class's skin
material. Copying one under another class's filename hands that class the donor's
body and the donor's skin. Measured against the shipped pack:

- All 10 authored female meshes bind exactly the atlas their vanilla body already
  uses — proof they were authored per class.
- **7 of the 9 donor mappings bound a different atlas**: Deadeye→Ranger,
  Woosa/Scholar/Nova→Witch, Drakania→Dark Knight, Guardian/Corsair→Sorceress.
  Only Maegu and Seraph happened to match. That is the original "Deadeye body
  looks stretched" report.

Female cross-class reuse is removed. Supported: the 10 female classes with an
authored mesh (Sorceress, Ranger, Tamer, Valkyrie, Witch, Kunoichi, Dark Knight,
Mystic, Lahn, Maehwa) and the 6 male classes with one (Warrior, Berserker, Musa,
Wizard, Ninja, Striker). Every other class is skipped with a stated reason.
`--all-classes` / `--new-females` are still accepted but print a note and do
nothing, so an older launcher cannot crash.

### Underwear was being written to a path the game never reads
`copy_female_class` / `copy_male_class` put both the nude and the underwear PAC
under `nude/`. Verified against the live game index: the real entry is
`character/model/1_pc/<folder>/armor/38_underwear/<prefix>_00_uw_0001.pac`, while
the same name under `nude/` is **not** a meta entry. All 16 underwear PACs were
therefore landing where nothing looks and being routed to `_add` as bogus new
entries. Added `female_underwear_folder()` / `male_underwear_folder()` and routed
them correctly.

### Validation
- Python suite: PASS, 83 tests.
- PowerShell suites and the 5.1 parser: PASS.
- Full real-pack run (10 females + 6 males): exit 0, 32 PACs, 17 textures,
  **0 underwear PACs under nude/, 0 files routed to `_add` (was 16), 0 paths
  absent from the game meta, 0 PACs with a missing texture.**
- Requesting the 9 unsupported classes produces 9 explicit skips and no output.
- Not verified: in-game appearance. Requires Meta Injector.

## v2.1.0 - 2026-08-04 - body slider repair + per-class pubic hair

### Work record
- AI application: Claude Code
- Model: Opus 5
- Parent: v2.0.9
- Task: sliders applied to bones the user never selected; bodies stretching (Deadeye)
- Runtime status: **tool-validated** against the live client — not yet in-game confirmed
- Scope: body sliders only. Pubic-hair per-class leakage and 3D vagina are deferred.

### Root causes found in the live game data (75 `customizationboneparamdesc` files)
- **The patcher overwrote `Default`.** Vanilla `Default` is per-class and
  anisotropic (Calf ships `1.10 0.88 1.00`, Thigh `0.97 0.90 0.90`, and 296 calf
  / 243 upper-arm / 112 thigh tags are non-uniform). Writing one uniform number
  over it re-proportioned bodies with no slider moved. This is the stretching.
- **All three axes were written with the same value.** The game declares which
  axis is bone length per tag: `HeightAxis="X"` on Thigh, Calf, Pelvis, Spine,
  UpperArm and Forearm; Hip and Breast declare none and are pure girth. Raising
  the length axis lengthens limbs and torso instead of thickening them.
- **`legs` / `spine` / `arms` were selectable at all.** They are length-dominant,
  and they are children of Pelvis, so they already inherit its scale — selecting
  pelvis visibly moved them regardless of the parts list.

### Fixes
- `Default` is never written. The game's per-class baseline is preserved exactly.
- The declared `HeightAxis` component is never written. Thigh girth widens; leg
  length stays vanilla, so characters cannot be made taller.
- Widen-only: a component is raised toward the requested max and never lowered
  below what the game already allowed.
- Groups reduced to `breasts`, `thighs`, `butt`. `legs`/`spine`/`arms` retired.
- **`butt` now patches hip *and* pelvis together.** Measured on the live client:
  33 of 75 body files lock `Bip01 L/R Hip` Max at ≤1.00 — the butt slider cannot
  move at all on those classes — and in all 33 the Pelvis still has headroom.
  Patching hip alone was a no-op for ~44% of classes, matching the long-standing
  community reports that the butt slider does nothing on newer classes.
- Each part carries its own max. Recommended preset: breasts 2.0, thighs 1.5,
  butt 1.4. Custom mode asks per part and writes only the parts chosen.
- A named preset re-derives its numbers on upgrade, so tuning a preset reaches
  users who picked it; only `custom` keeps a literal spec.
- Launcher config collapsed to one literal `bodySizeParts` spec
  (`breasts:2.0,thighs:1.5,butt:1.4`); `bodySizeMin`/`Default`/`Max` removed.
  Legacy configs migrate once with a visible message. An empty or retired-only
  selection resolves to *nothing*, never to "all".

### Per-class pubic hair (step 2) — root cause was never the filter
Measured from the Midnight nude PACs, which store their texture name once each:

- **13 of 19 female bodies render from ONE texture, `phw_01_nude_0001`**:
  Sorceress, Kunoichi, Mystic, Lahn, Nova, Maehwa, Drakania, Maegu, Woosa,
  Scholar, Valkyrie, Deadeye, Seraph. Only Tamer, Guardian, Dark Knight,
  Corsair, Ranger and Witch own their texture. Styling that one DDS styles all
  13 no matter what the class filter says — the filter was working; the target
  was shared. This also matches the community reports about shared body art.
- `NEW_FEMALE_PUBIC_BASE` guessed a donor atlas per class and was **wrong for 7
  of 9 entries** (Guardian was sent to Sorceress's atlas although it owns
  `pgw_01_nude_0001`; Nova/Drakania/Maegu/Woosa/Scholar/Deadeye were all sent to
  the wrong atlas). Donor guessing is gone: the atlas is read from the PAC.
- The launcher also wrote a **second** pubic package ("new females EXPERIMENTAL")
  with its own class list in the same run, and named packages per style/mode so a
  previous run's package stayed in `files_to_patch` and kept being injected.

Fixes (final iteration):
- New `tools/bdo_meta/body_atlas.py` resolves each class's nude body PAC and the
  atlas it actually references, with explicit source precedence (TheGreatSage
  primary, Suzu for Tamer/Deadeye) instead of glob order.
- The earlier material-alias approach (renaming the PAC's embedded texture stem
  to a private name) was tried and **reverted**: that string is a MATERIAL name
  resolved through the engine's material registry, not a texture path a new DDS
  can satisfy, so aliased bodies turned invisible in game.
- Final approach is **texture-only, zero PAC writes**. Classes that own their
  atlas are styled in place (PRIVATE-ATLAS). Classes sharing an atlas are styled
  once for the whole group when every sharer is selected with the SAME style
  (WHOLE-SHARED-GROUP); partial or conflicting selections are SKIPPED with a
  clear notice listing the sharers - never guessed, never widened silently.
- Styles are **per class** (`--styles pnw=full_bush,pcw=trimmed`); the atlas a
  class renders from is read from its PAC, so donor guessing is gone.
- One package (`_pubic_hair_perclass`); stale `_pubic_hair_*` packages are removed
  before every run. The second generator pass is deleted.
- Empty selection is a hard error, never "all".
- Disk cost is surfaced in the menu before generating (~111 MB per distinct style
  chosen among shared-atlas classes).

### Immersive pubic preset
One-key preset giving each class a different look, from the user's breakdown:
full bush (Guardian, Deadeye), medium bush (Witch, Ranger), small bush
(Drakania, Sorceress), trimmed (Corsair, Mystic), thin landing strip (Seraph,
Woosa), shaved innie (Valkyrie, Maehwa). Dark Knight, Kunoichi, Lahn, Maegu,
Nova, Scholar and Tamer are **omitted on purpose** — the nude body is already
bare, so leaving them unselected is both the correct look and free.

Known asset limit: **Corsair cannot receive pubic hair.** Its texture is
22,369,776 bytes and no shipped hair bin matches that size. It is skipped with a
clear message, and the menu warns before generating.

### Restore to vanilla (new)
Meta Injector does not edit the original PAZ archives — it appends new ones
(21 files, 1.83 GB on the test machine) and rewrites `pad00000.meta`. Restoring
the meta alone therefore leaves multi-GB orphans behind, and any later inject
re-applies from whatever is still in `files_to_patch`, which is why a restore
could look like it did nothing.

- New `tools/bdo_meta/vanilla_restore.py` with `scan`, `backup`, `restore`.
- `restore` puts back the **oldest** backup (a newer one can be a backup of an
  already-injected meta), deletes the injected PAZ, removes the inject stage, and
  verifies the result references exactly the backup's PAZ set. Dry run by default;
  the current meta is saved as `pad00000.pre-restore.meta` before writing.
- A PAZ is deleted only when it is **both** unreferenced by the restored meta
  **and** numbered above the highest number that meta references — vanilla ships
  unreferenced low-numbered archives and those are never touched.
- `backup` snapshots a pristine meta to `pad00000.BDOAIO-VANILLA.meta` with a
  sha256 sidecar, and **runs automatically before every inject**. It refuses to
  snapshot an already-injected meta as "vanilla".
- Launcher menu `[R]` gains `[V]` restore, `[S]` scan, `[B]` backup.
- AIO settings in `config.json` are never touched by a restore.

### Validation
- Python suite: PASS, 80 tests (body size, body atlas, vanilla restore, pubic).
- PowerShell: `test_body_size_config.ps1`, `test_pubic_config.ps1`,
  `test_meta_inject_launcher.ps1` all PASS; `bdo_aio.ps1` parses clean under
  Windows PowerShell 5.1.
- Live-asset body-size runs (read-only inputs, output to scratch), diffed
  byte-for-byte against the originals across all 75 files:
  - recommended preset (breasts 2.0 / thighs 1.5 / butt 1.4) — all changes on
    the 7 selected bones only;
  - `breasts:2.0` only — breast bones only, 0 elsewhere;
  - 0 files resized, 0 `Default` changed, 0 HeightAxis components changed,
    0 ranges narrowed, 0 bytes changed outside the selected tags.
- Live-asset pubic runs (read-only inputs, output to scratch):
  - shared-atlas partial selection (e.g. `pnw=full_bush` alone) — SKIPPED with
    the full sharer list, 0 files written;
  - whole shared group with one style (13 classes, `full_bush`) — exactly one
    styled DDS generated, 0 PACs written, 0 other atlases touched.
- Note: Guardian has no exact hair bin, so it uses a same-size donor bin (logged
  as `same-size donor`). Placement comes from `offsets.bin` and is unaffected.
- Not verified: in-game appearance of styled textures. Requires Meta Injector +
  beauty salon; pubic-hair per-class results not yet in-game confirmed.

## v2.0.9 - 2026-08-01

### Work record
- AI application: Codex desktop
- Model: GPT-5
- Reasoning mode: high
- Parent: v2.0.8 (`1f84a4e`)
- Task: diagnose and repair restored full-bush textures appearing shaved on Witch/Sorceress
- Intended files: pubic texture generator, one regression test, version/release documentation
- Runtime status at start: **contradicted** for pubic hair (user observed a shaved character despite a clean injector run); 3D vagina remains user-untested
- Authority: edited the clean authoritative Git checkout directly, per the user's no-duplicate/no-output preference; parent commit and GitHub release history provide rollback

### Restored pubic DDS layout repair
- Proved the PAC material bindings and canonical stage precedence were correct: Sorceress uses `phw_01_nude_0001`, Witch uses `pww_01_nude_0001`, and the generated pubic files win injection.
- Found the silent failure: the restored offset table addresses a 4K DXT1 DDS ending at byte 11,184,948, while Midnight ships Ranger/Sorceress/Witch as 89,478,612-byte uncompressed 32-bit DDS files. The old code checked only file length and therefore wrote compressed blocks into unrelated raw pixels while reporting success.
- Preserve the exact legacy byte patch for compatible Tamer/Dark Knight DXT1 files.
- For same-size 32-bit mipmapped DDS files, decode the selected and shaved DXT1 blocks, apply their per-pixel style delta to the matching mip/UV coordinates, and preserve the current body texture, DDS header, mip layout, and alpha.
- Reject unsupported DDS layouts and malformed/length-mismatched overlay resources instead of reporting a false success.

### Validation
- Python suite: PASS, 32 tests including exact DXT1 preservation and DXT1-to-32-bit translation.
- Live-asset dry run (read-only inputs): PASS for Sorceress and Witch; both kept 89,478,612-byte files, byte-identical 128-byte headers, unchanged alpha, and visible full-bush pixels in the expected UV region.
- Temporary generated DDS files and preview were deleted after validation; no duplicate product snapshot or retained output was created.
- Runtime status: **tool-validated**; user must regenerate the pubic option, rerun Meta Injector, and confirm in game. 3D vagina remains untested.

## v2.0.8 - 2026-08-01

### Work record
- AI application: Codex desktop
- Model: GPT-5
- Reasoning mode: high
- Parent: v2.0.7 (`9f57495`)
- Task: hotfix the canonical Meta Injector launcher after Windows PowerShell captured stage-builder console output as the stage path
- Intended files: `bdo_aio.ps1`, PowerShell regression check, and release/control documentation
- Runtime status at start: **contradicted** (user screenshot shows `Start-Process -ArgumentList` rejecting `System.Object[]`)
- PartCutGen evidence: **runtime-evidenced success** (`partcutdesc.xml` saved after 1,679 exclusions; zero-match optional patterns are informational)

### Meta Injector launch hotfix
- Routed canonical stage-builder stdout to the console instead of PowerShell's function success stream, keeping the returned stage path scalar.
- Cast the returned path to `System.String` and pass Meta Injector one explicit quoted `-files` argument string for Windows PowerShell compatibility.
- Added a regression that emits two simulated builder report lines and proves the function still returns only `X:\BDO_AIO_INJECT`.

### Validation
- Windows PowerShell parser: PASS.
- Exact PowerShell regression: PASS.
- Existing Python suite: PASS, 30 tests.
- Runtime status: **tool-validated**; user Meta Injector rerun and in-game validation remain required.

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
