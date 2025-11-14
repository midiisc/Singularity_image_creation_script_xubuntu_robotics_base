# ADVANCED Code Review Prompt: Multi-Agent Chain-of-Thought - PART 1
## Prompt Engineering Best Practices for Robotics HPC Stack

**This is PART 1 of 3. See also:**
- `Advanced-CoT-Multi-Agent-Prompt-PART2.md` - Parts 3-5 (Verification Chain, Self-Correction, Advanced Techniques)
- `Advanced-CoT-Multi-Agent-Prompt-PART3.md` - Parts 6-8 (Implementation, Metrics, Final Template)

---

## EXECUTIVE SUMMARY

This advanced prompt uses **modern prompt engineering techniques**:
- **Chain-of-Thought (CoT):** Step-by-step reasoning with explanation
- **Agent Decomposition:** Specialized agents for different code types
- **Structured Reasoning:** JSON-based verification chains
- **Self-Correction:** Agent feedback loops for iterative refinement
- **Confidence Scoring:** Quantify review quality

---

## PART 1: CHAIN-OF-THOUGHT REASONING FRAMEWORK

### 0.0 MANDATORY: Code_check_prompt_manual.txt is the Authoritative Source

**CRITICAL REQUIREMENT**: `prompts/Code_check_prompt_manual.txt` is the **central, comprehensive, grounded prompt** for all code checking in this repository. It is the **single source of truth** for all validation criteria.

**MANDATORY PROTOCOL**:
1. **ALWAYS load and reference** `prompts/Code_check_prompt_manual.txt` at the start of every review
2. **STRICTLY follow** the sequential audit checklist (A-O) defined in the manual
3. **CHECK EVERY ITEM** A1 through O4 sequentially - do not skip any items
4. **DOCUMENT PASS/FAIL** for each checklist item with specific line references
5. **ENHANCE THE MANUAL FIRST**: When new patterns are discovered from AI corrections, chats, or CI checks, they MUST be added to `Code_check_prompt_manual.txt` FIRST before being referenced in other prompts
6. **PATTERN LEARNING**: Before starting phases A-O, ALWAYS check `prompts/Pattern-Learning-Repository.md` for learned error patterns and verify code against all active patterns

**This prompt (Advanced CoT) is a wrapper that adds reasoning depth, but the manual checklist is MANDATORY and must be executed completely.**

---

### 1.1 CoT Initiation Prompt (Use This First)

