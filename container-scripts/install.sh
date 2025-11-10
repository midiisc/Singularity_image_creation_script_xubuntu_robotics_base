#!/usr/bin/env bash
#
# Installation helper for container scripts
# Reads MANIFEST.json and installs files to their target locations with proper permissions
#
# Usage:
#   install.sh [--all] [--script SOURCE_FILE] [--help]
#
# Options:
#   --all              Install all files from MANIFEST.json
#   --script FILE      Install specific file by source path
#   --help, -h         Show this help message
#
# Exit codes:
#   0  Success
#   1  Error (file not found, installation failed, etc.)
#

set -euo pipefail

# Script directory (container-scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
MANIFEST="${SCRIPT_DIR}/MANIFEST.json"
readonly MANIFEST

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Cleanup function for temporary resources
cleanup() {
    # Currently no temporary resources to clean up
    # This function is here for future extensibility
    :
}

# Trap handler for cleanup on exit
trap cleanup EXIT

# Error handler
error_exit() {
    local exit_code="${1:-1}"
    local error_msg="${2:-Unknown error}"
    echo -e "${RED}Error: ${error_msg}${NC}" >&2
    exit "${exit_code}"
}

# Validate that a path is safe (no path traversal)
validate_safe_path() {
    local path="$1"
    local base_dir="$2"
    
    # Resolve absolute paths
    local resolved_path
    resolved_path="$(readlink -f "${base_dir}/${path}" 2>/dev/null || echo "${base_dir}/${path}")"
    local resolved_base
    resolved_base="$(readlink -f "${base_dir}" 2>/dev/null || echo "${base_dir}")"
    
    # Check that resolved path is within base directory
    case "${resolved_path}" in
        "${resolved_base}"/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Validate permissions string (must be octal like 0644, 0755, etc.)
validate_permissions() {
    local perms="$1"
    
    # Check if it's a valid octal number (3-4 digits, 0-7)
    if [[ ! "${perms}" =~ ^[0-7]{3,4}$ ]]; then
        return 1
    fi
    
    return 0
}

# Check if manifest exists
if [ ! -f "${MANIFEST}" ]; then
    error_exit 1 "MANIFEST.json not found at ${MANIFEST}"
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: jq not found. Attempting to install...${NC}" >&2
    if command -v apt-get >/dev/null 2>&1; then
        # Temporarily disable exit on error for apt-get operations
        set +e
        apt-get update && apt-get install -y jq
        apt_status=$?
        set -e
        
        if [ "${apt_status}" -ne 0 ]; then
            error_exit 1 "Failed to install jq. Please install jq manually: apt-get install -y jq"
        fi
        
        # Verify jq is now available
        if ! command -v jq >/dev/null 2>&1; then
            error_exit 1 "jq installation appeared successful but jq command is not available"
        fi
    else
        error_exit 1 "jq is required but cannot be installed automatically. Please install jq manually."
    fi
fi

# Validate MANIFEST.json is valid JSON
if ! jq empty "${MANIFEST}" 2>/dev/null; then
    error_exit 1 "MANIFEST.json is not valid JSON"
fi

# Install a single file
install_file() {
    local source_file="$1"
    local target_file="$2"
    local permissions="$3"
    local file_type="$4"
    
    # Validate permissions format
    if ! validate_permissions "${permissions}"; then
        echo -e "${RED}Error: Invalid permissions format: ${permissions} (expected octal like 0644 or 0755)${NC}" >&2
        return 1
    fi
    
    # Validate source file path is safe (no path traversal)
    if ! validate_safe_path "${source_file}" "${SCRIPT_DIR}"; then
        echo -e "${RED}Error: Unsafe source file path: ${source_file}${NC}" >&2
        return 1
    fi
    
    # Resolve source file path
    local source_path="${SCRIPT_DIR}/${source_file}"
    
    if [ ! -f "${source_path}" ]; then
        echo -e "${RED}Error: Source file not found: ${source_path}${NC}" >&2
        return 1
    fi
    
    # Validate target file path (must be absolute)
    if [[ ! "${target_file}" = /* ]]; then
        echo -e "${RED}Error: Target file must be an absolute path: ${target_file}${NC}" >&2
        return 1
    fi
    
    # Create target directory if it doesn't exist
    local target_dir
    target_dir="$(dirname "${target_file}")"
    if [ ! -d "${target_dir}" ]; then
        if ! mkdir -p "${target_dir}"; then
            echo -e "${RED}Error: Failed to create directory ${target_dir}${NC}" >&2
            return 1
        fi
    fi
    
    # Copy file to target location
    if ! cp "${source_path}" "${target_file}"; then
        echo -e "${RED}Error: Failed to copy ${source_file} to ${target_file}${NC}" >&2
        return 1
    fi
    
    # Set permissions
    if ! chmod "${permissions}" "${target_file}"; then
        echo -e "${YELLOW}Warning: Failed to set permissions ${permissions} on ${target_file}${NC}" >&2
        # Don't fail installation if chmod fails, but warn
    fi
    
    # Make Python scripts executable if they're in /opt/scripts/ or /usr/local/bin/
    # (Python scripts are installed with 0644 but need to be executable)
    if [[ "${file_type}" == "python-scripts" ]] && [[ "${target_file}" =~ ^/(opt/scripts|usr/local/bin)/ ]]; then
        if ! chmod +x "${target_file}"; then
            echo -e "${YELLOW}Warning: Failed to make Python script executable: ${target_file}${NC}" >&2
        fi
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
    
    # Get total count with error handling
    if ! total=$(jq -r '.files | length' "${MANIFEST}" 2>/dev/null); then
        error_exit 1 "Failed to parse MANIFEST.json: invalid JSON structure"
    fi
    
    # Validate total is a number
    if [[ ! "${total}" =~ ^[0-9]+$ ]]; then
        error_exit 1 "Invalid file count in MANIFEST.json: ${total}"
    fi
    
    echo -e "${BLUE}Found ${total} files to install${NC}"
    echo ""
    
    # Process each file using process substitution to avoid subshell issues
    # Use process substitution to read from jq output directly
    while IFS= read -r file_entry || [ -n "${file_entry}" ]; do
        # Skip empty lines
        if [ -z "${file_entry}" ]; then
            continue
        fi
        
        local source_file
        local target_file
        local permissions
        local file_type
        
        # Extract fields with error handling
        if ! source_file=$(echo "${file_entry}" | jq -r '.source // empty' 2>/dev/null); then
            echo -e "${YELLOW}Warning: Failed to parse source field, skipping entry${NC}" >&2
            failed=$((failed + 1))
            continue
        fi
        
        if ! target_file=$(echo "${file_entry}" | jq -r '.target // empty' 2>/dev/null); then
            echo -e "${YELLOW}Warning: Failed to parse target field for ${source_file}, skipping${NC}" >&2
            failed=$((failed + 1))
            continue
        fi
        
        if ! permissions=$(echo "${file_entry}" | jq -r '.permissions // empty' 2>/dev/null); then
            echo -e "${YELLOW}Warning: Failed to parse permissions field for ${source_file}, skipping${NC}" >&2
            failed=$((failed + 1))
            continue
        fi
        
        if ! file_type=$(echo "${file_entry}" | jq -r '.file_type // empty' 2>/dev/null); then
            echo -e "${YELLOW}Warning: Failed to parse file_type field for ${source_file}, skipping${NC}" >&2
            failed=$((failed + 1))
            continue
        fi
        
        # Validate required fields are not empty
        if [ -z "${source_file}" ] || [ -z "${target_file}" ] || [ -z "${permissions}" ]; then
            echo -e "${YELLOW}Warning: Missing required fields (source, target, or permissions), skipping entry${NC}" >&2
            failed=$((failed + 1))
            continue
        fi
        
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
    done < <(jq -c '.files[]' "${MANIFEST}" 2>/dev/null || error_exit 1 "Failed to read files array from MANIFEST.json")
    
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Installation Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "Total files: ${total}"
    echo -e "${GREEN}Installed: ${installed}${NC}"
    if [ "${failed}" -gt 0 ]; then
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
    
    # Validate input is not empty
    if [ -z "${source_file}" ]; then
        error_exit 1 "Source file path cannot be empty"
    fi
    
    # Validate source file path is safe (no path traversal)
    if ! validate_safe_path "${source_file}" "${SCRIPT_DIR}"; then
        error_exit 1 "Unsafe source file path: ${source_file}"
    fi
    
    echo -e "${BLUE}Installing specific file: ${source_file}${NC}"
    
    # Find file in manifest with proper escaping
    local file_entry
    # Use jq's --arg to safely pass the source_file variable
    if ! file_entry=$(jq -c --arg source "${source_file}" '.files[] | select(.source == $source)' "${MANIFEST}" 2>/dev/null); then
        error_exit 1 "Failed to query MANIFEST.json"
    fi
    
    if [ -z "${file_entry}" ]; then
        error_exit 1 "File not found in manifest: ${source_file}"
    fi
    
    local target_file
    local permissions
    local file_type
    
    # Extract fields with error handling
    if ! target_file=$(echo "${file_entry}" | jq -r '.target // empty' 2>/dev/null); then
        error_exit 1 "Failed to parse target field from manifest entry"
    fi
    
    if ! permissions=$(echo "${file_entry}" | jq -r '.permissions // empty' 2>/dev/null); then
        error_exit 1 "Failed to parse permissions field from manifest entry"
    fi
    
    if ! file_type=$(echo "${file_entry}" | jq -r '.file_type // empty' 2>/dev/null); then
        error_exit 1 "Failed to parse file_type field from manifest entry"
    fi
    
    # Validate required fields
    if [ -z "${target_file}" ] || [ -z "${permissions}" ]; then
        error_exit 1 "Missing required fields (target or permissions) in manifest entry"
    fi
    
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
                if [ $# -lt 2 ]; then
                    error_exit 1 "--script requires a file path argument"
                fi
                install_specific_file="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [--all] [--script SOURCE_FILE] [--help]"
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
                error_exit 1 "Unknown option: $1 (use --help for usage information)"
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
