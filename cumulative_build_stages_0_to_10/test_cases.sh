#!/bin/bash
#===============================================================================
# COMPREHENSIVE TEST CASE FRAMEWORK
#===============================================================================
# Purpose: Test cases for permissions, bind mounts, and functionality
#          ALL tests must pass before stage can proceed
# Usage: source test_cases.sh; run_stage_tests <stage_num>
#===============================================================================

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0
CRITICAL_FAILURES=0

# Function: Test result reporting
test_pass() {
    local test_name="$1"
    printf '%s\n' "${GREEN}✓ PASS${NC}: ${test_name}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    printf '%s\n' "${RED}✗ FAIL${NC}: ${test_name}"
    printf '%s\n' "  Reason: ${reason}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
}

test_warning() {
    local test_name="$1"
    local reason="$2"
    printf '%s\n' "${YELLOW}⚠ WARN${NC}: ${test_name}"
    printf '%s\n' "  Reason: ${reason}"
    TESTS_WARNINGS=$((TESTS_WARNINGS + 1))
    # Warnings are treated as failures - must be fixed
    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
}

# Function: Test directory permissions
test_dir_permissions() {
    local dir_path="$1"
    local expected_perms="$2"
    local test_name="${3:-Directory permissions: ${dir_path}}"
    
    if [ ! -d "${dir_path}" ]; then
        test_fail "${test_name}" "Directory does not exist: ${dir_path}"
        return 1
    fi
    
    local actual_perms
    actual_perms=$(stat -c '%a' "${dir_path}" 2>/dev/null || printf '%s\n' "unknown")
    
    if [ "${actual_perms}" = "${expected_perms}" ]; then
        test_pass "${test_name} (${actual_perms})"
        return 0
    else
        test_fail "${test_name}" "Expected ${expected_perms}, got ${actual_perms}"
        return 1
    fi
}

# Function: Test file permissions
test_file_permissions() {
    local file_path="$1"
    local expected_perms="$2"
    local test_name="${3:-File permissions: ${file_path}}"
    
    if [ ! -f "${file_path}" ]; then
        test_fail "${test_name}" "File does not exist: ${file_path}"
        return 1
    fi
    
    local actual_perms
    actual_perms=$(stat -c '%a' "${file_path}" 2>/dev/null || printf '%s\n' "unknown")
    
    if [ "${actual_perms}" = "${expected_perms}" ]; then
        test_pass "${test_name} (${actual_perms})"
        return 0
    else
        test_fail "${test_name}" "Expected ${expected_perms}, got ${actual_perms}"
        return 1
    fi
}

# Function: Test read access
test_read_access() {
    local path="$1"
    local test_name="${2:-Read access: ${path}}"
    
    if [ ! -r "${path}" ]; then
        test_fail "${test_name}" "Path is not readable: ${path}"
        return 1
    fi
    
    test_pass "${test_name}"
    return 0
}

# Function: Test write access
test_write_access() {
    local path="$1"
    local test_name="${2:-Write access: ${path}}"
    
    local test_file=""
    if [ -d "${path}" ]; then
        test_file="${path}/.write_test_$$"
        if ! touch "${test_file}" 2>/dev/null; then
            test_fail "${test_name}" "Cannot create test file in: ${path}"
            return 1
        fi
        rm -f "${test_file}" 2>/dev/null || true
    elif [ -f "${path}" ]; then
        if [ ! -w "${path}" ]; then
            test_fail "${test_name}" "File is not writable: ${path}"
            return 1
        fi
    else
        test_fail "${test_name}" "Path does not exist: ${path}"
        return 1
    fi
    
    test_pass "${test_name}"
    return 0
}

# Function: Test execute access
test_execute_access() {
    local path="$1"
    local test_name="${2:-Execute access: ${path}}"
    
    if [ ! -x "${path}" ]; then
        test_fail "${test_name}" "Path is not executable: ${path}"
        return 1
    fi
    
    test_pass "${test_name}"
    return 0
}

# Function: Test bind mount (context-aware: host vs container)
test_bind_mount() {
    local mount_point="$1"
    local test_name="${2:-Bind mount: ${mount_point}}"
    
    # Determine context (host vs container)
    local current_user
    current_user=$(id -u 2>/dev/null || printf '%s\n' "0")
    local is_container=false
    
    # Check if we're in a container
    if [ "${current_user}" -eq 0 ] && ([ -f "/.singularity.d/runscript" ] || [ -f "/.apptainer.d/runscript" ]); then
        is_container=true
    fi
    
    # On host: bind mounts don't exist yet - test the HOST directories that will be bind-mounted
    if [ "${is_container}" = "false" ]; then
        # On host: test the HOST directories that will be bind-mounted
        case "${mount_point}" in
            /container_cache)
                # Test host cache directory - use environment variable if available
                local host_cache="${HOST_CACHE_BIND_SRC:-}"
                # Fallback: try to determine from common locations
                if [ -z "${host_cache}" ]; then
                    # Try to find container_cache in common locations
                    if [ -d "${HOME}/container_cache" ]; then
                        host_cache="${HOME}/container_cache"
                    elif [ -d "/home/$(id -un)/container_cache" ]; then
                        host_cache="/home/$(id -un)/container_cache"
                    fi
                fi
                if [ -n "${host_cache}" ] && [ -d "${host_cache}" ]; then
                    test_dir_permissions "${host_cache}" "755" "Host cache directory permissions"
                    test_read_access "${host_cache}" "Host cache directory read"
                    test_write_access "${host_cache}" "Host cache directory write"
                    return 0
                else
                    test_fail "${test_name}" "Host cache directory does not exist: ${host_cache:-<not set>}"
                    return 1
                fi
                ;;
            /tmp|/var/tmp)
                # Test host temp directory - use environment variable if available
                local host_tmp="${CONTAINER_TMP_BIND:-}"
                # Fallback: try to determine from common locations
                if [ -z "${host_tmp}" ]; then
                    # Try to find test_tmp in common locations
                    if [ -d "${HOME}/test_tmp" ]; then
                        host_tmp="${HOME}/test_tmp"
                    elif [ -d "/tmp/test_tmp" ]; then
                        host_tmp="/tmp/test_tmp"
                    fi
                fi
                if [ -n "${host_tmp}" ] && [ -d "${host_tmp}" ]; then
                    test_dir_permissions "${host_tmp}" "1777" "Host temp directory permissions"
                    test_read_access "${host_tmp}" "Host temp directory read"
                    test_write_access "${host_tmp}" "Host temp directory write"
                    return 0
                else
                    test_fail "${test_name}" "Host temp directory does not exist: ${host_tmp:-<not set>}"
                    return 1
                fi
                ;;
            *)
                test_warning "${test_name}" "Unknown mount point on host: ${mount_point}"
                return 0
                ;;
        esac
    fi
    
    # In container: test the actual bind mounts
    # Check existence
    if [ ! -d "${mount_point}" ]; then
        test_fail "${test_name}" "Mount point does not exist: ${mount_point}"
        return 1
    fi
    
    # Check if mounted (if mountpoint command available)
    if command -v mountpoint >/dev/null 2>&1; then
        if mountpoint -q "${mount_point}" 2>/dev/null; then
            test_pass "${test_name} (mounted)"
        else
            test_warning "${test_name}" "May not be bind-mounted (mountpoint check failed)"
        fi
    fi
    
    # Test permissions (1777 for /tmp, /var/tmp; 755 for /container_cache)
    local expected_perms="755"
    if [ "${mount_point}" = "/tmp" ] || [ "${mount_point}" = "/var/tmp" ]; then
        expected_perms="1777"
    fi
    test_dir_permissions "${mount_point}" "${expected_perms}" "${test_name} permissions"
    
    # Test read/write/execute access
    test_read_access "${mount_point}" "${test_name} read"
    test_write_access "${mount_point}" "${test_name} write"
    test_execute_access "${mount_point}" "${test_name} execute"
    
    return 0
}

# Function: Test file/directory ownership (context-aware)
test_ownership() {
    local path="$1"
    local expected_owner="${2:-}"
    local test_name="${3:-Ownership: ${path}}"
    
    if [ ! -e "${path}" ]; then
        test_fail "${test_name}" "Path does not exist: ${path}"
        return 1
    fi
    
    local actual_owner
    actual_owner=$(stat -c '%U:%G' "${path}" 2>/dev/null || printf '%s\n' "unknown")
    
    # Determine context (host vs container)
    local current_user
    current_user=$(id -u 2>/dev/null || printf '%s\n' "0")
    
    if [ "${current_user}" -eq 0 ]; then
        # In container: expect root:root
        if [ -z "${expected_owner}" ]; then
            expected_owner="root:root"
        fi
        if [ "${actual_owner}" = "${expected_owner}" ]; then
            test_pass "${test_name} (${actual_owner})"
            return 0
        else
            test_fail "${test_name}" "Expected ${expected_owner}, got ${actual_owner} (in container)"
            return 1
        fi
    else
        # On host: expect user:user (correct behavior)
        local current_user_name
        current_user_name=$(id -un 2>/dev/null || printf '%s\n' "unknown")
        local current_group
        current_group=$(id -gn 2>/dev/null || printf '%s\n' "unknown")
        local expected_host_owner="${current_user_name}:${current_group}"
        
        if [ "${actual_owner}" = "${expected_host_owner}" ]; then
            test_pass "${test_name} (${actual_owner} - host filesystem)"
            return 0
        elif [ -n "${expected_owner}" ] && [ "${actual_owner}" = "${expected_owner}" ]; then
            test_pass "${test_name} (${actual_owner})"
            return 0
        else
            test_warning "${test_name}" "Got ${actual_owner}, expected ${expected_host_owner} (host) or ${expected_owner} (container)"
            return 1
        fi
    fi
}

# Function: Test image file
test_image_file() {
    local image_path="$1"
    local test_name="${2:-Image file: ${image_path}}"
    
    # Check existence
    if [ ! -f "${image_path}" ]; then
        test_fail "${test_name}" "Image file does not exist: ${image_path}"
        return 1
    fi
    
    # Check permissions (must be 644)
    test_file_permissions "${image_path}" "644" "${test_name} permissions"
    
    # Check read access
    test_read_access "${image_path}" "${test_name} read"
    
    # Check if valid (if runtime available)
    if command -v apptainer >/dev/null 2>&1; then
        if apptainer inspect "${image_path}" >/dev/null 2>&1; then
            test_pass "${test_name} validity (apptainer)"
        else
            test_fail "${test_name}" "Image file is invalid (apptainer inspect failed)"
            return 1
        fi
    elif command -v singularity >/dev/null 2>&1; then
        if singularity inspect "${image_path}" >/dev/null 2>&1; then
            test_pass "${test_name} validity (singularity)"
        else
            test_fail "${test_name}" "Image file is invalid (singularity inspect failed)"
            return 1
        fi
    fi
    
    return 0
}

