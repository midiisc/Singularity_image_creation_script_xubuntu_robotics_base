# Beta Branch Workflow

## Overview
All development work now happens on the `beta` branch by default. This ensures a single, stable development branch with all the latest fixes and improvements.

## Current Status
- ✅ **Default branch**: `beta`
- ✅ **All fixes included**: OpenCV protection, dpkg fixes, directory creation fixes
- ✅ **Old branch removed**: `midiisc-v3-beta` has been deleted
- ✅ **Standardized workflow**: Use `./commit_to_beta.sh "message"`

## How to Commit Changes

### Method 1: Using the script (Recommended)
```bash
./commit_to_beta.sh "fix: Update OpenCV protection mechanism"
```

### Method 2: Manual commands
```bash
git add -A
git commit -m "your commit message"
git push origin beta
```

## Why New Branches Were Being Created

The issue was that Cursor agents were creating new branches with names like:
- `cursor/check-colmap-and-gui-build-status-f6e4`
- `cursor/analyze-project-girl-components-978b`

This happened because:
1. **No default branch was set** - Agents didn't know which branch to use
2. **No workflow instructions** - Agents created their own branch names
3. **No standardized process** - Each agent session created a new branch

## Solution Implemented

1. **Set beta as default working branch**
2. **Created standardized commit script**
3. **Added workflow configuration**
4. **Removed old conflicting branches**

## For Future Agents

When working on this repository:
1. **Always work on beta branch**
2. **Use the commit script**: `./commit_to_beta.sh "message"`
3. **Do not create new branches** unless explicitly requested
4. **All changes go to beta branch only**

## Branch Status

- ✅ `beta` - Main development branch (current)
- ❌ `midiisc-v3-beta` - Deleted (replaced by beta)
- ❌ `cursor/*` branches - Will be cleaned up as needed

## Verification

To verify you're on the correct branch:
```bash
git branch --show-current
# Should output: beta
```

To see all commits in beta:
```bash
git log --oneline origin/beta
```