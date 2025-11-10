#!/usr/bin/env bash
# x11vnc - attach to existing X display
# Official docs: https://github.com/LibVNC/x11vnc
# ArchWiki: https://wiki.archlinux.org/title/X11vnc

set -euo pipefail

DISPLAY_NUM=${1:-1}
# Validate DISPLAY_NUM is a positive integer
if ! [[ "${DISPLAY_NUM}" =~ ^[0-9]+$ ]] || [ "${DISPLAY_NUM}" -le 0 ]; then
    echo "ERROR: Display number must be a positive integer" >&2
    exit 1
fi
PORT=$((5900 + DISPLAY_NUM))

echo "Starting x11vnc on display :${DISPLAY_NUM} (port ${PORT})"
echo "Official documentation: https://github.com/LibVNC/x11vnc"

# Create password file if doesn't exist
# SECURITY: Always use password protection (never use -nopw in production)
if [ ! -f ~/.vnc/passwd ]; then
    echo "VNC password not set. Setting now:"
    x11vnc -storepasswd ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
fi

# Start x11vnc with security and performance optimizations
# Official best practices:
# - -forever: Keep server running after client disconnects
# - -shared: Allow multiple clients to connect
# - -rfbauth: Use password file (secure, never use -nopw)
# - -noxdamage: Better compatibility
# - -ncache: Enable pixel caching
# - -speeds: Optimize for LAN
x11vnc -display ":${DISPLAY_NUM}" \
  -forever \
  -shared \
  -rfbport "${PORT}" \
  -rfbauth ~/.vnc/passwd \
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
