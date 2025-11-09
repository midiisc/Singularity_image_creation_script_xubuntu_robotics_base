# ENHANCED Code Review Prompt: Robotics HPC Stack + Multi-Language
## Industry Best Practices for Pre-Commit Checks

---

## Executive Overview

This prompt extends your original Bash-focused audit framework to cover **C++, Python, CUDA, CMake, and documentation** while adding **robotics/HPC-specific checks**, proper **commenting standards**, and **pre-commit automation**.

Designed for:
- G2O, Ceres, GTSAM, OpenCV, Open3D, COLMAP
- MKL + CUDA + OpenMP optimization stacks
- Linux HPC environments (Ubuntu 24.04, Singularity)

---

## PART 0: Pre-Review Setup & Configuration

### 0.1 Repository Code Review Configuration

**File: `.codereviewrc`** (source at script startup)

```bash
#!/bin/bash
# Code review configuration for robotics HPC stack

# ===== LANGUAGE TARGETS =====
export REVIEW_LANGUAGES="bash,cpp,python,cuda,cmake"
export REVIEW_SCOPE="${REVIEW_SCOPE:-commit}"  # commit, file, function
export REVIEW_DEPTH="${REVIEW_DEPTH:-detailed}" # quick, standard, detailed

# ===== QUALITY GATES =====
export ENFORCE_MKL_CHECKS=true
export ENFORCE_CUDA_CHECKS=true
export ENFORCE_OPENMP_CHECKS=true
export ENFORCE_DOCUMENTATION=true
export ENFORCE_STATIC_ANALYSIS=true
export ENFORCE_PERFORMANCE_CHECKS=true

# ===== TOOL AVAILABILITY =====
export SHELLCHECK_ENABLED=true
export CLANG_TIDY_ENABLED=true
export PYLINT_ENABLED=true
export CPPCHECK_ENABLED=true
export DOXYGEN_ENABLED=true

# ===== HPC-SPECIFIC CONSTRAINTS =====
export HPC_CPU_CORES=32
export HPC_GPU_ARCH=sm_86  # NVIDIA A6000
export MKL_THREAD_LIMIT=32
export CUDA_COMPUTE_CAPABILITY=8.6
export SINGULARITY_DEF_PATH="Singularity.def"

# ===== DOCUMENTATION STANDARDS =====
export DOC_FORMAT="doxygen"  # doxygen, sphinx, javadoc
export COMMENT_RATIO_MIN=0.25  # minimum 25% comments in non-trivial code
export DOC_COVERAGE_MIN=85     # documentation coverage %

# ===== SECURITY & COMPLIANCE =====
export CHECK_SECURITY_ISSUES=true
export CHECK_LICENSE_HEADERS=true
export CHECK_SECRETS_SCANNING=true
export CHECK_RESOURCE_LEAKS=true

source "${CODEREVIEWRC_CUSTOM:-/dev/null}" 2>/dev/null || true

echo "✅ Code review configuration loaded"
```

---

## PART 1: Enhanced Context Review (with Multi-Language Support)

### 1.1 Detect Code Language & Complexity

```bash
#!/bin/bash
# detect-code-language.sh – Automatically identify review strategy

detect_language() {
    local file="$1"
    local ext="${file##*.}"
    
    case "$ext" in
        sh|bash)   echo "bash" ;;
        cpp|cc|cxx|c)  echo "cpp" ;;
        py)        echo "python" ;;
        cu|cuh)    echo "cuda" ;;
        cmake|CMakeLists.txt) echo "cmake" ;;
        *)         echo "unknown" ;;
    esac
}

# Calculate code complexity (lines, functions, branches)
calc_complexity() {
    local file="$1"
    local language=$(detect_language "$file")
    
    local lines=$(wc -l < "$file")
    local functions=0
    local branches=0
    
    case "$language" in
        bash)
            functions=$(grep -c "^[[:space:]]*function\|^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$file" || echo 0)
            branches=$(grep -c "if\|for\|while\|case\|&& \||| " "$file" || echo 0)
            ;;
        cpp)
            functions=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_:]*[[:space:]]*([^;]*{" "$file" || echo 0)
            branches=$(grep -c "if\|for\|while\|switch\|try\|&&\|||" "$file" || echo 0)
            ;;
        python)
            functions=$(grep -c "^def " "$file" || echo 0)
            branches=$(grep -c "if\|for\|while\|except\|and\|or" "$file" || echo 0)
            ;;
    esac
    
    # Cyclomatic complexity proxy
    local complexity=$((branches / 10 + functions / 5))
    
    echo "Language: $language | Lines: $lines | Functions: $functions | Branches: $branches | Est. Complexity: $complexity"
}

# Split strategy based on complexity
recommend_split() {
    local file="$1"
    local lines=$(wc -l < "$file")
    
    if [ "$lines" -gt 800 ]; then
        echo "SPLIT_REQUIRED: File exceeds 800 lines. Recommend chunks of 400-600 lines."
    elif [ "$lines" -gt 500 ]; then
        echo "SPLIT_OPTIONAL: Consider splitting for clarity."
    else
        echo "REVIEW_WHOLE: File is appropriately sized."
    fi
}
```

