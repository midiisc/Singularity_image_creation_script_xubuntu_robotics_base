#!/usr/bin/env python3
"""
Error Pattern Extraction and Prompt Enhancement System
Purpose: Extract error patterns from chat/commits and enhance prompts automatically
"""

import re
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import json

REPO_ROOT = Path(__file__).parent.parent.parent
PATTERN_REPO = REPO_ROOT / "prompts" / "Pattern-Learning-Repository.md"
CODE_CHECK_PROMPT = REPO_ROOT / "prompts" / "Code_check_prompt_manual.txt"  # Master entry point
CODE_CHECK_PROMPT_PART1 = REPO_ROOT / "prompts" / "Code_check_prompt_manual-PART1.txt"
CODE_CHECK_PROMPT_PART2 = REPO_ROOT / "prompts" / "Code_check_prompt_manual-PART2.txt"
CODE_CHECK_PROMPT_PART3 = REPO_ROOT / "prompts" / "Code_check_prompt_manual-PART3.txt"
CODE_CHECK_PROMPT_PART4 = REPO_ROOT / "prompts" / "Code_check_prompt_manual-PART4.txt"
ADVANCED_COT = REPO_ROOT / "prompts" / "Advanced-CoT-Multi-Agent-Prompt-PART1.md"
ENHANCED_REVIEW = REPO_ROOT / "prompts" / "Enhanced-Code-Review-Prompt-PART1.md"
LIBRARY_ANALYSIS = REPO_ROOT / "prompts" / "Library-Analysis-Tool-PART1.md"


