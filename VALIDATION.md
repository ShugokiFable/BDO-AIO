# BDO-AIO v2.3.1 hotfix candidate validation

Date: 2026-08-09

## Scope

- User symptom: the last Lower Back and Belly slider remained at its old maximum after `belly:1.25`.
- Root cause: 30 of 75 restored live descriptors already ship `Bip01 Spine`
  `WeightAxis02="Z"` at Max 1.35. A widen-only cap below 1.35 cannot add travel.
- Fix: belly baseline/recommended/high/extreme are now 1.35/1.45/1.60/1.75.
- Game/PAZ was read only. No release archive was built and nothing was pushed.

## Commands and results

| Command | Exit | Result |
|---------|------|--------|
| `python.exe -B -m unittest discover -v` from `tools\bdo_meta` | 0 | 101 tests passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\bdo_meta\test_body_size_config.ps1` | 0 | Corrected preset/migration and Windows PowerShell 5.1 encoding passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\bdo_meta\test_launcher_static.ps1` | 0 | Parse, function, and variable checks passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\bdo_meta\test_meta_inject_launcher.ps1` | 0 | Canonical Meta Injector argument isolation passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\bdo_meta\test_pubic_config.ps1` | 0 | Existing pubic configuration suite passed. |
| `python.exe -B .\tools\bdo_meta\_verify_presets_vs_stock.py` | 0 | Every recommended/high/extreme belly cap exceeds stock 1.35 and ordering is valid. |
| Read-only live-meta upgrade integration (`belly=1.45`) | 0 | 75/75 files changed in memory; 446 spine tags; 0 length/X/Min/Default/YZ violations. |
| `git diff --check` | 0 | No whitespace errors. |

## Verdict

```text
SCOPE: PASS
DIFF REVIEW: PASS
BUILD/COMPILE: N/A
TESTS/VALIDATORS: PASS
PACKAGE INSPECTION: N/A
UNRESOLVED: in-game slider travel and outfit clipping still require user confirmation
FINAL: PASS (tool-validated candidate only)
```
