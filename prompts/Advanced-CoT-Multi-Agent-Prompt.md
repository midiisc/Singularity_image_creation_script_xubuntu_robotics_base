# ADVANCED CODE REVIEW PROMPT: MULTI-AGENT CHAIN-OF-THOUGHT - MASTER ENTRY POINT

**AUTHORITATIVE SOURCE**: This file (`Advanced-CoT-Multi-Agent-Prompt.md`) is the **master entry point** for the Advanced CoT Multi-Agent code review framework. It orchestrates sequential checking across all parts while maintaining 500-line context limits.

**🚨 MANDATORY PRE-REVIEW TASK COMPLETION CHECK (BEFORE STARTING REVIEW)**:
- **BEFORE LOADING PART 1**: You MUST check for any earlier pending tasks from previous sessions, conversations, or incomplete work.
- **PENDING TASK HANDLING**: 
  - If any pending tasks are found, you MUST either:
    1. Complete them immediately before starting the review, OR
    2. Add them to the comprehensive todo list that will be created for this review
  - Do NOT start the review process until all earlier pending tasks are either completed or integrated into the current todo list.
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
- **ONLY AFTER VERIFICATION**: Proceed to create the comprehensive todo list and begin PART 1 review.

**SEQUENTIAL PROCESSING ARCHITECTURE**:
This prompt is split into multiple parts (each under 500 lines) to maintain full context throughout the review process. When this file is referenced, ALL parts MUST be processed sequentially:

1. **PART 1**: `Advanced-CoT-Multi-Agent-Prompt-PART1.md` (CoT Framework, Structured Reasoning, Sections 0-2)
2. **PART 2A**: `Advanced-CoT-Multi-Agent-Prompt-PART2A.md` (Verification Chain, Sections 3-4)
3. **PART 2B**: `Advanced-CoT-Multi-Agent-Prompt-PART2B.md` (Self-Correction, Sections 5 partial)
4. **PART 3**: `Advanced-CoT-Multi-Agent-Prompt-PART3.md` (Implementation, Metrics, Final Template, Sections 6-8)

**MANDATORY EXECUTION PROTOCOL FOR AI AGENTS**:
When this master entry point is referenced, you MUST:

0. **PRE-REVIEW TASK CHECK (MANDATORY FIRST STEP)**: Before starting the review, check for any earlier pending tasks (see "🚨 MANDATORY PRE-REVIEW TASK COMPLETION CHECK" section above). Complete them or add them to the comprehensive todo list. Only proceed after all earlier pending tasks are accounted for.
1. **LOAD PART 1 FIRST**: Read `prompts/Advanced-CoT-Multi-Agent-Prompt-PART1.md` completely
2. **PROCESS ALL TASKS IN PART 1**: Execute all CoT framework tasks, structured reasoning, and sections 0-2 from PART 1
3. **ONLY AFTER PART 1 COMPLETE**: Load `prompts/Advanced-CoT-Multi-Agent-Prompt-PART2A.md`
4. **PROCESS ALL TASKS IN PART 2A**: Execute all verification chain tasks and sections 3-4 from PART 2A
5. **ONLY AFTER PART 2A COMPLETE**: Load `prompts/Advanced-CoT-Multi-Agent-Prompt-PART2B.md`
6. **PROCESS ALL TASKS IN PART 2B**: Execute all self-correction tasks and section 5 from PART 2B
7. **ONLY AFTER PART 2B COMPLETE**: Load `prompts/Advanced-CoT-Multi-Agent-Prompt-PART3.md`
8. **PROCESS ALL TASKS IN PART 3**: Execute all implementation, metrics, and final template tasks (sections 6-8) from PART 3
9. **POST-REVIEW TODO COMPLETION CHECK (MANDATORY)**: Perform final comprehensive check of ALL todos (see "🚨 MANDATORY POST-REVIEW TODO COMPLETION CHECK" section below). Complete any incomplete todos. Only proceed after ALL todos are marked as completed.
10. **FINAL CONFIRMATION**: Verify all phases and sections have been processed across all parts AND all todos are completed