def extract_patterns_from_ai_findings(review_results: List[Tuple[str, str, Dict[str, object]]]) -> List[Dict]:
    """
    Extract error patterns from AI review findings.
    Covers ALL error types found during code review.
    Returns list of pattern dictionaries.
    """
    patterns = []
    
    for header, provider, review in review_results:
        findings = review.get("findings", [])
        if not isinstance(findings, list):
            continue
        
        for finding in findings:
            severity = finding.get("severity", "").lower()
            title = finding.get("title", "").strip()
            details = finding.get("details", "").strip()
            suggested_fix = finding.get("suggested_fix", "").strip()
            
            # Only extract patterns from critical/major findings (preventable errors)
            if severity not in ("critical", "major"):
                continue
            
            # Extract pattern from finding
            pattern = None
            error_text = f"{title} {details}".lower()
            
            # ===== SYNTAX ERRORS =====
            if any(term in error_text for term in ["pipe", "echo.*grep", "unsafe.*pipe", "here-string"]):
                pattern = {
                    "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                    "category": "Performance/Security",
                    "error": title or "Unsafe pipe pattern",
                    "root_cause": details[:200] if details else "See AI review findings",
                    "detection": r'echo\s+[^|]*\|\s*grep',
                    "prevention": suggested_fix or "Use `grep <<< \"${VAR}\"` or `[[ \"${VAR}\" =~ pattern ]]`",
                    "example": {
                        "wrong": "echo \"${VAR}\" | grep pattern",
                        "correct": "grep pattern <<< \"${VAR}\""
                    },
                    "date_added": datetime.now().strftime("%Y-%m-%d"),
                    "frequency": 1,
                    "source": "AI Review"
                }
            
            # ===== LOGIC ERRORS =====
            elif any(term in error_text for term in ["unclosed", "mismatch", "pairing", "if.*fi", "missing.*fi", "missing.*done"]):
                pattern = {
                    "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                    "category": "Logic/Structure",
                    "error": title or "Unclosed block or mismatched control structure",
                    "root_cause": details[:200] if details else "Missing closing statements",
                    "detection": "Count opening/closing keywords: if/fi, for/done, case/esac, {/}",
                    "prevention": suggested_fix or "Ensure all control structures are properly closed",
                    "example": {
                        "wrong": "if [ condition ]; then\n  echo 'test'\n# Missing fi",
                        "correct": "if [ condition ]; then\n  echo 'test'\nfi"
                    },
                    "date_added": datetime.now().strftime("%Y-%m-%d"),
                    "frequency": 1,
                    "source": "AI Review"
                }
            
            # ===== RUNTIME ERRORS =====
            elif any(term in error_text for term in ["unbound", "set.*u", "variable.*unset", "undefined.*variable"]):
                pattern = {
                    "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                    "category": "Runtime Error",
                    "error": title or "Unbound variable in set -u context",
                    "root_cause": details[:200] if details else "Variable used without default",
                    "detection": "Check for ${VAR} without ${VAR:-default} in set -u context",
                    "prevention": suggested_fix or "Always use ${VAR:-default} for potentially unset variables",
                    "example": {
                        "wrong": "set -u\nCACHE_DIR=\"${CONTAINER_APT_CACHE}\"",
                        "correct": "set -u\nCACHE_DIR=\"${CONTAINER_APT_CACHE:-/var/cache/apt/archives}\""
                    },
                    "date_added": datetime.now().strftime("%Y-%m-%d"),
                    "frequency": 1,
                    "source": "AI Review"
                }
            
            # ===== CONFIGURATION ERRORS =====
            elif any(term in error_text for term in ["cmake", "flag", "invalid.*flag", "unsupported.*flag", "documentation"]):
                pattern = {
                    "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                    "category": "Configuration/Build",
                    "error": title or "Invalid or undocumented CMake flag",
                    "root_cause": details[:200] if details else "Flag not validated against documentation",
                    "detection": "CMake flag validation script or grep for -D flags",
                    "prevention": suggested_fix or "Validate all flags against docs/flags/*.md before use",
                    "example": {
                        "wrong": "-DCERES_USE_CUDA=ON",
                        "correct": "-DUSE_CUDA=ON (validated against docs)"
                    },
                    "date_added": datetime.now().strftime("%Y-%m-%d"),
                    "frequency": 1,
                    "source": "AI Review"
                }
            
            # ===== STRUCTURAL ERRORS =====
            elif any(term in error_text for term in ["heredoc", "eof", "delimiter", "docstring", "header.*comment"]):
                pattern = {
                    "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                    "category": "Structural/Syntax",
                    "error": title or "Structural error",
                    "root_cause": details[:200] if details else "See AI review findings",
                    "detection": "Check for structural issues in code",
                    "prevention": suggested_fix or "Fix according to AI review suggestions",
                    "example": {
                        "wrong": "Structural issue detected",
                        "correct": "Fixed according to review"
                    },
                    "date_added": datetime.now().strftime("%Y-%m-%d"),
                    "frequency": 1,
                    "source": "AI Review"
                }
            
            # ===== SCOPE ERRORS =====
            elif any(term in error_text for term in ["local.*outside", "local.*function", "scope"]):
                pattern = {
                    "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                    "category": "Syntax/Scope",
                    "error": title or "Local keyword used outside function",
                    "root_cause": details[:200] if details else "local only valid inside functions",
                    "detection": "Check for 'local' at file scope (not inside function)",
                    "prevention": suggested_fix or "Use plain assignment or 'declare' at top level",
                    "example": {
                        "wrong": "local var=\"value\"  # At top level",
                        "correct": "var=\"value\"  # At top level"
                    },
                    "date_added": datetime.now().strftime("%Y-%m-%d"),
                    "frequency": 1,
                    "source": "AI Review"
                }
            
            # ===== GENERAL PATTERN (catch-all for other AI findings) =====
            elif severity in ("critical", "major"):
                # Extract error type from title/details
                error_type = "Unknown"
                if "syntax" in error_text:
                    error_type = "Syntax"
                elif "logic" in error_text:
                    error_type = "Logic"
                elif "security" in error_text:
                    error_type = "Security"
                elif "performance" in error_text:
                    error_type = "Performance"
                
                pattern = {
                    "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                    "category": f"{error_type} Error",
                    "error": title or "Error detected by AI review",
                    "root_cause": details[:200] if details else "See AI review findings",
                    "detection": f"AI review finding: {title}",
                    "prevention": suggested_fix or "Fix according to AI review suggestions",
                    "example": {
                        "wrong": "Error detected",
                        "correct": "Fixed according to review"
                    },
                    "date_added": datetime.now().strftime("%Y-%m-%d"),
                    "frequency": 1,
                    "source": "AI Review"
                }
            
            if pattern:
                patterns.append(pattern)
    
    return patterns


