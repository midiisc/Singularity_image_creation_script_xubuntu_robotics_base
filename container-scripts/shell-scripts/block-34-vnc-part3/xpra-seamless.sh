#!/usr/bin/env bash
# Xpra Seamless Mode - Stream individual applications

set -euo pipefail

if ! command -v xpra >/dev/null 2>&1; then
    echo "ERROR: xpra command not found. Please install Xpra before running this launcher." >&2
    exit 1
fi

APP=${1:-xterm}
DISPLAY_NUM=${2:-10}
PORT=${3:-10000}

echo "Starting Xpra in seamless mode for: ${APP}"
echo "Connect: http://localhost:${PORT}/"
echo ""

XPRA_HTML5_DIR="/usr/share/xpra/www"
XPRA_ARGS=(
    "--start=${APP}"
    "--bind-tcp=0.0.0.0:${PORT}"
    "--html=on"
    "--daemon=no"
    "--notifications=no"
    "--clipboard=yes"
)

if [ -d "${XPRA_HTML5_DIR}" ]; then
    XPRA_ARGS+=("--webdir=${XPRA_HTML5_DIR}")
else
    echo "⚠ HTML5 client not found at ${XPRA_HTML5_DIR} (falling back to Xpra defaults)"
fi

xpra start "${XPRA_ARGS[@]}"