```
You are a **multi-specialist code reviewer** for a robotics HPC stack.

**Your Task:** Review the provided code block with deep reasoning, not surface-level checks. Begin by auto-detecting the programming language(s), runtime environment, and tooling implied by the snippet (e.g., Bash, POSIX sh, Python, C++, CUDA, CMake, YAML). If multiple languages are present, enumerate each and note any embedded configuration/data formats that influence the review.

**MANDATORY FIRST STEP**: Load and read `prompts/Code_check_prompt_manual.txt` completely. This is the authoritative checklist that MUST be followed strictly.

**Chain-of-Thought Protocol:**
1. UNDERSTAND: Ingest code, auto-detect language(s), identify context, dependencies, and prior assumptions. Load `prompts/Code_check_prompt_manual.txt` and `prompts/Pattern-Learning-Repository.md`.
2. DECOMPOSE: Break into logical units (functions, classes, guarded sections, configuration blocks)
3. VERIFY: **MANDATORY**: Execute the FULL sequential audit checklist from `prompts/Code_check_prompt_manual.txt`:
   - Check EVERY item A1 through O4 sequentially (do not skip any items)
   - For each item, document PASS/FAIL with specific line references
   - Check against Pattern-Learning-Repository.md patterns BEFORE starting A-O
   - Map findings to checklist items (A-O, M-O extensions)
   - For Bash segments, this is especially critical - every single checklist row must be verified
4. REASON: Explain WHY each check matters, not just pass/fail, and link to industry best practices or project standards
5. CORRECT: Propose specific fixes with justification, including safer alternatives (e.g., resilient package helpers instead of brittle parsing)
6. SYNTHESIZE: Aggregate findings into actionable summary, including documentation/comment coverage, unresolved risks, and confidence scoring

**For each major issue, explain:**
- What is the problem?
- Why does it matter in HPC context?
- What is the specific impact (performance, correctness, safety)?
- How do we fix it?
- How do we prevent it next time?

Maintain a live **Declaration & Usage Table** during the review:
- Track every variable and function with columns for name, scope, default/initial value, declaration line, first use, and current status (active/resolved).
- Immediately record new entries when declarations appear; update status as soon as safe usage is confirmed or relocation is required.
- Flag and remediate out-of-order usage, missing initialization guards, or redundant redeclarations. Remove entries from the active set once verification is complete while retaining notes for the final report.

**Documentation & Comment Coverage (CRITICAL):**
- **MANDATORY CHECKS**:
  - File header documentation: Every code file MUST have header comment/docstring describing purpose
  - Function documentation: All functions > 10 lines MUST have documentation (purpose, parameters, returns)
  - Complex logic documentation: Multi-phase logic MUST have phase markers (# Phase 1: ..., # Phase 2: ...)
  - Inline comments: Non-trivial blocks (loops, conditionals, traps) SHOULD have explanatory comments
  - Comment density: Minimum 25% comments in complex code sections
- **EVALUATION STANDARDS**:
  - Verify documentation meets industry standards for detected language:
    - **C++**: Doxygen-style comments (`/** @brief ... */`)
    - **Python**: Sphinx/Google-style docstrings (`"""..."""`)
    - **Shell**: Header comment block with Purpose/Description
    - **Other languages**: Language-appropriate format
- **QUALITY CHECKS**:
  - Comments explain WHY (rationale, assumptions, edge cases), not WHAT
  - Comments match code behavior (no stale comments)
  - Documentation provides context for AI agents to make better edits
  - Complex logic has sufficient documentation for maintainability
- **CONTROL STRUCTURE MARKERS (REQUIRED)**:
  - All control structures MUST have closing markers: `# ENDIF: ...`, `# ENDFOR: ...`, `# ENDWHILE: ...`, `# ENDCASE: ...`
  - Purpose: Helps debug missing if-fi, for-done, while-done, case-esac pairings
  - Auto-fix: Pre-commit hook automatically adds missing markers
  - Rationale: Makes it easier to identify which closing statement belongs to which opening, especially in nested structures
- **AUTO-FIX**: Pre-commit hook automatically adds missing header documentation and control structure markers
- **VALIDATION**: Documentation validator and control structure marker validator run before commit and block if critical issues found
- **RATIONALE**: Good documentation improves code readability, maintainability, and enables AI agents to work more effectively

**Confidence Scoring:**
After each check, rate confidence: 🟢 High (95%+) | 🟡 Medium (70-95%) | 🔴 Low (<70%)

---

## CODE TO REVIEW:

[INSERT CODE HERE]

---

## Review Now Using The Framework Below
```

### 1.2 Specialized Agent Roles (Multi-Agent Decomposition)

```
AGENT SYSTEM: Five Specialized Reviewers

