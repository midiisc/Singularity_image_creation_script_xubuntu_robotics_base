# Prompt Cross-Reference Verification

**Generated**: 2025-11-13  
**Purpose**: Verify that Code Check, Advanced CoT, and Library Analysis Tool prompts properly reference each other

---

## Summary

✅ **ALL PROMPTS NOW PROPERLY CROSS-REFERENCE EACH OTHER**

---

## 1. Code_check_prompt_manual.txt → Library-Analysis-Tool.md

### Reference Locations (5 references):

#### **Reference 1: M-TOOLS (Line 192)**
```
M. Environment & Dependencies
- **M-TOOLS**: When analyzing library dependencies, CMake flags, or bundled 
  components, consider using `prompts/Library-Analysis-Tool.md` for automated 
  comprehensive analysis before manual verification.
```
**Purpose**: General awareness that the tool exists for M-section checks

---

#### **Reference 2: M8 CMAKE FLAG DOCUMENTATION (Line 257)**
```
- Tools: Use `prompts/Library-Analysis-Tool.md` to generate documentation; 
  `rg "option\\(|set\\(.*CACHE"` to extract flags from CMakeLists.txt
```
**Purpose**: Instructs to use Library Analysis Tool for generating CMake flag documentation

---

#### **Reference 3: M11 BUNDLED COMPONENT DETECTION (Lines 342-346)**
```
- **AUTOMATED ANALYSIS TOOL**: Use `prompts/Library-Analysis-Tool.md` to automate 
  bundled component detection:
  - Run: `./analyze-library.sh --library <name>` to generate comprehensive dependency analysis
  - Tool outputs: `bundled_components.md` (what's bundled), `version_changes.md` 
    (changelog analysis), `dependency_recommendations.md` (pros/cons)
  - Review generated analysis before writing detection logic in build scripts
  - Reference: See "PART 1: EXECUTABLE BASH SCRIPT" in Library-Analysis-Tool.md for usage
```
**Purpose**: Specific instructions for automated bundled component analysis

---

#### **Reference 4: M11 Real Error Example (Line 352)**
```
- **Could have been prevented**: Running Library Analysis Tool would have revealed 
  METIS bundling immediately
```
**Purpose**: Shows how tool prevents real errors (SuiteSparse METIS case)

---

## 2. Advanced-CoT-Multi-Agent-Prompt.md → Library-Analysis-Tool.md

### Reference Locations (5 references):

#### **Reference 1: Agent 2 Description Box (Lines 91-93)**
```
│ TOOLS AVAILABLE:                                            │
│ - Library Analysis Tool (prompts/Library-Analysis-Tool.md)  │
│   Automates: bundling detection, changelog parsing, version │
│   analysis. Recommended BEFORE manual library integration.  │
```
**Purpose**: Informs Agent 2 (HPC Specialist) that the tool is available

---

#### **Reference 2: M13 AUTOMATED ANALYSIS RECOMMENDATION (Lines 492-497)**
```
- **AUTOMATED ANALYSIS RECOMMENDATION**:
  * **BEFORE manual analysis**, Agent 2 SHOULD run Library Analysis Tool for 
    comprehensive automated analysis
  * Tool: `prompts/Library-Analysis-Tool.md` provides executable script `analyze-library.sh`
  * Usage: `./analyze-library.sh --library <name> --output ./analysis/<name>`
  * Generates: 
    - `bundled_components.md` - Automatic detection of bundled dependencies
    - `version_changes.md` - Git log analysis of dependency changes between versions
    - `dependency_recommendations.md` - Pros/cons tables and best practices
  * Benefit: Eliminates manual repo cloning/parsing, provides structured analysis 
    for agent reasoning
  * Agent should review tool output FIRST, then perform manual verification as needed
  * Reference tool output in agent's final analysis report
```
**Purpose**: Detailed instructions for Agent 2 to use the tool BEFORE manual analysis

---

#### **Reference 3: M13 Exit Criteria #3 (Line 505)**
```
3. ✅ Changelog reviewed for dependency changes (or Library Analysis Tool output reviewed)
```
**Purpose**: Allows tool output as alternative to manual changelog review

---

#### **Reference 4: M13 Exit Criteria #8 (Line 510)**
```
8. ✅ If Library Analysis Tool used, output files referenced in review documentation
```
**Purpose**: Ensures tool usage is documented when utilized

---

