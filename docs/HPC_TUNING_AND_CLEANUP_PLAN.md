# HPC Tuning and Script Cleanup Plan

**Objective:** Complete pending MKL integration tasks and remove unnecessary scripts for monolithic Singularity image builds targeting HPC deployment (A6000 GPU).

**Date:** 2025-01-XX

---

## Part 1: Complete Pending Actions

### 1.1 Advanced HPC Tuning (Thread Affinity)

**Action:** Create `/etc/profile.d/hpc-mkl-tune.sh` in the orchestrator script (Block 12A, after MKL environment setup)

**Content:**
```bash
#!/bin/bash
# HPC MKL/CUDA Runtime Tuning
# Optimized for A6000 GPU and multi-core CPU systems

# Thread Affinity Settings (OpenMP)
export OMP_PROC_BIND="${OMP_PROC_BIND:-close}"
export OMP_PLACES="${OMP_PLACES:-cores}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-32}"

# MKL Threading Configuration
export MKL_THREADING_LAYER="${MKL_THREADING_LAYER:-GNU}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-32}"
export MKL_DYNAMIC="${MKL_DYNAMIC:-FALSE}"  # Disable dynamic threading for HPC

# Intel MKL Thread Affinity (for compatibility)
export KMP_AFFINITY="${KMP_AFFINITY:-granularity=fine,compact,1,0}"

# CUDA Device Configuration
export CUDA_DEVICE_MAX_CONNECTIONS="${CUDA_DEVICE_MAX_CONNECTIONS:-1}"
export CUDA_LAUNCH_BLOCKING="${CUDA_LAUNCH_BLOCKING:-0}"  # Set to 1 for debugging

# Monitoring Toggles (disabled by default, enable when needed)
export MKL_VERBOSE="${MKL_VERBOSE:-0}"  # Set to 1 to enable MKL verbose output
export OMP_DISPLAY_ENV="${OMP_DISPLAY_ENV:-FALSE}"  # Set to TRUE to display OpenMP env

# Performance Hints
export MKL_INTERFACE_LAYER="${MKL_INTERFACE_LAYER:-LP64,ILP64}"
```

**Location:** Add after Block 12A.3 (MKL environment setup), around line ~2505

**Rationale:** Optimizes thread affinity for HPC workloads, disables dynamic threading for consistent performance, and provides monitoring toggles for debugging.

---

### 1.2 g2o CUDA Support (Experimental)

**Action:** Add `-DG2O_BUILD_CUDA=ON` to g2o CMake configuration

**Location:** Block 17, Sub-block 17.11 (g2o CMake configuration), around line ~5267

**Change:**
```bash
# Current (line ~5267):
cmake .. \
  -G Ninja \
  ...
  -D G2O_USE_CHOLMOD=ON \
  -D G2O_USE_CSPARSE=ON \
  -D G2O_USE_OPENMP=ON \
  ...

# Add after G2O_USE_OPENMP:
  -D G2O_BUILD_CUDA=ON \
```

**Note:** Marked as experimental in MKL_MIGRATION_PLAN.md. Will enable experimental CUDA solvers if available in g2o.

**Rationale:** Enables experimental CUDA acceleration in g2o for potential GPU-accelerated optimization.

---

## Part 2: Script Cleanup (MKL/CUDA Integration Scripts Only)

### 2.1 MKL/CUDA Integration Scripts to Remove

**Focus:** Only scripts created specifically for MKL/CUDA integration that are now redundant with the orchestrator.

#### Standalone MKL/CUDA Build Scripts
- ❌ `scripts/build-suitesparse-cuda.sh`
  - **Created for:** MKL + CUDA SuiteSparse build (Phase 3 of MKL migration)
  - **Reason:** Orchestrator now handles SuiteSparse build with MKL+CUDA (Block 12C)
  - **Status:** Redundant - functionality integrated into orchestrator
  - **Reference:** `docs/MKL_MIGRATION_PLAN.md` Phase 3.2

#### MKL/CUDA Setup Helper Scripts
- ❌ `scripts/setup-cuda-dev-local.sh`
  - **Created for:** Local PC CUDA development setup (Phase 1.1 of MKL migration)
  - **Reason:** For local PC development, not needed for HPC image builds
  - **Status:** Redundant - orchestrator handles CUDA installation (Block 13)
  - **Reference:** `docs/CUDA_BUILD_CHECKLIST.md` Section 1

- ❌ `scripts/install-suitesparse-cuda-deps.sh`
  - **Created for:** SuiteSparse CUDA dependencies installation (Phase 1.2 of MKL migration)
  - **Reason:** Orchestrator handles CUDA/cuDNN installation (Block 13)
  - **Status:** Redundant - functionality integrated into orchestrator
  - **Reference:** `docs/MKL_MIGRATION_PLAN.md` Phase 1.2

- ❌ `scripts/setup-apt-pins.sh`
  - **Created for:** APT pinning to protect MKL-built libraries (Phase 0.2 of MKL migration)
  - **Reason:** Orchestrator handles APT pinning inline (multiple blocks: Ceres, GTSAM, g2o, OpenCV, COLMAP, SuiteSparse)
  - **Status:** Redundant - functionality integrated into orchestrator
  - **Reference:** Script header mentions "Prevent system packages from replacing custom MKL builds"

