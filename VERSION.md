# BDO-AIO 2.2.0

- Parent: `v2.1.4` (consolidates 2.1.5 + 2.1.6 + body-preset docs already in 2.1.3)
- Bump: **minor** — censorship rewrite + genital safety + body Max clarity + UI cleanup

## Highlights

### Censorship removal actually works (and no longer holes the body)
- Blanks are **rebuilt from the live client**, not copied from the ~2018 Resorepless pack
- **DXT5 / DXT3** only: zero alpha → overlay stops drawing → body can show
- **DXT1 never blanked** (opaque black or alpha-test kills the mesh — measured twice)
- **`*_cull*` never blanked** (geometry clip masks — 2.1.4 rule, all tiers)
- Stale 4×4 stubs / size-mismatched pack files rejected; live rebuilds used instead
- Expanded on a 2026 NA sample: **236** safe emits (was ~450 with destructive zeros)
- Default tier remains **`off`**
- Known limit: built-in shorts on a **DXT1 base map** need a **remesh** (XYZW collections), not texture censorship
- Doc: `TEXTURE-BLANKING-RULES.md` (repo root)

### Genital packs no longer break underwear hide
- 3D vagina / penis write **nude body PAC only**
- Never write `armor/38_underwear/*_uw_0001.pac` (was beating Midnight’s ~1 KB dummy)

### Body size Max ceilings (from 2.1.3, still current)
- Presets are **Max ceilings only** (not forced body size)
- Stock Max is **per part**, not “all 1.25”
- **vanilla** 1.25 / 1.15 / 1.10 · **recommended** 1.37 / 1.30 / 1.18 · **high** 1.65 / 1.40 / 1.19 · **extreme** 2.00 / 1.45 / 1.20
- Above recommended: breasts may **clip outfits**, thighs may **collide**, butt may **pyramid**

### UI / recovery
- `[R]` recovery menu: 4 clear actions (restore game vs clear stage)
- 3D vagina class picker lists only the **10 authored-mesh** classes
- Pubic menu names private-atlas vs shared-atlas groups up front

## Upgrade note
If you previously injected a larger censorship set, **restore vanilla meta first** (`[R]`), then re-apply — omitted files otherwise stay live.
