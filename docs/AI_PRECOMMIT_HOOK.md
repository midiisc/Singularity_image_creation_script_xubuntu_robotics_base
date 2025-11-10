# AI-Assisted Pre-Commit Hook

The repository ships with a strict, AI-backed git pre-commit hook that builds on the existing `.cursor/pre-commit-audit.sh` shell review. This document explains how the hook works, how to configure the AI integration, and how to bypass it when necessary.

## Overview

- Hook script: `.git/hooks/pre-commit`
- AI reviewer: `scripts/hooks/ai_precommit_review.py`
- Prompt source: `prompts/Code_check_prompt_manual.txt`

The hook runs two consecutive stages:

1. `.cursor/pre-commit-audit.sh` – exhaustive static checks for shell scripts.
2. `ai_precommit_review.py` – collects staged diffs, sends them to a configured AI model, and blocks commits when the AI finds critical issues.

## What the AI reviewer does

- Filters staged files with extensions commonly used in this repository (`.sh`, `.py`, `.cpp`, `.yaml`, etc.).
- Generates unified diffs (`git diff --cached --unified=0`) and splits them into chunks (default 400 diff lines).
- Builds a strict review prompt using `prompts/Code_check_prompt_manual.txt` as the authoritative checklist.
- Dynamically routes simple chunks to the secondary model (Cursor/OpenAI) when configured, reserving Claude for complex or long-context reviews.
- Calls the selected AI model (Claude by default) and expects JSON with `status`, `summary`, and structured `findings`.
- Rejects the commit when any chunk returns `status: "reject"`; prints the AI feedback for each failing chunk.
- Caches successful responses in `.git/.ai-review-cache/` to avoid re-reviewing unchanged chunks.

## Configuration

Set the following environment variables (e.g., in your shell profile or via `direnv`). For convenience, `scripts/hooks/pre-commit.env.example` can be copied to `.git/hooks/pre-commit.env` and customised; the example pins `SKIP_AI_REVIEW=0` so the AI review always runs unless you explicitly override it.

### Auto-Loading Environment Variables

To automatically load AI review environment variables in all shell sessions, add the following to your shell profile (e.g., `~/.bashrc` for bash or `~/.zshrc` for zsh):

```bash
# Auto-load AI review environment variables for git pre-commit hook
# Source: Singularity_image_creation_script_xubuntu_robotics_base/.git/hooks/pre-commit.env
PRE_COMMIT_ENV="$HOME/Documents/Singularity_image_creation_script_xubuntu_robotics_base/.git/hooks/pre-commit.env"
if [ -f "$PRE_COMMIT_ENV" ]; then
    # Source the file with restricted permissions check
    if [ -r "$PRE_COMMIT_ENV" ]; then
        # shellcheck disable=SC1090
        . "$PRE_COMMIT_ENV"
    fi
fi
```

**Benefits:**
- Environment variables are automatically available in all new shell sessions
- No need to manually export variables before running git commands
- Pre-commit hook and shell sessions use the same configuration source
- Variables persist across terminal sessions

**Note:** Adjust the path in `PRE_COMMIT_ENV` to match your repository location. After adding this to your shell profile, open a new terminal or run `source ~/.bashrc` (or `source ~/.zshrc`) to load the variables.

