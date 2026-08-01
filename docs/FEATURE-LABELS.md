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
| Censorship tiers | Options **C** | Classic under-armor texture packs |
| Penis / 3D vagina | Options **V** | Classic mesh packs; old classes |
| Original resorepless.exe | Options **9** | Reference launcher only |

`files_to_patch` outputs for these use clear names, e.g. `_body_size_limits`, `_slot_hide_*`, `_pubic_hair`, `_censorship_*`, `_genital_legacy`.

## EXPERIMENTAL (from-scratch)

**Not** a Resorepless or Midnight restore. Built as optional extra in this AIO.

| Feature | Menu | Location |
|---------|------|----------|
| OptiScaler / Streamline / DLSS-style inject | Main **[X]** only | `experimental\dlss\` |

Hard gates, WARNING.txt, and **NOT SAFE** labeling. Kept out of the RESTORED options list.

## User content (not “features we invented”)

| Feature | Menu |
|---------|------|
| GameOption graphics profiles | **G** |
| NVIDIA Profile Inspector `.nip` | **N** |

## Best-effort all-class coverage

Where classic packs only had old classes, the AIO may **reuse a donor mesh/bin** renamed for Seraph, Deadeye, Woosa, etc.

| Apply mode | Label in logs / README under files_to_patch |
|------------|-----------------------------------------------|
| Exact classic asset for that class | **NATIVE** (still RESTORED feature) |
| Donor mesh/texture reused for missing class | **EXPERIMENTAL-REUSE** (must not be sold as native art) |

Body **size limits** already touch every `customizationboneparamdesc` in live PAZ (all classes).

## Honesty rules

- Do not rebrand EXPERIMENTAL inject as RESTORED.
- RESTORED packs that only cover old classes stay labeled limited/legacy in menus.
- Mesh-reuse for new classes is **EXPERIMENTAL-REUSE**, not NATIVE.
