#!/bin/bash
################################################################################
# Purpose: Diagnostic script to check build environment issues
#          Specifically checks /tmp, findutils, and APT configuration
# Usage: ./scripts/helpers/diagnose_build_environment.sh
#
# This script diagnoses common issues that cause build failures:
#   1. /tmp directory problems (disk space, permissions, mount options)
#   2. findutils installation and PATH issues
#   3. APT configuration and GPG key issues
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Get repository root
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -d "${SCRIPT_DIR}/../.." ]; then
  WORKSPACE_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
else
  WORKSPACE_ROOT=$(pwd)
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  BUILD ENVIRONMENT DIAGNOSTIC TOOL                             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}[INFO]${NC} Repository: $(basename "${WORKSPACE_ROOT}") (${WORKSPACE_ROOT})"
echo ""

ERRORS_FOUND=0
WARNINGS_FOUND=0

################################################################################
# SECTION 1: /tmp Directory Diagnostics
################################################################################

echo -e "${CYAN}╭────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${CYAN}│  SECTION 1: /tmp DIRECTORY DIAGNOSTICS                        │${NC}"
echo -e "${CYAN}╰────────────────────────────────────────────────────────────────╯${NC}"
echo ""

# Check 1.1: Disk space
echo -e "${BLUE}[CHECK 1.1]${NC} Checking /tmp disk space..."
TMP_SPACE_AVAIL=$(df -BG /tmp 2>/dev/null | awk 'NR==2 {print substr($4, 1, length($4)-1)}' || echo "0")
TMP_SPACE_USED=$(df -BG /tmp 2>/dev/null | awk 'NR==2 {print substr($3, 1, length($3)-1)}' || echo "0")
TMP_SPACE_TOTAL=$(df -BG /tmp 2>/dev/null | awk 'NR==2 {print substr($2, 1, length($2)-1)}' || echo "0")

if [[ "${TMP_SPACE_AVAIL}" =~ ^[0-9]+$ ]]; then
  if [ "${TMP_SPACE_AVAIL}" -lt 1 ]; then
    echo -e "${RED}  ✗ CRITICAL: /tmp has less than 1GB free (${TMP_SPACE_AVAIL}GB)${NC}"
    echo -e "${YELLOW}    This will cause apt-key temp file creation failures${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
  elif [ "${TMP_SPACE_AVAIL}" -lt 5 ]; then
    echo -e "${YELLOW}  ⚠ WARNING: /tmp has less than 5GB free (${TMP_SPACE_AVAIL}GB)${NC}"
    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
  else
    echo -e "${GREEN}  ✓ /tmp has sufficient space: ${TMP_SPACE_AVAIL}GB free${NC}"
  fi
  echo "    Total: ${TMP_SPACE_TOTAL}GB, Used: ${TMP_SPACE_USED}GB, Available: ${TMP_SPACE_AVAIL}GB"
else
  echo -e "${RED}  ✗ ERROR: Could not determine /tmp disk space${NC}"
  ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi
echo ""

# Check 1.2: Mount options
echo -e "${BLUE}[CHECK 1.2]${NC} Checking /tmp mount options..."
TMP_MOUNT_INFO=$(mount | grep -E "^[^ ]+.*on /tmp " || echo "")
if [ -n "${TMP_MOUNT_INFO}" ]; then
  echo "  Mount info: ${TMP_MOUNT_INFO}"
  if echo "${TMP_MOUNT_INFO}" | grep -qE "(noexec|nodev|nosuid|ro,|read-only)"; then
    echo -e "${RED}  ✗ CRITICAL: /tmp has restrictive mount options${NC}"
    if echo "${TMP_MOUNT_INFO}" | grep -q "noexec"; then
      echo -e "${YELLOW}    - noexec: Cannot execute binaries from /tmp${NC}"
    fi
    if echo "${TMP_MOUNT_INFO}" | grep -q "nodev"; then
      echo -e "${YELLOW}    - nodev: Cannot use device files in /tmp${NC}"
    fi
    if echo "${TMP_MOUNT_INFO}" | grep -qE "ro,|read-only"; then
      echo -e "${RED}    - read-only: /tmp is mounted read-only!${NC}"
      ERRORS_FOUND=$((ERRORS_FOUND + 1))
    fi
  else
    echo -e "${GREEN}  ✓ /tmp mount options are acceptable${NC}"
  fi
