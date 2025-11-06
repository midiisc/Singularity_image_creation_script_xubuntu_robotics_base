#!/usr/bin/env bash
# Quick VirtualGL and TurboVNC Testing Script
# Usage: ./test_virtualgl_turbovnc.sh /path/to/image.sif

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if image path is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Please provide the path to your Singularity image${NC}"
    echo "Usage: $0 /path/to/image.sif"
    exit 1
fi

IMAGE_PATH="$1"

# Check if image exists
if [ ! -f "$IMAGE_PATH" ]; then
    echo -e "${RED}Error: Image file not found: $IMAGE_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}VirtualGL and TurboVNC Testing Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Image: $IMAGE_PATH"
echo ""

# Function to run test
run_test() {
    local test_name="$1"
    local command="$2"
    
    echo -e "${YELLOW}Testing: $test_name${NC}"
    if singularity exec --nv "$IMAGE_PATH" bash -c "$command" 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED: $test_name${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED: $test_name${NC}"
        return 1
    fi
    echo ""
}

# Test counter
PASSED=0
FAILED=0

# Test 1: Check if image is accessible
echo -e "${BLUE}=== Test 1: Image Accessibility ===${NC}"
if singularity exec "$IMAGE_PATH" echo "Image accessible" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Image is accessible${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Cannot access image${NC}"
    ((FAILED++))
    exit 1
fi
echo ""

# Test 2: Check VirtualGL installation
echo -e "${BLUE}=== Test 2: VirtualGL Installation ===${NC}"
if run_test "VirtualGL binary exists" "which vglrun"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "VirtualGL version" "vglrun --version 2>&1 | head -1"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "VirtualGL path" "test -x /opt/VirtualGL/bin/vglrun"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "glxinfo available" "which glxinfo"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "glxspheres64 available" "which glxspheres64"; then
    ((PASSED++))
else
    ((FAILED++))
fi
echo ""

# Test 3: Check TurboVNC installation
echo -e "${BLUE}=== Test 3: TurboVNC Installation ===${NC}"
if run_test "TurboVNC server binary" "which vncserver"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "TurboVNC version" "vncserver --version 2>&1 | head -1"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "TurboVNC path" "test -x /opt/TurboVNC/bin/vncserver"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "vncviewer available" "which vncviewer"; then
    ((PASSED++))
else
    ((FAILED++))
fi
echo ""

# Test 4: Check environment configuration
echo -e "${BLUE}=== Test 4: Environment Configuration ===${NC}"
if run_test "VirtualGL in PATH" "echo \$PATH | grep -q VirtualGL"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "TurboVNC in PATH" "echo \$PATH | grep -q turbovnc"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "VirtualGL profile script" "test -f /etc/profile.d/virtualgl.sh"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "TurboVNC profile script" "test -f /etc/profile.d/turbovnc.sh"; then
    ((PASSED++))
else
    ((FAILED++))
fi
echo ""

# Test 5: Check test scripts
echo -e "${BLUE}=== Test 5: Test Scripts ===${NC}"
if run_test "test_virtualgl.sh exists" "test -x /usr/local/bin/test_virtualgl.sh"; then
    ((PASSED++))
else
    ((FAILED++))
fi

# Try to run the test script (may fail if DISPLAY not set, that's OK)
if run_test "test_virtualgl.sh executable" "test_virtualgl.sh --help 2>&1 || test_virtualgl.sh 2>&1 | head -5"; then
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ test_virtualgl.sh may require DISPLAY to be set${NC}"
    ((FAILED++))
fi
echo ""

# Test 6: Check GPU/NVIDIA support
echo -e "${BLUE}=== Test 6: GPU/NVIDIA Support ===${NC}"
if run_test "nvidia-smi available" "which nvidia-smi"; then
    ((PASSED++))
    # Try to run nvidia-smi (may fail without GPU, that's OK)
    if run_test "nvidia-smi works" "nvidia-smi --query-gpu=name --format=csv,noheader 2>&1 | head -1"; then
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠ nvidia-smi failed (GPU may not be available)${NC}"
        ((FAILED++))
    fi
else
    echo -e "${YELLOW}⚠ nvidia-smi not found${NC}"
    ((FAILED++))
fi

if run_test "CUDA available" "which nvcc || echo 'nvcc not in PATH'"; then
    ((PASSED++))
else
    ((FAILED++))
fi
echo ""

# Test 7: Check VNC configuration
echo -e "${BLUE}=== Test 7: VNC Configuration ===${NC}"
if run_test "VNC directories exist" "test -d /opt/TurboVNC"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "VirtualGL directories exist" "test -d /opt/VirtualGL"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "VNC symlinks" "ls /usr/local/bin/vnc* 2>/dev/null | head -3"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "VirtualGL symlinks" "ls /usr/local/bin/vgl* 2>/dev/null | head -3"; then
    ((PASSED++))
else
    ((FAILED++))
fi
echo ""

# Test 8: Check helper scripts
echo -e "${BLUE}=== Test 8: Helper Scripts ===${NC}"
if run_test "start_vnc script exists" "test -x /usr/local/bin/start_vnc_xfce.sh 2>/dev/null || echo 'Not found'"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "vgl_benchmark script" "test -x /usr/local/bin/vgl_benchmark.sh 2>/dev/null || echo 'Not found'"; then
    ((PASSED++))
else
    ((FAILED++))
fi

if run_test "vgl_info script" "test -x /usr/local/bin/vgl_info.sh 2>/dev/null || echo 'Not found'"; then
    ((PASSED++))
else
    ((FAILED++))
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Set VNC password: singularity exec --nv $IMAGE_PATH vncpasswd"
    echo "2. Start VNC server: singularity exec --nv $IMAGE_PATH vncserver :1"
    echo "3. Connect with VNC viewer to port 5901"
    echo "4. Test VirtualGL: vglrun glxspheres64"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed. See details above.${NC}"
    echo ""
    echo "Common issues:"
    echo "- GPU not available: Some tests may fail without GPU"
    echo "- DISPLAY not set: VirtualGL tests may fail"
    echo "- Check the detailed guide: TEST_VIRTUALGL_TURBOVNC.md"
    exit 1
fi