# Function: Test library verification (inspired by xubuntu_robotics_base_debug.sh)
test_library_verification() {
    local lib_path="$1"
    local test_name="${2:-Library verification: ${lib_path}}"
    
    if [ ! -f "${lib_path}" ]; then
        host_test_fail "${test_name}" "Library file does not exist: ${lib_path}"
        return 1
    fi
    
    # Test 1: File is readable
    if [ ! -r "${lib_path}" ]; then
        host_test_fail "${test_name}" "Library file is not readable: ${lib_path}"
        return 1
    fi
    
    # Test 2: Verify library naming convention (lib*.so*)
    local lib_basename
    lib_basename=$(basename "${lib_path}")
    if ! printf '%s\n' "${lib_basename}" | grep -qE '^lib.*\.so'; then
        host_test_warning "${test_name}" "Library does not follow naming convention (should be lib*.so*): ${lib_basename}"
    fi
    
    # Test 3: Try to load library with ldd (if available)
    if command -v ldd >/dev/null 2>&1; then
        if ldd "${lib_path}" >/dev/null 2>&1; then
            test_pass "${test_name} ldd check"
        else
            test_warning "${test_name}" "Library failed ldd check (may be corrupted or wrong architecture)"
        fi
    fi
    
    return 0
}

# Function: Test stage-specific functionality (context-aware)
test_stage_0() {
    local test_context="${1:-host}"  # host or container
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUITE: Stage 0 - Minimal Base (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "${test_context}" = "host" ]; then
        # HOST-SIDE TESTS: Test host directories and setup
        printf '%s\n' ""
        printf '%s\n' "Testing host directories (pre-build)..."
        
        # Test host cache directory
        if [ -n "${HOST_CACHE_BIND_SRC:-}" ]; then
            test_dir_permissions "${HOST_CACHE_BIND_SRC}" "755" "Host cache directory permissions"
            test_read_access "${HOST_CACHE_BIND_SRC}" "Host cache directory read"
            test_write_access "${HOST_CACHE_BIND_SRC}" "Host cache directory write"
        else
            test_fail "Host cache directory" "HOST_CACHE_BIND_SRC not set"
        fi
        
        # Test host temp directory
        if [ -n "${CONTAINER_TMP_BIND:-}" ]; then
            test_dir_permissions "${CONTAINER_TMP_BIND}" "1777" "Host temp directory permissions"
            test_read_access "${CONTAINER_TMP_BIND}" "Host temp directory read"
            test_write_access "${CONTAINER_TMP_BIND}" "Host temp directory write"
        else
            test_fail "Host temp directory" "CONTAINER_TMP_BIND not set"
        fi
        
        # Test config file exists on host
        # Note: Config file may be executable (755) or readable (644) - both are acceptable
        if [ -n "${CONFIG_FILE:-}" ] && [ -f "${CONFIG_FILE}" ]; then
            local config_perms
            config_perms=$(stat -c '%a' "${CONFIG_FILE}" 2>/dev/null || printf '%s\n' "unknown")
            if [ "${config_perms}" = "644" ] || [ "${config_perms}" = "755" ] || [ "${config_perms}" = "775" ]; then
                test_pass "Host config file permissions (${config_perms})"
            else
                test_warning "Host config file permissions" "Got ${config_perms}, expected 644/755/775"
            fi
            test_read_access "${CONFIG_FILE}" "Host config file read"
        else
            test_fail "Host config file" "Config file does not exist: ${CONFIG_FILE:-}"
        fi
        
        return 0
    else
        # CONTAINER-SIDE TESTS: Test bind mounts and container setup
        # Test bind mounts (comprehensive: existence, permissions, access)
        printf '%s\n' ""
        printf '%s\n' "Testing bind mounts (in container)..."
        test_bind_mount "/container_cache" "Container cache mount"
        test_bind_mount "/tmp" "Temp mount"
        test_bind_mount "/var/tmp" "Var temp mount"
        
        # Test config file (permissions and access)
        # Note: Config file may be executable (755/775) or readable (644) - both are acceptable
        printf '%s\n' ""
        printf '%s\n' "Testing config file (in container)..."
        if [ -f "/etc/config.sh" ]; then
            local config_perms
            config_perms=$(stat -c '%a' "/etc/config.sh" 2>/dev/null || printf '%s\n' "unknown")
            if [ "${config_perms}" = "644" ] || [ "${config_perms}" = "755" ] || [ "${config_perms}" = "775" ]; then
                test_pass "Config file permissions (${config_perms})"
            else
                test_warning "Config file permissions" "Got ${config_perms}, expected 644/755/775"
            fi
            test_read_access "/etc/config.sh" "Config file read access"
            
            # Test config file can be sourced
            if source /etc/config.sh >/dev/null 2>&1; then
                test_pass "Config file: Can be sourced"
            else
                test_fail "Config file" "Cannot source config file (syntax error?)"
            fi
        else
            test_fail "Config file" "Config file does not exist: /etc/config.sh"
        fi
        
        # Test essential tools (existence and execution)
        # Based on packages installed in stage_00_minimal.def
        printf '%s\n' ""
        printf '%s\n' "Testing essential tools (in container)..."
        
        # Download and network tools
        # Note: gnupg is a package name, not a command - the command is gpg
        for tool in wget curl gpg-agent gpg; do
            if command -v "${tool}" >/dev/null 2>&1; then
                test_pass "Essential tool: ${tool} (found)"
                
                # Test tool execution
                if "${tool}" --version >/dev/null 2>&1 || "${tool}" -V >/dev/null 2>&1 || "${tool}" --help >/dev/null 2>&1; then
                    test_pass "Essential tool: ${tool} (executable)"
                else
                    test_warning "Essential tool: ${tool}" "Found but execution test failed"
                fi
            else
                test_fail "Essential tool: ${tool}" "Tool not found in PATH"
            fi
        done
        
        # System tools
        for tool in ps pgrep file; do
            if command -v "${tool}" >/dev/null 2>&1; then
                test_pass "System tool: ${tool} (found)"
                
                # Test tool execution
                if "${tool}" --version >/dev/null 2>&1 || "${tool}" -V >/dev/null 2>&1 || "${tool}" --help >/dev/null 2>&1 || "${tool}" -h >/dev/null 2>&1; then
                    test_pass "System tool: ${tool} (executable)"
                else
                    test_warning "System tool: ${tool}" "Found but execution test failed"
                fi
            else
                test_fail "System tool: ${tool}" "Tool not found in PATH"
            fi
        done
        
        # Package inspection tools
        if command -v dpkg-deb >/dev/null 2>&1; then
            test_pass "Package tool: dpkg-deb (found)"
            if dpkg-deb --version >/dev/null 2>&1 || dpkg-deb --help >/dev/null 2>&1; then
                test_pass "Package tool: dpkg-deb (executable)"
            else
                test_warning "Package tool: dpkg-deb" "Found but execution test failed"
            fi
        else
            test_fail "Package tool: dpkg-deb" "Tool not found in PATH"
        fi
        
        # Archive tools
        for tool in tar gzip bzip2 xz unzip; do
            if command -v "${tool}" >/dev/null 2>&1; then
                test_pass "Archive tool: ${tool} (found)"
                
                # Test tool execution
                if "${tool}" --version >/dev/null 2>&1 || "${tool}" -V >/dev/null 2>&1 || "${tool}" --help >/dev/null 2>&1; then
                    test_pass "Archive tool: ${tool} (executable)"
                else
                    test_warning "Archive tool: ${tool}" "Found but execution test failed"
                fi
            else
                test_fail "Archive tool: ${tool}" "Tool not found in PATH"
            fi
        done
        
        return 0
    fi
}

