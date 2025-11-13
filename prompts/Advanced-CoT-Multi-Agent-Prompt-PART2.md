# ADVANCED Code Review Prompt: Multi-Agent Chain-of-Thought - PART 2
## Prompt Engineering Best Practices for Robotics HPC Stack

**This is PART 2 of 3. See also:**
- `Advanced-CoT-Multi-Agent-Prompt-PART1.md` - Parts 1-2 (CoT Framework, Structured Reasoning)
- `Advanced-CoT-Multi-Agent-Prompt-PART3.md` - Parts 6-8 (Implementation, Metrics, Final Template)

---

### 3.1 Structured Review Output

```json
{
  "review_metadata": {
    "timestamp": "2025-11-09T12:30:00Z",
    "language": "cpp",
    "detected_languages": ["cpp"],
    "chunk_plan": [
      {"range": "1-220", "note": "MKL initialization + SparseMatrix class head"},
      {"range": "201-450", "note": "Solver algorithms overlap", "overlap_with_previous": "201-220"}
    ],
    "file": "src/sparse_solver.cpp",
    "lines_reviewed": "1-450",
    "agents_deployed": 5,
    "tools_used": ["clang-tidy", "cppcheck", "rg", "custom-mkl-wrapper-linter"],
    "overall_confidence": 0.92
  },

  "chain_of_thought": [
    {
      "step": 1,
      "phase": "UNDERSTAND",
      "reasoning": "Code is C++ sparse linear algebra solver with MKL backend. Contains functions for sparse-dense matrix ops, Cholesky decomposition, and iterative solvers.",
      "dependencies_identified": ["Intel MKL", "OpenMP", "Eigen"],
      "complexity_estimate": "HIGH (3 classes, 15+ functions, matrix operations)"
    },
    
    {
      "step": 2,
      "phase": "DECOMPOSE",
      "reasoning": "Identified 3 logical units: (A) MKL wrapper initialization, (B) sparse data structure, (C) solver implementations.",
      "units": [
        {
          "name": "MKL initialization",
          "lines": "1-80",
          "agent_responsible": "HPC_SPECIALIST"
        },
        {
          "name": "SparseMatrix class",
          "lines": "81-200",
          "agent_responsible": "SYNTAX_VALIDATOR"
        },
        {
          "name": "Solver algorithms",
          "lines": "201-450",
          "agent_responsible": "CORRECTNESS_AUDITOR"
        }
      ]
    },
    
    {
      "step": 3,
      "phase": "VERIFY_SYNTAX",
      "agent": "SYNTAX_VALIDATOR",
      "checks": [
        {
          "criterion": "A1_SHEBANG",
          "status": "N/A",
          "reason": "Not a shell script"
        },
        {
          "criterion": "A2_FORMATTING",
          "status": "PASS",
          "confidence": 0.95,
          "detail": "Consistent 4-space indent, K&R style brace placement"
        },
        {
          "criterion": "A4_DECLARATION_ORDER",
          "status": "WARNING",
          "confidence": 0.80,
          "detail": "SparseMatrix::multiply_mkl() called before mkl_sparse_d_mv() declaration",
          "recommendation": "Move MKL wrapper initialization 20 lines earlier"
        }
      ]
    },

    {
      "step": 4,
      "phase": "VERIFY_HPC",
      "agent": "HPC_SPECIALIST",
      "checks": [
        {
          "criterion": "MKL_LINKAGE",
          "status": "PASS",
          "confidence": 0.98,
          "detail": "MKL BLAS routines: mkl_sparse_d_mv, mkl_sparse_d_trsv detected",
          "suggested_flags": "-lmkl_intel_lp64 -lmkl_core -lmkl_gnu_thread -lgomp -lpthread"
        },
        {
          "criterion": "OPENMP_PRAGMAS",
          "status": "WARNING",
          "confidence": 0.85,
          "detail": "Line 234: #pragma omp parallel for without reduction clause on accumulation",
          "risk": "Data race on sum variable",
          "fix": "Add 'reduction(+:sum)' to pragma"
        },
        {
          "criterion": "CUDA_INTEGRATION",
          "status": "NOT_APPLICABLE",
          "detail": "CPU-only code; consider cuSPARSE for large matrices"
        }
      ]
    },

    {
      "step": 5,
      "phase": "VERIFY_SAFETY",
      "agent": "SECURITY_AUDITOR",
      "checks": [
        {
          "criterion": "RESOURCE_CLEANUP",
          "status": "FAIL",
          "confidence": 0.98,
          "detail": "Line 189: mkl_sparse_destroy() only called on success path, not on error",
          "risk": "CRITICAL: MKL handle leaked on early return",
          "fix": "Use RAII wrapper or guard with try-finally"
        },
        {
          "criterion": "INPUT_VALIDATION",
          "status": "PASS",
          "confidence": 0.90,
          "detail": "Constructor validates matrix dimensions"
        }
      ]
    },

    {
      "step": 6,
      "phase": "VERIFY_DOCUMENTATION",
      "agent": "DOCUMENTATION_CHECKER",
      "checks": [
        {
          "criterion": "FUNCTION_DOCUMENTATION",
          "status": "PARTIAL",
          "confidence": 0.75,
          "detail": "3 of 5 functions have Doxygen comments",
          "missing_docs": ["multiply_mkl()", "transpose()"],
          "comment_ratio": 0.18,
          "target_ratio": 0.25,
          "gap": "7%"
        },
        {
          "criterion": "PARAMETER_DOCUMENTATION",
          "status": "INCOMPLETE",
          "confidence": 0.70,
          "detail": "solve_mkl() missing @param documentation for 'solver_type' parameter"
        }
      ]
    },

    {
      "step": 7,
      "phase": "VERIFY_CORRECTNESS",
      "agent": "CORRECTNESS_AUDITOR",
      "checks": [
        {
          "criterion": "ALGORITHM_CORRECTNESS",
          "status": "PASS",
          "confidence": 0.92,
          "detail": "Cholesky decomposition matches standard MKL LAPACK DPOTRF semantics"
        },
        {
          "criterion": "NUMERICAL_STABILITY",
          "status": "PASS",
          "confidence": 0.85,
          "detail": "Proper handling of info parameter for singular matrices"
        },
        {
          "criterion": "PERFORMANCE_REGRESSION",
          "status": "NEEDS_BENCHMARKS",
          "confidence": 0.60,
          "detail": "No performance baseline provided; recommend adding benchmark before release"
        }
      ]
    }
  ],

  "checklist_assessment": {
    "A": {
      "status": "PASS",
      "notes": ["A2 formatting confirmed via clang-format profile"]
    },
    "B": {
      "status": "N/A",
      "notes": ["Not a shell script; shell option audit skipped"]
    },
    "C": {
      "status": "PASS",
      "notes": ["Constructor guards null pointers; class invariants documented"]
    },
    "H": {
      "status": "FAIL",
      "notes": ["H1: Missing error check after mkl_sparse_create_csr"]
    },
    "L": {
      "status": "WARNING",
      "notes": ["L2: Duplicated solver logic flagged for refactor"]
    },
    "M": {
      "status": "PASS",
      "notes": ["M2: Documented requirement for MKL 2024.1", "M6: Package pinning verified in accompanying docs"]
    },
    "N": {
      "status": "FAIL",
      "notes": ["N1/N2: MKL handle leak on error path"]
    },
    "O": {
      "status": "NEEDS_ACTION",
      "notes": ["O1: Recommend adding unit tests covering sparse-dense multiply"]
    }
  },

  "issues_found": [
    {
      "id": "CRITICAL-1",
      "severity": "CRITICAL",
      "agent": "SECURITY_AUDITOR",
      "line": 189,
      "issue": "MKL handle not freed on error path",
      "explanation": "The mkl_sparse_destroy() function is only called on the success path (line 195), not when errors occur. If compute_result() returns early, memory is leaked.",
      "impact": "Memory leak (handles accumulate in long-running processes), HPC cluster resource exhaustion",
      "fix_before": "if (mkl_sparse_d_mv(...) == 0) { mkl_sparse_destroy(handle_); }",
      "fix_after": "unique_ptr<SparseMatrix> safe_handle(this, [](auto* p) { mkl_sparse_destroy(p->handle_); }); // RAII",
      "prevention": "Always use RAII; never rely on success path cleanup"
    },

    {
      "id": "WARNING-1",
      "severity": "HIGH",
      "agent": "HPC_SPECIALIST",
      "line": 234,
      "issue": "Data race in OpenMP loop",
      "explanation": "Line 234 has '#pragma omp parallel for' reducing into sum without reduction clause. Multiple threads write to 'sum' concurrently → undefined behavior.",
      "impact": "Non-deterministic results; numerical instability; incorrect answers",
      "fix": "Add 'reduction(+:sum)' to the pragma",
      "benchmark_impact": "No performance penalty; correctness only"
    },

    {
      "id": "WARNING-2",
      "severity": "MEDIUM",
      "agent": "DOCUMENTATION_CHECKER",
      "lines": "120, 156",
      "issue": "Missing function documentation",
      "explanation": "Functions multiply_mkl() and transpose() lack Doxygen comments. Future maintainers won't know parameters, return values, or MKL requirements.",
      "impact": "Maintenance burden; higher onboarding time for new developers",
      "fix": "Add Doxygen comments for both functions (5-10 lines each)"
    },

    {
      "id": "INFO-1",
      "severity": "LOW",
      "agent": "CORRECTNESS_AUDITOR",
      "line": null,
      "issue": "No performance baseline",
      "explanation": "Code lacks benchmark results. Can't verify if MKL optimization actually provides expected 2-5x speedup.",
      "impact": "No proof of HPC optimization effectiveness",
      "fix": "Add benchmark suite before release (optional but recommended)"
    }
  ],

  "documentation_review": {
    "comment_ratio": 0.18,
    "target_ratio": 0.25,
    "docstring_gaps": [
      {"symbol": "multiply_mkl", "missing": ["@param b_vector", "@return status"]},
      {"symbol": "transpose", "missing": ["Overall description", "Complexity note"]}
    ],
    "standards_crosscheck": [
      "C++ Doxygen compliance at 60%",
      "Header comment missing for solver namespace"
    ],
    "recommended_actions": [
      "Add usage note describing MKL threading configuration",
      "Refresh inline comments around parallel reduction with reduction clause"
    ]
  },

  "symbol_table": [
    {
      "name": "mkl_handle_",
      "type": "sparse_matrix_t",
      "declared_line": 42,
      "first_use": 89,
      "scope": "member",
      "status": "resolved",
      "notes": "Must be freed in destructor"
    },
    {
      "name": "multiply_mkl",
      "type": "method",
      "declared_line": 120,
      "first_use": 156,
      "scope": "public",
      "status": "documented_pass"
    }
  ],

  "corrections": [
    {
      "id": "CRITICAL-1",
      "before_code": "sparse_matrix_t handle_;\n// ...\nif (mkl_sparse_d_mv(...) == 0) {\n    mkl_sparse_destroy(handle_);\n}",
      "after_code": "struct MKLHandleGuard {\n    sparse_matrix_t handle_;\n    ~MKLHandleGuard() { \n        if (handle_) mkl_sparse_destroy(handle_); \n    }\n};\n// Usage:\nMKLHandleGuard h{handle_}; // Auto-cleanup on exit"
    },
    {
      "id": "WARNING-1",
      "before_code": "#pragma omp parallel for\nfor (int i = 0; i < n; ++i) {\n    sum += data[i];\n}",
      "after_code": "#pragma omp parallel for reduction(+:sum)\nfor (int i = 0; i < n; ++i) {\n    sum += data[i];\n}"
    }
  ],

  "summary": {
    "total_checks": 45,
    "passed": 38,
    "warned": 4,
    "failed": 1,
    "checklist_failures": ["H1", "N1"],
    "critical_blockers": 1,
    "approval_status": "CONDITIONAL_PASS",
    "approval_status_explanation": "Approve after fixing CRITICAL-1 (MKL handle leak) and WARNING-1 (OpenMP data race)",
    "documentation_coverage": "18% (target 25%)",
    "documentation_actions_required": [
      "Add Doxygen comments for multiply_mkl() and transpose()",
      "Update module header comment to match solver behavior"
    ],
    "hpc_optimization_score": "8.2/10",
    "overall_confidence": 0.92,
    "estimated_fix_time_minutes": 15
  }
}
```

