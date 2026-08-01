# BDO-AIO Design (self-contained publish package)

## Goal
One unzippable folder for end users: menu + bundled Midnight content + PartCutGen + Meta Injector.

## Layout
- Scripts/docs at package root
- All mod content and tools under `pack\` (relative paths only)
- `config.json` stores only the user's game PAZ path + choices (not tool paths)

## Dependencies outside the zip
- Black Desert Online install (PAZ)
- Python 3 on PATH

## Publish
See PUBLISH.md. Use menu [9] to verify pack size (~1.5-2 GB) before shipping.
