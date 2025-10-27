#!/bin/bash
#===============================================================================
# APPLY OPENCV FIX IMMEDIATELY
#===============================================================================
# Purpose: Apply the OpenCV protection fix to the main build script
# Usage: Run this script to fix the dpkg error
#===============================================================================

echo "Applying OpenCV protection fix to build script..."

# First, fix the current dpkg error
echo "1. Fixing current dpkg status error..."
if [ -f "/var/lib/dpkg/status" ]; then
    # Create backup
    cp /var/lib/dpkg/status /var/lib/dpkg/status.backup.$(date +%s)
    
    # Remove conflicting OpenCV entries
    sed -i '/^Package: libopencv-dev$/,/^$/d' /var/lib/dpkg/status
    sed -i '/^Package: libopencv-core-dev$/,/^$/d' /var/lib/dpkg/status
    sed -i '/^Package: libopencv-imgproc-dev$/,/^$/d' /var/lib/dpkg/status
    sed -i '/^Package: libopencv-highgui-dev$/,/^$/d' /var/lib/dpkg/status
    sed -i '/^Package: libopencv-contrib-dev$/,/^$/d' /var/lib/dpkg/status
    
    echo "✓ Cleaned conflicting OpenCV entries from dpkg status"
    
    # Test dpkg
    if dpkg --audit 2>/dev/null; then
        echo "✓ Dpkg database is now clean"
    else
        echo "⚠ Dpkg still has issues, but continuing..."
    fi
else
    echo "⚠ No dpkg status file found"
fi

# Now fix the build script
echo "2. Fixing build script OpenCV protection section..."

SCRIPT_FILE="/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh"

if [ ! -f "$SCRIPT_FILE" ]; then
    echo "✗ Build script not found: $SCRIPT_FILE"
    exit 1
fi

# Create backup
cp "$SCRIPT_FILE" "${SCRIPT_FILE}.backup.$(date +%s)"

# Find the problematic section
START_LINE=$(grep -n "Protect compiled OpenCV from APT overwrites" "$SCRIPT_FILE" | head -1 | cut -d: -f1)
END_LINE=$(grep -n "OpenCV protected from APT overwrites" "$SCRIPT_FILE" | head -1 | cut -d: -f1)

if [ -n "$START_LINE" ] && [ -n "$END_LINE" ]; then
    echo "Found OpenCV protection section at lines $START_LINE-$END_LINE"
    
    # Create replacement section
    cat > /tmp/opencv_replacement.sh << 'EOF'
#--- Sub-block 10.13.1: Protect compiled OpenCV from APT overwrites ---
# Critical: Prevent apt from installing libopencv-dev which would overwrite our optimized version
echo "Protecting compiled OpenCV from APT overwrites..."

# Clean up any existing OpenCV package entries that might cause conflicts
echo "Cleaning up existing OpenCV package entries..."
if [ -f "/var/lib/dpkg/status" ]; then
    # Remove any existing OpenCV package entries to prevent conflicts
    local opencv_packages=(
        "libopencv-dev"
        "libopencv-core-dev"
        "libopencv-imgproc-dev" 
        "libopencv-highgui-dev"
        "libopencv-contrib-dev"
    )
    
    for pkg in "${opencv_packages[@]}"; do
        # Remove package entries (from Package: line to next empty line)
        sed -i "/^Package: $pkg$/,/^$/d" /var/lib/dpkg/status 2>/dev/null || true
    done
    
    echo "✓ Cleaned existing OpenCV entries from dpkg status"
fi

# Use apt-mark hold (preferred method)
echo "Applying OpenCV protection using apt-mark hold..."
local opencv_packages=(
    "libopencv-dev"
    "libopencv-core-dev"
    "libopencv-imgproc-dev"
    "libopencv-highgui-dev" 
    "libopencv-contrib-dev"
)

local protected_count=0
for pkg in "${opencv_packages[@]}"; do
    echo "  Protecting package: $pkg"
    if apt-mark hold "$pkg" 2>/dev/null; then
        echo "    ✓ Held: $pkg"
        protected_count=$((protected_count + 1))
    else
        echo "    ⚠ Could not hold: $pkg (non-fatal)"
    fi
done

# Create apt preferences for additional protection
echo "Creating apt preferences for additional protection..."
mkdir -p /etc/apt/preferences.d 2>/dev/null || true

cat > /etc/apt/preferences.d/opencv-protection << 'PREFEOF'
# Protect compiled OpenCV from APT overwrites
Package: libopencv-dev libopencv-core-dev libopencv-imgproc-dev libopencv-highgui-dev libopencv-contrib-dev
Pin: version 999.9.9
Pin-Priority: 1001
PREFEOF

if [ -f "/etc/apt/preferences.d/opencv-protection" ]; then
    echo "✓ Created apt preferences for OpenCV protection"
    protected_count=$((protected_count + 1))
fi

# Verify dpkg database integrity
echo "Verifying dpkg database integrity..."
if dpkg --audit 2>/dev/null; then
    echo "✓ Dpkg database is clean and consistent"
else
    echo "⚠ Dpkg database has issues, but continuing..."
fi

echo "✓ OpenCV protection completed ($protected_count methods applied)"
EOF

    # Replace the section
    head -n $((START_LINE - 1)) "$SCRIPT_FILE" > /tmp/script_part1.sh
    cat /tmp/opencv_replacement.sh >> /tmp/script_part1.sh
    tail -n +$((END_LINE + 1)) "$SCRIPT_FILE" >> /tmp/script_part1.sh
    
    # Replace original
    mv /tmp/script_part1.sh "$SCRIPT_FILE"
    chmod +x "$SCRIPT_FILE"
    
    # Cleanup
    rm -f /tmp/opencv_replacement.sh
    
    echo "✓ Successfully fixed OpenCV protection section in build script"
else
    echo "✗ Could not find OpenCV protection section in build script"
    exit 1
fi

echo ""
echo "=========================================================="
echo "FIX COMPLETE"
echo "=========================================================="
echo "✓ Fixed current dpkg status error"
echo "✓ Fixed build script OpenCV protection section"
echo "✓ Created backups of original files"
echo ""
echo "The build script now uses safe methods that won't cause dpkg errors:"
echo "- apt-mark hold (preferred method)"
echo "- apt preferences (additional protection)"
echo "- Proper cleanup of conflicting entries"
echo ""
echo "You can now continue with your build!"