#!/usr/bin/env python3
"""
AI-assisted pre-commit reviewer.

This hook inspects staged files, sends their diffs to a configured AI model for
strict auditing, and blocks the commit when the model reports critical issues.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class Provider(str):
    OPENAI = "openai"
    ANTHROPIC = "anthropic"

REPO_ROOT = Path(__file__).resolve().parents[2]
CODE_MANUAL_PATH = REPO_ROOT / "prompts" / "Code_check_prompt_manual.txt"
CACHE_DIR = REPO_ROOT / ".git" / ".ai-review-cache"

ALLOWED_SUFFIXES = {
    ".sh",
    ".bash",
    ".py",
    ".c",
    ".cc",
    ".cpp",
    ".cxx",
    ".h",
    ".hpp",
    ".hh",
    ".js",
    ".ts",
    ".tsx",
    ".go",
    ".rs",
    ".yaml",
    ".yml",
    ".json",
    ".toml",
    ".cmake",
}

DEFAULT_MAX_CHUNK_LINES = 400
DEFAULT_MAX_TOKENS = 8192  # Increased to allow complete JSON responses with detailed findings
DEFAULT_SECONDARY_MAX_TOKENS = 4096  # Increased for secondary provider
DEFAULT_COMPLEXITY_LINE_THRESHOLD = 150
DEFAULT_COMPLEXITY_CHAR_THRESHOLD = 6000
DEFAULT_COMPLEXITY_HUNK_THRESHOLD = 3
OPENAI_DEFAULT_MODEL = "gpt-4.1-mini"
OPENAI_DEFAULT_API_URL = "https://api.openai.com/v1/chat/completions"
ANTHROPIC_API_VERSION = "2023-06-01"  # Anthropic API version header (keep for compatibility)


@dataclass(frozen=True)
class ProviderConfig:
    provider: str
    api_url: str
    model: str
    token: str
    max_tokens: int


PROVIDER_TOKEN_ENV_NAMES = {
    Provider.ANTHROPIC: ["AI_REVIEW_TOKEN", "ANTHROPIC_API_KEY", "CLAUDE_API_KEY"],
    Provider.OPENAI: [
        "AI_REVIEW_SECONDARY_TOKEN",
        "OPENAI_API_KEY",
        "OPENAI_API_TOKEN",
    ],
}

PROVIDER_DEFAULTS = {
    Provider.ANTHROPIC: {
        "api_url": "https://api.anthropic.com/v1/messages",
        # Valid model names (2025 official list):
        # Claude 4.x: claude-opus-4-1, claude-opus-4-1-20250805, claude-opus-4, claude-opus-4-20250514
        # Claude 4.x: claude-sonnet-4, claude-sonnet-4-20250514, claude-sonnet-4-5
        # Claude 3.7: claude-3-7-sonnet-latest, claude-3-7-sonnet-20250219
        # Claude 3.5: claude-3-5-sonnet-latest, claude-3-5-sonnet-20241022, claude-3-5-haiku-latest, claude-3-5-haiku-20241022
        # Claude 3: claude-3-opus-20240229, claude-3-sonnet-20240229, claude-3-haiku-20240307
        # Note: Some models support "-latest" suffix (3.5, 3.7), newer 4.x models use different format
        # Note: Sonnet 4 or 4.5 recommended as default for most use cases
        "model": "claude-sonnet-4",  # Default to Claude Sonnet 4 (fast, context-aware, good default); override with AI_REVIEW_MODEL env var
    },
    Provider.OPENAI: {
        "api_url": OPENAI_DEFAULT_API_URL,
        "model": OPENAI_DEFAULT_MODEL,
    },
}

PROVIDER_DEFAULT_MAX_TOKENS = {
    Provider.ANTHROPIC: DEFAULT_MAX_TOKENS,
    Provider.OPENAI: DEFAULT_SECONDARY_MAX_TOKENS,
}


class ReviewFailure(Exception):
    """Raised when the review process fails and the commit must be blocked."""


def run_git(args: Iterable[str], check: bool = False) -> subprocess.CompletedProcess[str]:
    """Run git command with optional check parameter."""
    return subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=check,
    )


def is_non_functional_file(path: str) -> bool:
    """
    Check if a file is non-functional using AI-based reasoning.
    Uses content analysis, docstring checks, and purpose detection.
    Returns True if the file should be rejected.
    """
    import subprocess
    import re
    
    file_path = REPO_ROOT / path
    if not file_path.exists():
        return False
    
    # Skip ALL core files (primary and secondary) - they are essential to the repository
    # PRIMARY CORE FILES (from AGENT-BEHAVIOR.mdc)
    primary_core_files = [
        "build_xubuntu_robotics_base.sh",
        "config.sh",
        "create_writable_overlay.sh",
        "run_on_best_node.sh",
        "setup_conda_environments.sh",
        "xubuntu_robotics_base_post_ULTRA_CLEANED.sh",
        "README.md",
    ]
    # SECONDARY CORE FILES (from AGENT-BEHAVIOR.mdc)
    secondary_core_files = [
        "scripts/hooks/ai_precommit_review.py",
        "scripts/hooks/pre-commit",
        "scripts/hooks/pre-commit-cmake-validator",
        "scripts/hooks/ai_file_purpose_checker.py",
        "scripts/hooks/extract_and_enhance_patterns.py",
        "scripts/hooks/run_all_ci_checks.sh",
        "scripts/hooks/validate_control_structure_markers.sh",
        "scripts/hooks/validate_documentation.sh",
    ]
    # Core files in subdirectories
    if path in primary_core_files or path in secondary_core_files:
        return False
    if path.startswith("scripts/helpers/") or path.startswith("container-scripts/"):
        return False
    if path.startswith(".cursor/rules/") and path.endswith(".mdc"):
        return False
    if path.startswith("prompts/") and (path.endswith(".txt") or path.endswith(".md")):
        return False
    
    # First: Quick filename pattern check (fast)
    basename = Path(path).name.lower()
    forbidden_patterns = [
        r'.*summary.*\.(md|txt)$',
        r'.*audit.*\.(md|txt)$',
        r'.*report.*\.(md|txt)$',
        r'.*findings.*\.(md|txt)$',
        r'.*analysis.*\.(md|txt)$',
        r'.*test_results.*\.(md|txt)$',
        r'.*fixes_summary.*\.(md|txt)$',
        r'.*removal_summary.*\.(md|txt)$',
        r'.*endpoint.*summary.*\.(md|txt)$',
        r'.*endpoint.*results.*\.(md|txt)$',
    ]
    
    for pattern in forbidden_patterns:
        if re.match(pattern, basename):
            return True
    
    # Second: AI-based content analysis (more thorough)
    ai_checker = REPO_ROOT / "scripts" / "hooks" / "ai_file_purpose_checker.py"
    if ai_checker.exists():
        try:
            result = subprocess.run(
                [sys.executable, str(ai_checker), str(file_path)],
                capture_output=True,
                text=True,
                timeout=10
            )
            # If exit code is 1, file is non-functional
            if result.returncode == 1:
                return True
        except (subprocess.TimeoutExpired, FileNotFoundError):
            # Fall back to pattern matching if AI checker fails
            pass
    
    # Fallback: Check for standalone test files (not in test directories)
    if re.match(r'^test_.*\.(sh|py)$', basename):
        if not any(part in path.lower() for part in ['test', 'tests', 'spec']):
            return True
    
    return False


def is_github_actions() -> bool:
    """Check if running in GitHub Actions environment."""
    return os.getenv("GITHUB_ACTIONS") == "true"


def get_pr_base_ref() -> Optional[str]:
    """Get the base ref for PR diff in GitHub Actions."""
    # In GitHub Actions, we can get base ref from environment
    # For PR events: GITHUB_BASE_REF contains the base branch name
    # For push events: compare with previous commit or default branch
    base_branch = os.getenv("GITHUB_BASE_REF")
    if base_branch:
        # Fetch the base branch first to ensure we can diff against it
        run_git(["fetch", "origin", base_branch], check=False)
        return f"origin/{base_branch}"
    
    # For push events, try to get default branch or use beta/main
    default_branch = os.getenv("GITHUB_DEFAULT_BRANCH", "beta")
    # Try to fetch default branch
    run_git(["fetch", "origin", default_branch], check=False)
    return f"origin/{default_branch}"


def get_staged_files() -> List[str]:
    """Get list of staged files (for local pre-commit)."""
    result = run_git(["diff", "--cached", "--name-only", "--diff-filter=ACMRT"])
    if result.returncode != 0:
        raise ReviewFailure(
            f"Failed to enumerate staged files:\n{result.stderr.strip()}"
        )
    paths = []
    for line in result.stdout.splitlines():
        path = line.strip()
        if not path:
            continue
        if Path(path).suffix.lower() in ALLOWED_SUFFIXES:
            if (REPO_ROOT / path).exists() or run_git(["ls-files", "--error-unmatch", path]).returncode == 0:
                paths.append(path)
    return paths


def get_pr_files() -> List[str]:
    """Get list of changed files in PR (for GitHub Actions)."""
    base_ref = get_pr_base_ref()
    if not base_ref:
        # Fallback: compare with HEAD~1 (previous commit)
        result = run_git(["diff", "--name-only", "--diff-filter=ACMRT", "HEAD~1", "HEAD"])
    else:
        # Compare with base branch
        # First ensure we have the base ref locally
        result = run_git(["diff", "--name-only", "--diff-filter=ACMRT", base_ref, "HEAD"])
    
    if result.returncode != 0:
        # If diff fails, try fallback to HEAD~1
        print(f"Warning: Could not diff against {base_ref}, trying HEAD~1...")
        result = run_git(["diff", "--name-only", "--diff-filter=ACMRT", "HEAD~1", "HEAD"])
        if result.returncode != 0:
            raise ReviewFailure(
                f"Failed to enumerate PR files:\n{result.stderr.strip()}"
            )
    
    paths = []
    for line in result.stdout.splitlines():
        path = line.strip()
        if not path:
            continue
        if Path(path).suffix.lower() in ALLOWED_SUFFIXES:
            if (REPO_ROOT / path).exists():
                paths.append(path)
    return paths


def get_staged_diff(path: str) -> str:
    """Get staged diff for a file (for local pre-commit)."""
    result = run_git(
        [
            "diff",
            "--cached",
            "--unified=0",
            "--no-color",
            "--",
            path,
        ]
    )
    if result.returncode != 0:
        raise ReviewFailure(
            f"Failed to obtain staged diff for {path}:\n{result.stderr.strip()}"
        )
    return result.stdout.strip()


def get_pr_diff(path: str) -> str:
    """Get PR diff for a file (for GitHub Actions)."""
    base_ref = get_pr_base_ref()
    if not base_ref:
        # Fallback: compare with HEAD~1
        result = run_git(
            [
                "diff",
                "--unified=0",
                "--no-color",
                "HEAD~1",
                "HEAD",
                "--",
                path,
            ]
        )
    else:
        # Compare with base branch
        result = run_git(
            [
                "diff",
                "--unified=0",
                "--no-color",
                base_ref,
                "HEAD",
                "--",
                path,
            ]
        )
    
    if result.returncode != 0:
        # If diff fails, try fallback to HEAD~1
        result = run_git(
            [
                "diff",
                "--unified=0",
                "--no-color",
                "HEAD~1",
                "HEAD",
                "--",
                path,
            ]
        )
        if result.returncode != 0:
            raise ReviewFailure(
                f"Failed to obtain PR diff for {path}:\n{result.stderr.strip()}"
            )
    return result.stdout.strip()


def chunk_diff(diff: str, max_lines: int) -> List[str]:
    if not diff:
        return []
    effective_limit = max(1, max_lines)
    lines = diff.splitlines()
    chunks: List[str] = []
    current: List[str] = []
    for line in lines:
        current.append(line)
        if len(current) >= effective_limit and line.startswith("@@"):
            chunks.append("\n".join(current))
            current = []
    if current:
        # Append any remaining lines even if we exceeded the limit without
        # encountering a hunk boundary.
        chunks.append("\n".join(current))
    return chunks


def load_manual() -> str:
    if not CODE_MANUAL_PATH.is_file():
        raise ReviewFailure(
            f"Required prompt manual not found at {CODE_MANUAL_PATH}"
        )
    return CODE_MANUAL_PATH.read_text(encoding="utf-8")


def ensure_cache_dir() -> None:
    if not CACHE_DIR.exists():
        CACHE_DIR.mkdir(parents=True, exist_ok=True)


def cache_key(provider: str, model: str, system_prompt: str, user_prompt: str) -> str:
    digest = hashlib.sha256()
    digest.update(provider.encode("utf-8"))
    digest.update(b"\x00")
    digest.update(model.encode("utf-8"))
    digest.update(b"\x00")
    digest.update(system_prompt.encode("utf-8"))
    digest.update(b"\x00")
    digest.update(user_prompt.encode("utf-8"))
    return digest.hexdigest()


def read_cache(key: str) -> Optional[Dict[str, object]]:
    cache_file = CACHE_DIR / f"{key}.json"
    if not cache_file.is_file():
        return None
    try:
        return json.loads(cache_file.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def write_cache(key: str, payload: Dict[str, object]) -> None:
    cache_file = CACHE_DIR / f"{key}.json"
    try:
        cache_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    except OSError:
        pass


def call_openai_api(
    api_url: str,
    api_token: str,
    model: str,
    system_prompt: str,
    user_prompt: str,
    timeout: int,
    max_tokens: int,
    is_secondary: bool = True,
    provider: str = Provider.OPENAI,
) -> Optional[Dict[str, object]]:
    effective_tokens = normalize_max_tokens(max_tokens, DEFAULT_SECONDARY_MAX_TOKENS)
    payload = {
        "model": model,
        "temperature": 0,
        "max_tokens": effective_tokens,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    }
    return perform_request(
        api_url=api_url,
        token_header="Authorization",
        token_value=f"Bearer {api_token}",
        payload=payload,
        timeout=timeout,
        extra_headers={},
        is_secondary=is_secondary,  # Pass through from review_chunk
        provider=provider,  # Pass through from review_chunk
    )


def call_anthropic_api(
    api_url: str,
    api_token: str,
    model: str,
    system_prompt: str,
    user_prompt: str,
    timeout: int,
    max_tokens: int,
    is_secondary: bool = False,
    provider: str = Provider.ANTHROPIC,
) -> Optional[Dict[str, object]]:
    """
    Call Anthropic Claude API with correct format.
    
    API endpoint: https://api.anthropic.com/v1/messages
    Headers: x-api-key (required), anthropic-version (required)
    Model names: Use hyphens (e.g., claude-sonnet-4, claude-3-5-sonnet-20241022)
    """
    effective_tokens = normalize_max_tokens(max_tokens, DEFAULT_MAX_TOKENS)
    
    # Ensure API URL is correct format
    if not api_url.startswith("https://"):
        raise ReviewFailure(f"Invalid API URL format: {api_url}. Must start with https://")
    if not api_url.endswith("/messages"):
        # Auto-correct if missing /messages suffix
        if api_url.endswith("/v1"):
            api_url = f"{api_url}/messages"
        elif not api_url.endswith("/v1/messages"):
            api_url = f"{api_url.rstrip('/')}/v1/messages"
    
    payload = {
        "model": model,
        "max_tokens": effective_tokens,
        "system": system_prompt,
        "messages": [{"role": "user", "content": user_prompt}],  # Simplified: content as string (also supports array format)
        "temperature": 0,
    }
    headers = {
        "x-api-key": api_token,
        "anthropic-version": ANTHROPIC_API_VERSION,
        "Content-Type": "application/json",  # Ensure proper case
    }
    return perform_request(
        api_url=api_url,
        token_header=None,
        token_value="",
        payload=payload,
        timeout=timeout,
        extra_headers=headers,
        is_secondary=is_secondary,  # Pass through from review_chunk
        provider=provider,  # Pass through from review_chunk
    )


def perform_request(
    api_url: str,
    token_header: Optional[str],
    token_value: str,
    payload: Dict[str, object],
    timeout: int,
    extra_headers: Dict[str, str],
    is_secondary: bool = False,
    provider: str = Provider.ANTHROPIC,
) -> Optional[Dict[str, object]]:
    body = json.dumps(payload).encode("utf-8")
    headers = dict(extra_headers)
    if token_header:
        headers[token_header] = token_value
    if not any(key.lower() == "content-type" for key in headers):
        headers["Content-Type"] = "application/json"
    request = Request(api_url, data=body, headers=headers, method="POST")
    try:
        with urlopen(request, timeout=timeout) as response:
            response_text = response.read().decode("utf-8")
            return json.loads(response_text)
    except HTTPError as exc:
        # Handle 400 Bad Request as configuration error (non-blocking)
        # 400 typically means invalid API key format, invalid payload, or missing fields
        if exc.code == 400:
            payload_preview = json.dumps(payload, indent=2)[:1024]
            error_msg = textwrap.dedent(
                f"""\
                AI review request failed with HTTP 400 (Bad Request).
                This usually indicates a configuration issue (invalid API key format, 
                invalid model name, or malformed request payload).
                Reason: {exc.reason}
                Payload preview:
                {payload_preview}
                
                To fix:
                1. Verify your API key is correctly formatted
                2. Check that the model name is valid for your provider
                3. Ensure all required environment variables are set correctly
                
                AI review will be skipped for this chunk. Commit will proceed.
                """
            )
            # For secondary providers, return None to allow fallback
            if is_secondary:
                print(f"Warning: Secondary provider '{provider}' API request failed with HTTP 400.")
                print(f"Reason: {exc.reason}")
                print("Falling back to primary provider or skipping secondary review.")
                return None
            # For primary provider, print warning but don't block commit
            # This makes AI review truly optional - configuration errors don't block commits
            print(f"⚠️  {error_msg}")
            print("⚠️  AI review skipped due to configuration error. Commit will proceed.")
            return None
        # For other HTTP errors (401, 403, 404, 500, etc.), raise exception
        payload_preview = json.dumps(payload, indent=2)[:1024]
        raise ReviewFailure(
            textwrap.dedent(
                f"""\
                AI review request failed with HTTP {exc.code}.
                Reason: {exc.reason}
                Payload preview:
                {payload_preview}
                """
            )
        ) from exc
    except URLError as exc:
        error_msg = str(exc.reason) if exc.reason else str(exc)
        if "timed out" in error_msg.lower() or "timeout" in error_msg.lower():
            raise ReviewFailure(
                f"AI review request timed out after {timeout} seconds. "
                f"Consider increasing timeout with --timeout flag or AI_REVIEW_TIMEOUT environment variable."
            ) from exc
        raise ReviewFailure(f"AI review request failed: {error_msg}") from exc
    except TimeoutError as exc:
        raise ReviewFailure(
            f"AI review request timed out after {timeout} seconds. "
            f"Consider increasing timeout with --timeout flag or AI_REVIEW_TIMEOUT environment variable."
        ) from exc
    except ValueError as exc:
        raise ReviewFailure(f"AI review request failed: {exc}") from exc


def extract_review_content(response: Dict[str, object], provider: str) -> str:
    """
    Extract text content from an AI response depending on the provider.
    """
    if provider == Provider.ANTHROPIC:
        content_list = response.get("content")
        if not isinstance(content_list, list) or not content_list:
            raise ReviewFailure("AI response missing content array.")
        text_segments = [
            segment.get("text", "")
            for segment in content_list
            if isinstance(segment, dict) and segment.get("type") == "text"
        ]
        combined = "\n".join(s.strip() for s in text_segments if isinstance(s, str))
        if not combined:
            raise ReviewFailure("AI response (Anthropic) missing textual content.")
        return combined

    # Default to OpenAI-format parsing
    choices = response.get("choices")
    if not isinstance(choices, list) or not choices:
        raise ReviewFailure("AI response missing choices.")
    content = choices[0].get("message", {}).get("content")
    if not isinstance(content, str) or not content.strip():
        raise ReviewFailure("AI response missing textual content.")
    return content.strip()


def parse_review_json(content: str) -> Dict[str, object]:
    """
    Attempt to parse structured JSON from the AI's response.
    Handles cases where JSON is embedded in markdown code blocks or text.
    """
    import re
    
    # Try direct parsing first
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        pass
    
    # Try extracting JSON from markdown code blocks (```json ... ``` or ``` ... ```)
    # First, try to find content that starts with ```json
    if content.strip().startswith('```json'):
        # Find the start of JSON content (after ```json\n)
        json_start_marker = '```json'
        start_pos = content.find(json_start_marker)
        if start_pos != -1:
            # Find the first newline after ```json
            content_start = content.find('\n', start_pos)
            if content_start == -1:
                content_start = start_pos + len(json_start_marker)
            else:
                content_start += 1  # Skip the newline
            
            # Find closing ``` (might be at end of content)
            closing_pos = content.find('```', content_start)
            if closing_pos == -1:
                # No closing found, use everything from content_start to end
                json_candidate = content[content_start:].strip()
            else:
                # Extract content between ```json\n and closing ```
                json_candidate = content[content_start:closing_pos].strip()
            
            if json_candidate:
                try:
                    return json.loads(json_candidate)
                except json.JSONDecodeError:
                    # If JSON parsing fails, try balanced brace extraction on the candidate
                    # This handles cases where JSON might be incomplete or have extra content
                    brace_start = json_candidate.find('{')
                    if brace_start != -1:
                        brace_count = 0
                        brace_end = -1
                        in_string = False
                        escape_next = False
                        
                        for i in range(brace_start, len(json_candidate)):
                            char = json_candidate[i]
                            
                            if escape_next:
                                escape_next = False
                                continue
                            
                            if char == '\\':
                                escape_next = True
                                continue
                            
                            if char in ('"', "'") and not escape_next:
                                in_string = not in_string
                                continue
                            
                            if not in_string:
                                if char == '{':
                                    brace_count += 1
                                elif char == '}':
                                    brace_count -= 1
                                    if brace_count == 0:
                                        brace_end = i
                                        break
                        
                        if brace_end != -1:
                            try:
                                return json.loads(json_candidate[brace_start:brace_end + 1])
                            except json.JSONDecodeError:
                                pass
    
    # Try standard regex patterns for code blocks
    json_block_patterns = [
        r'```json\s*\n(.*?)\n\s*```',  # ```json ... ``` (with newlines)
        r'```json\s*(.*?)\s*```',      # ```json ... ``` (flexible)
        r'```\s*\n(.*?)\n\s*```',      # ``` ... ``` (with newlines)
        r'```\s*(.*?)\s*```',          # ``` ... ``` (flexible)
    ]
    for pattern in json_block_patterns:
        matches = re.findall(pattern, content, re.DOTALL)
        for match in matches:
            cleaned = match.strip()
            if cleaned:
                try:
                    parsed = json.loads(cleaned)
                    return parsed
                except json.JSONDecodeError:
                    continue
    
    # Try finding JSON object in text (look for { ... } with balanced braces)
    # This handles cases like "Here is the JSON: { ... }"
    # Also handles cases where JSON is in code blocks but extraction failed
    brace_start = content.find('{')
    if brace_start != -1:
        brace_count = 0
        brace_end = -1
        in_string = False
        escape_next = False
        
        for i in range(brace_start, len(content)):
            char = content[i]
            
            # Handle string escaping
            if escape_next:
                escape_next = False
                continue
            
            if char == '\\':
                escape_next = True
                continue
            
            # Track string boundaries (handle both single and double quotes)
            if char in ('"', "'") and not escape_next:
                in_string = not in_string
                continue
            
            # Only count braces when not inside a string
            if not in_string:
                if char == '{':
                    brace_count += 1
                elif char == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        brace_end = i
                        break
        
        if brace_end != -1:
            json_candidate = content[brace_start:brace_end + 1]
            try:
                return json.loads(json_candidate)
            except json.JSONDecodeError:
                pass
    
    # If all extraction attempts fail, raise error with helpful message
    # Show more context to help debug
    preview = content[:2000] if len(content) > 2000 else content
    raise ReviewFailure(
        textwrap.dedent(
            f"""\
            AI response is not valid JSON and could not extract JSON from response.
            
            Response content preview ({len(content)} total chars, showing first {len(preview)}):
            {preview}
            
            Tried extraction methods:
            1. Direct JSON parsing
            2. Markdown code block extraction (```json ... ```)
            3. Balanced brace extraction
            
            If JSON appears to be truncated, the API response may be incomplete.
            Check API timeout settings or response size limits.
            """
        )
    )


def pretty_chunk_header(path: str, index: int, total: int) -> str:
    return f"{path} (chunk {index + 1} of {total})"


def review_chunk(
    config: ProviderConfig,
    system_prompt: str,
    user_prompt: str,
    timeout: int,
    cache_disabled: bool,
    is_secondary: bool = False,
) -> Optional[Dict[str, object]]:
    provider = config.provider
    if not config.token:
        raise ReviewFailure(
            f"AI provider '{provider}' is selected but no API token is configured."
        )

    cache_identifier = cache_key(
        provider,
        config.model,
        system_prompt,
        user_prompt,
    )
    if not cache_disabled:
        ensure_cache_dir()
        cached = read_cache(cache_identifier)
        if cached is not None:
            return cached

    try:
        if provider == Provider.ANTHROPIC:
            response = call_anthropic_api(
                api_url=config.api_url,
                api_token=config.token,
                model=config.model,
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                timeout=timeout,
                max_tokens=config.max_tokens,
                is_secondary=is_secondary,
                provider=provider,
            )
        elif provider == Provider.OPENAI:
            response = call_openai_api(
                api_url=config.api_url,
                api_token=config.token,
                model=config.model,
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                timeout=timeout,
                max_tokens=config.max_tokens,
                is_secondary=is_secondary,
                provider=provider,
            )
        else:
            raise ReviewFailure(f"Unsupported AI provider: {provider}")

        # Handle None response (e.g., from HTTP 400 error handling)
        if response is None:
            return None

        content = extract_review_content(response, provider)
        parsed = parse_review_json(content)

        if not cache_disabled:
            write_cache(cache_identifier, parsed)

        return parsed
    except HTTPError as exc:
        # For secondary providers, gracefully handle 404/API errors by returning None
        # This allows fallback to primary provider
        if is_secondary and exc.code in (404, 403, 401):
            print(
                f"Warning: Secondary provider '{provider}' API request failed with HTTP {exc.code}."
            )
            print(f"Reason: {exc.reason}")
            print("Falling back to primary provider or skipping secondary review.")
            return None
        # For primary provider or non-404 errors, raise the exception
        raise


def format_user_prompt(
    manual_text: str,
    repo_name: str,
    path: str,
    chunk: str,
    chunk_index: int,
    chunk_total: int,
) -> str:
    # Parse and include the FULL manual explicitly
    # The manual is the AUTHORITATIVE SOURCE - include all checklist items A1-P5
    import re
    
    manual_lines = manual_text.split('\n')
    
    # Extract header section (before checklist starts)
    header_end = 0
    for i, line in enumerate(manual_lines):
        if line.strip().startswith('A. Structure & Syntax'):
            header_end = i
            break
    
    header_section = '\n'.join(manual_lines[:header_end])
    
    # Extract ALL checklist items A1-P5 with full descriptions
    # Include all sections: A-O (Structure through Testing) + P (Build Flag Analysis)
    checklist_sections = []
    current_section = None
    current_items = []
    in_checklist = False
    
    for line in manual_lines[header_end:]:
        # Match main section headers (A. through P.)
        if re.match(r'^([A-P])\.\s+', line):
            if current_section:
                checklist_sections.append(f"{current_section}\n" + "\n".join(current_items))
            current_section = line.strip()
            current_items = []
            in_checklist = True
        # Match sub-items (A1., A2., etc. or - A1., - A2., etc.)
        elif in_checklist and (re.match(r'^- ([A-P][0-9]+)\.', line) or re.match(r'^([A-P][0-9]+)\.', line)):
            current_items.append(line.rstrip())
        # Match sub-items with descriptions (indented lines after checklist items)
        elif in_checklist and current_items and (line.startswith('  ') or line.startswith('    ')):
            # Include full description lines (up to reasonable length to avoid token limits)
            if len(line.strip()) > 0:
                current_items.append(line.rstrip())
        # Match critical patterns and examples (code blocks, examples)
        elif in_checklist and current_items:
            # Include code examples and critical patterns (they're important)
            if line.strip().startswith('```') or line.strip().startswith('**'):
                current_items.append(line.rstrip())
            elif line.strip() and not line.strip().startswith('---'):
                # Include continuation lines for checklist items
                if len(current_items) > 0 and len(current_items[-1]) < 200:
                    current_items.append(line.rstrip())
    
    # Add last section
    if current_section:
        checklist_sections.append(f"{current_section}\n" + "\n".join(current_items))
    
    # Combine header + all checklist sections
    full_manual_content = header_section + "\n\n" + "Step 2 – Sequential Audit Checklist\n\n" + "\n\n".join(checklist_sections)
    
    # If manual is too long, include key sections and reference the rest
    # But prioritize including ALL checklist item titles (A1-P5)
    if len(full_manual_content) > 30000:  # Rough token estimate
        # Include header + all section headers + all item titles
        manual_preview = header_section + "\n\n" + "Step 2 – Sequential Audit Checklist\n\n"
        for section in checklist_sections:
            # Extract section header and item titles
            section_lines = section.split('\n')
            manual_preview += section_lines[0] + "\n"  # Section header
            for line in section_lines[1:]:
                if re.match(r'^- ([A-P][0-9]+)\.', line) or re.match(r'^([A-P][0-9]+)\.', line):
                    manual_preview += line + "\n"
                elif line.strip().startswith('**') or line.strip().startswith('```'):
                    manual_preview += line + "\n"
        manual_preview += f"\n\n[Full manual with complete descriptions available at prompts/Code_check_prompt_manual.txt]"
    else:
        manual_preview = full_manual_content
    
    guidelines = textwrap.dedent(
        """\
        **MANDATORY**: The Manual (Code_check_prompt_manual.txt) is the AUTHORITATIVE SOURCE.
        You MUST follow it STRICTLY and check EVERY checklist item A1 through P5 sequentially.
        Do NOT skip any items. Document PASS/FAIL for each item with specific line references.
        
        Review each diff chunk as an independent audit gate.
        
        **MANDATORY EXECUTION PROTOCOL**:
        1. The FULL Manual is provided below - this is the AUTHORITATIVE SOURCE for all validation
        2. Check Pattern-Learning-Repository-PART1.md and PART2.md patterns BEFORE starting A-P phases
        3. Execute EVERY checklist item A1 through P5 sequentially from the Manual (A1-A6, B1-B3, C1-C5, D1-D4, E1-E3, F1-F3, G1-G5, H1-H4, I1-I4, J1-J3, K1-K3, L1-L6, M1-M14, N1-N5, O1-O4, P1-P5)
        4. Document PASS/FAIL for each item with specific line references
        5. Do not skip any items - the Manual is comprehensive and all items apply
        6. Reference the checklist item ID (e.g., "A1", "D3", "M8") in your findings
        
        CRITICAL: Check if any NEW FILES being added are non-functional:
        - Reject files matching patterns: *summary*, *audit*, *report*, *findings*, *analysis*, *test_results*
        - Reject standalone test files (test_*.sh, test_*.py) not in test directories
        - All analysis/documentation must be inline in chat, not committed as files
        - Repository must remain lean and purely functional
        
        CRITICAL: Check documentation coverage:
        - File header documentation: Every code file MUST have header comment/docstring
        - Function documentation: All functions > 10 lines MUST have documentation
        - Complex logic: Multi-phase logic MUST have phase markers (# Phase 1: ..., # Phase 2: ...)
        - Inline comments: Non-trivial blocks SHOULD have explanatory comments
        - Comment quality: Comments explain WHY (rationale, assumptions), not WHAT
        - Control structure markers: All if-fi, for-done, while-done, case-esac pairs MUST have closing markers (# ENDIF: ..., # ENDFOR: ..., etc.)
        - Reject if critical documentation is missing (header docs, function docs for large functions, control structure markers)
        
        Respond in JSON with the following schema:
        {
          "status": "approve" | "reject",
          "summary": "short explanation",
          "findings": [
            {
              "severity": "critical" | "major" | "minor",
              "title": "one-line summary",
              "details": "specific reasoning with references to lines/hunks",
              "suggested_fix": "actionable recommendation or empty string"
            }
          ]
        }
        Use "reject" when any critical or major issue remains unresolved.
        """
    )
    return textwrap.dedent(
        f"""\
        Repository: {repo_name}
        File: {path}
        Chunk: {chunk_index + 1} / {chunk_total}
        
        **AUTHORITATIVE MANUAL - Code_check_prompt_manual.txt** (FULL CHECKLIST A1-P5):
        ```
        {manual_preview}
        ```
        
        **CRITICAL**: This manual is the SINGLE SOURCE OF TRUTH. You MUST check ALL items A1-P5 sequentially.
        Guidelines:
        ```
        {guidelines}
        ```
        Diff chunk:
        ```
        {chunk}
        ```
        """
    )


def default_system_prompt() -> str:
    return textwrap.dedent(
        """\
        You are an automated pre-commit reviewer enforcing strict correctness,
        security, and style requirements. Operate as a deterministic auditor.
        
        **AUTHORITATIVE SOURCE**: You MUST use the Code_check_prompt_manual.txt provided
        in the user prompt as the SINGLE SOURCE OF TRUTH for all validation criteria.
        
        **MANDATORY PROCESS**:
        1. Parse the full manual provided in the user prompt
        2. Check ALL checklist items A1 through P5 sequentially (do not skip any)
        3. For each item, document PASS/FAIL with specific line references
        4. Reference checklist item IDs (A1, D3, M8, etc.) in all findings
        5. Approve only when the diff chunk fully complies with ALL checklist items
        6. When rejecting, include actionable guidance with checklist item references
        
        **CHECKLIST COVERAGE**: A1-A6 (Structure), B1-B3 (Shell Options), C1-C5 (Variables),
        D1-D4 (Quoting), E1-E3 (Heredocs), F1-F3 (Logic), G1-G5 (Functions), H1-H4 (Error Handling),
        I1-I4 (Timeouts), J1-J3 (Edge Cases), K1-K3 (Security), L1-L6 (Performance/Docs),
        M1-M14 (Environment/Dependencies), N1-N5 (Resource Management), O1-O4 (Testing),
        P1-P5 (Build Flag Analysis).
        """
    )


def resolve_token(env_names: Iterable[str]) -> str:
    for name in env_names:
        value = os.getenv(name)
        if value:
            stripped = value.strip()
            if stripped:
                return stripped
    return ""


def normalize_max_tokens(requested: int, fallback: int) -> int:
    if requested and requested > 0:
        return requested
    return fallback


def load_provider_configs(
    primary_provider: str,
    primary_api_url: str,
    primary_model: str,
    primary_max_tokens: int,
    secondary_provider: Optional[str],
    secondary_api_url: Optional[str],
    secondary_model: Optional[str],
    secondary_max_tokens: int,
) -> Tuple[Dict[str, ProviderConfig], bool]:
    configs: Dict[str, ProviderConfig] = {}
    token_names = PROVIDER_TOKEN_ENV_NAMES.get(primary_provider, [])
    primary_token = resolve_token(token_names)

    effective_primary_max_tokens = normalize_max_tokens(
        primary_max_tokens,
        PROVIDER_DEFAULT_MAX_TOKENS.get(primary_provider, DEFAULT_MAX_TOKENS),
    )

    if primary_token:
        configs[primary_provider] = ProviderConfig(
            provider=primary_provider,
            api_url=primary_api_url,
            model=primary_model,
            token=primary_token,
            max_tokens=effective_primary_max_tokens,
        )
        missing_primary = False
    else:
        missing_primary = True

    if (
        secondary_provider
        and secondary_provider != primary_provider
        and secondary_provider in PROVIDER_TOKEN_ENV_NAMES
    ):
        secondary_token = resolve_token(PROVIDER_TOKEN_ENV_NAMES[secondary_provider])
        if secondary_token:
            resolved_api_url = secondary_api_url or PROVIDER_DEFAULTS.get(
                secondary_provider, {}
            ).get("api_url", "")
            resolved_model = secondary_model or PROVIDER_DEFAULTS.get(
                secondary_provider, {}
            ).get("model", "")
            resolved_max_tokens = normalize_max_tokens(
                secondary_max_tokens,
                PROVIDER_DEFAULT_MAX_TOKENS.get(
                    secondary_provider, DEFAULT_SECONDARY_MAX_TOKENS
                ),
            )
            configs[secondary_provider] = ProviderConfig(
                provider=secondary_provider,
                api_url=resolved_api_url,
                model=resolved_model,
                token=secondary_token,
                max_tokens=resolved_max_tokens,
            )

    return configs, missing_primary


def is_complex_chunk(
    chunk: str,
    line_threshold: int,
    char_threshold: int,
    hunk_threshold: int,
) -> bool:
    line_count = chunk.count("\n") + 1
    if line_count > line_threshold:
        return True
    if len(chunk) > char_threshold:
        return True
    hunk_count = chunk.count("@@")
    if hunk_count > hunk_threshold:
        return True
    return False


def choose_provider(
    chunk: str,
    configs: Dict[str, ProviderConfig],
    primary_provider: str,
    secondary_provider: Optional[str],
    line_threshold: int,
    char_threshold: int,
    hunk_threshold: int,
) -> ProviderConfig:
    if not configs:
        raise ReviewFailure("No AI providers configured. Unable to audit diff chunks.")

    complex_chunk = is_complex_chunk(
        chunk,
        line_threshold=line_threshold,
        char_threshold=char_threshold,
        hunk_threshold=hunk_threshold,
    )

    if complex_chunk and primary_provider in configs:
        return configs[primary_provider]

    if (
        not complex_chunk
        and secondary_provider
        and secondary_provider in configs
    ):
        return configs[secondary_provider]

    if primary_provider in configs:
        return configs[primary_provider]

    # Fall back to any available provider
    return next(iter(configs.values()))


def collect_reviews(
    configs: Dict[str, ProviderConfig],
    primary_provider: str,
    secondary_provider: Optional[str],
    manual: str,
    max_chunk_lines: int,
    timeout: int,
    cache_disabled: bool,
    line_threshold: int,
    char_threshold: int,
    hunk_threshold: int,
) -> Tuple[bool, List[Tuple[str, str, Dict[str, object]]]]:
    repo_name = REPO_ROOT.name
    system_prompt = default_system_prompt()
    
    # Detect environment and get appropriate files
    in_github_actions = is_github_actions()
    if in_github_actions:
        print("Running in GitHub Actions - reviewing PR diff...")
        changed_files = get_pr_files()
        get_diff_func = get_pr_diff
    else:
        print("Running locally - reviewing staged files...")
        changed_files = get_staged_files()
        get_diff_func = get_staged_diff
    
    if not changed_files:
        return True, []

    # Check for non-functional files and reject them
    non_functional_files = [f for f in changed_files if is_non_functional_file(f)]
    if non_functional_files:
        print("\n" + "=" * 70)
        print("⚠️  NON-FUNCTIONAL FILES DETECTED")
        print("=" * 70)
        for file in non_functional_files:
            print(f"  ✗ {file}")
        print("\nThese files serve no functional purpose and should be removed.")
        print("Repository must remain lean and purely functional.")
        print("=" * 70 + "\n")
        # Return failure to block commit
        return False, []

    review_results: List[Tuple[str, str, Dict[str, object]]] = []
    all_passed = True
    
    # Count total chunks for progress tracking
    total_chunks = 0
    for path in changed_files:
        diff = get_diff_func(path)
        chunks = chunk_diff(diff, max_chunk_lines)
        total_chunks += len([c for c in chunks if c.strip()])
    
    if total_chunks == 0:
        return True, []
    
    current_chunk = 0
    print(f"Reviewing {total_chunks} chunk(s) across {len(changed_files)} file(s) with timeout {timeout}s per request...")
    print("")

    for path in changed_files:
        diff = get_diff_func(path)
        chunks = chunk_diff(diff, max_chunk_lines)
        if not chunks:
            continue
        for idx, chunk in enumerate(chunks):
            if not chunk.strip():
                continue
            current_chunk += 1
            print(f"[{current_chunk}/{total_chunks}] Reviewing {pretty_chunk_header(path, idx, len(chunks))}...")
            
            provider_config = choose_provider(
                chunk=chunk,
                configs=configs,
                primary_provider=primary_provider,
                secondary_provider=secondary_provider,
                line_threshold=line_threshold,
                char_threshold=char_threshold,
                hunk_threshold=hunk_threshold,
            )
            user_prompt = format_user_prompt(
                manual_text=manual,
                repo_name=repo_name,
                path=path,
                chunk=chunk,
                chunk_index=idx,
                chunk_total=len(chunks),
            )
            is_secondary = (
                secondary_provider
                and provider_config.provider == secondary_provider
            )
            try:
                review = review_chunk(
                    config=provider_config,
                    system_prompt=system_prompt,
                    user_prompt=user_prompt,
                    timeout=timeout,
                    cache_disabled=cache_disabled,
                    is_secondary=is_secondary,
                )
            except ReviewFailure as exc:
                error_msg = str(exc)
                if "timed out" in error_msg.lower():
                    print(f"  ⚠️  Timeout after {timeout}s - consider increasing AI_REVIEW_TIMEOUT")
                raise
            # If secondary provider failed (returned None), fall back to primary
            if review is None and is_secondary and primary_provider in configs:
                print(
                    f"Retrying with primary provider '{primary_provider}'..."
                )
                primary_config = configs[primary_provider]
                review = review_chunk(
                    config=primary_config,
                    system_prompt=system_prompt,
                    user_prompt=user_prompt,
                    timeout=timeout,
                    cache_disabled=cache_disabled,
                    is_secondary=False,
                )
                provider_config = primary_config
            
            # Skip if review is still None (both providers failed)
            if review is None:
                print(
                    f"Warning: Skipping review for {path} (chunk {idx + 1}) - all providers failed"
                )
                continue
                
            review_results.append(
                (
                    pretty_chunk_header(path, idx, len(chunks)),
                    provider_config.provider,
                    review,
                )
            )
            if review.get("status") != "approve":
                all_passed = False

    # Extract patterns from AI review findings (for pattern learning)
    if review_results:
        try:
            import sys
            pattern_extractor_path = REPO_ROOT / "scripts" / "hooks" / "extract_and_enhance_patterns.py"
            if pattern_extractor_path.exists():
                # Import the module
                import importlib.util
                spec = importlib.util.spec_from_file_location("extract_and_enhance_patterns", pattern_extractor_path)
                if spec and spec.loader:
                    extract_module = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(extract_module)
                    
                    ai_patterns = extract_module.extract_patterns_from_ai_findings(review_results)
                    if ai_patterns:
                        print("\n[PATTERN LEARNING] Extracting patterns from AI review findings...")
                        # Update pattern repository (for record-keeping)
                        if extract_module.update_pattern_repository(ai_patterns):
                            print(f"✓ Updated Pattern-Learning-Repository.md with {len(ai_patterns)} pattern(s)")
                        # CRITICAL: Enhance Code_check_prompt_manual.txt FIRST (authoritative source)
                        # Then enhance other prompts that reference the manual
                        for pattern in ai_patterns:
                            if extract_module.enhance_code_check_prompt(pattern):
                                print(f"✓ Enhanced Code_check_prompt_manual.txt (AUTHORITATIVE) with {pattern['id']}")
                            if extract_module.enhance_advanced_cot_prompt(pattern):
                                print(f"✓ Enhanced Advanced-CoT prompt with {pattern['id']}")
                        print("[PATTERN LEARNING] Pattern extraction completed\n")
        except Exception as e:
            # Don't fail review if pattern extraction fails
            print(f"Warning: Pattern extraction from AI findings failed: {e}")

    return all_passed, review_results


def print_review_outcomes(results: List[Tuple[str, str, Dict[str, object]]]) -> None:
    for header, provider, review in results:
        status = review.get("status", "unknown")
        summary = review.get("summary", "")
        findings = review.get("findings", [])
        print("=" * 80)
        print(f"{header}: {status.upper()} (provider: {provider})")
        if summary:
            print(f"Summary: {summary}")
        if isinstance(findings, list) and findings:
            print("- Findings:")
            for finding in findings:
                severity = finding.get("severity", "unknown")
                title = finding.get("title", "").strip() or "(untitled finding)"
                details = finding.get("details", "").strip()
                suggestion = finding.get("suggested_fix", "").strip()
                print(f"  • [{severity}] {title}")
                if details:
                    print(textwrap.indent(details, "    "))
                if suggestion:
                    print("    Suggested fix:")
                    print(textwrap.indent(suggestion, "      "))
        else:
            print("- No findings reported.")
    if results:
        print("=" * 80)


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run AI-assisted pre-commit review.",
    )
    parser.add_argument(
        "--max-lines",
        type=int,
        default=int(os.getenv("AI_REVIEW_MAX_LINES", DEFAULT_MAX_CHUNK_LINES)),
        help="Maximum number of diff lines per chunk.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=int(os.getenv("AI_REVIEW_TIMEOUT", "120")),  # Increased from 60 to 120 for large diffs
        help="API request timeout in seconds (default: 120).",
    )
    parser.add_argument(
        "--disable-cache",
        action="store_true",
        default=os.getenv("AI_REVIEW_DISABLE_CACHE", "0") == "1",
        help="Disable local caching of review responses.",
    )
    parser.add_argument(
        "--provider",
        type=str,
        default=os.getenv("AI_REVIEW_PROVIDER", Provider.ANTHROPIC),
        help="Primary AI provider to use (anthropic|openai).",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=int(os.getenv("AI_REVIEW_MAX_TOKENS", DEFAULT_MAX_TOKENS)),
        help="Maximum tokens to request from the model.",
    )
    parser.add_argument(
        "--secondary-provider",
        type=str,
        default=os.getenv("AI_REVIEW_SECONDARY_PROVIDER", Provider.OPENAI),
        help="Secondary AI provider to use for smaller/simple chunks.",
    )
    parser.add_argument(
        "--secondary-max-tokens",
        type=int,
        default=int(
            os.getenv("AI_REVIEW_SECONDARY_MAX_TOKENS", DEFAULT_SECONDARY_MAX_TOKENS)
        ),
        help="Maximum tokens to request from the secondary model.",
    )
    parser.add_argument(
        "--complex-lines",
        type=int,
        default=int(
            os.getenv(
                "AI_REVIEW_COMPLEXITY_LINE_THRESHOLD",
                DEFAULT_COMPLEXITY_LINE_THRESHOLD,
            )
        ),
        help="Mark chunks exceeding this diff line count as complex.",
    )
    parser.add_argument(
        "--complex-chars",
        type=int,
        default=int(
            os.getenv(
                "AI_REVIEW_COMPLEXITY_CHAR_THRESHOLD",
                DEFAULT_COMPLEXITY_CHAR_THRESHOLD,
            )
        ),
        help="Mark chunks exceeding this character count as complex.",
    )
    parser.add_argument(
        "--complex-hunks",
        type=int,
        default=int(
            os.getenv(
                "AI_REVIEW_COMPLEXITY_HUNK_THRESHOLD",
                DEFAULT_COMPLEXITY_HUNK_THRESHOLD,
            )
        ),
        help="Mark chunks exceeding this number of diff hunks as complex.",
    )
    return parser.parse_args(argv)


def detect_provider(explicit_provider: str, api_url: str) -> str:
    provider = (explicit_provider or "").strip().lower()
    if provider in (Provider.ANTHROPIC, Provider.OPENAI):
        return provider
    if "anthropic" in api_url.lower():
        return Provider.ANTHROPIC
    if "openai" in api_url.lower():
        return Provider.OPENAI
    # Default to Anthropic if unable to detect
    return Provider.ANTHROPIC


def main(argv: List[str]) -> int:
    """
    Main entry point for AI-assisted pre-commit review.
    
    NOTE: AI review is DISABLED by default and requires explicit opt-in.
    To enable: ENABLE_AI_REVIEW=1 git commit
    Or export: export ENABLE_AI_REVIEW=1
    """
    args = parse_args(argv)

    skip_flag = str(os.getenv("SKIP_AI_REVIEW", "0")).strip().lower()
    if skip_flag in {"1", "true", "yes"}:
        print("AI review skipped due to SKIP_AI_REVIEW being set.")
        return 0

    primary_api_url_env = os.getenv("AI_REVIEW_API_URL", "")
    primary_provider = detect_provider(args.provider, primary_api_url_env)
    primary_defaults = PROVIDER_DEFAULTS.get(
        primary_provider,
        PROVIDER_DEFAULTS[Provider.OPENAI],
    )
    primary_api_url = primary_api_url_env or primary_defaults["api_url"]
    primary_model = os.getenv("AI_REVIEW_MODEL", primary_defaults["model"])
    
    # Validate and correct Claude model name format
    if primary_provider == Provider.ANTHROPIC:
        # Fix common format errors: dots (3.5) should be hyphens (3-5) for API model names
        if "3.5" in primary_model or "3.7" in primary_model:
            corrected_model = primary_model.replace("3.5", "3-5").replace("3.7", "3-7")
            if corrected_model != primary_model:
                print(
                    f"⚠️  WARNING: Model name '{primary_model}' uses dots (3.5/3.7) which is incorrect.\n"
                    f"   Anthropic API requires hyphens (3-5/3-7). Corrected to: '{corrected_model}'",
                    file=sys.stderr,
                )
                primary_model = corrected_model
    
    primary_max_tokens = normalize_max_tokens(
        args.max_tokens,
        PROVIDER_DEFAULT_MAX_TOKENS.get(primary_provider, DEFAULT_MAX_TOKENS),
    )

    secondary_provider_arg = (args.secondary_provider or "").strip().lower()
    if secondary_provider_arg in {"", "none", "off", "disable", "disabled"}:
        secondary_provider = None
        secondary_api_url = None
        secondary_model = None
        secondary_max_tokens = 0
    else:
        secondary_api_url_env = os.getenv("AI_REVIEW_SECONDARY_API_URL", "")
        secondary_provider = detect_provider(
            args.secondary_provider, secondary_api_url_env
        )
        secondary_defaults = PROVIDER_DEFAULTS.get(
            secondary_provider,
            PROVIDER_DEFAULTS[Provider.OPENAI],
        )
        secondary_api_url = secondary_api_url_env or secondary_defaults["api_url"]
        secondary_model = os.getenv(
            "AI_REVIEW_SECONDARY_MODEL", secondary_defaults["model"]
        )
        secondary_max_tokens = normalize_max_tokens(
            args.secondary_max_tokens,
            PROVIDER_DEFAULT_MAX_TOKENS.get(
                secondary_provider, DEFAULT_SECONDARY_MAX_TOKENS
            ),
        )

    configs, missing_primary = load_provider_configs(
        primary_provider=primary_provider,
        primary_api_url=primary_api_url,
        primary_model=primary_model,
        primary_max_tokens=primary_max_tokens,
        secondary_provider=secondary_provider,
        secondary_api_url=secondary_api_url,
        secondary_model=secondary_model,
        secondary_max_tokens=secondary_max_tokens,
    )

    if missing_primary:
        expected_vars = ", ".join(
            PROVIDER_TOKEN_ENV_NAMES.get(primary_provider, [])
        ) or "AI_REVIEW_TOKEN"
        print(
            textwrap.dedent(
                f"""\
                ERROR: No API token configured for primary AI provider '{primary_provider}'.
                Set one of: {expected_vars}.
                To bypass temporarily, re-run with SKIP_AI_REVIEW=1 git commit --no-verify."""
            )
        )
        return 1

    if secondary_provider and secondary_provider not in configs:
        print(
            f"Note: Secondary provider '{secondary_provider}' token not found; "
            "falling back to the primary provider for all chunks."
        )
        secondary_provider = None

    try:
        manual = load_manual()
        all_passed, results = collect_reviews(
            configs=configs,
            primary_provider=primary_provider,
            secondary_provider=secondary_provider,
            manual=manual,
            max_chunk_lines=args.max_lines,
            timeout=args.timeout,
            cache_disabled=args.disable_cache,
            line_threshold=args.complex_lines,
            char_threshold=args.complex_chars,
            hunk_threshold=args.complex_hunks,
        )
    except ReviewFailure as exc:
        print(str(exc).strip())
        return 1

    print_review_outcomes(results)

    if all_passed:
        print("AI review passed for all inspected chunks.")
        return 0

    print("AI review reported issues. Commit blocked.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

