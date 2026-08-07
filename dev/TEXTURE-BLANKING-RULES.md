# Texture blanking: what is safe, what breaks meshes

Written after 2.1.3–2.1.6, where four separate attempts to remove painted-on
underwear broke bodies in four different ways. Everything here is measured on a live
2026 NA client, not inferred.

Read this before touching `tools/bdo_meta/censorship_pack_apply.py`.

---

## The one rule

> **Only blank a texture whose pixel format carries alpha. DXT5 and DXT3 only.
> Never DXT1. Never a `*_cull*` map. Never a file from the 2018 pack.**

Everything below is why.

---

## What "blanking" actually does, per format

Blanking means replacing the image payload while keeping the exact byte size the meta
declares. What that *decodes* to depends entirely on the pixel format.

| Format | Zeroed payload decodes to | Safe to blank? |
|---|---|---|
| **DXT5 / DXT3** | `alpha0 = alpha1 = 0`, all indices 0 → **alpha 0 everywhere** | **Yes.** The layer stops drawing, the body underneath shows. |
| **DXT1** | `color0 = color1 = 0`, index 0 → **opaque black** | **No.** Paints black over the body. |
| uncompressed + `DDPF_ALPHAPIXELS` | alpha 0 | Yes |
| uncompressed, no alpha | nothing useful | No |

### The DXT1 trap, in full

DXT1/BC1 *does* have a transparent encoding. When `color0 <= color1` the block switches
to 3-colour mode where index 3 means transparent:

```
00 00 01 00 FF FF FF FF     color0=0x0000  color1=0x0001  indices=0xFFFFFFFF
```

This is byte-for-byte what the original Resorepless pack shipped inside its 4×4 stubs,
so the engine genuinely honours it. **It still breaks meshes.** Tried twice:

1. Applied to all 157 DXT1 maps the expanded scan matched → meshes broke.
2. Narrowed to only the 15 names the 2018 pack hand-picked → meshes broke again.

The block was correct and the idea was still wrong. Transparency removes a painted
layer only when the shader treats the map as an **overlay**. BDO uses DXT1 for **base
diffuse** maps, and an alpha-tested base map that is fully transparent discards the
whole mesh. A base diffuse is not an overlay, so there is nothing to "remove" — you
only ever delete the garment.

**Do not re-attempt this.** `transparent_payload()` refuses DXT1 unconditionally and
`test_dxt1_is_always_refused` fails if anyone re-enables it.

---

## `*_cull*` maps are geometry, not decoration

A `*_cull*.dds` is the **clip mask** that decides which body texels survive under a
garment. It is not painted-on censorship, despite matching every naive name filter.

Blanking one (all 57 in the client are DXT1) makes it solid black = "cull everything".
The body region under the garment is discarded while separately-materialled pieces keep
rendering — the classic symptom is **a floating torso with the boots still standing on
the ground**. That was the Ranger set `0274` bug in 2.1.3.

`EXPAND_NAME_NEVER = ("_cull",)` is checked **before** every positive match rule so no
other token can reach one.

---

## The 2018 Resorepless pack is not a source of files

25 of its 27 entries no longer describe the texture they would replace:

