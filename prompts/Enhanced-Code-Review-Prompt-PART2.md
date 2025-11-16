# ENHANCED Code Review Prompt: Robotics HPC Stack + Multi-Language - PART 2
## Industry Best Practices for Pre-Commit Checks

HARD ENFORCEMENT – SINGLE-PART MEMORY & CHUNKING (PART 2)
- Only this PART’s content may be loaded while executing this part. Unload other review/manual parts from memory.
- Use master chunking: max 500 lines (target 450–500) with 20–40 lines overlap. Process chunks in order.
- For each chunk: execute PART 2 checks fully → apply fixes → re-run PART 2 checks until PASS/N/A. Keep only compact capsule (≤ 2KB): status map, symbol names, chunk cursor.
- Proceed to PART 3 only after all chunks pass; unload PART 2 before loading PART 3.
**This is PART 2 of 3. See also:**
- `Enhanced-Code-Review-Prompt-PART1.md` - Part 1 (Pre-Review Setup, Context Review, Checklist start)
- `Enhanced-Code-Review-Prompt-PART3.md` - Part 3 (Correction Summary, Tools & Automation)

---

## 🚨 MANDATORY SEQUENTIAL EXECUTION INSTRUCTIONS

**CRITICAL: This is a multi-part prompt designed to maintain 500-line full context limits.**

**PREREQUISITE CHECK:**
- [ ] **PART 1 COMPLETED**: All tasks in PART 1 must be 100% complete before starting PART 2
- [ ] **PART 1 OUTPUTS REVIEWED**: All outputs from PART 1 have been generated and reviewed
- [ ] **CONTEXT CARRIED FORWARD**: Key findings from PART 1 are available for reference

**EXECUTION PROTOCOL:**
1. **VERIFY PART 1 COMPLETION**: Ensure all PART 1 tasks are finished
2. **START PART 2**: Begin with this file (PART 2)
3. **COMPLETE ALL TASKS** in PART 2 fully before proceeding
4. **ONLY AFTER** PART 2 is 100% complete, proceed to PART 3
5. **DO NOT** jump ahead or skip parts - each part builds on the previous

**WHY SEQUENTIAL?**
- Maintains 500-line context window per part
- Ensures complete understanding before moving forward
- Prevents context overflow and incomplete reviews
- Each part is self-contained but builds on previous work

**VERIFICATION CHECKLIST:**
- [ ] All PART 1 tasks completed (prerequisite)
- [ ] All PART 2 tasks completed
- [ ] All PART 2 outputs generated
- [ ] Ready to proceed to PART 3

**ONLY PROCEED TO PART 3 WHEN ALL PART 2 TASKS ARE COMPLETE.**

---

## Mandatory 20-Item Todo Batching (Strict Sequence)
- This part inherits the batching protocol from the master files (`prompts/Code_check_prompt_manual.txt` and `prompts/Advanced-CoT-Multi-Agent-Prompt.md`):
  - Generate the next 20 atomic todos from current plan/state,
  - Execute strictly in order 1→20, one at a time, no interleaving or skipping,
  - Mark each completed before starting the next,
  - Only after all 20 complete, generate the next 20 and continue,
  - Do not advance chunks/sections while a 20-item batch is incomplete.

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

### C4. CMake Flag Validation (NEW - Added 2025-11-14)

**CRITICAL**: All CMake flags MUST be verified against documentation before use.

```bash
# CHECKLIST: For CMake configuration
# ✅ All flags are documented in docs/flags/LIBRARY_VERSION_CMAKE_FLAGS_DOCUMENTATION.md
# ✅ Flag names match exactly (case-sensitive)
# ✅ Flag types match documented types (OPTION for ON/OFF, STRING for paths)
# ✅ No undocumented flags (flags not in docs are silently ignored)
# ✅ No library-prefixed flags unless documented (e.g., Ceres_ENABLE_CUDA → use USE_CUDA)
# ✅ Standard CMake variables used correctly (BLA_VENDOR, CMAKE_PREFIX_PATH)
# ✅ Dependency find variables verified (SuiteSparse_DIR, METIS_DIR, etc.)

# VERIFICATION COMMAND:
check_cmake_flags() {
    local build_script="$1"
    local library="$2"
    local doc_file="docs/flags/${library}_CMAKE_FLAGS_DOCUMENTATION.md"
    
    if [ ! -f "$doc_file" ]; then
        echo "⚠️  Flag documentation not found: $doc_file"
        echo "   → Download library Git repo and parse CMakeLists.txt to create documentation"
        return 1
    fi
    
    # Extract all -D FLAG=VALUE patterns
    local flags=$(grep -oE '\-D[[:space:]]+[A-Z_]+[A-Z0-9_]*[[:space:]]*=' "$build_script" | sed 's/-D[[:space:]]*//' | sed 's/[[:space:]]*=.*//' | sort -u)
    
    for flag in $flags; do
        # Skip standard CMake variables
        if [[ "$flag" =~ ^CMAKE_|^BUILD_|^INSTALL_ ]]; then
            continue
        fi
        
        # Check if flag is documented
        if ! grep -qE "^### \`${flag}\`|^### ${flag}|^- \`${flag}\`" "$doc_file"; then
            echo "❌ ERROR: Undocumented flag found: $flag"
            echo "   → Flag is being silently ignored by CMake"
            echo "   → Action: Download library Git repo and verify flag existence"
            echo "   → If flag exists: Add to documentation"
            echo "   → If flag does NOT exist: Remove from build script"
            return 1
        fi
    done
    
    echo "✅ All CMake flags verified against documentation"
    return 0
}

# COMMON ERRORS:
# ❌ Ceres: SUITESPARSE_INCLUDE_DIR, CHOLMOD_LIBRARY → NOT valid (use SuiteSparse_DIR)
# ❌ SuiteSparse: METIS_LIBRARY_DIR → NOT valid (METIS is bundled)
# ✅ Ceres: SuiteSparse_DIR → Valid (documented)
# ✅ Ceres: CMAKE_PREFIX_PATH → Valid (standard CMake variable)
```

**Reference**: See `Code_check_prompt_manual.txt` M12 for detailed undocumented flag detection requirements.

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

