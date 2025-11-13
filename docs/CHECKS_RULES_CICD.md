# Code Checks, Rules, and CI/CD Integration

**Last Updated:** 2025-11-12  
**Purpose:** Documentation of all automated checks, workflow rules, and CI/CD integrations

---

## 📋 Code Checks

### Prompt-Based Checks

#### D3: Pipe Pattern Safety
- **Check:** Detects unsafe `echo "${VAR}" | grep` patterns
- **Required Pattern:** `grep <<< "${VAR}"` or `[[ "${VAR}" =~ pattern ]]`
- **Detection:** `grep -n 'echo.*|.*grep'`
- **Rationale:** Performance (eliminates subshell), security (prevents echo flag interpretation), explicit quoting
- **Location:** `prompts/Advanced-CoT-Multi-Agent-Prompt.md` (Lines 283-290)
- **Location:** `prompts/Code_check_prompt_manual.txt` (Lines 73-80)

#### L5: Multi-Phase Logic Documentation
- **Check:** Complex multi-phase detection/configuration logic must be documented
- **Required Components:**
  1. Header comment explaining overall strategy and number of phases
  2. Phase markers (e.g., "# Phase 1: ...") before each phase
  3. Final decision comment explaining how phases combine
- **Example:** 3-phase NVIDIA Video Codec SDK detection (lines 7996-8057)
- **Location:** `prompts/Advanced-CoT-Multi-Agent-Prompt.md` (Lines 333-359)
- **Location:** `prompts/Code_check_prompt_manual.txt` (Lines 150-185)

#### M11: CMake Flag Validation
- **Check:** All CMake flags must be validated against official library documentation
- **Requirements:**
  - All flags must exist in `docs/flags/LIBRARY_VERSION_CMAKE_FLAGS_DOCUMENTATION.md`
  - No library-prefixed flags (e.g., `CERES_USE_CUDA` is invalid, use `USE_CUDA`)
  - No undocumented flags
- **Tool:** `scripts/helpers/validate_cmake_flags.sh`
- **Location:** `prompts/Advanced-CoT-Multi-Agent-Prompt.md` (Lines 368-379)
- **Location:** `prompts/Code_check_prompt_manual.txt` (Lines 200-211)

#### M12: HPC Library Conflict Detection
- **Check:** Detect and prevent conflicts between HPC libraries
- **Conflict Types:**
  1. **MKL vs OpenBLAS** - Cannot coexist (symbol conflicts)
  2. **MKL TBB vs System TBB** - Cannot coexist (runtime conflicts)
  3. **Mixed BLAS vendors** - Must use consistent BLAS implementation
- **Detection Patterns:**
  - CMakeCache.txt inspection: `grep -E "^TBB_LIBRARIES" CMakeCache.txt`
  - Path checking: Reject `/opt/intel`, `/opt/intel/oneapi`, `mkl` in TBB paths
  - Accept: `/usr/lib/x86_64-linux-gnu/libtbb`
- **Tool:** `scripts/helpers/verify_cmake_cache.sh`
- **Location:** `prompts/Advanced-CoT-Multi-Agent-Prompt.md` (Lines 380-404)
- **Location:** `prompts/Code_check_prompt_manual.txt` (Lines 212-229)

### Automated Validation Tools

#### CMake Flag Validator
- **Script:** `scripts/helpers/validate_cmake_flags.sh`
- **Purpose:** Validates CMake flags against official library documentation
- **Features:**
  - Parses shell scripts for CMake commands
  - Checks flags against `docs/flags/` documentation
  - Detects undocumented or invalid flags
  - Report-only mode and strict mode
- **Usage:** `./scripts/helpers/validate_cmake_flags.sh <script_file>`
- **Exit Codes:** 0=success, 1=invalid flags, 2=no docs

#### CMakeCache Verifier
- **Script:** `scripts/helpers/verify_cmake_cache.sh`
- **Purpose:** Post-configuration validation of CMakeCache.txt
- **Checks:**
  1. **TBB Source Verification** - Ensures system TBB (not MKL TBB)
  2. **BLAS/LAPACK Validation** - Checks vendor consistency, detects mixed BLAS
  3. **CUDA Configuration** - Validates version and architecture flags
  4. **Library-Specific Checks** - Custom validation for each HPC library
- **Usage:** `./scripts/helpers/verify_cmake_cache.sh <cache_file> <library_name>`
- **Exit Codes:** 0=passed, 1=critical errors, 2=warnings

