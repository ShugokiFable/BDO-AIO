# dev/ — research notes, not a release

This branch is a **work-in-progress snapshot**, published so the findings aren't trapped on
one machine. It is **not** a release and nothing here changes the app.

The shipping release is **v2.2.0** on `main`. Do not treat this branch as installable.

## Start here

- **`PARTCUT-MECHANICS.md`** — how BDO decides to cut the body under a garment, and the three
  traps that cost two sessions of testing. This is the useful one.
- `TEXTURE-BLANKING-RULES.md` — which textures may be blanked for censorship removal, and the
  DXT1 trap that holes meshes.
- `DECISIONS.md` — decision log, including revocations.
- `STATE.md` — where work stopped.

`BOOB-WINDOW-OUTFITS.md` and `PIPELINE-VERIFY.md` are kept with **VOID banners**: their
conclusions were drawn from tests aimed at the wrong class. They're here as a record of how
the mistake happened, not as guidance.

## The open problem

`tools/bdo_meta/partcut_recut.py` restores the real nude body under an open-chested outfit,
per outfit, confirmed working in game. It isn't wired into the launcher because it needs a
hand-built outfit list per class — nothing in the game files marks a top as open-chested, so
the list can only be built by observation.

That's the part that would benefit from other people. If you identify a PAC stem for an
open-chested outfit in any class, that's a directly usable contribution.

## Contributing

Run after PartCutGen, before Meta Injector. Read `PARTCUT-MECHANICS.md` first — in
particular, verify class prefixes against `$Script:FemaleClasses` in `bdo_aio.ps1`
(`phw` is Sorceress, `pew` is Ranger). Assuming otherwise is what invalidated a whole
test campaign.
