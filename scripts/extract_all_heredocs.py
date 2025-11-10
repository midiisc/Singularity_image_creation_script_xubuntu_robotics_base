#!/usr/bin/env python3
"""
Comprehensive heredoc extraction tool.
Extracts ALL heredoc files (shell scripts, JSON, config files, etc.) and organizes by type.
"""

import json
import re
import sys
from pathlib import Path
from typing import List, Tuple, Optional, Dict
from dataclasses import dataclass, asdict
from enum import Enum


class FileType(Enum):
    """File type categories."""
    SHELL_SCRIPT = "shell-scripts"
    PYTHON_SCRIPT = "python-scripts"
    JSON_CONFIG = "json-configs"
    CONFIG_FILE = "config-files"
    LAYOUT_CONFIG = "layout-configs"
    DOCS = "docs"
    OTHER = "other"


@dataclass
class HeredocFile:
    """Metadata for a heredoc file."""
    source: str  # Relative path in container-scripts/
    target: str  # Target path in container
    file_type: FileType
    permissions: str
    block: int
    block_name: str
    description: str
    dependencies: List[str]
    line_start: int
    line_end: int
    delimiter: str
    file_path: str = ""  # Source file path (post_script or build_script)
    content: str = ""


class ComprehensiveHeredocExtractor:
    """Extract ALL heredoc files and organize by type."""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.container_scripts_dir = project_root / "container-scripts"
        self.post_script = project_root / "xubuntu_robotics_base_post_ULTRA_CLEANED.sh"
        self.build_script = project_root / "build_xubuntu_robotics_base.sh"
        self.blocks: Dict[int, str] = {}
        self.files: List[HeredocFile] = []
        
    def load_block_info(self):
        """Load block information from post script."""
        if not self.post_script.exists():
            return
        
        with open(self.post_script, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        current_block = None
        current_block_name = None
        
        for i, line in enumerate(lines, 1):
            # Match block headers: # BLOCK N: NAME
            match = re.match(r'^# BLOCK (\d+):\s*(.+)$', line)
            if match:
                current_block = int(match.group(1))
                current_block_name = match.group(2).strip()
                self.blocks[current_block] = current_block_name
    
    def get_block_for_line(self, line_num: int) -> Tuple[Optional[int], Optional[str]]:
        """Get block number and name for a given line number."""
        if not self.blocks:
            self.load_block_info()
        
        current_block = None
        current_block_name = None
        
        with open(self.post_script, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        for i in range(line_num - 1, -1, -1):
            if i >= len(lines):
                continue
            line = lines[i]
            match = re.match(r'^# BLOCK (\d+):\s*(.+)$', line)
            if match:
                current_block = int(match.group(1))
                current_block_name = match.group(2).strip()
                break
        
        return current_block, current_block_name
    
    def _find_heredoc_end(self, lines: List[str], start_idx: int, delimiter: str) -> Optional[int]:
        """Find the line number where heredoc ends (robust version).
        
        Handles various delimiter formats:
        - EOF
        - EOF;
        - EOF>
        - EOF  # comment
        -   EOF  (with indentation)
        - APS (on its own line)
        - CPS (on its own line)
        """
        # Look ahead up to 1000 lines (should be enough for any heredoc)
        max_lookahead = min(start_idx + 1000, len(lines))
        
        for i in range(start_idx, max_lookahead):
            line = lines[i]
            
            # Strategy 1: Exact match after stripping (most common case)
            stripped = line.strip()
            if stripped == delimiter:
                return i
            
            # Strategy 2: Delimiter followed by semicolon or redirect
            if stripped in [f"{delimiter};", f"{delimiter}>", f"{delimiter};>"]:
                return i
            
            # Strategy 3: Delimiter with only whitespace and optional comment
            # Match: "EOF", "  EOF  ", "EOF  # comment", "  EOF  # comment"
            if re.match(rf'^\s*{re.escape(delimiter)}\s*(#.*)?\s*$', line):
                return i
            
            # Strategy 4: Delimiter at start, followed by optional punctuation and whitespace
            # Remove trailing semicolons, redirects, whitespace, then check
            cleaned = re.sub(r'[;>\s#].*$', '', stripped)
            if cleaned == delimiter:
                return i
        
        return None
    
    def _detect_file_type(self, target_path: str, content: str) -> FileType:
        """Detect file type from target path and content."""
        target_lower = target_path.lower()
        content_start = content.strip()[:200]
        content_lower = content_start.lower()
        
        # Python scripts - check shebang first
        if content.strip().startswith('#!'):
            if 'python' in content[:50]:
                return FileType.PYTHON_SCRIPT
            if 'bash' in content[:50] or 'sh' in content[:50]:
                return FileType.SHELL_SCRIPT
        
        # Python scripts by target path
        if target_lower.endswith('.py'):
            return FileType.PYTHON_SCRIPT
        
        # JSON files
        if target_lower.endswith(('.json', '.json5')):
            return FileType.JSON_CONFIG
        if content_start.startswith('{') or content_start.startswith('['):
            if ('"' in content_start and ':' in content_start) or content_start.startswith('{'):
                # Check if it's actually JSON (not a shell script that outputs JSON)
                if not any(re.search(pattern, content_start) for pattern in [r'set -[euo]', r'\[\[ ', r'if \[ ', r'#!/']):
                    return FileType.JSON_CONFIG
        
        # APT preferences files
        if '/etc/apt/preferences.d/' in target_path:
            # Check if it's a preferences file (Package: Pin: Pin-Priority:)
            if re.search(r'Package:\s*\S+|Pin:\s*\S+|Pin-Priority:\s*-?\d+', content_start, re.IGNORECASE):
                return FileType.CONFIG_FILE
        
        # APT config files
        if '/etc/apt/apt.conf.d/' in target_path or '/etc/dpkg/dpkg.cfg.d/' in target_path:
            return FileType.CONFIG_FILE
        
        # Environment config files
        if target_path.endswith('/etc/environment') or 'LD_LIBRARY_PATH' in content_start or 'PKG_CONFIG_PATH' in content_start:
            return FileType.CONFIG_FILE
        
        # Documentation files
        if '/usr/local/share/doc/' in target_path or '/usr/share/doc/' in target_path:
            if 'guide' in target_lower or 'readme' in target_lower or '===' in content_start:
                return FileType.DOCS
        
        # Config files
        if target_lower.endswith(('.conf', '.pc', '.kdl', '.ron', '.yaml', '.yml', '.pref')):
            return FileType.CONFIG_FILE
        
        # Layout configs (Zellij, Tmux layouts)
        if 'layout' in target_lower or 'LAYOUT' in content[:100]:
            return FileType.LAYOUT_CONFIG
        
        # Shell scripts (default for .sh files)
        if target_lower.endswith(('.sh', '.bash')):
            return FileType.SHELL_SCRIPT
        
        # Check for shell script patterns
        shell_patterns = [
            r'set -[euo]',
            r'\[\[ ',
            r'if \[ ',
            r'for .* in ',
            r'while \[ ',
            r'function ',
            r'export ',
        ]
        for pattern in shell_patterns:
            if re.search(pattern, content):
                return FileType.SHELL_SCRIPT
        
        # Check for Python patterns (import statements, class definitions)
        python_patterns = [
            r'^import\s+\w+',
            r'^from\s+\w+\s+import',
            r'^class\s+\w+',
            r'^def\s+\w+\s*\(',
        ]
        for pattern in python_patterns:
            if re.search(pattern, content_start, re.MULTILINE):
                return FileType.PYTHON_SCRIPT
        
        return FileType.OTHER
    
    def _generate_descriptive_name(self, target_path: str, content: str, file_type: FileType,
                                   block: Optional[int], block_name: Optional[str]) -> str:
        """Generate descriptive filename."""
        # Clean target path first (remove variable syntax)
        target_clean = re.sub(r'\$\{[^}]+\}', '', target_path)
        target_clean = re.sub(r'\$[A-Z_][A-Z0-9_]*', '', target_clean)
        
        # Get base name and extension from cleaned path
        path_obj = Path(target_clean)
        base_name = path_obj.stem  # Name without extension (handles .txt, .sh, etc. correctly)
        existing_ext = path_obj.suffix[1:] if path_obj.suffix else None  # Extension without dot
        
        # Use target path as primary source
        target_lower = target_path.lower()
        
        # Map common patterns to descriptive names
        name_map = {
            'apt-aria': 'apt-wrapper-aria2c-accelerated-downloads',
            'ros_multiterm_zellij': 'ros-multiterminal-zellij-launcher',
            'ros_multiterm_tmux': 'ros-multiterminal-tmux-launcher',
            'ros_multiterm': 'ros-multiterminal-launcher',
            'zenoh_start': 'zenoh-router-bridge-startup',
            'zenoh_stop': 'zenoh-router-bridge-shutdown',
            'zenoh_status': 'zenoh-router-bridge-status-check',
            'unset_pythonpath': 'conda-activation-hook-pythonpath-management',
            'restore_pythonpath': 'conda-deactivation-hook-pythonpath-restore',
            'intel-mkl.sh': 'intel-mkl-environment-setup',
            'suitesparse.sh': 'suitesparse-library-path-configuration',
            'conda.sh': 'conda-profile-path-configuration',
            'vnc_select': 'vnc-server-selection-utility',
            'remote_desktop': 'remote-desktop-launcher-menu',
            'optimize_network': 'network-optimization-tuning',
            'benchmark': 'system-benchmarking-suite',
            'prune_apt_cache': 'apt-cache-pruning-cleanup',
            'prune_conda_cache': 'conda-cache-pruning-cleanup',
        }
        
        # Check if we have a mapped descriptive name
        descriptive_base = None
        for pattern, descriptive in name_map.items():
            if pattern in target_lower:
                descriptive_base = descriptive
                break
        
        # Use descriptive name if found, otherwise use base name
        if descriptive_base:
            name_part = descriptive_base
        else:
            name_part = base_name.replace('_', '-')
        
        # Determine extension: use existing extension if valid, otherwise get from file type
        if existing_ext and existing_ext in ['sh', 'bash', 'py', 'json', 'json5', 'conf', 'kdl', 'ron', 'yaml', 'yml', 'pc', 'cmake', 'toml', 'pref', 'desktop', 'xml', 'txt']:
            ext = existing_ext
        else:
            ext = self._get_extension(target_path, file_type)
            # Don't add extension if name_part already ends with it (shouldn't happen, but safety check)
            if name_part.endswith(f".{ext}"):
                return name_part
        
        return f"{name_part}.{ext}"
    
    def _get_extension(self, target_path: str, file_type: FileType) -> str:
        """Get file extension based on target path and type."""
        # Clean target path (remove variable syntax)
        target_clean = re.sub(r'\$\{[^}]+\}', '', target_path)
        target_clean = re.sub(r'\$[A-Z_][A-Z0-9_]*', '', target_clean)
        
        # Check for common extensions in cleaned path
        path_obj = Path(target_clean)
        if path_obj.suffix:
            ext = path_obj.suffix[1:]  # Remove leading dot
            # Validate extension is reasonable
            if ext in ['sh', 'bash', 'py', 'json', 'json5', 'conf', 'kdl', 'ron', 'yaml', 'yml', 'pc', 'cmake', 'toml', 'pref', 'desktop', 'xml', 'txt']:
                return ext
        
        # Fall back to file type-based extension
        if file_type == FileType.SHELL_SCRIPT:
            return 'sh'
        if file_type == FileType.PYTHON_SCRIPT:
            return 'py'
        if file_type == FileType.JSON_CONFIG:
            return 'json'
        if file_type == FileType.CONFIG_FILE:
            # Check if it's an APT preferences file
            if '/etc/apt/preferences.d/' in target_path:
                return 'pref'
            return 'conf'
        if file_type == FileType.LAYOUT_CONFIG:
            return 'kdl'
        if file_type == FileType.DOCS:
            return 'txt'
        
        # Last resort: check if base name suggests an extension
        base_name = path_obj.name.lower()
        if '.toml' in base_name:
            return 'toml'
        if '.xml' in base_name:
            return 'xml'
        if '.desktop' in base_name:
            return 'desktop'
        if '.pref' in base_name or 'preferences' in base_name or 'protect' in base_name:
            return 'pref'
        
        return 'txt'  # Default fallback
    
    def _sanitize_block_name(self, name: str) -> str:
        """Sanitize block name for use in directory name."""
        sanitized = re.sub(r'[^a-z0-9-]', '-', name.lower())
        sanitized = re.sub(r'-+', '-', sanitized)
        return sanitized.strip('-')
    
    def extract_heredocs_from_file(self, file_path: Path) -> List[HeredocFile]:
        """Extract all heredoc files from a source file."""
        if not file_path.exists():
            return []
        
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        heredocs = []
        i = 0
        
        while i < len(lines):
            line = lines[i]
            line_num = i + 1
            
            # Match heredoc patterns
            # Pattern 1: cat > file <<'EOF' or cat >> file <<'EOF'
            match1 = re.search(r'cat\s+>>?\s+([^\s<>"\'$]+(?:/[^\s<>"\'$]+)*|"[^"]+"|\'[^\']+\'|\$\{[^}]+\})\s+<<\s*([\'"]?)([A-Z_][A-Z0-9_]*)\2', line)
            # Pattern 2: if ! cat <<'EOF' > file or if cat <<'EOF' > file
            match2 = re.search(r'if\s+!?\s*cat\s+<<\s*([\'"]?)([A-Z_][A-Z0-9_]*)\1\s*>\s+([^\s<>"\'$]+(?:/[^\s<>"\'$]+)*|"[^"]+"|\'[^\']+\'|\$\{[^}]+\})', line)
            # Pattern 3: if ! cat <<'EOF' > file (alternative format)
            match3 = re.search(r'if\s+!?\s*cat\s+<<\s*([\'"]?)([A-Z_][A-Z0-9_]*)\1\s*>\s*([^\s;]+)', line)
            
            match = match1 or match2 or match3
            if match:
                # Extract components
                if match1:
                    target_path = match1.group(1).strip("'\"")
                    quoted = bool(match1.group(2))
                    delimiter = match1.group(3)
                elif match2:
                    quoted = bool(match2.group(1))
                    delimiter = match2.group(2)
                    target_path = match2.group(3).strip("'\"")
                else:  # match3
                    quoted = bool(match3.group(1))
                    delimiter = match3.group(2)
                    target_path = match3.group(3).strip("'\"")
                
                # Skip heredocs with variable paths (they're generated dynamically)
                if re.search(r'\$\{[^}]+\}', target_path) or re.search(r'\$[A-Z_][A-Z0-9_]*', target_path):
                    # Skip dynamic paths, but log for debugging
                    i += 1
                    continue
                
                # Clean target path (for display purposes)
                display_path = target_path
                
                # Find end of heredoc (robust search)
                end_line = self._find_heredoc_end(lines, i + 1, delimiter)
                if end_line is None:
                    # Try to find delimiter by looking for it more carefully
                    # Some heredocs might have the delimiter on a line with trailing content
                    for j in range(i + 1, min(i + 1000, len(lines))):
                        line_test = lines[j]
                        # Check if line contains only the delimiter (possibly with whitespace)
                        if re.match(rf'^\s*{re.escape(delimiter)}\s*$', line_test):
                            end_line = j
                            break
                        # Check if line starts with delimiter and has only comments after
                        if re.match(rf'^\s*{re.escape(delimiter)}\s*(#.*)?$', line_test):
                            end_line = j
                            break
                    
                    if end_line is None:
                        print(f"Warning: Could not find end of heredoc '{delimiter}' at line {line_num} in {file_path.name}")
                        i += 1
                        continue
                
                # Extract content
                content_lines = lines[i+1:end_line]
                content = ''.join(content_lines)
                
                # Skip empty heredocs
                if not content.strip():
                    i = end_line + 1
                    continue
                
                # Detect file type
                file_type = self._detect_file_type(display_path, content)
                
                # Get block info (only for post script)
                if 'xubuntu_robotics_base_post_ULTRA_CLEANED.sh' in str(file_path):
                    block, block_name = self.get_block_for_line(line_num)
                else:
                    # For build script, try to find block
                    block, block_name = None, "BUILD_SCRIPT"
                    for j in range(line_num - 1, max(0, line_num - 100), -1):
                        if j < len(lines):
                            block_match = re.match(r'^# BLOCK (\d+):\s*(.+)$', lines[j])
                            if block_match:
                                block = int(block_match.group(1))
                                block_name = block_match.group(2).strip()
                                break
                
                # Generate descriptive name
                descriptive_name = self._generate_descriptive_name(
                    display_path, content, file_type, block, block_name
                )
                
                # Determine permissions
                if file_type == FileType.SHELL_SCRIPT:
                    permissions = "0755" if "/bin/" in target_path or "/usr/local/bin/" in target_path else "0644"
                else:
                    permissions = "0644"
                
                # Create file metadata
                # line_end should be the line number (1-indexed) where the delimiter is found
                heredoc_file = HeredocFile(
                    source=f"{file_type.value}/block-{block or 0}-{self._sanitize_block_name(block_name or 'unknown')}/{descriptive_name}",
                    target=target_path,
                    file_type=file_type,
                    permissions=permissions,
                    block=block or 0,
                    block_name=block_name or "Unknown",
                    description=f"{file_type.value} file: {display_path}",
                    dependencies=[],
                    line_start=line_num,  # 1-indexed line where heredoc starts
                    line_end=end_line + 1,  # 1-indexed line where delimiter is found (end_line is 0-indexed)
                    delimiter=delimiter,
                    file_path=str(file_path),  # Store source file path
                    content=content
                )
                heredocs.append(heredoc_file)
                
                i = end_line + 1
            else:
                i += 1
        
        return heredocs
    
    def extract_and_organize(self):
        """Extract all heredoc files and organize by type."""
        print("=" * 60)
        print("Comprehensive Heredoc Extraction Tool")
        print("=" * 60)
        print()
        
        # Load block info
        print("Loading block information...")
        self.load_block_info()
        print(f"Found {len(self.blocks)} blocks")
        print()
        
        # Extract from post script
        print("Extracting from post script...")
        post_files = self.extract_heredocs_from_file(self.post_script)
        print(f"Found {len(post_files)} heredoc files")
        self.files.extend(post_files)
        
        # Extract from build script
        if self.build_script.exists():
            print("\nExtracting from build script...")
            build_files = self.extract_heredocs_from_file(self.build_script)
            print(f"Found {len(build_files)} heredoc files")
            self.files.extend(build_files)
        
        print(f"\nTotal heredoc files found: {len(self.files)}")
        
        # Organize by type
        files_by_type = {}
        for file_type in FileType:
            files_by_type[file_type] = [f for f in self.files if f.file_type == file_type]
            if files_by_type[file_type]:
                print(f"  {file_type.value}: {len(files_by_type[file_type])} files")
        
        # Create directory structure and extract files
        print("\nOrganizing files...")
        for heredoc_file in self.files:
            # Create type directory
            type_dir = self.container_scripts_dir / heredoc_file.file_type.value
            type_dir.mkdir(parents=True, exist_ok=True)
            
            # Create block directory
            block_dir = type_dir / heredoc_file.source.split('/', 1)[1].rsplit('/', 1)[0]
            block_dir.mkdir(parents=True, exist_ok=True)
            
            # Get filename
            filename = heredoc_file.source.split('/')[-1]
            file_path = block_dir / filename
            
            # Write file
            file_path.write_text(heredoc_file.content, encoding='utf-8')
            print(f"  Extracted: {heredoc_file.source}")
        
        # Generate manifest
        self._generate_manifest()
        
        # Create README
        self._create_readme()
        
        print("\n" + "=" * 60)
        print("Extraction complete!")
        print(f"Total files extracted: {len(self.files)}")
        print(f"Location: {self.container_scripts_dir}")
        print("=" * 60)
    
    def _generate_manifest(self):
        """Generate MANIFEST.json file."""
        manifest_files = []
        for file in self.files:
            file_dict = asdict(file)
            file_dict['file_type'] = file.file_type.value
            file_dict.pop('content', None)  # Don't store content in manifest
            manifest_files.append(file_dict)
        
        manifest_data = {
            "version": "1.0",
            "description": "Container scripts manifest - maps source files to installation targets",
            "files": manifest_files
        }
        
        manifest_path = self.container_scripts_dir / "MANIFEST.json"
        with open(manifest_path, 'w', encoding='utf-8') as f:
            json.dump(manifest_data, f, indent=2, ensure_ascii=False)
        
        print(f"\nGenerated MANIFEST.json with {len(manifest_files)} files")
    
    def _create_readme(self):
        """Create README.md file."""
        readme_content = f"""# Container Scripts

This directory contains all heredoc files extracted from the build and post scripts.

## Organization

Files are organized by type:
- `shell-scripts/` - Shell scripts (.sh, .bash)
- `json-configs/` - JSON configuration files (.json, .json5)
- `config-files/` - Configuration files (.conf, .kdl, .ron, etc.)
- `layout-configs/` - Layout configuration files (Zellij, Tmux)
- `other/` - Other file types

Within each type, files are organized by block number.

## Total Files

- **Total**: {len(self.files)} files
- **Shell scripts**: {len([f for f in self.files if f.file_type == FileType.SHELL_SCRIPT])}
- **JSON configs**: {len([f for f in self.files if f.file_type == FileType.JSON_CONFIG])}
- **Config files**: {len([f for f in self.files if f.file_type == FileType.CONFIG_FILE])}
- **Layout configs**: {len([f for f in self.files if f.file_type == FileType.LAYOUT_CONFIG])}
- **Other**: {len([f for f in self.files if f.file_type == FileType.OTHER])}

## Installation

Files are installed during container build via the `install.sh` helper script.
The helper reads `MANIFEST.json` and installs files to their target locations with proper permissions.

## Validation

Run validation to check all files:
```bash
python3 scripts/validate_heredoc_scripts.py
```
"""
        
        readme_path = self.container_scripts_dir / "README.md"
        readme_path.write_text(readme_content, encoding='utf-8')
        print("Created README.md")


def main():
    """Main function."""
    project_root = Path(__file__).parent.parent
    extractor = ComprehensiveHeredocExtractor(project_root)
    extractor.extract_and_organize()


if __name__ == '__main__':
    main()

