#!/bin/bash
# Check Zenoh status

set -euo pipefail

echo "Zenoh Infrastructure Status:"
echo "----------------------------"
# Check router
if pgrep -f "zenohd" > /dev/null; then
  echo "✓ Zenoh Router: RUNNING"
  echo "  REST API: http://localhost:8000"
else
  echo "✗ Zenoh Router: STOPPED"
fi



# Check Humble bridge
if pgrep -f 'zenoh-bridge.*zenoh-bridge-humble\.json5' > /dev/null 2>&1; then
  echo "✓ Humble Bridge: RUNNING (Domain 1 -> /humble namespace)"
else
  echo "✗ Humble Bridge: STOPPED"
fi

# Check Jazzy bridge
if pgrep -f 'zenoh-bridge.*zenoh-bridge-jazzy\.json5' > /dev/null 2>&1; then
  echo "✓ Jazzy Bridge: RUNNING (Domain 2 -> /jazzy namespace)"
else
  echo "✗ Jazzy Bridge: STOPPED"
fi

echo "Logs:"
echo "  Router: /tmp/zenoh-router.log"
echo "  Humble: /tmp/zenoh-humble.log"
echo "  Jazzy: /tmp/zenoh-jazzy.log"
