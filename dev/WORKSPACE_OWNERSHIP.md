# Workspace ownership

The authoritative product is the user-supplied Git checkout. BDO-AIO 2.3.0 is based on the clean v2.2.8 parent commit `f536378` and published v2.2.8 rollback release.

Per the user's explicit no-duplicate/no-output preference, this patch is made directly in the authoritative checkout. The immutable parent commit and published GitHub artifacts are the rollback boundary. The game, PAZ, tool-reference, save, and deployment trees remain read-only during development.
