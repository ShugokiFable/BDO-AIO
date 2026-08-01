# State

- Parent: v2.0.8 (`1f84a4e`)
- Active version: 2.0.9
- User evidence: Midnight, PartCutGen, Meta Injector, and other tested options now run without reported errors; full bush still appeared shaved on Witch or Sorceress; 3D vagina has not been tested
- Root cause: original Resorepless pubic bins contain DXT1 blocks for an 11,184,952-byte 4K layout, but Midnight's Ranger/Sorceress/Witch diffuse DDS files are 89,478,612-byte uncompressed 32-bit mip chains
- Fix: preserve exact byte patching for compatible DXT1 files and translate the selected-vs-shaved DXT1 pixel delta into matching coordinates for compatible 32-bit DDS files
- Mesh/stage evidence: Witch and Sorceress PACs reference the expected `_01_nude_0001` materials; pubic outputs win canonical staging; the current injected meta was newer than the generated files
- Validation: 32 tests pass; real Sorceress and Witch generation preserved size/header/alpha and visibly produced full-bush pixels in the expected UV region
- Cleanup: temporary 180 MB validation DDS files and preview deleted
- Release state: source hotfix ready for commit/package/publication; runtime confirmation pending
