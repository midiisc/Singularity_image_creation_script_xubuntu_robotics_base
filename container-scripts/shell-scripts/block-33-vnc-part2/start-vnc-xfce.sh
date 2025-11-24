#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Enhanced TurboVNC + VirtualGL + noVNC Launcher with Full Configuration
# ============================================================================

# --- Default Configuration ---
VNC_DISPLAY_NUM=${VNC_DISPLAY_NUM:-1}
VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
WEB_PORT=${WEB_PORT:-6081}
TURBOVNC_WEB_PORT=$((5800 + VNC_DISPLAY_NUM))
GEOM="${VNC_GEOM:-1920x1080}"
DEPTH="${VNC_DEPTH:-24}"

# VirtualGL Configuration
VGL_DISPLAY_AUTO_DETECT=${VGL_DISPLAY_AUTO_DETECT:-1}
VGL_DISPLAY_FALLBACK="${VGL_DISPLAY_FALLBACK:-:0}"
VGL_COMPRESS="${VGL_COMPRESS:-proxy}"
VGL_READBACK="${VGL_READBACK:-sync}"
VGL_FPS="${VGL_FPS:-0}"
VGL_VERBOSE="${VGL_VERBOSE:-0}"
VGL_DEBUG="${VGL_DEBUG:-0}"
VGL_FORCE_GPU="${VGL_FORCE_GPU:-0}"

# VNC Integration
VNC_VGL_INTEGRATION="${VNC_VGL_INTEGRATION:-1}"
VNC_OPENGL_EXTENSIONS="${VNC_OPENGL_EXTENSIONS:-1}"
VNC_GLX_EXTENSIONS="${VNC_GLX_EXTENSIONS:-1}"

# Debug Configuration
DEBUG_MODE="${DEBUG_MODE:-0}"
VERBOSE_MODE="${VERBOSE_MODE:-0}"

# Security: bind to localhost only (use -nolisten for remote access)
SECURITY_ARGS="-localhost"

# --- Help Function ---
show_help() {
  cat << 'EOF'
Enhanced TurboVNC + VirtualGL + noVNC Launcher

USAGE:
  start_vnc_xfce.sh [OPTIONS]

OPTIONS:
  --vgl-display DISPLAY    Set VGL_DISPLAY (default: auto-detect)
  --vgl-compress METHOD    Set compression (proxy|jpeg|rgb) (default: proxy)
  --vgl-readback MODE      Set readback mode (sync|async) (default: sync)
  --vgl-fps               Enable FPS display (default: disabled)
  --vgl-verbose           Enable verbose VirtualGL output
  --vgl-debug             Enable debug mode with detailed logging
  --vnc-display NUM       Set VNC display number (default: 1)
  --vnc-geometry SIZE     Set VNC geometry (default: 1920x1080)
  --vnc-depth BITS        Set color depth (default: 24)
  --no-vgl                Disable VirtualGL (software rendering)
  --force-vgl             Force VirtualGL even if not detected
  --debug                 Enable debug mode
  --verbose               Enable verbose output
  --help, -h              Show this help message

ENVIRONMENT VARIABLES:
  VGL_DISPLAY_AUTO_DETECT=1    Auto-detect VNC display (default: 1)
  VGL_DISPLAY_FALLBACK=:0      Fallback display (default: :0)
  VGL_COMPRESS=proxy           Compression method (default: proxy)
  VGL_READBACK=sync            Readback mode (default: sync)
  VGL_FPS=0                    FPS display (default: 0)
  VGL_VERBOSE=0                Verbose output (default: 0)
  VGL_DEBUG=0                  Debug mode (default: 0)
  VNC_DISPLAY_NUM=1            VNC display number (default: 1)
  VNC_GEOM=1920x1080           VNC geometry (default: 1920x1080)
  VNC_DEPTH=24                 Color depth (default: 24)

EXAMPLES:
  # Auto-detect everything
  start_vnc_xfce.sh

  # Specify VNC display and enable debug
  start_vnc_xfce.sh --vnc-display 2 --vgl-debug

  # Force specific VirtualGL display
  start_vnc_xfce.sh --vgl-display :2 --vgl-verbose

  # Disable VirtualGL (software rendering)
  start_vnc_xfce.sh --no-vgl

  # Test different compression
  start_vnc_xfce.sh --vgl-compress jpeg --vgl-fps
EOF
}


