#!/usr/bin/env python3
"""
Verify that all extracted heredoc files match the original content exactly.
"""

import json
import re
import sys
from pathlib import Path
from typing import Optional


def find_heredoc_delimiter(file_path: Path, line_num: int) -> Optional[str]:
    """Find the heredoc delimiter for a given line."""
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    if line_num - 1 >= len(lines):
        return None
    
    line = lines[line_num - 1]
    
    # Match heredoc patterns
    match1 = re.search(r'cat\s+>>?\s+.*<<\s*([\'"]?)([A-Z_][A-Z0-9_]*)\1', line)
    match2 = re.search(r'if\s+!?\s*cat\s+<<\s*([\'"]?)([A-Z_][A-Z0-9_]*)\1', line)
    
    match = match1 or match2
    if match:
        if match1:
            return match1.group(2)
        else:
            return match2.group(2)
    
    return None


def extract_heredoc_content(file_path: Path, line_start: int, line_end: int, delimiter: str) -> str:
    """Extract heredoc content from original file (robust version).
    
    line_start: Line number (1-indexed) where heredoc starts (e.g., line with 'cat > file <<EOF')
    line_end: Line number (1-indexed) where delimiter is found
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Convert to 0-indexed
    heredoc_start_idx = line_start - 1  # Line with 'cat > file <<EOF'
    heredoc_end_idx = line_end - 1  # Line with delimiter
    
    # Extract content: lines AFTER the heredoc declaration, UP TO (but not including) the delimiter line
    # So we extract from (start_idx + 1) to (end_idx)
    content_lines = lines[heredoc_start_idx + 1:heredoc_end_idx]
    
    return ''.join(content_lines)


def verify_extraction():
    """Verify all extracted files match originals."""
    project_root = Path(__file__).parent.parent
    post_script = project_root / "xubuntu_robotics_base_full.sh"
    build_script = project_root / "build_xubuntu_robotics_base.sh"
    container_scripts_dir = project_root / "container-scripts"
    manifest_path = container_scripts_dir / "MANIFEST.json"
    
    if not manifest_path.exists():
        print("Error: MANIFEST.json not found")
        return 1
    
    with open(manifest_path, 'r', encoding='utf-8') as f:
        manifest = json.load(f)
    
    print("=" * 60)
    print("Verifying Extracted Files")
    print("=" * 60)
    print()
    
    all_match = True
    total = 0
    matched = 0
    failed = 0
    
    files_key = 'files' if 'files' in manifest else 'scripts'
    file_list = manifest.get(files_key, [])
    
    for file_entry in file_list:
        total += 1
        source_path = file_entry['source']
        line_start = file_entry['line_start']
        line_end = file_entry['line_end']
        target = file_entry['target']
        delimiter = file_entry.get('delimiter', 'EOF')
        
        # Determine which source file
        if 'build_xubuntu_robotics_base.sh' in str(file_entry.get('file_path', '')):
            source_file = build_script
        else:
            source_file = post_script
        
        # Get extracted file
        extracted_path = container_scripts_dir / source_path
        if not extracted_path.exists():
            print(f"✗ {source_path}: File not found")
            failed += 1
            all_match = False
            continue
        
        # Use delimiter from manifest (should always be present)
        # Only try to find it if it's missing (shouldn't happen)
        if not delimiter:
            delimiter = find_heredoc_delimiter(source_file, line_start)
            if not delimiter:
                print(f"✗ {source_path}: Could not find delimiter (manifest missing delimiter field)")
                failed += 1
                all_match = False
                continue
        
        # Extract original content
        original_content = extract_heredoc_content(source_file, line_start, line_end, delimiter)
        extracted_content = extracted_path.read_text(encoding='utf-8')
        
        # Compare (normalize line endings)
        original_normalized = original_content.replace('\r\n', '\n').replace('\r', '\n')
        extracted_normalized = extracted_content.replace('\r\n', '\n').replace('\r', '\n')
        
        if original_normalized == extracted_normalized:
            print(f"✓ {source_path}")
            matched += 1
        else:
            print(f"✗ {source_path}: Content mismatch")
            print(f"  Original length: {len(original_normalized)}")
            print(f"  Extracted length: {len(extracted_normalized)}")
            
            # Show first difference
            orig_lines = original_normalized.split('\n')
            extr_lines = extracted_normalized.split('\n')
            for i, (orig, extr) in enumerate(zip(orig_lines, extr_lines), 1):
                if orig != extr:
                    print(f"  First difference at line {i}:")
                    print(f"    Original: {repr(orig[:80])}")
                    print(f"    Extracted: {repr(extr[:80])}")
                    break
            
            failed += 1
            all_match = False
    
    print()
    print("=" * 60)
    print("Verification Summary")
    print("=" * 60)
    print(f"Total files: {total}")
    print(f"Matched: {matched}")
    print(f"Failed: {failed}")
    print()
    
    if all_match:
        print("✓ All files match exactly!")
        return 0
    else:
        print("✗ Some files do not match")
        return 1


if __name__ == '__main__':
    sys.exit(verify_extraction())

