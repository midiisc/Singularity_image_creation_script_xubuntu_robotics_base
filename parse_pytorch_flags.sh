#!/bin/bash
#===============================================================================
# PyTorch Build Flags Parser
# Purpose: Parse PyTorch repository files to extract all build flags and their functions
# Usage: ./parse_pytorch_flags.sh [pytorch_source_directory]
# Output: PYTORCH_BUILD_FLAGS.md
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PyTorch Build Flags Parser${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Determine PyTorch source directory
if [ $# -gt 0 ]; then
    PYTORCH_DIR="$1"
else
    # Default to test build directory
    PYTORCH_DIR="/tmp/pytorch_openblas_test"
    # Try to find latest pytorch directory
    if [ -d "${PYTORCH_DIR}" ]; then
        LATEST_PYTORCH=$(find "${PYTORCH_DIR}" -maxdepth 1 -type d -name "pytorch-*" | sort -V | tail -1)
        if [ -n "${LATEST_PYTORCH}" ]; then
            PYTORCH_DIR="${LATEST_PYTORCH}"
        fi
    fi
fi

if [ ! -d "${PYTORCH_DIR}" ]; then
    echo -e "${RED}✗ ERROR: PyTorch source directory not found: ${PYTORCH_DIR}${NC}"
    echo "  Usage: $0 [pytorch_source_directory]"
    echo "  Or ensure PyTorch is cloned in /tmp/pytorch_openblas_test/"
    exit 1
fi

echo "  PyTorch source directory: ${PYTORCH_DIR}"

# Check for required files
if [ ! -f "${PYTORCH_DIR}/setup.py" ]; then
    echo -e "${RED}✗ ERROR: setup.py not found in ${PYTORCH_DIR}${NC}"
    exit 1
fi

OUTPUT_FILE="PYTORCH_BUILD_FLAGS.md"
echo "  Output file: ${OUTPUT_FILE}"
echo ""

# Create markdown file header
cat > "${OUTPUT_FILE}" << EOF
# PyTorch Build Flags Documentation

This document contains a comprehensive list of all PyTorch build flags extracted from the official PyTorch repository.

**Source**: PyTorch GitHub Repository  
**Repository**: https://github.com/pytorch/pytorch  
**Documentation**: https://github.com/pytorch/pytorch#from-source  
**Generated**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**PyTorch Source**: ${PYTORCH_DIR}

---

## Overview

PyTorch build flags are environment variables that control the compilation process. They can be set before running \`python setup.py build\` or \`python setup.py install\`.

---

## Build Flags

EOF

echo -e "${BLUE}[Step 1] Parsing setup.py for build flags...${NC}"

# Use Python to parse setup.py and extract flags with descriptions
python3 << PYTHON_EOF >> "${OUTPUT_FILE}"
import re
import sys
import os

pytorch_dir = "${PYTORCH_DIR}"
setup_py = os.path.join(pytorch_dir, 'setup.py')

if not os.path.exists(setup_py):
    print("Error: setup.py not found")
    sys.exit(1)

with open(setup_py, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

flags = {}
lines = content.split('\n')

# Extract flags with their preceding comments
for i, line in enumerate(lines):
    # Look for USE_ flag definitions
    if re.search(r'USE_([A-Z_]+)\s*=', line):
        # Look backwards for comments (up to 10 lines)
        desc_lines = []
        for j in range(max(0, i-10), i):
            comment_line = lines[j].strip()
            if comment_line.startswith('#'):
                desc = comment_line[1:].strip()
                # Skip separator lines and empty comments
                if desc and not desc.startswith('---') and not desc.startswith('==='):
                    desc_lines.insert(0, desc)  # Prepend to maintain order
        
        flag_match = re.search(r'USE_([A-Z_]+)', line)
        if flag_match:
            flag_name = f"USE_{flag_match.group(1)}"
            if desc_lines:
                flags[flag_name] = ' '.join(desc_lines)
            else:
                flags[flag_name] = "Flag from setup.py"

# Extract all os.getenv/os.environ.get calls for USE_ flags
pattern = r"os\.(?:getenv|environ\.get)\(['\"]USE_([A-Z_]+)['\"]"
matches = re.finditer(pattern, content)
for match in matches:
    flag_name = f"USE_{match.group(1)}"
    if flag_name not in flags:
        flags[flag_name] = "Environment variable flag"

# Extract CMAKE flags
cmake_pattern = r"(?:os\.(?:getenv|environ\.get)\(['\"]|export\s+)(CMAKE_[A-Z_]+)"
cmake_matches = re.finditer(cmake_pattern, content)
for match in cmake_matches:
    flag_name = match.group(1)
    if flag_name not in flags:
        flags[flag_name] = "CMake configuration flag"

# Extract TORCH flags
torch_pattern = r"TORCH_([A-Z_]+)\s*="
torch_matches = re.finditer(torch_pattern, content)
for match in torch_matches:
    flag_name = f"TORCH_{match.group(1)}"
    if flag_name not in flags:
        flags[flag_name] = "PyTorch-specific configuration flag"

# Extract BUILD flags
build_pattern = r"BUILD_([A-Z_]+)\s*="
build_matches = re.finditer(build_pattern, content)
for match in build_matches:
    flag_name = f"BUILD_{match.group(1)}"
    if flag_name not in flags:
        flags[flag_name] = "Build configuration flag"

# Print flags in organized sections
print("### Core Build Flags (USE_*)")
print("")
print("| Flag | Description |")
print("|------|-------------|")

use_flags = {k: v for k, v in flags.items() if k.startswith('USE_')}
for flag in sorted(set(use_flags.keys())):
    desc = use_flags[flag].replace('|', '\\|').replace('\n', ' ').strip()[:300]
    if not desc or desc == "Flag from setup.py":
        desc = "Environment variable flag"
    print(f"| \`{flag}\` | {desc} |")

print("")
print("### CUDA Flags")
print("")
print("| Flag | Description |")
print("|------|-------------|")

cuda_flags = {k: v for k, v in flags.items() if 'CUDA' in k.upper()}
for flag in sorted(set(cuda_flags.keys())):
    desc = cuda_flags[flag].replace('|', '\\|').replace('\n', ' ').strip()[:300]
    print(f"| \`{flag}\` | {desc} |")

print("")
print("### CMake Flags")
print("")
print("| Flag | Description |")
print("|------|-------------|")

cmake_flags = {k: v for k, v in flags.items() if k.startswith('CMAKE_')}
for flag in sorted(set(cmake_flags.keys())):
    desc = cmake_flags[flag].replace('|', '\\|').replace('\n', ' ').strip()[:300]
    print(f"| \`{flag}\` | {desc} |")

print("")
print("### Build Configuration Flags")
print("")
print("| Flag | Description |")
print("|------|-------------|")

build_flags = {k: v for k, v in flags.items() if k.startswith('BUILD_')}
for flag in sorted(set(build_flags.keys())):
    desc = build_flags[flag].replace('|', '\\|').replace('\n', ' ').strip()[:300]
    print(f"| \`{flag}\` | {desc} |")

PYTHON_EOF

echo -e "${GREEN}✓ Parsed setup.py${NC}"

# Extract additional flags from grep patterns
echo -e "${BLUE}[Step 2] Extracting additional flags from source files...${NC}"

cat >> "${OUTPUT_FILE}" << 'EOF'

---

## Additional Flags Found in Source

### All USE_* Flags Referenced

EOF

# Extract all USE_* references
grep -rh "USE_[A-Z_]*" "${PYTORCH_DIR}/setup.py" 2>/dev/null | \
    grep -oE "USE_[A-Z_]+" | \
    sort -u | \
    sed 's/^/| `/' | \
    sed 's/$/` | Environment variable flag |/' | \
    head -100 >> "${OUTPUT_FILE}" || true

cat >> "${OUTPUT_FILE}" << 'EOF'

---

## Common Build Flag Combinations

### OpenBLAS Build (No MKL)

```bash
export USE_MKL=0
export USE_MKLDNN=0
export USE_STATIC_MKL=0
export BLAS=OpenBLAS
export LAPACK=OpenBLAS
export USE_OPENMP=1
export USE_TBB=1
```

### CUDA Build

```bash
export USE_CUDA=1
export USE_CUDNN=1
export TORCH_CUDA_ARCH_LIST="8.6;8.9;9.0"
export CMAKE_CUDA_ARCHITECTURES="86;89;90"
```

### Performance Libraries

```bash
export USE_OPENMP=1
export USE_TBB=1
export OMP_NUM_THREADS=$(nproc)
export OPENBLAS_NUM_THREADS=$(nproc)
export MKL_NUM_THREADS=$(nproc)
export NUMEXPR_NUM_THREADS=$(nproc)
```

### Minimal Build (Faster Compilation)

```bash
export BUILD_TEST=0
export USE_DISTRIBUTED=0
export USE_TENSORPIPE=0
export USE_GLOO=0
export USE_MPI=0
export USE_NNPACK=0
```

---

## Notes

- All flags are environment variables that should be set before running the build
- Boolean flags typically use \`1\` for enabled, \`0\` for disabled
- Some flags may require additional dependencies to be installed
- Refer to the official PyTorch documentation for the most up-to-date information
- Flag names are case-sensitive
- Threading flags (OMP_NUM_THREADS, etc.) are runtime configuration, not build flags

---

## References

- [PyTorch Build Documentation](https://github.com/pytorch/pytorch#from-source)
- [PyTorch GitHub Repository](https://github.com/pytorch/pytorch)
- [PyTorch Releases](https://github.com/pytorch/pytorch/releases)
- [PyTorch setup.py](https://github.com/pytorch/pytorch/blob/main/setup.py)

EOF

echo -e "${GREEN}✓ Extracted additional flags${NC}"

# Count flags found
TOTAL_FLAGS=$(grep -c "^\| \`" "${OUTPUT_FILE}" | head -1 || echo "0")
echo ""
echo -e "${GREEN}✓ Documentation generated: ${OUTPUT_FILE}${NC}"
echo -e "${GREEN}  Total flags documented: ${TOTAL_FLAGS}${NC}"
echo -e "${BLUE}========================================${NC}\n"

exit 0
