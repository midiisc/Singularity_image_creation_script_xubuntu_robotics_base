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
2. **MANDATORY VERSION RESOLUTION** (STRICTLY ENFORCED):
   a. `TARGET_REF` (explicit user override - only if user explicitly requests)
   b. **Version pinned in `config.sh` (MANDATORY if available)** - This ensures correct supported flags for the pinned version are documented, not just the latest version
   c. **Latest stable release tag (ONLY if version not pinned)** - Excludes RC/beta/alpha/snapshot tags
   d. **NEVER use latest git snapshot** - Only stable releases
   
   **CRITICAL**: The script will FAIL if config.sh specifies a version that doesn't exist in the repository.
   This is intentional to ensure version accuracy. Verify config.sh version matches available tags.
   
   When running the script, the script automatically enforces this priority. Do NOT override with --ref unless user explicitly requests it.
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
- **MANDATORY**: Always use version pinned in config.sh if available (ensures correct flags documented for that version)
- **STRICTLY ENFORCED**: Only fall back to latest stable release if version NOT pinned in config.sh
- **NEVER**: Use latest git snapshot - only stable releases
- Handle errors robustly. Re-run the script with diagnostic logging if initial analysis fails.
- If config.sh version is specified but tag doesn't exist, script will fail with clear error message
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

**Two Documentation Paths Available:**

#### Path 1: Standard Documentation (Existing)
```
[In Claude/Cursor Composer, use the Advanced-Library-Documentation-Prompt from [260]]

Paste the full prompt [260]

Then paste the contents of \`flags_documentation.md\` (or the combined artefact) at the end:

"Here is the consolidated flag documentation from the repository analysis:

[PASTE EXTRACTED DATA HERE]

Now, using the agent framework in the prompt above, generate comprehensive documentation 
with all flags categorized, dependencies mapped, versions detected, and examples provided."
```

#### Path 2: Comprehensive 5-Phase Analysis (Enhanced - RECOMMENDED)
```
[In Claude/Cursor Composer, use Comprehensive-Flag-Analysis-Prompt.md]

Paste the full prompt from prompts/Comprehensive-Flag-Analysis-Prompt.md

Then paste the preprocessing data:

"Here is the preprocessing data from analyze-library.sh:

[PASTE preprocessing_data.json OR flags_documentation.md]

Now, following the 5-phase protocol (Discovery → Preprocessing → Deep Analysis → 
Multi-Pass Validation → Documentation Generation), generate comprehensive flag 
documentation with >=95% completeness target. Use the Mixture of Reasoning Experts 
architecture (Configuration Expert, Dependency Expert, Version Expert, Documentation Expert)."
```

**When to Use Each Path:**
- **Path 1**: Standard analysis, quick turnaround, basic flag extraction
- **Path 2**: Comprehensive analysis, research-grade documentation, version-aware tracking, historical evolution analysis (RECOMMENDED for production use)

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
│   * Uses version from config.sh (MANDATORY)│
│   * Falls back to latest stable release   │
│   * NEVER uses git snapshot               │
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

**This Bash Script + Prompt Integration**: Automatically downloads repo, analyzes files (CMake, C++, headers), extracts flags/versions, outputs structured data, feeds to AI prompt, generates comprehensive documentation.

**Usage**: Copy Agent Prompt Template, set `TARGET_LIBRARY`, send to Cursor/Claude – agent generates scripts, runs analysis, returns documentation automatically. **Complete working solution** that automates the entire process!
