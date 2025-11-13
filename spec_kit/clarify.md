# Clarify - Issues Resolved and Clarifications

## Issues Resolved

### 1. DPKG Status Corruption
**Problem**: Multiple OpenCV package entries causing dpkg parsing errors
**Root Cause**: OpenCV protection mechanism creating duplicate entries in `/var/lib/dpkg/status`
**Solution**: Replaced with safe `apt-mark hold` method and apt preferences
**Status**: ✅ Resolved

### 2. Missing Directory Creation
**Problem**: "No such file or directory" errors for dpkg status.d
**Root Cause**: Missing `mkdir -p /var/lib/dpkg/status.d` before creating dummy packages
**Solution**: Added directory creation for Ceres, G2O, and GTSAM protection
**Status**: ✅ Resolved

### 3. Branch Management
**Problem**: New branches created automatically by agents
**Root Cause**: No clear workflow instructions for agents
**Solution**: Created centralized rules system (`.cursor/rules/*.mdc`) automatically enforced by Cursor IDE
**Status**: ✅ Resolved

### 4. Repository Bloat
**Problem**: Multiple patch files and non-functional files
**Root Cause**: Temporary fixes created as separate files
**Solution**: Integrated all fixes into core files, removed patch files, centralized documentation
**Status**: ✅ Resolved

### 5. Rules Duplication
**Problem**: Rules duplicated across multiple files (AGENT_INSTRUCTIONS.md, README, etc.)
**Root Cause**: No single source of truth for rules
**Solution**: Centralized all rules in `.cursor/rules/*.mdc` files, removed duplicate documentation
**Status**: ✅ Resolved

## Current Clarifications

### Branch Workflow
- **Default**: All work on beta branch
- **Main Branch**: Only when explicitly instructed
- **New Branches**: Forbidden unless explicitly requested
- **Pull Requests**: Not used, direct commits only

### File Management
- **Core Files**: Only 7 essential files can be modified
- **New Files**: Only when explicitly requested
- **Spec Kit**: For documentation and specifications only
- **No Patches**: All fixes integrated into core files

### Build Process
- **Protection**: Uses apt-mark hold and apt preferences
- **Cleanup**: Automatic cleanup of conflicting entries
- **Error Handling**: Non-fatal failures, continues build
- **Verification**: Checks dpkg database integrity

### Agent Instructions & Rules System
- **Source of Truth**: `.cursor/rules/*.mdc` files (automatically enforced by Cursor IDE)
  - `.cursor/rules/000-MANDATORY-READ-FIRST.mdc` - Mandatory pre-work verification checklist (READ FIRST)
  - `.cursor/rules/MASTER-RULES-INDEX.mdc` - MASTER INDEX & SINGLE SOURCE OF TRUTH (references focused modules)
- **Automatic Enforcement**: Rules are automatically loaded and enforced by Cursor IDE (`alwaysApply: true`)
- **Mandatory**: All AI agents MUST follow rules (no manual configuration needed, strictly enforced)
- **Verification**: Check branch, files, and commit process before completing work (mandatory checklist)
- **Forbidden**: Creating new branches, adding non-core files, git operations without approval
- **Required**: Work on beta branch, edit core files only, get explicit user approval for git operations
- **Strict Adherence**: Rules are STRICTLY ENFORCED with mandatory verification checklists
- **Documentation**: See `docs/GLOBAL_CURSOR_SETTINGS.md` for global settings, `README.md` for quick reference

## Pending Clarifications
- None currently identified
- All major issues resolved
- Workflow established and documented