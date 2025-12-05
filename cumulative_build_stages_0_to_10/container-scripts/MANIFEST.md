# MANIFEST.json Documentation

## Overview

The `MANIFEST.json` file is a configuration manifest that maps source files in the `container-scripts/` directory to their installation targets in the container filesystem. It is used by the `install.sh` script to automate file installation with proper permissions and metadata.

## File Structure

```json
{
  "version": "1.0",
  "description": "Container scripts manifest - maps source files to installation targets",
  "files": [
    {
      "source": "relative/path/to/source/file",
      "target": "/absolute/path/to/target/file",
      "file_type": "shell-scripts",
      "permissions": "0755",
      "block": 11,
      "block_name": "BLOCK NAME",
      "description": "File description",
      "dependencies": [],
      "line_start": 1234,
      "line_end": 5678,
      "delimiter": "EOF",
      "file_path": "/path/to/source/script.sh"
    }
  ]
}
```

## Fields

### Root Level Fields

#### `version` (required)
- **Type:** `string`
- **Format:** Semantic versioning (MAJOR.MINOR, e.g., "1.0")
- **Description:** Schema version for compatibility tracking
- **Example:** `"1.0"`

#### `description` (required)
- **Type:** `string`
- **Description:** Human-readable description of the manifest file purpose
- **Example:** `"Container scripts manifest - maps source files to installation targets"`

#### `files` (required)
- **Type:** `array`
- **Description:** Array of file entry objects
- **Example:** `[{...}, {...}]`

### File Entry Fields

#### `source` (required)
- **Type:** `string`
- **Format:** Relative path from `container-scripts/` directory
- **Constraints:** Must not start with `/` (relative path only)
- **Description:** Path to source file in container-scripts/ directory
- **Example:** `"shell-scripts/block-11-apt-aria-wrapper-setup-must-be-before-nvidia/apt-wrapper-aria2c-accelerated-downloads.sh"`

#### `target` (required)
- **Type:** `string`
- **Format:** Absolute path (e.g., `/usr/local/bin/script.sh`) or relative path (e.g., `./script.sh`)
- **Description:** Target path where file will be installed in container
- **Example:** `"/usr/local/bin/apt-aria"` or `"./prune_apt_cache.sh"`

#### `file_type` (required)
- **Type:** `string`
- **Enum:** `["shell-scripts", "config-files", "other", "json-configs"]`
- **Description:** Category classification of the file type
- **Examples:**
  - `"shell-scripts"`: Executable shell scripts
  - `"config-files"`: Configuration files (`.conf`, `.xml`, etc.)
  - `"other"`: Other files (`.txt`, `.desktop`, `.py`, etc.)
  - `"json-configs"`: JSON5 configuration files

#### `permissions` (required)
- **Type:** `string`
- **Format:** Octal permission string (3-4 digits, 0-7)
- **Description:** File permissions in octal format
- **Examples:**
  - `"0755"`: Executable script (rwxr-xr-x)
  - `"0644"`: Config file (rw-r--r--)
  - `"0640"`: Restricted config file (rw-r-----)

#### `block` (optional but recommended)
- **Type:** `integer`
- **Minimum:** 0
- **Description:** Numeric block identifier indicating which build block this file belongs to
- **Example:** `11`

#### `block_name` (optional but recommended)
- **Type:** `string`
- **Description:** Human-readable name of the build block
- **Example:** `"APT-ARIA WRAPPER SETUP (MUST BE BEFORE NVIDIA!)"`

#### `description` (optional but recommended)
- **Type:** `string`
- **Description:** Human-readable description of the file's purpose and installation target
- **Example:** `"shell-scripts file: /usr/local/bin/apt-aria"`

#### `dependencies` (optional)
- **Type:** `array`
- **Default:** `[]`
- **Description:** Array of source file paths that this file depends on. Currently unused but reserved for future dependency resolution
- **Example:** `[]`

#### `line_start` (optional)
- **Type:** `integer | null`
- **Minimum:** 0 (if integer)
- **Description:** Starting line number in source script where this file's content begins. Use `null` for standalone files not extracted from source script
- **Example:** `2235` or `null`

#### `line_end` (optional)
- **Type:** `integer | null`
- **Minimum:** 0 (if integer)
- **Description:** Ending line number in source script where this file's content ends. Use `null` for standalone files not extracted from source script
- **Example:** `2365` or `null`

#### `delimiter` (optional)
- **Type:** `string | null`
- **Description:** Heredoc delimiter string used to extract file content from source script. Use `null` for standalone files not extracted from source script
- **Example:** `"EOF"` or `null`

#### `file_path` (optional)
- **Type:** `string | null`
- **Description:** Absolute path to source script file containing this file's content. Use `null` for standalone files not extracted from source script
- **Example:** `"/home/user/project/xubuntu_robotics_base_full.sh"` or `null`

## Usage

### Installation with install.sh

#### Install All Files
```bash
cd container-scripts/
./install.sh --all
```

#### Install Specific File
```bash
cd container-scripts/
./install.sh --script shell-scripts/block-11-apt-aria-wrapper-setup-must-be-before-nvidia/apt-wrapper-aria2c-accelerated-downloads.sh
```

