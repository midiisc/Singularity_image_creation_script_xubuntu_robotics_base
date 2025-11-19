# LIBRARY ANALYSIS TOOL - MASTER ENTRY POINT

**AUTHORITATIVE SOURCE**: This file (`Library-Analysis-Tool.md`) is the **master entry point** for the Library Analysis Tool. It orchestrates sequential processing across all parts while maintaining 500-line context limits.

**🚨 MANDATORY PRE-REVIEW TASK COMPLETION CHECK (BEFORE STARTING ANALYSIS)**:
- **BEFORE LOADING PART 1A**: You MUST check for any earlier pending tasks from previous sessions, conversations, or incomplete work.
- **PENDING TASK HANDLING**: 
  - If any pending tasks are found, you MUST either:
    1. Complete them immediately before starting the analysis, OR
    2. Add them to the comprehensive todo list that will be created for this analysis
  - Do NOT start the analysis process until all earlier pending tasks are either completed or integrated into the current todo list.
- **TASK SOURCES TO CHECK**:
  - Previous conversation history and incomplete todos
  - Any uncommitted changes that need review or completion
  - Any pending file modifications or corrections
  - Any incomplete validation or testing tasks
  - Any pending documentation or cleanup tasks
- **VERIFICATION REQUIRED**: Before proceeding to "MANDATORY EXECUTION PROTOCOL", verify that:
  - All earlier pending tasks are identified
  - All identified tasks are either completed or added to the comprehensive todo list
  - No tasks are left unaccounted for
- **ONLY AFTER VERIFICATION**: Proceed to create the comprehensive todo list and begin PART 1A analysis.

**SEQUENTIAL PROCESSING ARCHITECTURE**:
This tool is split into multiple parts (each under 500 lines) to maintain full context throughout the analysis process. When this file is referenced, ALL parts MUST be processed sequentially:

1. **PART 1A**: `Library-Analysis-Tool-PART1A.md` (Executable Bash Script, first half)
2. **PART 1B**: `Library-Analysis-Tool-PART1B.md` (Executable Bash Script, second half)
3. **PART 2**: `Library-Analysis-Tool-PART2.md` (How to Use, Agent-Facing Prompt Flow)
4. **PART 3A**: `Library-Analysis-Tool-PART3A.md` (Complete Workflow, Integration, first half)
5. **PART 3B**: `Library-Analysis-Tool-PART3B.md` (Complete Workflow, Integration, second half)

**MANDATORY EXECUTION PROTOCOL FOR AI AGENTS**:
When this master entry point is referenced, you MUST:

0. **PRE-REVIEW TASK CHECK (MANDATORY FIRST STEP)**: Before starting the analysis, check for any earlier pending tasks (see "🚨 MANDATORY PRE-REVIEW TASK COMPLETION CHECK" section above). Complete them or add them to the comprehensive todo list. Only proceed after all earlier pending tasks are accounted for.
1. **LOAD PART 1A FIRST**: Read `prompts/Library-Analysis-Tool-PART1A.md` completely
2. **PROCESS ALL TASKS IN PART 1A**: Execute all executable bash script tasks from PART 1A
3. **ONLY AFTER PART 1A COMPLETE**: Load `prompts/Library-Analysis-Tool-PART1B.md`
4. **PROCESS ALL TASKS IN PART 1B**: Execute all executable bash script tasks from PART 1B
5. **ONLY AFTER PART 1B COMPLETE**: Load `prompts/Library-Analysis-Tool-PART2.md`
6. **PROCESS ALL TASKS IN PART 2**: Execute all usage and agent-facing prompt flow tasks from PART 2
7. **ONLY AFTER PART 2 COMPLETE**: Load `prompts/Library-Analysis-Tool-PART3A.md`
8. **PROCESS ALL TASKS IN PART 3A**: Execute all workflow and integration tasks from PART 3A
9. **ONLY AFTER PART 3A COMPLETE**: Load `prompts/Library-Analysis-Tool-PART3B.md`
10. **PROCESS ALL TASKS IN PART 3B**: Execute all remaining workflow and integration tasks from PART 3B
11. **POST-REVIEW TODO COMPLETION CHECK (MANDATORY)**: Perform final comprehensive check of ALL todos (see "🚨 MANDATORY POST-REVIEW TODO COMPLETION CHECK" section below). Complete any incomplete todos. Only proceed after ALL todos are marked as completed.
12. **FINAL CONFIRMATION**: Verify all components have been processed across all parts AND all todos are completed

**HARD ENFORCEMENT – SINGLE-PART MEMORY & 500-LINE CHUNKING**:
- Exactly one part (this master or one PART) may be loaded in memory at a time. Unload previous part content before loading the next; retain only a compact capsule (≤ 2KB) with status map, symbol names, and active chunk cursor.
- When analyzing code/scripts, split inputs into chunks of max 500 lines (target 450–500) with 20–40 line overlaps. Process chunks in order; for each chunk: execute tasks fully, apply fixes, and re-run checks until PASS/N/A before moving on.
- If A–P checklist checks are required, invoke `prompts/Code_check_prompt_manual.txt` and honor its sequential (PART1→PART2→PART3→PART4), single-part memory, and chunking rules.

