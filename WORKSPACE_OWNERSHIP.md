# Workspace ownership

The authoritative product is the user-supplied Git checkout, currently based on parent v2.0.7 commit `9f57495`.

This directory is the complete 2.0.8 working snapshot made from the complete 2.0.7 tree, excluding only `.git` administration and the user's local `config.json`. It remains isolated until validation passes and is then promoted as a complete replacement while preserving Git administration and local configuration. The game, PAZ, tool-reference, save, and deployment trees remain read-only during development.