---

## PART 4: SELF-CORRECTION & FEEDBACK LOOPS

### 4.1 Agent Inter-Communication Protocol

```
AGENT FEEDBACK LOOP:

HPC_SPECIALIST → SECURITY_AUDITOR:
"I found MKL-specific code. Can you verify handle cleanup?"

SECURITY_AUDITOR → HPC_SPECIALIST:
"Found CRITICAL memory leak in MKL handle (line 189). 
 This prevents production deployment. 
 Severity raised to BLOCKER."

HPC_SPECIALIST → CORRECTNESS_AUDITOR:
"MKL resource leak fixed. Can you verify numerical impact?"

CORRECTNESS_AUDITOR → HPC_SPECIALIST:
"Verified: RAII wrapper doesn't affect numerical correctness. 
 Performance unaffected. Recommend merge."

DOCUMENTATION_CHECKER (broadcast):
"All agents: Please flag any undocumented functions for my coverage calculation."

[All agents respond with line numbers of undocumented code]

DOCUMENTATION_CHECKER → REVIEWER:
"Coverage report: 18% (3 of 5 functions). Gap: 7%. 
 Recommend adding 5-10 lines of Doxygen docs."
```

### 4.2 Confidence Scoring Methodology

```
CONFIDENCE CALCULATION:

For each check:
  confidence = base_score × tool_accuracy × reviewer_certainty

Examples:

1. SYNTAX CHECK (clang compiler):
   - Tool: clang (99% accurate)
   - Reviewer confidence: human verifies compiler output (95%)
   - Result: 0.98 confidence = GREEN 🟢

2. OPENMP PRAGMA ANALYSIS:
   - Tool: grep + manual inspection (70% accurate for semantic issues)
   - Reviewer confidence: moderate (75%)
   - Result: 0.525 confidence = YELLOW 🟡 (borderline)
   - Recommendation: Use static analyzer (Clang-Tidy)

3. NUMERICAL STABILITY:
   - Tool: theoretical analysis + literature review (60% coverage)
   - Reviewer confidence: modest (65%)
   - Result: 0.39 confidence = RED 🔴 (high uncertainty)
   - Recommendation: Run numerical tests, compare with reference implementation

Overall Review Confidence = mean(all check confidences)
  ≥ 0.90 = HIGH CONFIDENCE (ready to merge)
  0.70-0.90 = MEDIUM (needs minor fixes)
  < 0.70 = LOW (needs significant work or expert review)
```