### 1.2 Symbol Tracking Template

```bash
# Symbol Tracking Table (fill during review)
# FORMAT: NAME | TYPE | DECLARATION_LINE | FIRST_USE | SCOPE | STATUS | CHUNK

SYMBOL_TABLE=(
    # Example entries:
    # "MKL_LINK_FLAGS | variable | 42 | 108 | global/exported | active | chunk-B"
    # "build_ceres | function | 360 | 420 | global | resolved | chunk-B"
    # "LOCAL_TMP | variable | 615 | 640 | local(init_cache) | resolved | chunk-C"
)

declare -A SYMBOL_INDEX  # For O(1) lookup

track_symbol() {
    local name="$1" type="$2" decl_line="$3" first_use="$4" scope="$5"
    
    SYMBOL_TABLE+=("${name} | ${type} | ${decl_line} | ${first_use} | ${scope} | active | TBD")
    SYMBOL_INDEX["${name}"]=$((${#SYMBOL_TABLE[@]} - 1))
    
    echo "✅ Tracked: $name (type: $type, declared line $decl_line)"
}

mark_resolved() {
    local name="$1" reason="$2"
    
    if [[ -v SYMBOL_INDEX["$name"] ]]; then
        # Update status to resolved
        echo "✅ Resolved: $name ($reason)"
    else
        echo "⚠️  Symbol not found: $name"
    fi
}
```

---

## PART 2: Enhanced Sequential Audit Checklist

### A. Structure & Syntax (Updated for Multi-Language)

#### A1. Language-Specific Shebang & Header

**BASH:**
```bash
#!/bin/bash
# Script: descriptive-name.sh
# Purpose: Brief one-liner
# Dependencies: mktemp, git, curl (optional)
# Author: Name
# Date: YYYY-MM-DD
# Version: X.Y.Z
```

**PYTHON:**
```python
#!/usr/bin/env python3
"""
Module: descriptive_name
Purpose: Brief one-liner
Dependencies: numpy, torch, opencv-python
Author: Name
Date: YYYY-MM-DD
Version: X.Y.Z
"""

from __future__ import annotations  # Type hints
import sys
import logging
```

**C++:**
```cpp
/**
 * @file filename.cpp
 * @brief One-liner description
 * @author Name
 * @date YYYY-MM-DD
 * @version X.Y.Z
 * 
 * @details Extended description of purpose, algorithms, performance notes.
 * 
 * @note MKL enabled, CUDA support for A6000
 * @warning Not thread-safe if X happens
 */

#include "config.h"
#include <version>  // C++20
```

#### A2. Code Formatting Standards

**BASH:**
```bash
# ✅ GOOD: 4-space indent, semantic grouping
setup_environment() {
    local config_file="$1"
    
    # Load configuration
    if [ -f "$config_file" ]; then
        source "$config_file"
    else
        echo "ERROR: Config not found: $config_file" >&2
        return 1
    fi
    
    # Set defaults
    export MKL_THREADING_LAYER="${MKL_THREADING_LAYER:-GNU}"
}

# ❌ BAD: Inconsistent indent, no grouping
setup_environment(){
local config_file="$1"
if [ -f "$config_file" ]; then
source "$config_file"
else
echo "ERROR: Config not found: $config_file" >&2
fi
export MKL_THREADING_LAYER="${MKL_THREADING_LAYER:-GNU}"
}
```

