# Library Documentation & Flag Extraction Tool - PART 1B

HARD ENFORCEMENT – SINGLE-PART MEMORY & 500-LINE CHUNKING (PART 1B)
- Only PART 1B content may be loaded while executing this part. Unload other tool/manual parts from memory.
- Use master chunking: max 500 lines (target 450–500) with 20–40 lines overlap. Process chunks in order.
- For each chunk: execute PART 1B tasks fully → apply fixes → re-run PART 1B checks until PASS/N/A. Keep only compact capsule (≤ 2KB): status map, symbol names, chunk cursor.
- Proceed to PART 2 only after all chunks pass; unload PART 1B before loading PART 2.
**SEQUENTIAL CHECKING ENFORCED**: This is PART 1B of PART 1. You MUST have completed PART 1A (`Library-Analysis-Tool-PART1A.md`) before starting this part. After completing PART 1B, proceed to PART 2: `Library-Analysis-Tool-PART2.md`.

---

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