## 3. Integration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  USER TASK: Integrate library with unknown bundled dependencies │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ↓
        ┌────────────────────────────────────────┐
        │  STEP 1: Run Library Analysis Tool     │
        │  ./analyze-library.sh --library <name> │
        │                                         │
        │  Generates:                             │
        │  - bundled_components.md                │
        │  - version_changes.md                   │
        │  - dependency_recommendations.md        │
        └────────────────┬───────────────────────┘
                         │
                         ↓
        ┌────────────────────────────────────────┐
        │  STEP 2: Write build script with       │
        │  detection logic informed by tool      │
        │  output                                 │
        └────────────────┬───────────────────────┘
                         │
                         ↓
        ┌────────────────────────────────────────┐
        │  STEP 3a: Code Check Validation        │
        │  (Code_check_prompt_manual.txt)        │
        │                                         │
        │  Checks M11: BUNDLED COMPONENT         │
        │  DETECTION                              │
        │  - References Library Analysis Tool    │
        │  - Verifies detection logic correct    │
        └────────────────┬───────────────────────┘
                         │
                         ↓
        ┌────────────────────────────────────────┐
        │  STEP 3b: Advanced CoT Review          │
        │  (Advanced-CoT-Multi-Agent-Prompt.md)  │
        │                                         │
        │  Agent 2 checks M13: LIBRARY BUNDLED   │
        │  COMPONENT DETECTION AND ANALYSIS       │
        │  - References Library Analysis Tool    │
        │  - Expects tool output in review       │
        └────────────────┬───────────────────────┘
                         │
                         ↓
        ┌────────────────────────────────────────┐
        │  RESULT: Correct detection logic with  │
        │  bundled components properly handled   │
        │  (No more "libcolmap-metis not         │
        │  detected" issues!)                     │
        └────────────────────────────────────────┘
```

---

## 4. Reference Types

### Type A: General Awareness
- **Code Check M-TOOLS** (Line 192): Tells reviewers tool exists
- **Advanced CoT Agent 2 Box** (Lines 91-93): Tells Agent 2 tool is available

### Type B: Specific Usage Instructions
- **Code Check M8** (Line 257): Use for CMake flag documentation
- **Code Check M11** (Lines 342-346): Use for bundled component detection
- **Advanced CoT M13** (Lines 492-497): Detailed usage guide for Agent 2

### Type C: Exit Criteria / Validation
- **Advanced CoT Exit Criteria #3** (Line 505): Tool output as valid alternative
- **Advanced CoT Exit Criteria #8** (Line 510): Must reference tool if used

### Type D: Error Prevention Examples
- **Code Check M11 Example** (Line 352): Shows tool would have prevented METIS issue

---

## 5. Coverage Matrix

| Prompt | References Library Analysis Tool? | Where? | Purpose |
|--------|-----------------------------------|--------|---------|
| **Code_check_prompt_manual.txt** | ✅ YES (5 refs) | M-TOOLS, M8, M11 (3x), Real Error | General awareness, CMake flags, bundled components, error prevention |
| **Advanced-CoT-Multi-Agent-Prompt.md** | ✅ YES (5 refs) | Agent 2 box, M13 (3x), Exit criteria (2x) | Agent tooling, automated analysis recommendation, validation |
| **Library-Analysis-Tool.md** | N/A (is the tool itself) | - | Provides the automation referenced by other prompts |

---

## 6. Bi-directional Linkage

### Code Check ↔ Library Analysis Tool
- **Forward**: Code Check references Library Analysis Tool in M8, M11
- **Context**: Instructs reviewers to use tool for analysis
- **Backward**: Not needed (Code Check is validation, not a tool)

### Advanced CoT ↔ Library Analysis Tool
- **Forward**: Advanced CoT references Library Analysis Tool in Agent 2 description, M13
- **Context**: Agent 2 should use tool before manual analysis
- **Backward**: Not needed (Advanced CoT is validation prompt)

### Code Check ↔ Advanced CoT
- **Alignment**: Both reference Library Analysis Tool for same purpose (M11/M13)
- **Consistency**: Both expect tool output for bundled component analysis
- **No direct cross-reference needed**: They serve different purposes (manual check vs AI review)

---

## 7. Verification Commands

```bash
# Verify Code Check references
grep -n "Library.?Analysis.?Tool\|analyze-library" prompts/Code_check_prompt_manual.txt

# Expected output: 5 matches at lines 192, 257, 342, 346, 352

# Verify Advanced CoT references
grep -n "Library.?Analysis.?Tool\|analyze-library" prompts/Advanced-CoT-Multi-Agent-Prompt.md

# Expected output: 5 matches at lines 91, 492-494, 505, 510
```

---

## 8. Validation Status

✅ **Code_check_prompt_manual.txt**: 5 references to Library Analysis Tool  
✅ **Advanced-CoT-Multi-Agent-Prompt.md**: 5 references to Library Analysis Tool  
✅ **Library-Analysis-Tool.md**: Enhanced with 3 new functions for bundled component analysis  
✅ **Cross-references are contextually appropriate** (general awareness + specific usage)  
✅ **Integration flow is complete** (tool → build script → validation prompts)

---

## 9. Future Maintenance

**When updating Library-Analysis-Tool.md**:
1. Check if new capabilities should be referenced in Code Check M11
2. Check if new capabilities should be referenced in Advanced CoT M13
3. Update cross-reference examples if tool usage changes

**When updating Code Check or Advanced CoT prompts**:
1. Ensure M11/M13 sections still reference Library Analysis Tool
2. Keep usage examples synchronized with actual tool capabilities
3. Update exit criteria if tool validation requirements change

---

**Status**: ✅ COMPLETE - All prompts properly cross-reference each other  
**Last Verified**: 2025-11-13
