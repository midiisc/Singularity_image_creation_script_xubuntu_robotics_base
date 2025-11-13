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
DEFAULT_MAX_TOKENS = 2048
DEFAULT_SECONDARY_MAX_TOKENS = 1024
DEFAULT_COMPLEXITY_LINE_THRESHOLD = 150
DEFAULT_COMPLEXITY_CHAR_THRESHOLD = 6000
DEFAULT_COMPLEXITY_HUNK_THRESHOLD = 3
OPENAI_DEFAULT_MODEL = "gpt-4.1-mini"
OPENAI_DEFAULT_API_URL = "https://api.openai.com/v1/chat/completions"
ANTHROPIC_API_VERSION = "2023-06-01"


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
        # Valid model names: claude-3-opus-20240229, claude-3-sonnet-20240229, claude-3-haiku-20240307
        # Note: "claude-3.5-sonnet-latest" format is NOT supported - use specific version dates
        "model": "claude-3-opus-20240229",  # Using working model; override with AI_REVIEW_MODEL env var
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


def run_git(args: Iterable[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def get_staged_files() -> List[str]:
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


def get_staged_diff(path: str) -> str:
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
) -> Dict[str, object]:
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
    )


def call_anthropic_api(
    api_url: str,
    api_token: str,
    model: str,
    system_prompt: str,
    user_prompt: str,
    timeout: int,
    max_tokens: int,
) -> Dict[str, object]:
    effective_tokens = normalize_max_tokens(max_tokens, DEFAULT_MAX_TOKENS)
    payload = {
        "model": model,
        "max_tokens": effective_tokens,
        "system": system_prompt,
        "messages": [{"role": "user", "content": [{"type": "text", "text": user_prompt}]}],
        "temperature": 0,
    }
    headers = {
        "x-api-key": api_token,
        "anthropic-version": ANTHROPIC_API_VERSION,
        "content-type": "application/json",
    }
    return perform_request(
        api_url=api_url,
        token_header=None,
        token_value="",
        payload=payload,
        timeout=timeout,
        extra_headers=headers,
    )


def perform_request(
    api_url: str,
    token_header: Optional[str],
    token_value: str,
    payload: Dict[str, object],
    timeout: int,
    extra_headers: Dict[str, str],
) -> Dict[str, object]:
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
        raise ReviewFailure(f"AI review request failed: {exc.reason}") from exc
    except (TimeoutError, ValueError) as exc:
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
    """
    try:
        return json.loads(content)
    except json.JSONDecodeError as exc:
        raise ReviewFailure(
            textwrap.dedent(
                f"""\
                AI response is not valid JSON.
                Response content:
                {content}
                Error: {exc}
                """
            )
        ) from exc


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
            )
        else:
            raise ReviewFailure(f"Unsupported AI provider: {provider}")

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
    guidelines = textwrap.dedent(
        """\
        Review each diff chunk as an independent audit gate.
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
        Manual:
        ```
        {manual_text}
        ```
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
        Approve only when the diff chunk fully complies with all checklist
        items. When rejecting, include actionable guidance.
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
    staged_files = get_staged_files()
    if not staged_files:
        return True, []

    review_results: List[Tuple[str, str, Dict[str, object]]] = []
    all_passed = True

    for path in staged_files:
        diff = get_staged_diff(path)
        chunks = chunk_diff(diff, max_chunk_lines)
        if not chunks:
            continue
        for idx, chunk in enumerate(chunks):
            if not chunk.strip():
                continue
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
            review = review_chunk(
                config=provider_config,
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                timeout=timeout,
                cache_disabled=cache_disabled,
                is_secondary=is_secondary,
            )
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
        default=int(os.getenv("AI_REVIEW_TIMEOUT", "60")),
        help="API request timeout in seconds.",
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

