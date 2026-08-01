# Changelog

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