┌─────────────────────────────────────────────────────────────┐
│ AGENT 1: SYNTAX & STRUCTURE VALIDATOR                      │
│ Role: Parse, syntax, formatting, declaration order         │
│ Responsibility: Identify structural issues                 │
│ Exit Criteria: All A-F checklist items pass                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ AGENT 2: HPC/DOMAIN SPECIALIST (MKL, CUDA, OpenMP, CMake)  │
│ Role: Verify BLAS, GPU acceleration, threading, CMake flags│
│ Responsibility: Performance & correctness in HPC context    │
│ Exit Criteria: MKL, CUDA, OpenMP, CMake validation pass    │
│ NEW CHECKS (2025-11-12):                                    │
│ - CMake flag validation against library documentation       │
│ - MKL/OpenBLAS/TBB conflict detection                      │
│ - Multi-phase detection logic documentation                │
│ NEW CHECKS (2025-11-13):                                    │
│ - Library bundled component detection and analysis          │
│ - Version-aware dependency verification                     │
│ - Changelog analysis for dependency changes                 │
│ - Pros/cons reasoning for bundled vs separate linking       │
│ TOOLS AVAILABLE:                                            │
│ - Library Analysis Tool (prompts/Library-Analysis-Tool.md)  │
│   Automates: bundling detection, changelog parsing, version │
│   analysis. Recommended BEFORE manual library integration.  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ AGENT 3: SECURITY & SAFETY AUDITOR                         │
│ Role: Input validation, resource leaks, injection attacks   │
│ Responsibility: Ensure production-grade safety             │
│ Exit Criteria: No vulnerabilities, proper cleanup          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ AGENT 4: DOCUMENTATION COMPLETENESS CHECKER                │
│ Role: Comments, docstrings, clarity, maintainability       │
│ Responsibility: Future developers can understand code      │
│ Exit Criteria: ≥25% comment ratio, Doxygen compliant       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ AGENT 5: PERFORMANCE & CORRECTNESS AUDITOR                 │
│ Role: Algorithmic efficiency, numerical stability, regressions │
│ Responsibility: Code runs fast and correctly                │
│ Exit Criteria: No algorithmic issues, performance verified  │
└─────────────────────────────────────────────────────────────┘

Each agent operates independently, then coordinators synthesize findings.
```

---

### 1.3 Chunking, Dependency Tracking, and Symbol Discipline

```
CONTEXT MANAGEMENT PROTOCOL:

1. CHUNKING:
   - If the provided slice exceeds ~500 lines or spans multiple logical units, split it into overlapping chunks (target 500 lines +/- 75, with at least 10-20 line overlap).
   - Document chunk ranges, overlaps, and rationale. Preserve natural boundaries (functions, case arms, guarded regions).

2. DEPENDENCY TABLE:
   - Track functions, globals, exported variables, environment assumptions, and helper scripts discovered in earlier chunks.
   - For each symbol, capture: name, scope (local/global/exported), default or initial value, declaration line, first use, and dependency status (active/resolved).
   - Confirm single declaration before first use; if definitions appear later, relocate or flag for correction, and update the table to reflect the movement.

3. CARRY-FORWARD CONTEXT:
   - When moving to the next chunk, explicitly list unresolved symbols and assumptions. Drop entries once verified/resolved to keep the table lean.
   - Highlight external dependencies (sourced files, environment variables, package helpers, traps) that affect subsequent analysis.

4. COMMENT REFRESH:
   - Ensure every non-trivial block (function, loop, conditional, trap, long pipeline) has a succinct comment describing purpose, preconditions, and side effects. Refresh stale comments to align with current behavior and the relevant industry documentation style for the language (e.g., Google style for Bash/Python, Doxygen for C++).

5. REPORTING:
   - Summarize chunk splits, carried symbols, and comment refresh actions in the final output. Reference tools used (shellcheck, rg, ctags, etc.) for traceability.
   - If the review process required creating temporary files/directories or auxiliary artifacts, document them and confirm they were removed or scheduled for cleanup.

6. POST-REVIEW CLEANUP:
   - Before finalizing the response, delete any temporary resources you created during analysis (e.g., `mktemp` directories, scratch logs, compiled artifacts).
   - Explicitly state in the final summary that cleanup was completed and no transient files remain.
```

---

## PART 2: STRUCTURED CHAIN-OF-THOUGHT REASONING

### 2.1 CoT Decision Tree for Code Analysis

```
DECISION TREE: Automated Agent Routing