# --- Command Line Argument Parsing ---
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --vgl-display)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --vgl-display" >&2
          exit 1
        fi
        VGL_DISPLAY_AUTO_DETECT=0
        VGL_DISPLAY_FALLBACK="$2"
        shift 2
        ;;
      --vgl-compress)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --vgl-compress" >&2
          exit 1
        fi
        VGL_COMPRESS="$2"
        shift 2
        ;;
      --vgl-readback)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --vgl-readback" >&2
          exit 1
        fi
        VGL_READBACK="$2"
        shift 2
        ;;
      --vgl-fps)
        VGL_FPS="1"
        shift
        ;;
      --vgl-verbose)
        VGL_VERBOSE="1"
        VERBOSE_MODE="1"
        shift
        ;;
      --vgl-debug)
        VGL_DEBUG="1"
        DEBUG_MODE="1"
        VERBOSE_MODE="1"
        shift
        ;;
      --vnc-display)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --vnc-display" >&2
          exit 1
        fi
        VNC_DISPLAY_NUM="$2"
        VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
        TURBOVNC_WEB_PORT=$((5800 + VNC_DISPLAY_NUM))
        shift 2
        ;;
      --vnc-geometry)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --vnc-geometry" >&2
          exit 1
        fi
        GEOM="$2"
        shift 2
        ;;
      --vnc-depth)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --vnc-depth" >&2
          exit 1
        fi
        DEPTH="$2"
        shift 2
        ;;
      --no-vgl)
        VNC_VGL_INTEGRATION="0"
        shift
        ;;
      --force-vgl)
        VGL_FORCE_GPU="1"
        shift
        ;;
      --debug)
        DEBUG_MODE="1"
        VERBOSE_MODE="1"
        shift
        ;;
      --verbose)
        VERBOSE_MODE="1"
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
}

# --- VirtualGL Display Detection ---
detect_vgl_display() {
  # Official VirtualGL docs: When using TurboVNC with -vgl flag, VGL_DISPLAY should be set to the VNC display
  # Reference: https://rawcdn.githack.com/VirtualGL/virtualgl/3.1.4/doc/index.html
  if [ "$VGL_DISPLAY_AUTO_DETECT" = "1" ]; then
    # Primary: Use the VNC display that's about to be started (most reliable)
    # When TurboVNC starts with -vgl flag, VirtualGL should use the VNC display
    if [ -n "${VNC_DISPLAY_NUM:-}" ]; then
      export VGL_DISPLAY=":${VNC_DISPLAY_NUM}"
      [ "${VERBOSE_MODE}" = "1" ] && echo "  ✓ Set VGL_DISPLAY to VNC display: :${VNC_DISPLAY_NUM}"
      return 0
    fi
    
    # Fallback: Try to detect VNC display from running processes
    local vnc_display="" vnc_cmd=""
    
    # Method 1: Check for Xvnc processes using pgrep
    if command -v pgrep >/dev/null 2>&1; then
      vnc_cmd=$(pgrep -af "Xvnc" 2>/dev/null | head -1 || true)
      if [ -n "${vnc_cmd}" ]; then
        vnc_display=$(echo "${vnc_cmd}" | grep -E -o ':[0-9]+' | head -1 || true)
      fi
    else
      vnc_display=$(# SC2009: Consider using pgrep instead
            ps aux 2>/dev/null | grep -v grep | grep -E -o 'Xvnc.*:[0-9]+' | head -1 | grep -E -o ':[0-9]+' | head -1 || true)
    fi
    
    # Method 2: Check for vncserver processes
    if [ -z "${vnc_display:-}" ]; then
      if command -v pgrep >/dev/null 2>&1; then
        vnc_cmd=$(pgrep -af "vncserver" 2>/dev/null | head -1 || true)
        if [ -n "${vnc_cmd}" ]; then
          vnc_display=$(echo "${vnc_cmd}" | grep -E -o ':[0-9]+' | head -1 || true)
        fi
      else
        vnc_display=$(# SC2009: Consider using pgrep instead
            ps aux 2>/dev/null | grep -v grep | grep -E -o 'vncserver.*:[0-9]+' | head -1 | grep -E -o ':[0-9]+' | head -1 || true)
      fi
    fi
    
    # Method 3: Check for display :1, :2, etc.
    if [ -z "${vnc_display:-}" ]; then
      for i in 1 2 3 4 5; do
        if [ -S "/tmp/.X11-unix/X${i}" ] 2>/dev/null; then
          vnc_display=":${i}"
          break
        fi
      done
    fi
    
    if [ -n "${vnc_display:-}" ]; then
      export VGL_DISPLAY="${vnc_display}"
      [ "${VERBOSE_MODE:-0}" = "1" ] && echo "  ✓ Auto-detected VGL_DISPLAY: ${vnc_display}"
    else
      export VGL_DISPLAY="${VGL_DISPLAY_FALLBACK}"
      [ "${VERBOSE_MODE:-0}" = "1" ] && echo "  ⚠ Using fallback VGL_DISPLAY: ${VGL_DISPLAY_FALLBACK}"
    fi
  else
    export VGL_DISPLAY="${VGL_DISPLAY_FALLBACK}"
    [ "${VERBOSE_MODE:-0}" = "1" ] && echo "  ✓ Using specified VGL_DISPLAY: ${VGL_DISPLAY_FALLBACK}"
  fi
}

