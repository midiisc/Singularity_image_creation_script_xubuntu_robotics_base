#!/bin/bash
################################################################################
# CMAKE FLAG DOCUMENTATION GENERATOR
# Purpose: Auto-generate docs/flags/ documentation from library repositories
# Usage: ./generate_flag_docs.sh <library_name> <version> [repo_url]
#
# Features:
#   - Clones library repository at specific version
#   - Parses CMakeLists.txt for option() and set() declarations
#   - Generates markdown documentation with flag descriptions
#   - Includes source commit hash and generation metadata
#
# Exit codes:
#   0 = Documentation generated successfully
#   1 = Error occurred
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORKSPACE_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
DOCS_FLAGS_DIR="${WORKSPACE_ROOT}/docs/flags"
TEMP_DIR=$(mktemp -d -t flagdocs.XXXXXX)

# Cleanup on exit
trap 'rm -rf "${TEMP_DIR}"' EXIT

# Arguments
LIBRARY_NAME=""
VERSION=""
REPO_URL=""

################################################################################
# HELPER FUNCTIONS
################################################################################

print_usage() {
  cat <<EOF
Usage: ${0##*/} <library_name> <version> [repo_url]

Generate CMake flag documentation from library source

Arguments:
  library_name  Library to document (e.g., ceres-solver, gtsam, opencv)
  version       Version/tag to document (e.g., 2.2.0, v4.11.4)
  repo_url      Git repository URL (optional, uses default for known libraries)

Examples:
  ${0##*/} ceres-solver 2.2.0
  ${0##*/} opencv 4.11.4
  ${0##*/} gtsam 4.2 https://github.com/borglab/gtsam.git

Known libraries (auto-detect repo):
  - ceres-solver: https://github.com/ceres-solver/ceres-solver.git
  - opencv: https://github.com/opencv/opencv.git
  - gtsam: https://github.com/borglab/gtsam.git
  - g2o: https://github.com/RainerKuemmerle/g2o.git
  - open3d: https://github.com/isl-org/Open3D.git
  - colmap: https://github.com/colmap/colmap.git

EOF
  exit 1
}

get_default_repo() {
  local lib="$1"
  case "${lib,,}" in
    ceres-solver|ceres)
      echo "https://github.com/ceres-solver/ceres-solver.git"
      ;;
    opencv)
      echo "https://github.com/opencv/opencv.git"
      ;;
    gtsam)
      echo "https://github.com/borglab/gtsam.git"
      ;;
    g2o)
      echo "https://github.com/RainerKuemmerle/g2o.git"
      ;;
    open3d)
      echo "https://github.com/isl-org/Open3D.git"
      ;;
    colmap)
      echo "https://github.com/colmap/colmap.git"
      ;;
    *)
      echo ""
      ;;
  esac
}

clone_library() {
  local repo_url="$1"
  local version="$2"
  local clone_dir="${TEMP_DIR}/source"
  
  echo "Cloning ${LIBRARY_NAME} ${VERSION}..."
  
  if ! git clone --depth 1 --branch "${version}" "${repo_url}" "${clone_dir}" 2>&1 | head -10; then
    echo -e "${RED}ERROR: Failed to clone repository${NC}"
    echo "Repository: ${repo_url}"
    echo "Version: ${version}"
    exit 1
  fi
  
  echo "${clone_dir}"
}

