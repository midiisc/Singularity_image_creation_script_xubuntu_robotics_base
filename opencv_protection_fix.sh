#!/bin/bash
#===============================================================================
# IMPROVED OPENCV PROTECTION MECHANISM
#===============================================================================
# Purpose: Protect compiled OpenCV from APT overwrites with better error handling
# Usage: Source this file and call protect_opencv_from_apt
#===============================================================================

protect_opencv_from_apt() {
    echo "Protecting compiled OpenCV from APT overwrites..."
    
    # Create backup of original status file
    if [ -f /var/lib/dpkg/status ]; then
        cp /var/lib/dpkg/status /var/lib/dpkg/status.backup.$(date +%s) 2>/dev/null || true
    fi
    
    # Method 1: Use apt-mark hold (preferred method)
    echo "Method 1: Using apt-mark hold..."
    if command -v apt-mark >/dev/null 2>&1; then
        for pkg in libopencv-dev libopencv-core-dev libopencv-imgproc-dev libopencv-highgui-dev libopencv-contrib-dev; do
            if apt-mark hold "$pkg" 2>/dev/null; then
                echo "✓ Held package: $pkg"
            else
                echo "⚠ Failed to hold package: $pkg (may not be installed)"
            fi
        done
        echo "✓ OpenCV packages held via apt-mark"
        return 0
    fi
    
    # Method 2: Use dpkg --set-selections (fallback)
    echo "Method 2: Using dpkg --set-selections..."
    if command -v dpkg >/dev/null 2>&1; then
        for pkg in libopencv-dev libopencv-core-dev libopencv-imgproc-dev libopencv-highgui-dev libopencv-contrib-dev; do
            if echo "$pkg hold" | dpkg --set-selections 2>/dev/null; then
                echo "✓ Held package: $pkg"
            else
                echo "⚠ Failed to hold package: $pkg"
            fi
        done
        echo "✓ OpenCV packages held via dpkg --set-selections"
        return 0
    fi
    
    # Method 3: Create dummy packages (last resort)
    echo "Method 3: Creating dummy package entries..."
    mkdir -p /var/lib/dpkg/status.d 2>/dev/null || {
        echo "✗ Cannot create /var/lib/dpkg/status.d directory"
        return 1
    }
    
    for pkg in libopencv-dev libopencv-core-dev libopencv-imgproc-dev libopencv-highgui-dev libopencv-contrib-dev; do
        cat > "/var/lib/dpkg/status.d/$pkg" << EOF
Package: $pkg
Status: install ok installed
Priority: optional
Section: libdevel
Installed-Size: 1
Maintainer: Custom Build
Architecture: amd64
Version: 999.9.9
Description: Placeholder for compiled OpenCV (in /usr/local)
 This is a dummy package to prevent apt from installing $pkg.
EOF
        
        # Append to main status file with error handling
        if [ -f "/var/lib/dpkg/status.d/$pkg" ]; then
            if cat "/var/lib/dpkg/status.d/$pkg" >> /var/lib/dpkg/status 2>/dev/null; then
                echo "✓ Created dummy entry for: $pkg"
            else
                echo "⚠ Failed to append to /var/lib/dpkg/status for: $pkg"
            fi
        else
            echo "⚠ Failed to create dummy file for: $pkg"
        fi
    done
    
    echo "✓ OpenCV protection completed (dummy packages method)"
}

# Alternative: Simple apt preferences approach
protect_opencv_with_preferences() {
    echo "Protecting OpenCV using apt preferences..."
    
    mkdir -p /etc/apt/preferences.d 2>/dev/null || {
        echo "✗ Cannot create /etc/apt/preferences.d directory"
        return 1
    }
    
    cat > /etc/apt/preferences.d/opencv-protection << 'EOF'
# Protect compiled OpenCV from APT overwrites
Package: libopencv-dev libopencv-core-dev libopencv-imgproc-dev libopencv-highgui-dev libopencv-contrib-dev
Pin: version 999.9.9
Pin-Priority: 1001
EOF
    
    if [ -f /etc/apt/preferences.d/opencv-protection ]; then
        echo "✓ OpenCV protection preferences created"
        return 0
    else
        echo "✗ Failed to create OpenCV protection preferences"
        return 1
    fi
}

# Main function with fallback
protect_opencv_comprehensive() {
    echo "==> Protecting compiled OpenCV from APT overwrites..."
    
    # Try methods in order of preference
    if protect_opencv_from_apt; then
        echo "✓ OpenCV protection successful"
    elif protect_opencv_with_preferences; then
        echo "✓ OpenCV protection successful (preferences method)"
    else
        echo "⚠ OpenCV protection failed - manual intervention may be required"
        echo "  You may need to manually prevent OpenCV package installation"
        return 1
    fi
}

# Export functions for use
export -f protect_opencv_from_apt
export -f protect_opencv_with_preferences  
export -f protect_opencv_comprehensive

echo "OpenCV protection functions loaded"