**NON-INTERACTIVE AUTONOMY (NO APPROVAL PROMPTS)**:
- Operate fully autonomously under this prompt: do not stop to ask the user for approval, confirmation, or to proceed between chunks or parts.
- Provide brief informational status updates only; never block awaiting user input during PART1 → PART2A → PART2B → PART3 processing.
- Continue applying fixes and re-validating per-part, per-chunk automatically until the entire file passes all parts.
- Do not output permission-seeking or interrogative phrases (e.g., "confirm", "okay to proceed", "shall I", "waiting for approval"). Use declarative status only.
- Only pause if multiple corrective strategies exist with materially different trade-offs; in that rare case, present options with concise pros/cons and wait. Otherwise, proceed without interruption.
- If any other instruction conflicts with this autonomy policy, this section takes precedence for workflows governed by this prompt.

**IMMEDIATE EXECUTION – NO PLAN-ONLY OUTPUT**
- Start execution immediately: run PART 1 tasks on the first chunk without emitting planning-only text.
- Replace intent/prep language with action-tied, declarative results (e.g., "PART 1 Chunk A: applied 2 fixes; re-validated PASS").
- After any "Starting" line, the next output MUST report completed action on a concrete chunk/part.
- If a chunk has no corrections, proceed silently to the next chunk and state the skip in one line.
- Keep cadence: action → result → next action in progress.

**HARD ENFORCEMENT – SINGLE-PART MEMORY & 500-LINE CHUNKING**:
- Exactly one prompt-part (from this Advanced CoT flow or Code Check Manual) may be resident in memory at a time. Before loading a new part, unload prior part content; retain only a compact capsule (≤ 2KB) with: minimal status map, symbol names only, and active chunk cursor.
- Before analysis, split the input code into chunks of max 500 lines (target 450–500) with 20–40 lines of overlap. Preserve natural boundaries when feasible; if not possible without exceeding the limit, honor the size limit and rely on overlap.
- For each chunk and for the currently-loaded part: run tasks/checks completely, apply fixes, and re-run until PASS/N/A. Only then proceed to the next chunk. After all chunks pass for the current part, unload it and proceed to the next part.
- If this CoT flow triggers A–P checklist checks, it MUST do so through `prompts/Code_check_prompt_manual.txt` with its strict sequential (PART1→PART2→PART3→PART4), single-part memory, and chunking rules.

**BATCHED TODO GENERATION & EXECUTION (20-ITEM STRICT SEQUENCE)**:
- All CoT-driven reviews MUST follow a strict 20-item batching protocol:
  1) Generate the next 20 atomic todos from the current reasoning plan and state,
  2) Execute them in order (1→20), one at a time, without interleaving or skipping,
  3) Mark each as completed before starting the next,
  4) Only after all 20 complete, generate the next batch of 20 and continue,
  5) Repeat until the entire review/file is complete across all parts (PART1 → PART2A → PART2B → PART3).
- The batching protocol is mandatory and complements the single-part memory and 500-line chunking rules. Do not advance parts/chunks while a 20-item batch is incomplete.

ONE-PART-AT-A-TIME ENFORCEMENT:
- STRICT: Work on exactly one part at a time; do not interleave sections across parts.
- COMPLETE-IN-PART: Apply all fixes/corrections identified during a part before moving on.
- RE-VALIDATE: Re-run that part’s validations/checklists to confirm PASS/N/A post-corrections.
- CARRY FORWARD: Persist artifacts (findings, JSON outputs, symbol/context tables) for the next part.
- BLOCK NEXT PART until the current part is fully completed and re-validated.

**CONTEXT MANAGEMENT**:
- Each part is processed independently with full context (under 500 lines each)
- Cross-references maintained across parts (as documented in each part)
- No phases or sections skipped - sequential processing ensures complete coverage
- Each part references previous parts for continuity

**USAGE FOR USERS**:
- **Single entry point**: Reference `prompts/Advanced-CoT-Multi-Agent-Prompt.md` (this file)
- **Automatic sequential processing**: AI agents automatically load and process all parts in sequence
- **Full coverage guaranteed**: All phases and sections are processed without missing any
- **Context limits maintained**: Each part stays under 500 lines for optimal context window usage