| Problem | Count | Example |
|---|---|---|
| 4×4 stub, 152–176 B | 9 | `pew_00_lb_0033_dec.dds` 152 B vs live **1 398 256 B** |
| mipless (flat 1024² over the client's mipped map) | 13 | `pdw_02_lb_0005.dds` 524 416 B vs live 699 192 B |
| geometry clip mask | 1 | `pdw_00_sho_0002_cull.dds` |
| gone from the client | 1 | `pbw_00_ub_0054_dm.dds` |
| **still current** | **2** | `pbw_00_ub_0054.dds`, `pnw_00_ub_0001_dec.dds` |

A 4×4 stub is the worst case: it *does* erase the painted underwear, then smears one
block across the whole UV, so the body renders as a single dead colour. That reads as
"shorts gone but no ass or crotch, broken mesh" — which is easy to misread as a partial
success. **It is not a partial success. It is a destroyed map.**

`legacy_reject_reason()` refuses any pack file that is ≤4×4 / <256 B, a clip mask, or a
different byte size than the live block. **Blanks are generated from the live client**
so dimensions, format and mip chain are correct by construction.

---

## What censorship removal can and cannot do

It swaps **textures**. It never installs a nude body — that is Midnight
(Suzu / TheGreatSage) and the 3D genital packs.

- **Can** remove painted-on underwear that lives in a DXT5 `_dec` overlay layer.
  234 such layers across all classes on this client.
- **Cannot** remove anything on a DXT1 base map. Blanking it destroys the garment.
- **Cannot** remove built-in shorts that are **modelled geometry**.

For that last case the only fix is a **replacement mesh**, which is what the Midnight
XYZW collections are. Measured against vanilla, those files are 56%–2452% of the
original size — entirely different 3D models, not edits:

```
pew_00_ub_0274.pac    218603 -> 159195   ( 73%)
pew_10_ub_0074.pac    224588 -> 1031005  (459%)
pew_10_hand_0006.pac   38760 -> 950475   (2452%)
```

A collection is three things working together:

1. the replacement `.pac` — the mechanism; the shorts simply are not modelled
2. `.partcutdesc_exclusions.txt` → PartCutGen adds the garment to `Disable` so the body
   is **not** cut, and skin renders where the smaller garment no longer covers
3. an optional `_ao.dds` so the body does not poke through the new mesh

**PartCutGen can only stop the body being cut. It can never remove garment geometry.**
No amount of exclusion tuning fixes an outfit with modelled-in shorts, and adding
exclusions where none are needed causes poke-through on outfits that currently render
fine.

---

## Workflow rule: restore before shrinking the emitted set

Meta Injector updates the meta for every file it writes, so a re-inject correctly
replaces anything the new run **still emits**. A file the new run **omits** keeps
whatever the previous run injected.

- emitted set **growing** → plain re-inject is fine
- emitted set **shrinking** → restore vanilla first (`[R]` → `[1]`), or the dropped
  files stay live and you debug a bug that no longer exists in the code

This is exactly how 2.1.4 appeared not to fix anything.

Only ordering constraint in the pipeline: **deploy Midnight before PartCutGen**, since
PartCutGen scans the deployed meshes. Censorship is textures only and can run any time
before injection. Menu numbers are positions, not a sequence.

---

## Diagnosis checklist

When a body or outfit breaks after a texture change, in this order:

1. **Read the live meta, not the source pack.** Extract the suspect file from
   `pad00000.meta` and check its format and whether the payload is zeroed. Compare
   against `pad00000.BDOAIO-VANILLA.meta`. Half the wrong turns here came from
   reasoning about staged files instead of what is actually injected.
2. **Trust the A/B over the theory.** "Build X rendered clean, build X+N broke" narrows
   it to N faster than any amount of file analysis. Two of the four wrong diagnoses
   survived only because a user report was treated as vaguer than it was.
3. **Check the pixel format before blaming logic.** Most of these bugs were one format
   assumption, not a control-flow error.
4. **partcutdesc cannot remove geometry.** PartCutGen only adds a `Disable` section;
   non-`Disable` cut totals are identical to vanilla (6334 on this client). Disabling a
   cut makes the body show *more*. If something is missing, the cause is elsewhere.

### Disproven theories — do not revisit

- ~~"Censorship priority 500 overwrites a Midnight XYZW cull."~~ Midnight ships **none**
  of the 27 legacy filenames. Checked all of them; zero collisions.
- ~~"XYZW collections are missing partcut exclusions."~~ 169 of 183 uncovered
  replacements have no cut at all, and none of the 14 that do are Ranger.
- ~~"Dummied underwear with a surviving cut punches holes."~~ 0 of 1506 replaced
  underwear PACs have an active cut without an exclusion.
- ~~"Medium is unfixable and must be retired."~~ It was stale pack files, now fixed.

---

## Guards that enforce this

| Guard | Protects |
|---|---|
| `transparent_payload()` | format rules; DXT1 refused unconditionally |
| `legacy_reject_reason()` | stubs, clip masks, size mismatch vs live |
| `EXPAND_NAME_NEVER` | `*_cull*`, checked before positive rules |
| `AGE_AMBIGUOUS_NAME_TOKENS` | adult-only boundary; never relax |
| `tools/bdo_meta/test_censorship_pack_apply.py` | all of the above, with the real filenames |

Run `python -m unittest discover -p "test_*.py"` in `tools/bdo_meta` before shipping any
change here.
