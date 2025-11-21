#!/usr/bin/env bash
# Two-Stage SSL Tunneling for VNC Access in HPC Environments
# Usage: vnc_ssl_tunnel.sh [login_node] [compute_node] [vnc_port] [web_port]

set -euo pipefail

# Auto-detect system information
COMPUTE_NODE="${2:-$(hostname)}"
USER_NAME="${USER:-$(whoami)}"
NODE_IP="${NODE_IP:-$(hostname -I 2>/dev/null | awk '{print $1}' | head -1 || echo 'localhost')}"

# Configuration with auto-detection
LOGIN_NODE="${1:-107.122.148.226}"
LOGIN_PORT="${LOGIN_PORT:-22}"
VNC_PORT="${3:-5901}"
WEB_PORT="${4:-6081}"
# Calculate TurboVNC web port more robustly (remove assumption that port starts with 59)
VNC_DISPLAY_NUM_FROM_PORT=$((VNC_PORT - 5900))
TURBOVNC_WEB_PORT=$((5800 + VNC_DISPLAY_NUM_FROM_PORT))

# Try to detect compute node from SLURM environment
if [ -n "${SLURM_JOB_NODELIST:-}" ]; then
    # Extract first node from SLURM_JOB_NODELIST
    # D3: Use here-string instead of echo | cut (unsafe pipe pattern)
    COMPUTE_NODE=$(cut -d',' -f1 <<< "${SLURM_JOB_NODELIST}" | sed 's/\[.*\]//')
    echo "Detected compute node from SLURM: ${COMPUTE_NODE}"
elif [ -n "${SLURM_NODELIST:-}" ]; then
    # D3: Use here-string instead of echo | cut (unsafe pipe pattern)
    COMPUTE_NODE=$(cut -d',' -f1 <<< "${SLURM_NODELIST}" | sed 's/\[.*\]//')
    echo "Detected compute node from SLURM: ${COMPUTE_NODE}"
fi

# Try to detect node IP more accurately
if [ -n "${SLURM_NODEID:-}" ] && [ -n "${COMPUTE_NODE:-}" ]; then
    # If we have SLURM node ID, try to get IP from scontrol
    NODE_IP=$(scontrol show node "${COMPUTE_NODE}" 2>/dev/null | grep -oP 'NodeAddr=\K[^\s]+' | head -1 || echo "${NODE_IP}")
fi

# Fallback IP detection methods
if [ -z "${NODE_IP:-}" ] || [ "${NODE_IP}" = "127.0.0.1" ]; then
    # Try to get external IP
    NODE_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1 || echo "${NODE_IP:-localhost}")
fi

if [ -z "${NODE_IP:-}" ] || [ "${NODE_IP}" = "127.0.0.1" ]; then
    # Last resort - use hostname
    NODE_IP=$(hostname -I 2>/dev/null | awk '{print $1}' | grep -v '^127\.' | head -1 || echo "localhost")
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    printf '%b\n' "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    printf '%b\n' "${CYAN}║  Two-Stage SSL Tunneling for VNC Access (HPC Environment)     ║${NC}"
    printf '%b\n' "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_usage() {
    echo "Usage: $0 [login_node] [compute_node] [vnc_port] [web_port]"
    echo ""
    echo "Arguments:"
    echo "  login_node    - HPC login node IP/hostname (default: 107.122.148.226)"
    echo "  compute_node  - Compute node hostname (default: current hostname)"
    echo "  vnc_port      - VNC port number (default: 5901)"
    echo "  web_port      - Web/noVNC port number (default: 6081)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use defaults"
    echo "  $0 107.122.148.226 node001 5902      # Custom VNC port"
    echo "  $0 107.122.148.226 gpu-node-01 5901 6081  # All custom"
}

check_vnc_running() {
    local port="${1}"
    if ! ss -tuln 2>/dev/null | grep -q ":${port}\b"; then
        echo -e "${RED}Error: VNC server not running on port ${port}${NC}"
        echo "Start VNC first with: start_vnc_xfce.sh"
        return 1
    fi
    return 0
}

