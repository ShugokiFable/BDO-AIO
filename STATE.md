# State

- Parent snapshot: v2.0.7 (`9f57495`)
- Active snapshot: 2.0.8
- Runtime status: PartCutGen completed in the user log; Meta Injector launch is contradicted by the user screenshot and awaits retest with this hotfix
- Authority workflow: full isolated 2.0.8 copy created before editing; 2.0.7 remains untouched
- Meta Injector root cause: `Prepare-BdoInjectStage` allowed the Python stage-builder report into PowerShell's success pipeline, so `$stage` became `System.Object[]` instead of one path string
- Fix: route the report to the host, cast the returned stage to one string, and pass one explicit quoted `-files` argument string
- PartCutGen status: successful; 1,679 exclusions and `partcutdesc.xml` saved, while three optional patterns matched zero files
- Preserved 2.0.7 scope: graphics, body-slider, XYZW, censorship, and genital fixes are unchanged
- Source validation: 30 Python tests plus the exact Windows PowerShell stage-output regression pass
- Release state: tool-validated hotfix candidate; Meta Injector and in-game retest required
