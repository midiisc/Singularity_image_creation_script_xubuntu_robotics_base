# ADVANCED CODE REVIEW PROMPT: MULTI-AGENT CHAIN-OF-THOUGHT - MASTER ENTRY POINT

**AUTHORITATIVE SOURCE**: This file (`Advanced-CoT-Multi-Agent-Prompt.md`) is the **master entry point** for the Advanced CoT Multi-Agent code review framework. It orchestrates sequential checking across all parts while maintaining 500-line context limits.

**SEQUENTIAL PROCESSING ARCHITECTURE**:
This prompt is split into multiple parts (each under 500 lines) to maintain full context throughout the review process. When this file is referenced, ALL parts MUST be processed sequentially:

1. **PART 1**: `Advanced-CoT-Multi-Agent-Prompt-PART1.md` (CoT Framework, Structured Reasoning, Sections 0-2)
2. **PART 2A**: `Advanced-CoT-Multi-Agent-Prompt-PART2A.md` (Verification Chain, Sections 3-4)
3. **PART 2B**: `Advanced-CoT-Multi-Agent-Prompt-PART2B.md` (Self-Correction, Sections 5 partial)
4. **PART 3**: `Advanced-CoT-Multi-Agent-Prompt-PART3.md` (Implementation, Metrics, Final Template, Sections 6-8)

**MANDATORY EXECUTION PROTOCOL FOR AI AGENTS**:
When this master entry point is referenced, you MUST:

1. **LOAD PART 1 FIRST**: Read `prompts/Advanced-CoT-Multi-Agent-Prompt-PART1.md` completely
2. **PROCESS ALL TASKS IN PART 1**: Execute all CoT framework tasks, structured reasoning, and sections 0-2 from PART 1
3. **ONLY AFTER PART 1 COMPLETE**: Load `prompts/Advanced-CoT-Multi-Agent-Prompt-PART2A.md`
4. **PROCESS ALL TASKS IN PART 2A**: Execute all verification chain tasks and sections 3-4 from PART 2A
5. **ONLY AFTER PART 2A COMPLETE**: Load `prompts/Advanced-CoT-Multi-Agent-Prompt-PART2B.md`
6. **PROCESS ALL TASKS IN PART 2B**: Execute all self-correction tasks and section 5 from PART 2B
7. **ONLY AFTER PART 2B COMPLETE**: Load `prompts/Advanced-CoT-Multi-Agent-Prompt-PART3.md`
8. **PROCESS ALL TASKS IN PART 3**: Execute all implementation, metrics, and final template tasks (sections 6-8) from PART 3
9. **FINAL CONFIRMATION**: Verify all phases and sections have been processed across all parts

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

