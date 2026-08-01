EXPERIMENTAL DLSS / OPTISCALER FOR BDO
=====================================

Status: EXPERIMENTAL — NOT SAFE — NOT OFFICIALLY SUPPORTED

Why this exists
  Black Desert only exposes weak upscaling (FSR 1.0-class). This pack
  tries to bring OptiScaler (and optional Streamline DLSS pieces) so you
  can route through modern upscalers (DLSS / FSR3 / XeSS where hardware allows).

What is bundled
  OptiScaler\     OptiScaler 0.9.4-final (main path)
  Streamline\     NVIDIA Streamline 2.12 DLLs (DLSS helpers)
  upgrades\       Newer nvngx DLSS + AMD FidelityFX/FSR + DirectStorage 1.4 (from zzDLL)
  optional\       Extra tools (advanced only)
    version.dll                 alternate proxy DLL (optional)
    dlss-enabler-setup.exe      separate installer UI (optional)

FSR swap
  Menu X install -> pick upscaler [3] fsr31
  Installer overwrites amd_fidelityfx_* with upgrades\amd and sets OptiScaler.ini to fsr31.

What is NOT included (on purpose)
  SkyrimUpscaler — wrong game (Skyrim SE). Do not put that in BDO.

How the AIO installs it
  1. Menu [X] — EXPERIMENTAL DLSS/OptiScaler
  2. Read warnings and type YES
  3. Game root = folder that contains BlackDesert64.exe (parent of PAZ)
  4. Copies OptiScaler + Streamline into game root
  5. Renames OptiScaler.dll -> dxgi.dll (default; most compatible)
  6. Optionally sets Dx11/Dx12 upscaler preference to dlss in OptiScaler.ini

In-game
  - Enable the game's upscale / FSR option if present so the hook has a path
  - OptiScaler overlay: often INSERT or configured in OptiScaler.ini
  - See OptiScaler wiki: https://github.com/optiscaler/OptiScaler/wiki

Uninstall
  Menu [X] -> Uninstall experimental DLLs
  Or delete the listed DLLs from the game root (AIO prints the list)

If the game will not start
  Uninstall immediately. Repair/verify game files. Do not leave half-installed.

Credits
  OptiScaler — https://github.com/optiscaler/OptiScaler
  Streamline — NVIDIA
  DLSS Enabler (optional setup) — respective authors
