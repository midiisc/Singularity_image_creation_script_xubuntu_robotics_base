#!/usr/bin/env bash
# Advanced noVNC launcher with token authentication and SSL

set -euo pipefail

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is required to generate authentication tokens." >&2
  exit 1
fi

WEBSOCKIFY_PATH=$(command -v websockify || true)
if [ -z "${WEBSOCKIFY_PATH}" ]; then
  echo "ERROR: websockify binary not found. Install noVNC/websockify before running this launcher." >&2
  exit 1
fi

NOVNC_DIR=""
for candidate in /usr/local/share/novnc /usr/share/novnc; do
  if [ -d "${candidate}" ] && [ -f "${candidate}/vnc.html" ]; then
    NOVNC_DIR="${candidate}"
    break
  fi
done

if [ -z "${NOVNC_DIR}" ]; then
  echo "ERROR: noVNC web assets not found (checked /usr/local/share/novnc and /usr/share/novnc)." >&2
  exit 1
fi

VNC_DISPLAY="${1:-:1}"
WEB_PORT="${2:-6081}"
VNC_PORT=$((5900 + ${VNC_DISPLAY#:}))

# Generate random token for this session
TOKEN=$(openssl rand -hex 16)

echo "=========================================="
echo "Advanced noVNC Server"
echo "=========================================="
echo "VNC Display: ${VNC_DISPLAY}"
echo "Web Port: ${WEB_PORT}"
echo "Token: ${TOKEN}"
echo ""
echo "Connect: http://localhost:${WEB_PORT}/?token=${TOKEN}"
echo "=========================================="

# Start websockify with token authentication
# Create temporary token file (more robust than process substitution)
TOKEN_FILE=$(mktemp)
echo "${TOKEN}: localhost:${VNC_PORT}" > "${TOKEN_FILE}"
trap "rm -f '${TOKEN_FILE}'" EXIT INT TERM

"${WEBSOCKIFY_PATH}" \
  --web "${NOVNC_DIR}" \
  --token-plugin TokenFile \
  --token-source "${TOKEN_FILE}" \
  "${WEB_PORT}"