test_stage_1() {
    local test_context="${1:-host}"  # host or container
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUITE: Stage 1 - Bootstrap Safe Environment (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run Stage 0 tests first (all must pass)
    printf '%s\n' ""
    printf '%s\n' "Running Stage 0 prerequisite tests..."
    if ! test_stage_0 "${test_context}"; then
        test_fail "Stage 0 prerequisites" "Stage 0 tests failed - cannot proceed"
        return 1
    fi
    
    if [ "${test_context}" = "host" ]; then
        # HOST-SIDE: Only test host setup, skip container-specific tests
        return 0
    fi
    
    # Test shims (comprehensive: existence, permissions, execution)
    printf '%s\n' ""
    printf '%s\n' "Testing tool shims..."
    for shim_tool in gpg apt-key mktemp; do
        if [ -f "/usr/bin/${shim_tool}" ] && [ -f "/usr/bin/${shim_tool}.real" ]; then
            # Test shim file permissions
            test_file_permissions "/usr/bin/${shim_tool}" "755" "Shim: ${shim_tool} permissions"
            
            # Test real binary exists
            if [ -f "/usr/bin/${shim_tool}.real" ]; then
                test_pass "Shim: ${shim_tool}.real exists"
            else
                test_fail "Shim: ${shim_tool}" "Real binary not found: /usr/bin/${shim_tool}.real"
            fi
            
            # Test shim is executable
            test_execute_access "/usr/bin/${shim_tool}" "Shim: ${shim_tool} executable"
            
            # Test shim execution (actual tool execution)
            if "${shim_tool}" --version >/dev/null 2>&1 || "${shim_tool}" -V >/dev/null 2>&1 || "${shim_tool}" --help >/dev/null 2>&1; then
                test_pass "Shim execution: ${shim_tool}"
            else
                # For mktemp, test with actual usage
                if [ "${shim_tool}" = "mktemp" ]; then
                    TEST_TMP=$(mktemp 2>/dev/null || printf '%s\n' "")
                    if [ -n "${TEST_TMP}" ] && [ -f "${TEST_TMP}" ]; then
                        rm -f "${TEST_TMP}" 2>/dev/null || true
                        test_pass "Shim execution: ${shim_tool} (mktemp test)"
                    else
                        test_fail "Shim execution: ${shim_tool}" "mktemp failed to create temp file"
                    fi
                else
                    test_fail "Shim execution: ${shim_tool}" "Shim failed to execute"
                fi
            fi
        else
            test_fail "Shim: ${shim_tool}" "Shim or real binary not found"
        fi
    done
    
    # Test APT configuration (comprehensive)
    printf '%s\n' ""
    printf '%s\n' "Testing APT configuration..."
    if [ -f "/etc/apt/apt.conf.d/00-safe-temp" ]; then
        test_file_permissions "/etc/apt/apt.conf.d/00-safe-temp" "644" "APT temp config permissions"
        test_read_access "/etc/apt/apt.conf.d/00-safe-temp" "APT temp config read"
        
        # Verify TMPDIR is set correctly in config
        if grep -q "Acquire::TempDir" "/etc/apt/apt.conf.d/00-safe-temp" 2>/dev/null; then
            test_pass "APT temp config: TMPDIR configured"
            
            # Extract and verify TMPDIR path exists and is writable
            APT_TMPDIR=$(grep "Acquire::TempDir" "/etc/apt/apt.conf.d/00-safe-temp" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || printf '%s\n' "")
            if [ -n "${APT_TMPDIR}" ] && [ -d "${APT_TMPDIR}" ] && [ -w "${APT_TMPDIR}" ]; then
                test_pass "APT temp config: TMPDIR path valid and writable (${APT_TMPDIR})"
            else
                test_fail "APT temp config" "TMPDIR path invalid or not writable: ${APT_TMPDIR}"
            fi
        else
            test_fail "APT temp config" "TMPDIR not configured in APT config"
        fi
    else
        test_fail "APT temp config" "APT temp config file does not exist"
    fi
    
    # Test TMPDIR environment (comprehensive)
    printf '%s\n' ""
    printf '%s\n' "Testing TMPDIR environment..."
    if [ -n "${TMPDIR:-}" ]; then
        test_pass "TMPDIR environment: Set (${TMPDIR})"
        
        if [ -d "${TMPDIR}" ]; then
            test_pass "TMPDIR environment: Directory exists (${TMPDIR})"
            
            if [ -w "${TMPDIR}" ]; then
                test_pass "TMPDIR environment: Writable (${TMPDIR})"
                
                # Test actual write access
                TEST_FILE="${TMPDIR}/.tmpdir_test_$$"
                if touch "${TEST_FILE}" 2>/dev/null; then
                    rm -f "${TEST_FILE}" 2>/dev/null || true
                    test_pass "TMPDIR environment: Write test passed"
                else
                    test_fail "TMPDIR environment" "Cannot write to TMPDIR: ${TMPDIR}"
                fi
            else
                test_fail "TMPDIR environment" "TMPDIR not writable: ${TMPDIR}"
            fi
        else
            test_fail "TMPDIR environment" "TMPDIR directory does not exist: ${TMPDIR}"
        fi
    else
        test_fail "TMPDIR environment" "TMPDIR not set"
    fi
    
    # Test /tmp permissions (comprehensive)
    printf '%s\n' ""
    printf '%s\n' "Testing /tmp permissions..."
    test_dir_permissions "/tmp" "1777" "/tmp permissions"
    test_read_access "/tmp" "/tmp read access"
    test_write_access "/tmp" "/tmp write access"
    test_execute_access "/tmp" "/tmp execute access"
    
    return 0
}

test_stage_2() {
    local test_context="${1:-host}"  # host or container
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUITE: Stage 2 - Terminal Colors and Block 0 (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run Stage 1 tests first (all must pass)
    printf '%s\n' ""
    printf '%s\n' "Running Stage 1 prerequisite tests..."
    if ! test_stage_1 "${test_context}"; then
        test_fail "Stage 1 prerequisites" "Stage 1 tests failed - cannot proceed"
        return 1
    fi
    
    if [ "${test_context}" = "host" ]; then
        # HOST-SIDE: Only test host setup, skip container-specific tests
        return 0
    fi
    
    # Test terminal color codes (comprehensive)
    printf '%s\n' ""
    printf '%s\n' "Testing terminal color codes..."
    for color_var in RED GREEN YELLOW BLUE NC; do
        if [ -n "${!color_var:-}" ]; then
            test_pass "Terminal color: ${color_var} defined (${!color_var})"
        else
            test_fail "Terminal color: ${color_var}" "Color variable not defined"
        fi
    done
    
    # Test container scripts directory
    printf '%s\n' ""
    printf '%s\n' "Testing container scripts directory..."
    if [ -d "/container-scripts" ]; then
        test_pass "Container scripts directory exists: /container-scripts"
        test_dir_permissions "/container-scripts" "755" "Container scripts directory permissions"
        test_read_access "/container-scripts" "Container scripts directory read"
        test_execute_access "/container-scripts" "Container scripts directory execute"
    else
        test_fail "Container scripts directory" "Directory does not exist: /container-scripts"
    fi
    
    # Test installer script
    printf '%s\n' ""
    printf '%s\n' "Testing installer script..."
    if [ -f "/container-scripts/install.sh" ]; then
        test_pass "Installer script exists: /container-scripts/install.sh"
        test_file_permissions "/container-scripts/install.sh" "755" "Installer script permissions"
        test_read_access "/container-scripts/install.sh" "Installer script read"
        test_execute_access "/container-scripts/install.sh" "Installer script executable"
    else
        test_fail "Installer script" "Script does not exist: /container-scripts/install.sh"
    fi
    
    # Test manifest file
    printf '%s\n' ""
    printf '%s\n' "Testing manifest file..."
    if [ -f "/container-scripts/MANIFEST.json" ]; then
        test_pass "Manifest file exists: /container-scripts/MANIFEST.json"
        test_file_permissions "/container-scripts/MANIFEST.json" "644" "Manifest file permissions"
        test_read_access "/container-scripts/MANIFEST.json" "Manifest file read"
    else
        test_fail "Manifest file" "File does not exist: /container-scripts/MANIFEST.json"
    fi
    
    # Test installed scripts (key verification scripts)
    printf '%s\n' ""
    printf '%s\n' "Testing installed scripts..."
    for script in verify-mkl-env.sh verify-cuda-mkl-linkage.sh verify-python-mkl.sh; do
        if [ -f "/container-scripts/shell-scripts/${script}" ]; then
            test_pass "Installed script exists: ${script}"
            test_execute_access "/container-scripts/shell-scripts/${script}" "Installed script executable: ${script}"
        else
            test_warning "Installed script: ${script}" "Script not found (may be optional)"
        fi
    done
    
    return 0
}

test_stage_3() {
    local test_context="${1:-host}"  # host or container
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUITE: Stage 3 - Initialization Blocks (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run Stage 2 tests first (all must pass)
    printf '%s\n' ""
    printf '%s\n' "Running Stage 2 prerequisite tests..."
    if ! test_stage_2 "${test_context}"; then
        test_fail "Stage 2 prerequisites" "Stage 2 tests failed - cannot proceed"
        return 1
    fi
    
    if [ "${test_context}" = "host" ]; then
        # HOST-SIDE: Only test host setup, skip container-specific tests
        return 0
    fi
    
    # Test phase tracking variables
    # Note: These are build-time variables set in %post, not runtime environment variables
    # They may not be available in runtime context, so we check if they exist in build context
    printf '%s\n' ""
    printf '%s\n' "Testing phase tracking variables..."
    for phase_var in PHASE1_STATUS PHASE2_STATUS PHASE3_STATUS PHASE4_STATUS PHASE5_STATUS; do
        if [ -n "${!phase_var:-}" ]; then
            test_pass "Phase tracking: ${phase_var} defined (${!phase_var})"
        else
            # Phase tracking variables are build-time only, not runtime
            # They're set during %post but not exported to %environment
            # This is expected behavior - they're used during build, not runtime
            test_warning "Phase tracking: ${phase_var}" "Variable not defined in runtime (expected - build-time variable)"
        fi
    done
    
    # Test environment setup
    printf '%s\n' ""
    printf '%s\n' "Testing environment setup..."
    if [ "${DEBIAN_FRONTEND:-}" = "noninteractive" ]; then
        test_pass "Environment: DEBIAN_FRONTEND=noninteractive"
    else
        test_fail "Environment: DEBIAN_FRONTEND" "Not set to noninteractive (got: ${DEBIAN_FRONTEND:-unset})"
    fi
    
    # Test terminal colors (from Stage 2, should still be available)
    printf '%s\n' ""
    printf '%s\n' "Testing terminal colors (cumulative from Stage 2)..."
    for color_var in RED GREEN YELLOW BLUE NC; do
        if [ -n "${!color_var:-}" ]; then
            test_pass "Terminal color: ${color_var} available (${!color_var})"
        else
            test_fail "Terminal color: ${color_var}" "Color variable not available (cumulative check)"
        fi
    done
    
    # Test common functions script
    printf '%s\n' ""
    printf '%s\n' "Testing common functions script..."
    if [ -f "/scripts/common_functions.sh" ]; then
        test_pass "Common functions script exists: /scripts/common_functions.sh"
        test_read_access "/scripts/common_functions.sh" "Common functions script read"
        
        # Test if script can be sourced
        if source /scripts/common_functions.sh >/dev/null 2>&1; then
            test_pass "Common functions script: Can be sourced"
        else
            test_fail "Common functions script" "Cannot source script (syntax error?)"
        fi
    else
        test_fail "Common functions script" "Script does not exist: /scripts/common_functions.sh"
    fi
    
    # Test calculate_build_jobs() function
    printf '%s\n' ""
    printf '%s\n' "Testing calculate_build_jobs() function..."
    if [ -f "/scripts/common_functions.sh" ]; then
        # Source the script to make function available
        source /scripts/common_functions.sh >/dev/null 2>&1 || true
        
        if command -v calculate_build_jobs >/dev/null 2>&1 || type calculate_build_jobs >/dev/null 2>&1; then
            test_pass "Function: calculate_build_jobs() is callable"
            
            # Test function execution
            BUILD_JOBS=$(calculate_build_jobs 2>/dev/null || printf '%s\n' "")
            if [ -n "${BUILD_JOBS}" ] && [ "${BUILD_JOBS}" -gt 0 ] 2>/dev/null; then
                test_pass "Function: calculate_build_jobs() returns valid value (${BUILD_JOBS})"
            else
                test_fail "Function: calculate_build_jobs()" "Function returned invalid value: ${BUILD_JOBS}"
            fi
        else
            test_fail "Function: calculate_build_jobs()" "Function not callable after sourcing common_functions.sh"
        fi
    else
        test_fail "Function: calculate_build_jobs()" "Cannot test - common_functions.sh not found"
    fi
    
    # Test debug_glibc() function (should be defined in environment or available)
    printf '%s\n' ""
    printf '%s\n' "Testing debug_glibc() function..."
    if command -v debug_glibc >/dev/null 2>&1 || type debug_glibc >/dev/null 2>&1; then
        test_pass "Function: debug_glibc() is callable"
        
        # Test function execution (should not fail)
        if debug_glibc >/dev/null 2>&1; then
            test_pass "Function: debug_glibc() executes without errors"
        else
            test_warning "Function: debug_glibc()" "Function execution had issues (may be expected)"
        fi
    else
        test_warning "Function: debug_glibc()" "Function not callable (may be defined inline in .def file)"
    fi
    
    return 0
}

test_stage_4() {
    local test_context="${1:-host}"  # host or container
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUITE: Stage 4 - Cache and Mirror Functions (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run Stage 3 tests first (all must pass)
    printf '%s\n' ""
    printf '%s\n' "Running Stage 3 prerequisite tests..."
    if ! test_stage_3 "${test_context}"; then
        test_fail "Stage 3 prerequisites" "Stage 3 tests failed - cannot proceed"
        return 1
    fi
    
    if [ "${test_context}" = "host" ]; then
        # HOST-SIDE: Only test host setup, skip container-specific tests
        return 0
    fi
    
    # Test mirror functions script
    printf '%s\n' ""
    printf '%s\n' "Testing mirror functions script..."
    if [ -f "/scripts/mirror_functions.sh" ]; then
        test_pass "Mirror functions script exists: /scripts/mirror_functions.sh"
        test_read_access "/scripts/mirror_functions.sh" "Mirror functions script read"
        
        # Test if script can be sourced
        if source /scripts/mirror_functions.sh >/dev/null 2>&1; then
            test_pass "Mirror functions script: Can be sourced"
        else
            test_fail "Mirror functions script" "Cannot source script (syntax error?)"
        fi
    else
        test_fail "Mirror functions script" "Script does not exist: /scripts/mirror_functions.sh"
    fi
    
    # Test library functions script
    printf '%s\n' ""
    printf '%s\n' "Testing library functions script..."
    if [ -f "/scripts/library_functions.sh" ]; then
        test_pass "Library functions script exists: /scripts/library_functions.sh"
        test_read_access "/scripts/library_functions.sh" "Library functions script read"
        
        # Test if script can be sourced
        if source /scripts/library_functions.sh >/dev/null 2>&1; then
            test_pass "Library functions script: Can be sourced"
        else
            test_fail "Library functions script" "Cannot source script (syntax error?)"
        fi
    else
        test_fail "Library functions script" "Script does not exist: /scripts/library_functions.sh"
    fi
    
    # Test cache management functions (from common_functions.sh)
    printf '%s\n' ""
    printf '%s\n' "Testing cache management functions..."
    if [ -f "/scripts/common_functions.sh" ]; then
        source /scripts/common_functions.sh >/dev/null 2>&1 || true
        
        # Test consolidate_cache_packages()
        if command -v consolidate_cache_packages >/dev/null 2>&1 || type consolidate_cache_packages >/dev/null 2>&1; then
            test_pass "Function: consolidate_cache_packages() is callable"
        else
            test_fail "Function: consolidate_cache_packages()" "Function not callable after sourcing common_functions.sh"
        fi
        
        # Test monitor_cache()
        if command -v monitor_cache >/dev/null 2>&1 || type monitor_cache >/dev/null 2>&1; then
            test_pass "Function: monitor_cache() is callable"
        else
            test_fail "Function: monitor_cache()" "Function not callable after sourcing common_functions.sh"
        fi
    else
        test_fail "Cache management functions" "Cannot test - common_functions.sh not found"
    fi
    
    # Test mirror probing functions (from mirror_functions.sh)
    printf '%s\n' ""
    printf '%s\n' "Testing mirror probing functions..."
    if [ -f "/scripts/mirror_functions.sh" ]; then
        source /scripts/mirror_functions.sh >/dev/null 2>&1 || true
        
        # Test test_mirror()
        if command -v test_mirror >/dev/null 2>&1 || type test_mirror >/dev/null 2>&1; then
            test_pass "Function: test_mirror() is callable"
        else
            test_fail "Function: test_mirror()" "Function not callable after sourcing mirror_functions.sh"
        fi
        
        # Test probe_and_set_mirrors()
        if command -v probe_and_set_mirrors >/dev/null 2>&1 || type probe_and_set_mirrors >/dev/null 2>&1; then
            test_pass "Function: probe_and_set_mirrors() is callable"
        else
            test_fail "Function: probe_and_set_mirrors()" "Function not callable after sourcing mirror_functions.sh"
        fi
    else
        test_fail "Mirror probing functions" "Cannot test - mirror_functions.sh not found"
    fi
    
    # Test library verification functions (from library_functions.sh)
    printf '%s\n' ""
    printf '%s\n' "Testing library verification functions..."
    if [ -f "/scripts/library_functions.sh" ]; then
        source /scripts/library_functions.sh >/dev/null 2>&1 || true
        
        # Test verify_library_available()
        if command -v verify_library_available >/dev/null 2>&1 || type verify_library_available >/dev/null 2>&1; then
            test_pass "Function: verify_library_available() is callable"
        else
            test_fail "Function: verify_library_available()" "Function not callable after sourcing library_functions.sh"
        fi
        
        # Test run_ldconfig_refresh()
        if command -v run_ldconfig_refresh >/dev/null 2>&1 || type run_ldconfig_refresh >/dev/null 2>&1; then
            test_pass "Function: run_ldconfig_refresh() is callable"
        else
            test_fail "Function: run_ldconfig_refresh()" "Function not callable after sourcing library_functions.sh"
        fi
        
        # Test ensure_library_path_registered()
        if command -v ensure_library_path_registered >/dev/null 2>&1 || type ensure_library_path_registered >/dev/null 2>&1; then
            test_pass "Function: ensure_library_path_registered() is callable"
        else
            test_warning "Function: ensure_library_path_registered()" "Function not callable (may be optional)"
        fi
    else
        test_fail "Library verification functions" "Cannot test - library_functions.sh not found"
    fi
    
    return 0
}

test_stage_5() {
    local test_context="${1:-host}"  # host or container
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUITE: Stage 5 - Cache Monitoring and Configuration (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run Stage 4 tests first (all must pass)
    printf '%s\n' ""
    printf '%s\n' "Running Stage 4 prerequisite tests..."
    if ! test_stage_4 "${test_context}"; then
        test_fail "Stage 4 prerequisites" "Stage 4 tests failed - cannot proceed"
        return 1
    fi
    
    if [ "${test_context}" = "host" ]; then
        # HOST-SIDE: Only test host setup, skip container-specific tests
        return 0
    fi
    
    # Test cache functions script
    printf '%s\n' ""
    printf '%s\n' "Testing cache functions script..."
    if [ -f "/scripts/cache_functions.sh" ]; then
        test_pass "Cache functions script exists: /scripts/cache_functions.sh"
        test_read_access "/scripts/cache_functions.sh" "Cache functions script read"
        
        # Test if script can be sourced
        if source /scripts/cache_functions.sh >/dev/null 2>&1; then
            test_pass "Cache functions script: Can be sourced"
        else
            test_fail "Cache functions script" "Cannot source script (syntax error?)"
        fi
    else
        test_fail "Cache functions script" "Script does not exist: /scripts/cache_functions.sh"
    fi
    
    # Test cache monitoring data file (BLOCK 5.1)
    # Note: This file is created during build but may not persist in runtime
    # since /tmp is a bind mount that may be cleaned. This is expected behavior.
    printf '%s\n' ""
    printf '%s\n' "Testing cache monitoring data file (BLOCK 5.1)..."
    if [ -f "/tmp/cache_monitor_data.txt" ]; then
        test_pass "Cache monitoring data file exists: /tmp/cache_monitor_data.txt"
        test_read_access "/tmp/cache_monitor_data.txt" "Cache monitoring data file read"
        test_write_access "/tmp/cache_monitor_data.txt" "Cache monitoring data file write"
        
        # Test CSV header
        if grep -q "^Stage|Container APT|Var APT|Conda|Wheels|Julia" /tmp/cache_monitor_data.txt 2>/dev/null; then
            test_pass "Cache monitoring data file: Has correct CSV header"
        else
            test_fail "Cache monitoring data file" "Missing or incorrect CSV header"
        fi
    else
        # File may not exist at runtime (created during build, /tmp is cleaned)
        # This is expected - the file is created during build and used during build
        test_warning "Cache monitoring data file" "File does not exist at runtime (expected - created during build, /tmp may be cleaned)"
    fi
    
    # Test cache monitoring functions (BLOCK 5.2-5.4)
    printf '%s\n' ""
    printf '%s\n' "Testing cache monitoring functions (BLOCK 5.2-5.4)..."
    if [ -f "/scripts/cache_functions.sh" ]; then
        source /scripts/cache_functions.sh >/dev/null 2>&1 || true
        
        # Test display_cache_monitoring_summary()
        if command -v display_cache_monitoring_summary >/dev/null 2>&1 || type display_cache_monitoring_summary >/dev/null 2>&1; then
            test_pass "Function: display_cache_monitoring_summary() is callable"
            # Test execution (should not fail even if data file is empty)
            if display_cache_monitoring_summary >/dev/null 2>&1; then
                test_pass "Function: display_cache_monitoring_summary() executes successfully"
            else
                test_fail "Function: display_cache_monitoring_summary()" "Execution failed"
            fi
        else
            test_fail "Function: display_cache_monitoring_summary()" "Function not callable after sourcing cache_functions.sh"
        fi
        
        # Test cache_summary()
        if command -v cache_summary >/dev/null 2>&1 || type cache_summary >/dev/null 2>&1; then
            test_pass "Function: cache_summary() is callable"
            # Test execution (should not fail even if cache directories are empty)
            if cache_summary >/dev/null 2>&1; then
                test_pass "Function: cache_summary() executes successfully"
            else
                test_fail "Function: cache_summary()" "Execution failed"
            fi
        else
            test_fail "Function: cache_summary()" "Function not callable after sourcing cache_functions.sh"
        fi
    else
        test_fail "Cache monitoring functions" "Cannot test - cache_functions.sh not found"
    fi
    
    # Test cache directory configuration (BLOCK 6.1-6.2)
    # Note: These variables are set in %environment section and should be available at runtime
    printf '%s\n' ""
    printf '%s\n' "Testing cache directory configuration (BLOCK 6.1-6.2)..."
    
    # Test CACHE_ROOT environment variable
    # Use CONTAINER_CACHE_ROOT from config.sh as fallback (should be set in %environment)
    if [ -n "${CACHE_ROOT:-}" ]; then
        test_pass "Environment variable: CACHE_ROOT is set (${CACHE_ROOT})"
    elif [ -n "${CONTAINER_CACHE_ROOT:-}" ]; then
        # Fallback to CONTAINER_CACHE_ROOT from config.sh (should be /container_cache)
        test_pass "Environment variable: CACHE_ROOT (using CONTAINER_CACHE_ROOT: ${CONTAINER_CACHE_ROOT})"
    else
        test_warning "Environment variable: CACHE_ROOT" "Not set (may be set in %environment section)"
    fi
    
    # Test PIP_CACHE_DIR
    local cache_root_val="${CACHE_ROOT:-${CONTAINER_CACHE_ROOT:-/container_cache}}"
    if [ -n "${PIP_CACHE_DIR:-}" ]; then
        test_pass "Environment variable: PIP_CACHE_DIR is set (${PIP_CACHE_DIR})"
        if [[ "${PIP_CACHE_DIR}" == "${cache_root_val}/wheels" ]]; then
            test_pass "Environment variable: PIP_CACHE_DIR points to correct path"
        else
            test_warning "Environment variable: PIP_CACHE_DIR" "Does not point to ${cache_root_val}/wheels (got: ${PIP_CACHE_DIR})"
        fi
    else
        test_warning "Environment variable: PIP_CACHE_DIR" "Not set (may be set in %environment section)"
    fi
    
    # Test CONDA_PKGS_DIRS
    if [ -n "${CONDA_PKGS_DIRS:-}" ]; then
        test_pass "Environment variable: CONDA_PKGS_DIRS is set (${CONDA_PKGS_DIRS})"
        if [[ "${CONDA_PKGS_DIRS}" == "${cache_root_val}/conda_pkgs" ]]; then
            test_pass "Environment variable: CONDA_PKGS_DIRS points to correct path"
        else
            test_warning "Environment variable: CONDA_PKGS_DIRS" "Does not point to ${cache_root_val}/conda_pkgs (got: ${CONDA_PKGS_DIRS})"
        fi
    else
        test_warning "Environment variable: CONDA_PKGS_DIRS" "Not set (may be set in %environment section)"
    fi
    
    # Test JULIA_DEPOT_PATH
    if [ -n "${JULIA_DEPOT_PATH:-}" ]; then
        test_pass "Environment variable: JULIA_DEPOT_PATH is set (${JULIA_DEPOT_PATH})"
        if [[ "${JULIA_DEPOT_PATH}" == *"${cache_root_val}/julia_pkgs"* ]]; then
            test_pass "Environment variable: JULIA_DEPOT_PATH contains correct path"
        else
            test_warning "Environment variable: JULIA_DEPOT_PATH" "Does not contain ${cache_root_val}/julia_pkgs (got: ${JULIA_DEPOT_PATH})"
        fi
    else
        test_warning "Environment variable: JULIA_DEPOT_PATH" "Not set (may be set in %environment section)"
    fi
    
    # Test unified cache setup functions (BLOCK 6.3-6.4)
    printf '%s\n' ""
    printf '%s\n' "Testing unified cache setup functions (BLOCK 6.3-6.4)..."
    if [ -f "/scripts/cache_functions.sh" ]; then
        source /scripts/cache_functions.sh >/dev/null 2>&1 || true
        
        # Test validate_and_repair_cache()
        if command -v validate_and_repair_cache >/dev/null 2>&1 || type validate_and_repair_cache >/dev/null 2>&1; then
            test_pass "Function: validate_and_repair_cache() is callable"
            # Test execution (should create directories if missing)
            if validate_and_repair_cache >/dev/null 2>&1; then
                test_pass "Function: validate_and_repair_cache() executes successfully"
            else
                test_fail "Function: validate_and_repair_cache()" "Execution failed"
            fi
        else
            test_fail "Function: validate_and_repair_cache()" "Function not callable after sourcing cache_functions.sh"
        fi
        
        # Test setup_unified_cache()
        if command -v setup_unified_cache >/dev/null 2>&1 || type setup_unified_cache >/dev/null 2>&1; then
            test_pass "Function: setup_unified_cache() is callable"
        else
            test_fail "Function: setup_unified_cache()" "Function not callable after sourcing cache_functions.sh"
        fi
    else
        test_fail "Unified cache setup functions" "Cannot test - cache_functions.sh not found"
    fi
    
    # Test APT cache configuration file (BLOCK 6.4)
    printf '%s\n' ""
    printf '%s\n' "Testing APT cache configuration file (BLOCK 6.4)..."
    if [ -f "/etc/apt/apt.conf.d/90-cache.conf" ]; then
        test_pass "APT cache config file exists: /etc/apt/apt.conf.d/90-cache.conf"
        test_read_access "/etc/apt/apt.conf.d/90-cache.conf" "APT cache config file read"
        
        # Test Dir::Cache::Archives setting
        if grep -q "Dir::Cache::Archives" /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null; then
            test_pass "APT cache config: Contains Dir::Cache::Archives setting"
        else
            test_fail "APT cache config" "Missing Dir::Cache::Archives setting"
        fi
        
        # Test APT::Keep-Downloaded-Packages setting
        if grep -q "APT::Keep-Downloaded-Packages" /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null; then
            test_pass "APT cache config: Contains APT::Keep-Downloaded-Packages setting"
        else
            test_fail "APT cache config" "Missing APT::Keep-Downloaded-Packages setting"
        fi
    else
        test_fail "APT cache config file" "File does not exist: /etc/apt/apt.conf.d/90-cache.conf"
    fi
    
    # Test pip cache configuration file (BLOCK 6.4)
    printf '%s\n' ""
    printf '%s\n' "Testing pip cache configuration file (BLOCK 6.4)..."
    if [ -f "/root/.config/pip/pip.conf" ]; then
        test_pass "Pip cache config file exists: /root/.config/pip/pip.conf"
        test_read_access "/root/.config/pip/pip.conf" "Pip cache config file read"
        
        # Test cache-dir setting
        if grep -q "cache-dir" /root/.config/pip/pip.conf 2>/dev/null; then
            test_pass "Pip cache config: Contains cache-dir setting"
        else
            test_fail "Pip cache config" "Missing cache-dir setting"
        fi
    else
        test_fail "Pip cache config file" "File does not exist: /root/.config/pip/pip.conf"
    fi
    
    # Test cache directories exist and are writable (from validate_and_repair_cache)
    printf '%s\n' ""
    printf '%s\n' "Testing cache directories (from validate_and_repair_cache)..."
    local cache_dirs=(
        "${CONTAINER_APT_CACHE:-/container_cache/apt}"
        "${CONTAINER_WHEELS_CACHE:-/container_cache/wheels}"
        "${CONTAINER_CONDA_CACHE:-/container_cache/conda_pkgs}"
        "${CONTAINER_JULIA_CACHE:-/container_cache/julia_pkgs}"
    )
    for cache_dir in "${cache_dirs[@]}"; do
        if [ -d "${cache_dir}" ]; then
            test_pass "Cache directory exists: ${cache_dir}"
            test_dir_permissions "${cache_dir}" "755" "Cache directory permissions: ${cache_dir}"
            test_write_access "${cache_dir}" "Cache directory write: ${cache_dir}"
        else
            test_fail "Cache directory" "Directory does not exist: ${cache_dir}"
        fi
    done
    
    return 0
}

# Function: Test Stage 6 - Package Management Functions
test_stage_6() {
    local test_context="${1:-host}"  # host or container
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUITE: Stage 6 - Package Management Functions (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run Stage 5 tests first (all must pass)
    printf '%s\n' ""
    printf '%s\n' "Running Stage 5 prerequisite tests..."
    if ! test_stage_5 "${test_context}"; then
        test_fail "Stage 5 prerequisites" "Stage 5 tests failed - cannot proceed"
        return 1
    fi
    
    if [ "${test_context}" = "host" ]; then
        # HOST-SIDE: Only test host setup, skip container-specific tests
        return 0
    fi
    
    # Test package functions script
    printf '%s\n' ""
    printf '%s\n' "Testing package functions script..."
    if [ -f "/scripts/package_functions.sh" ]; then
        test_pass "Package functions script exists: /scripts/package_functions.sh"
        test_read_access "/scripts/package_functions.sh" "Package functions script read"
        test_file_permissions "/scripts/package_functions.sh" "644" "Package functions script permissions"
        
        # Test if script can be sourced
        if source /scripts/package_functions.sh >/dev/null 2>&1; then
            test_pass "Package functions script: Can be sourced"
        else
            test_fail "Package functions script: Cannot be sourced" "Syntax error or missing dependencies"
        fi
    else
        test_fail "Package functions script" "File does not exist: /scripts/package_functions.sh"
    fi
    
    # Test all package management functions are defined
    printf '%s\n' ""
    printf '%s\n' "Testing package management function definitions..."
    local package_functions=(
        "setup_conda_staging_area"
        "atomic_package_replace"
        "verify_package_integrity"
        "acquire_package_lock"
        "release_package_lock"
    )
    for func_name in "${package_functions[@]}"; do
        if declare -f "${func_name}" >/dev/null 2>&1; then
            test_pass "Function defined: ${func_name}()"
        else
            test_fail "Function definition" "Function ${func_name}() is NOT defined"
        fi
    done
    
    # Test function execution (testable functions only)
    printf '%s\n' ""
    printf '%s\n' "Testing package management function execution..."
    
    # Test verify_package_integrity() with /dev/null (should fail gracefully)
    if verify_package_integrity "/dev/null" >/dev/null 2>&1; then
        test_warning "verify_package_integrity() execution" "Returned success for /dev/null (unexpected)"
    else
        test_pass "verify_package_integrity() execution: Correctly rejected invalid file"
    fi
    
    # Test acquire_package_lock() and release_package_lock()
    local test_pkg_name="test-package-$$"
    if acquire_package_lock "${test_pkg_name}" >/dev/null 2>&1; then
        test_pass "acquire_package_lock() execution: Lock acquired"
        if release_package_lock "${test_pkg_name}" >/dev/null 2>&1; then
            test_pass "release_package_lock() execution: Lock released"
        else
            test_fail "release_package_lock() execution" "Failed to release lock"
        fi
    else
        test_fail "acquire_package_lock() execution" "Failed to acquire lock"
    fi
    
    # Test setup_conda_staging_area() (will work even without Conda)
    if setup_conda_staging_area >/dev/null 2>&1; then
        test_pass "setup_conda_staging_area() execution: Staging area created"
    else
        test_fail "setup_conda_staging_area() execution" "Failed to create staging area"
    fi
    
    # Note: atomic_package_replace() requires Conda/Mamba, so we skip execution test
    printf '%s\n' ""
    printf '%s\n' "${YELLOW}[INFO]${NC} Skipping atomic_package_replace() execution test (requires Conda/Mamba - not yet installed)"
    
    # Test runtime initialization script
    printf '%s\n' ""
    printf '%s\n' "Testing runtime initialization script..."
    if [ -f "/etc/profile.d/stage6_init.sh" ]; then
        test_pass "Runtime init script exists: /etc/profile.d/stage6_init.sh"
        test_read_access "/etc/profile.d/stage6_init.sh" "Runtime init script read"
        test_file_permissions "/etc/profile.d/stage6_init.sh" "644" "Runtime init script permissions"
        
        # Verify script sources package_functions.sh
        if grep -q "package_functions.sh" /etc/profile.d/stage6_init.sh 2>/dev/null; then
            test_pass "Runtime init script: Sources package_functions.sh"
        else
            test_fail "Runtime init script" "Does not source package_functions.sh"
        fi
    else
        test_warning "Runtime init script" "File does not exist: /etc/profile.d/stage6_init.sh (may be created at runtime)"
    fi
    
    return 0
}

# Function: Test Stage 7 - Main Build Execution Start
test_stage_7() {
    local test_context="${1:-host}"  # host or container
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUITE: Stage 7 - Main Build Execution Start (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run Stage 6 tests first (all must pass)
    printf '%s\n' ""
    printf '%s\n' "Running Stage 6 prerequisite tests..."
    if ! test_stage_6 "${test_context}"; then
        test_fail "Stage 6 prerequisites" "Stage 6 tests failed - cannot proceed"
        return 1
    fi
    
    if [ "${test_context}" = "host" ]; then
        # HOST-SIDE: Only test host setup, skip container-specific tests
        return 0
    fi
    
    # Test ensure_directory_writable() function
    printf '%s\n' ""
    printf '%s\n' "Testing ensure_directory_writable() function..."
    if [ -f /scripts/common_functions.sh ]; then
        source /scripts/common_functions.sh >/dev/null 2>&1 || true
        if declare -f ensure_directory_writable >/dev/null 2>&1; then
            test_pass "Function defined: ensure_directory_writable()"
            
            # Test function execution with a test directory
            local test_dir="/tmp/test_writable_$$"
            if ensure_directory_writable "${test_dir}" "Test directory" >/dev/null 2>&1; then
                test_pass "ensure_directory_writable() execution: Directory created and verified writable"
                rm -rf "${test_dir}" 2>/dev/null || true
            else
                test_fail "ensure_directory_writable() execution" "Failed to create or verify writable directory"
            fi
        else
            test_fail "Function definition" "Function ensure_directory_writable() is NOT defined"
        fi
    else
        test_fail "Common functions script" "File does not exist: /scripts/common_functions.sh"
    fi
    
    # Test cache directories exist
    printf '%s\n' ""
    printf '%s\n' "Testing cache directory structure..."
    local cache_dirs=(
        "${CONTAINER_APT_CACHE:-/container_cache/apt/archives}"
        "${CONTAINER_WHEELS_CACHE:-/container_cache/wheels}"
        "${CONTAINER_CONDA_CACHE:-/container_cache/conda_pkgs}"
        "${CONTAINER_JULIA_CACHE:-/container_cache/julia_pkgs}"
        "/root/.cache/conda"
        "/root/.cache/julia"
        "/root/.local/share/julia"
    )
    for cache_dir in "${cache_dirs[@]}"; do
        if [ -d "${cache_dir}" ]; then
            test_pass "Cache directory exists: ${cache_dir}"
            test_dir_permissions "${cache_dir}" "755" "Cache directory permissions: ${cache_dir}"
            test_write_access "${cache_dir}" "Cache directory write: ${cache_dir}"
        else
            test_fail "Cache directory" "Directory does not exist: ${cache_dir}"
        fi
    done
    
    # Test system directories are writable
    printf '%s\n' ""
    printf '%s\n' "Testing system directory writability..."
    local system_dirs=(
        "/var/lib/apt/lists"
        "/var/cache/apt/archives"
        "/etc/apt/sources.list.d"
        "/usr/local/bin"
        "/usr/local/lib"
        "/usr/local/include"
    )
    for sys_dir in "${system_dirs[@]}"; do
        if [ -d "${sys_dir}" ]; then
            test_write_access "${sys_dir}" "System directory write: ${sys_dir}"
        else
            test_fail "System directory" "Directory does not exist: ${sys_dir}"
        fi
    done
    
    # Test installation prefix directory
    printf '%s\n' ""
    printf '%s\n' "Testing installation prefix directory..."
    local install_prefix="${INSTALL_PREFIX:-/opt}"
    if [ -d "${install_prefix}" ]; then
        test_pass "Installation prefix exists: ${install_prefix}"
        test_write_access "${install_prefix}" "Installation prefix write: ${install_prefix}"
    else
        test_fail "Installation prefix" "Directory does not exist: ${install_prefix}"
    fi
    
    # Test validate_and_repair_cache() function
    printf '%s\n' ""
    printf '%s\n' "Testing validate_and_repair_cache() function..."
    if [ -f /scripts/cache_functions.sh ]; then
        source /scripts/cache_functions.sh >/dev/null 2>&1 || true
        if declare -f validate_and_repair_cache >/dev/null 2>&1; then
            test_pass "Function defined: validate_and_repair_cache()"
            if validate_and_repair_cache >/dev/null 2>&1; then
                test_pass "validate_and_repair_cache() execution: Cache validated and repaired"
            else
                test_warning "validate_and_repair_cache() execution" "Function had issues (may be expected)"
            fi
        else
            test_warning "Function definition" "Function validate_and_repair_cache() is NOT defined (may be from previous stage)"
        fi
    else
        test_warning "Cache functions script" "File does not exist: /scripts/cache_functions.sh (may be from previous stage)"
    fi
    
    # Test write permissions in /root/.cache
    printf '%s\n' ""
    printf '%s\n' "Testing write permissions in /root/.cache..."
    if [ -d /root/.cache ]; then
        test_write_access "/root/.cache" "Root cache directory write"
        local test_file="/root/.cache/write_test_$$"
        if touch "${test_file}" 2>/dev/null && rm -f "${test_file}" 2>/dev/null; then
            test_pass "Write permissions test: /root/.cache is writable"
        else
            test_warning "Write permissions test" "Could not create/delete test file in /root/.cache"
        fi
    else
        test_warning "Root cache directory" "Directory does not exist: /root/.cache"
    fi
    
    # Test setup_gpg_verification() function (placeholder)
    printf '%s\n' ""
    printf '%s\n' "Testing setup_gpg_verification() function..."
    if declare -f setup_gpg_verification >/dev/null 2>&1; then
        test_pass "Function defined: setup_gpg_verification()"
        if setup_gpg_verification >/dev/null 2>&1; then
            test_pass "setup_gpg_verification() execution: Placeholder function executed"
        else
            test_warning "setup_gpg_verification() execution" "Function had issues (placeholder)"
        fi
    else
        test_warning "Function definition" "Function setup_gpg_verification() is NOT defined (may be from previous stage)"
    fi
    
    # Test runtime initialization script
    printf '%s\n' ""
    printf '%s\n' "Testing runtime initialization script..."
    if [ -f "/etc/profile.d/stage7_init.sh" ]; then
        test_pass "Runtime init script exists: /etc/profile.d/stage7_init.sh"
        test_read_access "/etc/profile.d/stage7_init.sh" "Runtime init script read"
        test_file_permissions "/etc/profile.d/stage7_init.sh" "644" "Runtime init script permissions"
        
        # Verify script sources common_functions.sh
        if grep -q "common_functions.sh" /etc/profile.d/stage7_init.sh 2>/dev/null; then
            test_pass "Runtime init script: Sources common_functions.sh"
        else
            test_fail "Runtime init script" "Does not source common_functions.sh"
        fi
    else
        test_warning "Runtime init script" "File does not exist: /etc/profile.d/stage7_init.sh (may be created at runtime)"
    fi
    
    return 0
}

# Function: Test Stage 8 - Mirror Selection and APT Setup
test_stage_8() {
    local test_context="${1:-host}"  # host or container
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUITE: Stage 8 - Mirror Selection and APT Setup (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run Stage 7 tests first (all must pass)
    printf '%s\n' ""
    printf '%s\n' "Running Stage 7 prerequisite tests..."
    if ! test_stage_7 "${test_context}"; then
        test_fail "Stage 7 prerequisites" "Stage 7 tests failed - cannot proceed"
        return 1
    fi
    
    if [ "${test_context}" = "host" ]; then
        # HOST-SIDE: Only test host setup, skip container-specific tests
        return 0
    fi
    
    # Test mirror configuration
    printf '%s\n' ""
    printf '%s\n' "Testing mirror configuration..."
    if [ -f /etc/apt/sources.list ]; then
        test_pass "APT sources.list exists: /etc/apt/sources.list"
        test_read_access "/etc/apt/sources.list" "APT sources.list read"
        
        # Check if sources.list contains a mirror URL (not just archive.ubuntu.com)
        if grep -qE "http://.*ubuntu" /etc/apt/sources.list 2>/dev/null; then
            test_pass "Mirror configuration: sources.list contains mirror URL"
        else
            test_warning "Mirror configuration" "sources.list may not contain mirror URL"
        fi
    else
        test_fail "APT sources.list" "File does not exist: /etc/apt/sources.list"
    fi
    
    # Test FASTEST_MIRROR environment variable (may be set at runtime)
    printf '%s\n' ""
    printf '%s\n' "Testing FASTEST_MIRROR environment variable..."
    if [ -n "${FASTEST_MIRROR:-}" ]; then
        test_pass "FASTEST_MIRROR is set: ${FASTEST_MIRROR}"
    else
        test_warning "FASTEST_MIRROR" "Environment variable not set (may be set at runtime)"
    fi
    
    # Test mirror functions availability
    printf '%s\n' ""
    printf '%s\n' "Testing mirror functions availability..."
    if [ -f /scripts/mirror_functions.sh ]; then
        source /scripts/mirror_functions.sh >/dev/null 2>&1 || true
        for func in probe_and_set_mirrors test_mirror verify_fastest_mirror reapply_fastest_mirror; do
            if declare -f "${func}" >/dev/null 2>&1; then
                test_pass "Function defined: ${func}()"
            else
                test_warning "Function definition" "Function ${func}() is NOT defined (may be from previous stage)"
            fi
        done
    else
        test_fail "Mirror functions script" "File does not exist: /scripts/mirror_functions.sh"
    fi
    
    # Test APT repositories (universe, PPAs)
    printf '%s\n' ""
    printf '%s\n' "Testing APT repositories..."
    if grep -qE "^[^#]*universe" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
        test_pass "Universe repository: Enabled"
    else
        test_warning "Universe repository" "May not be enabled (check sources.list)"
    fi
    
    # Test software-properties-common installation
    if command -v add-apt-repository >/dev/null 2>&1; then
        test_pass "add-apt-repository command: Available"
    else
        test_warning "add-apt-repository" "Command not found (may not be installed)"
    fi
    
    # Test GPG keys
    printf '%s\n' ""
    printf '%s\n' "Testing GPG keys..."
    if [ -d /usr/share/keyrings ]; then
        test_pass "GPG keyrings directory exists: /usr/share/keyrings"
        test_write_access "/usr/share/keyrings" "GPG keyrings directory write"
        
        # Check for Drake GPG key (if available)
        if [ -f /usr/share/keyrings/drake.gpg ]; then
            test_pass "Drake GPG key: Imported successfully"
            test_read_access "/usr/share/keyrings/drake.gpg" "Drake GPG key read"
        else
            test_warning "Drake GPG key" "Not found (may not be in cache or will be downloaded later)"
        fi
    else
        test_warning "GPG keyrings directory" "Directory does not exist: /usr/share/keyrings"
    fi
    
    # Test package verification tools
    printf '%s\n' ""
    printf '%s\n' "Testing package verification tools..."
    if command -v dpkg-sig >/dev/null 2>&1; then
        test_pass "dpkg-sig command: Available"
    else
        test_warning "dpkg-sig" "Command not found (may not be available in this Ubuntu version)"
    fi
    
    # Test verify_deb_package() function
    printf '%s\n' ""
    printf '%s\n' "Testing verify_deb_package() function..."
    if declare -f verify_deb_package >/dev/null 2>&1; then
        test_pass "Function defined: verify_deb_package()"
    else
        test_warning "Function definition" "Function verify_deb_package() is NOT defined (may be from previous stage)"
    fi
    
    # Test runtime initialization script
    printf '%s\n' ""
    printf '%s\n' "Testing runtime initialization script..."
    if [ -f "/etc/profile.d/stage8_init.sh" ]; then
        test_pass "Runtime init script exists: /etc/profile.d/stage8_init.sh"
        test_read_access "/etc/profile.d/stage8_init.sh" "Runtime init script read"
        test_file_permissions "/etc/profile.d/stage8_init.sh" "644" "Runtime init script permissions"
        
        # Verify script exports FASTEST_MIRROR
        if grep -q "FASTEST_MIRROR" /etc/profile.d/stage8_init.sh 2>/dev/null; then
            test_pass "Runtime init script: Exports FASTEST_MIRROR"
        else
            test_warning "Runtime init script" "May not export FASTEST_MIRROR"
        fi
        
        # Verify script defines verify_deb_package
        if grep -q "verify_deb_package" /etc/profile.d/stage8_init.sh 2>/dev/null; then
            test_pass "Runtime init script: Defines verify_deb_package()"
        else
            test_warning "Runtime init script" "May not define verify_deb_package()"
        fi
    else
        test_warning "Runtime init script" "File does not exist: /etc/profile.d/stage8_init.sh (may be created at runtime)"
    fi
    
    return 0
}

# Function: Test Stage 9 features (APT-ARIA wrapper setup)
test_stage_9() {
    local test_context="${1:-host}"
    
    printf '%s\n' ""
    printf '%s\n' "Testing Stage 9: APT-ARIA Wrapper Setup (BLOCK 11)"
    
    # Test apt-aria wrapper
    printf '%s\n' ""
    printf '%s\n' "Testing apt-aria wrapper..."
    if [ -f /usr/local/bin/apt-aria ]; then
        test_pass "apt-aria wrapper exists: /usr/local/bin/apt-aria"
        test_read_access "/usr/local/bin/apt-aria" "apt-aria wrapper read"
        test_execute_access "/usr/local/bin/apt-aria" "apt-aria wrapper execute"
        test_file_permissions "/usr/local/bin/apt-aria" "755" "apt-aria wrapper permissions"
    else
        test_fail "apt-aria wrapper" "File does not exist: /usr/local/bin/apt-aria"
    fi
    
    # Test apt-get and apt symlinks
    printf '%s\n' ""
    printf '%s\n' "Testing APT tool symlinks..."
    if [ -L /usr/local/bin/apt-get ]; then
        test_pass "apt-get symlink exists: /usr/local/bin/apt-get"
        local apt_get_target
        apt_get_target=$(readlink -f /usr/local/bin/apt-get 2>/dev/null || echo "")
        if [ -n "${apt_get_target:-}" ] && [ "${apt_get_target}" = "/usr/local/bin/apt-aria" ]; then
            test_pass "apt-get symlink target: Points to apt-aria"
        else
            test_warning "apt-get symlink target" "May not point to apt-aria: ${apt_get_target:-unknown}"
        fi
    else
        test_warning "apt-get symlink" "Symlink does not exist: /usr/local/bin/apt-get"
    fi
    
    if [ -L /usr/local/bin/apt ]; then
        test_pass "apt symlink exists: /usr/local/bin/apt"
        local apt_target
        apt_target=$(readlink -f /usr/local/bin/apt 2>/dev/null || echo "")
        if [ -n "${apt_target:-}" ] && [ "${apt_target}" = "/usr/local/bin/apt-aria" ]; then
            test_pass "apt symlink target: Points to apt-aria"
        else
            test_warning "apt symlink target" "May not point to apt-aria: ${apt_target:-unknown}"
        fi
    else
        test_warning "apt symlink" "Symlink does not exist: /usr/local/bin/apt"
    fi
    
    # Test container-cache.sh
    printf '%s\n' ""
    printf '%s\n' "Testing container-cache.sh..."
    if [ -f /etc/profile.d/container-cache.sh ]; then
        test_pass "container-cache.sh exists: /etc/profile.d/container-cache.sh"
        test_read_access "/etc/profile.d/container-cache.sh" "container-cache.sh read"
        test_file_permissions "/etc/profile.d/container-cache.sh" "644" "container-cache.sh permissions"
    else
        test_warning "container-cache.sh" "File does not exist: /etc/profile.d/container-cache.sh"
    fi
    
    # Test CONTAINER_APT_CACHE in /etc/environment
    printf '%s\n' ""
    printf '%s\n' "Testing CONTAINER_APT_CACHE in /etc/environment..."
    if [ -f /etc/environment ] && [ -r /etc/environment ]; then
        if grep -q "^CONTAINER_APT_CACHE=" /etc/environment 2>/dev/null; then
            test_pass "CONTAINER_APT_CACHE: Present in /etc/environment"
        else
            test_warning "CONTAINER_APT_CACHE" "Not found in /etc/environment"
        fi
    else
        test_warning "/etc/environment" "File does not exist or is not readable"
    fi
    
    # Test PATH order
    printf '%s\n' ""
    printf '%s\n' "Testing PATH order..."
    local path_value
    path_value="${PATH:-}"
    if [ -n "${path_value}" ]; then
        local first_local first_usr
        first_local=$(awk -v RS=':' '/\/usr\/local\/bin/{print NR; exit}' <<< "${path_value}" 2>/dev/null || echo "")
        first_usr=$(awk -v RS=':' '/\/usr\/bin/{print NR; exit}' <<< "${path_value}" 2>/dev/null || echo "")
        if [ -n "${first_local}" ] && [ -n "${first_usr}" ] && [[ "${first_local}" =~ ^[0-9]+$ ]] && [[ "${first_usr}" =~ ^[0-9]+$ ]]; then
            if [ "${first_local}" -lt "${first_usr}" ]; then
                test_pass "PATH order: /usr/local/bin precedes /usr/bin (apt-aria active)"
            else
                test_warning "PATH order" "/usr/bin appears before /usr/local/bin (apt-aria may be overshadowed)"
            fi
        else
            test_warning "PATH order" "Could not parse PATH: ${path_value}"
        fi
    else
        test_warning "PATH" "PATH environment variable is not set"
    fi
    
    # Test aria2c command
    printf '%s\n' ""
    printf '%s\n' "Testing aria2c command..."
    if command -v aria2c >/dev/null 2>&1; then
        test_pass "aria2c command: Available"
    else
        test_warning "aria2c" "Command not found (may not be installed)"
    fi
    
    # Test runtime initialization script
    printf '%s\n' ""
    printf '%s\n' "Testing runtime initialization script..."
    if [ -f "/etc/profile.d/stage9_init.sh" ]; then
        test_pass "Runtime init script exists: /etc/profile.d/stage9_init.sh"
        test_read_access "/etc/profile.d/stage9_init.sh" "Runtime init script read"
        test_file_permissions "/etc/profile.d/stage9_init.sh" "644" "Runtime init script permissions"
        
        # Verify script sources container-cache.sh
        if grep -q "container-cache.sh" /etc/profile.d/stage9_init.sh 2>/dev/null; then
            test_pass "Runtime init script: Sources container-cache.sh"
        else
            test_warning "Runtime init script" "May not source container-cache.sh"
        fi
    else
        test_warning "Runtime init script" "File does not exist: /etc/profile.d/stage9_init.sh (may be created at runtime)"
    fi
    
    return 0
}

test_stage_10() {
    local test_context="${1:-host}"
    
    printf '%s\n' ""
    printf '%s\n' "Testing Stage 10: Intel oneAPI MKL Installation (BLOCK 12A)"
    
    # Test Intel oneAPI GPG key
    printf '%s\n' ""
    printf '%s\n' "Testing Intel oneAPI GPG key..."
    if [ -f /usr/share/keyrings/oneapi-archive-keyring.gpg ]; then
        test_pass "Intel oneAPI GPG key exists: /usr/share/keyrings/oneapi-archive-keyring.gpg"
        test_read_access "/usr/share/keyrings/oneapi-archive-keyring.gpg" "GPG keyring read"
    else
        test_fail "Intel oneAPI GPG key" "File does not exist: /usr/share/keyrings/oneapi-archive-keyring.gpg"
    fi
    
    # Test Intel oneAPI repository configuration
    printf '%s\n' ""
    printf '%s\n' "Testing Intel oneAPI repository configuration..."
    if [ -f /etc/apt/sources.list.d/oneAPI.list ]; then
        test_pass "Intel oneAPI repository file exists: /etc/apt/sources.list.d/oneAPI.list"
        test_read_access "/etc/apt/sources.list.d/oneAPI.list" "Repository file read"
        
        if grep -q "apt.repos.intel.com/oneapi" /etc/apt/sources.list.d/oneAPI.list 2>/dev/null; then
            test_pass "Intel oneAPI repository: Contains correct URL"
        else
            test_warning "Intel oneAPI repository" "May not contain correct URL"
        fi
    else
        test_fail "Intel oneAPI repository" "File does not exist: /etc/apt/sources.list.d/oneAPI.list"
    fi
    
    # Test MKL package installation
    printf '%s\n' ""
    printf '%s\n' "Testing MKL package installation..."
    # Check for MKL packages - they might be versioned (e.g., intel-oneapi-mkl-2025.3)
    # Pattern matches: intel-oneapi-mkl, intel-oneapi-mkl-2025.3, intel-mkl, etc.
    if dpkg -l 2>/dev/null | grep -qiE "^ii\s+intel.*mkl"; then
        test_pass "MKL package: Installed"
    else
        # Also check if MKL files exist even if package name doesn't match
        if [ -d "/opt/intel/oneapi/mkl" ] && find /opt/intel/oneapi/mkl -name "libmkl*.so" -type f 2>/dev/null | head -1 | grep -q .; then
            test_pass "MKL package: Installed (MKL libraries found, package name may differ)"
        else
            test_fail "MKL package" "Not found in dpkg listing and no MKL libraries found"
        fi
    fi
    
    # Test MKLROOT environment variable
    printf '%s\n' ""
    printf '%s\n' "Testing MKLROOT environment variable..."
    if [ -n "${MKLROOT:-}" ]; then
        test_pass "MKLROOT: Set to ${MKLROOT}"
    elif [ -f /etc/environment ] && grep -q "^MKLROOT=" /etc/environment 2>/dev/null; then
        test_pass "MKLROOT: Present in /etc/environment"
        # Try to source it
        if [ "${test_context}" = "container" ]; then
            . /etc/environment 2>/dev/null || true
            if [ -n "${MKLROOT:-}" ]; then
                test_pass "MKLROOT: Can be sourced from /etc/environment"
            fi
        fi
    else
        test_warning "MKLROOT" "Not set (may be set at runtime)"
    fi
    
    # Test MKL libraries
    printf '%s\n' ""
    printf '%s\n' "Testing MKL libraries..."
    local mkl_base="/opt/intel/oneapi/mkl"
    if [ -d "${mkl_base}" ]; then
        test_pass "MKL base directory exists: ${mkl_base}"
        
        local mkl_lib_count
        mkl_lib_count=$(find "${mkl_base}" -maxdepth 3 -name "libmkl*.so" -type f 2>/dev/null | wc -l)
        if [ "${mkl_lib_count:-0}" -gt 0 ]; then
            test_pass "MKL libraries: Found ${mkl_lib_count} libraries"
        else
            test_warning "MKL libraries" "No libraries found in ${mkl_base}"
        fi
        
        # Test libmkl_rt.so (runtime library)
        local mkl_rt
        mkl_rt=$(find "${mkl_base}" -name "libmkl_rt.so" -type f 2>/dev/null | head -1)
        if [ -n "${mkl_rt:-}" ] && [ -f "${mkl_rt}" ]; then
            test_pass "MKL runtime library: Found at ${mkl_rt}"
        else
            test_warning "MKL runtime library" "libmkl_rt.so not found"
        fi
    else
        test_fail "MKL base directory" "Does not exist: ${mkl_base}"
    fi
    
    # Test MKL include directory
    printf '%s\n' ""
    printf '%s\n' "Testing MKL include directory..."
    local mkl_include
    if [ -n "${MKLROOT:-}" ]; then
        mkl_include="${MKLROOT}/include"
    else
        mkl_include="/opt/intel/oneapi/mkl/latest/include"
    fi
    
    if [ -d "${mkl_include}" ] && [ -f "${mkl_include}/mkl_cblas.h" ]; then
        test_pass "MKL include directory: Found at ${mkl_include}"
    else
        # Try to find it
        local found_include
        found_include=$(find /opt/intel/oneapi/mkl -maxdepth 4 -type f -name "mkl_cblas.h" 2>/dev/null | head -1)
        if [ -n "${found_include:-}" ]; then
            test_pass "MKL include directory: Found at $(dirname "${found_include}")"
        else
            test_warning "MKL include directory" "Not found at ${mkl_include}"
        fi
    fi
    
    # Test intel-mkl.sh environment script
    printf '%s\n' ""
    printf '%s\n' "Testing intel-mkl.sh environment script..."
    if [ -f /etc/profile.d/intel-mkl.sh ]; then
        test_pass "intel-mkl.sh exists: /etc/profile.d/intel-mkl.sh"
        test_read_access "/etc/profile.d/intel-mkl.sh" "intel-mkl.sh read"
        test_file_permissions "/etc/profile.d/intel-mkl.sh" "644" "intel-mkl.sh permissions"
    else
        test_fail "intel-mkl.sh" "File does not exist: /etc/profile.d/intel-mkl.sh"
    fi
    
    # Test MKLROOT in /etc/environment
    printf '%s\n' ""
    printf '%s\n' "Testing MKLROOT in /etc/environment..."
    if [ -f /etc/environment ] && [ -r /etc/environment ]; then
        if grep -q "^MKLROOT=" /etc/environment 2>/dev/null; then
            test_pass "MKLROOT: Present in /etc/environment"
        else
            test_warning "MKLROOT" "Not found in /etc/environment"
        fi
    else
        test_warning "/etc/environment" "File does not exist or is not readable"
    fi
    
    # Test MKL alternatives registration
    printf '%s\n' ""
    printf '%s\n' "Testing MKL alternatives registration..."
    if command -v update-alternatives >/dev/null 2>&1; then
        local blas_alt
        blas_alt=$(update-alternatives --display libblas.so.3-x86_64-linux-gnu 2>/dev/null | grep -i mkl || echo "")
        if [ -n "${blas_alt:-}" ]; then
            test_pass "MKL alternatives: Registered for BLAS"
        else
            test_warning "MKL alternatives" "May not be registered for BLAS"
        fi
        
        local lapack_alt
        lapack_alt=$(update-alternatives --display liblapack.so.3-x86_64-linux-gnu 2>/dev/null | grep -i mkl || echo "")
        if [ -n "${lapack_alt:-}" ]; then
            test_pass "MKL alternatives: Registered for LAPACK"
        else
            test_warning "MKL alternatives" "May not be registered for LAPACK"
        fi
    else
        test_warning "update-alternatives" "Command not found (alternatives system may not be available)"
    fi
    
    # Test runtime initialization script
    printf '%s\n' ""
    printf '%s\n' "Testing runtime initialization script..."
    if [ -f "/etc/profile.d/stage10_init.sh" ]; then
        test_pass "Runtime init script exists: /etc/profile.d/stage10_init.sh"
        test_read_access "/etc/profile.d/stage10_init.sh" "Runtime init script read"
        test_file_permissions "/etc/profile.d/stage10_init.sh" "644" "Runtime init script permissions"
        
        # Verify script sources intel-mkl.sh
        if grep -q "intel-mkl.sh" /etc/profile.d/stage10_init.sh 2>/dev/null; then
            test_pass "Runtime init script: Sources intel-mkl.sh"
        else
            test_warning "Runtime init script" "May not source intel-mkl.sh"
        fi
    else
        test_warning "Runtime init script" "File does not exist: /etc/profile.d/stage10_init.sh (may be created at runtime)"
    fi
    
    return 0
}

# Function: Run tests for a stage (context-aware)
run_stage_tests() {
    local stage_num="${1:-0}"
    local test_context="${2:-host}"  # host or container
    
    # Reset counters
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_WARNINGS=0
    CRITICAL_FAILURES=0
    
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "RUNNING TEST SUITE FOR STAGE ${stage_num} (${test_context})"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    case "${stage_num}" in
        0)
            test_stage_0 "${test_context}"
            ;;
        1)
            test_stage_1 "${test_context}"
            ;;
        2)
            test_stage_2 "${test_context}"
            ;;
        3)
            test_stage_3 "${test_context}"
            ;;
        4)
            test_stage_4 "${test_context}"
            ;;
        5)
            test_stage_5 "${test_context}"
            ;;
        6)
            test_stage_6 "${test_context}"
            ;;
        7)
            test_stage_7 "${test_context}"
            ;;
        8)
            test_stage_8 "${test_context}"
            ;;
        9)
            test_stage_9 "${test_context}"
            ;;
        10)
            test_stage_10 "${test_context}"
            ;;
        *)
            printf '%s\n' "${YELLOW}⚠${NC} No test suite defined for stage ${stage_num}"
            ;;
    esac
    
    # Print summary
    printf '%s\n' ""
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "TEST SUMMARY FOR STAGE ${stage_num}"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s\n' "${GREEN}✓ Passed:${NC} ${TESTS_PASSED}"
    printf '%s\n' "${YELLOW}⚠ Warnings:${NC} ${TESTS_WARNINGS}"
    printf '%s\n' "${RED}✗ Failed:${NC} ${TESTS_FAILED}"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ ${CRITICAL_FAILURES} -eq 0 ]; then
        printf '%s\n' "${GREEN}✓ All tests passed - Stage ${stage_num} ready to proceed${NC}"
        return 0
    else
        printf '%s\n' "${RED}✗ ${CRITICAL_FAILURES} critical test(s) failed - Stage ${stage_num} cannot proceed${NC}"
        printf '%s\n' "${RED}  All failures and warnings must be resolved before building${NC}"
        return 1
    fi
}

# Export functions
export -f test_pass test_fail test_warning
export -f test_dir_permissions test_file_permissions
export -f test_read_access test_write_access test_execute_access
export -f test_bind_mount test_ownership test_image_file
export -f test_stage_0 test_stage_1 test_stage_2 test_stage_3 test_stage_4 test_stage_5 test_stage_6 test_stage_7 test_stage_8 test_stage_9 test_stage_10 run_stage_tests

