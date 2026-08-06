# BDO-AIO 2.1.4

- Parent: `v2.1.3`
- Bump: patch
- Fix: censorship `expanded` tier no longer zero-fills `*_cull*.dds` geometry clip
  masks. A zeroed DXT1 payload decodes to solid black, which culls the whole body
  region under the garment (Ranger set `0274` lost its legs).
  - `EXPAND_NAME_NEVER = ("_cull",)`, checked before every positive match rule
  - 57 staged files change: 56 revert to vanilla, 1 keeps its authored pack image
  - the 377 underwear / decal textures the tier is actually for are unchanged
- Body size: unchanged from 2.1.3
  - vanilla 1.25/1.15/1.10 (stock Max per part — not all 1.25)
  - recommended 1.37/1.30/1.18 (no-clip)
  - high 1.65/1.40/1.19 (breasts clip outfits; thighs may collide)
  - extreme 2.00/1.45/1.20 (breasts clip; thighs collide; butt pyramid risk)
