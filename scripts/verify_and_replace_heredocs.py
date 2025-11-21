#!/usr/bin/env python3
"""
Comprehensive heredoc verification and replacement script.
1. Verifies all extracted files match their heredocs
2. Finds heredocs that need replacement
3. Generates replacement code
"""

import json
import re
from pathlib import Path
from typing import List, Tuple, Dict

def load_manifest(manifest_path: Path) -> Dict:
    """Load MANIFEST.json."""
    with open(manifest_path, 'r') as f:
        return json.load(f)

def extract_heredoc_content(lines: List[str], start_line: int, delimiter: str) -> Tuple[str, int]:
    """Extract heredoc content and find end line.
    
    Returns:
        Tuple of (content, end_line) or (None, None) if delimiter not found
    """
    start_idx = start_line - 1  # Convert to 0-indexed
    end_idx = None
    
    # Look ahead up to 1000 lines (should be enough for any heredoc)
    max_lookahead = min(start_idx + 1000, len(lines))
    
    for i in range(start_idx + 1, max_lookahead):
        line = lines[i]
        
        # Strategy 1: Exact match after stripping (most common case)
        stripped = line.strip()
        if stripped == delimiter:
            end_idx = i
            break
        
        # Strategy 2: Delimiter followed by semicolon or redirect
        if stripped in [f"{delimiter};", f"{delimiter}>", f"{delimiter};>"]:
            end_idx = i
            break
        
        # Strategy 3: Delimiter with only whitespace and optional comment
        # Match: "EOF", "  EOF  ", "EOF  # comment", "  EOF  # comment"
        if re.match(rf'^\s*{re.escape(delimiter)}\s*(#.*)?\s*$', line):
            end_idx = i
            break
        
        # Strategy 4: Delimiter at start, followed by optional punctuation and whitespace
        # Remove trailing semicolons, redirects, whitespace, then check
        cleaned = re.sub(r'[;>\s#].*$', '', stripped)
        if cleaned == delimiter:
            end_idx = i
            break
    
    if end_idx is None:
        return None, None
    
    content = ''.join(lines[start_idx + 1:end_idx])
    return content, end_idx + 1  # Return 1-indexed end line

def verify_heredoc_termination(script_path: Path, manifest_path: Path) -> List[Dict]:
    """Verify all heredocs in manifest are properly terminated.
    
    Returns:
        List of dicts with 'file', 'line', 'delimiter', 'status' (missing/mismatched/ok)
    """
    manifest = load_manifest(manifest_path)
    
    with open(script_path, 'r') as f:
        script_lines = f.readlines()
    
    issues = []
    
    for file_entry in manifest['files']:
        line_start = file_entry['line_start']
        delimiter = file_entry['delimiter']
        
        # Extract heredoc content and find end
        heredoc_content, end_line = extract_heredoc_content(script_lines, line_start, delimiter)
        
        if heredoc_content is None or end_line is None:
            issues.append({
                'file': file_entry['source'],
                'line': line_start,
                'delimiter': delimiter,
                'status': 'missing',
                'target': file_entry.get('target', 'N/A')
            })
        else:
            # Check for mismatched delimiter (case sensitivity)
            if end_line - 1 < len(script_lines):
                end_line_content = script_lines[end_line - 1].strip()
                # Remove optional comment and whitespace
                end_delimiter = re.sub(r'\s*(#.*)?$', '', end_line_content)
                if end_delimiter != delimiter:
                    issues.append({
                        'file': file_entry['source'],
                        'line': line_start,
                        'delimiter': delimiter,
                        'end_line': end_line,
                        'end_delimiter': end_delimiter,
                        'status': 'mismatched',
                        'target': file_entry.get('target', 'N/A')
                    })
                else:
                    # Check for trailing content (delimiter should be alone on line)
                    if not re.match(rf'^\s*{re.escape(delimiter)}\s*(#.*)?\s*$', script_lines[end_line - 1]):
                        issues.append({
                            'file': file_entry['source'],
                            'line': line_start,
                            'delimiter': delimiter,
                            'end_line': end_line,
                            'status': 'trailing_content',
                            'target': file_entry.get('target', 'N/A')
                        })
    
    return issues

def verify_extracted_files(script_path: Path, manifest_path: Path, container_scripts_dir: Path):
    """Verify all extracted files match their heredocs."""
    manifest = load_manifest(manifest_path)
    
    with open(script_path, 'r') as f:
        script_lines = f.readlines()
    
    mismatches = []
    missing_files = []
    verified = []
    
    for file_entry in manifest['files']:
        line_start = file_entry['line_start']
        delimiter = file_entry['delimiter']
        source_path = container_scripts_dir / file_entry['source']
        target_path = file_entry['target']
        
        # Extract heredoc content from script
        heredoc_content, end_line = extract_heredoc_content(script_lines, line_start, delimiter)
        
        if heredoc_content is None:
            mismatches.append({
                'file': file_entry['source'],
                'line': line_start,
                'issue': 'Could not find heredoc end'
            })
            continue
        
        # Read extracted file
        if not source_path.exists():
            missing_files.append({
                'file': file_entry['source'],
                'line': line_start,
                'target': target_path
            })
            continue
        
        extracted_content = source_path.read_text(encoding='utf-8')
        
        # Compare (normalize whitespace)
        heredoc_normalized = heredoc_content.strip()
        extracted_normalized = extracted_content.strip()
        
        if heredoc_normalized != extracted_normalized:
            mismatches.append({
                'file': file_entry['source'],
                'line': line_start,
                'target': target_path,
                'heredoc_len': len(heredoc_content),
                'extracted_len': len(extracted_content),
                'issue': 'Content mismatch'
            })
        else:
            verified.append(file_entry['source'])
    
    return verified, mismatches, missing_files