| Variable | Purpose | Default / Notes |
|----------|---------|-----------------|
| `AI_REVIEW_TOKEN` | Primary API token (Claude) | Falls back to `ANTHROPIC_API_KEY`, `CLAUDE_API_KEY`. Required for complex reviews. |
| `AI_REVIEW_API_URL` | Primary endpoint URL | Defaults to Anthropic Claude messages API: `https://api.anthropic.com/v1/messages`. |
| `AI_REVIEW_MODEL` | Primary model name | Defaults to `claude-3.5-sonnet-latest`. |
| `AI_REVIEW_MAX_LINES` | Max diff lines per chunk | Defaults to `400`. |
| `AI_REVIEW_TIMEOUT` | API timeout in seconds | Defaults to `60`. |
| `AI_REVIEW_DISABLE_CACHE` | Disable on-disk cache if set to `1` | Cache path: `.git/.ai-review-cache/`. |
| `AI_REVIEW_PROVIDER` | Primary AI backend (`anthropic` or `openai`) | Defaults to `anthropic`. |
| `AI_REVIEW_MAX_TOKENS` | Max response tokens for the primary model | Defaults to `2048`. |
| `AI_REVIEW_SECONDARY_PROVIDER` | Secondary backend for lightweight chunks | Defaults to `cursor`. Set to `none` to disable. |
| `AI_REVIEW_SECONDARY_TOKEN` | Secondary API token (Cursor/OpenAI) | Falls back to `CURSOR_API_KEY`, `CURSOR_AGENT_KEY`, then `OPENAI_API_KEY`. |
| `AI_REVIEW_SECONDARY_API_URL` | Secondary endpoint URL | Defaults to `https://api.cursor.sh/v1/chat/completions`. |
| `AI_REVIEW_SECONDARY_MODEL` | Secondary model name | Defaults to `gpt-4.1-mini`. |
| `AI_REVIEW_SECONDARY_MAX_TOKENS` | Max tokens for the secondary model | Defaults to `1024`. |
| `AI_REVIEW_COMPLEXITY_LINE_THRESHOLD` | Line-count heuristic for complex chunks | Defaults to `150`. |
| `AI_REVIEW_COMPLEXITY_CHAR_THRESHOLD` | Character-count heuristic for complex chunks | Defaults to `6000`. |
| `AI_REVIEW_COMPLEXITY_HUNK_THRESHOLD` | Diff hunk heuristic for complex chunks | Defaults to `3`. |

Example configuration:

```bash
export AI_REVIEW_TOKEN="sk-your-token"
export AI_REVIEW_API_URL="https://api.anthropic.com/v1/messages"
export AI_REVIEW_MODEL="claude-3.5-sonnet-latest"
export AI_REVIEW_PROVIDER="anthropic"

export AI_REVIEW_SECONDARY_TOKEN="cursor-or-openai-token"
export AI_REVIEW_SECONDARY_API_URL="https://api.cursor.sh/v1/chat/completions"
export AI_REVIEW_SECONDARY_MODEL="gpt-4.1-mini"
export AI_REVIEW_SECONDARY_PROVIDER="cursor"
```

## Bypass and fallback options

- **Default behaviour:** `SKIP_AI_REVIEW` is treated as `0` (runs the review) unless you set it otherwise.

- **Temporarily skip AI review:** `SKIP_AI_REVIEW=1 git commit`
- **Skip all pre-commit checks:** `git commit --no-verify`
- **Missing token:** The hook fails with an actionable error message when no token is set. Supply one or skip explicitly if required.

## Caching behaviour

- Cache files are keyed by the provider, model, system prompt, and diff chunk.
- Cached responses are reused when the diff chunk is unchanged, dramatically reducing latency for iterative commits.
- Set `AI_REVIEW_DISABLE_CACHE=1` to ignore the cache.

## Exit codes

- `0`: All audits (shell + AI) passed; commit continues.
- `1`: Audit failure (ShellCheck, syntax, AI findings, or API failure). Fix issues or bypass intentionally.

## Maintenance tips

- Update `prompts/Code_check_prompt_manual.txt` whenever the review policy evolves; the AI prompt pulls the file verbatim.
- When introducing new file types, add their extensions to `ALLOWED_SUFFIXES` in `scripts/hooks/ai_precommit_review.py`.
- If the API schema diverges from Anthropic’s Claude endpoint, update `call_anthropic_api()` / `extract_review_content()` accordingly. For alternate providers, extend the abstractions in `ai_precommit_review.py`.
- Tune `AI_REVIEW_COMPLEXITY_*` thresholds if you need Claude to trigger more or less aggressively, or if you want Cursor usage to increase/decrease.
- The runtime automatically sets `chmod 600` on `.git/hooks/pre-commit.env` before sourcing it. Keep the file within `.git/hooks/` so it never lands in version control.