# --- VirtualGL Configuration ---
configure_virtualgl() {
  if [ "${VNC_VGL_INTEGRATION:-1}" = "1" ]; then
    echo "Configuring VirtualGL..."
    
    # Detect display
    detect_vgl_display
    
    # Set VirtualGL environment variables
    export VGL_COMPRESS
    export VGL_READBACK
    export VGL_LOGO="0"
    export VGL_FPS
    export VGL_VERBOSE
    
    # Debug mode settings
    if [ "${VGL_DEBUG:-0}" = "1" ]; then
      export VGL_VERBOSE="1"
      export VGL_LOG_LEVEL="2"
      [ "${VERBOSE_MODE:-0}" = "1" ] && echo "  ✓ VirtualGL debug mode enabled"
    fi
    
    # Force GPU usage
    if [ "${VGL_FORCE_GPU:-0}" = "1" ]; then
      export VGL_FORCE_GPU="1"
      [ "${VERBOSE_MODE:-0}" = "1" ] && echo "  ✓ VirtualGL force GPU enabled"
    fi
    
    if [ "${VERBOSE_MODE:-0}" = "1" ]; then
      echo "  ✓ VirtualGL configured:"
      echo "    VGL_DISPLAY=${VGL_DISPLAY:-}"
      echo "    VGL_COMPRESS=${VGL_COMPRESS:-}"
      echo "    VGL_READBACK=${VGL_READBACK:-}"
      echo "    VGL_FPS=${VGL_FPS:-}"
      echo "    VGL_VERBOSE=${VGL_VERBOSE:-}"
    fi
  else
    echo "VirtualGL integration disabled (software rendering)"
  fi
}

