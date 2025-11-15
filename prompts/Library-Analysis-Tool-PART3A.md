# Library Documentation & Flag Extraction Tool - PART 3
## Automated Analyzer + AI Prompt Integration

**This is PART 3 of 3. See also:**
- `Library-Analysis-Tool-PART1.md` - Part 1 (Executable Bash Script)
- `Library-Analysis-Tool-PART2.md` - Part 2 (How to Use, Agent-Facing Prompt Flow)

---

## 🚨 MANDATORY SEQUENTIAL EXECUTION INSTRUCTIONS

**CRITICAL: This is a multi-part prompt designed to maintain 500-line full context limits.**

**PREREQUISITE CHECK:**
- [ ] **PART 1 COMPLETED**: All tasks in PART 1 must be 100% complete
- [ ] **PART 2 COMPLETED**: All tasks in PART 2 must be 100% complete
- [ ] **PART 1 & 2 OUTPUTS REVIEWED**: All outputs from previous parts have been generated and reviewed
- [ ] **CONTEXT CARRIED FORWARD**: Key findings from PART 1 and PART 2 are available for reference

**EXECUTION PROTOCOL:**
1. **VERIFY PART 1 & 2 COMPLETION**: Ensure all previous parts are finished
2. **START PART 3**: Begin with this file (PART 3 - FINAL PART)
3. **COMPLETE ALL TASKS** in PART 3 fully
4. **FINAL SYNTHESIS**: Combine all findings from PART 1, PART 2, and PART 3

**WHY SEQUENTIAL?**
- Maintains 500-line context window per part
- Ensures complete understanding before moving forward
- Prevents context overflow and incomplete reviews
- Each part is self-contained but builds on previous work

**VERIFICATION CHECKLIST:**
- [ ] All PART 1 tasks completed (prerequisite)
- [ ] All PART 2 tasks completed (prerequisite)
- [ ] All PART 3 tasks completed
- [ ] All PART 3 outputs generated
- [ ] Final synthesis complete

**THIS IS THE FINAL PART - COMPLETE ALL TASKS HERE.**

---

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

---

**SEQUENTIAL CHECKING ENFORCED**: This is PART 3A of PART 3. After completing this part, continue with PART 3B: `Library-Analysis-Tool-PART3B.md`. This completes the Library Analysis Tool.