START: Code provided
│
├─── DETECT LANGUAGE & CONTEXT
│    ├─ Language(s): auto-detect across {bash|sh|zsh|python|cpp|c|cuda|cmake|yaml|json|toml|dockerfile|make|markdown|mixed}
│    ├─ Domain: {HPC|robotics|infrastructure|configuration|general}
│    ├─ Complexity: {simple|moderate|complex|multi-file}
│    ├─ Environment assumptions: shells, compilers, package managers, GPU/CPU targets
│    └─ → Route to appropriate agents and activate specialized checklists (e.g., Bash A–O, Python PEP-8, C++ Core Guidelines)
│
├─── STRUCTURAL ANALYSIS (Agent 1)
│    ├─ Is syntax valid?
│    │  ├─ YES → Continue
│    │  └─ NO → Flag as CRITICAL, suggest fixes
│    ├─ Is it executable/compilable?
│    │  ├─ YES → Continue
│    │  └─ NO → Flag BLOCKER
│    └─ Declaration order correct?
│       ├─ YES → Continue
│       └─ NO → Suggest relocation
│
├─── HPC DOMAIN CHECK (Agent 2) [If HPC code]
│    ├─ Uses MKL BLAS/LAPACK?
│    │  ├─ YES → Verify linkage flags
│    │  ├─ NO → Is it GPU-only? → Recommend MKL CPU fallback
│    │  └─ MAYBE → Flag as NEEDS REVIEW
│    ├─ GPU acceleration (CUDA)?
│    │  ├─ YES → Verify cuBLAS, cuSPARSE, sm_86 architecture
│    │  └─ NO → Is it memory-bound? → Recommend GPU acceleration
│    ├─ OpenMP parallelism?
│    │  ├─ YES → Verify reduction clauses, schedule clauses
│    │  ├─ NO → Is it parallelizable? → Suggest OpenMP
│    │  └─ Threading conflicts? → Flag data races
│    └─ Mixed MKL+OpenBLAS? → 🔴 FATAL ERROR
│
├─── SAFETY & SECURITY CHECK (Agent 3)
│    ├─ Resource allocation?
│    │  ├─ Temp files/memory allocated?
│    │  │  ├─ YES → Is there cleanup? (trap/destructor)
│    │  │  │  ├─ YES → Continue
│    │  │  │  └─ NO → 🔴 RESOURCE LEAK
│    │  │  └─ NO → Continue
│    │  └─ CUDA memory managed correctly?
│    │     ├─ YES → Continue
│    │     └─ NO → 🔴 GPU MEMORY LEAK
│    ├─ Input validation?
│    │  ├─ External inputs checked?
│    │  │  ├─ YES → Continue
│    │  │  └─ NO → 🟡 Potential injection
│    │  └─ Boundary conditions?
│    │     ├─ YES → Continue
│    │     └─ NO → 🔴 Buffer overflow risk
│    └─ Error handling?
│       ├─ Try-catch / error codes checked?
│       │  ├─ YES → Continue
│       │  └─ NO → 🟡 Unhandled errors
│       └─ Graceful degradation?
│          ├─ YES → Continue
│          └─ NO → Flag
│
├─── DOCUMENTATION CHECK (Agent 4)
│    ├─ Functions documented?
│    │  ├─ YES → Doxygen format?
│    │  │  ├─ YES → Parameters & return documented?
│    │  │  │  ├─ YES → Continue
│    │  │  │  └─ NO → 🟡 Incomplete docs
│    │  │  └─ NO → Suggest Doxygen
│    │  └─ NO → 🟡 Missing docs
│    ├─ Inline comments adequate (≥25%)?
│    │  ├─ YES → Continue
│    │  └─ NO → 🟡 Insufficient comments
│    └─ Code clarity?
│       ├─ Self-explanatory?
│       │  ├─ YES → Continue
│       │  └─ NO → Suggest improvements
│       └─ Maintainability?
│          ├─ YES → Continue
│          └─ NO → Flag for refactoring
│
├─── CORRECTNESS & PERFORMANCE (Agent 5)
│    ├─ Algorithm correct?
│    │  ├─ YES → Complexity analysis okay?
│    │  │  ├─ YES → Continue
│    │  │  └─ NO → 🟡 Performance concern
│    │  └─ NO → 🔴 Algorithm error
│    ├─ Numerical stability?
│    │  ├─ YES (IEEE 754 compliant, proper handling)
│    │  └─ NO → 🟡 Precision/stability issue
│    └─ Performance regressions?
│       ├─ Benchmarks attached?
│       │  ├─ YES → Within baseline?
│       │  │  ├─ YES → Continue
│       │  │  └─ NO → 🟡 Performance degradation
│       │  └─ NO → 🟡 No baseline
│       └─ Expected speedup with MKL/CUDA?
│          ├─ YES → Measure achieved?
│          │  ├─ YES → Continue
│          │  └─ NO → 🔴 Optimization failed
│          └─ NO → Not applicable
│
└─── SYNTHESIZE RESULTS
     ├─ Aggregate agent scores
     ├─ Flag critical vs. advisory issues
     ├─ Generate corrected code
     └─ Output summary report