# --- VirtualGL Test Function ---
test_virtualgl() {
  if [ "${VNC_VGL_INTEGRATION:-1}" = "1" ]; then
    echo "Testing VirtualGL configuration..."
    
    # Check if vglrun is available
    if ! command -v vglrun >/dev/null 2>&1; then
      echo "  ✗ vglrun not found - VirtualGL not available"
      return 1
    fi
    
    # Check if VirtualGL can access the display
    if [ -n "${VGL_DISPLAY:-}" ]; then
      echo "  ✓ VGL_DISPLAY set to: ${VGL_DISPLAY}"
      
      # Test VirtualGL connection
      local glxinfo_output=""
      if glxinfo_output=$(vglrun -d "${VGL_DISPLAY}" glxinfo 2>/dev/null); then
        echo "  ✓ VirtualGL can access display ${VGL_DISPLAY}"
        
        # Test OpenGL rendering
        if printf '%s\n' "${glxinfo_output}" | grep -q "OpenGL renderer"; then
          echo "  ✓ OpenGL rendering available"
          return 0
        else
          echo "  ⚠ OpenGL rendering not available"
          return 1
        fi
      else
        echo "  ✗ VirtualGL cannot access display ${VGL_DISPLAY}"
        return 1
      fi
    else
      echo "  ✗ VGL_DISPLAY not set"
      return 1
    fi
  else
    echo "VirtualGL integration disabled"
    return 0
  fi
}

# --- Parse command line arguments ---
parse_arguments "$@"

# --- Ensure TurboVNC is in PATH ---

