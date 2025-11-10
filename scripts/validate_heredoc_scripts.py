#!/usr/bin/env python3
"""
Extract and validate shell scripts created via heredoc syntax.
Validates using shellcheck and other shell script best practices.
"""

import os
import re
import sys
import subprocess
import tempfile
import shutil
from pathlib import Path
from typing import List, Tuple, Optional, Dict
from dataclasses import dataclass


@dataclass
class HeredocScript:
    """Represents a shell script extracted from heredoc."""
    file_path: str
    line_start: int
    line_end: int
    target_path: str
    content: str
    delimiter: str
    quoted: bool
    shell_type: str


class Colors:
    """ANSI color codes for terminal output."""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color


class HeredocValidator:
    """Validator for heredoc shell scripts."""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.tmp_dir = project_root / "tmp" / "heredoc_validation"
        self.tmp_dir.mkdir(parents=True, exist_ok=True)
        self.scripts: List[HeredocScript] = []
        self.stats = {
            'total': 0,
            'passed': 0,
            'failed': 0,
            'warnings': 0
        }
        
    def check_shellcheck(self) -> bool:
        """Check if shellcheck is available, install if possible."""
        if shutil.which('shellcheck'):
            return True
        
        print(f"{Colors.YELLOW}Warning: shellcheck not found. Attempting to install...{Colors.NC}")
        
        # Try to install shellcheck
        install_commands = [
            ['sudo', 'apt-get', 'update', '&&', 'sudo', 'apt-get', 'install', '-y', 'shellcheck'],
            ['brew', 'install', 'shellcheck'],
        ]
        
        for cmd in install_commands:
            try:
                # Split command if it contains &&
                if '&&' in cmd:
                    parts = ' '.join(cmd).split(' && ')
                    for part in parts:
                        subprocess.run(part.split(), check=True)
                else:
                    subprocess.run(cmd, check=True)
                if shutil.which('shellcheck'):
                    print(f"{Colors.GREEN}✓ shellcheck installed successfully{Colors.NC}")
                    return True
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue
        
        print(f"{Colors.RED}Error: Cannot install shellcheck automatically.{Colors.NC}")
        print("  Please install it manually from: https://github.com/koalaman/shellcheck#installing")
        return False
    
    def detect_shell_type(self, content: str) -> str:
        """Detect shell type from script content."""
        lines = content.split('\n')
        
        # Check shebang
        if lines and lines[0].startswith('#!'):
            shebang = lines[0]
            if 'bash' in shebang:
                return 'bash'
            elif 'sh' in shebang:
                return 'sh'
        
        # Check for bash-specific features
        bash_patterns = [
            r'set -[euo]',
            r'\[\[ ',
            r'declare -',
            r'local ',
            r'\$\{.*:.*\}',  # Parameter expansion
            r'\(\( ',  # Arithmetic expansion
        ]
        
        for pattern in bash_patterns:
            if re.search(pattern, content):
                return 'bash'
        
        return 'sh'
    
    def is_shell_script(self, target_path: str, content: str) -> bool:
        """Determine if a heredoc contains a shell script."""
        # Exclude non-shell file types
        if target_path.endswith(('.def', '.json', '.json5', '.xml', '.yaml', '.yml', '.kdl', '.ron', '.pc', '.conf')):
            return False
        
        # Exclude Singularity definition files
        if 'Bootstrap:' in content[:200] or '%files' in content[:200] or '%environment' in content[:200]:
            return False
        
        # Exclude JSON/JSON5 files (check for JSON-like structure)
        if content.strip().startswith('{') or content.strip().startswith('['):
            # Check if it looks like JSON (has JSON-like structure)
            if ('"' in content[:100] and ':' in content[:100]) or content.strip().startswith('{'):
                # But allow if it has shell script patterns (might be a shell script that outputs JSON)
                if not any(re.search(pattern, content) for pattern in [r'set -[euo]', r'\[\[ ', r'if \[ ', r'#!/']):
                    return False
        
        # Check file extension
        if target_path.endswith(('.sh', '.bash')):
            return True
        
        # Check for shebang
        if content.strip().startswith('#!'):
            if 'bash' in content[:50] or 'sh' in content[:50]:
                return True
        
        # Check for shell script patterns
        shell_patterns = [
            r'set -[euo]',
            r'\[\[ ',
            r'if \[ ',
            r'for .* in ',
            r'while \[ ',
            r'function ',
            r'\(\)\s*\{',
            r'export ',
        ]
        
        for pattern in shell_patterns:
            if re.search(pattern, content):
                return True
        
        return False
    
    def extract_heredocs(self, file_path: Path) -> List[HeredocScript]:
        """Extract all heredoc scripts from a file."""
        scripts = []
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.splitlines(keepends=True)
        except Exception as e:
            print(f"{Colors.RED}Error reading {file_path}: {e}{Colors.NC}")
            return scripts
        
        i = 0
        while i < len(lines):
            line = lines[i]
            line_num = i + 1
            
            # Match heredoc patterns more flexibly
            # Pattern 1: cat > file <<'EOF' or cat >> file <<'EOF' (handles paths with slashes and spaces)
            match1 = re.search(r'cat\s+>>?\s+([^\s<>"\'$]+(?:/[^\s<>"\'$]+)*|"[^"]+"|\'[^\']+\'|\$\{[^}]+\})\s+<<\s*([\'"]?)([A-Z_][A-Z0-9_]*)\2', line)
            # Pattern 2: if ! cat <<'EOF' > file or if cat <<'EOF' > file
            match2 = re.search(r'if\s+!?\s*cat\s+<<\s*([\'"]?)([A-Z_][A-Z0-9_]*)\1\s*>\s+([^\s<>"\'$]+(?:/[^\s<>"\'$]+)*|"[^"]+"|\'[^\']+\'|\$\{[^}]+\})', line)
            # Pattern 3: if ! cat <<'EOF' > file (alternative format)
            match3 = re.search(r'if\s+!?\s*cat\s+<<\s*([\'"]?)([A-Z_][A-Z0-9_]*)\1\s*>\s*([^\s;]+)', line)
            
            match = match1 or match2 or match3
            if match:
                # Extract components based on which pattern matched
                if match1:
                    # Pattern: cat > file <<'EOF'
                    target_path = match1.group(1).strip("'\"")
                    quoted = bool(match1.group(2))
                    delimiter = match1.group(3)
                elif match2:
                    # Pattern: if ! cat <<'EOF' > file
                    quoted = bool(match2.group(1))
                    delimiter = match2.group(2)
                    target_path = match2.group(3).strip("'\"")
                else:  # match3
                    quoted = bool(match3.group(1))
                    delimiter = match3.group(2)
                    target_path = match3.group(3).strip("'\"")
                
                # Clean up target_path (remove variable syntax for display, but keep original)
                display_path = target_path
                display_path = re.sub(r'\$\{[^}]+\}', 'VAR', display_path)
                display_path = re.sub(r'\$[A-Z_][A-Z0-9_]*', 'VAR', display_path)
                
                # Find the end of the heredoc
                end_line = self._find_heredoc_end(lines, i + 1, delimiter)
                if end_line is None:
                    print(f"{Colors.YELLOW}Warning: Could not find end of heredoc '{delimiter}' starting at line {line_num} in {file_path}{Colors.NC}")
                    i += 1
                    continue
                
                # Extract content (lines between start and end, excluding the delimiter line)
                content_lines = lines[i+1:end_line]
                content = ''.join(content_lines)
                
                # Check if this is a shell script
                if self.is_shell_script(display_path, content):
                    shell_type = self.detect_shell_type(content)
                    script = HeredocScript(
                        file_path=str(file_path),
                        line_start=line_num,
                        line_end=end_line + 1,
                        target_path=display_path,
                        content=content,
                        delimiter=delimiter,
                        quoted=quoted,
                        shell_type=shell_type
                    )
                    scripts.append(script)
                
                i = end_line + 1
            else:
                i += 1
        
        return scripts
    
    def _find_heredoc_end(self, lines: List[str], start_idx: int, delimiter: str) -> Optional[int]:
        """Find the line number where heredoc ends."""
        for i in range(start_idx, len(lines)):
            line = lines[i].strip()
            # Remove trailing semicolon, redirect, or other syntax
            line = re.sub(r'[;>]*$', '', line).strip()
            if line == delimiter:
                return i
        return None
    
    def validate_script(self, script: HeredocScript) -> Tuple[bool, List[str]]:
        """Validate a shell script using shellcheck and other checks."""
        issues = []
        passed = True
        
        # Write script to temporary file
        temp_file = self.tmp_dir / f"script_{self.stats['total']}.sh"
        try:
            temp_file.write_text(script.content, encoding='utf-8')
        except Exception as e:
            issues.append(f"Failed to write temporary file: {e}")
            return False, issues
        
        # Check 1: Syntax validation
        try:
            shell_cmd = 'bash' if script.shell_type == 'bash' else 'sh'
            result = subprocess.run(
                [shell_cmd, '-n', str(temp_file)],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode != 0:
                issues.append(f"Syntax error: {result.stderr}")
                passed = False
        except subprocess.TimeoutExpired:
            issues.append("Syntax check timed out")
            passed = False
        except Exception as e:
            issues.append(f"Syntax check failed: {e}")
            passed = False
        
        # Check 2: Shellcheck validation
        if shutil.which('shellcheck'):
            try:
                result = subprocess.run(
                    ['shellcheck', '-x', '-f', 'gcc', '-s', script.shell_type, str(temp_file)],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                if result.returncode != 0:
                    # Parse shellcheck output
                    for line in result.stdout.split('\n'):
                        if line.strip():
                            issues.append(f"Shellcheck: {line}")
                    self.stats['warnings'] += len([l for l in result.stdout.split('\n') if l.strip()])
                    # Don't fail on shellcheck warnings, just report them
            except subprocess.TimeoutExpired:
                issues.append("Shellcheck timed out")
            except Exception as e:
                issues.append(f"Shellcheck failed: {e}")
        
        # Check 3: Common best practices
        common_issues = self._check_best_practices(script.content, script.shell_type)
        issues.extend(common_issues)
        if common_issues:
            self.stats['warnings'] += len(common_issues)
        
        return passed, issues
    
    def _check_best_practices(self, content: str, shell_type: str) -> List[str]:
        """Check for common shell script best practices."""
        issues = []
        lines = content.split('\n')
        
        # Check for shebang if it's a standalone script
        if lines and not lines[0].startswith('#!'):
            # Check if it looks like a script (has commands, not just config)
            if any(re.search(r'set -|if |for |while |function ', line) for line in lines[:10]):
                issues.append("Missing shebang line")
        
        # Check for error handling
        has_error_handling = bool(re.search(r'set -[euo]|set -o (errexit|nounset|pipefail)', content))
        if not has_error_handling and shell_type == 'bash':
            # Only warn if it's a substantial script
            if len(lines) > 5:
                issues.append("Consider adding 'set -euo pipefail' for error handling")
        
        # Check for unquoted variables in test conditions (basic check)
        test_pattern = r'(test |\[ |\[\[ ).*\$[a-zA-Z_][a-zA-Z0-9_]*[^"]'
        if re.search(test_pattern, content):
            # This is a weak check, but it's a common issue
            issues.append("Potential unquoted variables in test conditions")
        
        # Check for command substitution without proper handling
        # This is complex, so we'll skip it for now
        
        return issues
    
    def process_file(self, file_path: Path):
        """Process a file and extract heredoc scripts."""
        print(f"{Colors.BLUE}Processing: {file_path.relative_to(self.project_root)}{Colors.NC}")
        scripts = self.extract_heredocs(file_path)
        self.scripts.extend(scripts)
        print(f"  Found {len(scripts)} shell script(s) in heredocs")
    
    def validate_all(self):
        """Validate all extracted scripts."""
        print(f"\n{Colors.CYAN}{'='*60}{Colors.NC}")
        print(f"{Colors.CYAN}Validating {len(self.scripts)} script(s){Colors.NC}")
        print(f"{Colors.CYAN}{'='*60}{Colors.NC}\n")
        
        for i, script in enumerate(self.scripts, 1):
            self.stats['total'] += 1
            
            print(f"{Colors.BLUE}{'─'*60}{Colors.NC}")
            print(f"{Colors.BLUE}Script #{i}: {script.target_path}{Colors.NC}")
            print(f"  Location: {script.file_path}:{script.line_start}")
            print(f"  Shell type: {script.shell_type}")
            print(f"  Delimiter: {script.delimiter} (quoted: {script.quoted})")
            print(f"{Colors.BLUE}{'─'*60}{Colors.NC}")
            
            passed, issues = self.validate_script(script)
            
            if passed and not issues:
                print(f"{Colors.GREEN}✓ Validation passed{Colors.NC}")
                self.stats['passed'] += 1
            elif passed:
                print(f"{Colors.YELLOW}⚠ Validation passed with warnings:{Colors.NC}")
                for issue in issues:
                    print(f"  • {issue}")
                self.stats['passed'] += 1
            else:
                print(f"{Colors.RED}✗ Validation failed:{Colors.NC}")
                for issue in issues:
                    print(f"  • {issue}")
                self.stats['failed'] += 1
            
            print()
    
    def print_summary(self):
        """Print validation summary."""
        print(f"\n{Colors.CYAN}{'='*60}{Colors.NC}")
        print(f"{Colors.CYAN}Validation Summary{Colors.NC}")
        print(f"{Colors.CYAN}{'='*60}{Colors.NC}")
        print(f"Total scripts: {self.stats['total']}")
        print(f"{Colors.GREEN}Passed: {self.stats['passed']}{Colors.NC}")
        print(f"{Colors.RED}Failed: {self.stats['failed']}{Colors.NC}")
        print(f"{Colors.YELLOW}Warnings: {self.stats['warnings']}{Colors.NC}")
        print()
        
        if self.stats['failed'] == 0 and self.stats['warnings'] == 0:
            print(f"{Colors.GREEN}✓ All scripts passed validation!{Colors.NC}")
            return 0
        elif self.stats['failed'] == 0:
            print(f"{Colors.YELLOW}⚠ All scripts passed, but some warnings were found.{Colors.NC}")
            return 0
        else:
            print(f"{Colors.RED}✗ Some scripts failed validation.{Colors.NC}")
            return 1


def main():
    """Main function."""
    # Get project root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    print(f"{Colors.BLUE}{'='*60}{Colors.NC}")
    print(f"{Colors.BLUE}  Heredoc Shell Script Validator{Colors.NC}")
    print(f"{Colors.BLUE}{'='*60}{Colors.NC}\n")
    
    validator = HeredocValidator(project_root)
    
    # Check for shellcheck
    has_shellcheck = validator.check_shellcheck()
    if not has_shellcheck:
        print(f"{Colors.YELLOW}Warning: shellcheck not available. Some checks will be skipped.{Colors.NC}\n")
    
    # Find files to process
    files_to_check = [
        project_root / "xubuntu_robotics_base_post_ULTRA_CLEANED.sh",
        project_root / "build_xubuntu_robotics_base.sh",
    ]
    
    # Add scripts directory
    scripts_dir = project_root / "scripts"
    if scripts_dir.exists():
        files_to_check.extend(scripts_dir.rglob("*.sh"))
    
    # Process each file
    for file_path in files_to_check:
        if file_path.exists():
            validator.process_file(file_path)
    
    # Validate all scripts
    if validator.scripts:
        validator.validate_all()
    else:
        print(f"{Colors.YELLOW}No shell scripts found in heredocs.{Colors.NC}")
    
    # Print summary
    return validator.print_summary()


if __name__ == '__main__':
    sys.exit(main())

