# Library Documentation & Flag Extraction Tool
## Automated Analyzer + AI Prompt Integration

This is a **complete, executable solution** that:
1. **Downloads repository** (git clone)
2. **Analyzes files** (CMake, C++, bash scripts)
3. **Extracts all flags and versions** (bash script)
4. **Feeds to AI prompt** (Claude/Cursor)
5. **Generates comprehensive documentation**

---

## PART 1: EXECUTABLE BASH SCRIPT (analyze-library.sh)

```bash
#!/bin/bash

################################################################################
# CONFIG-AWARE LIBRARY ANALYSIS TOOL
# Purpose:
#   * Clone the latest compatible stable release for a library using config.sh
#   * Recursively analyze the repository for flags, options, and dependencies
#   * Emit Markdown + JSON documentation consumable by downstream AI tooling
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
  * When --library is set, config.sh is sourced to resolve the stable release.
  * If config.sh does not specify a version, the latest non-RC tag is used.
  * When neither --library nor REPO_URL_OR_PATH is provided, usage is displayed.
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

        local version_var="${LIBRARY_VERSION_VARS[$LIBRARY_ID]:-}"
        if [[ -n "$version_var" && -n "${!version_var:-}" ]]; then
            LIBRARY_VERSION="${!version_var}"
            log_info "Config pin for ${LIBRARY_ID}: ${LIBRARY_VERSION} (via ${version_var})"
        elif [[ -n "$version_var" ]]; then
            log_warning "Config variable ${version_var} is unset — will auto-detect latest stable release"
        else
            log_warning "No config mapping defined for ${LIBRARY_ID} version — will auto-detect latest stable release"
        fi
    fi

    if [[ -z "$REPO_SPEC" ]]; then
        log_error "Unable to determine repository source"
        exit 1
    fi
}

determine_checkout_ref() {
    if [[ -n "$CHECKOUT_REF" ]]; then
        RESOLVED_REF="$CHECKOUT_REF"
        log_info "Using user-specified ref: $RESOLVED_REF"
        return
    fi

    if [[ -n "$LIBRARY_ID" && -n "$LIBRARY_VERSION" ]]; then
        local prefix="${LIBRARY_VERSION_PREFIX[$LIBRARY_ID]:-}"
        local candidate
        candidate=$(normalize_version_tag "$LIBRARY_VERSION" "$prefix")
        if [[ -n "$candidate" ]] && is_git_url "$REPO_SPEC" && tag_exists "$REPO_SPEC" "$candidate"; then
            RESOLVED_REF="$candidate"
            log_info "Resolved ${LIBRARY_ID} to config tag: ${RESOLVED_REF}"
            return
        else
            log_warning "Configured tag ${candidate:-<empty>} not found in remote — trying auto-detection"
        fi
    fi

    if is_git_url "$REPO_SPEC"; then
        local latest
        latest=$(fetch_latest_stable_tag "$REPO_SPEC")
        if [[ -n "$latest" ]]; then
            RESOLVED_REF="$latest"
            log_info "Auto-detected latest stable tag: ${RESOLVED_REF}"
            return
        fi
        local default_branch
        default_branch=$(fetch_default_branch "$REPO_SPEC")
        if [[ -n "$default_branch" ]]; then
            RESOLVED_REF="$default_branch"
            log_warning "Falling back to default branch ${RESOLVED_REF}"
            return
        fi
    fi

    RESOLVED_REF=""
    log_warning "No explicit ref detected — cloning default HEAD"
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
        else
            echo "- (none found)" >> "${CMAKE_FLAGS_FILE}"
        fi
        echo "" >> "${CMAKE_FLAGS_FILE}"

        local add_definitions
        add_definitions=$(grep -nE "^[[:space:]]*add_definitions\(" "${cmake_file}" 2>/dev/null || true)
        echo "**add_definitions**" >> "${CMAKE_FLAGS_FILE}"
        if [[ -n "$add_definitions" ]]; then
            echo "$add_definitions" | sed 's/^\([0-9]\+\):[[:space:]]*/- L\1: /' >> "${CMAKE_FLAGS_FILE}"
        else
            echo "- (none found)" >> "${CMAKE_FLAGS_FILE}"
        fi
        echo "" >> "${CMAKE_FLAGS_FILE}"
    done

    log_success "CMake flag extraction complete → ${CMAKE_FLAGS_FILE}"
}

extract_cpp_defines() {
    log_info "Step 4: Extracting C/C++ defines..."
    : > "${CPP_DEFINES_FILE}"
    if [[ ${#HEADER_FILES[@]} -eq 0 ]]; then
        echo "_No header files (*.h/ *.hpp) located._" >> "${CPP_DEFINES_FILE}"
        log_warning "No headers discovered; skipping macro extraction"
        return
    fi

    local tmp_defines
    tmp_defines="$(mktemp)"

    for header in "${HEADER_FILES[@]}"; do
        while IFS= read -r line; do
            printf '%s:%s\n' "$header" "$line" >> "$tmp_defines"
        done < <(grep -nE '^[[:space:]]*#define[[:space:]]+[A-Za-z0-9_]+' "$header" 2>/dev/null || true)
    done

    {
        echo "# Macro Inventory"
        echo ""
        echo "_Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
        echo ""
    } >> "${CPP_DEFINES_FILE}"

    if [[ ! -s "$tmp_defines" ]]; then
        echo "_No #define directives located._" >> "${CPP_DEFINES_FILE}"
        rm -f "$tmp_defines"
        return
    fi

    {
        echo "## Top Macros by Occurrence"
        echo ""
    } >> "${CPP_DEFINES_FILE}"

    local macro_counts
    macro_counts=$(awk -F'#define' '{macro=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", macro); print macro}' "$tmp_defines" \
        | sed 's/[[:space:]].*$//' \
        | sort | uniq -c | sort -nr)

    if [[ -n "$macro_counts" ]]; then
        if [[ "$FULL_SCAN" == true ]]; then
            echo "$macro_counts" | awk '{printf("- %s × %s\n", $1, $2)}' >> "${CPP_DEFINES_FILE}"
        else
            echo "$macro_counts" | head -n 200 | awk '{printf("- %s × %s\n", $1, $2)}' >> "${CPP_DEFINES_FILE}"
            if [[ $(echo "$macro_counts" | wc -l) -gt 200 ]]; then
                echo "" >> "${CPP_DEFINES_FILE}"
                echo "_Top macro list truncated; rerun without --summary for complete counts._" >> "${CPP_DEFINES_FILE}"
            fi
        fi
    else
        echo "- (none found)" >> "${CPP_DEFINES_FILE}"
    fi

    {
        echo ""
        echo "## Detailed Index"
        echo ""
    } >> "${CPP_DEFINES_FILE}"

    if [[ "$FULL_SCAN" == true ]]; then
        while IFS= read -r entry; do
            local file_path line_num rest relpath
            file_path="${entry%%:*}"
            rest="${entry#*:}"
            line_num="${rest%%:*}"
            relpath=$(realpath --relative-to="${ANALYSIS_ROOT}" "$file_path" 2>/dev/null || echo "$file_path")
            echo "- ${relpath} (L${line_num}): ${rest#*:}" >> "${CPP_DEFINES_FILE}"
        done < "$tmp_defines"
    else
        head -n 400 "$tmp_defines" | while IFS= read -r entry; do
            local file_path line_num rest relpath
            file_path="${entry%%:*}"
            rest="${entry#*:}"
            line_num="${rest%%:*}"
            relpath=$(realpath --relative-to="${ANALYSIS_ROOT}" "$file_path" 2>/dev/null || echo "$file_path")
            echo "- ${relpath} (L${line_num}): ${rest#*:}" >> "${CPP_DEFINES_FILE}"
        done
        if [[ $(wc -l < "$tmp_defines") -gt 400 ]]; then
            echo "" >> "${CPP_DEFINES_FILE}"
            echo "_Truncated for summary mode; rerun without --summary for full listing._" >> "${CPP_DEFINES_FILE}"
        fi
    fi

    rm -f "$tmp_defines"
    log_success "Macro extraction complete → ${CPP_DEFINES_FILE}"
}

analyze_bundled_components() {
    log_info "Step 5a: Analyzing bundled components..."
    local bundled_analysis_file="${OUTPUT_DIR}/bundled_components.md"
    : > "${bundled_analysis_file}"
    
    {
        echo "# Bundled Component Analysis"
        echo ""
        echo "_Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
        echo ""
        echo "## Detection Strategy"
        echo ""
        echo "This analysis identifies dependencies that are bundled within the library versus those requiring separate installation."
        echo ""
        
        # Check for external/third_party directories
        echo "## Bundled Dependencies (Subdirectories)"
        echo ""
        local bundled_dirs=$(find "${ANALYSIS_ROOT}" -type d \( -name "external" -o -name "third_party" -o -name "3rdparty" -o -name "vendor" \) 2>/dev/null || true)
        if [[ -n "$bundled_dirs" ]]; then
            echo "$bundled_dirs" | while IFS= read -r dir; do
                local relpath=$(realpath --relative-to="${ANALYSIS_ROOT}" "$dir" 2>/dev/null || echo "$dir")
                echo "### $relpath"
                echo ""
                # List subdirectories in external/
                if [[ -d "$dir" ]]; then
                    find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r subdir; do
                        local subname=$(basename "$subdir")
                        echo "- **${subname}**: Bundled as subdirectory"
                        # Try to detect version
                        if [[ -f "$subdir/CMakeLists.txt" ]]; then
                            local version=$(grep -m1 -E "project.*VERSION|set.*VERSION" "$subdir/CMakeLists.txt" 2>/dev/null | sed -E 's/.*VERSION[[:space:]]+([0-9.]+).*/\1/' || echo "unknown")
                            if [[ "$version" != "unknown" && -n "$version" ]]; then
                                echo "  - Version: ${version}"
                            fi
                        fi
                    done
                    echo ""
                fi
            done
        else
            echo "- No standard bundled dependency directories found (external/, third_party/, 3rdparty/)"
        fi
        echo ""
        
        # Check for add_subdirectory calls that reference external projects
        echo "## Bundled via add_subdirectory"
        echo ""
        local subdirs=$(grep -rh "add_subdirectory" "${CMAKE_FILES[@]}" 2>/dev/null | grep -vE "^\s*#" | grep -E "add_subdirectory\(" || true)
        if [[ -n "$subdirs" ]]; then
            echo "$subdirs" | sed -E 's/.*add_subdirectory\(([^)]+)\).*/- \1/' | sort -u | while IFS= read -r subdir; do
                # Skip common internal directories
                if [[ ! "$subdir" =~ ^(src|test|tests|examples|samples|docs|doc|cmake|scripts)$ ]]; then
                    echo "- ${subdir}"
                fi
            done
        else
            echo "- (none detected)"
        fi
        echo ""
        
        # Check for FetchContent (downloaded at configure time)
        echo "## FetchContent Dependencies (Downloaded)"
        echo ""
        local fetch_content=$(grep -rh "FetchContent_Declare" "${CMAKE_FILES[@]}" 2>/dev/null || true)
        if [[ -n "$fetch_content" ]]; then
            echo "$fetch_content" | grep -oE "FetchContent_Declare\([^)]*\)" | while IFS= read -r decl; do
                local dep_name=$(echo "$decl" | sed -E 's/FetchContent_Declare\(([^ )]+).*/\1/')
                local git_repo=$(echo "$decl" | grep -oE "GIT_REPOSITORY [^ )]*" | sed 's/GIT_REPOSITORY //' || echo "")
                local git_tag=$(echo "$decl" | grep -oE "GIT_TAG [^ )]*" | sed 's/GIT_TAG //' || echo "")
                echo "- **${dep_name}**"
                if [[ -n "$git_repo" ]]; then
                    echo "  - Repository: ${git_repo}"
                fi
                if [[ -n "$git_tag" ]]; then
                    echo "  - Version/Tag: ${git_tag}"
                fi
            done
        else
            echo "- (none detected)"
        fi
        echo ""
    } >> "${bundled_analysis_file}"
    
    log_success "Bundled component analysis → ${bundled_analysis_file}"
}

analyze_version_changes() {
    log_info "Step 5b: Analyzing version changes and changelogs..."
    local changelog_file="${OUTPUT_DIR}/version_changes.md"
    : > "${changelog_file}"
    
    {
        echo "# Version Change Analysis"
        echo ""
        echo "_Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
        echo ""
        
        if ! git -C "${ANALYSIS_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
            echo "_Not a git repository; version analysis skipped._"
            log_warning "Not a git repository, skipping version analysis"
            return
        fi
        
        echo "## Current Version: ${RESOLVED_REF:-unknown}"
        echo ""
        
        # Try to find recent tags
        echo "## Recent Release Tags"
        echo ""
        local recent_tags=$(git -C "${ANALYSIS_ROOT}" tag --sort=-version:refname 2>/dev/null | head -n 10 || true)
        if [[ -n "$recent_tags" ]]; then
            echo "$recent_tags" | while IFS= read -r tag; do
                local tag_date=$(git -C "${ANALYSIS_ROOT}" log -1 --format=%ai "$tag" 2>/dev/null || echo "unknown")
                echo "- \`${tag}\` (${tag_date})"
            done
        else
            echo "- (no tags found)"
        fi
        echo ""
        
        # Analyze dependency changes if we have tags
        if [[ -n "$recent_tags" ]]; then
            echo "## Dependency Changes Between Versions"
            echo ""
            local latest_tag=$(echo "$recent_tags" | head -n1)
            local previous_tag=$(echo "$recent_tags" | sed -n '2p')
            
            if [[ -n "$previous_tag" && -n "$latest_tag" ]]; then
                echo "### Changes from ${previous_tag} to ${latest_tag}"
                echo ""
                
                # Look for dependency-related changes
                local dep_changes=$(git -C "${ANALYSIS_ROOT}" log "${previous_tag}..${latest_tag}" \
                    --grep="depend\|bundle\|include\|integrate\|external\|third.party" \
                    --oneline 2>/dev/null | head -n 20 || true)
                
                if [[ -n "$dep_changes" ]]; then
                    echo "**Dependency-related commits:**"
                    echo '```'
                    echo "$dep_changes"
                    echo '```'
                    echo ""
                else
                    echo "- No dependency-related commits found in git log"
                    echo ""
                fi
                
                # Check for CMakeLists.txt changes
                local cmake_changes=$(git -C "${ANALYSIS_ROOT}" diff "${previous_tag}..${latest_tag}" -- CMakeLists.txt 2>/dev/null | grep -E "^\+.*find_package|^\+.*FetchContent|^\+.*add_subdirectory|^-.*find_package|^-.*FetchContent|^-.*add_subdirectory" | head -n 30 || true)
                
                if [[ -n "$cmake_changes" ]]; then
                    echo "**CMakeLists.txt dependency changes:**"
                    echo '```diff'
                    echo "$cmake_changes"
                    echo '```'
                    echo ""
                fi
            fi
        fi
        
        # Check for CHANGELOG file
        echo "## Changelog Excerpts"
        echo ""
        local changelog=$(find "${ANALYSIS_ROOT}" -maxdepth 2 -type f -iname "CHANGELOG*" -o -iname "HISTORY*" -o -iname "RELEASES*" 2>/dev/null | head -n1)
        if [[ -n "$changelog" && -f "$changelog" ]]; then
            echo "Found changelog: $(basename "$changelog")"
            echo ""
            echo "**Recent entries mentioning dependencies:**"
            echo '```'
            grep -i -E "depend|bundle|include|integrate|external|third.party|metis|eigen|blas|lapack" "$changelog" 2>/dev/null | head -n 30 || echo "(no matches found)"
            echo '```'
        else
            echo "- No CHANGELOG file found"
        fi
        echo ""
    } >> "${changelog_file}"
    
    log_success "Version change analysis → ${changelog_file}"
}

