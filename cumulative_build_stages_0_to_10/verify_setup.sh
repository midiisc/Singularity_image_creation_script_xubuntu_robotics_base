#!/bin/bash
#===============================================================================
# VERIFY SETUP SCRIPT
#===============================================================================
# Purpose: Verify all required files and dependencies are present
# Usage: ./verify_setup.sh
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ROOT="${SCRIPT_DIR}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "VERIFYING CUMULATIVE BUILD SETUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ERRORS=0

# Check container runtime
echo "1. Container Runtime:"
if command -v apptainer >/dev/null 2>&1; then
    echo "   ✓ apptainer found: $(apptainer --version | head -1)"
elif command -v singularity >/dev/null 2>&1; then
    echo "   ✓ singularity found: $(singularity --version | head -1)"
else
    echo "   ✗ Neither apptainer nor singularity found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check fakeroot
echo "2. fakeroot:"
if command -v fakeroot >/dev/null 2>&1; then
    echo "   ✓ fakeroot found: $(fakeroot --version | head -1)"
else
    echo "   ⚠ fakeroot not found (will use sudo if needed)"
fi
echo ""

# Check config.sh
echo "3. Configuration:"
if [ -f "${BUILD_ROOT}/config.sh" ]; then
    echo "   ✓ config.sh found"
else
    echo "   ✗ config.sh not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check stages directory
echo "4. Stage Definition Files:"
if [ -d "${BUILD_ROOT}/stages" ]; then
    STAGE_COUNT=$(ls "${BUILD_ROOT}/stages"/stage_*.def 2>/dev/null | wc -l)
    if [ "${STAGE_COUNT}" -ge 11 ]; then
        echo "   ✓ stages directory found with ${STAGE_COUNT} definition files"
        for stage_num in $(seq 0 10); do
            if ls "${BUILD_ROOT}/stages"/stage_$(printf "%02d" ${stage_num})_*.def 1>/dev/null 2>&1; then
                echo "     ✓ Stage ${stage_num} definition file found"
            else
                echo "     ✗ Stage ${stage_num} definition file missing"
                ERRORS=$((ERRORS + 1))
            fi
        done
    else
        echo "   ✗ Only ${STAGE_COUNT} definition files found (expected 11)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ✗ stages directory not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check container-scripts
echo "5. Container Scripts:"
if [ -d "${BUILD_ROOT}/container-scripts" ]; then
    SCRIPT_COUNT=$(find "${BUILD_ROOT}/container-scripts" -name "*.sh" 2>/dev/null | wc -l)
    echo "   ✓ container-scripts directory found with ${SCRIPT_COUNT} shell scripts"
    
    # Check for critical scripts
    CRITICAL_SCRIPTS=(
        "container-scripts/install.sh"
        "container-scripts/shell-scripts/block-12a-mkl-installation.sh"
    )
    for script in "${CRITICAL_SCRIPTS[@]}"; do
        if [ -f "${BUILD_ROOT}/${script}" ]; then
            echo "     ✓ ${script} found"
        else
            echo "     ⚠ ${script} not found (may be optional)"
        fi
    done
else
    echo "   ✗ container-scripts directory not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check scripts directory
echo "6. Helper Scripts:"
if [ -d "${BUILD_ROOT}/scripts" ]; then
    HELPER_COUNT=$(find "${BUILD_ROOT}/scripts" -name "*.sh" 2>/dev/null | wc -l)
    echo "   ✓ scripts directory found with ${HELPER_COUNT} helper scripts"
    
    # Check for critical helper scripts
    CRITICAL_HELPERS=(
        "scripts/common_functions.sh"
        "scripts/mirror_functions.sh"
        "scripts/library_functions.sh"
        "scripts/cache_functions.sh"
        "scripts/package_functions.sh"
    )
    for helper in "${CRITICAL_HELPERS[@]}"; do
        if [ -f "${BUILD_ROOT}/${helper}" ]; then
            echo "     ✓ ${helper} found"
        else
            echo "     ✗ ${helper} not found"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    echo "   ✗ scripts directory not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check build script
echo "7. Build Script:"
if [ -f "${BUILD_ROOT}/build_cumulative_stages_0_to_10.sh" ]; then
    if [ -x "${BUILD_ROOT}/build_cumulative_stages_0_to_10.sh" ]; then
        echo "   ✓ build_cumulative_stages_0_to_10.sh found and executable"
    else
        echo "   ⚠ build_cumulative_stages_0_to_10.sh found but not executable"
        echo "     Run: chmod +x build_cumulative_stages_0_to_10.sh"
    fi
else
    echo "   ✗ build_cumulative_stages_0_to_10.sh not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check disk space
echo "8. Disk Space:"
AVAILABLE_SPACE=$(df -BG "${BUILD_ROOT}" | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "${AVAILABLE_SPACE}" -ge 20 ]; then
    echo "   ✓ Sufficient disk space: ${AVAILABLE_SPACE} GB available"
elif [ "${AVAILABLE_SPACE}" -ge 10 ]; then
    echo "   ⚠ Limited disk space: ${AVAILABLE_SPACE} GB available (recommend 20+ GB)"
else
    echo "   ✗ Insufficient disk space: ${AVAILABLE_SPACE} GB available (need 20+ GB)"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${ERRORS} -eq 0 ]; then
    echo "✓ SETUP VERIFICATION PASSED"
    echo "  All required files and dependencies are present"
    echo "  Ready to build stages 0-10"
    echo ""
    echo "Next step: ./build_cumulative_stages_0_to_10.sh"
    exit 0
else
    echo "✗ SETUP VERIFICATION FAILED"
    echo "  ${ERRORS} error(s) found"
    echo "  Please fix the issues above before building"
    exit 1
fi

