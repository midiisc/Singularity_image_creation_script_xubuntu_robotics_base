# Comprehensive Build Flags Analysis Prompt
## 5-Phase Architecture with Mixture of Reasoning Experts

**Purpose**: This prompt provides a complete, production-ready system for comprehensively analyzing compilation flags in large C++ libraries like SuiteSparse, Ceres, GTSAM, and others.

**Target Completeness**: >=95% flag coverage with multi-source validation

---

## Overview: 5-Phase Architecture

### Phase 1: Discovery (Automated Preprocessing)
- Recursively find ALL build-related files (CMakeLists.txt, *.cmake, changelogs, docs)
- Categorize by type (cmake, config, changelog, docs)
- Generate manifest with statistics

### Phase 2: Preprocessing (Automated Extraction)
- Extract flags using regex patterns (option(), set(), add_definitions())
- Identify dependencies (required vs optional)
- Parse version information (git tags, CMake project version)
- Export structured JSON for programmatic access

### Phase 3: Deep Analysis (LLM with Chain-of-Thought)
- Semantic understanding of each flag
- Cross-reference with documentation
- Parse changelogs for version-specific changes
- Track bundled dependency evolution (e.g., METIS in SuiteSparse)

### Phase 4: Multi-Pass Validation (LLM)
- Consistency checking across sources
- Dependency resolution and conflict detection
- Version-aware validation
- Gap identification

### Phase 5: Documentation Generation (LLM)
- Comprehensive markdown documentation (50-100 pages)
- JSON database (programmatic access)
- Quick reference card (2-5 pages)
- Troubleshooting guide with solutions

---

## Mixture of Reasoning Experts Architecture

**Four Specialized Agents:**

1. **Configuration Expert**: Analyzes CMake options, cache variables, build flags
2. **Dependency Expert**: Maps external, bundled, and optional dependencies
3. **Version Expert**: Tracks historical changes, version-specific behaviors
4. **Documentation Expert**: Synthesizes findings into comprehensive documentation

**Each expert uses Chain-of-Thought reasoning:**
- Step-by-step analysis
- Explicit reasoning chains
- Cross-validation with other experts
- Structured output templates

---

## Phase 3: Deep Analysis Protocol

### Step 1: Flag Semantic Understanding

For each flag discovered in preprocessing:

1. **Identify flag type**:
   - CMake option (BOOL, STRING, FILEPATH, PATH)
   - Cache variable (CMAKE_*)
   - Compiler definition (-D)
   - Build configuration (Debug/Release)

2. **Extract semantic meaning**:
   - What does this flag control?
   - What are the valid values?
   - What is the default?
   - When was it introduced? (version tracking)

3. **Document dependencies**:
   - Required dependencies when enabled
   - Optional dependencies
   - Conflicts with other flags
   - Platform-specific behavior

### Step 2: Cross-Reference Validation

1. **CMakeLists.txt analysis**:
   - Find all references to the flag
   - Understand conditional logic
   - Track usage patterns

2. **Documentation cross-check**:
   - Search README, INSTALL, BUILD docs
   - Verify flag descriptions match implementation
   - Identify documentation gaps

3. **Changelog parsing**:
   - Find version when flag was introduced
   - Track changes/deprecations
   - Note breaking changes

### Step 3: Historical Evolution Tracking

For bundled dependencies (e.g., METIS in SuiteSparse):

1. **Version timeline**:
   - Pre-v3.0: Separate libmetis + libcholmod_metis.so required
   - v3.0+: METIS embedded into CHOLMOD with renamed symbols
   - v5.0+: No libcholmod_metis.so, all in libcholmod.so
   - v7.0+: Can disable with -DNPARTITION flag

2. **Documentation format**:
   ```markdown
   ### METIS Configuration (CRITICAL: Version-Specific)
   
   **Current (v7.11):** Bundled by default, no external dependency
   
   **Troubleshooting:**
   - Error: "libcholmod_metis.so not found"
     - Cause: Legacy CMake scripts expecting old structure
     - Solution: Link only `-lcholmod` (includes METIS)
     - Since: v3.0 (2008)
   
   **CMake Flags:**
   - ENABLE_METIS (BOOL, default ON): Enable METIS partitioning
   - NPARTITION (build flag): Disable METIS if needed
   ```

---

## Phase 4: Multi-Pass Validation

### Pass 1: Consistency Check
- Verify flag names consistent across CMakeLists.txt files
- Check default values match documentation
- Validate dependency requirements

### Pass 2: Dependency Resolution
- Map all find_package() calls to flags
- Identify circular dependencies
- Detect missing optional dependencies

### Pass 3: Version-Aware Validation
- Verify flags exist in analyzed version
- Check for deprecated flags
- Validate version-specific behaviors

### Pass 4: Gap Identification
- Find flags in code but not documented
- Identify documented flags not in code
- Report completeness metrics

---

## Phase 5: Documentation Generation

