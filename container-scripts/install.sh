#!/usr/bin/env bash
#
# Installation helper for container scripts
# Reads MANIFEST.json and installs files to their target locations with proper permissions
#

set -euo pipefail

# Script directory (container-scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/MANIFEST.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if manifest exists
if [ ! -f "${MANIFEST}" ]; then
    echo -e "${RED}Error: MANIFEST.json not found at ${MANIFEST}${NC}" >&2
    exit 1
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: jq not found. Attempting to install...${NC}" >&2
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y jq
    else
        echo -e "${RED}Error: jq is required but cannot be installed automatically${NC}" >&2
        exit 1
    fi
fi

# Install a single file
install_file() {
    local source_file="$1"
    local target_file="$2"
    local permissions="$3"
    local file_type="$4"
    
    # Resolve source file path
    local source_path="${SCRIPT_DIR}/${source_file}"
    
    if [ ! -f "${source_path}" ]; then
        echo -e "${RED}Error: Source file not found: ${source_path}${NC}" >&2
        return 1
    fi
    
    # Create target directory if it doesn't exist
    local target_dir
    target_dir="$(dirname "${target_file}")"
    if [ ! -d "${target_dir}" ]; then
        mkdir -p "${target_dir}" || {
            echo -e "${RED}Error: Failed to create directory ${target_dir}${NC}" >&2
            return 1
        }
    fi
    
    # Copy file to target location
    if ! cp "${source_path}" "${target_file}"; then
        echo -e "${RED}Error: Failed to copy ${source_file} to ${target_file}${NC}" >&2
        return 1
    fi
    
    # Set permissions
    if ! chmod "${permissions}" "${target_file}"; then
        echo -e "${YELLOW}Warning: Failed to set permissions ${permissions} on ${target_file}${NC}" >&2
    fi
    
    echo -e "${GREEN}✓ Installed: ${source_file} -> ${target_file} (${permissions})${NC}"
    return 0
}

# Install all files from manifest
install_all() {
    local total=0
    local installed=0
    local failed=0
    
    echo -e "${BLUE}Reading MANIFEST.json...${NC}"
    
    # Get total count
    total=$(jq '.files | length' "${MANIFEST}")
    echo -e "${BLUE}Found ${total} files to install${NC}"
    echo ""
    
    # Process each file using process substitution to avoid subshell issues
    # Use process substitution to read from jq output directly
    while IFS= read -r file_entry; do
        local source_file
        local target_file
        local permissions
        local file_type
        
        source_file=$(echo "${file_entry}" | jq -r '.source')
        target_file=$(echo "${file_entry}" | jq -r '.target')
        permissions=$(echo "${file_entry}" | jq -r '.permissions')
        file_type=$(echo "${file_entry}" | jq -r '.file_type')
        
        # Skip if source file doesn't exist
        if [ ! -f "${SCRIPT_DIR}/${source_file}" ]; then
            echo -e "${YELLOW}Warning: Source file not found: ${source_file}${NC}" >&2
            failed=$((failed + 1))
            continue
        fi
        
        # Install file
        if install_file "${source_file}" "${target_file}" "${permissions}" "${file_type}"; then
            installed=$((installed + 1))
        else
            failed=$((failed + 1))
        fi
    done < <(jq -c '.files[]' "${MANIFEST}")
    
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Installation Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "Total files: ${total}"
    echo -e "${GREEN}Installed: ${installed}${NC}"
    if [ ${failed} -gt 0 ]; then
        echo -e "${RED}Failed: ${failed}${NC}"
        return 1
    else
        echo -e "${GREEN}✓ All files installed successfully!${NC}"
        return 0
    fi
}

# Install specific file by source path
install_specific() {
    local source_file="$1"
    
    echo -e "${BLUE}Installing specific file: ${source_file}${NC}"
    
    # Find file in manifest
    local file_entry
    file_entry=$(jq -c ".files[] | select(.source == \"${source_file}\")" "${MANIFEST}")
    
    if [ -z "${file_entry}" ]; then
        echo -e "${RED}Error: File not found in manifest: ${source_file}${NC}" >&2
        return 1
    fi
    
    local target_file
    local permissions
    local file_type
    
    target_file=$(echo "${file_entry}" | jq -r '.target')
    permissions=$(echo "${file_entry}" | jq -r '.permissions')
    file_type=$(echo "${file_entry}" | jq -r '.file_type')
    
    install_file "${source_file}" "${target_file}" "${permissions}" "${file_type}"
}

# Main function
main() {
    local install_all_flag=false
    local install_specific_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                install_all_flag=true
                shift
                ;;
            --script)
                install_specific_file="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [--all] [--script SOURCE_FILE]"
                echo ""
                echo "Options:"
                echo "  --all              Install all files from MANIFEST.json"
                echo "  --script FILE      Install specific file by source path"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0 --all"
                echo "  $0 --script shell-scripts/block-11-apt-aria-wrapper-setup-must-be-before-nvidia/apt-wrapper-aria2c-accelerated-downloads.sh"
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Install based on flags
    if [ "${install_all_flag}" = true ]; then
        install_all
    elif [ -n "${install_specific_file}" ]; then
        install_specific "${install_specific_file}"
    else
        # Default: install all
        echo -e "${YELLOW}No option specified. Installing all files...${NC}"
        install_all
    fi
}

# Run main function
main "$@"