create_tunnel_scripts() {
    local login_node="${1}"
    local compute_node="${2}"
    local vnc_port="${3}"
    local web_port="${4}"
    # Calculate TurboVNC web port more robustly
    local vnc_display_num
    vnc_display_num=$((vnc_port - 5900))
    local turbovnc_web_port
    turbovnc_web_port=$((5800 + vnc_display_num))
    local user_name="${5}"
    local node_ip="${6}"
    # Get login_port from outer scope (defined in main script)
    local login_port="${LOGIN_PORT:-22}"
    
    # Create Stage 1 script (local machine to login node)
    cat > /tmp/vnc_tunnel_stage1.sh << EOF
#!/bin/bash
# Stage 1: Tunnel from local machine to login node
echo "Stage 1: Creating tunnel to login node..."
echo "Command: ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} -p ${login_port} ${user_name}@${login_node}"
echo ""
echo "After connecting, run Stage 2 script on the login node."
echo "Press Ctrl+C to stop this tunnel."
echo ""

ssh -L "${vnc_port}:localhost:${vnc_port}" \\
    -L "${web_port}:localhost:${web_port}" \\
    -L "${turbovnc_web_port}:localhost:${turbovnc_web_port}" \\
    -p "${login_port}" \\
    "${user_name}@${login_node}"
EOF

    # Create Stage 2 script (login node to compute node)
    cat > /tmp/vnc_tunnel_stage2.sh << EOF
#!/bin/bash
# Stage 2: Tunnel from login node to compute node
echo "Stage 2: Creating tunnel to compute node..."
echo "Command: ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${compute_node}"
echo ""
echo "Alternative with IP: ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${node_ip}"
echo ""
echo "After connecting, VNC will be available on localhost:${vnc_port}"
echo "Press Ctrl+C to stop this tunnel."
echo ""

# Try hostname first, fallback to IP if needed
ssh -L "${vnc_port}:localhost:${vnc_port}" \\
    -L "${web_port}:localhost:${web_port}" \\
    -L "${turbovnc_web_port}:localhost:${turbovnc_web_port}" \\
    "${user_name}@${compute_node}" || \\
ssh -L "${vnc_port}:localhost:${vnc_port}" \\
    -L "${web_port}:localhost:${web_port}" \\
    -L "${turbovnc_web_port}:localhost:${turbovnc_web_port}" \\
    "${user_name}@${node_ip}"
EOF

    # Create combined script (direct two-stage tunnel)
    cat > /tmp/vnc_tunnel_direct.sh << EOF
#!/bin/bash
# Direct two-stage tunnel using SSH jump host
echo "Direct Two-Stage Tunnel: Local -> Login -> Compute"
echo "Command: ssh -J ${user_name}@${login_node}:${login_port} -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${compute_node}"
echo ""
echo "Alternative with IP: ssh -J ${user_name}@${login_node}:${login_port} -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${node_ip}"
echo ""
echo "VNC will be available on localhost:${vnc_port}"
echo "Web interface: http://localhost:${web_port}"
echo "Press Ctrl+C to stop this tunnel."
echo ""

# Try hostname first, fallback to IP if needed
ssh -J "${user_name}@${login_node}:${login_port}" \\
    -L "${vnc_port}:localhost:${vnc_port}" \\
    -L "${web_port}:localhost:${web_port}" \\
    -L "${turbovnc_web_port}:localhost:${turbovnc_web_port}" \\
    "${user_name}@${compute_node}" || \\
ssh -J "${user_name}@${login_node}:${login_port}" \\
    -L "${vnc_port}:localhost:${vnc_port}" \\
    -L "${web_port}:localhost:${web_port}" \\
    -L "${turbovnc_web_port}:localhost:${turbovnc_web_port}" \\
    "${user_name}@${node_ip}"
EOF

    chmod +x /tmp/vnc_tunnel_*.sh
}

