EXPERIMENTAL OPTISCALER FOR BDO
===============================

Status: EXPERIMENTAL - NOT SAFE - NOT OFFICIALLY SUPPORTED

This folder contains only the unmodified official OptiScaler 0.9.4 release
payload used by menu X:

  OptiScaler\     OptiScaler 0.9.4-final
  Streamline\     Streamline DLLs distributed in that release

BDO does not officially support this hook. It may crash, fail anti-cheat,
break after a game update, or put an account at risk. Menu X is isolated from
the normal Midnight / PartCutGen / Meta Injector workflow and requires two
explicit confirmations.

BDO-AIO intentionally does not bundle or layer a separate DLSS Enabler,
third-party nvngx/FidelityFX swaps, or DirectStorage DLLs over OptiScaler.

Install
  1. Menu X -> read WARNING.txt.
  2. Choose install and type YES.
  3. Confirm the game root and proxy name.
  4. AIO backs up conflicting known filenames before copying.

Uninstall
  Use menu X or R. Uninstall requires the BDO-AIO marker and refuses to delete
  an unrelated or unverifiable proxy DLL merely because it is named dxgi.dll,
  winmm.dll, or version.dll.

If the game will not start
  Uninstall immediately, restore the timestamped AIO backup if appropriate,
  and use the official launcher Verify/Repair flow.

Project and documentation
  https://github.com/optiscaler/OptiScaler