else
  echo -e "${YELLOW}  ⚠ Could not find /tmp mount information${NC}"
  WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
fi
echo ""

# Check 1.3: Permissions
echo -e "${BLUE}[CHECK 1.3]${NC} Checking /tmp permissions..."
TMP_PERMS=$(stat -c "%a" /tmp 2>/dev/null || echo "unknown")
if [ "${TMP_PERMS}" = "1777" ] || [ "${TMP_PERMS}" = "777" ]; then
  echo -e "${GREEN}  ✓ /tmp permissions are correct: ${TMP_PERMS}${NC}"
else
  echo -e "${YELLOW}  ⚠ /tmp permissions are ${TMP_PERMS} (expected 1777 or 777)${NC}"
  WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
fi
echo ""

# Check 1.4: Writability test
echo -e "${BLUE}[CHECK 1.4]${NC} Testing /tmp writability..."
TEST_FILE="/tmp/diagnostic_test_$$"
if touch "${TEST_FILE}" 2>/dev/null; then
  if echo "test" > "${TEST_FILE}" 2>/dev/null; then
    if [ -f "${TEST_FILE}" ] && [ -r "${TEST_FILE}" ]; then
      rm -f "${TEST_FILE}" 2>/dev/null || true
      echo -e "${GREEN}  ✓ /tmp is writable and readable${NC}"
    else
      echo -e "${RED}  ✗ CRITICAL: /tmp file creation succeeded but file is not readable${NC}"
      ERRORS_FOUND=$((ERRORS_FOUND + 1))
    fi
  else
    echo -e "${RED}  ✗ CRITICAL: Cannot write to file in /tmp${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
    rm -f "${TEST_FILE}" 2>/dev/null || true
  fi
else
  echo -e "${RED}  ✗ CRITICAL: Cannot create files in /tmp${NC}"
  echo -e "${YELLOW}    This will cause apt-key temp file creation failures${NC}"
  ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi
echo ""

# Check 1.5: Filesystem type
echo -e "${BLUE}[CHECK 1.5]${NC} Checking /tmp filesystem type..."
TMP_FSTYPE=$(df -T /tmp 2>/dev/null | awk 'NR==2 {print $2}' || echo "unknown")
echo "  Filesystem type: ${TMP_FSTYPE}"
if [ "${TMP_FSTYPE}" = "tmpfs" ]; then
  echo -e "${BLUE}  ℹ /tmp is a tmpfs (RAM-based)${NC}"
  echo -e "${YELLOW}    Note: tmpfs size is limited by available RAM${NC}"
elif [ "${TMP_FSTYPE}" = "unknown" ]; then
  echo -e "${YELLOW}  ⚠ Could not determine filesystem type${NC}"
  WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
fi
echo ""

################################################################################
# SECTION 2: findutils Diagnostics
################################################################################

echo -e "${CYAN}╭────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${CYAN}│  SECTION 2: FINDUTILS DIAGNOSTICS                            │${NC}"
echo -e "${CYAN}╰────────────────────────────────────────────────────────────────╯${NC}"
echo ""

# Check 2.1: findutils package installation
echo -e "${BLUE}[CHECK 2.1]${NC} Checking findutils package installation..."
if dpkg -l | grep -qE "^ii.*findutils"; then
  FINDUTILS_VERSION=$(dpkg -l | grep -E "^ii.*findutils" | awk '{print $3}' || echo "unknown")
  echo -e "${GREEN}  ✓ findutils is installed: ${FINDUTILS_VERSION}${NC}"
else
  echo -e "${RED}  ✗ CRITICAL: findutils package is not installed${NC}"
  ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi
echo ""

# Check 2.2: Which find command
echo -e "${BLUE}[CHECK 2.2]${NC} Checking which 'find' command is used..."
FIND_PATH=$(command -v find 2>/dev/null || echo "not found")
FIND_TYPE=$(type find 2>/dev/null || echo "unknown")
echo "  'find' command path: ${FIND_PATH}"
echo "  'find' command type: ${FIND_TYPE}"

if [ "${FIND_PATH}" = "not found" ]; then
  echo -e "${RED}  ✗ CRITICAL: 'find' command not found in PATH${NC}"
  ERRORS_FOUND=$((ERRORS_FOUND + 1))