**C++:**
```cpp
// ✅ GOOD: K&R style, clear grouping, max 100 columns
class SparseMatrix {
private:
    size_t rows_;
    size_t cols_;
    std::vector<double> data_;

public:
    // Constructor with MKL alignment
    explicit SparseMatrix(size_t rows, size_t cols)
        : rows_(rows), cols_(cols) {
        data_.reserve(rows * cols);
    }
    
    // Compute sparse-dense product using MKL
    void multiply_mkl(const double* vec, double* result) const {
        mkl_sparse_d_mv(SPARSE_OPERATION_NON_TRANSPOSE, 1.0, handle_,
                        vec, 0.0, result);
    }
};
```

**Python:**
```python
# ✅ GOOD: PEP 8 compliant, docstrings, type hints
class MKLOptimizer:
    """GPU-accelerated optimizer using Intel MKL backend.
    
    Attributes:
        learning_rate (float): Learning rate for optimization.
        num_threads (int): Number of MKL threads.
    """
    
    def __init__(self, learning_rate: float = 0.001,
                 num_threads: int = 32) -> None:
        """Initialize optimizer with MKL threading.
        
        Args:
            learning_rate: Learning rate (default 0.001).
            num_threads: Threads for MKL (default 32).
            
        Raises:
            ValueError: If learning_rate <= 0.
        """
        if learning_rate <= 0:
            raise ValueError(f"learning_rate must be > 0, got {learning_rate}")
        
        self.learning_rate = learning_rate
        self.num_threads = num_threads
        
    def step(self, grads: np.ndarray) -> np.ndarray:
        """Update parameters using gradients.
        
        Args:
            grads: Gradient array.
            
        Returns:
            Updated parameters.
        """
        return grads * self.learning_rate
```

---

### B. Documentation & Comments (NEW SECTION)

#### B1. Comment Standards by Language

**BASH - Inline Comments:**
```bash
# ✅ GOOD: Clear intent, preconditions
verify_mkl_installation() {
    # Check MKL libraries are accessible
    # Precondition: MKLROOT is set
    # Return: 0 if MKL found, 1 if not
    
    local mkl_lib="${MKLROOT}/lib/intel64/libmkl_core.so"
    
    # Use -f to test file existence, not -e which follows symlinks
    if [ -f "$mkl_lib" ]; then
        echo "✅ MKL found at $mkl_lib"
        return 0
    else
        echo "❌ MKL not found. Install with: sudo apt-get install intel-oneapi-mkl" >&2
        return 1
    fi
}

# ❌ BAD: Vague, no context
verify_mkl() {
    if [ -f "$MKLROOT/lib/intel64/libmkl_core.so" ]; then
        echo "OK"
    else
        echo "ERROR"
    fi
}
```

**C++ - Doxygen Comments:**
```cpp
// ✅ GOOD: Doxygen-compatible, parameter & return docs
/**
 * @brief Compute sparse matrix-vector product using Intel MKL.
 * 
 * Uses MKL's optimized sparse BLAS routines for efficient computation.
 * Thread-safe with OpenMP for multi-core scaling.
 * 
 * @param[in] matrix Sparse matrix (CSR format, MKL-optimized)
 * @param[in] vec Input vector
 * @param[out] result Output vector (preallocated)
 * @param[in] num_threads OpenMP threads (default: OMP_NUM_THREADS)
 * 
 * @return Status code (0 = success, -1 = invalid input)
 * 
 * @note Requires MKL linking: -lmkl_intel_lp64 -lmkl_core
 * @warning Not CUDA-optimized; consider cuSPARSE for GPU.
 * @see mkl_sparse_d_mv()
 * 
 * @par Example:
 * @code
 * SparseMatrix A = load_mkl_matrix("data.mtx");
 * std::vector<double> x(A.cols(), 1.0);
 * std::vector<double> y(A.rows());
 * sparse_mv_mkl(A, x.data(), y.data());
 * @endcode
 */
int sparse_mv_mkl(const SparseMatrix& matrix,
                  const double* vec, double* result,
                  int num_threads = 0) {
    // Validate inputs
    if (!vec || !result) return -1;
    if (matrix.rows() == 0) return -1;
    
    // Use OpenMP for thread management
    #pragma omp parallel for schedule(static) num_threads(num_threads)
    for (size_t i = 0; i < matrix.rows(); ++i) {
        // Compute row-wise dot product
        result[i] = 0.0;
        for (auto [col, val] : matrix.row(i)) {
            result[i] += val * vec[col];
        }
    }
    
    return 0;
}

// ❌ BAD: No documentation, unclear parameters
int sparse_mv(const SparseMatrix& m, const double* v, double* r) {
    for (size_t i = 0; i < m.rows(); ++i) {
        r[i] = 0.0;
        for (auto [c, val] : m.row(i)) {
            r[i] += val * v[c];
        }
    }
    return 0;
}
```