**FOR TOOL INTEGRATION**:
- **Python scripts**: Load this master file, then sequentially read PART1 → PART2A → PART2B → PART3
- **Shell scripts**: Reference this master file, tooling should handle sequential loading
- **Pre-commit hooks**: Load this master file, process all parts sequentially
- **CI/CD**: Reference this master file, validate across all parts sequentially

**MANDATORY FOR ALL REVIEWS**: 
- ALL code reviews MUST reference this master entry point
- This master file MUST be enhanced FIRST when new patterns are discovered
- All phases and sections MUST be processed sequentially across all parts - do not skip any
- Pattern learning updates MUST be added to the appropriate PART file FIRST before being referenced elsewhere

**VERIFICATION**:
After processing all parts, confirm:
- ✅ PART 1 processed (CoT Framework, Structured Reasoning, Sections 0-2)
- ✅ PART 2A processed (Verification Chain, Sections 3-4)
- ✅ PART 2B processed (Self-Correction, Section 5)
- ✅ PART 3 processed (Implementation, Metrics, Final Template, Sections 6-8)
- ✅ All phases and sections checked sequentially without skipping any

**🚨 MANDATORY POST-REVIEW TODO COMPLETION CHECK (BEFORE FINALIZING)**:
- **AFTER ALL PARTS COMPLETE**: You MUST perform a final comprehensive check of ALL todos before finalizing the review.
- **TODO VERIFICATION REQUIRED**:
  - Review the comprehensive todo list created at the beginning
  - Verify that EVERY single todo item is marked as "completed"
  - Check for any todos that may have been marked as "pending", "in_progress", or "cancelled"
  - Identify any todos that were added during the review process but not yet completed
- **INCOMPLETE TODO HANDLING**:
  - If ANY todo remains incomplete, pending, or in progress:
    1. **STOP finalization immediately**
    2. **Complete ALL incomplete todos** before proceeding
    3. **Re-verify** that all todos are marked as completed
    4. **Only then** proceed to final confirmation
  - Do NOT finalize the review if any todos are incomplete
  - Do NOT leave any todos for "later" or "future" completion
- **FINAL TODO CHECKLIST**:
  - ✅ All PART 1 tasks (CoT Framework, Structured Reasoning, Sections 0-2) - todos completed
  - ✅ All PART 2A tasks (Verification Chain, Sections 3-4) - todos completed
  - ✅ All PART 2B tasks (Self-Correction, Section 5) - todos completed
  - ✅ All PART 3 tasks (Implementation, Metrics, Final Template, Sections 6-8) - todos completed
  - ✅ Final confirmation task - todo completed
  - ✅ Any earlier pending tasks (from pre-review check) - todos completed
  - ✅ Any tasks added during review process - todos completed
- **ZERO TOLERANCE**: If even ONE todo is incomplete, the review is NOT complete. Continue working until ALL todos are fully completed.
- **ONLY AFTER ALL TODOS COMPLETE**: Proceed to final confirmation and mark the review as complete.

---

**PART FILES REFERENCE**:
- `prompts/Advanced-CoT-Multi-Agent-Prompt-PART1.md` - CoT Framework, Structured Reasoning, Sections 0-2
- `prompts/Advanced-CoT-Multi-Agent-Prompt-PART2A.md` - Verification Chain, Sections 3-4
- `prompts/Advanced-CoT-Multi-Agent-Prompt-PART2B.md` - Self-Correction, Section 5
- `prompts/Advanced-CoT-Multi-Agent-Prompt-PART3.md` - Implementation, Metrics, Final Template, Sections 6-8

**SEQUENTIAL CHECKING ENFORCED**: Process parts in order (PART1 → PART2A → PART2B → PART3). Do not skip or merge parts.

**INTEGRATION WITH Code_check_prompt_manual.txt**:
- This CoT prompt wraps and extends `prompts/Code_check_prompt_manual.txt` (master entry point)
- Both prompts must be processed: Code_check_prompt_manual.txt (checklist) + this CoT prompt (reasoning framework)
- Sequential processing: First load Code_check_prompt_manual.txt parts, then load this CoT prompt parts

