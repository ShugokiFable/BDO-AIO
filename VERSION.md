# BDO-AIO 2.2.8

- Parent: `v2.2.0` (public). Bump: patch — restore safety warnings + Customization snapshot.
- **Vanilla restore / body-size footgun closed (warnings only):** game updates often need
  `[R] → [1]` first or the launcher stalls. Characters saved above stock Max are clamped
  on load under vanilla; Beauty Album / Customization presets can be overwritten with
  clamped data. Salon rebuilds cost pearls. The app now:
  - Explains the safe free order on body-size menu and restore
  - Requires confirm before dry-run restore
  - Snapshots `Documents\Black Desert\Customization` → `backup\Customization-*`
  - Prints post-restore next steps (update → re-inject → then log mains)
- **2.2.7 retained:** Body UNCUT removed; see `dev/PARTCUT-MECHANICS.md`.

## Retained from 2.2.0 (the public release)

- Censorship rewrite: live-client blanks, **DXT5/DXT3 only**, never DXT1, never `*_cull*`.
  Default **off**. See `dev/TEXTURE-BLANKING-RULES.md`.
- Genital packs write the nude body PAC only — no underwear overwrite.
- Body Max presets: vanilla / recommended / high / extreme.
- Midnight deploy + PartCutGen + Meta Injector wizard, `[R]` recovery menu.

## Upgrade note

If you previously injected a larger censorship set, restore vanilla meta first (`[R]`), then
re-apply — files the new run omits otherwise stay live.

**Body size users:** after any vanilla restore (including for game updates), re-inject body
size **before** logging characters that were above stock Max.
