# Feature labels (MODERN / RESTORED / EXPERIMENTAL)

BDO-AIO mixes three origins. They are **separated in the UI** so nothing from-scratch is mistaken for a classic restore.

## MODERN

Current 2024–2026 Midnight / Meta Injector pipeline.

| Feature | Menu |
|---------|------|
| Gender / armor hide / XYZW collections | Options hub **1**, wizard **6** |
| Deploy Midnight pack | **3** / **6** |
| PartCutGen / Meta Injector | **4** / **5** |
| Nude + underwear through Seraph | Midnight pack |

## RESTORED

Features that **existed in Resorepless-era tooling**, reimplemented or repackaged here (not invented as new gameplay systems).

| Feature | Menu | Notes |
|---------|------|--------|
| Body size min/default/max | Options **2**/**3** | Classic size patcher; custom numbers are still this feature |
| Slot hide (gloves/boots/helmets/weapons/stockings) | Options **4**/**5** | Classic granular hide toggles |
| Pubic hair styles | Options **6**/**7** | Classic bins + offsets |
| Censorship tiers | Options **C** | Classic under-armor texture packs; **expanded** scans live PAZ for new outfits |
| Apply all RESTORED | Main **[A]** / wizard **6** | Body → slots → pubic → censorship → genitals |
| Per-class slot hide | Options **4** | Optional class prefix filter (e.g. `pdkl`) |
| Post-patch regen | Main **[H]** | heisha `run.cmd` helper |
| Restore / clean | Main **[R]** | Clear AIO patches / experimental DLLs / backup restore |
| Penis / 3D vagina | Options **V** | Classic mesh packs; old classes |
| Original resorepless.exe | Options **9** | Reference launcher only |

`files_to_patch` outputs for these use clear names, e.g. `_body_size_limits`, `_slot_hide_*`, `_pubic_hair`, `_censorship_*`, `_genital_legacy`.

## EXPERIMENTAL (from-scratch)

**Not** a Resorepless or Midnight restore. Built as optional extra in this AIO.

| Feature | Menu | Location |
|---------|------|----------|
| OptiScaler / Streamline / DLSS / FSR / DirectStorage | Main **[X]** only | `experimental\dlss\` + `upgrades\` |

Hard gates, WARNING.txt, and **NOT SAFE** labeling. Kept out of the RESTORED options list.

## User content (not “features we invented”)

| Feature | Menu |
|---------|------|
| GameOption graphics profiles | **G** |
| NVIDIA Profile Inspector `.nip` | **N** |

## Best-effort all-class coverage

Where classic packs only had old classes, the AIO can **optionally** reuse a donor mesh/bin renamed for Seraph, Deadeye, Woosa, etc.

| Apply mode | Label / output folder | Default |
|------------|----------------------|---------|
| Exact classic asset for that class | **NATIVE** / `_…_RESTORED_native` | **ON** (RESTORED path) |
| Donor for any missing class | **EXPERIMENTAL-REUSE** / `_…_EXPERIMENTAL_reuse` | **OFF** (opt-in in [6]/[V]) |
| **New females only** (Seraph, Deadeye, Woosa, Maegu, Scholar, Nova, Corsair, Drakania, Guardian) | **EXPERIMENTAL-REUSE** / `_genital_EXPERIMENTAL_new_females`, `_pubic_hair_EXPERIMENTAL_new_females` | Options hub **[F]** |

CLI: `--native-only` (default) · `--all-classes` · `--new-females` (preferred donors + synthesized pubic DDS).

**Honesty for [F]:** genital apply **replaces** Midnight/TheGreatSage nude PAC for that class with a donor genital body. Not original art.

Body **size limits** already touch every `customizationboneparamdesc` in live PAZ (all classes).

## Honesty rules

- Do not rebrand EXPERIMENTAL inject as RESTORED.
- RESTORED packs that only cover old classes stay labeled limited/legacy in menus.
- Mesh-reuse for new classes is **EXPERIMENTAL-REUSE**, not NATIVE — and stays off unless the user opts in.