ONE-PART-AT-A-TIME ENFORCEMENT:
- STRICT: Execute one part at a time; do not interleave commands/analysis across parts.
- COMPLETE-IN-PART: Apply all fixes and generate all outputs for the current part before advancing.
- RE-VALIDATE: Re-run the current part’s checks to confirm PASS/N/A after corrections and artifact generation.
- CARRY FORWARD: Persist generated artifacts (JSON, manifests, summaries) for consumption by subsequent parts.
- BLOCK NEXT PART until the current part is fully completed and re-validated.

**CONTEXT MANAGEMENT**:
- Each part is processed independently with full context (under 500 lines each)
- Script components and cross-references maintained across parts (as documented in each part)
- No components skipped - sequential processing ensures complete analysis coverage
- Each part references previous parts for continuity

**USAGE FOR USERS**:
- **Single entry point**: Reference `prompts/Library-Analysis-Tool.md` (this file)
- **Automatic sequential processing**: AI agents automatically load and process all parts in sequence
- **Full coverage guaranteed**: All components and workflows are processed without missing any
- **Context limits maintained**: Each part stays under 500 lines for optimal context window usage

**FOR TOOL INTEGRATION**:
- **Python scripts**: Load this master file, then sequentially read PART1A → PART1B → PART2 → PART3A → PART3B
- **Shell scripts**: Reference this master file, tooling should handle sequential loading
- **Pre-commit hooks**: Load this master file, process all parts sequentially
- **CI/CD**: Reference this master file, validate across all parts sequentially

**MANDATORY FOR ALL LIBRARY ANALYSES**: 
- ALL library analyses MUST reference this master entry point
- This master file MUST be enhanced FIRST when new analysis patterns are discovered
- All components and workflows MUST be processed sequentially across all parts - do not skip any
- Pattern learning updates MUST be added to the appropriate PART file FIRST before being referenced elsewhere

**VERIFICATION**:
After processing all parts, confirm:
- ✅ PART 1A processed (Executable Bash Script, first half)
- ✅ PART 1B processed (Executable Bash Script, second half)
- ✅ PART 2 processed (How to Use, Agent-Facing Prompt Flow)
- ✅ PART 3A processed (Complete Workflow, Integration, first half)
- ✅ PART 3B processed (Complete Workflow, Integration, second half)
- ✅ All components checked sequentially without skipping any

**🚨 MANDATORY POST-REVIEW TODO COMPLETION CHECK (BEFORE FINALIZING)**:
- **AFTER ALL PARTS COMPLETE**: You MUST perform a final comprehensive check of ALL todos before finalizing the analysis.
- **TODO VERIFICATION REQUIRED**:
  - Review the comprehensive todo list created at the beginning
  - Verify that EVERY single todo item is marked as "completed"
  - Check for any todos that may have been marked as "pending", "in_progress", or "cancelled"
  - Identify any todos that were added during the analysis process but not yet completed
- **INCOMPLETE TODO HANDLING**:
  - If ANY todo remains incomplete, pending, or in progress:
    1. **STOP finalization immediately**
    2. **Complete ALL incomplete todos** before proceeding
    3. **Re-verify** that all todos are marked as completed
    4. **Only then** proceed to final confirmation
  - Do NOT finalize the analysis if any todos are incomplete
  - Do NOT leave any todos for "later" or "future" completion
- **FINAL TODO CHECKLIST**:
  - ✅ All PART 1A tasks (Executable Bash Script, first half) - todos completed
  - ✅ All PART 1B tasks (Executable Bash Script, second half) - todos completed
  - ✅ All PART 2 tasks (How to Use, Agent-Facing Prompt Flow) - todos completed
  - ✅ All PART 3A tasks (Complete Workflow, Integration, first half) - todos completed
  - ✅ All PART 3B tasks (Complete Workflow, Integration, second half) - todos completed
  - ✅ Final confirmation task - todo completed
  - ✅ Any earlier pending tasks (from pre-review check) - todos completed
  - ✅ Any tasks added during analysis process - todos completed
- **ZERO TOLERANCE**: If even ONE todo is incomplete, the analysis is NOT complete. Continue working until ALL todos are fully completed.
- **ONLY AFTER ALL TODOS COMPLETE**: Proceed to final confirmation and mark the analysis as complete.

---

**PART FILES REFERENCE**:
- `prompts/Library-Analysis-Tool-PART1A.md` - Executable Bash Script, first half
- `prompts/Library-Analysis-Tool-PART1B.md` - Executable Bash Script, second half
- `prompts/Library-Analysis-Tool-PART2.md` - How to Use, Agent-Facing Prompt Flow
- `prompts/Library-Analysis-Tool-PART3A.md` - Complete Workflow, Integration, first half
- `prompts/Library-Analysis-Tool-PART3B.md` - Complete Workflow, Integration, second half

**SEQUENTIAL CHECKING ENFORCED**: Process parts in order (PART1A → PART1B → PART2 → PART3A → PART3B). Do not skip or merge parts.

**INTEGRATION WITH OTHER PROMPTS**:
- This tool is referenced by `prompts/Code_check_prompt_manual.txt` (section M12, PART3)
- This tool can be used in conjunction with `prompts/Advanced-CoT-Multi-Agent-Prompt.md` for comprehensive analysis
- Sequential processing: Load required prompt parts, then load this tool parts as needed

