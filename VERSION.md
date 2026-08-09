# BDO-AIO 2.3.1 hotfix candidate

- Latest public release remains **v2.3.0** until the corrected slider is confirmed in-game.
- **v2.3.1 lower-belly depth fix:** live vanilla data shows 30 of 75 descriptors
  already cap `Bip01 Spine` Z/depth at **1.35**. The v2.3.0 belly presets were
  therefore too low to unlock the last slider on those classes.
- **Lower Back and Belly restored safely:** a separate `belly` ceiling targets only
  `Bip01 Spine`. The declared X `HeightAxis` (torso length) remains untouched; only
  Y/Z lower-back and abdomen girth can widen.
- Corrected belly presets: baseline **1.35**, recommended **1.45**, high **1.60**,
  extreme **1.75**. Named presets opt in automatically; custom specs remain literal.
- Tool-validated as widen-only and length-preserving across the live 75-file customization set.
- **Vanilla restore / body-size footgun closed (warnings only):** game updates often need
  `[R] -> [1]` first or the launcher stalls. Characters saved above stock Max are clamped
  on load under vanilla; Beauty Album / Customization presets can be overwritten with
  clamped data. Salon rebuilds cost pearls. The app now:
  - Explains the safe free order on body-size menu and restore
  - Requires confirm before dry-run restore
  - Snapshots `Documents\Black Desert\Customization` -> `backup\Customization-*`
  - Prints post-restore next steps (update -> re-inject -> then log mains)
- Candidate is intentionally not packaged or published until the user confirms the
  last slider gains visible travel in-game. v2.3.0 remains the rollback release.

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