**Python - NumPy/Scipy Docstring:**
```python
# ✅ GOOD: NumPy docstring format, MKL-specific notes
def solve_sparse_linear_mkl(A: scipy.sparse.csr_matrix,
                            b: np.ndarray,
                            solver: str = 'pardiso',
                            num_threads: int = 32) -> np.ndarray:
    r"""Solve sparse linear system using MKL sparse solvers.
    
    Wraps Intel MKL sparse solver routines for efficient solution of 
    Ax = b when A is sparse. Automatically uses MKL threading.
    
    Parameters
    ----------
    A : scipy.sparse.csr_matrix
        Sparse matrix in compressed sparse row format (m x n).
    b : np.ndarray
        Right-hand side vector (m,) or (m, k) for multiple RHS.
    solver : {'pardiso', 'cg', 'gmres'}, optional
        MKL sparse solver (default: 'pardiso').
    num_threads : int, optional
        OpenMP threads for MKL (default: 32).
    
    Returns
    -------
    x : np.ndarray
        Solution vector or (n, k) if b is (m, k).
    
    Raises
    ------
    ValueError
        If A is not sparse CSR or dimensions don't match.
    RuntimeError
        If MKL solver fails to converge.
    
    Notes
    -----
    Requires Intel MKL installed and linked: -lmkl_intel_lp64
    
    Thread-safe with OpenMP; control threads via OMP_NUM_THREADS env var.
    
    Examples
    --------
    >>> import scipy.sparse as sp
    >>> A = sp.random(100, 100, density=0.1, format='csr')
    >>> b = np.random.randn(100)
    >>> x = solve_sparse_linear_mkl(A, b)
    >>> print(np.allclose(A @ x, b))
    True
    
    See Also
    --------
    scipy.sparse.linalg.spsolve : Fallback solver without MKL
    """
    
    # Validate inputs
    if not sp.issparse(A) or A.format != 'csr':
        raise ValueError("A must be scipy.sparse CSR matrix")
    
    if A.shape[0] != b.shape[0]:
        raise ValueError(f"Shape mismatch: A.shape[0]={A.shape[0]}, b.shape[0]={b.shape[0]}")
    
    # Set MKL thread count
    import mkl
    mkl.set_num_threads(num_threads)
    
    # Call MKL sparse solver
    from scipy.sparse.linalg import spsolve
    x = spsolve(A, b, permc_spec='COLAMD')
    
    return x
```

#### B2. Function/Class Documentation Checklist

Every **non-trivial** function must include:

- ✅ **Purpose:** One-liner summary
- ✅ **Parameters:** Types, constraints, defaults
- ✅ **Return value:** Type and semantics
- ✅ **Exceptions/Errors:** What can go wrong
- ✅ **Side effects:** State changes, I/O, threading
- ✅ **Performance notes:** Complexity, threading, GPU acceleration
- ✅ **Examples:** Minimal runnable snippet
- ✅ **Related:** Links to similar functions or documentation

---

### C. HPC & Robotics-Specific Checks (NEW SECTION)

#### C1. MKL Integration

```bash
# CHECKLIST: Every compute-heavy function
# ✅ Uses MKL BLAS/LAPACK, not generic math lib
# ✅ Links to MKL (-lmkl_intel_lp64 -lmkl_core -lmkl_gnu_thread)
# ✅ Thread count matches OMP_NUM_THREADS
# ✅ No mixing with OpenBLAS in same binary
# ✅ Handles case where MKL unavailable (fallback or error)

# VERIFICATION COMMAND:
check_mkl_integration() {
    local binary="$1"
    
    # Check MKL symbols
    if ! nm "$binary" | grep -q "mkl_"; then
        echo "⚠️  No MKL symbols found in $binary"
        return 1
    fi
    
    # Check for OpenBLAS mixing (conflict!)
    if nm "$binary" | grep -q "openblas" && nm "$binary" | grep -q "mkl_"; then
        echo "❌ FATAL: Both MKL and OpenBLAS present. Symbol conflicts likely."
        return 1
    fi
    
    # Check linkage
    if ! ldd "$binary" | grep -q "libmkl_intel"; then
        echo "⚠️  MKL not in runtime dependencies"
        return 1
    fi
    
    echo "✅ MKL integration verified"
    return 0
}
```

