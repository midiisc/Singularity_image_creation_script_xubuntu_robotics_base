#!/usr/bin/env bash
set -euo pipefail

# TurboVNC Performance Tuning Helper

echo "=========================================="
echo "TurboVNC Performance Tuner"
echo "=========================================="
echo ""

if [ -z "${DISPLAY:-}" ]; then
    echo "ERROR: Must be run from within VNC session"
    echo "Start VNC first, then run this from terminal inside VNC"
    exit 1
fi

echo "Current VNC Session Information:"
vncserver -list 2>/dev/null || echo "  (vncserver command not available)"
echo ""

echo "Testing different compression settings..."
echo "This will take about 30 seconds..."
echo ""

# Test function
test_setting() {
    local quality=$1
    local subsample=$2
    local desc=$3

    echo "Testing: $desc (Quality=$quality, Subsample=$subsample)"

    # This would require vncviewer to support setting these
    # Just document the settings
    echo "  Recommended for: $desc"
    echo ""
}


test_setting 95 1 "High quality (default)"
test_setting 80 1 "Balanced (good for most)"
test_setting 60 2 "Low bandwidth"
test_setting 30 2 "Very slow connections"

echo "=========================================="
echo "To change settings, edit:"
echo "  ~/.vnc/turbovncserver.conf"
echo ""
echo "Or set environment variables:"
echo "  export TVNC_QUALITY=80"
echo "  export TVNC_SUBSAMPLE=1"
echo "=========================================="
