# Library Documentation & Flag Extraction Tool - PART 1
## Automated Analyzer + AI Prompt Integration

**This is PART 1 of 3. See also:**
- `Library-Analysis-Tool-PART2.md` - Part 2 (How to Use, Agent-Facing Prompt Flow)
- `Library-Analysis-Tool-PART3.md` - Part 3 (Complete Workflow, Integration)

---

## 🚨 MANDATORY SEQUENTIAL EXECUTION INSTRUCTIONS

**CRITICAL: This is a multi-part prompt designed to maintain 500-line full context limits.**

**EXECUTION PROTOCOL:**
1. **START HERE**: Begin with PART 1 (this file)
2. **COMPLETE ALL TASKS** in PART 1 fully before proceeding
3. **ONLY AFTER** PART 1 is 100% complete, proceed to PART 2
4. **COMPLETE ALL TASKS** in PART 2 fully before proceeding
5. **ONLY AFTER** PART 2 is 100% complete, proceed to PART 3
6. **DO NOT** jump ahead or skip parts - each part builds on the previous

**WHY SEQUENTIAL?**
- Maintains 500-line context window per part
- Ensures complete understanding before moving forward
- Prevents context overflow and incomplete reviews
- Each part is self-contained but builds on previous work

**VERIFICATION CHECKLIST:**
- [ ] All PART 1 tasks completed
- [ ] All PART 1 outputs generated
- [ ] Ready to proceed to PART 2

**ONLY PROCEED TO PART 2 WHEN ALL PART 1 TASKS ARE COMPLETE.**

---

This is a **complete, executable solution** that:
1. **Downloads repository** (git clone)
2. **Analyzes files** (CMake, C++, bash scripts)
3. **Extracts all flags and versions** (bash script) - **Phase 1-2 of 5-phase system**
4. **Feeds to AI prompt** (Claude/Cursor) - **Phase 3-5 of 5-phase system**
5. **Generates comprehensive documentation**

**Enhanced with Comprehensive Build Flags Analysis System:**
- **5-Phase Architecture**: Discovery → Preprocessing → Deep Analysis → Multi-Pass Validation → Documentation Generation
- **Mixture of Reasoning Experts**: 4 specialized agents (Configuration, Dependency, Version, Documentation)
- **Version-Aware Tracking**: Historical evolution analysis (e.g., METIS in SuiteSparse)
- **Target Completeness**: >=95% flag coverage with multi-source validation

**See also:**
- `Comprehensive-Flag-Analysis-Prompt.md` - Complete 5-phase analysis protocol

---

## PART 1: EXECUTABLE BASH SCRIPT (analyze-library.sh)

