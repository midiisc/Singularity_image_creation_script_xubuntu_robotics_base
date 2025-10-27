# AGENT INSTRUCTIONS - CRITICAL WORKFLOW

## 🚨 MANDATORY WORKFLOW - READ BEFORE ANY CHANGES

### BRANCH RULES
- **ONLY 2 BRANCHES ALLOWED**: `main` and `beta`
- **ALWAYS work on `beta` branch** - NEVER create new branches
- **NO `cursor/*` branches** - This is forbidden
- **NO pull requests** - All changes go directly to beta branch
- **MAIN BRANCH**: Only when explicitly instructed (e.g., "commit to main" or "merge beta to main")
- **BETA TO MAIN**: User will explicitly say when to merge beta commits to main

### BEFORE STARTING ANY WORK:
```bash
# 1. Check current branch
git branch --show-current

# 2. If not on beta, switch to beta
git checkout beta

# 3. Pull latest changes
git pull origin beta

# 4. Verify you're on beta branch
git status
```

### EDITING RULES
- **ONLY edit these core files**:
  - `build_xubuntu_robotics_base.sh`
  - `config.sh`
  - `create_writable_overlay.sh`
  - `run_on_best_node.sh`
  - `setup_conda_environments.sh`
  - `xubuntu_robotics_base_post_ULTRA_CLEANED.sh`
  - `README.md`

- **NO new files** unless explicitly requested by user
- **NO patch scripts** - All fixes go into core files
- **NO workflow files** - Keep repository clean
- **NO temporary files** - Repository must stay minimal and clutter-free
- **ALL modifications** must be done on core files only

### COMMIT PROCESS
```bash
# 1. Add changes
git add -A

# 2. Commit with clear message
git commit -m "fix: Description of changes"

# 3. Push to beta branch (DEFAULT)
git push origin beta

# 4. ONLY if explicitly instructed, push to main
# git push origin main
```

### BETA TO MAIN WORKFLOW
- **DEFAULT**: All commits go to beta branch
- **MAIN COMMITS**: Only when user explicitly says "commit to main" or "merge beta to main"
- **END OF DAY**: User will explicitly instruct when to merge beta commits to main
- **VERIFICATION**: User will verify changes before main branch updates

### FORBIDDEN ACTIONS
❌ Creating new branches
❌ Creating pull requests
❌ Adding non-core files
❌ Creating patch scripts
❌ Working on any branch other than beta
❌ Creating temporary files
❌ Adding workflow files
❌ Committing to main without explicit instruction

### REPOSITORY PRINCIPLES
- **MINIMAL**: Keep repository clutter-free
- **CORE FILES ONLY**: All work on essential files
- **NO BLOAT**: No unnecessary files or branches
- **CLEAN COMMITS**: Direct, purposeful changes

### VERIFICATION
Before finishing, verify:
- [ ] Working on beta branch
- [ ] Only core files modified
- [ ] No new files created
- [ ] Changes committed to beta
- [ ] No new branches created
- [ ] Repository remains minimal and clean

## REMEMBER: BETA BRANCH ONLY, CORE FILES ONLY, NO NEW BRANCHES, MINIMAL REPO