#### Pre-commit Hook
- **Script:** `scripts/hooks/pre-commit-cmake-validator`
- **Purpose:** Enforce CMake validation before commits
- **Behavior:**
  - Runs CMake validator on staged files
  - Fails commit if validation errors found
  - Can be bypassed with `--no-verify` (not recommended)
- **Installation:** `ln -sf ../../scripts/hooks/pre-commit-cmake-validator .git/hooks/pre-commit`

---

## 🔒 Workflow Rules

### Feature Branch Workflow

**Source:** `.cursor/rules/MASTER-RULES-WORKFLOW.mdc` (Part 2: Git Workflow & Branch Management)

#### Branch Rules
- Create dedicated feature branch per session: `feature/<scope>-<timestamp>`
- Push feature branch and open PR targeting `beta`
- All work occurs through PR (no direct commits to `beta` or `main`)
- Avoid `cursor/*` branches unless explicitly directed

#### Merge Process
1. Stage and commit approved changes
2. Push to PR branch immediately
3. Run merge-feasibility check against `origin/beta`:
   - `git fetch origin`
   - `git checkout beta`
   - `git pull origin beta`
   - `git merge --no-commit --no-ff origin/<feature-branch>`
   - Report outcome (clean vs. conflicts)
   - `git merge --abort` to reset
4. If clean, merge PR branch into `beta`, push, delete feature branch
5. If conflicts, report and coordinate with user

#### Cleanup
- After merging into `beta`:
  - Delete feature branch locally: `git branch -d <branch>`
  - Delete feature branch remotely: `git push origin --delete <branch>`
  - Confirm only `main` and `beta` remain on remote

### Cloud Agent Rules

**Source:** `.cursor/rules/MASTER-RULES-CLOUD.mdc` (Part 5: Cloud Agent Specifics)

#### Branch Coordination
- Confirm correct branch with user before starting
- Sync latest changes: `git pull origin <branch>`
- Verify workspace state: `git status`

#### Feature Branch Lifecycle
1. **Create** - One feature branch per session
2. **Push** - Push branch and open PR (with approval)
3. **Work** - All commits go to feature branch
4. **Check** - Merge-feasibility after every push
5. **Merge** - Merge into `beta` when ready
6. **Cleanup** - Delete merged branch (local and remote)

#### PR Requirements
- Request approval before creating PR
- PR title must include timestamp: `feat: <description> (2025-11-12 15:30 UTC)`
- Post PR URL, source branch, target branch, and title in chat
- Update PR description as work progresses
- Close/merge PR after completion

#### Git Operations
All git operations require explicit user approval:
- ❌ `git add` - Requires "commit this", "add and commit", etc.
- ❌ `git commit` - Requires "commit this", "save changes", etc.
- ❌ `git push` - Requires "push to beta", "push changes", etc.
- ❌ `git checkout -b` - Requires approval for branch creation
- ✅ `git pull origin <branch>` - Allowed for syncing
- ✅ `git status` - Allowed for checking status

### Pre-Commit Audit

**Source:** `.cursor/rules/MASTER-RULES-WORKFLOW.mdc` (Part 2: Git Workflow & Branch Management)

#### Code Validation (Updated - 2025-11-12)
- **Bash Validation:** Runs automatically on push (not every commit)
- **Bash Checklist:** `prompts/Code_check_prompt_manual.txt`
- **Auto-fix:** All errors automatically corrected
- **CoT Auto-trigger:** Advanced CoT audit runs automatically for substantial/complex commits
- **CoT Prompt:** `prompts/Advanced-CoT-Multi-Agent-Prompt.md`
- **Process:**
  1. On push: Extract diff and run bash validation
  2. Auto-fix all errors found
  3. Agent classifies: CoT-worthy or simple bash check sufficient
  4. If CoT-worthy: Run Advanced CoT audit automatically
  5. Report findings in chat

#### Verification Checklist
Before completing any work:
- [ ] Working on user-approved branch
- [ ] Only core files modified
- [ ] No new files created (unless requested)
- [ ] Advanced CoT audit completed
- [ ] Merge-feasibility check reported (if targeting beta)
- [ ] User approval obtained for git operations
- [ ] Feature branch PR merged/closed (if applicable)
- [ ] Feature branch deleted locally and remotely

---

## 🚀 CI/CD Integrations

### GitHub Actions Workflow

