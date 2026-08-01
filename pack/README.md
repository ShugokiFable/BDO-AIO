# `pack\` — Midnight mod content (local / full release only)

This folder is **required** for menu options 3–6 (deploy + PartCutGen + Meta Injector).

It is **not stored in this GitHub repo** (≈1.8 GB, tens of thousands of files, third-party content).

## What belongs here

Copy a full Midnight XYZW PAZ pack so this folder contains at least:

```text
pack\
  midnight_xyzw.cmd
  midnight_xyzw\
    midnight_xyzw.py
    _00_suzu_nude\
    _00_remove_underwear\
    _00_remove_all_armors\
    ...
  Meta Injector.exe
  PartCutGen.exe
```

Typical source: Midnight / heisha PAZ release (e.g. 0.4.x with Seraph).

## After clone

1. Obtain the Midnight pack yourself (Undertow / author release / your backup).
2. Extract so files land **inside** `pack\` (not a nested random folder name).
3. Run `START.bat` → menu **9** to verify.

## Full offline zip

If you redistribute a complete offline AIO (scripts + pack + experimental), zip the whole folder locally — do not force the multi‑GB payload through git.