def extract_error_patterns_from_check_results(check_results: Dict[str, str], check_errors: Dict[str, str]) -> List[Dict]:
    """
    Extract error patterns from CI check failures.
    Covers ALL error types: syntax, logic, configuration, structural, runtime.
    Returns list of pattern dictionaries.
    """
    patterns = []
    
    for check_name, error_msg in check_errors.items():
        pattern = None
        error_lower = error_msg.lower()
        check_lower = check_name.lower()
        
        # ===== SYNTAX ERRORS =====
        if "pipe" in check_lower or "echo.*grep" in error_lower or "unsafe.*pipe" in error_lower:
            pattern = {
                "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                "category": "Performance/Security",
                "error": "Unsafe echo | grep pattern",
                "root_cause": "Creates unnecessary subshell, potential echo flag interpretation",
                "detection": r'echo\s+[^|]*\|\s*grep',
                "prevention": "Use `grep <<< \"${VAR}\"` or `[[ \"${VAR}\" =~ pattern ]]`",
                "example": {
                    "wrong": 'if echo "${VAR}" | grep -q "pattern"; then',
                    "correct": 'if grep -q "pattern" <<< "${VAR}"; then'
                },
                "date_added": datetime.now().strftime("%Y-%m-%d"),
                "frequency": 1
            }
        
        elif "bash" in check_name.lower() and "compatibility" in check_name.lower():
            pattern = {
                "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                "category": "Syntax/Compatibility",
                "error": "Bash 4+ features without version checks",
                "root_cause": "Bash 4+ features not available in Bash 3.x",
                "detection": r'\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,\}',
                "prevention": "Replace with `tr '[:lower:]' '[:upper:]'` or add version check",
                "example": {
                    "wrong": 'lib_upper=${lib^^}',
                    "correct": 'lib_upper=$(echo "${lib}" | tr "[:lower:]" "[:upper:]")'
                },
                "date_added": datetime.now().strftime("%Y-%m-%d"),
                "frequency": 1
            }
        
        # ===== CONFIGURATION ERRORS =====
        elif "cmake" in check_lower or "flag" in check_lower:
            pattern = {
                "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                "category": "Configuration/Build",
                "error": "Invalid or undocumented CMake flags",
                "root_cause": "Flags not validated against library documentation",
                "detection": "CMake flag validation script or grep for -D flags",
                "prevention": "Validate all flags against docs/flags/*.md before use",
                "example": {
                    "wrong": "-DCERES_USE_CUDA=ON",
                    "correct": "-DUSE_CUDA=ON (validated against docs)"
                },
                "date_added": datetime.now().strftime("%Y-%m-%d"),
                "frequency": 1
            }
        
        # ===== LOGIC ERRORS =====
        elif "if.*fi" in error_lower or "unclosed" in error_lower or "mismatch" in error_lower or "pairing" in error_lower:
            pattern = {
                "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                "category": "Logic/Structure",
                "error": "Unclosed blocks or mismatched control structures",
                "root_cause": "Missing closing statements (fi, done, }, etc.)",
                "detection": "Count opening/closing keywords: if/fi, for/done, case/esac, {/}",
                "prevention": "Ensure all control structures are properly closed",
                "example": {
                    "wrong": "if [ condition ]; then\n  echo 'test'\n# Missing fi",
                    "correct": "if [ condition ]; then\n  echo 'test'\nfi"
                },
                "date_added": datetime.now().strftime("%Y-%m-%d"),
                "frequency": 1
            }
        
        # ===== STRUCTURAL ERRORS =====
        elif "heredoc" in error_lower or "eof" in error_lower or "delimiter" in error_lower:
            pattern = {
                "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                "category": "Structural/Syntax",
                "error": "Incorrect heredoc syntax or unquoted delimiter",
                "root_cause": "Heredoc delimiter not quoted or mismatched",
                "detection": "Check for <<EOF without quotes, or mismatched EOF markers",
                "prevention": "Use <<'EOF' for literal content, ensure matching delimiters",
                "example": {
                    "wrong": "<<EOF\n$VAR will expand\nEOF",
                    "correct": "<<'EOF'\n$VAR will not expand\nEOF"
                },
                "date_added": datetime.now().strftime("%Y-%m-%d"),
                "frequency": 1
            }
        
        # ===== RUNTIME ERRORS =====
        elif "unbound" in error_lower or "set.*u" in error_lower or "variable" in error_lower:
            pattern = {
                "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                "category": "Runtime Error",
                "error": "Unbound variable in set -u context",
                "root_cause": "Variable used without default when set -u is active",
                "detection": "Check for ${VAR} without ${VAR:-default} in set -u context",
                "prevention": "Always use ${VAR:-default} for potentially unset variables",
                "example": {
                    "wrong": "set -u\nCACHE_DIR=\"${CONTAINER_APT_CACHE}\"",
                    "correct": "set -u\nCACHE_DIR=\"${CONTAINER_APT_CACHE:-/var/cache/apt/archives}\""
                },
                "date_added": datetime.now().strftime("%Y-%m-%d"),
                "frequency": 1
            }
        
        # ===== SCOPE ERRORS =====
        elif "local" in error_lower and ("outside" in error_lower or "function" in error_lower):
            pattern = {
                "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                "category": "Syntax/Scope",
                "error": "Local keyword used outside function",
                "root_cause": "local only valid inside functions",
                "detection": "Check for 'local' at file scope (not inside function)",
                "prevention": "Use plain assignment or 'declare' at top level",
                "example": {
                    "wrong": "local var=\"value\"  # At top level",
                    "correct": "var=\"value\"  # At top level\n# OR inside function:\nfunc() {\n  local var=\"value\"\n}"
                },
                "date_added": datetime.now().strftime("%Y-%m-%d"),
                "frequency": 1
            }
        
        # ===== DOCUMENTATION ERRORS =====
        elif "docstring" in error_lower or "header.*comment" in error_lower or "missing.*comment" in error_lower:
            pattern = {
                "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                "category": "Structural/Documentation",
                "error": "Missing docstring or header comment",
                "root_cause": "Code file missing purpose description",
                "detection": "Check first 20 lines for docstring/header comment",
                "prevention": "Add header comment/docstring describing file purpose",
                "example": {
                    "wrong": "#!/bin/bash\nset -euo pipefail\n# No purpose description",
                    "correct": "#!/bin/bash\n# Purpose: Automated validation script\n# Description: Runs CI checks before commit\nset -euo pipefail"
                },
                "date_added": datetime.now().strftime("%Y-%m-%d"),
                "frequency": 1
            }
        
        # ===== GENERAL PATTERN (catch-all for other errors) =====
        elif pattern is None and error_msg:
            # Extract error type from error message
            error_type = "Unknown"
            if "validation" in error_lower:
                error_type = "Validation"
            elif "syntax" in error_lower:
                error_type = "Syntax"
            elif "logic" in error_lower:
                error_type = "Logic"
            
            pattern = {
                "id": f"P-{datetime.now().strftime('%Y%m%d')}-{len(patterns) + 1:03d}",
                "category": f"{error_type} Error",
                "error": error_msg[:100],  # Truncate long messages
                "root_cause": "See error message for details",
                "detection": check_name,
                "prevention": "Fix according to error message",
                "example": {
                    "wrong": "Error occurred",
                    "correct": "Fixed according to validation"
                },
                "date_added": datetime.now().strftime("%Y-%m-%d"),
                "frequency": 1
            }
        
        if pattern:
            patterns.append(pattern)
    
    return patterns


