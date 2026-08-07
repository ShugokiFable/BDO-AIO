# Workspace ownership

The authoritative product is the user-supplied Git checkout. BDO-AIO 2.0.9 is based on the clean v2.0.8 parent commit `1f84a4e`.

Per the user's explicit no-duplicate/no-output preference, this patch is made directly in the authoritative checkout. The immutable parent commit and published GitHub artifacts are the rollback boundary. The game, PAZ, tool-reference, save, and deployment trees remain read-only during development.
