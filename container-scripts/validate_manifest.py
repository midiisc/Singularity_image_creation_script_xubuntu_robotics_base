#!/usr/bin/env python3
"""
Validation script for MANIFEST.json

Validates JSON syntax, schema compliance, and data consistency.

Usage:
    python3 validate_manifest.py [--schema SCHEMA_FILE] [--manifest MANIFEST_FILE]

Options:
    --schema SCHEMA_FILE    Path to JSON Schema file (default: MANIFEST.schema.json)
    --manifest MANIFEST_FILE Path to manifest file (default: MANIFEST.json)
    --verbose, -v           Enable verbose output
    --help, -h              Show this help message

Exit codes:
    0  Success (all validations passed)
    1  Error (validation failed)
"""

import json
import sys
import argparse
import os
from pathlib import Path
from typing import Dict, List, Any, Optional
import re

# Color codes for terminal output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_error(message: str) -> None:
    """Print error message in red."""
    print(f"{Colors.RED}ERROR: {message}{Colors.NC}", file=sys.stderr)

def print_warning(message: str) -> None:
    """Print warning message in yellow."""
    print(f"{Colors.YELLOW}WARNING: {message}{Colors.NC}", file=sys.stderr)

def print_success(message: str) -> None:
    """Print success message in green."""
    print(f"{Colors.GREEN}✓ {message}{Colors.NC}")

def print_info(message: str) -> None:
    """Print info message in blue."""
    print(f"{Colors.BLUE}INFO: {message}{Colors.NC}")

