# State

- Parent snapshot: v2.0.6 (`ad1534c`)
- Active snapshot: 2.0.7
- Runtime status: user reports black characters and previously broken graphics settings; runtime retest required
- Authority workflow: developed and validated in a full isolated 2.0.7 copy before promotion
- Graphics root cause: 2.0.6 replaced the complete live `GameOption.txt` with a stale partial template, forced invalid/stale `graphicOption = 7`, and forced low textures (`2`)
- Donor-texture root cause: generated donor DDS names did not match the material names embedded in the PAC meshes
- Donor scope: female reuse only; male genital packs remain native-only
- Research boundary: current installed client and official/current sources are evidence; no invented hidden engine keys
- Current client evidence: Remastered UI index maps to saved value `9`, Ultra maps to `8`, and High texture UI index maps to saved value `0`
- Source/asset validation: 30 tests pass; all 22 PAC diffuse bindings and three complete generation modes pass against current read-only NA metadata
- Release state: tool-validated complete replacement; in-game retest required
