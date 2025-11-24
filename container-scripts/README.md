# Container Scripts

This directory contains all heredoc files extracted from the build and post scripts.

## Organization

Files are organized by type:
- `shell-scripts/` - Shell scripts (.sh, .bash)
- `json-configs/` - JSON configuration files (.json, .json5)
- `config-files/` - Configuration files (.conf, .kdl, .ron, etc.)
- `layout-configs/` - Layout configuration files (Zellij, Tmux)
- `other/` - Other file types

Within each type, files are organized by block number.

## Total Files

- **Total**: 1 files
- **Shell scripts**: 0
- **JSON configs**: 0
- **Config files**: 0
- **Layout configs**: 0
- **Other**: 1

## Installation

Files are installed during container build via the `install.sh` helper script.
The helper reads `MANIFEST.json` and installs files to their target locations with proper permissions.

## Validation

Run validation to check all files:
```bash
python3 scripts/validate_heredoc_scripts.py
```