# --- Cleanup function ---
cleanup() {
  echo ""
  echo "Shutting down VNC services..."
  vncserver -kill ":${VNC_DISPLAY_NUM}" 2>/dev/null || true
  pkill -f "websockify.*${WEB_PORT}" 2>/dev/null || true
  jobs -p | xargs -r kill 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# --- Check dependencies ---
check_dependencies() {
  local missing=0

  echo "Checking dependencies..."


  if ! command -v vncserver >/dev/null 2>&1; then
    echo "  ✗ vncserver not found"
    missing=1
  else
    echo "  ✓ vncserver: $(command -v vncserver)"
  fi


  if ! command -v Xvnc >/dev/null 2>&1; then
    echo "  ✗ Xvnc not found"
    missing=1
  else
    echo "  ✓ Xvnc: $(command -v Xvnc)"
  fi

  if ! command -v startxfce4 >/dev/null 2>&1; then
    echo "  ✗ startxfce4 not found"
    missing=1
  else
    echo "  ✓ XFCE4 available"
  fi

  if [ "${missing}" -eq 1 ]; then
    echo ""
    echo "ERROR: Missing required dependencies"
    echo "PATH: ${PATH}"
    exit 1
  fi

  echo "✓ All dependencies found"
  echo ""
}

# --- Check VirtualGL availability ---
check_virtualgl() {
  local gpu_info=""
  echo "Checking VirtualGL availability..."

  # Add VirtualGL to PATH

  if command -v vglrun >/dev/null 2>&1; then
    echo "  ✓ VirtualGL available: $(command -v vglrun)"

    # Check GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
      gpu_info=$(timeout 5 nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "")
      if [ -n "${gpu_info:-}" ]; then
        echo "  ✓ GPU detected: ${gpu_info}"
      else
        echo "  ⚠ nvidia-smi found but no GPU detected"
      fi
    else
      echo "  ⚠ nvidia-smi not found (CPU rendering only)"
    fi



    # Check OpenGL utilities
    if command -v glxinfo >/dev/null 2>&1; then
      echo "  ✓ glxinfo available for OpenGL testing"
    fi
    if command -v glxspheres64 >/dev/null 2>&1; then
      echo "  ✓ glxspheres64 available for GPU benchmarking"
    fi
  else
    echo "  ⚠ VirtualGL not available"
    echo "    GPU-accelerated applications may not work properly"
  fi

  echo ""
}

# --- Setup VNC configuration ---
setup_vnc_config() {
  if ! install -d -m 0700 "${HOME}/.vnc"; then
    echo "Failed to create ${HOME}/.vnc directory" >&2
    exit 1
  fi

  # Create xstartup script with VirtualGL integration
  # Official TurboVNC docs: https://rawcdn.githack.com/TurboVNC/turbovnc/3.2.1/doc/index.html
  # Official VirtualGL docs: https://rawcdn.githack.com/VirtualGL/virtualgl/3.1.4/doc/index.html
  if ! cat > "${HOME}/.vnc/xstartup" << 'XSTART'
#!/bin/sh
# Enhanced TurboVNC xstartup for XFCE4 + VirtualGL
# Official documentation:
# - TurboVNC: https://rawcdn.githack.com/TurboVNC/turbovnc/3.2.1/doc/index.html
# - VirtualGL: https://rawcdn.githack.com/VirtualGL/virtualgl/3.1.4/doc/index.html
# - x11vnc: https://github.com/LibVNC/x11vnc

# Load X resources
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true

# Font cache
fc-cache -f 2>/dev/null || true

# Start D-Bus if not running
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
fi

# VirtualGL Environment Setup
if [ -n "${VGL_DISPLAY:-}" ]; then
  export VGL_DISPLAY
  export VGL_COMPRESS="${VGL_COMPRESS:-proxy}"
  export VGL_READBACK="${VGL_READBACK:-sync}"
  export VGL_LOGO="${VGL_LOGO:-0}"
  export VGL_FPS="${VGL_FPS:-0}"
  export VGL_VERBOSE="${VGL_VERBOSE:-0}"
  
  # Debug mode
  if [ "${VGL_DEBUG:-0}" = "1" ]; then
    export VGL_VERBOSE="1"
    export VGL_LOG_LEVEL="2"
  fi
  
  # Force GPU usage
  if [ "${VGL_FORCE_GPU:-0}" = "1" ]; then
    export VGL_FORCE_GPU="1"
  fi
fi

# X11 Configuration for VirtualGL
export DISPLAY="${DISPLAY:-:1}"

# Disable compositing for better VNC performance
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /general/use_compositing -s false 2>/dev/null || true

# XFCE4 optimizations for VirtualGL
export XFWM4_USE_PRESENT=0  # Disable Present extension (can cause issues with VirtualGL)
export XFCE4_SESSION_DEBUG=0  # Disable XFCE debug output

# Disable screen blanking
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# VirtualGL Integration Test (if enabled)
if [ "${VNC_VGL_INTEGRATION:-1}" = "1" ] && [ -n "${VGL_DISPLAY:-}" ]; then
  # Test VirtualGL connection
  if command -v vglrun >/dev/null 2>&1; then
    # Set up VirtualGL environment
    export VGL_DISPLAY
    echo "VirtualGL configured for display: $VGL_DISPLAY"
  else
    echo "Warning: VirtualGL not found, using software rendering"
  fi
fi

# Start XFCE4
exec /usr/bin/startxfce4
XSTART
then
    if ! chmod +x "${HOME}/.vnc/xstartup"; then
        echo "Failed to set execute permission on ${HOME}/.vnc/xstartup" >&2
        exit 1
    fi
    echo "✓ VNC configuration created"
else
    echo "Failed to create ${HOME}/.vnc/xstartup" >&2
    exit 1
fi
}

# --- Start VNC server ---
start_vnc_server() {
  echo "Starting TurboVNC server..."
  echo "  Display: :${VNC_DISPLAY_NUM}"
  echo "  Geometry: ${GEOM}"
  echo "  Depth: ${DEPTH}"
  echo "  VirtualGL Integration: $([ "${VNC_VGL_INTEGRATION:-1}" = "1" ] && echo "Enabled" || echo "Disabled")"

  # Check if VNC password is set
  if [ ! -f "${HOME}/.vnc/passwd" ]; then
    echo ""
    echo "⚠ VNC password not set. Please set it now:"
    vncpasswd
    echo ""
  fi

  # Configure VirtualGL before starting VNC
  configure_virtualgl

  # Build VNC server arguments
  local vnc_args=(
    ":${VNC_DISPLAY_NUM}"
    "-geometry" "${GEOM}"
    "-depth" "${DEPTH}"
    "${SECURITY_ARGS}"
    "-xstartup" "${HOME}/.vnc/xstartup"
  )

  # Add VirtualGL-specific VNC arguments if integration is enabled
  # Official TurboVNC docs: Use -vgl flag for VirtualGL integration
  # Reference: https://rawcdn.githack.com/TurboVNC/turbovnc/3.2.1/doc/index.html
  if [ "${VNC_VGL_INTEGRATION:-1}" = "1" ]; then
    # CRITICAL: Add -vgl flag for VirtualGL integration (official recommendation)
    # This enables VirtualGL to send rendered 3D images to TurboVNC via shared memory
    vnc_args+=("-vgl")
    
    # Add OpenGL extensions for VirtualGL
    if [ "${VNC_OPENGL_EXTENSIONS:-1}" = "1" ]; then
      vnc_args+=("-extension" "GLX")
    fi
    
    # Add GLX extensions for VirtualGL
    if [ "${VNC_GLX_EXTENSIONS:-1}" = "1" ]; then
      vnc_args+=("-extension" "MIT-SHM")
    fi
    
    # Add VirtualGL-optimized settings
    vnc_args+=(
      "-dpi" "96"
      "-desktop" "Xubuntu-VGL"
      "-alwaysshared"
      "-dontdisconnect"
    )
    
    [ "${VERBOSE_MODE:-0}" = "1" ] && echo "  ✓ VirtualGL-optimized VNC arguments added (with -vgl flag)"
  fi

  # Start VNC server with arguments
  vncserver "${vnc_args[@]}"

  # Wait for server to start
  sleep 3

  # Verify
  if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
    echo "ERROR: VNC server failed to start"
    echo "Check logs:"
    find "${HOME}/.vnc" -maxdepth 1 -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2- || true
    echo ""
    find "${HOME}/.vnc" -maxdepth 1 -name "*.log" -type f -exec tail -20 {} \; 2>/dev/null || true
    exit 1
  fi


  echo "✓ VNC server running on display :${VNC_DISPLAY_NUM} (port ${VNC_PORT})"
}


# --- Check TurboVNC's built-in webserver ---
check_turbovnc_webserver() {
  # TurboVNC may start its own webserver automatically
  if ss -tuln 2>/dev/null | grep -q ":${TURBOVNC_WEB_PORT}\b"; then
    echo "✓ TurboVNC built-in webserver detected on port ${TURBOVNC_WEB_PORT}"
    return 0
  else
    echo "⚠ TurboVNC built-in webserver not running"
    return 1
  fi
}

# --- Start noVNC (websockify) ---
start_novnc() {
  echo "Starting noVNC (HTML5 VNC client)..."

  # Find websockify
  local websockify_path=""

#--- Sub-block 33.5: Section 4574 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
  for candidate in /usr/bin/websockify /usr/local/bin/websockify "${MINIFORGE_HOME:-/opt/miniforge3}/bin/websockify"; do
    if [ -x "${candidate}" ]; then
      websockify_path="${candidate}"
      echo "  Found websockify: ${websockify_path}"
      break
    fi
  done

  if [ -z "${websockify_path:-}" ]; then
    echo "  ✗ websockify not found - noVNC will not be available"
    return 1
  fi

  # Find noVNC web files
  local novnc_dir=""
  for candidate in /usr/local/share/novnc /usr/share/novnc; do
    if [ -d "${candidate}" ] && [ -f "${candidate}/vnc.html" ]; then
      novnc_dir="${candidate}"
      echo "  Found noVNC: ${novnc_dir}"
      break
    fi
  done


  # Start websockify
  local websockify_pid=""
  if [ -n "${novnc_dir:-}" ]; then
    (
      "${websockify_path}" --web "${novnc_dir}" "${WEB_PORT}" "localhost:${VNC_PORT}" 2>&1 | \
        grep -v "WARNING" | grep -v "numpy" || true
    ) &
  else
    echo "  ⚠ noVNC files not found, starting websockify without web interface"
    (
      "${websockify_path}" "${WEB_PORT}" "localhost:${VNC_PORT}" 2>&1 | \
        grep -v "WARNING" | grep -v "numpy" || true
    ) &
  fi


  websockify_pid=$!
  sleep 2

  if ! kill -0 "${websockify_pid}" 2>/dev/null; then
    echo "  ✗ websockify failed to start"
    return 1
  fi

  WEBSOCKIFY_PID="${websockify_pid}"
  echo "✓ noVNC running on port ${WEB_PORT} (PID: ${websockify_pid})"
  return 0
}

#--- Sub-block 33.6: Section 4624 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# --- Display connection information ---
display_connection_info() {
  local node=""
  local username=""
  local primary_ip=""
  local login_placeholder=""

  node=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
  username="${USER:-$(whoami)}"
  primary_ip="$(
    hostname -I 2>/dev/null \
      | tr ' ' '\n' \
      | grep -v '^127\.' \
      | head -1 \
      || true
  )"
  primary_ip=${primary_ip:-localhost}
  login_placeholder="\${USER:-${username}}"

  echo ""
  echo "=========================================="
  echo "✓ VNC Server Ready!"
  echo "=========================================="
  echo "Hostname: ${node}"
  echo "Display: :${VNC_DISPLAY_NUM}"
  echo "VirtualGL: $([ "${VNC_VGL_INTEGRATION:-1}" = "1" ] && echo "Enabled (VGL_DISPLAY=${VGL_DISPLAY:-:1})" || echo "Disabled")"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "CONNECTION METHOD 1: Native VNC Viewer (Recommended)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
  echo ""
  echo "Auto-Detected Information:"
  echo "  Username: ${username}"
  echo "  Compute Node: ${node}"
  echo "  Node IP: ${primary_ip}"
  echo ""
  echo "Stage 1 - Tunnel to Login Node (Run on your local machine):"
  echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} -L ${WEB_PORT}:localhost:${WEB_PORT} -p 22 ${login_placeholder}@107.122.148.226"
  echo ""
  echo "Stage 2 - From Login Node to Compute Node (Run on login node):"
  echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} -L ${WEB_PORT}:localhost:${WEB_PORT} ${login_placeholder}@${node}"
  echo ""
  echo "Alternative Stage 2 (with IP):"
  echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} -L ${WEB_PORT}:localhost:${WEB_PORT} ${login_placeholder}@${primary_ip}"
  echo ""
  echo "Direct Two-Stage Tunnel (Single Command):"
  echo "   ssh -J ${login_placeholder}@107.122.148.226:22 -L ${VNC_PORT}:localhost:${VNC_PORT} -L ${WEB_PORT}:localhost:${WEB_PORT} ${login_placeholder}@${node}"
  echo ""
  echo "Connect VNC viewer to: localhost:${VNC_PORT}"
  echo "   (or localhost:${VNC_DISPLAY_NUM})"
  echo ""

  if ss -tuln 2>/dev/null | grep -q ":${WEB_PORT}\b"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CONNECTION METHOD 2: Web Browser (noVNC)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
    echo ""
    echo "Auto-Detected Information:"
    echo "  Username: ${username}"
    echo "  Compute Node: ${node}"
    echo "  Node IP: ${primary_ip}"
    echo ""
    echo "Stage 1 - Tunnel to Login Node (Run on your local machine):"
    echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} -p 22 ${login_placeholder}@107.122.148.226"
    echo ""
    echo "Stage 2 - From Login Node to Compute Node (Run on login node):"
    echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} ${login_placeholder}@${node}"
    echo ""
    echo "Alternative Stage 2 (with IP):"
    echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} ${login_placeholder}@${primary_ip}"
    echo ""
    echo "Direct Two-Stage Tunnel (Single Command):"
    echo "   ssh -J ${login_placeholder}@107.122.148.226:22 -L ${WEB_PORT}:localhost:${WEB_PORT} ${login_placeholder}@${node}"
    echo ""
    echo "Open browser to: http://localhost:${WEB_PORT}"
    echo ""
  fi


  if ss -tuln 2>/dev/null | grep -q ":${TURBOVNC_WEB_PORT}\b"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CONNECTION METHOD 3: TurboVNC Java Applet"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
    echo ""
    echo "Stage 1 - Tunnel to Login Node:"
    echo "   ssh -L ${TURBOVNC_WEB_PORT}:localhost:${TURBOVNC_WEB_PORT} \${USER}@login.hpc.edu"
    echo ""
    echo "Stage 2 - From Login Node to Compute Node:"
    echo "   ssh -L ${TURBOVNC_WEB_PORT}:localhost:${TURBOVNC_WEB_PORT} ${login_placeholder}@${node}"
    echo ""
    echo "Alternative - Direct Two-Stage Tunnel:"
    echo "   ssh -J ${login_placeholder}@login.hpc.edu -L ${TURBOVNC_WEB_PORT}:localhost:${TURBOVNC_WEB_PORT} ${login_placeholder}@${node}"
    echo ""
    echo "Open browser to: http://localhost:${TURBOVNC_WEB_PORT}"
    echo "   (Requires Java plugin - not recommended for modern browsers)"
    echo ""
  fi


