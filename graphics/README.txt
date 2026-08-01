BLACK DESERT REMASTERED MAX-QUALITY PATCHES
===========================================

IMPORTANT 2.0.7 FIX
- These are small merge patches, not complete GameOption files.
- Use START.bat -> G. Do not rename or copy a .patch file over GameOption.txt.
- The AIO backs up the complete current file and changes only the listed keys.
- Display adapter, window mode, refresh behavior, HDR calibration, audio, UI,
  camera preferences, account flags, and unknown/new client keys stay untouched.

WHY THE OLD FILES WERE REMOVED
- 2.0.6 replaced the complete current-client file with a stale partial template.
- It also used textureQuality = 2 even though the current client uses 0 for High.
- The current installed client scripts map the Remastered UI button to saved
  graphicOption 9 and Ultra to 8. These profiles use 9 and omit Ultra.
- No fake DLSS, ray tracing, Lumen, RTXGI, FSR2/3, path tracing, virtual texture,
  or other invented engine keys are added.

PROFILES
1. GameOption_Remastered_1080p.patch
   1920x1080 maximum-quality Remastered gameplay.

2. GameOption_Remastered_1440p.patch
   2560x1440 maximum-quality Remastered gameplay.

3. GameOption_Remastered_DLDSR_4K.patch
   3840x2160 Remastered downsampling for a 2560x1440 monitor.
   First enable NVIDIA Control Panel > Manage 3D Settings > DSR Factors >
   DL scaling 2.25x, use fullscreen, then select 3840x2160 in BDO.

QUALITY CHOICES
- Texture Quality: High
- Graphics: Remastered (Ultra intentionally omitted)
- Anti-Aliasing: TAA
- SSAO and Tessellation: On
- Native upscale / AMD FSR: Off for maximum clarity
- Depth of field and motion blur: Off for a sharper moving image
- Effect-frame and far-player optimization: Off
- Other players' actual costumes: On

The tool does not mark GameOption.txt read-only. Close BDO before applying and
verify the settings in game afterward. If a patch changes the file format or
removes a required key, the merge fails closed instead of manufacturing one.
