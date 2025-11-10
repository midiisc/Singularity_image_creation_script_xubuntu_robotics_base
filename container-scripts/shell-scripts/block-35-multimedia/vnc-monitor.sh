#!/usr/bin/env bash
# Monitor VNC session performance

set -euo pipefail

echo "=========================================="
echo "VNC Session Performance Monitor"
echo "=========================================="
echo ""

echo "1. VNC Processes:"
# Use pgrep instead of ps aux | grep for better reliability
if command -v pgrep >/dev/null 2>&1; then
    pgrep -af "Xvnc|websockify|xfce" 2>/dev/null || echo "  No matching processes found"
else
    # Fallback to ps if pgrep not available
    ps aux 2>/dev/null | grep -E "Xvnc|websockify|xfce" | grep -v grep || echo "  No matching processes found"
fi
echo ""

echo "2. Network Connections:"
if command -v ss >/dev/null 2>&1; then
    if ! ss -tuln | grep -E "5901|6081|5800"; then
        echo "  No matching connections found"
    fi
else
    echo "  Networking utility 'ss' not available"
fi
echo ""

echo "3. GPU Utilization:"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total \
      --format=csv,noheader,nounits
else
    echo "  nvidia-smi not available"
fi
echo ""

echo "4. CPU Usage (VNC related):"
# Use pgrep instead of ps aux | grep
if command -v pgrep >/dev/null 2>&1; then
    mapfile -t vnc_pids < <(pgrep -f "Xvnc|websockify" 2>/dev/null || true)
    if [ "${#vnc_pids[@]}" -gt 0 ]; then
        pid_list=$(printf '%s\n' "${vnc_pids[@]}" | paste -sd, -)
        if ps_output=$(ps -o pid=,pcpu= -p "${pid_list}" 2>/dev/null); then
            total_cpu=$(printf '%s\n' "${ps_output}" | awk '{sum+=$2} END {print sum}')
            echo "  Total CPU: ${total_cpu:-0}%"
        else
            echo "  Unable to calculate CPU usage"
        fi
    else
        echo "  No VNC processes found"
    fi
else
    # Fallback to ps if pgrep not available
    ps aux 2>/dev/null | grep -E "Xvnc|websockify" | grep -v grep | awk '{print $3}' | \
      awk '{sum+=$1} END {if (NR>0) print "  Total CPU: " sum "%"; else print "  No VNC processes found"}'
fi
echo ""

echo "5. Memory Usage:"
free -h
echo ""

echo "6. Display Information:"
if [ -n "${DISPLAY:-}" ]; then
    echo "  DISPLAY: ${DISPLAY}"
    if command -v xdpyinfo >/dev/null 2>&1; then
        xdpyinfo | grep -E "dimensions|resolution" | sed 's/^/  /'
    else
        echo "  xdpyinfo command not available"
    fi
else
    echo "  Not running in X session"
fi
echo "=========================================="