def update_pattern_repository(patterns: List[Dict]) -> bool:
    """
    Update Pattern-Learning-Repository.md with new patterns.
    Returns True if updated.
    """
    if not patterns:
        return False
    
    if not PATTERN_REPO.exists():
        print(f"Warning: Pattern repository not found: {PATTERN_REPO}")
        return False
    
    content = PATTERN_REPO.read_text(encoding="utf-8")
    
    for pattern in patterns:
        # Check if pattern already exists
        if pattern["id"] in content:
            # Update frequency
            pattern_match = re.search(
                rf'### {re.escape(pattern["id"])}.*?- \*\*Frequency\*\*: (\d+)',
                content,
                re.DOTALL
            )
            if pattern_match:
                old_freq = int(pattern_match.group(1))
                new_freq = old_freq + pattern["frequency"]
                content = re.sub(
                    rf'({re.escape(pattern["id"])}.*?- \*\*Frequency\*\*: )\d+',
                    rf'\g<1>{new_freq}',
                    content,
                    flags=re.DOTALL
                )
            continue
        
        # Add new pattern
        pattern_text = f"""
### {pattern["id"]}: {pattern["error"]}
- **Category**: {pattern["category"]}
- **Error**: {pattern["error"]}
- **Root Cause**: {pattern["root_cause"]}
- **Detection**: 
  ```regex
  {pattern["detection"]}
  ```
- **Prevention**: {pattern["prevention"]}
- **Example**:
  ```bash
  # WRONG
  {pattern["example"]["wrong"]}
  
  # CORRECT
  {pattern["example"]["correct"]}
  ```
- **Date Added**: {pattern["date_added"]}
- **Frequency**: {pattern["frequency"]} occurrence(s) detected
"""
        
        # Insert before "## Active Patterns" or at end
        if "## Active Patterns" in content:
            content = content.replace("## Active Patterns", f"## Active Patterns{pattern_text}")
        else:
            content += pattern_text
    
    PATTERN_REPO.write_text(content, encoding="utf-8")
    return True