def find_heredocs_needing_replacement(script_path: Path, manifest_path: Path):
    """Find heredocs that need to be replaced with calls/comments."""
    manifest = load_manifest(manifest_path)
    manifest_by_line = {f['line_start']: f for f in manifest['files']}
    manifest_by_target = {f['target']: f for f in manifest['files']}
    
    with open(script_path, 'r') as f:
        lines = f.readlines()
    
    needs_replacement = []
    already_replaced = []
    
    for i, line in enumerate(lines, 1):
        # Check for heredoc patterns
        if re.search(r'cat\s+>>?\s+', line) and '<<' in line:
            path_match = re.search(r'cat\s+>>?\s+([^\s<>]+)', line)
            if path_match:
                path = path_match.group(1).strip("'\"")
                
                # Skip dynamic paths
                if re.search(r'\$\{[^}]+\}', path) or re.search(r'^\$[A-Z_][A-Z0-9_]*', path):
                    continue
                
                # Check if in manifest
                if i in manifest_by_line or path in manifest_by_target:
                    # Check if already has replacement comment
                    has_comment = False
                    for j in range(max(0, i-15), min(len(lines), i+1)):
                        if 'is installed via install.sh' in lines[j] or ('Source:' in lines[j] and 'Target:' in lines[j]):
                            has_comment = True
                            break
                    
                    if has_comment:
                        already_replaced.append((i, path))
                    else:
                        file_entry = manifest_by_line.get(i) or manifest_by_target.get(path)
                        needs_replacement.append({
                            'line': i,
                            'path': path,
                            'entry': file_entry
                        })
        
        # Check for python3 heredocs
        if 'python3' in line and '<<' in line and 'python3' in line.lower():
            delim_match = re.search(r'<<\s*[\'"]?([A-Z_][A-Z0-9_]*)[\'"]?', line)
            if delim_match:
                delim = delim_match.group(1)
                # Check if in manifest
                file_entry = None
                for entry in manifest['files']:
                    if entry['line_start'] == i or entry['delimiter'] == delim:
                        file_entry = entry
                        break
                
                if file_entry:
                    # Check if already replaced
                    has_call = False
                    for j in range(max(0, i-5), min(len(lines), i+5)):
                        if file_entry['target'] in lines[j] and 'python3' in lines[j]:
                            has_call = True
                            break
                    
                    if not has_call:
                        needs_replacement.append({
                            'line': i,
                            'path': None,
                            'entry': file_entry,
                            'type': 'python'
                        })
    
    return needs_replacement, already_replaced

def main():
    project_root = Path(__file__).parent.parent
    script_path = project_root / "xubuntu_robotics_base_full.sh"
    manifest_path = project_root / "container-scripts" / "MANIFEST.json"
    container_scripts_dir = project_root / "container-scripts"
    
    print("=" * 70)
    print("Heredoc Verification and Replacement Analysis")
    print("=" * 70)
    print()
    
    # Verify heredoc termination FIRST
    print("Step 1: Verifying heredoc termination...")
    termination_issues = verify_heredoc_termination(script_path, manifest_path)
    
    if termination_issues:
        print(f"  WARNING: Found {len(termination_issues)} heredoc termination issues:")
        for issue in termination_issues[:10]:
            if issue['status'] == 'missing':
                print(f"    {issue['file']} (line {issue['line']}): Missing delimiter '{issue['delimiter']}'")
            elif issue['status'] == 'mismatched':
                print(f"    {issue['file']} (line {issue['line']}): Delimiter mismatch '{issue['delimiter']}' vs '{issue.get('end_delimiter', 'N/A')}'")
            elif issue['status'] == 'trailing_content':
                print(f"    {issue['file']} (line {issue['line']}): Delimiter '{issue['delimiter']}' has trailing content")
        if len(termination_issues) > 10:
            print(f"    ... and {len(termination_issues) - 10} more issues")
        print()
    else:
        print("  All heredocs properly terminated")
        print()
    
    # Verify extracted files
    print("Step 2: Verifying extracted files...")
    verified, mismatches, missing_files = verify_extracted_files(
        script_path, manifest_path, container_scripts_dir
    )
    
    print(f"  Verified: {len(verified)} files")
    print(f"  Mismatches: {len(mismatches)} files")
    print(f"  Missing files: {len(missing_files)} files")
    print()
    
    if mismatches:
        print("MISMATCHES:")
        for m in mismatches[:10]:
            print(f"  {m['file']} (line {m['line']}): {m.get('issue', 'unknown')}")
        print()
    
    if missing_files:
        print("MISSING FILES:")
        for m in missing_files[:10]:
            print(f"  {m['file']} (line {m['line']}) -> {m['target']}")
        print()
    
    # Find heredocs needing replacement
    print("Step 3: Finding heredocs needing replacement...")
    needs_replacement, already_replaced = find_heredocs_needing_replacement(
        script_path, manifest_path
    )
    
    print(f"  Needs replacement: {len(needs_replacement)}")
    print(f"  Already replaced: {len(already_replaced)}")
    print()
    
    if needs_replacement:
        print("NEEDS REPLACEMENT:")
        for item in needs_replacement[:20]:
            entry = item['entry']
            if entry:
                print(f"  Line {item['line']}: {entry['target']} ({entry.get('file_type', 'unknown')})")
            else:
                print(f"  Line {item['line']}: {item.get('path', 'N/A')}")
        print()
    
    print("=" * 70)
    print("Analysis complete!")
    print("=" * 70)

if __name__ == '__main__':
    main()

