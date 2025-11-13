# ENHANCED Code Review Prompt: Robotics HPC Stack + Multi-Language - PART 3
## Industry Best Practices for Pre-Commit Checks

**This is PART 3 of 3. See also:**
- `Enhanced-Code-Review-Prompt-PART1.md` - Part 1 (Pre-Review Setup, Context Review, Checklist start)
- `Enhanced-Code-Review-Prompt-PART2.md` - Part 2 (Enhanced Sequential Audit Checklist continued)

---

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