parse_cmake_options() {
  local cmake_file="$1"
  local output_file="$2"
  
  echo "Parsing CMake options from ${cmake_file}..."
  
  # Extract option() declarations
  grep -n "^[[:space:]]*option(" "${cmake_file}" | while IFS=: read -r lineno line; do
    # Parse: option(NAME "Description" DEFAULT)
    if [[ "${line}" =~ option.*\(([A-Z_0-9]+).*\"([^\"]+)\" ]]; then
      local flag_name="${BASH_REMATCH[1]}"
      local description="${BASH_REMATCH[2]}"
      local default_value="${BASH_REMATCH[3]}"
      
      echo "### ${flag_name}" >> "${output_file}"
      echo "" >> "${output_file}"
      echo "- **Type:** BOOL (ON/OFF)" >> "${output_file}"
      echo "- **Default:** \`${default_value}\`" >> "${output_file}"
      echo "- **Description:** ${description}" >> "${output_file}"
      echo "- **Source line:** ${lineno}" >> "${output_file}"
      echo "" >> "${output_file}"
      echo "\`\`\`cmake" >> "${output_file}"
      echo "${line}" >> "${output_file}"
      echo "\`\`\`" >> "${output_file}"
      echo "" >> "${output_file}"
    fi
  done
}

parse_cmake_variables() {
  local cmake_file="$1"
  local output_file="$2"
  
  echo "Parsing CMake set() declarations from ${cmake_file}..."
  
  # Extract set() declarations with CACHE
  grep -n "^[[:space:]]*set(" "${cmake_file}" | grep "CACHE" | while IFS=: read -r lineno line; do
    # Parse: set(NAME value CACHE TYPE "Description")
    if [[ "${line}" =~ set.*\(([A-Z_0-9]+).*CACHE.*\"([^\"]+)\" ]]; then
      local var_name="${BASH_REMATCH[1]}"
      local default_value="${BASH_REMATCH[2]}"
      local var_type="${BASH_REMATCH[3]}"
      local description="${BASH_REMATCH[4]}"
      
      echo "### ${var_name}" >> "${output_file}"
      echo "" >> "${output_file}"
      echo "- **Type:** ${var_type}" >> "${output_file}"
      echo "- **Default:** \`${default_value}\`" >> "${output_file}"
      echo "- **Description:** ${description}" >> "${output_file}"
      echo "- **Source line:** ${lineno}" >> "${output_file}"
      echo "" >> "${output_file}"
      echo "\`\`\`cmake" >> "${output_file}"
      echo "${line}" >> "${output_file}"
      echo "\`\`\`" >> "${output_file}"
      echo "" >> "${output_file}"
    fi
  done
}

generate_documentation() {
  local clone_dir="$1"
  local commit_hash
  
  # Get commit hash
  cd "${clone_dir}" || exit 1
  commit_hash=$(git rev-parse HEAD)
  
  # Find CMakeLists.txt (usually in root or specific subdirectory)
  local cmake_main="${clone_dir}/CMakeLists.txt"
  
  if [ ! -f "${cmake_main}" ]; then
    echo -e "${RED}ERROR: CMakeLists.txt not found in ${clone_dir}${NC}"
    exit 1
  fi
  
  # Create output file
  mkdir -p "${DOCS_FLAGS_DIR}"
  local lib_upper=$(echo "${LIBRARY_NAME}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
  local version_clean=$(echo "${VERSION}" | tr -d 'v')
  local output_file="${DOCS_FLAGS_DIR}/${lib_upper}_${version_clean}_CMAKE_FLAGS_DOCUMENTATION.md"
  
  echo "Generating documentation: ${output_file}"
  
  # Write header
  cat > "${output_file}" <<EOF
# ${LIBRARY_NAME} ${VERSION} - CMake Flags Documentation

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Source:** ${REPO_URL}  
**Commit:** \`${commit_hash}\`  
**CMake Minimum Version:** $(grep "cmake_minimum_required" "${cmake_main}" | head -1 || echo "N/A")

---

## Overview

This document contains all CMake configuration options for ${LIBRARY_NAME} ${VERSION}.  
Extracted from the official source repository at commit \`${commit_hash}\`.

---

## Boolean Options (option)

EOF
  
  # Parse options
  parse_cmake_options "${cmake_main}" "${output_file}"
  
  # Add cached variables section
  cat >> "${output_file}" <<EOF

---

## Cache Variables (set + CACHE)

EOF
  
  # Parse cache variables
  parse_cmake_variables "${cmake_main}" "${output_file}"
  
  # Add usage example
  cat >> "${output_file}" <<EOF

---

## Usage Example

\`\`\`bash
cmake .. \\
  -G Ninja \\
  -D CMAKE_BUILD_TYPE=Release \\
  -D CMAKE_INSTALL_PREFIX=/usr/local \\
  -D <FLAG_NAME>=<VALUE>
\`\`\`

---

## Validation

To validate CMake flags against this documentation:

\`\`\`bash
./scripts/helpers/validate_cmake_flags.sh <build_script> --strict
\`\`\`

---

**Documentation generated by:** \`scripts/generate_flag_docs.sh\`  
**Last updated:** $(date -u +"%Y-%m-%d")
EOF
  
  echo -e "${GREEN}✓ Documentation generated: ${output_file}${NC}"
  echo ""
  echo "To use this documentation:"
  echo "  1. Review the generated file"
  echo "  2. Reference it in build scripts: # Reference: ${output_file##*/}"
  echo "  3. Run validator: ./scripts/helpers/validate_cmake_flags.sh <script>"
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
  # Parse arguments
  if [ $# -lt 2 ]; then
    print_usage
  fi
  
  LIBRARY_NAME="$1"
  VERSION="$2"
  REPO_URL="${3:-$(get_default_repo "${LIBRARY_NAME}")}"
  
  if [ -z "${REPO_URL}" ]; then
    echo -e "${RED}ERROR: No default repository URL for '${LIBRARY_NAME}'${NC}"
    echo "Please provide repository URL as third argument"
    exit 1
  fi
  
  # Print header
  echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     CMAKE FLAG DOCUMENTATION GENERATOR            ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Library: ${LIBRARY_NAME}"
  echo "Version: ${VERSION}"
  echo "Repository: ${REPO_URL}"
  echo "Temp directory: ${TEMP_DIR}"
  echo ""
  
  # Clone library
  clone_dir=$(clone_library "${REPO_URL}" "${VERSION}")
  
  # Generate documentation
  generate_documentation "${clone_dir}"
  
  echo ""
  echo -e "${GREEN}✓ Documentation generation complete${NC}"
}

main "$@"