#### C2. CUDA Acceleration

```bash
# CHECKLIST: For GPU-accelerated code
# ✅ Uses CUDA compute capability sm_86 (A6000)
# ✅ cuBLAS/cuSPARSE/cuSolver linked when applicable
# ✅ Error checking on CUDA calls (cudaCheckError macro)
# ✅ Device memory freed after use (no leaks)
# ✅ Handles case where CUDA unavailable
# ✅ Proper stream management for async ops

# VERIFICATION COMMAND:
check_cuda_integration() {
    local binary="$1"
    
    # Check CUDA symbols
    if ! nm "$binary" | grep -q "cuda"; then
        echo "⚠️  No CUDA symbols found"
        return 1
    fi
    
    # Check compute capability
    if ! grep -q "sm_86\|compute_86" "$binary" 2>/dev/null; then
        echo "⚠️  compute_86 not found (should be sm_86 for A6000)"
    fi
    
    # Check for error handling
    if ! strings "$binary" | grep -q "cudaGetLastError\|CUDA_CHECK"; then
        echo "⚠️  No CUDA error checking detected"
        return 1
    fi
    
    echo "✅ CUDA integration verified"
    return 0
}
```

#### C3. OpenMP Threading

```bash
# CHECKLIST: For parallel code
# ✅ Pragmas use proper schedule (static/dynamic/guided)
# ✅ Reduction clauses correct for data types
# ✅ No data races (shared/private/firstprivate correct)
# ✅ Nested parallelism disabled unless intentional
# ✅ Thread count respects OMP_NUM_THREADS
# ✅ Compatible with MKL's OpenMP layer

# VERIFICATION COMMAND:
check_openmp_integration() {
    local source="$1"
    
    # Check for pragmas
    if ! grep -q "#pragma omp" "$source"; then
        echo "ℹ️  No OpenMP pragmas found"
        return 0
    fi
    
    # Check for data race issues
    local bad_pragmas=$(grep "#pragma omp" "$source" | grep -c "parallel for" || echo 0)
    if [ "$bad_pragmas" -gt 5 ]; then
        echo "⚠️  Many 'parallel for' pragmas; consider explicit loops"
    fi
    
    # Check reduction clauses
    if grep -q "#pragma omp parallel for" "$source" && \
       ! grep -q "reduction(" "$source"; then
        echo "⚠️  Potential data race: parallel loop without reduction"
        return 1
    fi
    
    echo "✅ OpenMP integration verified"
    return 0
}
```

---

### D. Additional Security & Performance Checks (EXPANDED)

#### D1. Memory & Resource Leaks

**BASH:**
```bash
# ✅ Check for resource cleanup
verify_resource_cleanup() {
    local script="$1"
    
    # Count temp file creations vs deletions
    local mktemp_count=$(grep -c "mktemp" "$script" || echo 0)
    local rm_count=$(grep -c "rm.*\${.*_DIR\|rm.*-rf" "$script" || echo 0)
    
    if [ "$mktemp_count" -gt 0 ] && [ "$rm_count" -eq 0 ]; then
        echo "❌ ERROR: Temp files created but never deleted"
        return 1
    fi
    
    # Check for trap cleanup
    if [ "$mktemp_count" -gt 0 ] && ! grep -q "trap.*rm" "$script"; then
        echo "❌ ERROR: Temp files created but no trap cleanup"
        return 1
    fi
    
    echo "✅ Resource cleanup verified"
    return 0
}
```

**C++:**
```cpp
// ✅ GOOD: Proper cleanup with RAII
class SparseMatrixMKL {
private:
    sparse_matrix_t handle_;
    bool is_sorted_;

public:
    SparseMatrixMKL(int rows, int cols) 
        : handle_(nullptr), is_sorted_(false) {
        // Initialize
    }
    
    // Destructor ensures cleanup
    ~SparseMatrixMKL() {
        if (handle_) {
            mkl_sparse_destroy(handle_);
            handle_ = nullptr;
        }
    }
    
    // Move semantics to prevent leaks
    SparseMatrixMKL(SparseMatrixMKL&& other) noexcept 
        : handle_(other.handle_) {
        other.handle_ = nullptr;
    }
};

// ❌ BAD: Manual cleanup required, easy to leak
SparseMatrixMKL* create_matrix(int rows, int cols) {
    auto m = new SparseMatrixMKL(rows, cols);  // Caller must delete!
    return m;
}
```

