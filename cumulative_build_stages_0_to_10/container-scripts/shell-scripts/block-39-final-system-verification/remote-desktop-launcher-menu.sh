#!/usr/bin/env bash
# Unified Remote Desktop Launcher

set -euo pipefail

# Ensure helper scripts exist before invocation and surface failures.
invoke_helper() {
  local executable="${1:?executable name required}"
  shift

  if ! command -v "${executable}" >/dev/null 2>&1; then
    printf 'Required helper "%s" is not available in PATH.\n' "${executable}" >&2
    return 0
  fi

  if ! "${executable}" "$@"; then
    local rc=$?
    printf 'Helper "%s" exited with status %s.\n' "${executable}" "${rc}" >&2
  fi

  return 0
}

# Display the interactive menu of remote desktop options.
print_menu() {
  cat <<'EOF'

========================================
Remote Desktop Launcher
========================================

Available Options:

VNC SERVERS:
  1) TurboVNC (default, best for most uses)
  2) TurboVNC High Quality (fast network)
  3) TurboVNC Low Bandwidth (slow network)
  4) TigerVNC (alternative)
  5) x11vnc (attach to existing display)
  6) KasmVNC (modern web VNC)

APPLICATION STREAMING:
  7) Xpra (seamless windows)
  8) Sunshine (game streaming, ultra-low latency)

UTILITIES:
  9) List running sessions
 10) Kill all VNC servers
 11) Test VirtualGL
 12) GPU benchmark
 13) Record screen

 0) Exit

========================================
EOF
}

# Prompt the operator to press Enter before returning to the menu.
prompt_continue() {
  local _discard=""

  if ! read -r -p "Press Enter to continue..." _discard; then
    printf 'Input aborted; exiting.\n' >&2
    return 1
  fi

  return 0
}

handle_choice() {
  local selection="${1:-}"

  case "${selection}" in
    1) invoke_helper start_vnc_xfce.sh ;;
    2) invoke_helper start_vnc_ultrahq.sh ;;
    3) invoke_helper start_vnc_lowbw.sh ;;
    4) invoke_helper start_vnc_tigervnc.sh ;;
    5)
      local disp=""
      if ! read -r -p "Display number (default 1): " disp; then
        printf 'Input aborted; returning to menu.\n' >&2
        return 2
      fi
      invoke_helper start_x11vnc.sh "${disp:-1}"
      ;;
    6) invoke_helper start_kasmvnc.sh ;;
    7) invoke_helper start_xpra.sh ;;
    8) invoke_helper start_sunshine.sh ;;
    9)
      if command -v vncserver >/dev/null 2>&1; then
        vncserver -list 2>/dev/null || true
      else
        printf 'vncserver is not available in PATH.\n' >&2
      fi
      printf '\n'
      if command -v pgrep >/dev/null 2>&1; then
        pgrep -af 'vnc|xpra|sunshine' 2>/dev/null || true
      else
        # SC2009: Consider using pgrep instead
            ps aux 2>/dev/null | grep -E 'vnc|xpra|sunshine' | grep -v grep || true
      fi
      ;;
    10)
      if command -v vncserver >/dev/null 2>&1; then
        vncserver -kill :1 2>/dev/null || true
      fi
      if command -v pkill >/dev/null 2>&1; then
        pkill -f vnc || true
        pkill -f xpra || true
      else
        printf 'pkill not available; please terminate sessions manually if needed.\n' >&2
      fi
      printf 'All VNC-related servers requested to terminate.\n'
      ;;
    11) invoke_helper test_virtualgl.sh ;;
    12) invoke_helper vgl_benchmark.sh ;;
    13)
      local fname=""
      if ! read -r -p "Output filename (default: screen_recording.mp4): " fname; then
        printf 'Input aborted; returning to menu.\n' >&2
        return 2
      fi
      invoke_helper record_screen.sh 1 "${fname:-screen_recording.mp4}"
      ;;
    0)
      printf 'Exiting remote desktop launcher.\n'
      return 1
      ;;
    *)
      printf 'Invalid option.\n'
      return 2
      ;;
  esac

  return 0
}

main() {
  local choice=""

  while true; do
    print_menu

    if ! read -r -p "Select option: " choice; then
      printf 'Input aborted; exiting.\n' >&2
      return 0
    fi

    printf '\n'

    if handle_choice "${choice}"; then
      if ! prompt_continue; then
        break
      fi
    else
      local rc=$?

      case "${rc}" in
        1) break ;;
        2) continue ;;
        *) if ! prompt_continue; then break; fi ;;
      esac
    fi
  done

  return 0
}

# Check if running in container
if [ -f /.singularity.d/Singularity ]; then
  printf 'Running inside Singularity container\n'
else
  printf 'Warning: Should be run inside container\n'
fi

main "$@"
