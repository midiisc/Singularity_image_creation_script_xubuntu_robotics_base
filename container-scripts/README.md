# Container Scripts

This directory contains all heredoc files extracted from the build and post scripts.

## Organization

Files are organized by type:
- `shell-scripts/` - Shell scripts (.sh, .bash) - 57 files
- `json-configs/` - JSON configuration files (.json, .json5) - 3 files
- `config-files/` - Configuration files (.conf, .kdl, .ron, etc.) - 10 files
- `other/` - Other file types (APT preferences, desktop files, etc.) - 20 files

Within each type, files are organized by block number.

## Total Files

- **Total**: 90 files
- **Shell scripts**: 57
- **JSON configs**: 3
- **Config files**: 10
- **Other**: 20

## Files Status

✅ All 90 files extracted and verified to match originals exactly.

## Installation

Files are installed during container build via the `install.sh` helper script.
The helper reads `MANIFEST.json` and installs files to their target locations with proper permissions.

### Usage

```bash
# Install all files
./install.sh --all

# Install specific file
./install.sh --script shell-scripts/block-11-apt-aria-wrapper-setup-must-be-before-nvidia/apt-wrapper-aria2c-accelerated-downloads.sh
```

## Extraction

To re-extract all files:
```bash
python3 scripts/extract_all_heredocs.py
```

## Verification

Verify all extracted files match originals:
```bash
python3 scripts/verify_all_extraction.py
```

## Validation

Validate shell scripts:
```bash
python3 scripts/validate_heredoc_scripts.py
```

## Verification Tools

HPC verification scripts are included in `verification-tools/`:

- **verify-mkl-env.sh** - Validates MKL environment setup and functionality
- **verify-cuda-mkl-linkage.sh** - Verifies library linkages (MKL/CUDA/OpenMP)

These scripts are installed to `/usr/local/bin/` in the container via `install.sh` and can be run on HPC nodes:

```bash
singularity exec your_image.sif verify-mkl-env.sh
singularity exec your_image.sif verify-cuda-mkl-linkage.sh
```

**Note:** These scripts are only in `container-scripts/verification-tools/` and are installed to the container. They are not needed on the host system (removed from `scripts/` directory to avoid duplication).
