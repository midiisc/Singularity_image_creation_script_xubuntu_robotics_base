# Build Script Requirements

This document lists all files and folders that must be present in the same root directory when running `build_xubuntu_robotics_base.sh`.

## Required Files

### 1. `build_xubuntu_robotics_base.sh` (The Build Script)
- **Location**: Root directory
- **Purpose**: Main build orchestration script
- **Required**: Yes (this is the script you run)

### 2. `config.sh` (Configuration File)
- **Location**: Root directory (same as build script)
- **Purpose**: Centralized configuration (versions, URLs, paths)
- **Required**: Yes (script exits if not found)
- **Checked**: At startup (Block 2.2)

### 3. `xubuntu_robotics_base_full.sh` (Post Script)
- **Location**: Root directory
- **Purpose**: Container post-installation script (executed inside container)
- **Required**: Yes (copied to container in %files section)
- **Copied to**: `/container_post_script.sh` inside container

## Required Directories

### 1. `container-scripts/` (Container Scripts Directory)
- **Location**: Root directory
- **Purpose**: Contains all extracted heredoc scripts for installation
- **Required**: Yes (entire directory copied to container)
- **Copied to**: `/container-scripts` inside container
- **Contents**:
  - `install.sh` - Installation script
  - `MANIFEST.json` - Installation manifest
  - `shell-scripts/` - Shell scripts organized by block
  - `verification-tools/` - Verification scripts
  - `config-files/` - Configuration files
  - `json-configs/` - JSON configuration files
  - Other extracted scripts

## Optional (Created Automatically)

### 1. `container_cache/` (Cache Directory)
- **Location**: Root directory (created automatically if missing)
- **Purpose**: Cache for downloaded packages and binaries
- **Required**: No (created automatically)
- **Subdirectories** (created automatically):
  - `container_cache/binaries/` - Pre-downloaded binaries (optional, can be pre-populated)
  - `container_cache/debs/` - Pre-downloaded .deb files (optional, can be pre-populated)
  - `container_cache/apt/` - APT cache (created automatically)
  - `container_cache/apt/archives/` - APT package archives (created automatically)
  - `container_cache/conda_pkgs/` - Conda packages (created automatically)
  - `container_cache/wheels/` - Python wheels (created automatically)
  - `container_cache/julia_pkgs/` - Julia packages (created automatically)

### 2. `build_logs/` (Build Logs Directory)
- **Location**: Root directory (created automatically)
- **Purpose**: Build log files
- **Required**: No (created automatically)

## Directory Structure

```
.
├── build_xubuntu_robotics_base.sh    # REQUIRED - Build script
├── config.sh                          # REQUIRED - Configuration file
├── xubuntu_robotics_base_full.sh  # REQUIRED - Post script
├── container-scripts/                 # REQUIRED - Container scripts directory
│   ├── install.sh
│   ├── MANIFEST.json
│   ├── shell-scripts/
│   ├── verification-tools/
│   ├── config-files/
│   └── json-configs/
├── container_cache/                   # OPTIONAL - Created automatically
│   ├── binaries/                      # OPTIONAL - Can be pre-populated
│   ├── debs/                          # OPTIONAL - Can be pre-populated
│   ├── apt/                           # Created automatically
│   ├── conda_pkgs/                    # Created automatically
│   ├── wheels/                        # Created automatically
│   └── julia_pkgs/                    # Created automatically
└── build_logs/                        # Created automatically
```

## File Paths in Build Script

The build script uses `${SCRIPT_DIR}` to reference files relative to the script location:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
```

Files copied to container (from %files section):
- `${CONFIG_FILE}` → `/etc/config.sh`
- `${SCRIPT_DIR}/container_cache/binaries` → `/container_cache/binaries`
- `${SCRIPT_DIR}/container_cache/debs` → `/container_cache/debs`
- `${SCRIPT_DIR}/xubuntu_robotics_base_full.sh` → `/container_post_script.sh`
- `${SCRIPT_DIR}/config.sh` → `/container_config.sh`
- `${SCRIPT_DIR}/container-scripts` → `/container-scripts`

## Pre-populating Cache (Optional)

You can pre-populate the cache directories to speed up builds:

1. **Pre-download binaries**: Place files in `container_cache/binaries/`
2. **Pre-download .deb files**: Place files in `container_cache/debs/`
3. **Pre-download Conda packages**: Place files in `container_cache/conda_pkgs/`
4. **Pre-download Python wheels**: Place files in `container_cache/wheels/`
5. **Pre-download Julia packages**: Place files in `container_cache/julia_pkgs/`

The build script will check for existing files and skip downloads if found.

## Verification

Before running the build script, verify:

```bash
# Check required files exist
test -f build_xubuntu_robotics_base.sh && echo "✓ Build script found" || echo "✗ Build script missing"
test -f config.sh && echo "✓ Config file found" || echo "✗ Config file missing"
test -f xubuntu_robotics_base_full.sh && echo "✓ Post script found" || echo "✗ Post script missing"
test -d container-scripts && echo "✓ Container scripts directory found" || echo "✗ Container scripts directory missing"

# Check container-scripts has required files
test -f container-scripts/install.sh && echo "✓ install.sh found" || echo "✗ install.sh missing"
test -f container-scripts/MANIFEST.json && echo "✓ MANIFEST.json found" || echo "✗ MANIFEST.json missing"
```

## Error Messages

If required files are missing, you'll see:

1. **config.sh not found**:
   ```
   ERROR: Configuration file not found: /path/to/config.sh
   Please ensure config.sh exists in the same directory as this script.
   ```

2. **container_cache missing** (warning, not fatal):
   ```
   WARNING: Host cache directory missing at ${PWD}/container_cache; continuing without preseeding.
   ```

3. **container-scripts missing** (warning in container):
   ```
   WARNING: Container scripts installation files not found. Some scripts may not be available.
   ```

## Summary

**Required Files:**
- `build_xubuntu_robotics_base.sh`
- `config.sh`
- `xubuntu_robotics_base_full.sh`

**Required Directories:**
- `container-scripts/` (with `install.sh` and `MANIFEST.json`)

**Optional (Created Automatically):**
- `container_cache/` (and all subdirectories)
- `build_logs/`

**All files and directories must be in the same root directory as the build script.**