### Output Structure

1. **Complete Documentation** (`{Library}_v{Version}_flags_complete.md`):
   - Executive summary
   - Flag inventory (categorized)
   - Dependency matrix
   - Version history
   - Troubleshooting guide
   - Build examples

2. **JSON Database** (`{Library}_flags_database.json`):
   ```json
   {
     "flags": [
       {
         "name": "ENABLE_METIS",
         "type": "BOOL",
         "default": true,
         "description": "Enable METIS partitioning",
         "introduced": "v3.0",
         "dependencies": [],
         "conflicts": ["NPARTITION"],
         "version_specific": {
           "v3.0+": "Bundled in CHOLMOD",
           "v7.0+": "Can be disabled with NPARTITION"
         }
       }
     ],
     "dependencies": [...],
     "version_info": {...}
   }
   ```

3. **Quick Reference** (`{Library}_flags_quick_ref.md`):
   - Most common flags (top 20-30)
   - Copy-paste build examples
   - Common troubleshooting

4. **Analysis Report** (`analysis_report_{timestamp}.md`):
   - Completeness metrics
   - Validation results
   - Gap analysis
   - Recommendations

---

## Quality Metrics

**Target Metrics:**
- **Completeness**: >=95% of flags documented
- **Accuracy**: All flags validated against source code
- **Version Coverage**: All major versions analyzed
- **Dependency Mapping**: 100% of dependencies mapped

**Validation Checklist:**
- [ ] All CMakeLists.txt files analyzed
- [ ] All option() calls documented
- [ ] All cache variables identified
- [ ] All dependencies mapped (bundled vs external)
- [ ] Version history complete
- [ ] Troubleshooting guide comprehensive
- [ ] JSON database valid and complete

---

## Usage Instructions

### For AI Agents (Cursor/Claude)

1. **Preprocessing Phase** (if not already done):
   ```
   Run analyze-library.sh to generate preprocessing_data.json
   ```

2. **Invoke Analysis**:
   ```
   @Comprehensive-Flag-Analysis-Prompt.md Analyze all build flags following 5-phase protocol.
   Use preprocessing_data.json. Target: >=95% completeness.
   ```

3. **Review Outputs**:
   - Complete documentation: `{Library}_v{Version}_flags_complete.md`
   - JSON database: `{Library}_flags_database.json`
   - Quick reference: `{Library}_flags_quick_ref.md`
   - Analysis report: `analysis_report_{timestamp}.md`

### Workflow Integration

This prompt integrates with:
- `Library-Analysis-Tool-PART1.md` - Preprocessing script
- `Library-Analysis-Tool-PART2.md` - Agent workflow
- `Library-Analysis-Tool-PART3.md` - Complete integration

---

## Best Practices

1. **Recursive & Complete**: Analyze EVERY file at ANY depth
2. **Version-Aware**: Track when flags were introduced, bundled, deprecated
3. **Multi-Source Validation**: Cross-reference CMake, changelogs, docs
4. **Structured Output**: Both human-readable (MD) and machine-readable (JSON)
5. **Dependency Tracking**: Map external, bundled, and optional dependencies
6. **Historical Analysis**: Chronicle evolution (e.g., "METIS bundled since v3.0")
7. **Troubleshooting**: Document common errors with concrete solutions
8. **Reproducible**: Can re-run for new versions with same workflow

---

## Example: SuiteSparse METIS Analysis

**Historical Evolution:**
- **Pre-v3.0**: Separate libmetis + libcholmod_metis.so required
- **v3.0+**: METIS embedded into CHOLMOD with renamed symbols
- **v5.0+**: No libcholmod_metis.so, all in libcholmod.so
- **v7.0+**: Can disable with -DNPARTITION flag

**Documentation Output:**
```markdown
### METIS Configuration (CRITICAL: Version-Specific)

**Current (v7.11):** Bundled by default, no external dependency

**Troubleshooting:**
- Error: "libcholmod_metis.so not found"
  - Cause: Legacy CMake scripts expecting old structure
  - Solution: Link only `-lcholmod` (includes METIS)
  - Since: v3.0 (2008)

**CMake Flags:**
- ENABLE_METIS (BOOL, default ON): Enable METIS partitioning
- NPARTITION (build flag): Disable METIS if needed
```

---

## Integration with Existing Tools

This prompt enhances:
- **analyze-library.sh**: Adds Phase 1-2 preprocessing
- **Library-Analysis-Tool prompts**: Adds Phase 3-5 LLM analysis
- **Code_check_prompt_manual.txt**: Adds build flag validation patterns

**Complete Workflow:**
1. Run `analyze-library.sh` → Generates preprocessing data
2. Feed preprocessing data + this prompt → Generates comprehensive documentation
3. Validate against `Code_check_prompt_manual.txt` → Ensures quality

---

**This is a production-ready, research-grade system for build flag analysis that eliminates guesswork and ensures nothing is missed.**

