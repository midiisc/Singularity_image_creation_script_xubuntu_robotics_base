#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ULTIMATE TurboVNC + VirtualGL + noVNC Launcher
# With all performance optimizations
# ============================================================================


# --- Configuration ---

#--- Sub-block 33.10: Section 4774 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
VNC_DISPLAY_NUM=${VNC_DISPLAY_NUM:-1}
VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
WEB_PORT=${WEB_PORT:-6081}
GEOM="${VNC_GEOM:-1920x1080}"
DEPTH="${VNC_DEPTH:-24}"


# Performance settings
TVNC_QUALITY="${TVNC_QUALITY:-95}"
TVNC_SUBSAMPLE="${TVNC_SUBSAMPLE:-1}"
TVNC_COMPRESSLEVEL="${TVNC_COMPRESSLEVEL:-2}"

# VirtualGL settings

# Ensure paths

# --- Cleanup function ---
cleanup() {
  echo ""
  echo "Shutting down all services..."
  vncserver -kill ":${VNC_DISPLAY_NUM}" 2>/dev/null || true
  pkill -f "websockify.*${WEB_PORT}" 2>/dev/null || true
  pkill -f pulseaudio 2>/dev/null || true
  jobs -p | xargs -r kill 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# --- Banner ---
echo "============================================"
echo "  ULTIMATE Remote Desktop Environment"
echo "============================================"
echo ""

# --- Check dependencies ---
echo "[1/8] Checking dependencies..."
for cmd in vncserver Xvnc startxfce4 vglrun websockify; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    echo "  ✓ ${cmd}"
  else
    echo "  ✗ ${cmd} - MISSING!"
    exit 1
  fi
done


# --- Check GPU ---
echo ""
echo "[2/8] Checking GPU..."
if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_NAME=$(timeout 5 nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "")
  if [ -n "${GPU_NAME}" ]; then
    echo "  ✓ GPU: ${GPU_NAME}"
  else
    echo "  ⚠ nvidia-smi found but no GPU detected"
  fi
else
  echo "  ⚠ No NVIDIA GPU detected (CPU rendering only)"
fi


# --- Setup VNC ---
echo ""
echo "[3/8] Configuring VNC..."

# Performance-optimized xstartup
cat > "$HOME/.vnc/xstartup" << 'XSTART'
#!/bin/sh
# Performance-optimized xstartup

# Load resources
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
fc-cache -f 2>/dev/null || true

# D-Bus
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
fi

# Disable ALL compositing and effects
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/show_frame_shadow -s false 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/show_popup_shadow -s false 2>/dev/null || true

# Disable screen management
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true
xset b off 2>/dev/null || true
xset r rate 250 30 2>/dev/null || true

# Start clipboard sync
autocutsel -fork -selection CLIPBOARD 2>/dev/null || true
autocutsel -fork -selection PRIMARY 2>/dev/null || true

# XFCE
exec startxfce4
XSTART
chmod +x "$HOME/.vnc/xstartup"
echo "  ✓ xstartup configured"


# --- Start VNC ---
echo ""
echo "[4/8] Starting TurboVNC server..."
echo "  Display: :${VNC_DISPLAY_NUM}"
echo "  Geometry: ${GEOM}"
echo "  Quality: ${TVNC_QUALITY}"
echo "  Subsample: ${TVNC_SUBSAMPLE}"


if [ ! -f "$HOME/.vnc/passwd" ]; then
  echo ""
  echo "⚠ VNC password not set. Please set it now:"
  vncpasswd
  echo ""
fi

vncserver ":${VNC_DISPLAY_NUM}" \
  -geometry "${GEOM}" \
  -depth "${DEPTH}" \
  -localhost \
  -xstartup "$HOME/.vnc/xstartup" \
  -quality "${TVNC_QUALITY}" \
  -compresslevel "${TVNC_COMPRESSLEVEL}" \
  -subsample "${TVNC_SUBSAMPLE}"

sleep 3

if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
  echo "  ✗ VNC server failed to start"
  cat "${HOME}/.vnc"/*.log 2>/dev/null | tail -20 || true
  exit 1
fi
echo "  ✓ VNC server running on :${VNC_DISPLAY_NUM}"

# --- Start PulseAudio ---
echo ""
echo "[5/8] Starting audio support..."
if command -v pulseaudio >/dev/null 2>&1; then
  if ! pulseaudio --check 2>/dev/null; then
    pulseaudio --start --exit-idle-time=-1 2>/dev/null &
    echo "  ✓ PulseAudio started"
  else
    echo "  ✓ PulseAudio already running"
  fi
else
  echo "  ⚠ PulseAudio not available"
fi


# --- Start noVNC ---
echo ""
echo "[6/8] Starting noVNC (HTML5 interface)..."

WEBSOCKIFY=""
for candidate in /usr/bin/websockify /usr/local/bin/websockify; do
  [ -x "${candidate}" ] && WEBSOCKIFY="${candidate}" && break
done

# Launch websockify with filtered logging and relaxed pipe handling, returning background PID.
start_websockify_filtered() {
  local web_port="$1"
  local vnc_port="$2"
  local novnc_dir="$3"

  (
    set +e
    set +o pipefail
    "${WEBSOCKIFY}" --web "${novnc_dir}" "${web_port}" "localhost:${vnc_port}" 2>&1 \
      | grep -Ev "WARNING|numpy" \
      || true
  ) &

  echo $!
}


if [ -z "${WEBSOCKIFY}" ]; then
  echo "  ✗ websockify not found - skipping web interface"
else
  NOVNC_DIR=""
  for candidate in /usr/local/share/novnc /usr/share/novnc; do
    [ -d "${candidate}" ] && [ -f "${candidate}/vnc.html" ] && NOVNC_DIR="${candidate}" && break
  done

  if [ -n "${NOVNC_DIR}" ]; then
    WSPID=$(start_websockify_filtered "${WEB_PORT}" "${VNC_PORT}" "${NOVNC_DIR}")
    sleep 2
    if kill -0 "${WSPID}" 2>/dev/null; then
      echo "  ✓ noVNC running on port ${WEB_PORT}"
    else
      echo "  ✗ noVNC failed to start"
    fi
  else
    echo "  ⚠ noVNC files not found"
  fi
fi

# --- Performance check ---
echo ""
echo "[7/8] Running performance check..."

# Quick GPU test
if command -v vglrun >/dev/null 2>&1 && command -v glxinfo >/dev/null 2>&1; then
  RENDERER=$(
    vglrun glxinfo 2>/dev/null \
      | awk -F': ' '/OpenGL renderer/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' \
      || true
  )
  if [ -n "${RENDERER:-}" ]; then
    echo "  ✓ GPU rendering: ${RENDERER}"
  else
    echo "  ⚠ GPU rendering test failed"
  fi
else
  echo "  ⚠ Cannot test GPU rendering"
fi


# --- Connection info ---
NODE=$(hostname -f 2>/dev/null || hostname)
echo ""
echo "============================================"
echo "  🎉 Remote Desktop Ready!"
echo "============================================"
echo ""
echo "Node: ${NODE}"
echo "Display: :${VNC_DISPLAY_NUM}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "METHOD 1: VNC Viewer (Best Performance)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
echo ""
echo "Stage 1 - Tunnel to Login Node:"
echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} \${USER}@login.hpc.edu"
echo ""
echo "Stage 2 - From Login Node to Compute Node:"
echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} \${USER}@${NODE}"
echo ""
echo "Alternative - Direct Two-Stage Tunnel:"
echo "   ssh -J \${USER}@login.hpc.edu -L ${VNC_PORT}:localhost:${VNC_PORT} \${USER}@${NODE}"
echo ""
echo "Connect VNC to: localhost:${VNC_PORT}"
echo ""


if [ -n "${WSPID:-}" ] && kill -0 "${WSPID}" 2>/dev/null; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "METHOD 2: Web Browser (No Install Needed)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
  echo ""
  echo "Stage 1 - Tunnel to Login Node:"
  echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} \${USER}@login.hpc.edu"
  echo ""
  echo "Stage 2 - From Login Node to Compute Node:"
  echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} \${USER}@${NODE}"
  echo ""
  echo "Alternative - Direct Two-Stage Tunnel:"
  echo "   ssh -J \${USER}@login.hpc.edu -L ${WEB_PORT}:localhost:${WEB_PORT} \${USER}@${NODE}"
  echo ""
  echo "Browse: http://localhost:${WEB_PORT}"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PERFORMANCE TIPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• GPU apps: vglrun <app> or use aliases (vblender, etc.)"
echo "• Benchmark: vgl_benchmark.sh"
echo "• Monitor: vnc_monitor.sh"
echo "• Tune VNC: turbovnc_tune.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CONTROLS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• Stop: Press Ctrl+C"
echo "• Logs: tail -f ~/.vnc/*.log"
echo "• Status: vncserver -list"
echo "============================================"
echo ""

# --- Monitor and keep alive ---
echo "[8/8] Monitoring services..."
while true; do
  sleep 30

  # Check VNC
  if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
    echo "ERROR: VNC server died"
    exit 1
  fi


  # Check websockify
  if [ -n "${WSPID:-}" ]; then
    if ! kill -0 "${WSPID}" 2>/dev/null; then
      echo "WARNING: websockify died, restarting..."
      WSPID=$(start_websockify_filtered "${WEB_PORT}" "${VNC_PORT}" "${NOVNC_DIR}")
    fi
  fi
done