### 2.2 MKL/CUDA Integration Scripts to Keep

#### MKL/CUDA Verification Scripts (Keep - Useful for HPC Validation)
- ✅ `scripts/verify-cuda-mkl-linkage.sh`
  - **Created for:** MKL/CUDA linkage verification (Phase 5.1 of MKL migration)
  - **Reason:** Useful for validating MKL/CUDA linkage on HPC node
  - **Status:** Keep - essential for HPC validation
  - **Reference:** `docs/MKL_MIGRATION_PLAN.md` Phase 5.1, `docs/CUDA_BUILD_CHECKLIST.md` Section 4

- ✅ `scripts/verify-mkl-env.sh`
  - **Created for:** MKL environment verification (Phase 2.4 of MKL migration)
  - **Reason:** Useful for validating MKL environment on HPC node
  - **Status:** Keep - essential for HPC validation
  - **Reference:** `docs/MKL_MIGRATION_PLAN.md` Phase 2.4, `docs/CUDA_BUILD_CHECKLIST.md` Section 4

#### Helper Scripts (Keep - Useful for HPC Operations)
- ✅ `scripts/helpers/create_writable_overlay.sh`
  - **Reason:** Referenced in `build_xubuntu_robotics_base.sh` (line 3661)
  - **Status:** Keep - useful for creating writable overlays on HPC

- ✅ `scripts/helpers/run_on_best_node.sh`
  - **Reason:** Useful for HPC job submission and node selection
  - **Status:** Keep - useful for HPC operations

- ✅ `scripts/helpers/setup_conda_environments.sh`
  - **Reason:** Referenced in orchestrator comments (lines 9766, 13515, 13550)
  - **Status:** Keep - useful for setting up conda environments in overlays

---

## Part 3: Implementation Steps

### Step 1: Add HPC Tuning Script
1. Locate Block 12A.3 in `xubuntu_robotics_base_post_ULTRA_CLEANED.sh` (after MKL environment setup)
2. Add heredoc to create `/etc/profile.d/hpc-mkl-tune.sh` with thread affinity settings
3. Source the script after creation
4. Add comment explaining purpose and A6000 optimization

### Step 2: Add g2o CUDA Support
1. Locate Block 17, Sub-block 17.11 (g2o CMake configuration)
2. Add `-D G2O_BUILD_CUDA=ON` flag after `G2O_USE_OPENMP=ON`
3. Add comment noting experimental status

### Step 3: Remove Unnecessary Scripts
1. Delete all scripts listed in Section 2.1
2. Update any documentation that references removed scripts
3. Check helper scripts (Section 2.2) and remove if not used

### Step 4: Update Documentation
1. Update `docs/MKL_INTEGRATION_STATUS.md` to mark HPC tuning and g2o CUDA as complete
2. Update `docs/MKL_MIGRATION_PLAN.md` status if needed
3. Document removed scripts in a changelog or commit message

---

## Part 4: Verification

After implementation:
1. Verify HPC tuning script is created and sourced during build
2. Verify g2o CMake includes `-DG2O_BUILD_CUDA=ON`
3. Verify removed scripts are not referenced anywhere
4. Test build process still works (if possible)

---

## Summary

**Files to Modify:**
- `xubuntu_robotics_base_post_ULTRA_CLEANED.sh` (add HPC tuning, add g2o CUDA flag)

**Files to Delete (MKL/CUDA Integration Scripts Only):**
- `scripts/build-suitesparse-cuda.sh` (standalone MKL+CUDA build - now in orchestrator)
- `scripts/setup-cuda-dev-local.sh` (local CUDA setup - not needed for HPC images)
- `scripts/install-suitesparse-cuda-deps.sh` (CUDA deps - now in orchestrator Block 13)
- `scripts/setup-apt-pins.sh` (MKL-specific APT pinning - now in orchestrator)

**Files to Keep (MKL/CUDA Integration Scripts):**
- MKL/CUDA verification scripts (2): `verify-cuda-mkl-linkage.sh`, `verify-mkl-env.sh`
- Helper scripts (3): `create_writable_overlay.sh`, `run_on_best_node.sh`, `setup_conda_environments.sh`

**Note:** General development tools (extract scripts, test scripts, pre-commit hooks) are NOT part of this cleanup as they were not created for MKL integration.

**Estimated Impact:**
- Remove 3-4 MKL/CUDA integration scripts that are now redundant
- Keep essential verification scripts for HPC validation
- Focused cleanup on MKL integration artifacts only
- General development tools remain untouched

---

## Approval Required

Please review this plan and approve before I proceed with:
1. Adding HPC tuning script
2. Adding g2o CUDA support
3. Removing unnecessary scripts

**Findings:**
- Helper scripts are referenced/used: `create_writable_overlay.sh` in build script, `setup_conda_environments.sh` in orchestrator comments
- All helper scripts will be kept as they're useful for HPC operations

**Questions:**
1. Any other MKL/CUDA integration scripts you want to keep that I've marked for removal?
2. Any additional HPC tuning settings you want in the tuning script?