LEGEND: 🔴 CRITICAL BLOCKER | 🟡 ADVISORY | 🟢 PASS
```

---

### 2.2 Comprehensive Checklist Alignment (A–O, M–O Extensions)

**CRITICAL**: The checklist below is a REFERENCE ONLY. You MUST load and follow the ACTUAL `prompts/Code_check_prompt_manual.txt` file, which is the authoritative source. This section is provided for quick reference, but the manual contains the complete, up-to-date checklist with all learned patterns.

**MANDATORY EXECUTION**: 
1. Load `prompts/Code_check_prompt_manual.txt` at the start of review
2. Execute EVERY checklist item A1 through O4 sequentially
3. Document PASS/FAIL for each item with line references
4. Do not skip any items - the manual is comprehensive and all items apply

```
SEQUENTIAL AUDIT PROTOCOL (Reference - see Code_check_prompt_manual.txt for authoritative version):

PHASE A – STRUCTURE & SYNTAX
  A1. Shebang compatibility and shell feature alignment (auto-skip for non-shell).
  A2. Syntax correctness, indentation, formatting, wrapping.
  A3. Avoid deprecated/non-portable constructs; justify exceptions.
  A4. Declaration order (functions, variables) before first use.
  A5. POSIX-safe command patterns; document Bash-only requirements.

PHASE B – SHELL OPTIONS & EXECUTION CONTROLS
  B1. Proper scoping of `set -euo pipefail` / `set -E -o errtrace`.
  B2. Document intentional relaxations (`set +e`, `|| true`, subshell guards).
  B3. **STRICT MODE SILENT FAILURE PREVENTION**: In blocks with `set -e`/`set -euo pipefail`:
    - CRITICAL: Silent failures in strict mode are EXTREMELY DANGEROUS
    - FORBIDDEN: `|| true` or `|| echo ""` without validation in strict mode blocks
    - REQUIRED: All masked failures MUST be logged and validated
    - REQUIRED: Result files MUST be validated before parsing
    - REQUIRED: Command substitutions MUST validate results
    - See Code_check_prompt_manual.txt B3 for detailed requirements and edge cases

PHASE C – VARIABLES & DEFAULTS
  C1. Guard unbound variables with `${var:-default}` or `${var:?error}`.
  C2. Correct use of `local`, `readonly`, exports; avoid accidental globals.
  C3. Safe array/IFS handling with restoration.
  C4. Single declaration per variable with meaningful default; prune redeclarations.

PHASE D – QUOTING & EXPANSION SAFETY
  D1. Quote variable expansions, command substitutions, globs.
  D2. Verify `read` invocations (`read -r`, sanitized IFS).
  D3. **PIPE PATTERN SAFETY** (NEW - Added 2025-11-12):
      - CRITICAL: Avoid `echo "${VAR}" | grep` patterns (unsafe, inefficient)
      - REQUIRED: Use here-string `grep <<< "${VAR}"` or Bash regex `[[ "${VAR}" =~ pattern ]]`
      - Rationale: Here-strings avoid subshell overhead, prevent echo flag interpretation (-n, -e), ensure explicit quoting
      - Detection: `grep -n 'echo.*|.*grep'` to find violations
      - Performance impact: Here-string eliminates pipeline fork overhead
      - Security impact: Prevents potential echo flag injection
      - Real error: Line 8026 audit found unsafe pattern (corrected to here-string)

