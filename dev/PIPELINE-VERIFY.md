# PartCutGen / Meta Injector verification (2026-08-06)

> ⛔ **VOID below the pipeline section.** The pipeline mechanics (inject ran, file count is
> expected to stay the same) are still correct. Every *conclusion* about Look 7 is not:
> the targets were `phw` = **Sorceress**, the character was **Ranger** = `pew`.
> `BasicCutType PHW_Upperbody02` is Sorceress's folder; Ranger's is **`PEW_Upperbody`**.
> See `dev/STATE.md`.


## User concern
“Meta Injector same injected file number for 2 runs” + Look 7 still no areola → steps wrong?

## Verdict: **steps were correct; wrong garments were targeted**

### Evidence pipeline applied free PHW uncut

| Check | Result |
|-------|--------|
| `_body_uncut` stage | 23 free `phw_*_ub_*` patterns, mtime after staging |
| PartCutGen `partcutdesc.xml` | Free PHW files under `<CutType Name="Disable">` |
| `BDO_AIO_INJECT\character\partcutdesc.xml` | Same Disable list, same mtime as PartCutGen out |
| Live `pad00000.meta` | Extracted partcutdesc: free PHW **in Disable = YES** |
| Live `Event_UB` | Still has `PHW_10_UB_0002_E.pac` (**not** Disabled) |

### Why same Meta Injector “file count” is normal
Injector still injects roughly the **same set of paths** (one `partcutdesc.xml`, same PAC/DDS packages).  
Changing who sits under **Disable** inside `partcutdesc.xml` does **not** add a new file → count stays the same.  
`pad00000.meta` **mtime did update** after inject (proof inject ran).

### Why Look 7 still had no areola after free PHW Disable
All free Ranger upperbodies from Midnight free_items were Disabled in the **live** meta and Look 7 was **still** cut.  
Therefore Look #7 is **not** (only) those free_items free tops — or free Disable alone is not what fixed Look 7 earlier.

Earlier free-window stages also uncut **`Event_UB` → `phw_10_ub_0002_e`**, which was **still cut** in live meta. That is the next target.

### Correct next stage
Registry adds `phw_10_ub_0002_e` + high-skin pearl PHW candidates + keep free PHW.

### Update after free+Event_UB retest (user: nothing changed)
Live meta confirmed Event_UB PHW commented + free PHW in Disable. Look 7 still cut.
**Body UNCUT list expansion is not the missing step.**

`BasicCutType Name="PHW_Upperbody02"` → path `1_Pc/2_PHW/Armor/9_Upperbody` (all Ranger ub).

### Nuclear test result (user-confirmed)
PartCutGen: `1_pc/2_phw/armor/9_upperbody/` matched **357** file(s). Injected.  
Look **7 still no areola**. Look **8** slight clip only when shaking camera.  

**Final partcut verdict:** Disable cannot fix free open Ranger Look 7.  
Next: in-game outfit **display name** → remesh/XYZW plan. See `BOOB-WINDOW-OUTFITS.md` / `STATE.md`.
