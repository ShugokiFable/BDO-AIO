# BDO-AIO 2.3.0

- Latest public release: **v2.3.0** (GitHub / full.7z).
- **Lower Back and Belly restored safely:** a separate `belly` ceiling targets only
  `Bip01 Spine`. The declared X `HeightAxis` (torso length) remains untouched; only
  Y/Z lower-back and abdomen girth can widen.
- Conservative belly presets: baseline **1.10**, recommended **1.20**, high **1.25**,
  extreme **1.30**. Named presets opt in automatically; custom specs remain literal.
- Tool-validated as widen-only and length-preserving across the live 75-file customization set.
- **Vanilla restore / body-size footgun closed (warnings only):** game updates often need
  `[R] -> [1]` first or the launcher stalls. Characters saved above stock Max are clamped
  on load under vanilla; Beauty Album / Customization presets can be overwritten with
  clamped data. Salon rebuilds cost pearls. The app now:
  - Explains the safe free order on body-size menu and restore
  - Requires confirm before dry-run restore
  - Snapshots `Documents\Black Desert\Customization` -> `backup\Customization-*`
  - Prints post-restore next steps (update -> re-inject -> then log mains)
- Full offline archive: `BDO-AIO-v2.3.0-full.7z`
- SHA256: see `BDO-AIO-v2.3.0-full.7z.sha256`

## Also retained from 2.2.0

- Censorship rewrite: live-client blanks, **DXT5/DXT3 only**, never DXT1, never `*_cull*`.
  Default **off**. See `dev/TEXTURE-BLANKING-RULES.md`.
- Genital packs write the nude body PAC only - no underwear overwrite.
- Body Max presets: vanilla / recommended / high / extreme.
- Midnight deploy + PartCutGen + Meta Injector wizard, `[R]` recovery menu.

## Upgrade note

If you previously injected a larger censorship set, restore vanilla meta first (`[R]`), then
re-apply - files the new run omits otherwise stay live.

**Body size users:** after any vanilla restore (including for game updates), re-inject body
size **before** logging characters that were above stock Max.
