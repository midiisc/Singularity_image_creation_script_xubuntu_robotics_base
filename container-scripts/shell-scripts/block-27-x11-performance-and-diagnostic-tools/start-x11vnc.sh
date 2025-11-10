#!/usr/bin/env bash
# x11vnc - Can attach to existing display or create new one
# Official docs: https://github.com/LibVNC/x11vnc
# ArchWiki: https://wiki.archlinux.org/title/X11vnc

set -euo pipefail

DISPLAY_NUM=${1:-:1}
# Extract numeric part from display number (handle both :1 and 1 formats)
DISPLAY_NUM_NUMERIC="${DISPLAY_NUM#:}"
# Validate and default to 1 if empty or non-numeric
if [ -z "${DISPLAY_NUM_NUMERIC}" ] || ! [ "${DISPLAY_NUM_NUMERIC}" -ge 0 ] 2>/dev/null; then
    DISPLAY_NUM_NUMERIC=1
fi
PORT=$((5900 + DISPLAY_NUM_NUMERIC))

echo "Starting x11vnc on display ${DISPLAY_NUM} (port ${PORT})..."
echo "Official documentation: https://github.com/LibVNC/x11vnc"

# Create password file if doesn't exist
# Official recommendation: Always use password protection for security
if [ ! -f ~/.vnc/passwd ]; then
    echo "VNC password not set. Setting now:"
    x11vnc -storepasswd ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
fi

# Start x11vnc with security and performance optimizations
# Official best practices from x11vnc documentation:
# - -forever: Keep server running after client disconnects
# - -shared: Allow multiple clients to connect
# - -rfbauth: Use password file for authentication (secure)
# - -noxdamage: Disable X damage extension (better compatibility)
# - -ncache: Enable pixel caching for better performance
# - -ncache_cr: Enable client-side caching
# - -speeds: Optimize for LAN connections
# - -wait: Reduce CPU usage by waiting between updates
# - -defer: Defer screen updates for better performance
# - -noxrecord: Disable XRECORD extension (security)
# - -noxfixes: Disable XFIXES extension (compatibility)
x11vnc -display "${DISPLAY_NUM}" \
  -rfbport "${PORT}" \
  -rfbauth ~/.vnc/passwd \
  -forever \
  -shared \
  -noxdamage \
  -noxrecord \
  -noxfixes \
  -ncache 10 \
  -ncache_cr \
  -speeds lan \
  -wait 20 \
  -defer 20 \
  -bg \
  -o ~/.vnc/x11vnc.log
