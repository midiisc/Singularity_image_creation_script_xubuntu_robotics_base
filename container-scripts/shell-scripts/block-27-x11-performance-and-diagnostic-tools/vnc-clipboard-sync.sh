#!/usr/bin/env bash
# Synchronize clipboard between VNC and host

if [ -z "${DISPLAY:-}" ]; then
    echo "ERROR: DISPLAY not set"
    exit 1
fi

# Start autocutsel for clipboard sync
autocutsel -fork -selection CLIPBOARD
autocutsel -fork -selection PRIMARY

echo "✓ Clipboard sync started"
echo "  Copy/paste should work between VNC and local machine"