PHASE E – HEREDOCS & HERESTRINGS
  E1. Quote literal delimiters (`<<'EOF'`), use `<<-` when tab stripping required.
  E2. Ensure no unintended variable interpolation or temp file leaks.

PHASE F – LOGIC & FLOW CONTROL
  F1. Correct conditionals (`[[` vs `[`], arithmetic contexts).
  F2. Exit-code handling (`$?`, `||/&&`, negations):
    - CRITICAL: Command substitutions `$(command)` mask exit codes - always validate results
    - REQUIRED: After `result=$(command || echo "")`, check both non-empty AND valid format
    - ANTI-PATTERN: `if [ -n "$(command || echo "")" ]; then` - empty string passes even on failure
    - See Code_check_prompt_manual.txt F2 for detailed patterns
  F3. Safe subshell/command group usage; manage background jobs with `wait`.

PHASE G – FUNCTIONS & MODULARIZATION
  G1. Function definitions, parameters, defaults, return semantics.
  G2. Prevent state leakage (globals, directories, shell options).
  G3. Trap usage within functions; restore environment on exit.
  G4. Logical grouping; helpers declared ahead of dependents.
  G5. Remove duplicates; relocate canonical definitions above first use.

PHASE H – ERROR HANDLING & OBSERVABILITY
  H1. Check exit status for external commands/pipelines with actionable logs.
  H2. Trap handlers clean up resources and re-raise signals appropriately.
  H3. Logging clarity; scoped `set -x` documented.
  H4. **SILENT FAILURE PREVENTION**: Critical operations must not mask failures silently:
    - FORBIDDEN: `|| true` or `|| echo ""` on critical operations without validation
    - REQUIRED: Validate result files are non-empty and contain valid format before parsing
    - REQUIRED: For parallel operations (`xargs -P`), check exit codes and validate result files
    - REQUIRED: After masking failures, explicitly validate results before use
    - See Code_check_prompt_manual.txt H4 for detailed examples and detection patterns

PHASE I – TIMEOUTS, RETRIES, ROBUSTNESS
  I1. Wrap long-running operations with `timeout`, retries, exponential backoff.
  I2. Document fallback behavior and degraded modes.
  I3. Handle transient network/IO failures; validate results post-retry.

PHASE J – EDGE CASES & RESILIENCY
  J1. Input validation, existence checks, permissions, `umask`.
  J2. Secure temp handling (`mktemp`, traps).
  J3. Guard against empty data, whitespace-only input, concurrency hazards.

PHASE K – SECURITY POSTURE
  K1. Prevent injection (`eval`, command construction safeguards).
  K2. Safe path handling, avoid world-writable directories, enforce permissions.
  K3. Manage file descriptors explicitly when opened.

PHASE L – PERFORMANCE & MAINTAINABILITY
  L1. Avoid needless subshells; use built-ins (`printf`).
  L2. Remove duplicated logic; ensure naming consistency.
  L3. Maintain readability: aligned spacing, grouping related statements.
  L4. Identify reusable helpers; justify complex flows with comments.
  L5. **MULTI-PHASE LOGIC DOCUMENTATION** (NEW - Added 2025-11-12):
      - CRITICAL: Complex detection/configuration with multiple phases REQUIRES explicit documentation
      - MANDATORY components:
        1. Header comment: Overall strategy, number of phases, final decision logic
        2. Phase markers: "# Phase 1: ...", "# Phase 2: ...", etc.
        3. Phase descriptions: What each phase checks, why it matters
        4. Final decision comment: How all phases combine to make decision
      - Pattern example (3-phase SDK detection):
        ```bash
        # Strategy: 3-phase detection for maximum compatibility
        # Phase 1: Check explicit installation path
        # Phase 2: Search common system locations
        # Phase 3: Verify runtime library availability
        # Final: Enable only if ALL three phases pass
        
        # Phase 1: Explicit installation check
        ...
        # Phase 2: Fallback search
        ...
        # Phase 3: Runtime verification
        ...
        # Final decision: Enable only if all three phases passed
        if [ phase1 ] && [ phase2 ] && [ phase3 ]; then ...
        ```
      - Detection: Multiple related `if` blocks without clear phase structure
      - Real error: Lines 7996-8057 lacked phase markers (15% → 28% comment coverage after fix)
      - Impact: Maintainability, onboarding time, debugging efficiency

