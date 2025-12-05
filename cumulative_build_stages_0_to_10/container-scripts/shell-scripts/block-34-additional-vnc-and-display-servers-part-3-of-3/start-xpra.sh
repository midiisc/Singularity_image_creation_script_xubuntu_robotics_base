#!/usr/bin/env bash
# Xpra Application Streaming with HTML5 client

set -euo pipefail

if ! command -v xpra >/dev/null 2>&1; then
    echo "ERROR: xpra command not found. Please install Xpra before running this launcher." >&2
    exit 1
fi

DISPLAY_NUM=${1:-10}
PORT=${2:-10000}

echo "=========================================="
echo "Xpra Application Streaming"
echo "=========================================="
echo "Display: :${DISPLAY_NUM}"
echo "TCP Port: ${PORT}"
echo "HTML5 Client: http://localhost:${PORT}/"
echo ""
echo "Usage:"
echo "  start_xpra.sh [display] [port]"
echo "  Example: start_xpra.sh 10 10000"
echo "=========================================="
echo ""

# Set up Xpra HTML5 web directory
# Official path per https://github.com/Xpra-org/xpra-html5
XPRA_HTML5_DIR="/usr/share/xpra/www"
XPRA_WEB_DIR=""
if [ -d "${XPRA_HTML5_DIR}" ]; then
    XPRA_WEB_DIR="${XPRA_HTML5_DIR}"
    export XPRA_WEB_DIR
    echo "✓ HTML5 client available at ${XPRA_HTML5_DIR}"
else
    echo "⚠ HTML5 client not found (using built-in if available)"
fi

XPRA_ARGS=(
    ":${DISPLAY_NUM}"
    "--bind-tcp=0.0.0.0:${PORT}"
    "--html=on"
    "--start=startxfce4"
    "--daemon=no"
    "--notifications=no"
    "--clipboard=yes"
    "--printing=no"
)

if [ -n "${XPRA_WEB_DIR}" ]; then
    XPRA_ARGS+=("--webdir=${XPRA_WEB_DIR}")
fi

echo "Starting Xpra server..."
xpra start "${XPRA_ARGS[@]}"

echo ""
echo "Xpra stopped"
