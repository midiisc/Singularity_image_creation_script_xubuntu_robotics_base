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
        version="${version%%_*}"
    fi
    if [[ "$version" == v* || "$version" == V* ]]; then
        echo "$version"
    elif [[ -n "$prefix" ]]; then
        echo "${prefix}${version}"
    else
        echo "$version"
    fi
}

tag_exists() {
    local repo="$1"
    local tag="$2"
    git ls-remote --tags --refs "$repo" "refs/tags/${tag}" >/dev/null 2>&1
}

fetch_latest_stable_tag() {
    local repo="$1"
    git ls-remote --tags --refs "$repo" 2>/dev/null \
        | awk '{print $2}' \
        | sed 's|refs/tags/||' \
        | grep -E '^[vV]?[0-9]+(\.[0-9]+)*([._-][0-9]+)?$' \
        | grep -viE 'rc|beta|alpha' \
        | sort -V \
        | tail -n 1
}

fetch_default_branch() {
    local repo="$1"
    git ls-remote --symref "$repo" HEAD 2>/dev/null \
        | awk -F'[/ ]+' '/^ref:/ {print $NF; exit}'
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE"
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    else
        log_warning "Config file not found at $CONFIG_FILE — proceeding without project version pinning"
    fi
}

resolve_library_source() {
    if [[ -n "$LIBRARY_ID" ]]; then
        if [[ -z "${LIBRARY_REPOS[$LIBRARY_ID]:-}" ]]; then
            log_error "Unknown library identifier: $LIBRARY_ID"
            log_info "Supported libraries: ${!LIBRARY_REPOS[*]}"
            exit 1
        fi
        REPO_SPEC="${REPO_SPEC:-${LIBRARY_REPOS[$LIBRARY_ID]}}"

        # MANDATORY: Check for version pinning in config.sh
        # This ensures correct supported flags for the pinned version are documented
        local version_var="${LIBRARY_VERSION_VARS[$LIBRARY_ID]:-}"
        if [[ -n "$version_var" && -n "${!version_var:-}" ]]; then
            LIBRARY_VERSION="${!version_var}"
            log_success "✅ Found config.sh version pin for ${LIBRARY_ID}: ${LIBRARY_VERSION} (via ${version_var})"
            log_info "Will use this version to ensure correct flag documentation"
        elif [[ -n "$version_var" ]]; then
            log_warning "⚠️  Config variable ${version_var} exists but is unset in config.sh"
            log_warning "Will fall back to latest stable release (not recommended for reproducible analysis)"
            log_warning "Consider adding version pinning to config.sh for ${LIBRARY_ID}"
        else
            log_warning "⚠️  No config mapping defined for ${LIBRARY_ID} version in script"
            log_warning "Will fall back to latest stable release (not recommended for reproducible analysis)"
            log_warning "Consider adding ${LIBRARY_ID} to LIBRARY_VERSION_VARS mapping and config.sh"
        fi
    fi

    if [[ -z "$REPO_SPEC" ]]; then
        log_error "Unable to determine repository source"
        exit 1
    fi
}

determine_checkout_ref() {
    # Priority 1: User-specified ref (explicit override)
    if [[ -n "$CHECKOUT_REF" ]]; then
        RESOLVED_REF="$CHECKOUT_REF"
        log_info "Using user-specified ref: $RESOLVED_REF"
        return
    fi

    # Priority 2: MANDATORY - Use version pinned in config.sh (if available)
    # This ensures correct supported flags for the pinned version are documented
    if [[ -n "$LIBRARY_ID" && -n "$LIBRARY_VERSION" ]]; then
        local prefix="${LIBRARY_VERSION_PREFIX[$LIBRARY_ID]:-}"
        local candidate
        candidate=$(normalize_version_tag "$LIBRARY_VERSION" "$prefix")
        if [[ -n "$candidate" ]] && is_git_url "$REPO_SPEC" && tag_exists "$REPO_SPEC" "$candidate"; then
            RESOLVED_REF="$candidate"
            log_success "✅ Using config.sh pinned version: ${RESOLVED_REF} (via ${LIBRARY_VERSION_VARS[$LIBRARY_ID]})"
            log_info "This ensures correct supported flags for version ${LIBRARY_VERSION} are documented"
            return
        else
            log_error "❌ CRITICAL: Configured version ${candidate:-<empty>} from config.sh not found in remote repository"
            log_error "Repository: $REPO_SPEC"
            log_error "Expected tag: $candidate"
            log_error "This may indicate:"
            log_error "  1. Version tag format mismatch (check LIBRARY_VERSION_PREFIX mapping)"
            log_error "  2. Repository structure changed"
            log_error "  3. Version not yet released"
            log_error ""
            log_error "Please verify the version in config.sh matches available repository tags"
            exit 1
        fi
    fi

    # Priority 3: Fallback to latest stable release (ONLY if version not pinned in config.sh)
    # NEVER use latest git snapshot - only stable releases
    if is_git_url "$REPO_SPEC"; then
        local latest
        latest=$(fetch_latest_stable_tag "$REPO_SPEC")
        if [[ -n "$latest" ]]; then
            RESOLVED_REF="$latest"
            log_warning "⚠️  No version pinned in config.sh for ${LIBRARY_ID:-library}"
            log_info "Falling back to latest stable release tag: ${RESOLVED_REF}"
            log_warning "NOTE: This may not match the version used in the build script"
            log_warning "Consider adding version pinning to config.sh for reproducible analysis"
            return
        fi
        # Last resort: Only if no stable tags exist, use default branch (should be rare)
        local default_branch
        default_branch=$(fetch_default_branch "$REPO_SPEC")
        if [[ -n "$default_branch" ]]; then
            RESOLVED_REF="$default_branch"
            log_error "❌ WARNING: No stable release tags found, using default branch ${RESOLVED_REF}"
            log_error "This is a git snapshot and may not represent a stable release"
            log_error "Documentation generated may not match any specific release version"
            return
        fi
    fi

    RESOLVED_REF=""
    log_error "❌ Unable to determine checkout reference"
    log_error "Repository: $REPO_SPEC"
    log_error "Library ID: ${LIBRARY_ID:-N/A}"
    exit 1
}