#--- Code section 4438 ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block 33.7: Section 4674 ---
# Purpose: Continued implementation
# Purpose: Continuing implementation
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "USEFUL COMMANDS:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "View VNC logs:"
  echo "  tail -f \${HOME}/.vnc/*.log"
  echo ""
  echo "List running VNC servers:"
  echo "  vncserver -list"
  echo ""
  echo "Kill this VNC server:"
  echo "  vncserver -kill :${VNC_DISPLAY_NUM}"
  echo ""
  echo "Change VNC password:"
  echo "  vncpasswd"
  echo ""
  
  # Add VirtualGL usage instructions
  if [ "${VNC_VGL_INTEGRATION:-1}" = "1" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VIRTUALGL USAGE:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "To run GPU-accelerated applications:"
    echo "  vglrun glxspheres64          # Test OpenGL rendering"
    echo "  vglrun firefox               # GPU-accelerated Firefox"
    echo "  vglrun glxgears              # Test OpenGL performance"
    echo ""
    echo "Debug VirtualGL:"
    echo "  test_virtualgl.sh            # Comprehensive test"
    echo "  vglrun -d :1 glxinfo         # Check OpenGL info"
    echo "  vglrun -d :1 glxspheres64    # Test with specific display"
    echo ""
    echo "VirtualGL Configuration:"
    echo "  VGL_DISPLAY: ${VGL_DISPLAY:-:1}"
    echo "  VGL_COMPRESS: ${VGL_COMPRESS:-proxy}"
    echo "  VGL_READBACK: ${VGL_READBACK:-sync}"
    echo ""
  fi
  
  echo "=========================================="
  echo ""
  echo "Press Ctrl+C to stop all VNC services"
  echo ""
}

