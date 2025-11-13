# Constitution - Core Principles and Rules

## Repository Constitution
This document defines the fundamental principles and rules governing this repository.

### Core Principles
1. **Minimal Repository**: Keep only essential files, no bloat
2. **Two Branches Only**: `main` and `beta` - no exceptions
3. **Core Files Only**: All modifications on essential functional files
4. **No New Files**: Unless explicitly requested
5. **Clean Commits**: Direct, purposeful changes only

### Branch Rules
- **Beta Branch**: Default working branch for all development
- **Main Branch**: Only when explicitly instructed
- **No New Branches**: Forbidden unless explicitly requested
- **No Pull Requests**: Direct commits only

### File Management
- **Core Files**: Only edit these 7 essential files
- **Spec Kit**: Documentation and specifications only
- **No Patches**: All fixes integrated into core files
- **No Workflow Files**: Keep repository clean

### Development Workflow
1. **Verify branch**: Check you're on beta branch (`git branch --show-current`)
2. **Pull latest**: `git pull origin beta`
3. **Edit core files only**: Only modify allowed core files
4. **Run audit**: Pre-commit audit runs automatically (or run manually)
5. **Get approval**: Never commit/push without explicit user approval
6. **Commit**: Clear, descriptive commit messages
7. **Push to beta**: Default branch (only if explicitly approved)
8. **Main branch**: Only when explicitly instructed by user

### Rules System - Strictly Enforced
- **Source of Truth**: `.cursor/rules/*.mdc` files (automatically enforced by Cursor IDE)
- **Mandatory Pre-Work**: `.cursor/rules/000-MANDATORY-READ-FIRST.mdc` (READ FIRST, verification checklist)
- **Master Rules**: `.cursor/rules/MASTER-RULES-INDEX.mdc` - MASTER INDEX & SINGLE SOURCE OF TRUTH (references focused modules)
- **Automatic Enforcement**: Cursor IDE loads and enforces rules automatically (`alwaysApply: true`)
- **Mandatory Verification**: Pre-work checklists required before any action
- **Strict Language**: Rules use "YOU MUST", "STRICTLY ENFORCED", "ABSOLUTELY MANDATORY"
- **No Duplication**: Rules defined once, referenced elsewhere
- **Violation Protocol**: Stop, explain, ask permission, wait for confirmation
- **Documentation**: `docs/GLOBAL_CURSOR_SETTINGS.md` for global settings

### Quality Standards
- **Clean Code**: Well-documented, maintainable
- **Error Handling**: Robust, non-fatal failures
- **Verification**: Test before committing
- **Documentation**: Clear, concise specifications
- **Audit Compliance**: All code must pass pre-commit audit
- **Rules Compliance**: All AI agents must follow `.cursor/rules/*.mdc` rules
- **User Approval**: Never commit/push without explicit user approval

## Violations
Any violation of these principles requires immediate correction and explanation.