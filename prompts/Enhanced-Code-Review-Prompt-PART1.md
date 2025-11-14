# ENHANCED Code Review Prompt: Robotics HPC Stack + Multi-Language - PART 1
## Industry Best Practices for Pre-Commit Checks

**This is PART 1 of 3. See also:**
- `Enhanced-Code-Review-Prompt-PART2.md` - Part 2 (Enhanced Sequential Audit Checklist continued)
- `Enhanced-Code-Review-Prompt-PART3.md` - Part 3 (Correction Summary, Tools & Automation)

---

## 🚨 MANDATORY SEQUENTIAL EXECUTION INSTRUCTIONS

**CRITICAL: This is a multi-part prompt designed to maintain 500-line full context limits.**

**EXECUTION PROTOCOL:**
1. **START HERE**: Begin with PART 1 (this file)
2. **COMPLETE ALL TASKS** in PART 1 fully before proceeding
3. **ONLY AFTER** PART 1 is 100% complete, proceed to PART 2
4. **COMPLETE ALL TASKS** in PART 2 fully before proceeding
5. **ONLY AFTER** PART 2 is 100% complete, proceed to PART 3
6. **DO NOT** jump ahead or skip parts - each part builds on the previous

**WHY SEQUENTIAL?**
- Maintains 500-line context window per part
- Ensures complete understanding before moving forward
- Prevents context overflow and incomplete reviews
- Each part is self-contained but builds on previous work

**VERIFICATION CHECKLIST:**
- [ ] All PART 1 tasks completed
- [ ] All PART 1 outputs generated
- [ ] Ready to proceed to PART 2

**ONLY PROCEED TO PART 2 WHEN ALL PART 1 TASKS ARE COMPLETE.**

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
export ENFORCE_HEADER_DOCS=true  # require header comments/docstrings
export ENFORCE_FUNCTION_DOCS=true  # require function documentation (>10 lines)
export ENFORCE_PHASE_MARKERS=true  # require phase markers for complex logic
export ENFORCE_INLINE_COMMENTS=true  # require comments for non-trivial blocks
export DOC_AUTO_FIX=true  # auto-fix missing documentation in pre-commit hook
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

## PART 0: MANDATORY - Code_check_prompt_manual.txt is the Authoritative Source

**CRITICAL REQUIREMENT**: `prompts/Code_check_prompt_manual.txt` is the **central, comprehensive, grounded prompt** for all code checking in this repository. It is the **single source of truth** for all validation criteria.

**MANDATORY PROTOCOL**:
1. **ALWAYS load and reference** `prompts/Code_check_prompt_manual.txt` at the start of every review
2. **STRICTLY follow** the sequential audit checklist (A-O) defined in the manual
3. **CHECK EVERY ITEM** A1 through O4 sequentially - do not skip any items
4. **DOCUMENT PASS/FAIL** for each checklist item with specific line references
5. **ENHANCE THE MANUAL FIRST**: When new patterns are discovered from AI corrections, chats, or CI checks, they MUST be added to `Code_check_prompt_manual.txt` FIRST before being referenced in other prompts
6. **PATTERN LEARNING**: Before starting phases A-O, ALWAYS check `prompts/Pattern-Learning-Repository.md` for learned error patterns and verify code against all active patterns

**This prompt (Enhanced Code Review) provides multi-language extensions and HPC-specific checks, but the manual checklist is MANDATORY and must be executed completely for all Bash code.**

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

**CRITICAL**: The checklist below provides multi-language extensions and HPC-specific checks. However, for Bash code, you MUST load and follow the ACTUAL `prompts/Code_check_prompt_manual.txt` file, which is the authoritative source. This section provides language-specific examples, but the manual contains the complete, up-to-date checklist with all learned patterns.

**MANDATORY EXECUTION FOR BASH CODE**:
1. Load `prompts/Code_check_prompt_manual.txt` at the start of review
2. Execute EVERY checklist item A1 through O4 sequentially from the manual
3. Document PASS/FAIL for each item with line references
4. Do not skip any items - the manual is comprehensive and all items apply
5. Use the language-specific examples below as supplements, not replacements

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
