# VirtualGL environment configuration
# Official documentation: https://rawcdn.githack.com/VirtualGL/virtualgl/3.1.4/doc/index.html

# VirtualGL runtime environment (with dynamic display detection)
# VGL_DISPLAY will be set dynamically by VNC launcher scripts
export VGL_COMPRESS="${VGL_COMPRESS:-proxy}"       # Compression method (proxy, jpeg, rgb)
export VGL_READBACK="${VGL_READBACK:-sync}"        # Readback mode (sync recommended for VNC)
export VGL_LOGO="${VGL_LOGO:-0}"                   # Disable VirtualGL logo overlay
export VGL_FPS="${VGL_FPS:-0}"                     # Disable FPS display (set to 1 to enable)
export VGL_VERBOSE="${VGL_VERBOSE:-0}"             # Verbose output (set to 1 to enable)

# Optimize for VNC environments
export VGL_SYNC="${VGL_SYNC:-1}"                   # Synchronize with vertical retrace
export VGL_REFRESHRATE="${VGL_REFRESHRATE:-60}"    # Target refresh rate for VNC

# Debug and development settings
export VGL_DEBUG="${VGL_DEBUG:-0}"                 # Debug mode (set to 1 to enable)
export VGL_LOG_LEVEL="${VGL_LOG_LEVEL:-1}"         # Log level (0-3)
export VGL_FORCE_GPU="${VGL_FORCE_GPU:-0}"         # Force GPU usage (set to 1 to enable)

# Auto-detect VNC display if not set
if [ -z "${VGL_DISPLAY:-}" ]; then
  # Try to detect VNC display from running processes
  vnc_display=""
  
  # Method 1: Check for Xvnc processes using pgrep
  if command -v pgrep >/dev/null 2>&1; then
    vnc_cmd=$(pgrep -af "Xvnc" 2>/dev/null | head -1)
    if [ -n "${vnc_cmd}" ]; then
      vnc_display=$(grep -oE ':[0-9]+' <<< "${vnc_cmd}" | head -1)
    fi
  else
    vnc_display=$(ps aux 2>/dev/null | grep -oE 'Xvnc.*:[0-9]+' | head -1 | grep -oE ':[0-9]+' | head -1)
  fi
  
  # Method 2: Check for vncserver processes
  if [ -z "${vnc_display}" ]; then
    if command -v pgrep >/dev/null 2>&1; then
      vnc_cmd=$(pgrep -af "vncserver" 2>/dev/null | head -1)
      if [ -n "${vnc_cmd}" ]; then
        vnc_display=$(grep -oE ':[0-9]+' <<< "${vnc_cmd}" | head -1)
      fi
    else
      vnc_display=$(ps aux 2>/dev/null | grep -oE 'vncserver.*:[0-9]+' | head -1 | grep -oE ':[0-9]+' | head -1)
    fi
  fi
  
  # Method 3: Check for display :1, :2, etc.
  if [ -z "${vnc_display}" ]; then
    for i in 1 2 3 4 5; do
      if [ -S "/tmp/.X11-unix/X${i}" ]; then
        vnc_display=":${i}"
        break
      fi
    done
  fi
  
  # Set VGL_DISPLAY
  if [ -n "${vnc_display}" ]; then
    export VGL_DISPLAY="${vnc_display}"
  else
    export VGL_DISPLAY=":0"  # Fallback
  fi
fi

# VirtualGL integration settings
export VNC_VGL_INTEGRATION="${VNC_VGL_INTEGRATION:-1}"     # Enable VNC-VGL integration
export VNC_OPENGL_EXTENSIONS="${VNC_OPENGL_EXTENSIONS:-1}" # Enable OpenGL extensions
export VNC_GLX_EXTENSIONS="${VNC_GLX_EXTENSIONS:-1}"       # Enable GLX extensions