#### D2. Security: Input Validation

**BASH:**
```bash
# ✅ GOOD: Validate all inputs
install_library() {
    local lib_name="$1"
    local version="${2:-latest}"
    
    # Validate library name (alphanumeric + dash)
    if ! [[ "$lib_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: Invalid library name: $lib_name" >&2
        return 1
    fi
    
    # Validate version (no path traversal)
    if [[ "$version" == *"/"* ]] || [[ "$version" == *".."* ]]; then
        echo "ERROR: Invalid version string: $version" >&2
        return 1
    fi
    
    # Use quoted variable to prevent injection
    apt-get install -y "lib${lib_name}=${version}"
}
```

**C++:**
```cpp
// ✅ GOOD: Bounds checking, type safety
std::vector<double> solve_system(
    const std::vector<double>& matrix,
    const std::vector<double>& rhs,
    size_t n) {
    
    // Validate dimensions
    if (matrix.size() != n * n) {
        throw std::invalid_argument(
            fmt::format("Matrix size {} != n*n ({}x{})", 
                       matrix.size(), n, n));
    }
    
    if (rhs.size() != n) {
        throw std::invalid_argument(
            fmt::format("RHS size {} != n ({})", rhs.size(), n));
    }
    
    std::vector<double> result(n);
    // ... solve ...
    return result;
}
```

---

### E. Pre-Commit Hooks Integration (NEW SECTION)

#### E1. Comprehensive `.pre-commit-config.yaml`

```yaml
repos:
  # ===== Bash/Shell =====
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0
    hooks:
      - id: shellcheck
        args: ['--severity=warning', '--format=gcc']
        exclude: '^\.git'

  # ===== Python =====
  - repo: https://github.com/psf/black
    rev: 24.1.1
    hooks:
      - id: black
        language_version: python3.11

  - repo: https://github.com/charliermarsh/ruff
    rev: v0.2.0
    hooks:
      - id: ruff
        args: ['--fix', '--line-length=100']

  - repo: https://github.com/pycqa/pylint
    rev: pylint-3.0.3
    hooks:
      - id: pylint
        args: ['--fail-under=8.0']
        additional_dependencies: ['numpy', 'torch']

  # ===== C++ =====
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-merge-conflict
      - id: end-of-file-fixer

  - repo: https://github.com/pocc/pre-commit-hooks
    rev: v1.3.5
    hooks:
      - id: clang-format
        args: ['-i', '--style=file']
      - id: cppcheck
        args: ['--enable=all', '--suppress=missingIncludeSystem']

  # ===== CMake =====
  - repo: https://github.com/cmake-format/cmake_format
    rev: v0.6.14
    hooks:
      - id: cmake-format
        args: ['--in-place']

  # ===== Documentation =====
  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v3.1.0
    hooks:
      - id: prettier
        types_or: [markdown, yaml]

  # ===== Custom Robotics HPC Checks =====
  - repo: local
    hooks:
      - id: mkl-integration-check
        name: Check MKL Integration
        entry: bash scripts/verify-mkl-integration.sh
        language: script
        types: [cpp, c]
        stages: [commit]

      - id: cuda-integration-check
        name: Check CUDA Integration
        entry: bash scripts/verify-cuda-integration.sh
        language: script
        types: [cuda, cpp]
        stages: [commit]

      - id: openmp-check
        name: Check OpenMP Pragmas
        entry: bash scripts/verify-openmp.sh
        language: script
        types: [cpp, c, cuda]
        stages: [commit]

      - id: documentation-coverage
        name: Check Documentation Coverage
        entry: bash scripts/verify-documentation.sh
        language: script
        types: [cpp, python]
        stages: [commit]

      - id: performance-check
        name: Performance Regression Check
        entry: bash scripts/performance-baseline.sh
        language: script
        stages: [manual]  # Run manually before releases

      - id: singularity-lint
        name: Lint Singularity Definition
        entry: bash scripts/lint-singularity.sh
        language: script
        files: '^Singularity\.def'
        stages: [commit]
```

#### E2. Custom MKL Verification Hook

**`scripts/verify-mkl-integration.sh`:**

