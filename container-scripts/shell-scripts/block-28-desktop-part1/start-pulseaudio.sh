#!/usr/bin/env bash
set -euo pipefail

# Start PulseAudio for VNC session
if pulseaudio --check 2>/dev/null; then
    echo "PulseAudio already running"
else
    if pulseaudio --start --exit-idle-time=-1; then
        echo "✓ PulseAudio started"
    else
        echo "✗ Failed to start PulseAudio" >&2
        exit 1
    fi
fi