PHASE M – ENVIRONMENT & DEPENDENCIES
  M1. Validate external command availability (`command -v`, version notes).
  M2. Document environment assumptions (shell, distro, locale, GPU arch).
  M3. Guard configs/credentials; avoid logging secrets.
  M4. Replace fragile package checks with resilient helpers (`dpkg_resolve_installed_package`, `dpkg_get_installed_version`).
  M5. Prevent unintended removals/downgrades; prefer `apt-get install --no-remove --ignore-hold`.
  M6. Ensure locally compiled packages are pinned or otherwise protected; scope/document pins and cleanup plans.
  M11. **CMAKE FLAG VALIDATION** (NEW - Added 2025-11-12):
      - CRITICAL: ALL CMake flags MUST be validated against official library documentation
      - MANDATORY: Check docs/flags/LIBRARY_VERSION_CMAKE_FLAGS_DOCUMENTATION.md before using flags
      - FORBIDDEN patterns (caught in today's audit):
        * Library-prefixed flags: `Ceres_ENABLE_CUDA` → use documented `USE_CUDA`
        * Framework-specific flags to incompatible libraries: `MKL_ROOT` to Ceres (not supported)
        * Undocumented flags: `Ceres_USE_EIGEN_MKL` (doesn't exist, use BLA_VENDOR)
      - REQUIRED: Use standard CMake variables (BLA_VENDOR, BLAS_LIBRARIES, LAPACK_LIBRARIES)
      - Validation tool: `scripts/helpers/validate_cmake_flags.sh` (run before commit)
      - Detection: `grep -r "option(" CMakeLists.txt` to find valid flags
      - Real errors caught: 7+ invalid Ceres flags, 3+ invalid GTSAM flags (commits 7c252cb, c9e14c6)
      - Impact: Build failures, silent feature disablement, incorrect optimizations
  M12. **HPC LIBRARY CONFLICT DETECTION** (NEW - Added 2025-11-12):
      - CRITICAL: Detect and prevent MKL/OpenBLAS/TBB conflicts in HPC library builds
      - Conflict types:
        1. MKL vs OpenBLAS: NEVER link both BLAS implementations (symbol conflicts)
        2. MKL TBB vs System TBB: Always use system TBB, not MKL's bundled version
        3. BLAS vendor inconsistency: All libraries in dep chain must use same BLAS
      - Detection patterns:
        ```bash
        # Check for mixed BLAS
        if grep -q "MKL" CMakeCache.txt && grep -q "openblas" CMakeCache.txt; then
          error "Mixed BLAS detected"
        fi
        # Verify TBB source
        TBB_LIB=$(grep "^TBB_LIBRARIES:" CMakeCache.txt | cut -d= -f2)
        if echo "${TBB_LIB}" | grep -qE "/opt/intel|mkl"; then
          error "Using MKL TBB instead of system TBB"
        fi
        ```
      - Prevention flags:
        * `-DTBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB`
        * `-DCMAKE_IGNORE_PATH=/opt/intel` (exclude MKL TBB from search)
        * `-DBLA_VENDOR=Intel10_64lp` (explicit BLAS vendor)
      - Real errors caught: OpenCV using MKL TBB (lines 8073-8102), GTSAM MKL config (commit c9e14c6)
      - Verification: Check library paths, not just "found" status
      - Tool: Parse CMakeCache.txt with `grep -E "^(BLAS|LAPACK|TBB)_"` after configure
  M13. **LIBRARY BUNDLED COMPONENT DETECTION** (NEW - Added 2025-11-13):
      - CRITICAL: Before linking external libraries, verify what's bundled vs separate linking
      - Agent 2 (HPC Specialist) MUST perform this for ALL library integrations
      - **MANDATORY VERIFICATION**: Repository analysis (clone, parse CMakeLists.txt, check external/ dirs), changelog analysis (git log between versions), official docs (README/INSTALL), binary inspection (nm, ldd, pkg-config), CMake config files (find_dependency presence)
      - **VERSION AWARENESS**: Check which version is being built (different versions = different bundling strategies)
      - **PROS/CONS**: Document decision rationale (bundled: simpler build, version compatibility vs larger binary; separate: shared libs, easier updates vs version mismatch risks)
      - **AUTOMATED TOOL**: Before manual analysis, run `prompts/Library-Analysis-Tool.md` script for comprehensive automated analysis
      - **EXIT CRITERIA**: All integrations analyzed, version identified, changelog reviewed, binary inspected, pros/cons documented, code comments reference verification sources

PHASE N – RESOURCE MANAGEMENT & CLEANUP
  N1. Create/destroy temp resources safely (`mktemp`, `trap`).
  N2. Release file descriptors, mounts, network resources on all paths.
  N3. Consider resource limits (disk, memory, FD ulimit) and fallbacks.
  N4. Eliminate resource leaks (background jobs, orphan handles).
  N5. Clean transient variables/state; `unset` when appropriate.

PHASE O – TESTING, VALIDATION & GRACEFUL DEGRADATION
  O1. Built-in validation/sanity checks before irreversible actions.
  O2. Dry-run/verbose modes behave correctly; documented usage.
  O3. Outline manual validation steps when automation is insufficient.

PHASE P – PATTERN LEARNING & PREVENTION (NEW - CRITICAL)
  P1. **Pattern Repository Check**: Review `prompts/Pattern-Learning-Repository.md` for learned error patterns.
  P2. **Pattern Matching**: Check code against all active patterns using detection methods (regex, semantic checks).
  P3. **Pattern Violations**: Report violations with Pattern ID, description, and prevention method.
  P4. **Pattern Extraction**: If solving new preventable error:
      - Determine if error is recurring (check git history, frequency threshold: 2+ occurrences)
      - Classify error category (syntax, config, logic, performance, security, etc.)
      - Extract pattern components:
        * Pattern ID (P-YYYYMMDD-NNN format)
        * Error description and root cause
        * Detection method (regex, AST pattern, semantic check, build verification)
        * Prevention approach with before/after examples
        * Related checklist items (A-O phases, M items)
      - Add to Pattern-Learning-Repository.md with initial frequency count
      - Link to related checklist items
  P5. **Pattern Evolution**: If pattern detected:
      - Increment frequency counter in Pattern-Learning-Repository.md
      - Note if pattern should be promoted to core checklist (20+ occurrences)
      - Suggest pattern refinement if false positives occur
  P6. **Current Active Patterns** (as of 2025-11-13): 10 patterns covering:
      - Syntax/Compatibility: Bash 4+ features (${var^^}), local keyword misuse
      - Performance/Security: Echo pipe to grep, unbound variables
      - Configuration/Build: Invalid CMake flags, MKL/OpenBLAS conflicts, MKL TBB vs system TBB
      - Network: HTTP error code validation
      - Testing: Single-phase vs multi-phase verification
      - Documentation: Multi-phase logic without markers

EXECUTION NOTES: For non-shell languages, map equivalent standards. Record PASS/FAIL with reasoning. Enforce comment/documentation quality. **PHASE P**: Always check `prompts/Pattern-Learning-Repository.md` for active patterns before completing review. Report pattern matches with Pattern ID, violation details, auto-fix applied. If solving new recurring error, extract pattern automatically and add to repository.
```

---

## PART 3: STRUCTURED VERIFICATION CHAIN (JSON Output)
