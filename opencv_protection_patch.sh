#!/bin/bash
#===============================================================================
# OPENCV PROTECTION PATCH
#===============================================================================
# Purpose: Replace the problematic OpenCV protection section in the build script
# Usage: Run this script to patch the main build script
#===============================================================================

# Backup original file
if [ -f "/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh" ]; then
    cp "/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh" "/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh.backup.$(date +%s)"
    echo "✓ Created backup of original script"
fi

# Create the improved OpenCV protection section
cat > /tmp/opencv_protection_section.sh << 'EOF'
#--- Sub-block 10.13.1: Protect compiled OpenCV from APT overwrites ---
# Critical: Prevent apt from installing libopencv-dev which would overwrite our optimized version
echo "Protecting compiled OpenCV from APT overwrites..."

# Method 1: Use apt-mark hold (preferred method)
if command -v apt-mark >/dev/null 2>&1; then
    echo "Using apt-mark hold method..."
    for pkg in libopencv-dev libopencv-core-dev libopencv-imgproc-dev libopencv-highgui-dev libopencv-contrib-dev; do
        if apt-mark hold "$pkg" 2>/dev/null; then
            echo "✓ Held package: $pkg"
        else
            echo "⚠ Package $pkg not available for holding (non-fatal)"
        fi
    done
    echo "✓ OpenCV packages held via apt-mark"
else
    # Method 2: Use dpkg --set-selections (fallback)
    echo "Using dpkg --set-selections method..."
    for pkg in libopencv-dev libopencv-core-dev libopencv-imgproc-dev libopencv-highgui-dev libopencv-contrib-dev; do
        if echo "$pkg hold" | dpkg --set-selections 2>/dev/null; then
            echo "✓ Held package: $pkg"
        else
            echo "⚠ Failed to hold package: $pkg (non-fatal)"
        fi
    done
    echo "✓ OpenCV packages held via dpkg --set-selections"
fi

# Method 3: Create apt preferences (additional protection)
echo "Creating apt preferences for additional protection..."
mkdir -p /etc/apt/preferences.d 2>/dev/null || true
cat > /etc/apt/preferences.d/opencv-protection << 'PREFEOF'
# Protect compiled OpenCV from APT overwrites
Package: libopencv-dev libopencv-core-dev libopencv-imgproc-dev libopencv-highgui-dev libopencv-contrib-dev
Pin: version 999.9.9
Pin-Priority: 1001
PREFEOF

if [ -f /etc/apt/preferences.d/opencv-protection ]; then
    echo "✓ OpenCV protection preferences created"
else
    echo "⚠ Failed to create preferences file (non-fatal)"
fi

echo "✓ OpenCV protected from APT overwrites"
EOF

# Find the line numbers for the OpenCV protection section
START_LINE=$(grep -n "Protect compiled OpenCV from APT overwrites" "/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh" | cut -d: -f1)
END_LINE=$(grep -n "OpenCV protected from APT overwrites" "/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh" | cut -d: -f1)

if [ -n "$START_LINE" ] && [ -n "$END_LINE" ]; then
    echo "Found OpenCV protection section at lines $START_LINE-$END_LINE"
    
    # Create a temporary file with the replacement
    head -n $((START_LINE - 1)) "/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh" > /tmp/patched_script.sh
    cat /tmp/opencv_protection_section.sh >> /tmp/patched_script.sh
    tail -n +$((END_LINE + 1)) "/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh" >> /tmp/patched_script.sh
    
    # Replace the original file
    mv /tmp/patched_script.sh "/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh"
    chmod +x "/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh"
    
    echo "✓ Successfully patched OpenCV protection section"
    echo "✓ Original script backed up with timestamp"
else
    echo "✗ Could not find OpenCV protection section in the script"
    echo "  You may need to manually replace the section starting with:"
    echo "  'Protect compiled OpenCV from APT overwrites...'"
fi

# Cleanup
rm -f /tmp/opencv_protection_section.sh

echo "Patch complete!"