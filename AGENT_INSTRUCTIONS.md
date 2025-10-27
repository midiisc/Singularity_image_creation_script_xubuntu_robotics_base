# AGENT INSTRUCTIONS - CRITICAL WORKFLOW

## 🚨 MANDATORY WORKFLOW - READ BEFORE ANY CHANGES

### BRANCH RULES
- **ONLY 2 BRANCHES ALLOWED**: `main` and `beta`
- **ALWAYS work on `beta` branch** - NEVER create new branches
- **NO `cursor/*` branches** - This is forbidden
- **NO pull requests** - All changes go directly to beta branch

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

- **NO new files** unless explicitly requested
- **NO patch scripts** - All fixes go into core files
- **NO workflow files** - Keep repository clean

### COMMIT PROCESS
```bash
# 1. Add changes
git add -A

# 2. Commit with clear message
git commit -m "fix: Description of changes"

# 3. Push to beta branch
git push origin beta
```

### FORBIDDEN ACTIONS
❌ Creating new branches
❌ Creating pull requests
❌ Adding non-core files
❌ Creating patch scripts
❌ Working on any branch other than beta

### VERIFICATION
Before finishing, verify:
- [ ] Working on beta branch
- [ ] Only core files modified
- [ ] No new files created
- [ ] Changes committed to beta
- [ ] No new branches created

## REMEMBER: BETA BRANCH ONLY, CORE FILES ONLY, NO NEW BRANCHES