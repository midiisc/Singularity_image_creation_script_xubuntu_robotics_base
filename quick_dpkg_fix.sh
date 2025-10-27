#!/bin/bash
#===============================================================================
# QUICK DPKG STATUS FIX
#===============================================================================
# Purpose: Quick fix for the specific OpenCV dpkg error
# Usage: Run this script to immediately fix the issue
#===============================================================================

echo "Quick fix for dpkg status corruption..."

# Create backup
cp /var/lib/dpkg/status /var/lib/dpkg/status.backup.$(date +%s)

# Remove all OpenCV package entries that are causing conflicts
echo "Removing conflicting OpenCV package entries..."
sed -i '/^Package: libopencv-dev$/,/^$/d' /var/lib/dpkg/status
sed -i '/^Package: libopencv-core-dev$/,/^$/d' /var/lib/dpkg/status
sed -i '/^Package: libopencv-imgproc-dev$/,/^$/d' /var/lib/dpkg/status
sed -i '/^Package: libopencv-highgui-dev$/,/^$/d' /var/lib/dpkg/status
sed -i '/^Package: libopencv-contrib-dev$/,/^$/d' /var/lib/dpkg/status

# Test the fix
echo "Testing dpkg status file..."
if dpkg --audit 2>/dev/null; then
    echo "✓ Dpkg status file is now clean"
    echo "✓ You can continue with your build"
else
    echo "✗ Still has issues - run the comprehensive fix: ./dpkg_status_fix.sh"
fi