elif echo "${FIND_TYPE}" | grep -q "alias"; then
  echo -e "${YELLOW}  ⚠ WARNING: 'find' is aliased - this may override GNU find${NC}"
  echo "    Alias: ${FIND_TYPE}"
  WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
elif [ "${FIND_PATH}" != "/usr/bin/find" ]; then
  echo -e "${YELLOW}  ⚠ WARNING: Using 'find' from ${FIND_PATH} (not /usr/bin/find)${NC}"
  WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
fi
echo ""

# Check 2.3: GNU find version
echo -e "${BLUE}[CHECK 2.3]${NC} Checking GNU find version..."
if /usr/bin/find --version >/dev/null 2>&1; then
  FIND_VERSION=$(/usr/bin/find --version 2>&1 | head -1 || echo "unknown")
  echo -e "${GREEN}  ✓ /usr/bin/find is available: ${FIND_VERSION}${NC}"
else
  echo -e "${RED}  ✗ CRITICAL: /usr/bin/find is not available or not GNU find${NC}"
  ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi
echo ""

# Check 2.4: find -printf support
echo -e "${BLUE}[CHECK 2.4]${NC} Testing find -printf support..."
TEST_FILE="/tmp/find_printf_test_$$"
if touch "${TEST_FILE}" 2>/dev/null; then
  # Test with PATH find
  if find "${TEST_FILE}" -printf '%p\n' >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 'find' (from PATH) supports -printf${NC}"
  else
    echo -e "${RED}  ✗ CRITICAL: 'find' (from PATH) does NOT support -printf${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
  fi
  
  # Test with full path
  if /usr/bin/find "${TEST_FILE}" -printf '%p\n' >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ /usr/bin/find supports -printf${NC}"
  else
    echo -e "${RED}  ✗ CRITICAL: /usr/bin/find does NOT support -printf${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
  fi
  
  rm -f "${TEST_FILE}" 2>/dev/null || true
else
  echo -e "${YELLOW}  ⚠ Could not create test file (this is a /tmp issue, see Section 1)${NC}"
  WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
fi
echo ""

# Check 2.5: PATH order
echo -e "${BLUE}[CHECK 2.5]${NC} Checking PATH order for find command..."
echo "  Current PATH: ${PATH}"
FIND_IN_PATH=$(echo "${PATH}" | tr ':' '\n' | while IFS= read -r dir; do
  if [ -f "${dir}/find" ] && [ -x "${dir}/find" ]; then
    echo "${dir}/find"
    break
  fi
done)

if [ -n "${FIND_IN_PATH}" ]; then
  echo "  First 'find' found in PATH: ${FIND_IN_PATH}"
  if [ "${FIND_IN_PATH}" = "/usr/bin/find" ]; then
    echo -e "${GREEN}  ✓ /usr/bin is before other directories in PATH${NC}"
  else
    echo -e "${YELLOW}  ⚠ WARNING: ${FIND_IN_PATH} is found before /usr/bin/find${NC}"
    echo -e "${YELLOW}    Consider: export PATH=\"/usr/bin:\${PATH}\"${NC}"
    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
  fi
fi
echo ""

################################################################################
# SECTION 3: APT Configuration Diagnostics
################################################################################

echo -e "${CYAN}╭────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${CYAN}│  SECTION 3: APT CONFIGURATION DIAGNOSTICS                    │${NC}"
echo -e "${CYAN}╰────────────────────────────────────────────────────────────────╯${NC}"
echo ""

# Check 3.1: APT temp directory
echo -e "${BLUE}[CHECK 3.1]${NC} Checking APT temporary directory configuration..."
APT_TMPDIR=$(apt-config dump | grep -i "Dir::Cache" | head -1 || echo "default")
echo "  APT cache directory: ${APT_TMPDIR}"
if [ -n "${TMPDIR:-}" ]; then
  echo "  TMPDIR environment variable: ${TMPDIR}"
  if [ ! -d "${TMPDIR}" ] || [ ! -w "${TMPDIR}" ]; then
    echo -e "${RED}  ✗ CRITICAL: TMPDIR (${TMPDIR}) is not writable${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
  fi
fi
echo ""