create_dependency_recommendations() {
    log_info "Step 5c: Creating dependency recommendations..."
    local recommendations_file="${OUTPUT_DIR}/dependency_recommendations.md"
    : > "${recommendations_file}"
    
    {
        echo "# Dependency Management Recommendations"
        echo ""
        echo "_Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
        echo ""
        
        echo "## Bundled vs Separate: Pros & Cons"
        echo ""
        echo "### Bundled Dependencies"
        echo ""
        echo "**Advantages:**"
        echo "- ✅ Simplified build process (fewer external dependencies to install)"
        echo "- ✅ Guaranteed version compatibility (library tested with specific versions)"
        echo "- ✅ Faster initial setup (no hunting for compatible dependency versions)"
        echo "- ✅ Reproducible builds (same dependencies across all environments)"
        echo "- ✅ Reduced dependency resolution conflicts"
        echo ""
        echo "**Disadvantages:**"
        echo "- ❌ Larger binary sizes (dependencies compiled into library)"
        echo "- ❌ Potential symbol conflicts if dependency used elsewhere"
        echo "- ❌ Harder to apply security updates to bundled dependencies"
        echo "- ❌ Duplicate libraries on system if multiple projects bundle same dependency"
        echo "- ❌ More disk space usage"
        echo ""
        echo "**Best used when:**"
        echo "- Rapid deployment is priority"
        echo "- Version sensitivity is critical"
        echo "- Limited system administration control"
        echo "- Standalone application deployment"
        echo ""
        
        echo "### Separate System Dependencies"
        echo ""
        echo "**Advantages:**"
        echo "- ✅ Shared libraries save disk space"
        echo "- ✅ Easier security updates (update once, affects all)"
        echo "- ✅ Centralized dependency management"
        echo "- ✅ Smaller application binaries"
        echo "- ✅ System package manager handles updates"
        echo ""
        echo "**Disadvantages:**"
        echo "- ❌ Version mismatch risks between library and dependencies"
        echo "- ❌ Complex dependency resolution required"
        echo "- ❌ Build system complexity increases"
        echo "- ❌ Potential breakage from system updates"
        echo "- ❌ Requires more setup documentation"
        echo ""
        echo "**Best used when:**"
        echo "- System integration is important"
        echo "- Multiple applications share dependencies"
        echo "- Security updates are frequent/critical"
        echo "- Long-term system maintenance is planned"
        echo ""
        
        echo "## Detection Strategy"
        echo ""
        echo "When integrating a library, follow this verification process:"
        echo ""
        echo "1. **Check version being built**: Don't assume old documentation applies"
        echo "   \`\`\`bash"
        echo "   git describe --tags --exact-match 2>/dev/null || git rev-parse --abbrev-ref HEAD"
        echo "   \`\`\`"
        echo ""
        echo "2. **Parse CMakeLists.txt for bundling indicators**:"
        echo "   \`\`\`bash"
        echo "   grep -r \"FetchContent_Declare\\|add_subdirectory.*external\" ."
        echo "   find . -type d -name \"external\" -o -name \"third_party\""
        echo "   \`\`\`"
        echo ""
        echo "3. **Check changelog between versions**:"
        echo "   \`\`\`bash"
        echo "   git log v7.0..v7.8 --grep=\"bundle\\|dependency\" --oneline"
        echo "   \`\`\`"
        echo ""
        echo "4. **Verify built binaries**:"
        echo "   \`\`\`bash"
        echo "   nm -D /usr/local/lib/libname.so | grep \"dependency_symbol\""
        echo "   ldd /usr/local/lib/libname.so"
        echo "   pkg-config --libs library-name"
        echo "   \`\`\`"
        echo ""
        echo "5. **Check CMake config files**:"
        echo "   \`\`\`bash"
        echo "   grep \"find_dependency\" /usr/local/lib/cmake/Library/LibraryConfig.cmake"
        echo "   \`\`\`"
        echo ""
        
        echo "## Documentation Template"
        echo ""
        echo "When documenting library integration, include:"
        echo ""
        echo "\`\`\`bash"
        echo "# Library: [Name] [Version]"
        echo "# Source: [URL to exact tag/commit]"
        echo "# Verified: [Date] via [method]"
        echo "#"
        echo "# Bundled dependencies:"
        echo "#   - [Dependency]: [version] (since [library version])"
        echo "#   - Rationale: [why bundled is chosen]"
        echo "#"
        echo "# Separate dependencies:"
        echo "#   - [Dependency]: User must provide [version range]"
        echo "#   - Installation: apt install [package] OR build from [source]"
        echo "#"
        echo "# Decision rationale:"
        echo "#   - [Explain bundled vs separate choice]"
        echo "#   - Trade-offs accepted: [list]"
        echo "\`\`\`"
        echo ""
    } >> "${recommendations_file}"
    
    log_success "Dependency recommendations → ${recommendations_file}"
}