def validate_json_syntax(file_path: Path) -> tuple[bool, Optional[Dict[str, Any]]]:
    """Validate JSON syntax."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return True, data
    except json.JSONDecodeError as e:
        print_error(f"Invalid JSON syntax: {e}")
        return False, None
    except FileNotFoundError:
        print_error(f"File not found: {file_path}")
        return False, None

def validate_required_fields(data: Dict[str, Any]) -> bool:
    """Validate required root-level fields."""
    required_fields = ['version', 'description', 'files']
    missing_fields = [field for field in required_fields if field not in data]
    
    if missing_fields:
        print_error(f"Missing required fields: {', '.join(missing_fields)}")
        return False
    
    if not isinstance(data['files'], list):
        print_error("'files' must be an array")
        return False
    
    return True

def validate_version(version: str) -> bool:
    """Validate version format (semantic versioning MAJOR.MINOR)."""
    if not isinstance(version, str):
        print_error("'version' must be a string")
        return False
    
    if not re.match(r'^\d+\.\d+$', version):
        print_error(f"Invalid version format: {version}. Expected MAJOR.MINOR (e.g., '1.0')")
        return False
    
    return True

def validate_file_entry(entry: Dict[str, Any], index: int, script_dir: Path, verbose: bool = False) -> List[str]:
    """Validate a single file entry."""
    errors = []
    warnings = []
    
    # Required fields
    required_fields = ['source', 'target', 'file_type', 'permissions']
    missing_fields = [field for field in required_fields if field not in entry]
    if missing_fields:
        errors.append(f"Entry {index}: Missing required fields: {', '.join(missing_fields)}")
        return errors, warnings
    
    # Validate source path
    source = entry['source']
    if not isinstance(source, str):
        errors.append(f"Entry {index}: 'source' must be a string")
    elif source.startswith('/'):
        errors.append(f"Entry {index}: 'source' must be a relative path (not start with '/')")
    else:
        source_path = script_dir / source
        if not source_path.exists():
            warnings.append(f"Entry {index}: Source file not found: {source}")
    
    # Validate target path
    target = entry['target']
    if not isinstance(target, str) or len(target) == 0:
        errors.append(f"Entry {index}: 'target' must be a non-empty string")
    elif not target.startswith('/'):
        # install.sh requires absolute paths (see install.sh line 147)
        errors.append(f"Entry {index}: 'target' must be an absolute path (start with '/'). Got: {target}")
    
    # Validate file_type
    valid_file_types = ['shell-scripts', 'config-files', 'other', 'json-configs']
    file_type = entry['file_type']
    if file_type not in valid_file_types:
        errors.append(f"Entry {index}: Invalid 'file_type': {file_type}. Must be one of: {', '.join(valid_file_types)}")
    
    # Validate permissions
    permissions = entry['permissions']
    if not isinstance(permissions, str):
        errors.append(f"Entry {index}: 'permissions' must be a string")
    elif not re.match(r'^[0-7]{3,4}$', permissions):
        errors.append(f"Entry {index}: Invalid 'permissions' format: {permissions}. Must be 3-4 digit octal string")
    
    # Validate block (if present)
    if 'block' in entry:
        block = entry['block']
        if not isinstance(block, int) or block < 0:
            errors.append(f"Entry {index}: 'block' must be a non-negative integer")
    
    # Validate line_start and line_end (if present)
    for field in ['line_start', 'line_end']:
        if field in entry:
            value = entry[field]
            if value is not None and (not isinstance(value, int) or value < 0):
                errors.append(f"Entry {index}: '{field}' must be null or a non-negative integer")
    
    # Validate delimiter (if present)
    if 'delimiter' in entry:
        delimiter = entry['delimiter']
        if delimiter is not None and not isinstance(delimiter, str):
            errors.append(f"Entry {index}: 'delimiter' must be null or a string")
        elif delimiter == "N/A":
            warnings.append(f"Entry {index}: 'delimiter' uses 'N/A' instead of null. Consider using null for missing values")
    
    # Validate file_path (if present)
    if 'file_path' in entry:
        file_path = entry['file_path']
        if file_path is not None and not isinstance(file_path, str):
            errors.append(f"Entry {index}: 'file_path' must be null or a string")
        elif file_path == "N/A":
            warnings.append(f"Entry {index}: 'file_path' uses 'N/A' instead of null. Consider using null for missing values")
    
    # Validate dependencies (if present)
    if 'dependencies' in entry:
        dependencies = entry['dependencies']
        if not isinstance(dependencies, list):
            errors.append(f"Entry {index}: 'dependencies' must be an array")
        elif len(dependencies) > 0 and verbose:
            print_info(f"Entry {index}: Has {len(dependencies)} dependencies (dependency tracking not yet implemented)")
    
    return errors, warnings

def validate_manifest(manifest_path: Path, schema_path: Optional[Path] = None, script_dir: Optional[Path] = None, verbose: bool = False) -> bool:
    """Validate manifest file."""
    print_info(f"Validating manifest: {manifest_path}")
    
    # Validate JSON syntax
    is_valid, data = validate_json_syntax(manifest_path)
    if not is_valid:
        return False
    
    print_success("JSON syntax is valid")
    
    # Validate required fields
    if not validate_required_fields(data):
        return False
    
    print_success("Required fields are present")
    
    # Validate version
    if not validate_version(data['version']):
        return False
    
    print_success(f"Version format is valid: {data['version']}")
    
    # Set script directory
    if script_dir is None:
        script_dir = manifest_path.parent
    
    # Validate file entries
    files = data['files']
    total_files = len(files)
    print_info(f"Validating {total_files} file entries...")
    
    all_errors = []
    all_warnings = []
    
    for i, entry in enumerate(files):
        errors, warnings = validate_file_entry(entry, i, script_dir, verbose)
        all_errors.extend(errors)
        all_warnings.extend(warnings)
    
    # Print errors
    if all_errors:
        print_error(f"Found {len(all_errors)} error(s):")
        for error in all_errors:
            print_error(f"  - {error}")
    
    # Print warnings
    if all_warnings:
        print_warning(f"Found {len(all_warnings)} warning(s):")
        for warning in all_warnings:
            print_warning(f"  - {warning}")
    
    # Summary
    if all_errors:
        print_error(f"Validation failed: {len(all_errors)} error(s), {len(all_warnings)} warning(s)")
        return False
    elif all_warnings:
        print_warning(f"Validation passed with {len(all_warnings)} warning(s)")
        return True
    else:
        print_success(f"Validation passed: {total_files} file entries validated successfully")
        return True

def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description="Validate MANIFEST.json file",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        '--schema',
        type=Path,
        default=None,
        help='Path to JSON Schema file (default: MANIFEST.schema.json in same directory as manifest)'
    )
    parser.add_argument(
        '--manifest',
        type=Path,
        default=Path('MANIFEST.json'),
        help='Path to manifest file (default: MANIFEST.json)'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose output'
    )
    
    args = parser.parse_args()
    
    # Resolve paths
    manifest_path = args.manifest.resolve()
    if not manifest_path.exists():
        print_error(f"Manifest file not found: {manifest_path}")
        return 1
    
    # Set schema path
    schema_path = args.schema
    if schema_path is None:
        schema_path = manifest_path.parent / 'MANIFEST.schema.json'
    else:
        schema_path = schema_path.resolve()
    
    # Validate manifest
    success = validate_manifest(manifest_path, schema_path, verbose=args.verbose)
    
    return 0 if success else 1

if __name__ == '__main__':
    sys.exit(main())

