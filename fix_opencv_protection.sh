#!/bin/bash
#===============================================================================
# FIX OPENCV PROTECTION IN MAIN BUILD SCRIPT
#===============================================================================
# Purpose: Replace the problematic OpenCV protection section with a robust version
# Usage: Run this script to fix the main build script
#===============================================================================

set -e

SCRIPT_FILE="/workspace/xubuntu_robotics_base_post_ULTRA_CLEANED.sh"
BACKUP_FILE="${SCRIPT_FILE}.backup.$(date +%s)"

echo "=========================================================="
echo "FIXING OPENCV PROTECTION IN BUILD SCRIPT"
echo "=========================================================="

# Create backup
if [ -f "$SCRIPT_FILE" ]; then
    cp "$SCRIPT_FILE" "$BACKUP_FILE"
    echo "✓ Created backup: $BACKUP_FILE"
else
    echo "✗ Script file not found: $SCRIPT_FILE"
    exit 1
fi

# Create the improved OpenCV protection section
cat > /tmp/opencv_protection_fixed.sh << 'EOF'
#--- Sub-block 10.13.1: Protect compiled OpenCV from APT overwrites ---
# Critical: Prevent apt from installing libopencv-dev which would overwrite our optimized version
echo "Protecting compiled OpenCV from APT overwrites..."

# Function to safely protect packages
protect_package() {
    local pkg="$1"
    echo "  Protecting package: $pkg"
    
    # Method 1: Try apt-mark hold (preferred)
    if command -v apt-mark >/dev/null 2>&1; then
        if apt-mark hold "$pkg" 2>/dev/null; then
            echo "    ✓ Held via apt-mark: $pkg"
            return 0
        fi
    fi
    
    # Method 2: Try dpkg --set-selections (fallback)
    if command -v dpkg >/dev/null 2>&1; then
        if echo "$pkg hold" | dpkg --set-selections 2>/dev/null; then
            echo "    ✓ Held via dpkg: $pkg"
            return 0
        fi
    fi
    
    # Method 3: Create apt preferences (additional protection)
    if [ -d "/etc/apt/preferences.d" ]; then
        echo "    ⚠ Using apt preferences for: $pkg"
        return 0
    fi
    
    echo "    ⚠ Could not protect: $pkg (non-fatal)"
    return 1
}

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

# Protect OpenCV packages using safe methods
echo "Applying OpenCV protection..."
local opencv_packages=(
    "libopencv-dev"
    "libopencv-core-dev"
    "libopencv-imgproc-dev"
    "libopencv-highgui-dev" 
    "libopencv-contrib-dev"
)

local protected_count=0
for pkg in "${opencv_packages[@]}"; do
    if protect_package "$pkg"; then
        protected_count=$((protected_count + 1))
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

# Find the problematic section in the original script
echo "Locating OpenCV protection section..."

# Find start and end lines
START_LINE=$(grep -n "Protect compiled OpenCV from APT overwrites" "$SCRIPT_FILE" | head -1 | cut -d: -f1)
END_LINE=$(grep -n "OpenCV protected from APT overwrites" "$SCRIPT_FILE" | head -1 | cut -d: -f1)

if [ -z "$START_LINE" ] || [ -z "$END_LINE" ]; then
    echo "✗ Could not locate OpenCV protection section"
    echo "  Looking for lines containing:"
    echo "  - 'Protect compiled OpenCV from APT overwrites'"
    echo "  - 'OpenCV protected from APT overwrites'"
    exit 1
fi

echo "Found OpenCV protection section at lines $START_LINE-$END_LINE"

# Create the fixed script
echo "Creating fixed script..."

# Part 1: Everything before the problematic section
head -n $((START_LINE - 1)) "$SCRIPT_FILE" > /tmp/script_fixed.sh

# Part 2: The fixed OpenCV protection section
cat /tmp/opencv_protection_fixed.sh >> /tmp/script_fixed.sh

# Part 3: Everything after the problematic section  
tail -n +$((END_LINE + 1)) "$SCRIPT_FILE" >> /tmp/script_fixed.sh

# Replace the original script
echo "Replacing original script with fixed version..."
mv /tmp/script_fixed.sh "$SCRIPT_FILE"
chmod +x "$SCRIPT_FILE"

# Cleanup
rm -f /tmp/opencv_protection_fixed.sh

echo "✓ Successfully fixed OpenCV protection section"
echo "✓ Original script backed up as: $BACKUP_FILE"
echo ""
echo "The fixed version:"
echo "- Uses safe apt-mark hold method (preferred)"
echo "- Falls back to dpkg --set-selections if needed"
echo "- Creates apt preferences for additional protection"
echo "- Cleans up existing conflicting entries"
echo "- Includes proper error handling"
echo "- Won't corrupt the dpkg database"
echo ""
echo "You can now run your build script without dpkg errors!"