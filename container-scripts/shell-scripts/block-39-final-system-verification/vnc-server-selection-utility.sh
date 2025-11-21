#!/usr/bin/env bash
# VNC Server Selection and Comparison Tool

set -euo pipefail

cat << 'INFO'
========================================
VNC Server Options
========================================

Available VNC servers in this container:

1. TurboVNC (Default - Recommended)
   - Best performance for GPU applications
   - Optimized JPEG compression
   - Built specifically for VirtualGL
   - Command: start_vnc_xfce.sh

2. TurboVNC Ultimate (Enhanced)
   - All TurboVNC features
   - Automatic optimization
   - Performance monitoring
   - Audio support
   - Command: start_vnc_ultimate.sh

3. TigerVNC (Alternative)
   - Good compatibility
   - Different compression algorithm
   - Some prefer the image quality
   - Command: start_vnc_tigervnc.sh

4. KasmVNC (Modern)
   - Modern web-first VNC
   - Built-in web interface
   - Container-optimized
   - Command: start_kasmvnc.sh


5. x11vnc (Screen Sharing)
   - Can attach to existing X session
   - Good for debugging
   - Command: start_x11vnc.sh



#--- Sub-block 39.2: Final cleanup ---
# Purpose: Post-installation cleanup
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
========================================
RECOMMENDATION
========================================


#--- Sub-block 39.3: Final cleanup operations ---
# Purpose: Post-installation cleanup tasks
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
For most users: start_vnc_ultimate.sh

This provides the best balance of:
- Performance (TurboVNC)
- GPU support (VirtualGL)
- Ease of use (noVNC web interface)
- Monitoring and diagnostics

========================================
PERFORMANCE COMPARISON
========================================

Benchmark your options:
  vgl_benchmark.sh       (VirtualGL performance)
  turbovnc_tune.sh       (TurboVNC settings)
  vnc_monitor.sh         (Real-time monitoring)

========================================
INFO

# If argument provided, start that server
if [ $# -gt 0 ]; then
  case "${1}" in
    turbovnc|1)
      exec start_vnc_xfce.sh
      ;;
    ultimate|2)
      exec start_vnc_ultimate.sh
      ;;
    tiger|3)
      exec start_vnc_tigervnc.sh
      ;;
    kasm|4)
      exec start_kasmvnc.sh
      ;;
    x11vnc|5)
      exec start_x11vnc.sh
      ;;
    *)
      echo "Unknown option: ${1}"
      exit 1
      ;;
  esac
fi