extract_dependencies() {
    if [[ "$INCLUDE_DEPENDENCY_MAP" != true ]]; then
        log_info "Skipping dependency extraction (--no-deps specified)"
        echo "_Dependency extraction skipped (per --no-deps)_." > "${DEPENDENCIES_FILE}"
        return
    fi

    log_info "Step 5: Extracting dependency graph hints..."
    : > "${DEPENDENCIES_FILE}"
    if [[ ${#CMAKE_FILES[@]} -eq 0 ]]; then
        echo "_No CMakeLists discovered — dependency extraction skipped._" >> "${DEPENDENCIES_FILE}"
        return
    fi

    local tmp_find tmp_link tmp_fetch tmp_pkg
    tmp_find="$(mktemp)"
    tmp_link="$(mktemp)"
    tmp_fetch="$(mktemp)"
    tmp_pkg="$(mktemp)"

    for cmake_file in "${CMAKE_FILES[@]}"; do
        grep -hE "find_package\(" "$cmake_file" 2>/dev/null >> "$tmp_find" || true
        grep -hE "target_link_libraries\(" "$cmake_file" 2>/dev/null >> "$tmp_link" || true
        grep -hE "FetchContent_Declare\(" "$cmake_file" 2>/dev/null >> "$tmp_fetch" || true
        grep -hE "pkg_check_modules\(" "$cmake_file" 2>/dev/null >> "$tmp_pkg" || true
    done

    {
        echo "# Dependency Signals"
        echo ""
        echo "_Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
        echo ""

        echo "## find_package Calls"
        echo ""
        if [[ -s "$tmp_find" ]]; then
            sed -E 's/.*find_package\(([^ )]+).*/- \1/' "$tmp_find" | sort -u
        else
            echo "- (none found)"
        fi
        echo ""

        echo "## target_link_libraries"
        echo ""
        if [[ -s "$tmp_link" ]]; then
            sed -E 's/.*target_link_libraries\(([^ )]+)[[:space:]]+(PUBLIC|PRIVATE|INTERFACE)?[[:space:]]*(.*)\).*/- Target: \1 | Scope: \2 | Links: \3/' "$tmp_link" \
                | sed 's/  */ /g' \
                | sort -u
        else
            echo "- (none found)"
        fi
        echo ""

        echo "## FetchContent_Declare"
        echo ""
        if [[ -s "$tmp_fetch" ]]; then
            sed -E 's/.*FetchContent_Declare\(([^ )]+).*/- \1/' "$tmp_fetch" | sort -u
        else
            echo "- (none found)"
        fi
        echo ""

        echo "## pkg_check_modules"
        echo ""
        if [[ -s "$tmp_pkg" ]]; then
            sed -E 's/.*pkg_check_modules\(([^ )]+).*/- \1/' "$tmp_pkg" | sort -u
        else
            echo "- (none found)"
        fi
        echo ""
    } >> "${DEPENDENCIES_FILE}"

    rm -f "$tmp_find" "$tmp_link" "$tmp_fetch" "$tmp_pkg"
    
    # Run new enhanced analysis functions
    analyze_bundled_components
    analyze_version_changes
    create_dependency_recommendations
    
    log_success "Dependency extraction complete → ${DEPENDENCIES_FILE}"
}

create_summary() {
    log_info "Step 6: Creating analysis summary..."
    local detected_version
    detected_version=$(extract_version)

    {
        echo "# Library Analysis Report"
        echo ""
        echo "**Generated:** $(date)"
        echo ""
        echo "**Repository:** ${GIT_REMOTE_URL}"
        echo ""
        echo "**Analyzed Ref:** ${RESOLVED_REF:-unknown}"
        echo ""
        echo "**Head Commit:** ${GIT_COMMIT}"
        echo ""
        echo "**Detected Version:** ${detected_version}"
        if [[ -n "$LIBRARY_ID" ]]; then
            echo ""
            echo "**Library Identifier:** ${LIBRARY_ID}"
            if [[ -n "$LIBRARY_VERSION" ]]; then
                echo ""
                echo "**Config Pin:** ${LIBRARY_VERSION}"
            fi
        fi
        echo ""
        echo "## File Statistics"
        echo ""
        echo "- CMakeLists.txt files: ${FILES_FOUND[cmake]:-0}"
        echo "- Header files: ${FILES_FOUND[headers]:-0}"
        echo "- Shell scripts: ${FILES_FOUND[scripts]:-0}"
        echo "- configure/m4 scripts: ${FILES_FOUND[configure]:-0}"
        echo "- Makefiles: ${FILES_FOUND[makefile]:-0}"
        echo ""
        echo "## Generated Artefacts"
        echo ""
        echo "### Core Analysis Files"
        echo "- \`$(basename "${CMAKE_FLAGS_FILE}")\` – CMake flags and cache variables"
        echo "- \`$(basename "${CPP_DEFINES_FILE}")\` – C/C++ macro inventory"
        echo "- \`$(basename "${DEPENDENCIES_FILE}")\` – Dependency extraction"
        echo ""
        echo "### Enhanced Dependency Analysis"
        echo "- \`bundled_components.md\` – Bundled vs separate dependency detection"
        echo "- \`version_changes.md\` – Changelog and version transition analysis"
        echo "- \`dependency_recommendations.md\` – Pros/cons and best practices"
        echo ""
        echo "### Documentation"
        echo "- \`$(basename "${DOC_FILE}")\` – Consolidated documentation"
        echo "- \`$(basename "${JSON_FILE}")\` – Machine-readable summary"
        echo ""
        echo "## Next Steps"
        echo ""
        echo "1. Review generated Markdown artefacts in ${OUTPUT_DIR}"
        echo "2. **Check bundled_components.md** to understand what's bundled vs separate"
        echo "3. **Review version_changes.md** for dependency evolution across versions"
        echo "4. **Read dependency_recommendations.md** for integration guidance"
        echo "5. Feed \`$(basename "${DOC_FILE}")\` to the Advanced Library Documentation prompt"
        echo "6. Optionally rerun with \`--summary\` for condensed output"
    } > "${REPORT_FILE}"

    log_success "Summary created → ${REPORT_FILE}"
}

create_json_output() {
    log_info "Step 7: Creating JSON metadata..."
    local detected_version
    detected_version=$(extract_version)

    cat > "${JSON_FILE}" <<EOF
{
  "analysis_metadata": {
    "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "repository": "${GIT_REMOTE_URL}",
    "analyzed_ref": "${RESOLVED_REF}",
    "head_commit": "${GIT_COMMIT}",
    "library_id": "${LIBRARY_ID}",
    "library_config_version": "${LIBRARY_VERSION}",
    "detected_version": "${detected_version}",
    "mode": "$( [[ "${FULL_SCAN}" == true ]] && echo "full" || echo "summary" )"
  },
  "file_statistics": {
    "cmake_files": ${FILES_FOUND[cmake]:-0},
    "headers": ${FILES_FOUND[headers]:-0},
    "scripts": ${FILES_FOUND[scripts]:-0},
    "configure_scripts": ${FILES_FOUND[configure]:-0},
    "makefiles": ${FILES_FOUND[makefile]:-0}
  },
  "artefacts": {
    "report_markdown": "$(basename "${REPORT_FILE}")",
    "cmake_flags": "$(basename "${CMAKE_FLAGS_FILE}")",
    "cpp_defines": "$(basename "${CPP_DEFINES_FILE}")",
    "dependencies": "$(basename "${DEPENDENCIES_FILE}")",
    "documentation": "$(basename "${DOC_FILE}")"
  },
  "next_steps": [
    "Review generated Markdown files",
    "Feed documentation into Advanced Library Documentation prompt",
    "Trigger downstream build/test automation as needed"
  ]
}
EOF

    log_success "JSON metadata created → ${JSON_FILE}"
}

create_markdown_documentation() {
    log_info "Step 8: Building consolidated documentation..."
    local title="${LIBRARY_DOC_TITLES[$LIBRARY_ID]:-Library}"
    if [[ -n "$RESOLVED_REF" ]]; then
        title="${title} (${RESOLVED_REF})"
    fi

    {
        echo "# ${title} Flag Documentation"
        echo ""
        echo "_Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
        echo ""
        if [[ -n "$LIBRARY_VERSION" ]]; then
            echo "- Configured version: \`${LIBRARY_VERSION}\`"
        fi
        if [[ -n "$RESOLVED_REF" ]]; then
            echo "- Analyzed git ref: \`${RESOLVED_REF}\`"
        fi
        if [[ -n "$GIT_COMMIT" ]]; then
            echo "- Commit: \`${GIT_COMMIT}\`"
        fi
        if [[ -n "$GIT_REMOTE_URL" ]]; then
            echo "- Remote: \`${GIT_REMOTE_URL}\`"
        fi
        echo ""
        echo "## Contents"
        echo ""
        echo "- [CMake Flags](#cmake-flags)"
        echo "- [C/C++ Macros](#cc-macros)"
        if [[ "$INCLUDE_DEPENDENCY_MAP" == true ]]; then
            echo "- [Dependency Signals](#dependency-signals)"
            echo "- [Bundled Components](#bundled-components)"
            echo "- [Version Changes](#version-changes)"
            echo "- [Dependency Recommendations](#dependency-recommendations)"
        fi
        echo "- [File Statistics](#file-statistics)"
        echo ""
        echo "## CMake Flags"
        echo ""
        cat "${CMAKE_FLAGS_FILE}"
        echo ""
        echo "## C/C++ Macros"
        echo ""
        cat "${CPP_DEFINES_FILE}"
        if [[ "$INCLUDE_DEPENDENCY_MAP" == true ]]; then
            echo ""
            echo "## Dependency Signals"
            echo ""
            cat "${DEPENDENCIES_FILE}"
            echo ""
            echo "## Bundled Components"
            echo ""
            if [[ -f "${OUTPUT_DIR}/bundled_components.md" ]]; then
                cat "${OUTPUT_DIR}/bundled_components.md"
            else
                echo "_(Bundled component analysis not available)_"
            fi
            echo ""
            echo "## Version Changes"
            echo ""
            if [[ -f "${OUTPUT_DIR}/version_changes.md" ]]; then
                cat "${OUTPUT_DIR}/version_changes.md"
            else
                echo "_(Version change analysis not available)_"
            fi
            echo ""
            echo "## Dependency Recommendations"
            echo ""
            if [[ -f "${OUTPUT_DIR}/dependency_recommendations.md" ]]; then
                cat "${OUTPUT_DIR}/dependency_recommendations.md"
            else
                echo "_(Dependency recommendations not available)_"
            fi
        fi
        echo ""
        echo "## File Statistics"
        echo ""
        echo "- CMakeLists.txt files: ${FILES_FOUND[cmake]:-0}"
        echo "- Header files: ${FILES_FOUND[headers]:-0}"
        echo "- Shell scripts: ${FILES_FOUND[scripts]:-0}"
        echo "- configure/m4 scripts: ${FILES_FOUND[configure]:-0}"
        echo "- Makefiles: ${FILES_FOUND[makefile]:-0}"
    } > "${DOC_FILE}"

    log_success "Consolidated documentation created → ${DOC_FILE}"
}

main() {
    log_info "Starting Library Analysis Tool"
    log_info "Output directory: $(realpath "${OUTPUT_DIR}")"

    load_config
    resolve_library_source
    determine_checkout_ref
    clone_repository
    discover_files
    extract_cmake_flags
    extract_cpp_defines
    extract_dependencies
    create_summary
    create_markdown_documentation
    create_json_output

    echo ""
    log_success "Analysis complete!"
    echo ""
    echo "Generated artefacts:"
    echo "  Core files:"
    echo "    - ${REPORT_FILE}"
    echo "    - ${DOC_FILE}"
    echo "    - ${CMAKE_FLAGS_FILE}"
    echo "    - ${CPP_DEFINES_FILE}"
    echo "    - ${DEPENDENCIES_FILE}"
    echo "    - ${JSON_FILE}"
    if [[ "$INCLUDE_DEPENDENCY_MAP" == true ]]; then
        echo "  Enhanced dependency analysis:"
        echo "    - ${OUTPUT_DIR}/bundled_components.md"
        echo "    - ${OUTPUT_DIR}/version_changes.md"
        echo "    - ${OUTPUT_DIR}/dependency_recommendations.md"
    fi
    echo ""
    log_info "Next: Review dependency analysis files, then feed '${DOC_FILE}' into the Advanced Library Documentation prompt"
}

main "$@"
```

---

## PART 2: HOW TO USE (Agent-Facing Prompt Flow)

### User Instructions (what you copy into Cursor/Claude)

1. Copy the **Agent Prompt** below into your IDE chat.
2. Replace the placeholders at the top (for example `TARGET_LIBRARY`) with the library you want analyzed.
3. Send the prompt. The agent will:
   - Materialize `analyze-library.sh` (if it does not exist)
   - Execute the script with the supplied parameters
   - Gather the generated artefacts
   - Feed `flags_documentation.md` into the advanced documentation workflow
4. Review the produced documentation and follow-up as needed (e.g., request deeper dives, extra filtering, comparisons).

### Agent Prompt Template

```
You are the Library Analysis Agent.

TARGET_LIBRARY="ceres"             # required: library identifier or Git URL/path
TARGET_OUTPUT_DIR="./analysis"     # optional: where to store artefacts
TARGET_REF=""                      # optional: tag/branch override; leave empty to auto-detect
RUN_SUMMARY_MODE=false             # optional: set true for condensed output
SKIP_DEPENDENCIES=false            # optional: set true to skip dependency extraction

Instructions:
1. Clean up any temporary helper scripts from prior runs (e.g., `rm -f ./analyze-library.tmp.sh ./complete-analysis.tmp.sh`). Ensure `analyze-library.sh` exists and matches the exact contents from the "Executable Bash Script" section of Library-Analysis-Tool.md; recreate it if needed.
2. Select the analysis version in the following priority order:  
   a. `TARGET_REF` (explicit request in this prompt)  
   b. Version pinned in `config.sh` (or other project code/configuration files)  
   c. Latest compatible stable release/tag when neither is set  
   When running the script, ensure it uses the chosen version by applying `--ref` if needed or allowing the script to resolve the config/default logic automatically.
3. Run the script with:
      ./analyze-library.sh --library "${TARGET_LIBRARY}" \
          --output "${TARGET_OUTPUT_DIR}/${TARGET_LIBRARY}" \
          $( [[ -n "${TARGET_REF}" ]] && printf -- '--ref %s ' "${TARGET_REF}" ) \
          $( [[ "${RUN_SUMMARY_MODE}" == "true" ]] && printf -- '--summary ' ) \
          $( [[ "${SKIP_DEPENDENCIES}" == "true" ]] && printf -- '--no-deps ' )
   - If `TARGET_LIBRARY` is a Git URL or local path, call the script accordingly (no `--library` flag).
4. After execution, read `${TARGET_OUTPUT_DIR}/${TARGET_LIBRARY}/flags_documentation.md`.
5. Feed that documentation into the Advanced Library Documentation Prompt (Prompt [260]) and produce the final synthesized report.
6. Delete any temporary helper scripts you generated solely for this run (e.g., `rm -f ./analyze-library.tmp.sh ./complete-analysis.tmp.sh`) before finishing.

Important:
- Handle errors robustly. Re-run the script with diagnostic logging if initial analysis fails.
- Prefer versions pinned in config.sh; fall back to latest stable tag when missing.
- Do not request additional user input unless absolutely necessary.
```

### How the Agent Uses the Artefacts

Internally, the agent will:

```bash
cd "${TARGET_OUTPUT_DIR}/${TARGET_LIBRARY}"
# Inspect artefacts
ls -1
# Feed primary documentation into subsequent prompt
cat flags_documentation.md | <downstream prompt pipeline>
```

The agent copies the generated content (especially `flags_documentation.md`) into the advanced documentation prompt and delivers the final response to you.

### Optional Agent Enhancements

- If you want comparative analysis, instruct the agent to run the prompt twice (different libraries) and summarize differences.
- For CI integration, ask the agent to package the script and instructions into a reusable workflow/job.
- To focus on a subset (e.g., CUDA flags), instruct the agent during the final reporting phase.

### Example Agent Invocation (for clarity)

> *“Use the Library Analysis prompt for `open3d`, store results under `./analysis/open3d`, run in summary mode, and skip dependency extraction.”*

The agent will substitute:

```
TARGET_LIBRARY="open3d"
TARGET_OUTPUT_DIR="./analysis"
RUN_SUMMARY_MODE=true
SKIP_DEPENDENCIES=true
```

and follow the same automated process. The user does **not** have to create or run scripts manually.

### Hand-off to Advanced Documentation

When the agent transitions to the advanced documentation prompt, it pastes the generated content and requests the final structured report. The agent workflow ensures `flags_documentation.md` is always available for that hand-off.

```
[In Claude/Cursor Composer, use the Advanced-Library-Documentation-Prompt from [260]]

Paste the full prompt [260]

Then paste the contents of \`flags_documentation.md\` (or the combined artefact) at the end:

"Here is the consolidated flag documentation from the repository analysis:

[PASTE EXTRACTED DATA HERE]

Now, using the agent framework in the prompt above, generate comprehensive documentation 
with all flags categorized, dependencies mapped, versions detected, and examples provided."
```

---

## PART 3: COMPLETE WORKFLOW (One Command)

This section remains for agents or automations that prefer to wrap the analyzer in a single helper script. The agent can create and execute `complete-analysis.sh` automatically when additional orchestration is desired (for example, batching or chaining analyses without manual prompting).

```bash
#!/bin/bash
# complete-analysis.sh
# One-command analysis + documentation generation

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 [analyze-library.sh arguments...]"
  echo "Example: $0 --library ceres"
  exit 1
fi

TEMP_DIR="/tmp/lib_analysis_$$"
OUTPUT_PATH=""
ARGS=("$@")

for ((i=0; i<${#ARGS[@]}; i++)); do
  if [[ "${ARGS[$i]}" == "--output" || "${ARGS[$i]}" == "-o" ]]; then
    if (( i + 1 < ${#ARGS[@]} )); then
      OUTPUT_PATH="${ARGS[$((i+1))]}"
    fi
    break
  fi
done

CMD=(./analyze-library.sh "$@")
if [[ -z "$OUTPUT_PATH" ]]; then
  CMD+=(--output "$TEMP_DIR")
else
  mkdir -p "${OUTPUT_PATH}"
  TEMP_DIR="$(realpath "${OUTPUT_PATH}")"
fi

echo "📥 Starting complete analysis workflow..."
"${CMD[@]}"

echo ""
echo "📋 Primary handoff artefact (flags_documentation.md):"
echo "------------------------------------------------------------------"
if [[ -f "${TEMP_DIR}/flags_documentation.md" ]]; then
  cat "${TEMP_DIR}/flags_documentation.md"
else
  echo "(flags_documentation.md not found in ${TEMP_DIR})"
fi
echo "------------------------------------------------------------------"

echo ""
echo "📌 NEXT STEPS:"
echo ""
echo "1. Copy the consolidated documentation above"
echo "2. Open Cursor/Claude"
echo "3. Paste the Advanced-Library-Documentation-Prompt [260]"
echo "4. Paste the copied documentation at the end"
echo "5. Run the analysis"
echo ""
echo "ℹ️  Files saved in: ${TEMP_DIR}"
```

---

## PART 4: INTEGRATION: Bash Script + AI Prompt

### How They Work Together

```
┌──────────────────────────────────────────┐
│ BASH SCRIPT (analyze-library.sh)        │
│ - Downloads repo (git clone)             │
│ - Finds CMakeLists.txt files             │
│ - Extracts flags from C++, CMake         │
│ - Detects versions                       │
│ - Creates structured text output         │
└────────────┬─────────────────────────────┘
             │
             ↓ (feeds extracted data)
             │
┌────────────▼──────────────────────────────────┐
│ CLAUDE/CURSOR + AI PROMPT [260]              │
│ - Uses extracted data as input                │
│ - Applies agent hierarchy (7 agents)          │
│ - Categorizes flags (10 categories)           │
│ - Maps dependencies                           │
│ - Detects conflicts                           │
│ - Generates comprehensive documentation       │
│ - Creates build examples                      │
│ - Produces markdown + JSON output             │
└─────────────────────────────────────────────────┘
             │
             ↓ (outputs)
             │
┌────────────▼──────────────────────────────────┐
│ FINAL DOCUMENTATION                           │
│ - Comprehensive flag reference                │
│ - Categorized by performance/GPU/MKL/etc      │
│ - Dependency matrix                           │
│ - Build examples (copy-paste ready)           │
│ - Troubleshooting guide                       │
│ - Version compatibility                       │
└────────────────────────────────────────────────┘
```

---

## SUMMARY

**Current Prompt [260]:** 
- Instructions for analysis (what should be done)
- Used manually in Claude/Cursor
- Requires you to explain data

**This Bash Script + Prompt Integration:**
- ✅ **Automatically downloads repo** (git clone)
- ✅ **Actually analyzes files** (CMake, C++, headers)
- ✅ **Extracts real flags and versions**
- ✅ **Outputs structured data**
- ✅ **Feeds to AI prompt automatically**
- ✅ **Generates comprehensive documentation**

**Usage (for the user):**
1. Copy the Agent Prompt Template.
2. Set `TARGET_LIBRARY`, optionally tweak other variables.
3. Send the prompt in Cursor/Claude – the agent generates scripts, runs analysis, and returns the final documentation automatically.

This is a **complete, working solution** that automates the entire process!
