# ADVANCED Code Review Prompt: Multi-Agent Chain-of-Thought - PART 2
## Prompt Engineering Best Practices for Robotics HPC Stack

**This is PART 2 of 3. See also:**
- `Advanced-CoT-Multi-Agent-Prompt-PART1.md` - Parts 1-2 (CoT Framework, Structured Reasoning)
- `Advanced-CoT-Multi-Agent-Prompt-PART3.md` - Parts 6-8 (Implementation, Metrics, Final Template)

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

---

**SEQUENTIAL CHECKING ENFORCED**: This is PART 2A of PART 2. After completing this part, continue with PART 2B: `Advanced-CoT-Multi-Agent-Prompt-PART2B.md`. Then proceed to PART 3: `Advanced-CoT-Multi-Agent-Prompt-PART3.md`.
