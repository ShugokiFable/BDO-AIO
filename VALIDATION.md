# Validation

BDO-AIO 2.0.5 is tool-validated. Structural validation is not runtime confirmation.

## Source and control gates

- Python unit tests: PASS, 21 tests.
- Python syntax parse: PASS for `tools/bdo_meta/*.py`.
- PowerShell parser: PASS for `bdo_aio.ps1`.
- Modified Python command help: PASS.
- `config.example.json`: PASS JSON parse; machine-specific `config.json` is ignored and preserved locally.
- `git diff --check`: PASS.
- Public path scan: PASS; no developer username or reference-drive path outside bundled pack/experimental payloads.

## Semantic generation gates

- Body-size reproduction: PASS, 75 files, 6,786 attribute edits, all outputs byte-length identical to extracted sources and all edited values complete three-component vectors.
- Current live injection source: PASS, 1,470 canonical winners, 0 invalid paths, 0 unresolved overrides, 3 intentionally ignored metadata files.
- Full-bush reproduction: PASS, 21 winners, 14 intentional `_add` entries, 0 invalid paths; `README.txt` ignored.
- Expanded censorship reproduction: PASS, 450 DDS files plus metadata, 0 decode failures, every output has DDS magic, and no Shai/child-token path was emitted.
- New-female genital reproduction: PASS, 30 winners, 16 intentional `_add` entries, 0 invalid paths.
- Full bundled pack inventory: PASS, 38,152 files and 1,946,038,900 bytes.

## Runtime boundary

- The installed game and live PAZ were inspected read-only.
- No game, launcher, Meta Injector, Meta Patcher, SSEEdit, xEdit, or Creation Kit process was launched.
- In-game body-slider and full-stack behavior remain UNTESTED and require the user's isolated retest.