# --- Monitor services ---
monitor_services() {
  local check_count=0

  # Continuously verify that VNC and websockify remain healthy, restarting websockify if needed.
  while true; do
    sleep 30
    check_count=$((check_count + 1))

    # Check VNC server every loop
    if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
      echo "ERROR: VNC server died unexpectedly"
      exit 1
    fi

    # Check websockify every 3rd loop (90 seconds)
    if [ $((check_count % 3)) -eq 0 ]; then
      if [ -n "${WEBSOCKIFY_PID:-}" ]; then
        if ! kill -0 "${WEBSOCKIFY_PID}" 2>/dev/null; then
          echo "WARNING: websockify died, restarting..."
          start_novnc || echo "Failed to restart websockify"
        fi
      fi
    fi
  done
}



#--- Sub-block 33.8: Section 4724 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# ============================================================================
# Main Execution
# ============================================================================

echo "=========================================="
echo "TurboVNC + noVNC Launcher"
echo "=========================================="
echo ""

# Run setup steps
check_dependencies
check_virtualgl
setup_vnc_config
start_vnc_server

# Test VirtualGL after VNC is running
if [ "${VNC_VGL_INTEGRATION:-}" = "1" ]; then
  echo ""
  echo "Testing VirtualGL integration..."
  test_virtualgl || echo "⚠ VirtualGL test failed - check configuration"
fi

# Try to start web interfaces
check_turbovnc_webserver || true
start_novnc || echo "⚠ noVNC not available (VNC viewer still works)"

# Display connection info
display_connection_info

# Monitor and keep alive
monitor_services