---

## PART 5: ADVANCED PROMPT TECHNIQUES

### 5.1 Few-Shot Learning (Examples for Model)

```
EXAMPLE 1: MKL Integration Error

Input Code:
```cpp
#include <mkl.h>
#include <cblas.h>

void multiply(double* A, double* B, double* C, int n) {
    // No thread management, no error checking
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                n, n, n, 1.0, A, n, B, n, 0.0, C, n);
}
```

Expected Agent Response (HPC_SPECIALIST):
"ISSUE: Missing MKL threading configuration. OMP_NUM_THREADS may not be respected.
RISK: Suboptimal performance (threading misconfiguration).
FIX:
```cpp
#include <mkl.h>
mkl_set_num_threads(omp_get_max_threads());  // Respect OMP_NUM_THREADS
mkl_set_threading_layer(MKL_THREADING_GNU);  // Match our OpenMP layer
```
RATIONALE: Without explicit threading setup, MKL defaults may not align with environment."

---

EXAMPLE 2: Resource Leak

Input Code:
```cpp
SparseMatrix* create_matrix(int n) {
    auto* m = new SparseMatrix(n, n);  // Caller must delete
    mkl_sparse_create_csr(..., &m->handle_);
    return m;
}
```

Expected Agent Response (SECURITY_AUDITOR):
"CRITICAL RESOURCE LEAK: Memory ownership unclear. Caller must delete, but MKL handle lifecycle ambiguous.
RISK: Process hangs or crashes if caller forgets to free; handle leaks → resource exhaustion on HPC.
FIX: Use RAII with unique_ptr + custom deleter
```cpp
std::unique_ptr<SparseMatrix> create_matrix(int n) {
    auto m = std::make_unique<SparseMatrix>(n, n);
    mkl_sparse_create_csr(..., &m->handle_);
    return m;  // Auto-cleanup on scope exit
}
```
RATIONALE: HPC environments run long-running processes; memory leaks accumulate."
```

### 5.2 Meta-Prompting (Prompt About Prompting)

```
META-PROMPT: Request Agent to Evaluate Prompt Quality

"Before reviewing code, evaluate this review prompt:

1. COMPLETENESS: Does it cover all critical checks for HPC code?
2. CLARITY: Are instructions unambiguous?
3. EFFICIENCY: Can agents execute this in parallel?
4. EXTENSIBILITY: Can new checks be added?

Score: _/10
Gaps Identified: [list]
Suggested Improvements: [list]

After scoring, proceed with full code review."
```

### 5.3 Verification by Contradiction

```
VERIFICATION PROTOCOL: Assume the opposite

For each check, ask the opposite:

Normal Check: "Does MKL initialization happen?"
Reverse Check: "If MKL is NOT initialized, what breaks?"
  → This forces deeper analysis of dependencies
  
Expected Impact: Forces agents to explain *why*, not just *what*
