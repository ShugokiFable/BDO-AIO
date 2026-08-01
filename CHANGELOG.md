# Changelog

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