def enhance_code_check_prompt(pattern: Dict) -> bool:
    """
    Enhance Code_check_prompt_manual.txt with pattern if not already covered.
    Handles split parts: checks all parts sequentially, enhances the appropriate part.
    """
    if not CODE_CHECK_PROMPT.exists():
        return False
    
    # Load all parts sequentially to check for existing pattern and determine target part
    part_files = [
        (CODE_CHECK_PROMPT_PART1, "PART1"),
        (CODE_CHECK_PROMPT_PART2, "PART2"),
        (CODE_CHECK_PROMPT_PART3, "PART3"),
        (CODE_CHECK_PROMPT_PART4, "PART4"),
    ]
    
    # Check if pattern already exists in any part
    for part_path, part_name in part_files:
        if part_path.exists():
            content = part_path.read_text(encoding="utf-8")
            if pattern["detection"] in content or pattern["error"].lower() in content.lower():
                return False  # Pattern already covered
    
    # Determine target part based on section (A-C in PART1, D-H in PART2, I-M in PART3, N-P in PART4)
    target_part = None
    section_map = {
        "A": CODE_CHECK_PROMPT_PART1,  # A. Structure & Syntax
        "B": CODE_CHECK_PROMPT_PART1,  # B. Shell Options
        "C": CODE_CHECK_PROMPT_PART1,  # C. Variables & Defaults
        "D": CODE_CHECK_PROMPT_PART2,  # D. Quoting & Expansion Safety (continues in PART2)
        "E": CODE_CHECK_PROMPT_PART2,  # E. Here-docs
        "F": CODE_CHECK_PROMPT_PART2,  # F. Logic & Flow Control
        "G": CODE_CHECK_PROMPT_PART2,  # G. Functions
        "H": CODE_CHECK_PROMPT_PART2,  # H. Error Handling (continues in PART3)
        "I": CODE_CHECK_PROMPT_PART3,  # I. Timeouts
        "J": CODE_CHECK_PROMPT_PART3,  # J. Edge Cases
        "K": CODE_CHECK_PROMPT_PART3,  # K. Security
        "L": CODE_CHECK_PROMPT_PART3,  # L. Performance
        "M": CODE_CHECK_PROMPT_PART3,  # M. Environment & Dependencies
        "N": CODE_CHECK_PROMPT_PART4,  # N. Resource Management
        "O": CODE_CHECK_PROMPT_PART4,  # O. Testing & Validation
        "P": CODE_CHECK_PROMPT_PART4,  # P. Build Flag Analysis
    }
    
    # Determine target section based on pattern category
    if "pipe" in pattern["category"].lower():
        target_part = CODE_CHECK_PROMPT_PART2  # D3 section
    elif "bash" in pattern["category"].lower() or "compatibility" in pattern["category"].lower():
        target_part = CODE_CHECK_PROMPT_PART1  # A6 section
    elif "security" in pattern["category"].lower() or "injection" in pattern["category"].lower():
        target_part = CODE_CHECK_PROMPT_PART3  # K section
    elif "cmake" in pattern["category"].lower() or "flag" in pattern["category"].lower():
        target_part = CODE_CHECK_PROMPT_PART4  # M or P section
    elif "error" in pattern["category"].lower() or "failure" in pattern["category"].lower():
        target_part = CODE_CHECK_PROMPT_PART2  # H section
    else:
        # Default to PART1
        target_part = CODE_CHECK_PROMPT_PART1
    
    if not target_part.exists():
        return False
    
    content = target_part.read_text(encoding="utf-8")
    
    # Add to appropriate section based on category
    if "pipe" in pattern["category"].lower() or "performance" in pattern["category"].lower():
        # Add to D3 section (Pipe Pattern Safety)
        if "D3" in content or "Pipe Pattern Safety" in content:
            section_pattern = r'(D3\.\s*\*\*PIPE PATTERN SAFETY\*\*.*?)(\n[E-Z]\.|\n\n[A-Z]\.)'
            addition = f"\n- **Pattern {pattern['id']}**: {pattern['error']}\n  - Detection: {pattern['detection']}\n  - Fix: {pattern['prevention']}\n"
            content = re.sub(section_pattern, rf'\1{addition}\2', content, flags=re.DOTALL)
        else:
            # Add new D3 section
            content += f"\n\nD3. **PIPE PATTERN SAFETY**\n- **Pattern {pattern['id']}**: {pattern['error']}\n  - Detection: {pattern['detection']}\n  - Fix: {pattern['prevention']}\n"
    
    elif "bash" in pattern["category"].lower() or "compatibility" in pattern["category"].lower():
        # Add to A6 section (Bash Version Compatibility)
        if "A6" in content and "BASH VERSION COMPATIBILITY" in content:
            addition = f"\n  - FORBIDDEN: {pattern['error']} - {pattern['prevention']}\n"
            content = re.sub(
                r'(A6\.\s*\*\*BASH VERSION COMPATIBILITY\*\*.*?- FORBIDDEN:.*?\n)',
                rf'\1{addition}',
                content,
                flags=re.DOTALL
            )
    
    target_part.write_text(content, encoding="utf-8")
    return True


