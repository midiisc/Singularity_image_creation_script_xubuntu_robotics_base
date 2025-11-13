# ENHANCED Code Review Prompt: Robotics HPC Stack + Multi-Language - PART 2
## Industry Best Practices for Pre-Commit Checks

**This is PART 2 of 3. See also:**
- `Enhanced-Code-Review-Prompt-PART1.md` - Part 1 (Pre-Review Setup, Context Review, Checklist start)
- `Enhanced-Code-Review-Prompt-PART3.md` - Part 3 (Correction Summary, Tools & Automation)

---

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

#### B1. File Header Documentation (MANDATORY):
- ✅ **REQUIRED**: Every code file MUST have header comment/docstring
- ✅ **Format**: Language-appropriate (Doxygen for C++, Sphinx for Python, header comments for shell)
- ✅ **Content**: Purpose, description, author/date (optional), key dependencies
- ✅ **AUTO-FIX**: Pre-commit hook automatically adds missing headers
- ✅ **VALIDATION**: Documentation validator blocks commit if missing

#### B2. Function/Class Documentation Checklist (MANDATORY for functions > 10 lines):

Every **non-trivial** function must include:

- ✅ **Purpose:** One-liner summary
- ✅ **Parameters:** Types, constraints, defaults
- ✅ **Return value:** Type and semantics
- ✅ **Exceptions/Errors:** What can go wrong
- ✅ **Side effects:** State changes, I/O, threading
- ✅ **Performance notes:** Complexity, threading, GPU acceleration
- ✅ **Examples:** Minimal runnable snippet
- ✅ **Related:** Links to similar functions or documentation
- ✅ **AUTO-FIX**: Pre-commit hook can add basic function documentation templates
- ✅ **VALIDATION**: Documentation validator checks function documentation coverage
- ✅ **RATIONALE**: Good documentation enables AI agents to understand context and make better edits

#### B3. Complex Logic Documentation (MANDATORY):
- ✅ **REQUIRED**: Multi-phase detection/configuration logic MUST have phase markers
- ✅ **Format**: `# Phase 1: ...`, `# Phase 2: ...`, etc.
- ✅ **REQUIRED**: Long conditionals/loops MUST have explanatory comments
- ✅ **REQUIRED**: Comment density minimum 25% in complex code sections
- ✅ **BEST PRACTICE**: Comments explain WHY (rationale, assumptions), not WHAT
- ✅ **VALIDATION**: Documentation validator checks for phase markers in complex logic

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