### Validation

#### Validate JSON Syntax
```bash
python3 -m json.tool MANIFEST.json > /dev/null && echo "Valid JSON" || echo "Invalid JSON"
```

#### Validate with JSON Schema
```bash
# Install ajv-cli if not available
npm install -g ajv-cli

# Validate manifest against schema
ajv validate -s MANIFEST.schema.json -d MANIFEST.json
```

**What is JSON Schema?**  
JSON Schema is a vocabulary that allows you to annotate and validate JSON documents. The `MANIFEST.schema.json` file serves several purposes:
- **Validation**: Ensures MANIFEST.json follows the correct format, data types, and constraints
- **Documentation**: Self-documenting with field descriptions and examples
- **IDE Support**: Enables autocomplete, error highlighting, and type checking in IDEs
- **CI/CD Integration**: Can be used in automated testing pipelines
- **Versioning**: Tracks schema evolution and compatibility

See the schema file itself for detailed field definitions and validation rules.

#### Validate with jq
```bash
# Check if JSON is valid
jq empty MANIFEST.json && echo "Valid JSON" || echo "Invalid JSON"

# Count files
jq '.files | length' MANIFEST.json

# List all source files
jq -r '.files[].source' MANIFEST.json

# List all target paths
jq -r '.files[].target' MANIFEST.json

# Find files by block
jq '.files[] | select(.block == 11)' MANIFEST.json

# Find files by file_type
jq '.files[] | select(.file_type == "shell-scripts")' MANIFEST.json
```

## File Type Categories

### shell-scripts
Executable shell scripts installed to `/usr/local/bin/`, `/etc/profile.d/`, or other system directories.

**Examples:**
- `/usr/local/bin/apt-aria`
- `/etc/profile.d/cuda.sh`
- `/usr/local/bin/start_vnc_xfce.sh`

### config-files
Configuration files installed to system configuration directories.

**Examples:**
- `/etc/apt/apt.conf.d/99-drake-insecure.conf`
- `/etc/tmux.conf`
- `/etc/turbovncserver.conf.d/performance.conf`

### other
Other files including text files, desktop files, XML files, Python scripts, etc.

**Examples:**
- `/etc/apt/preferences.d/cuda-repository-pin`
- `/usr/share/applications/freecad.desktop`
- `/opt/scripts/zenoh_topic_bridge.py`

### json-configs
JSON5 configuration files for applications.

**Examples:**
- `/etc/zenoh/zenoh-router.json5`
- `/etc/zenoh/zenoh-bridge-humble.json5`

## Block Organization

Files are organized into blocks corresponding to build phases:

- **Block 0:** Build script and verification tools
- **Block 4:** Mirror probing functions
- **Block 11:** APT-ARIA wrapper setup
- **Block 12:** OpenBLAS compilation
- **Block 13:** NVIDIA CUDA/cuDNN setup
- **Block 14:** Drake robotics framework
- **Block 15:** Firefox installation
- **Block 16:** Phase 1 - Foundational system libraries
- **Block 17:** Phase 3 - High-level dependencies
- **Block 19:** Cache pruning scripts
- **Block 20:** Phase 4 - OpenCV compilation
- **Block 21:** Julia environment setup
- **Block 24:** 3D reconstruction and NeRF tools
- **Block 25:** JAX CUDA installation
- **Block 27:** X11 performance and diagnostic tools
- **Block 28:** Desktop environment and remote access setup (Part 1 of 3)
- **Block 29:** Conda/Python environment setup
- **Block 31:** CAD and 3D printing tools
- **Block 33:** VNC startup scripts and configurations (Part 2 of 3)
- **Block 34:** Additional VNC and display servers (Part 3 of 3)
- **Block 35:** Multimedia and performance tools
- **Block 36:** Modern Rust-based CLI tools
- **Block 37:** Rust toolchain installation
- **Block 38:** Robotics middleware - Zenoh
- **Block 39:** Final system verification
- **Block 40:** Documentation and user guides

## Path Resolution

### Source Paths
- All `source` paths are **relative** to the `container-scripts/` directory
- Must not start with `/` (absolute paths not allowed)
- Example: `"shell-scripts/block-11/script.sh"` resolves to `container-scripts/shell-scripts/block-11/script.sh`

### Target Paths
- Most `target` paths are **absolute** paths in the container filesystem
- Example: `"/usr/local/bin/script.sh"`
- Some build-time scripts use **relative** paths (e.g., `"./prune_apt_cache.sh"`)
- Relative paths are resolved relative to the build directory

## Permissions

### Common Permission Values

| Permission | Octal | Description | Usage |
|------------|-------|-------------|-------|
| `0755` | rwxr-xr-x | Executable script | Shell scripts in `/usr/local/bin/` |
| `0644` | rw-r--r-- | Config file | Configuration files, text files |
| `0640` | rw-r----- | Restricted config | Sensitive configuration files |

### Permission Format
- Must be 3-4 digit octal string (0-7)
- Format: `^[0-7]{3,4}$`
- Examples: `"0644"`, `"0755"`, `"0640"`

## Versioning

