# ADVANCED Code Review Prompt: Multi-Agent Chain-of-Thought - PART 2B

**SEQUENTIAL CHECKING ENFORCED**: This is PART 2B of PART 2. You MUST have completed PART 1 and PART 2A before starting this part. After completing PART 2B, proceed to PART 3: `Advanced-CoT-Multi-Agent-Prompt-PART3.md`.

---

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