# Check 3.2: APT keyring directory
echo -e "${BLUE}[CHECK 3.2]${NC} Checking APT keyring directory..."
if [ -d "/etc/apt/trusted.gpg.d" ]; then
  if [ -w "/etc/apt/trusted.gpg.d" ]; then
    echo -e "${GREEN}  ✓ /etc/apt/trusted.gpg.d is writable${NC}"
  else
    echo -e "${RED}  ✗ CRITICAL: /etc/apt/trusted.gpg.d is not writable${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
  fi
else
  echo -e "${RED}  ✗ CRITICAL: /etc/apt/trusted.gpg.d does not exist${NC}"
  ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi
echo ""

# Check 3.3: Test apt-key temp file creation
echo -e "${BLUE}[CHECK 3.3]${NC} Testing apt-key temporary file creation..."
# Simulate what apt-key does
APT_CONF_TEST="/tmp/apt.conf.test_$$"
if echo "test" > "${APT_CONF_TEST}" 2>/dev/null; then
  rm -f "${APT_CONF_TEST}" 2>/dev/null || true
  echo -e "${GREEN}  ✓ Can create apt.conf-style temp files in /tmp${NC}"
else
  echo -e "${RED}  ✗ CRITICAL: Cannot create apt.conf-style temp files in /tmp${NC}"
  echo -e "${YELLOW}    This will cause 'Couldn't create temporary file /tmp/apt.conf.XXXXXX' errors${NC}"
  ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi
echo ""

# Check 3.4: GPG key verification
echo -e "${BLUE}[CHECK 3.4]${NC} Checking GPG key verification capability..."
if command -v gpg >/dev/null 2>&1; then
  if gpg --version >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ GPG is available and working${NC}"
  else
    echo -e "${RED}  ✗ CRITICAL: GPG is installed but not working${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
  fi
else
  echo -e "${RED}  ✗ CRITICAL: GPG is not installed${NC}"
  ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi
echo ""

# Check 3.5: Container detection
echo -e "${BLUE}[CHECK 3.5]${NC} Checking container environment..."
if [ -n "${SINGULARITY_NAME:-}" ]; then
  echo "  Container: Singularity (${SINGULARITY_NAME})"
  echo -e "${BLUE}  ℹ Running in Singularity container${NC}"
fi
if [ -n "${APPTAINER_NAME:-}" ]; then
  echo "  Container: Apptainer (${APPTAINER_NAME})"
  echo -e "${BLUE}  ℹ Running in Apptainer container${NC}"
fi
if [ -f "/.singularity.d/runscript" ]; then
  echo -e "${BLUE}  ℹ Singularity container detected${NC}"
fi
if [ -f "/.dockerenv" ]; then
  echo -e "${BLUE}  ℹ Docker container detected${NC}"
fi
if [ -z "${SINGULARITY_NAME:-}" ] && [ -z "${APPTAINER_NAME:-}" ] && [ ! -f "/.singularity.d/runscript" ] && [ ! -f "/.dockerenv" ]; then
  echo -e "${BLUE}  ℹ Running on host system (not in container)${NC}"
fi
echo ""

################################################################################
# SUMMARY
################################################################################

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
if [ "${ERRORS_FOUND}" -eq 0 ] && [ "${WARNINGS_FOUND}" -eq 0 ]; then
  echo -e "${CYAN}║${GREEN}  ✓ ALL CHECKS PASSED - ENVIRONMENT IS HEALTHY              ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  exit 0
elif [ "${ERRORS_FOUND}" -eq 0 ]; then
  echo -e "${CYAN}║${YELLOW}  ⚠ SOME WARNINGS FOUND (${WARNINGS_FOUND}) - ENVIRONMENT MAY HAVE ISSUES  ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  exit 0
else
  echo -e "${CYAN}║${RED}  ✗ ERRORS FOUND (${ERRORS_FOUND} errors, ${WARNINGS_FOUND} warnings) - FIX REQUIRED${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}[RECOMMENDATIONS]${NC}"
  echo ""
  if [ "${ERRORS_FOUND}" -gt 0 ]; then
    echo "  1. Review errors above and fix critical issues"
    echo "  2. Common fixes:"
    echo "     - Clean /tmp: sudo find /tmp -type f -mtime +7 -delete"
    echo "     - Fix /tmp permissions: sudo chmod 1777 /tmp"
    echo "     - Install findutils: sudo apt update && sudo apt install findutils"
    echo "     - Update PATH: export PATH=\"/usr/bin:\${PATH}\""
    echo ""
  fi
  exit 1
fi

