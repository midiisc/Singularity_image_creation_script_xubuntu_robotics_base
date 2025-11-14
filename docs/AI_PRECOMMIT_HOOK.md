# AI-Assisted Code Review

This repository uses AI-powered code review via Claude (Anthropic) to ensure code quality and consistency. **AI review is now primarily run in GitHub Actions** on all PRs and pushes, ensuring consistent review across all contributors.

## Overview

- **GitHub Actions**: AI review runs automatically on all PRs and pushes (primary method)
- **Local pre-commit hook**: AI review is **DISABLED by default** (can be enabled with `ENABLE_AI_REVIEW=1`)
- AI reviewer: `scripts/hooks/ai_precommit_review.py`
- Prompt source: `prompts/Code_check_prompt_manual.txt`

## AI Review in GitHub Actions (Primary Method)

AI review runs automatically in GitHub Actions on:
- All pull requests (PRs)
- All pushes to `beta` and `main` branches

### Configuration

1. **Set GitHub Secret**: Add your Anthropic API key as a GitHub Secret:
   - Go to: Repository Settings → Secrets and variables → Actions
   - Add secret: `ANTHROPIC_API_KEY` with your API key value
   - This is the same API key you use locally

2. **Automatic Execution**: The AI review job runs automatically - no additional configuration needed.

3. **Review Results**: 
   - Review findings are displayed in the GitHub Actions workflow output
   - Currently configured as **non-blocking** (warnings only)
   - Review the output to see any issues found

### Benefits of GitHub Actions AI Review

- ✅ **Consistent**: All PRs get reviewed, cannot be bypassed
- ✅ **Secure**: API keys stored in GitHub Secrets
- ✅ **Centralized**: Review history visible in PR timeline
- ✅ **Cost-effective**: Only runs on PRs/pushes, not every local commit
- ✅ **Team-wide**: Same review standards for all contributors

## Local Pre-Commit Hook (Optional)

**AI review is DISABLED by default in local pre-commit hooks.**

The pre-commit hook runs static checks only:
1. Static validation checks (pipe patterns, CMake flags, etc.)
2. ~~AI review~~ (disabled by default)

### Enabling Local AI Review (Not Recommended)

If you want to enable AI review locally (not recommended - use GitHub Actions instead):

```bash
# One-time enable for a commit
ENABLE_AI_REVIEW=1 git commit

# Or export for current session
export ENABLE_AI_REVIEW=1
git commit
```

**Why disabled locally?**
- Avoids API costs on every local commit
- Ensures consistent review in CI/CD
- Prevents bypass of review requirements
- Centralizes review history in PRs

## What the AI reviewer does

The AI reviewer (`ai_precommit_review.py`) automatically detects the environment:

- **GitHub Actions**: Reviews PR diffs (compares base branch to PR branch)
- **Local**: Reviews staged files (when enabled with `ENABLE_AI_REVIEW=1`)

Common behavior:
- Filters files with extensions commonly used in this repository (`.sh`, `.py`, `.cpp`, `.yaml`, etc.)
- Generates unified diffs and splits them into chunks (default 400 diff lines)
- Builds a strict review prompt using `prompts/Code_check_prompt_manual.txt` as the authoritative checklist
- Calls Claude (Anthropic) API and expects JSON with `status`, `summary`, and structured `findings`
- Reports findings with severity levels (critical, major, minor)
- In GitHub Actions: Outputs findings to workflow logs
- In local mode: Blocks commit when critical issues found

## Configuration

### GitHub Actions Configuration (Required)

1. **Add GitHub Secret**:
   - Repository Settings → Secrets and variables → Actions
   - Add secret: `ANTHROPIC_API_KEY`
   - Value: Your Anthropic API key (same as you use locally)

2. **Automatic Setup**: The workflow is already configured - no additional steps needed.

### Local Configuration (Optional - Only if enabling local review)

If you want to enable local AI review (not recommended), set the following environment variables:

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
| `AI_REVIEW_SECONDARY_PROVIDER` | Secondary backend for lightweight chunks | Defaults to `openai`. Set to `none` to disable. |
| `AI_REVIEW_SECONDARY_TOKEN` | Secondary API token (OpenAI) | Falls back to `OPENAI_API_KEY`, `OPENAI_API_TOKEN`. |
| `AI_REVIEW_SECONDARY_API_URL` | Secondary endpoint URL | Defaults to `https://api.openai.com/v1/chat/completions`. |
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

export AI_REVIEW_SECONDARY_TOKEN="sk-your-openai-key"
export AI_REVIEW_SECONDARY_API_URL="https://api.openai.com/v1/chat/completions"
export AI_REVIEW_SECONDARY_MODEL="gpt-4.1-mini"
export AI_REVIEW_SECONDARY_PROVIDER="openai"

# Or disable secondary provider (recommended):
export AI_REVIEW_SECONDARY_PROVIDER="none"
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
- Tune `AI_REVIEW_COMPLEXITY_*` thresholds if you need Claude to trigger more or less aggressively, or if you want OpenAI usage to increase/decrease.
- The runtime automatically sets `chmod 600` on `.git/hooks/pre-commit.env` before sourcing it. Keep the file within `.git/hooks/` so it never lands in version control.

