#!/usr/bin/env python3
"""
AI-Based File Purpose Checker

Purpose: This is a functional utility script used by the pre-commit hook to detect non-functional files.
It analyzes file content, docstrings, and naming patterns to identify files that should not be committed
(such as test artifacts, analysis reports, summary files, etc.).

This script is a core component of the repository's pre-commit validation system and must be committed.
"""

import sys
from pathlib import Path
from typing import Optional, Dict, List, Tuple
import re

REPO_ROOT = Path(__file__).parent.parent.parent


def check_file_has_docstring(file_path: Path) -> Tuple[bool, Optional[str]]:
    """
    Check if file has proper docstring/header comment.
    Returns (has_docstring, reason_if_missing)
    """
    if not file_path.exists():
        return False, "File does not exist"
    
    # Skip non-code files
    code_extensions = {'.sh', '.py', '.cpp', '.c', '.h', '.hpp', '.js', '.ts', '.java', '.go', '.rs'}
    if file_path.suffix not in code_extensions:
        return True, None  # Non-code files don't need docstrings
    
    try:
        content = file_path.read_text(encoding='utf-8', errors='ignore')
        lines = content.split('\n')[:20]  # Check first 20 lines
        
        # Check for various docstring/comment patterns
        has_shebang = False
        has_docstring = False
        has_header_comment = False
        
        for i, line in enumerate(lines):
            # Check for shebang
            if i == 0 and line.startswith('#!'):
                has_shebang = True
                continue
            
            # Skip empty lines
            if not line.strip():
                continue
            
            # Check for docstring patterns
            if file_path.suffix == '.py':
                # Python: """docstring""" or '''docstring'''
                if re.match(r'^\s*""".*"""', line) or re.match(r"^\s*'''.*'''", line):
                    has_docstring = True
                    break
                if re.match(r'^\s*"""', line) or re.match(r"^\s*'''", line):
                    has_docstring = True
                    break
            elif file_path.suffix in {'.sh', '.cpp', '.c', '.h', '.hpp', '.js', '.ts', '.java', '.go', '.rs'}:
                # Shell/C/C++/etc: Check for header comment block
                if line.strip().startswith('#') or line.strip().startswith('//') or line.strip().startswith('/*'):
                    # Check if it's a meaningful comment (not just a single #)
                    comment_text = re.sub(r'^[\s#/*]*', '', line).strip()
                    if len(comment_text) > 10:  # Meaningful comment
                        has_header_comment = True
                        # Check if it continues (multi-line comment block)
                        if i < len(lines) - 1:
                            next_line = lines[i + 1]
                            if (next_line.strip().startswith('#') or 
                                next_line.strip().startswith('//') or
                                next_line.strip().startswith('*')):
                                has_header_comment = True
                                break
        
        if has_docstring or has_header_comment:
            return True, None
        
        # Reason for missing
        if has_shebang:
            return False, "File has shebang but missing header comment/docstring describing purpose"
        else:
            return False, "File missing header comment/docstring describing purpose"
    
    except Exception as e:
        return False, f"Error reading file: {e}"


