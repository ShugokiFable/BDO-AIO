# Workspace ownership

The authoritative product is the user-supplied Git checkout. BDO-AIO 2.4.1 is a wording-only hotfix based on published v2.4.0 tag commit `75c2dd0`; v2.4.0 remains the rollback release.

Per the user's explicit no-duplicate/no-output preference, this patch is made directly in the authoritative checkout. The immutable parent commit and published GitHub artifacts are the rollback boundary. The game, PAZ, tool-reference, save, and deployment trees remain read-only during development.
