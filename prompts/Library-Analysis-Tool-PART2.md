# Library Documentation & Flag Extraction Tool - PART 2
## Automated Analyzer + AI Prompt Integration

**This is PART 2 of 3. See also:**
- `Library-Analysis-Tool-PART1.md` - Part 1 (Executable Bash Script)
- `Library-Analysis-Tool-PART3.md` - Part 3 (Complete Workflow, Integration)

---

## 🚨 MANDATORY SEQUENTIAL EXECUTION INSTRUCTIONS

**CRITICAL: This is a multi-part prompt designed to maintain 500-line full context limits.**

**PREREQUISITE CHECK:**
- [ ] **PART 1 COMPLETED**: All tasks in PART 1 must be 100% complete before starting PART 2
- [ ] **PART 1 OUTPUTS REVIEWED**: All outputs from PART 1 have been generated and reviewed
- [ ] **CONTEXT CARRIED FORWARD**: Key findings from PART 1 are available for reference

**EXECUTION PROTOCOL:**
1. **VERIFY PART 1 COMPLETION**: Ensure all PART 1 tasks are finished
2. **START PART 2**: Begin with this file (PART 2)
3. **COMPLETE ALL TASKS** in PART 2 fully before proceeding
4. **ONLY AFTER** PART 2 is 100% complete, proceed to PART 3
5. **DO NOT** jump ahead or skip parts - each part builds on the previous

**WHY SEQUENTIAL?**
- Maintains 500-line context window per part
- Ensures complete understanding before moving forward
- Prevents context overflow and incomplete reviews
- Each part is self-contained but builds on previous work

**VERIFICATION CHECKLIST:**
- [ ] All PART 1 tasks completed (prerequisite)
- [ ] All PART 2 tasks completed
- [ ] All PART 2 outputs generated
- [ ] Ready to proceed to PART 3

**ONLY PROCEED TO PART 3 WHEN ALL PART 2 TASKS ARE COMPLETE.**

---

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