### Semantic Versioning
The `version` field uses semantic versioning (MAJOR.MINOR format):
- **MAJOR:** Breaking changes (incompatible schema changes)
- **MINOR:** New features (backward-compatible additions)

### Version History
- **1.0:** Initial version with current schema

### Breaking Changes
Breaking changes require MAJOR version increment:
- Removing required fields
- Changing field types
- Changing enum values
- Changing required fields to optional (backward compatible)

### Non-Breaking Changes
Non-breaking changes allow MINOR version increment:
- Adding optional fields
- Adding new enum values
- Adding new file types
- Extending descriptions

## Best Practices

### 1. Use Absolute Paths for Target
Prefer absolute paths for `target` field:
```json
{
  "target": "/usr/local/bin/script.sh"  // ✅ Good
}
```

Avoid relative paths unless necessary:
```json
{
  "target": "./script.sh"  // ⚠️ Use only for build-time scripts
}
```

### 2. Use null for Missing Values
Use `null` instead of placeholder strings:
```json
{
  "line_start": null,  // ✅ Good
  "delimiter": null    // ✅ Good
}
```

Avoid placeholder strings:
```json
{
  "line_start": 0,      // ⚠️ Avoid (use null)
  "delimiter": "N/A"    // ⚠️ Avoid (use null)
}
```

### 3. Provide Descriptive Descriptions
Use clear, descriptive `description` fields:
```json
{
  "description": "shell-scripts file: /usr/local/bin/apt-aria"  // ✅ Good
}
```

### 4. Group Related Files by Block
Organize files by build block for better maintainability:
```json
{
  "block": 11,
  "block_name": "APT-ARIA WRAPPER SETUP (MUST BE BEFORE NVIDIA!)"
}
```

### 5. Validate Before Committing
Always validate JSON syntax and schema before committing:
```bash
# Validate syntax
python3 -m json.tool MANIFEST.json > /dev/null

# Validate schema (if ajv-cli available)
ajv validate -s MANIFEST.schema.json -d MANIFEST.json
```

## Troubleshooting

### Common Issues

#### Invalid JSON Syntax
**Error:** `JSON syntax error`  
**Solution:** Validate with `python3 -m json.tool MANIFEST.json`

#### Missing Source File
**Error:** `Source file not found`  
**Solution:** Verify `source` path is correct relative to `container-scripts/` directory

#### Invalid Permissions
**Error:** `Invalid permissions format`  
**Solution:** Use 3-4 digit octal string (e.g., `"0755"`, `"0644"`)

#### Path Traversal
**Error:** `Unsafe source file path`  
**Solution:** Ensure `source` path does not contain `..` or start with `/`

## Examples

### Example 1: Shell Script
```json
{
  "source": "shell-scripts/block-11-apt-aria-wrapper-setup-must-be-before-nvidia/apt-wrapper-aria2c-accelerated-downloads.sh",
  "target": "/usr/local/bin/apt-aria",
  "file_type": "shell-scripts",
  "permissions": "0755",
  "block": 11,
  "block_name": "APT-ARIA WRAPPER SETUP (MUST BE BEFORE NVIDIA!)",
  "description": "shell-scripts file: /usr/local/bin/apt-aria",
  "dependencies": [],
  "line_start": 2235,
  "line_end": 2365,
  "delimiter": "EOF",
  "file_path": "/home/user/project/xubuntu_robotics_base_full.sh"
}
```

### Example 2: Config File
```json
{
  "source": "config-files/block-14-drake-robotics-framework-setup/99-drake-insecure.conf",
  "target": "/etc/apt/apt.conf.d/99-drake-insecure.conf",
  "file_type": "config-files",
  "permissions": "0644",
  "block": 14,
  "block_name": "DRAKE ROBOTICS FRAMEWORK SETUP",
  "description": "config-files file: /etc/apt/apt.conf.d/99-drake-insecure.conf",
  "dependencies": [],
  "line_start": 4046,
  "line_end": 4049,
  "delimiter": "EOF",
  "file_path": "/home/user/project/xubuntu_robotics_base_full.sh"
}
```

### Example 3: Standalone File
```json
{
  "source": "verification-tools/verify-mkl-env.sh",
  "target": "/usr/local/bin/verify-mkl-env.sh",
  "file_type": "shell-scripts",
  "permissions": "0755",
  "block": 0,
  "block_name": "VERIFICATION TOOLS",
  "description": "MKL environment verification script for HPC validation",
  "dependencies": [],
  "line_start": null,
  "line_end": null,
  "delimiter": null,
  "file_path": null
}
```

## References

- [JSON Schema Specification](https://json-schema.org/)
- [RFC 8259 - The JSON Data Interchange Format](https://tools.ietf.org/html/rfc8259)
- [install.sh](../container-scripts/install.sh) - Installation script that uses this manifest
- [MANIFEST.schema.json](../container-scripts/MANIFEST.schema.json) - JSON Schema for validation

## Changelog

### Version 1.0 (2025-01-27)
- Initial version with current schema
- Support for 92 files across 4 file types
- Block organization (0-40)
- Line range tracking for extracted files
- Dependency field (reserved for future use)

