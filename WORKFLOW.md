# Development Workflow

## Branch Strategy

### Main Branch (`main`)
- **Purpose**: Stable, production-ready code
- **Updates**: Only through merges from `midiisc-v3-beta`
- **Protection**: No direct commits (development happens in beta)

### Beta Branch (`midiisc-v3-beta`)
- **Purpose**: Development and testing
- **Updates**: Active development, new features, fixes
- **Testing**: All changes validated before merging to main

---

## Standard Workflow

### 1. Development Phase (on beta branch)

```bash
# Switch to beta branch
git checkout midiisc-v3-beta

# Make your changes to files
# Edit config.sh, build scripts, etc.

# Stage changes
git add <files>

# Commit with descriptive message
git commit -m "feature: Description of changes"

# Push to GitHub
git push origin midiisc-v3-beta
```

### 2. Testing Phase

- Test the changes in beta branch
- Build and verify the container
- Run test scripts (locally kept)
- Validate all functionality

### 3. Release Phase (merge to main)

```bash
# Ensure beta is up to date
git checkout midiisc-v3-beta
git pull origin midiisc-v3-beta

# Switch to main
git checkout main
git pull origin main

# Merge beta into main
git merge midiisc-v3-beta -m "Release: Description of changes"

# Push to GitHub
git push origin main

# Update beta to match main (keep them synced)
git checkout midiisc-v3-beta
git merge main --ff-only
git push origin midiisc-v3-beta
```

---

## Quick Reference Commands

### Check Current Branch
```bash
git branch -vv
```

### View Status
```bash
git status
```

### View Commit History
```bash
git log --oneline -10
```

### Compare Branches
```bash
git log main..midiisc-v3-beta --oneline
```

### Sync Both Branches (when they should be identical)
```bash
git checkout main
git merge midiisc-v3-beta --ff-only
git checkout midiisc-v3-beta
```

---

## File Categories

### Tracked by Git (Committed to Repository)
- `README.md` - Documentation
- `config.sh` - Centralized configuration
- `build_xubuntu_robotics_base.sh` - Main build script
- `xubuntu_robotics_base_post_ULTRA_CLEANED.sh` - Post-install script
- `create_writable_overlay.sh` - Overlay management
- `run_on_best_node.sh` - HPC job submission
- `setup_conda_environments.sh` - Environment setup
- `.gitignore` - Git ignore rules

### Ignored by Git (Local Development Only)
- `run_test_clean.sh` - Test runner
- `test_3d_recon_build.sh` - 3D reconstruction tests
- `RESTORE_TEST_FILES.md` - Restoration guide
- `container_cache/` - Build cache
- `build_logs/` - Build logs
- `*.sif`, `*.def` - Container images

---

## Commit Message Guidelines

### Format
```
<type>: <description>

[optional body]
```

### Types
- `feat` or `feature`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Test additions or changes
- `chore`: Maintenance tasks

### Examples
```bash
git commit -m "feat: Add CUDA 12.6 support for A6000 GPU"
git commit -m "fix: PyCOLMAP installation from correct directory"
git commit -m "docs: Update README with Open3D 0.19 features"
```

---

## Current Status (as of 2025-10-27)

### Repository
- **URL**: https://github.com/midiisc/Singularity_image_creation_script_xubuntu_robotics_base
- **Default Branch**: main
- **Development Branch**: midiisc-v3-beta

### Latest Commit
- **Commit**: 8d813d5
- **Message**: "Update .gitignore: Exclude RESTORE_TEST_FILES.md from repository"
- **Status**: Both branches synced to this commit

### Key Features
- ✅ Modular build system with centralized config
- ✅ PyCOLMAP 3.12.6 Python bindings support
- ✅ Open3D 0.19.0 with CUDA 12 and Python 3.12
- ✅ Comprehensive caching system
- ✅ CUDA 12.6 + cuDNN 9.14 support
- ✅ Optimized for NVIDIA A6000 (sm_86)
- ✅ x86-64-v3 CPU optimizations

---

## Troubleshooting

### Branch Out of Sync
```bash
# Reset beta to match main
git checkout midiisc-v3-beta
git reset --hard main
git push origin midiisc-v3-beta --force
```

### Undo Last Commit (Local Only)
```bash
git reset --soft HEAD~1  # Keep changes staged
# or
git reset --hard HEAD~1  # Discard changes
```

### View What Changed
```bash
git diff main..midiisc-v3-beta
```

---

## Best Practices

1. **Always work on beta branch** for new features
2. **Test thoroughly** before merging to main
3. **Keep commits atomic** (one logical change per commit)
4. **Write clear commit messages**
5. **Pull before pushing** to avoid conflicts
6. **Keep both branches synced** after releases
7. **Don't commit test files** (they're in .gitignore)
8. **Update README.md** when adding new features

---

**Last Updated**: 2025-10-27
**Maintainer**: Midhun S Menon