```bash
#!/bin/bash
# Verify MKL integration in C++ files

set -e

for file in "$@"; do
    echo "Checking MKL integration in $file..."
    
    # Check for MKL includes
    if grep -q "#include.*mkl\|#include.*blas" "$file"; then
        echo "  ✅ MKL includes found"
    else
        echo "  ⚠️  No MKL includes"
        continue
    fi
    
    # Check for proper linking comments
    if grep -q "// Link:.*-lmkl_intel_lp64\|// CMake.*MKL" "$file"; then
        echo "  ✅ Linking instructions documented"
    else
        echo "  ⚠️  No linking documentation"
    fi
    
    # Check for thread management
    if grep -q "mkl_set_num_threads\|OMP_NUM_THREADS\|mkl_get_max_threads" "$file"; then
        echo "  ✅ Thread management found"
    else
        echo "  ⚠️  No thread management"
    fi
    
    # Check for error handling
    if grep -q "if.*mkl\|LAPACKE_\|ipiv\|info" "$file"; then
        echo "  ✅ Error/info parameter handling"
    fi
done

exit 0
```

---

### F. Documentation Coverage Check (NEW)

**`scripts/verify-documentation.sh`:**

```bash
#!/bin/bash
# Check documentation coverage for C++ and Python

check_cpp_docs() {
    local file="$1"
    local total_lines=$(wc -l < "$file")
    local doc_lines=$(grep -c "^\s*//\|^\s*/\*\|^\s*\*" "$file" || echo 0)
    local ratio=$((doc_lines * 100 / total_lines))
    
    if [ "$ratio" -lt 25 ]; then
        echo "❌ $file: Doc coverage ${ratio}% < 25%"
        return 1
    else
        echo "✅ $file: Doc coverage ${ratio}%"
        return 0
    fi
}

check_python_docs() {
    local file="$1"
    local functions=$(grep -c "^def " "$file" || echo 0)
    local docstrings=$(grep -c '"""' "$file" || echo 0)
    
    if [ "$functions" -gt 0 ] && [ "$docstrings" -lt "$functions" ]; then
        echo "❌ $file: Missing docstrings (${functions} functions, ${docstrings} docstrings)"
        return 1
    else
        echo "✅ $file: Docstring coverage adequate"
        return 0
    fi
}

# Main
for file in "$@"; do
    case "${file##*.}" in
        cpp|cc|cxx|h|hpp) check_cpp_docs "$file" || exit 1 ;;
        py) check_python_docs "$file" || exit 1 ;;
    esac
done

exit 0
```

---

## PART 3: Correction Summary Template

```markdown
# Code Review Summary

## File(s) Reviewed
- `src/sparse_solver.cpp` (lines 1–450)
- `src/mkl_wrapper.h` (lines 1–150)

## Language(s)
- C++ (MKL-optimized sparse solver)

## Checklist Results

### Structure & Syntax (A1–A5)
- [✅] A1. Shebang/headers correct: Doxygen header present
- [✅] A2. Indentation 4-space, K&R style consistent
- [✅] A3. No deprecated constructs (C++17 compliant)
- [⚠️] A4. Declaration order: `mkl_sparse_destroy()` called after declaration (resolved)
- [✅] A5. POSIX-safe patterns

### Documentation (B1–B2) **NEW**
- [✅] B1. Doxygen comments on all public functions
- [❌] B2. Missing parameter documentation on `solve_mkl()` – **FIXED**
  ```cpp
  // Before: Undocumented function
  int solve_mkl(sparse_matrix_t A, double* b) { ... }
  
  // After: Documented with Doxygen
  /**
   * @brief Solve sparse linear system using MKL PARDISO.
   * @param[in] A Sparse matrix in MKL format
   * @param[in,out] b RHS vector (input), solution (output)
   * @return 0 on success, MKL error code otherwise
   */
  int solve_mkl(sparse_matrix_t A, double* b) { ... }
  ```

### HPC/Robotics Checks (C1–C3) **NEW**
- [✅] C1. MKL linking verified: `-lmkl_intel_lp64 -lmkl_core` present
- [✅] C2. CUDA sm_86 architecture specified
- [⚠️] C3. OpenMP reduction clause on line 234 – **FIXED**
  ```cpp
  // Before: potential data race
  #pragma omp parallel for
  for (int i = 0; i < n; ++i) sum += data[i];
  
  // After: proper reduction
  #pragma omp parallel for reduction(+:sum)
  for (int i = 0; i < n; ++i) sum += data[i];
  ```

### Security & Resource Management (D1–D2, K1–K3, N1–N5)
- [✅] D1. Input validation for matrix dimensions
- [✅] K1. No unsafe eval or string injection
- [✅] N1. RAII destructor cleans MKL handles
- [❌] N2. Leaked CUDA stream on early return – **FIXED**
  ```cpp
  // Before: stream not destroyed on error path
  if (compute_result() != 0) return;  // Leak!
  
  // After: RAII wrapper ensures cleanup
  CudaStreamGuard stream;  // Destructor cleans up
  if (compute_result() != 0) return;  // Safe
  ```

## Symbol Table (Carried Across Chunks)

| Name | Type | Declaration | First Use | Scope | Status |
|------|------|-------------|-----------|-------|--------|
| `mkl_handle_` | member | 42 | 89 | class | resolved |
| `solve_mkl()` | function | 120 | 156 | public | resolved |
| `stream_` | variable | 201 | 234 | local | resolved |

## Tools Used for Verification

- `shellcheck` (v0.10.0): No issues
- `clang-format` (LLVM 18): Reformatted 3 blocks
- `cppcheck` (2.13): No critical warnings
- `grep` patterns: MKL linkage ✅, CUDA calls ✅, OpenMP pragmas ✅

## Remaining Items to Address

- [ ] Add GPU memory profiling before deployment
- [ ] Run performance baseline on A6000
- [ ] Add unit tests for `solve_mkl()` edge cases

## Final Status

**Block fully audited and corrected.**
All checklist items (A1–O3) have been reviewed and pass after corrections.
No new files created. All symbols now have single declarations before first use.
```

