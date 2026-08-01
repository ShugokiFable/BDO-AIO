# Decisions

## 2026-08-01

- Treat Resorepless pubic bins as DXT1 block resources, not format-independent byte ranges; checking only that offsets fit a larger DDS is invalid.
- Preserve exact legacy patching for DXT1 targets. For current 32-bit targets, translate the selected-versus-shaved DXT1 delta into matching mip and UV coordinates without replacing the current skin or alpha.
- Fail closed on unsupported DDS layouts or malformed overlay lengths.
- Follow the user's explicit no-duplicate preference for this small hotfix; use the clean parent Git commit and published release as rollback instead of retaining another multi-gigabyte local snapshot.
- Treat external-command stdout inside a value-returning PowerShell function as data contamination unless it is explicitly routed to the host.
- Pass Meta Injector one explicit quoted `-files` argument string for Windows PowerShell compatibility.
- Do not change PartCutGen for optional zero-match patterns when its generated `partcutdesc.xml` is saved successfully.
- Treat the user-reported slider-only crash as a release blocker.
- Do not attribute the slider crash to the experimental FSR DLL without independent evidence.
- Do not solve path length by deleting or skipping Midnight XYZW content.
- Preserve the exact width of each live body-slider vector field, including source whitespace; never normalize the whole XML file.
- Do not inject or launch the game during tool validation.
- Preserve all XYZW content by canonicalizing only organizer layers and shortening both source and PAZ roots with temporary drive mappings.
- Treat normal paths absent from live meta as errors, except intentional AIO-generated pubic/genital outputs, which use Meta Injector's `_add` contract.
- Ignore generated README files because they are tool metadata, not game assets.
- Keep Meta Patcher separate from Meta Injector; they do different work.
- Follow the Meta Patcher author's region FAQ: skip it on detected NA/EU clients and never infer a requirement for an unknown region.
- Keep donor genital reuse female-only. Do not map Dosa or Wukong to an older male body without a verified compatible mesh.
- Regenerate armor and underwear hides from live metadata because this needs filenames and dummy assets, not a borrowed body mesh.
- Keep only the current stable official OptiScaler bundle behind the existing unsafe opt-in gate; remove DLSS Enabler, zzDLL swaps, and DirectStorage layering.
- Require the AIO install marker before experimental uninstall and verify common proxy DLL names before deletion.
- Remove the abandoned Resorepless UI and PAZ Unpacker from the end-user menu because integrated AIO generators/extraction cover the shipped workflow.
- Preserve user configuration locally while removing it from Git/public releases.
- Never replace the complete current-client `GameOption.txt` with a bundled template; merge only locally verified keys and preserve all user, hardware, and unknown fields.
- Ship Remastered at 1080p, 1440p, and optional DLDSR 4K; omit Ultra because its performance cost does not fit the requested gameplay profile.
- Do not invent hidden BDO engine keys. Current installed client scripts are the authority: the Remastered UI button maps to saved `graphicOption = 9`, Ultra maps to `8`, and the High texture button maps to saved `textureQuality = 0`.
- Preserve the exact material stem embedded in each genital PAC. A renamed PAC does not change its UV/material binding, so its authored donor DDS names must remain unchanged.
