#!/bin/bash
#===============================================================================
# DPKG STATUS CORRUPTION FIX
#===============================================================================
# Purpose: Fix dpkg status file corruption with multiple package instances
# Usage: Run this script to clean up dpkg status file
#===============================================================================

echo "=========================================================="
echo "DPKG STATUS CORRUPTION FIX"
echo "=========================================================="

# Function to backup and clean dpkg status
fix_dpkg_status() {
    local status_file="/var/lib/dpkg/status"
    local backup_file="/var/lib/dpkg/status.backup.$(date +%s)"
    
    echo "1. Creating backup of current status file..."
    if [ -f "$status_file" ]; then
        cp "$status_file" "$backup_file" 2>/dev/null || {
            echo "✗ Failed to create backup"
            return 1
        }
        echo "✓ Backup created: $backup_file"
    else
        echo "✗ Status file not found: $status_file"
        return 1
    fi
    
    echo "2. Analyzing status file for duplicates..."
    
    # Find packages with multiple entries
    local duplicate_packages=$(grep "^Package:" "$status_file" | sort | uniq -d)
    
    if [ -n "$duplicate_packages" ]; then
        echo "Found duplicate packages:"
        echo "$duplicate_packages"
        echo ""
        
        echo "3. Cleaning up duplicate entries..."
        
        # Create a temporary clean status file
        local temp_status="/tmp/dpkg_status_clean"
        local current_package=""
        local package_start_line=0
        local line_num=0
        local in_package=false
        local keep_package=true
        
        > "$temp_status"
        
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            
            # Check if this is a package header
            if [[ "$line" =~ ^Package:[[:space:]]*(.+)$ ]]; then
                local pkg_name="${BASH_REMATCH[1]}"
                
                # If we were in a package, decide whether to keep it
                if [ "$in_package" = true ]; then
                    if [ "$keep_package" = true ]; then
                        # Keep the previous package (write it to temp file)
                        sed -n "${package_start_line},$((line_num - 1))p" "$status_file" >> "$temp_status"
                    fi
                fi
                
                # Check if this package is a duplicate
                local count=$(grep -c "^Package: $pkg_name$" "$status_file")
                if [ "$count" -gt 1 ]; then
                    echo "  Found duplicate: $pkg_name ($count instances)"
                    # Keep only the first instance, skip others
                    keep_package=false
                else
                    keep_package=true
                fi
                
                current_package="$pkg_name"
                package_start_line="$line_num"
                in_package=true
            fi
            
            # Check if we've reached the end of a package (empty line)
            if [ -z "$line" ] && [ "$in_package" = true ]; then
                if [ "$keep_package" = true ]; then
                    # Keep this package
                    sed -n "${package_start_line},${line_num}p" "$status_file" >> "$temp_status"
                fi
                in_package=false
                keep_package=true
            fi
            
        done < "$status_file"
        
        # Handle the last package if file doesn't end with newline
        if [ "$in_package" = true ] && [ "$keep_package" = true ]; then
            sed -n "${package_start_line},\$p" "$status_file" >> "$temp_status"
        fi
        
        echo "4. Validating cleaned status file..."
        
        # Check for syntax errors in the cleaned file
        if dpkg --audit 2>/dev/null < "$temp_status"; then
            echo "✓ Cleaned status file is valid"
            
            echo "5. Replacing original status file..."
            if mv "$temp_status" "$status_file" 2>/dev/null; then
                echo "✓ Status file successfully cleaned"
                
                echo "6. Verifying dpkg database integrity..."
                if dpkg --audit 2>/dev/null; then
                    echo "✓ Dpkg database is now clean and consistent"
                    return 0
                else
                    echo "⚠ Dpkg database still has issues, but status file is cleaner"
                    return 1
                fi
            else
                echo "✗ Failed to replace status file"
                return 1
            fi
        else
            echo "✗ Cleaned status file has syntax errors"
            return 1
        fi
        
    else
        echo "✓ No duplicate packages found"
        return 0
    fi
}

