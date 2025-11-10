#!/usr/bin/env bash
# KasmVNC - Modern VNC with built-in web interface

set -euo pipefail

DISPLAY_NUM=1
VNC_PORT=$((5900 + DISPLAY_NUM))
WEB_PORT=6901

mkdir -p "${HOME}/.vnc"

# Create KasmVNC xstartup
cat > "${HOME}/.vnc/xstartup" << 'XS'
#!/bin/sh
eval "$(dbus-launch --sh-syntax)" 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
exec startxfce4
XS
chmod +x "${HOME}/.vnc/xstartup"

echo "Starting KasmVNC..."
echo "  Display: :${DISPLAY_NUM}"
echo "  VNC Port: ${VNC_PORT}"
echo "  Web Port: ${WEB_PORT}"
echo ""
echo "Connect: http://localhost:${WEB_PORT}"
echo ""


kasmvncserver ":${DISPLAY_NUM}" \
  -geometry 1920x1080 \
  -depth 24 \
  -websocketPort "${WEB_PORT}" \
  -interface 0.0.0.0


echo "KasmVNC started!"
tail -f "${HOME}/.vnc"/*.log