clone_repository() {
    log_info "Step 1: Preparing repository..."

    if [[ -d "$REPO_SPEC" ]]; then
        log_info "Using local checkout: $REPO_SPEC"
        ANALYSIS_ROOT="${ANALYSIS_DIR}/repo"
        mkdir -p "$ANALYSIS_ROOT"
        if command -v rsync >/dev/null 2>&1; then
            rsync -a --delete --exclude '.git' "$REPO_SPEC"/ "$ANALYSIS_ROOT"/
            if git -C "$REPO_SPEC" rev-parse --git-dir >/dev/null 2>&1; then
                rsync -a "$REPO_SPEC/.git/" "$ANALYSIS_ROOT/.git/" 2>/dev/null || true
            fi
        else
            log_warning "rsync not available; falling back to cp -a"
            cp -a "$REPO_SPEC"/. "$ANALYSIS_ROOT"/
        fi
    else
        if ! is_git_url "$REPO_SPEC"; then
            log_error "Unsupported repository spec: $REPO_SPEC"
            exit 1
        fi
        ANALYSIS_ROOT="${ANALYSIS_DIR}/repo"
        mkdir -p "$ANALYSIS_ROOT"
        if [[ -n "$RESOLVED_REF" ]]; then
            log_info "Cloning ${REPO_SPEC} at ref ${RESOLVED_REF}"
            if ! git clone --depth 1 --filter=blob:none --recurse-submodules "${REPO_SPEC}" "${ANALYSIS_ROOT}" --branch "${RESOLVED_REF}" 2>/dev/null; then
                log_warning "Shallow clone failed, retrying full clone"
                rm -rf "${ANALYSIS_ROOT}"
                git clone "${REPO_SPEC}" "${ANALYSIS_ROOT}"
                git -C "${ANALYSIS_ROOT}" checkout "${RESOLVED_REF}"
            fi
        else
            log_info "Cloning ${REPO_SPEC} (default HEAD)"
            git clone --depth 1 --filter=blob:none "${REPO_SPEC}" "${ANALYSIS_ROOT}"
        fi
        git -C "${ANALYSIS_ROOT}" submodule update --init --recursive --depth 1 2>/dev/null || \
        git -C "${ANALYSIS_ROOT}" submodule update --init --recursive 2>/dev/null || true
    fi

    if git -C "${ANALYSIS_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
        GIT_REMOTE_URL=$(git -C "${ANALYSIS_ROOT}" config --get remote.origin.url 2>/dev/null || echo "N/A")
        GIT_COMMIT=$(git -C "${ANALYSIS_ROOT}" rev-parse HEAD 2>/dev/null || echo "N/A")
        if [[ -z "$RESOLVED_REF" ]]; then
            RESOLVED_REF=$(git -C "${ANALYSIS_ROOT}" describe --tags --exact-match 2>/dev/null || git -C "${ANALYSIS_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || "")
        fi
    fi

    log_success "Repository staged at: ${ANALYSIS_ROOT}"
}

discover_files() {
    log_info "Step 2: Discovering build artefacts..."
    FILES_FOUND=()
    CMAKE_FILES=()
    HEADER_FILES=()
    BUILD_SCRIPTS=()

    while IFS= read -r -d '' file; do
        CMAKE_FILES+=("$file")
    done < <(find "${ANALYSIS_ROOT}" -type f -name "CMakeLists.txt" -print0 2>/dev/null)
    FILES_FOUND[cmake]=${#CMAKE_FILES[@]}

    while IFS= read -r -d '' file; do
        HEADER_FILES+=("$file")
    done < <(find "${ANALYSIS_ROOT}" -type f \( -name "*.h" -o -name "*.hpp" \) -print0 2>/dev/null)
    FILES_FOUND[headers]=${#HEADER_FILES[@]}

    while IFS= read -r -d '' file; do
        BUILD_SCRIPTS+=("$file")
    done < <(find "${ANALYSIS_ROOT}" -type f -name "*.sh" -print0 2>/dev/null)
    FILES_FOUND[scripts]=${#BUILD_SCRIPTS[@]}

    FILES_FOUND[configure]=$(find "${ANALYSIS_ROOT}" -type f \( -name "configure" -o -name "*.m4" \) 2>/dev/null | wc -l | tr -d ' ')
    FILES_FOUND[makefile]=$(find "${ANALYSIS_ROOT}" -type f -name "Makefile*" 2>/dev/null | wc -l | tr -d ' ')

    log_success "Discovered ${FILES_FOUND[cmake]:-0} CMakeLists, ${FILES_FOUND[headers]:-0} headers, ${FILES_FOUND[scripts]:-0} scripts"
}

extract_version() {
    local detected="unknown"
    if git -C "${ANALYSIS_ROOT}" describe --tags --exact-match >/dev/null 2>&1; then
        detected=$(git -C "${ANALYSIS_ROOT}" describe --tags --exact-match 2>/dev/null)
    elif git -C "${ANALYSIS_ROOT}" describe --tags >/dev/null 2>&1; then
        detected=$(git -C "${ANALYSIS_ROOT}" describe --tags 2>/dev/null)
    else
        detected=$(grep -hE "project\(.*VERSION|set\(.*VERSION" "${ANALYSIS_ROOT}/CMakeLists.txt" 2>/dev/null \
            | head -n1 \
            | sed -E 's/.*VERSION[[:space:]]+([0-9]+(\.[0-9]+){1,3}).*/\1/' )
    fi
    if [[ -z "$detected" ]]; then
        detected="unknown"
    fi
    echo "$detected"
}

extract_cmake_flags() {
    log_info "Step 3: Extracting CMake flags..."
    : > "${CMAKE_FLAGS_FILE}"
    if [[ ${#CMAKE_FILES[@]} -eq 0 ]]; then
        echo "_No CMakeLists.txt files located._" >> "${CMAKE_FLAGS_FILE}"
        log_warning "No CMakeLists.txt files discovered; skipping CMake flag extraction"
        return
    fi

    {
        echo "# CMake Flag Inventory"
        echo ""
        echo "_Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
        echo ""
    } >> "${CMAKE_FLAGS_FILE}"

    for cmake_file in "${CMAKE_FILES[@]}"; do
        local relpath
        relpath=$(realpath --relative-to="${ANALYSIS_ROOT}" "${cmake_file}" 2>/dev/null || echo "${cmake_file}")
        echo "## ${relpath}" >> "${CMAKE_FLAGS_FILE}"
        echo "" >> "${CMAKE_FLAGS_FILE}"

        local options
        options=$(grep -nE "^[[:space:]]*option\(" "${cmake_file}" 2>/dev/null || true)
        echo "**Options**" >> "${CMAKE_FLAGS_FILE}"
        if [[ -n "$options" ]]; then
            echo "$options" | sed 's/^\([0-9]\+\):[[:space:]]*/- L\1: /' >> "${CMAKE_FLAGS_FILE}"
        else
            echo "- (none found)" >> "${CMAKE_FLAGS_FILE}"
        fi
        echo "" >> "${CMAKE_FLAGS_FILE}"

        local cache_entries
        cache_entries=$(grep -nE "^[[:space:]]*set\([[:space:]]*CMAKE_[A-Z0-9_]*FLAGS" "${cmake_file}" 2>/dev/null || true)
        echo "**Global Compiler Flags**" >> "${CMAKE_FLAGS_FILE}"
        if [[ -n "$cache_entries" ]]; then
            echo "$cache_entries" | sed 's/^\([0-9]\+\):[[:space:]]*/- L\1: /' >> "${CMAKE_FLAGS_FILE}"
        else
            echo "- (none found)" >> "${CMAKE_FLAGS_FILE}"
        fi
        echo "" >> "${CMAKE_FLAGS_FILE}"

        local target_compile_opts
        target_compile_opts=$(grep -nE "target_compile_(options|definitions)" "${cmake_file}" 2>/dev/null || true)
        echo "**Target Compile Options/Definitions**" >> "${CMAKE_FLAGS_FILE}"
        if [[ -n "$target_compile_opts" ]]; then
            echo "$target_compile_opts" | sed 's/^\([0-9]\+\):[[:space:]]*/- L\1: /' >> "${CMAKE_FLAGS_FILE}"
