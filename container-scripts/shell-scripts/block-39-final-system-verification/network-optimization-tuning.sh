#!/usr/bin/env bash
# Optimize network for remote desktop (run on host/container with permissions)

set -euo pipefail

echo "Optimizing TCP for remote desktop..."

# These would need to run on host or with capabilities
# Include as documentation

cat << 'EOF'
# Add these to host system /etc/sysctl.conf for better performance:

# Increase TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Increase max backlog
net.core.netdev_max_backlog = 5000

# Enable BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

Then run: sudo sysctl -p
EOF


echo ""
echo "Note: These optimizations require host-level changes"