**File:** `.github/workflows/prompt-validation.yml`

#### Triggers
- **Pull Requests:** `main`, `beta` branches
- **Pushes:** `main`, `beta` branches
- **Paths:** Only on changes to:
  - `**/*.sh` files
  - `prompts/**` directory
  - `scripts/**` directory
  - Workflow file itself

#### Jobs

##### 1. check-pipe-patterns
- **Purpose:** Detect unsafe `echo | grep` patterns
- **Command:** `grep -n 'echo.*|.*grep' xubuntu_robotics_base_post_ULTRA_CLEANED.sh`
- **Failure:** If any patterns found
- **Output:** Line numbers of violations

##### 2. validate-cmake-flags
- **Purpose:** Validate CMake flags against documentation
- **Command:** `./scripts/helpers/validate_cmake_flags.sh xubuntu_robotics_base_post_ULTRA_CLEANED.sh --report-only`
- **Failure:** If invalid flags detected
- **Output:** List of invalid flags and missing documentation

##### 3. check-multi-phase-docs
- **Purpose:** Verify complex logic has phase documentation
- **Logic:**
  - Count complex blocks: `grep -c 'if.*\[.*\].*; then' | wc -l`
  - Count phase markers: `grep -c '# Phase [0-9]:' | wc -l`
  - Calculate ratio
- **Warning:** If ratio < 0.3 (less than 30% documented)
- **Output:** Documentation coverage percentage

##### 4. check-tbb-verification
- **Purpose:** Ensure TBB verification exists for HPC libraries
- **Checks:**
  - Ceres TBB verification block exists
  - g2o TBB verification block exists
  - GTSAM TBB verification block exists
- **Failure:** If any verification missing
- **Output:** Which libraries lack verification

##### 5. check-heredoc-syntax
- **Purpose:** Validate heredoc delimiter syntax
- **Checks:**
  - All heredocs have matching delimiters
  - Warns about unquoted EOF (potential expansion issues)
- **Warning:** Unquoted delimiters found
- **Output:** Lines with unquoted heredocs

##### 6. check-bash-compatibility
- **Purpose:** Detect Bash 4+ features without version checks
- **Patterns:**
  - `${var^^}` - Uppercase expansion
  - `${var,,}` - Lowercase expansion
  - `${var@Q}` - Quote expansion
- **Failure:** If features found without Bash version guard
- **Output:** Lines with incompatible features

##### 7. shellcheck
- **Purpose:** Comprehensive shell script linting
- **Tool:** ShellCheck
- **Severity:** warning
- **Format:** gcc (compatible with GitHub annotations)
- **Output:** All ShellCheck findings with line numbers

##### 8. summary
- **Purpose:** Aggregate all job results
- **Dependencies:** All 7 check jobs
- **Behavior:**
  - Reports pass/fail for each job
  - Provides remediation guidance for failures
  - Links to relevant documentation
- **Always runs:** Even if previous jobs fail

### CI/CD Benefits
- Zero manual oversight for validation
- Continuous enforcement of prompt rules
- Early detection of violations
- Automated feedback on PRs
- Consistent code quality across commits

---

## 📖 Documentation References

### Prompt Files
- `prompts/Advanced-CoT-Multi-Agent-Prompt.md` - Multi-agent CoT code review framework
- `prompts/Code_check_prompt_manual.txt` - Comprehensive Bash code checklist

### Rule Files
- `.cursor/rules/000-MANDATORY-READ-FIRST.mdc` - Pre-work verification checklist
- `.cursor/rules/MASTER-RULES-INDEX.mdc` - **MASTER INDEX & SINGLE SOURCE OF TRUTH** - References all focused rule modules (all under 500 lines, Cursor-compliant)

### Tool Files
- `scripts/helpers/validate_cmake_flags.sh` - CMake flag validator
- `scripts/helpers/verify_cmake_cache.sh` - CMakeCache verifier
- `scripts/hooks/pre-commit-cmake-validator` - Pre-commit validation hook
- `.github/workflows/prompt-validation.yml` - CI/CD workflow

### Documentation Files
- `docs/CMAKE_FLAG_VALIDATOR_USAGE.md` - CMake validator usage guide
- `docs/cmake-templates/README.md` - CMake template usage guide
- `README.md` - Project README (includes all new features)

---

**Status:** ✅ All checks, rules, and CI/CD integrations documented  
**Last Updated:** 2025-11-12