def enhance_advanced_cot_prompt(pattern: Dict) -> bool:
    """
    Enhance Advanced-CoT-Multi-Agent-Prompt with pattern if not already covered.
    """
    if not ADVANCED_COT.exists():
        return False
    
    content = ADVANCED_COT.read_text(encoding="utf-8")
    
    # Check if pattern is already covered
    if pattern["detection"] in content or pattern["error"].lower() in content.lower():
        return False
    
    # Add to pattern checking section
    if "Pattern" in content or "P-" in content:
        pattern_section = f"""
**Pattern {pattern["id"]}**: {pattern["error"]}
- Detection: {pattern["detection"]}
- Prevention: {pattern["prevention"]}
- Category: {pattern["category"]}
"""
        # Insert into pattern section
        if "## Pattern Checking" in content or "PHASE P" in content:
            content = re.sub(
                r'(## Pattern Checking|PHASE P.*?)(\n##|\n#)',
                rf'\1{pattern_section}\2',
                content,
                flags=re.DOTALL
            )
        else:
            content += f"\n\n## Pattern Checking\n{pattern_section}"
    
    ADVANCED_COT.write_text(content, encoding="utf-8")
    return True


def main():
    """
    Main function: Extract patterns from CI check results and enhance prompts.
    """
    # This would be called from the pre-commit hook with check results
    check_results = {}
    check_errors = {}
    
    if len(sys.argv) > 1:
        # Parse check results from JSON (passed as first argument)
        try:
            json_input = sys.argv[1]
            # Handle both JSON string and file path
            if json_input.startswith('{'):
                check_data = json.loads(json_input)
            else:
                # Treat as file path
                json_path = Path(json_input)
                if json_path.exists():
                    check_data = json.loads(json_path.read_text(encoding="utf-8"))
                else:
                    check_data = json.loads(json_input)
            
            check_results = check_data.get("results", {})
            check_errors = check_data.get("errors", {})
        except (json.JSONDecodeError, FileNotFoundError) as e:
            print(f"Warning: Could not parse JSON input: {e}")
            # Continue with empty results - no patterns to extract
            check_results = {}
            check_errors = {}
    else:
        # Default: no patterns to extract
        check_results = {}
        check_errors = {}
    
    # Extract patterns
    patterns = extract_error_patterns_from_check_results(check_results, check_errors)
    
    if not patterns:
        print("No new patterns to extract")
        return 0
    
    print(f"Extracted {len(patterns)} error pattern(s)")
    
    # Update pattern repository (for record-keeping)
    if update_pattern_repository(patterns):
        print(f"✓ Updated {PATTERN_REPO.name}")
    
    # CRITICAL: Enhance Code_check_prompt_manual.txt FIRST (authoritative source)
    # Then enhance other prompts that reference the manual
    for pattern in patterns:
        if enhance_code_check_prompt(pattern):
            print(f"✓ Enhanced Code_check_prompt_manual.txt (AUTHORITATIVE) with {pattern['id']}")
        if enhance_advanced_cot_prompt(pattern):
            print(f"✓ Enhanced Advanced-CoT prompt with {pattern['id']}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