show_connection_info() {
    local vnc_port="${1}"
    local web_port="${2}"
    # Calculate TurboVNC web port more robustly
    local vnc_display_num
    vnc_display_num=$((vnc_port - 5900))
    local turbovnc_web_port
    turbovnc_web_port=$((5800 + vnc_display_num))
    local user_name="${3}"
    local compute_node="${4}"
    local node_ip="${5}"
    local login_node="${6}"
    # Get login_port from outer scope
    local login_port="${LOGIN_PORT:-22}"
    
    printf '%b\n' "${GREEN}✓ SSL Tunneling Scripts Created${NC}"
    echo ""
    printf '%b\n' "${BLUE}Auto-Detected Information:${NC}"
    echo "  Username: ${user_name}"
    echo "  Compute Node: ${compute_node}"
    echo "  Node IP: ${node_ip}"
    echo "  Login Node: ${login_node}"
    echo ""
    printf '%b\n' "${BLUE}Port Information:${NC}"
    echo "  VNC Port: ${vnc_port}"
    echo "  Web Port: ${web_port}"
    echo "  TurboVNC Web Port: ${turbovnc_web_port}"
    echo ""
    printf '%b\n' "${YELLOW}Ready-to-Copy SSH Commands:${NC}"
    echo ""
    printf '%b\n' "${CYAN}Stage 1 (Run on your local machine):${NC}"
    echo "ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} -p ${login_port} ${user_name}@${login_node}"
    echo ""
    printf '%b\n' "${CYAN}Stage 2 (Run on login node):${NC}"
    echo "ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${compute_node}"
    echo ""
    printf '%b\n' "${CYAN}Alternative Stage 2 (with IP):${NC}"
    echo "ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${node_ip}"
    echo ""
    printf '%b\n' "${CYAN}Direct Two-Stage Tunnel (Single Command):${NC}"
    echo "ssh -J ${user_name}@${login_node}:${login_port} -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${compute_node}"
    echo ""
    printf '%b\n' "${CYAN}Alternative Direct Tunnel (with IP):${NC}"
    echo "ssh -J ${user_name}@${login_node}:${login_port} -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${node_ip}"
    echo ""
    printf '%b\n' "${YELLOW}Available Scripts:${NC}"
    echo "  /tmp/vnc_tunnel_stage1.sh  - Stage 1 (Local -> Login Node)"
    echo "  /tmp/vnc_tunnel_stage2.sh  - Stage 2 (Login -> Compute Node)"
    echo "  /tmp/vnc_tunnel_direct.sh  - Direct Two-Stage Tunnel"
    echo ""
    printf '%b\n' "${GREEN}Connection URLs:${NC}"
    echo "  VNC Viewer: localhost:${vnc_port}"
    echo "  Web Browser: http://localhost:${web_port}"
    echo "  TurboVNC Web: http://localhost:${turbovnc_web_port}"
}

# Main execution
main() {
    print_header
    
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    printf '%b\n' "${BLUE}Configuration:${NC}"
    echo "  Login Node: ${LOGIN_NODE}"
    echo "  Compute Node: ${COMPUTE_NODE}"
    echo "  Username: ${USER_NAME}"
    echo "  Node IP: ${NODE_IP}"
    echo "  VNC Port: ${VNC_PORT}"
    echo "  Web Port: ${WEB_PORT}"
    echo ""
    
    # Check if VNC is running
    if ! check_vnc_running "${VNC_PORT}"; then
        exit 1
    fi
    
    # Create tunnel scripts
    create_tunnel_scripts "${LOGIN_NODE}" "${COMPUTE_NODE}" "${VNC_PORT}" "${WEB_PORT}" "${USER_NAME}" "${NODE_IP}"
    
    # Show connection info
    show_connection_info "${VNC_PORT}" "${WEB_PORT}" "${USER_NAME}" "${COMPUTE_NODE}" "${NODE_IP}" "${LOGIN_NODE}"
}

main "$@"