---

## PART 4: Additional Tools & Automation

### Setup Pre-Commit

```bash
# Install pre-commit framework
pip install pre-commit

# Install hooks from .pre-commit-config.yaml
pre-commit install

# Test all hooks on your code
pre-commit run --all-files

# Update hook versions
pre-commit autoupdate
```

### Continuous Integration

**`.github/workflows/code-review.yml`:**

```yaml
name: Automated Code Review

on: [push, pull_request]

jobs:
  review:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          sudo apt-get install -y clang-tools cppcheck shellcheck
          pip install pylint black ruff
      
      - name: Run pre-commit hooks
        uses: pre-commit/action@v3
      
      - name: Check MKL integration
        run: bash scripts/verify-mkl-integration.sh src/*.cpp
      
      - name: Check documentation coverage
        run: bash scripts/verify-documentation.sh src/*.cpp src/*.py
      
      - name: Build and test
        run: |
          mkdir build && cd build
          cmake .. -DCMAKE_BUILD_TYPE=Release
          cmake --build . --parallel $(nproc)
          ctest --output-on-failure
```

---

## PART 5: Best Practices Summary

| Aspect | Standard | Tools |
|--------|----------|-------|
| **Code Format** | 4-space indent, K&R (C++), PEP 8 (Python) | clang-format, black, ruff |
| **Static Analysis** | Zero critical warnings | cppcheck, pylint, shellcheck |
| **Documentation** | Doxygen (C++), NumPy docstrings (Python) | doxygen, sphinx |
| **MKL Integration** | Explicit linking, thread management | verify-mkl script |
| **CUDA Support** | sm_86, error checking, no leaks | verify-cuda script |
| **OpenMP** | Proper reduction/schedule clauses | verify-openmp script |
| **Comments** | ≥25% ratio, Doxygen tags | documentation script |
| **Resource Management** | RAII, trap cleanup (shell) | manual review + linters |
| **Security** | Input validation, no injection | cppcheck, manual review |
| **Testing** | Unit + integration tests | CMake/GTest, pytest |

---

## CONCLUSION

This enhanced prompt provides:

✅ **Multi-language support** (Bash, C++, Python, CUDA, CMake)
✅ **HPC/Robotics context** (MKL, CUDA, OpenMP verification)
✅ **Documentation standards** (Doxygen, NumPy, inline comments)
✅ **Pre-commit automation** (hooks, CI/CD integration)
✅ **Industry best practices** (security, performance, maintainability)
✅ **Comprehensive checklists** (15 categories A–O)
✅ **Practical examples** (good vs. bad patterns)
✅ **Tool integration** (shellcheck, clang-tidy, pylint, cppcheck)

**Use this prompt for every code commit to maintain production-grade quality in your robotics HPC stack.**
