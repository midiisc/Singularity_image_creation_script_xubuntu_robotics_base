# Library Documentation & Flag Extraction Tool - PART 3B

**SEQUENTIAL CHECKING ENFORCED**: This is PART 3B of PART 3 (FINAL). You MUST have completed PART 1, PART 2, and PART 3A before starting this part. This completes the Library Analysis Tool.

---

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
