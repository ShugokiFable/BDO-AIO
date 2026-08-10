# BDO-AIO v2.4.1 validation

Date: 2026-08-09

## Scope

- Five body regions with 12 explicit axis ceilings.
- Recommended/Custom schema-2 launcher configuration and legacy migration.
- Max-only, widen-only, exact-byte patching.
- Read-only live PAZ descriptor audit. No game or deployed patch files were written.
- Butt-cheek versus pelvis-Z wording regression checks.

## Commands and results

| Command | Exit | Result |
|---|---:|---|
| `python -B tools\bdo_meta\test_body_size_patcher.py` | 0 | 18 focused axis/parser/byte-safety tests passed. |
| `python -B -m unittest discover -v tools\bdo_meta` | 0 | 94 complete Python tests passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\bdo_meta\test_body_size_config.ps1` | 0 | Schema 2, migration, UI text, invariant formatting, and PowerShell 5.1 BOM checks passed. |
| `test_launcher_static.ps1`, `test_meta_inject_launcher.ps1`, `test_pubic_config.ps1` | 0 | Launcher parse/call graph, Meta Injector argument isolation, and pubic configuration suites passed. |
| `python -B tools\bdo_meta\_verify_presets_vs_stock.py --paz "...\Black Desert Online\PAZ"` | 0 | 75 descriptors, 75 changed in memory, 3,136 target tags, 2,383 Max edits, 0 violations. |
| `git diff --check` | 0 | No whitespace errors before commit. |
| `7z t BDO-AIO-v2.4.1-full.7z` | pending | Run after packaging. |
| release exclusion audit | pending | Run after packaging. |

## Live audit invariants

- Descriptor count: 75.
- Every patched output retained its exact input byte length.
- `Min` and `Default` remained byte-identical.
- Thigh X, Pelvis X, and Belly Y remained unchanged.
- Spine X changed only under the explicit Belly-X target.
- No higher class-authored Max value was reduced.

## Verdict

```text
SCOPE: PASS
DIFF REVIEW: PASS
PYTHON TESTS: PASS
POWERSHELL TESTS: PASS
READ-ONLY LIVE DESCRIPTOR AUDIT: PASS
PACKAGE: PENDING
REMOTE RELEASE: PENDING
UNRESOLVED: cross-class and outfit appearance requires in-game user testing
FINAL: PASS (tool-validated; runtime appearance pending)
```
