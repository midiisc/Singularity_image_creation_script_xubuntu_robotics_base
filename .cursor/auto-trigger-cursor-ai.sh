#!/usr/bin/env bash
#===============================================================================
# AUTO-TRIGGER CURSOR AI IN IDE
#===============================================================================
# Purpose: Automatically trigger Cursor AI to show suggestions in IDE
# This script attempts to programmatically invoke Cursor AI analysis
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Get the file and prompt file from arguments
FILE="${1:-}"
PROMPT_FILE="${2:-}"

if [ -z "${FILE}" ] || [ -z "${PROMPT_FILE}" ]; then
    echo "Usage: $0 <file> <prompt-file>"
    exit 1
fi

# Method 1: Use Cursor CLI if available
if command -v cursor >/dev/null 2>&1; then
    # Try to open file in Cursor and trigger AI
    if cursor --command "workbench.action.quickOpen" "${FILE}" 2>/dev/null; then
        # Try to send command to Cursor to open AI chat with prompt
        if cursor --command "workbench.action.chat.open" 2>/dev/null; then
            # Try to send the prompt content
            if [ -f "${PROMPT_FILE}" ]; then
                cursor --command "workbench.action.chat.sendMessage" --input "$(cat "${PROMPT_FILE}")" 2>/dev/null || true
            fi
        fi
    fi
fi

# Method 2: Create a Cursor workspace command file
# Cursor can auto-execute commands from .cursor/commands/
mkdir -p "${SCRIPT_DIR}/commands" 2>/dev/null || true

COMMAND_FILE="${SCRIPT_DIR}/commands/audit-$(date +%s).json"
cat > "${COMMAND_FILE}" <<EOF
{
  "command": "cursor.chat.open",
  "args": {
    "file": "${FILE}",
    "prompt": "$(jq -Rs . < "${PROMPT_FILE}" 2>/dev/null || cat "${PROMPT_FILE}")"
  }
}
EOF

# Method 3: Create a special marker file that Cursor watches
# Cursor may auto-trigger on certain file patterns
MARKER_FILE="${PROJECT_ROOT}/.cursor/.trigger-ai-$$.cursor"
cat > "${MARKER_FILE}" <<EOF
# CURSOR AI AUTO-TRIGGER
# File: ${FILE}
# Prompt: ${PROMPT_FILE}
# 
# This file triggers Cursor AI analysis automatically.
# Open ${FILE} in Cursor and use Cmd/Ctrl+K with the prompt from ${PROMPT_FILE}
EOF

# Method 4: Use Cursor's file association to auto-open
# Create a .cursor-trigger file that Cursor recognizes
TRIGGER_FILE="${PROJECT_ROOT}/.cursor-trigger"
cat > "${TRIGGER_FILE}" <<EOF
{
  "action": "audit",
  "file": "${FILE}",
  "prompt_file": "${PROMPT_FILE}",
  "timestamp": $(date +%s)
}
EOF

# Method 5: Try to use Cursor's extension API via IPC
# Check if Cursor is running and send IPC message
CURSOR_PID=$(pgrep -f "Cursor" 2>/dev/null | head -1 || echo "")
if [ -n "${CURSOR_PID}" ]; then
    # Try to send message to Cursor via named pipe or socket
    CURSOR_SOCKET="${HOME}/.cursor/ipc.sock"
    if [ -S "${CURSOR_SOCKET}" ] 2>/dev/null; then
        echo "{\"command\":\"chat.open\",\"file\":\"${FILE}\",\"prompt\":\"$(cat "${PROMPT_FILE}")\"}" | \
            nc -U "${CURSOR_SOCKET}" 2>/dev/null || true
    fi
fi

# Method 6: Create a VS Code-style task that Cursor can execute
mkdir -p "${PROJECT_ROOT}/.vscode" 2>/dev/null || true
cat > "${PROJECT_ROOT}/.vscode/tasks.json" <<'TASKS_EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Cursor AI Audit",
      "type": "shell",
      "command": "cursor",
      "args": [
        "--command",
        "workbench.action.chat.open"
      ],
      "problemMatcher": []
    }
  ]
}
TASKS_EOF

echo "Cursor AI trigger files created"
echo "File: ${FILE}"
echo "Prompt: ${PROMPT_FILE}"
echo ""
echo "If Cursor doesn't auto-trigger, manually:"
echo "  1. Open ${FILE} in Cursor"
echo "  2. Press Cmd/Ctrl+K"
echo "  3. Use prompt from ${PROMPT_FILE}"