```bash
#!/bin/bash

################################################################################
# CONFIG-AWARE LIBRARY ANALYSIS TOOL
# Purpose:
#   * Clone the version pinned in config.sh (MANDATORY if available)
#   * Fall back to latest stable release ONLY if version not pinned in config.sh
#   * NEVER use latest git snapshot - only stable releases
#   * Recursively analyze the repository for flags, options, and dependencies
#   * Emit Markdown + JSON documentation consumable by downstream AI tooling
#
# VERSION RESOLUTION PRIORITY (STRICTLY ENFORCED):
#   1. User-specified --ref (explicit override)
#   2. Version pinned in config.sh (MANDATORY - ensures correct flags documented)
#   3. Latest stable release tag (ONLY if not pinned in config.sh)
#   4. Default branch (LAST RESORT - should be rare, warns about git snapshot)
#
# Usage examples:
#   ./analyze-library.sh --library ceres
#   ./analyze-library.sh --library open3d --output ./output_dir
#   ./analyze-library.sh https://github.com/colmap/colmap.git ./out
#   ./analyze-library.sh --library opencv --ref 4.10.0 --summary
################################################################################

set -euo pipefail

# ===== INITIAL CONFIGURATION =====
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORKSPACE_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CONFIG_FILE_DEFAULT="${WORKSPACE_ROOT}/config.sh"

OUTPUT_DIR="."
REPO_SPEC=""
LIBRARY_ID=""
LIBRARY_VERSION=""
CHECKOUT_REF=""
CONFIG_FILE=""
FULL_SCAN=true
INCLUDE_DEPENDENCY_MAP=true

ANALYSIS_DIR="$(mktemp -d /tmp/lib_analysis_XXXXXX)"
ANALYSIS_ROOT=""
REPORT_FILE=""
JSON_FILE=""
DOC_FILE=""
CMAKE_FLAGS_FILE=""
CPP_DEFINES_FILE=""
DEPENDENCIES_FILE=""
RESOLVED_REF=""
GIT_REMOTE_URL="N/A"
GIT_COMMIT="N/A"

# Color codes for output (ANSI escape sequences)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

cleanup() {
    rm -rf "${ANALYSIS_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

usage() {
cat <<EOF
Usage: ${SCRIPT_NAME} [options] [REPO_URL_OR_PATH] [OUTPUT_DIR]

Options:
  -l, --library <name>   Library identifier (ceres, colmap, g2o, gtsam,
                         open3d, openblas, opencv, pytorch, suitesparse,
                         libcxxwrap_julia)
  -r, --ref <ref>        Explicit git ref (tag/branch/commit) to analyze
                         (overrides config + auto-detection)
  -o, --output <dir>     Output directory (default: current directory)
      --config <file>    Path to alternate config.sh (default: ${CONFIG_FILE_DEFAULT})
      --summary          Condensed summary mode (limits very large listings)
      --no-deps          Skip dependency graph extraction
  -h, --help             Show this help message

Positional arguments:
  REPO_URL_OR_PATH       Optional when --library is supplied; accepts git URL
                         (https/ssh) or an existing local checkout
  OUTPUT_DIR             Fallback positional output directory if --output not set

Behavior:
  * When --library is set, config.sh is sourced to resolve the pinned version (MANDATORY).
  * Version from config.sh is ALWAYS used if available (ensures correct flags documented).
  * If config.sh does not specify a version, the latest stable release tag is used (NOT git snapshot).
  * When neither --library nor REPO_URL_OR_PATH is provided, usage is displayed.
  
Version Resolution (STRICTLY ENFORCED):
  1. User --ref override (if provided)
  2. config.sh pinned version (MANDATORY if available - ensures version-specific flag accuracy)
  3. Latest stable release tag (ONLY if not pinned - excludes RC/beta/alpha)
  4. Default branch (LAST RESORT - warns about using git snapshot)
EOF
}

# ===== ARGUMENT PARSING =====
while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--library)
            [[ $# -lt 2 ]] && { log_error "Missing value for --library"; exit 1; }
            LIBRARY_ID="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
            shift 2
            ;;
        -r|--ref)
            [[ $# -lt 2 ]] && { log_error "Missing value for --ref"; exit 1; }
            CHECKOUT_REF="$2"
            shift 2
            ;;
        -o|--output)
            [[ $# -lt 2 ]] && { log_error "Missing value for --output"; exit 1; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --config)
            [[ $# -lt 2 ]] && { log_error "Missing value for --config"; exit 1; }
            CONFIG_FILE="$2"
            shift 2
            ;;
        --summary)
            FULL_SCAN=false
            shift
            ;;
        --no-deps)
            INCLUDE_DEPENDENCY_MAP=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$REPO_SPEC" ]]; then
                REPO_SPEC="$1"
            elif [[ "$OUTPUT_DIR" == "." ]]; then
                OUTPUT_DIR="$1"
            else
                log_warning "Ignoring extra argument: $1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$REPO_SPEC" && -z "$LIBRARY_ID" ]]; then
    usage
    exit 1
fi

if [[ -z "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$CONFIG_FILE_DEFAULT"
fi

mkdir -p "$OUTPUT_DIR"
REPORT_FILE="$(realpath "${OUTPUT_DIR}")/analysis_report.md"
JSON_FILE="$(realpath "${OUTPUT_DIR}")/analysis_report.json"
DOC_FILE="$(realpath "${OUTPUT_DIR}")/flags_documentation.md"
CMAKE_FLAGS_FILE="$(realpath "${OUTPUT_DIR}")/cmake_flags.md"
CPP_DEFINES_FILE="$(realpath "${OUTPUT_DIR}")/cpp_defines.md"
DEPENDENCIES_FILE="$(realpath "${OUTPUT_DIR}")/dependencies.md"

declare -gA FILES_FOUND=()
declare -ga CMAKE_FILES=()
declare -ga HEADER_FILES=()
declare -ga BUILD_SCRIPTS=()

declare -A LIBRARY_REPOS=(
    [ceres]="https://github.com/ceres-solver/ceres-solver.git"
    [colmap]="https://github.com/colmap/colmap.git"
    [g2o]="https://github.com/RainerKuemmerle/g2o.git"
    [gtsam]="https://github.com/borglab/gtsam.git"
    [open3d]="https://github.com/isl-org/Open3D.git"
    [openblas]="https://github.com/OpenMathLib/OpenBLAS.git"
    [opencv]="https://github.com/opencv/opencv.git"
    [pytorch]="https://github.com/pytorch/pytorch.git"
    [suitesparse]="https://github.com/DrTimothyAldenDavis/SuiteSparse.git"
    [libcxxwrap_julia]="https://github.com/JuliaInterop/libcxxwrap-julia.git"
)

declare -A LIBRARY_VERSION_VARS=(
    [ceres]=CERES_VERSION
    [colmap]=COLMAP_VERSION
    [g2o]=G2O_VERSION
    [gtsam]=GTSAM_VERSION
    [open3d]=OPEN3D_VERSION
    [openblas]=OPENBLAS_VERSION
    [opencv]=OPENCV_VERSION
    [pytorch]=PYTORCH_VERSION
    [libcxxwrap_julia]=LIBCXXWRAP_JULIA_VERSION
)

declare -A LIBRARY_VERSION_PREFIX=(
    [open3d]="v"
    [pytorch]="v"
)

declare -A LIBRARY_DOC_TITLES=(
    [ceres]="Ceres Solver"
    [colmap]="COLMAP"
    [g2o]="g2o"
    [gtsam]="GTSAM"
    [open3d]="Open3D"
    [openblas]="OpenBLAS"
    [opencv]="OpenCV"
    [pytorch]="PyTorch"
    [suitesparse]="SuiteSparse"
    [libcxxwrap_julia]="libcxxwrap-julia"
)

# ===== HELPERS =====
is_git_url() {
    [[ "$1" =~ ^(https?://|git@) ]]
}

normalize_version_tag() {
    local version="$1"
    local prefix="${2:-}"
    if [[ "$version" =~ (_git|_dev)$ ]]; then

---

**SEQUENTIAL CHECKING ENFORCED**: This is PART 1A of PART 1. After completing this part, continue with PART 1B: `Library-Analysis-Tool-PART1B.md`. Then proceed to PART 2: `Library-Analysis-Tool-PART2.md`.