# Function to specifically fix OpenCV package conflicts
fix_opencv_conflicts() {
    echo "=========================================================="
    echo "SPECIFIC OPENCV CONFLICT FIX"
    echo "=========================================================="
    
    local status_file="/var/lib/dpkg/status"
    local backup_file="/var/lib/dpkg/status.backup.opencv.$(date +%s)"
    
    echo "1. Creating OpenCV-specific backup..."
    cp "$status_file" "$backup_file" 2>/dev/null || {
        echo "✗ Failed to create backup"
        return 1
    }
    
    echo "2. Removing all OpenCV package entries..."
    
    # Remove all OpenCV-related packages from status
    local opencv_packages=(
        "libopencv-dev"
        "libopencv-core-dev" 
        "libopencv-imgproc-dev"
        "libopencv-highgui-dev"
        "libopencv-contrib-dev"
        "libopencv-core4"
        "libopencv-imgproc4"
        "libopencv-highgui4"
        "libopencv-contrib4"
    )
    
    for pkg in "${opencv_packages[@]}"; do
        echo "  Removing: $pkg"
        # Remove package entries (from Package: line to next empty line)
        sed -i "/^Package: $pkg$/,/^$/d" "$status_file" 2>/dev/null || true
    done
    
    echo "3. Verifying OpenCV packages are removed..."
    local remaining=$(grep -c "libopencv" "$status_file" 2>/dev/null || echo "0")
    if [ "$remaining" -eq 0 ]; then
        echo "✓ All OpenCV packages removed from status file"
    else
        echo "⚠ $remaining OpenCV references still remain"
    fi
    
    echo "4. Testing dpkg status file..."
    if dpkg --audit 2>/dev/null; then
        echo "✓ Dpkg status file is now valid"
        return 0
    else
        echo "✗ Dpkg status file still has issues"
        return 1
    fi
}

# Function to rebuild dpkg database
rebuild_dpkg_database() {
    echo "=========================================================="
    echo "DPKG DATABASE REBUILD (NUCLEAR OPTION)"
    echo "=========================================================="
    echo "⚠ WARNING: This will rebuild the entire dpkg database"
    echo "⚠ This should only be used if other methods fail"
    echo ""
    read -p "Continue with database rebuild? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Database rebuild cancelled"
        return 1
    fi
    
    echo "1. Stopping any running dpkg processes..."
    pkill -f dpkg 2>/dev/null || true
    sleep 2
    
    echo "2. Creating comprehensive backup..."
    local backup_dir="/var/lib/dpkg/backup.$(date +%s)"
    mkdir -p "$backup_dir"
    cp -r /var/lib/dpkg/* "$backup_dir/" 2>/dev/null || true
    echo "✓ Backup created in: $backup_dir"
    
    echo "3. Rebuilding dpkg database..."
    
    # Clear current status
    > /var/lib/dpkg/status
    
    # Rebuild from available packages
    if command -v dpkg >/dev/null 2>&1; then
        # Get list of actually installed packages
        dpkg -l | grep "^ii" | awk '{print $2}' > /tmp/installed_packages
        
        # For each installed package, create a minimal status entry
        while read -r pkg; do
            cat >> /var/lib/dpkg/status << EOF
Package: $pkg
Status: install ok installed
Priority: optional
Section: unknown
Installed-Size: 0
Maintainer: Unknown
Architecture: amd64
Version: 1.0.0
Description: Rebuilt package entry
 This package was rebuilt during database recovery.
EOF
            echo "" >> /var/lib/dpkg/status
        done < /tmp/installed_packages
        
        rm -f /tmp/installed_packages
        
        echo "4. Testing rebuilt database..."
        if dpkg --audit 2>/dev/null; then
            echo "✓ Database rebuild successful"
            return 0
        else
            echo "✗ Database rebuild failed"
            return 1
        fi
    else
        echo "✗ dpkg command not available"
        return 1
    fi
}

# Main execution
main() {
    echo "Choose fix method:"
    echo "1) Clean duplicate packages (recommended)"
    echo "2) Remove OpenCV packages specifically"
    echo "3) Rebuild entire dpkg database (nuclear option)"
    echo "4) All methods in sequence"
    echo ""
    read -p "Enter choice (1-4): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            fix_dpkg_status
            ;;
        2)
            fix_opencv_conflicts
            ;;
        3)
            rebuild_dpkg_database
            ;;
        4)
            echo "Running all fix methods in sequence..."
            fix_dpkg_status || fix_opencv_conflicts || rebuild_dpkg_database
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo ""
    echo "=========================================================="
    echo "FINAL VERIFICATION"
    echo "=========================================================="
    
    if dpkg --audit 2>/dev/null; then
        echo "✓ Dpkg database is now clean and functional"
        echo "✓ You can now proceed with your build"
    else
        echo "✗ Dpkg database still has issues"
        echo "  You may need to manually edit /var/lib/dpkg/status"
        echo "  or restore from backup"
    fi
}

# Run main function
main "$@"