def analyze_file_purpose(file_path: Path) -> Dict[str, any]:
    """
    Analyze file to determine if it's non-functional.
    Uses content analysis, not just filename patterns.
    """
    result = {
        "is_non_functional": False,
        "reason": None,
        "file_type": None,
        "has_docstring": False,
        "suggested_action": None
    }
    
    if not file_path.exists():
        return result
    
    try:
        content = file_path.read_text(encoding='utf-8', errors='ignore')
        basename = file_path.name.lower()
        path_str = str(file_path).lower()
        
        # Check for docstring
        has_doc, doc_reason = check_file_has_docstring(file_path)
        result["has_docstring"] = has_doc
        if not has_doc:
            result["suggested_action"] = f"Add header comment/docstring: {doc_reason}"
        
        # Analyze content for non-functional indicators
        content_lower = content.lower()
        first_50_lines = '\n'.join(content.split('\n')[:50])
        
        # Test file indicators (content-based, not just filename)
        test_indicators = [
            r'test.*dry.*run',
            r'dry.*run.*test',
            r'for.*testing.*only',
            r'temporary.*test',
            r'#.*test.*file',
            r'#.*dry.*run',
            r'purpose.*test',
            r'purpose.*dry.*run',
        ]
        
        # Analysis/documentation indicators
        analysis_indicators = [
            r'analysis.*report',
            r'summary.*of',
            r'findings.*from',
            r'audit.*results',
            r'investigation.*results',
            r'#.*analysis',
            r'#.*summary',
            r'#.*report',
        ]
        
        # Check if file is clearly a test/dry-run file
        is_test_file = False
        test_reason = None
        
        for pattern in test_indicators:
            if re.search(pattern, first_50_lines, re.IGNORECASE):
                is_test_file = True
                test_reason = f"Content indicates test/dry-run file (matched: {pattern})"
                break
        
        # Check if file is analysis/documentation
        is_analysis_file = False
        analysis_reason = None
        
        for pattern in analysis_indicators:
            if re.search(pattern, first_50_lines, re.IGNORECASE):
                is_analysis_file = True
                analysis_reason = f"Content indicates analysis/documentation file (matched: {pattern})"
                break
        
        # Check filename patterns (secondary check)
        filename_analysis = False
        if (any(term in basename for term in ['test_', '_test', 'dryrun', 'dry-run', 'temp_', '_temp']) and
            file_path.suffix in {'.sh', '.py'} and
            'test' not in path_str and 'tests' not in path_str and 'spec' not in path_str):
            filename_analysis = True
        
        # Determine if non-functional
        if is_test_file:
            result["is_non_functional"] = True
            result["reason"] = test_reason
            result["file_type"] = "test/dry-run"
            result["suggested_action"] = "Remove test file after testing completes"
        elif is_analysis_file:
            result["is_non_functional"] = True
            result["reason"] = analysis_reason
            result["file_type"] = "analysis/documentation"
            result["suggested_action"] = "Remove analysis file - all analysis should be inline in chat"
        elif filename_analysis and not has_doc:
            # Filename suggests test but no docstring to confirm purpose
            result["is_non_functional"] = True
            result["reason"] = "Filename suggests test/temporary file but missing docstring to confirm purpose"
            result["file_type"] = "suspected test/temporary"
            result["suggested_action"] = "Add docstring explaining file purpose, or remove if temporary"
        
    except Exception as e:
        result["reason"] = f"Error analyzing file: {e}"
    
    return result


def main():
    """Main function: Check files for non-functional status and docstring requirements."""
    if len(sys.argv) < 2:
        print("Usage: ai_file_purpose_checker.py <file1> [file2] ...")
        sys.exit(1)
    
    non_functional_files = []
    missing_docstring_files = []
    
    for file_arg in sys.argv[1:]:
        file_path = Path(file_arg)
        if not file_path.is_absolute():
            file_path = REPO_ROOT / file_path
        
        analysis = analyze_file_purpose(file_path)
        
        if analysis["is_non_functional"]:
            non_functional_files.append({
                "path": str(file_path.relative_to(REPO_ROOT)),
                "reason": analysis["reason"],
                "type": analysis["file_type"],
                "action": analysis["suggested_action"]
            })
        
        if not analysis["has_docstring"]:
            missing_docstring_files.append({
                "path": str(file_path.relative_to(REPO_ROOT)),
                "reason": analysis.get("suggested_action", "Missing docstring")
            })
    
    # Output results
    if non_functional_files:
        print("\n⚠️  NON-FUNCTIONAL FILES DETECTED:")
        for file_info in non_functional_files:
            print(f"  ✗ {file_info['path']}")
            print(f"    Reason: {file_info['reason']}")
            print(f"    Type: {file_info['type']}")
            print(f"    Action: {file_info['action']}")
        print()
    
    if missing_docstring_files:
        print("\n⚠️  FILES MISSING DOCSTRINGS:")
        for file_info in missing_docstring_files:
            print(f"  ✗ {file_info['path']}: {file_info['reason']}")
        print()
    
    # Exit code: 1 if issues found
    if non_functional_files or missing_docstring_files:
        sys.exit(1)
    
    sys.exit(0)


if __name__ == "__main__":
    main()

