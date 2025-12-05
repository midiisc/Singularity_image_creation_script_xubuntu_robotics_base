#!/bin/bash
#===============================================================================
# CUMULATIVE BUILD SCRIPT - Stages 0 to 10
#===============================================================================
# Purpose: Build all stages cumulatively from Stage 0 to Stage 10 in sequence
#          Each stage builds on the previous stage's image
# Usage: ./build_cumulative_stages_0_to_10.sh [--runtime apptainer|singularity]
#===============================================================================

set -euo pipefail

# Get script directory and set base paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ROOT="${SCRIPT_DIR}"
STAGES_DIR="${BUILD_ROOT}/stages"
OUTPUT_DIR="${BUILD_ROOT}/output"
LOGS_DIR="${BUILD_ROOT}/logs"
CONFIG_FILE="${BUILD_ROOT}/config.sh"

# CRITICAL: Use the SAME container_cache as main build scripts for cache reuse
# Main build scripts use: ${REPO_ROOT}/container_cache
# This allows reusing packages already downloaded by build_xubuntu_robotics_base.sh
REPO_ROOT="$(cd "${BUILD_ROOT}/.." && pwd)"
MAIN_CACHE_DIR="${REPO_ROOT}/container_cache"

# Parse arguments
KEEP_INTERMEDIATE=false
CONTAINER_RUNTIME="apptainer"

while [[ $# -gt 0 ]]; do
    case $1 in
        --runtime)
            CONTAINER_RUNTIME="$2"
            shift 2
            ;;
        --keep-intermediate|--keep)
            KEEP_INTERMEDIATE=true
            shift
            ;;
        apptainer|singularity)
            CONTAINER_RUNTIME="$1"
            shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Usage: $0 [--runtime apptainer|singularity] [--keep-intermediate]" >&2
            echo "" >&2
            echo "Default behavior: Build all stages sequentially, keep only final stage_10 image" >&2
            echo "  --keep-intermediate: Keep all intermediate stage images (for debugging)" >&2
            exit 1
            ;;
    esac
done

if [ "${CONTAINER_RUNTIME}" != "apptainer" ] && [ "${CONTAINER_RUNTIME}" != "singularity" ]; then
    echo "Error: Runtime must be 'apptainer' or 'singularity'" >&2
    exit 1
fi

# Check if runtime is available
if ! command -v "${CONTAINER_RUNTIME}" >/dev/null 2>&1; then
    echo "Error: ${CONTAINER_RUNTIME} not found in PATH" >&2
    exit 1
fi

# Check if fakeroot is available
USE_FAKEROOT=false
if command -v fakeroot >/dev/null 2>&1; then
    USE_FAKEROOT=true
    echo "✓ fakeroot available - will use --fakeroot flag"
else
    echo "⚠ fakeroot not available - will use sudo (if needed)"
fi

# Create directories
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BUILD_ROOT}/tmp"

# Verify required files exist
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PRE-BUILD: Verifying required files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Error: config.sh not found at ${CONFIG_FILE}" >&2
    exit 1
fi
echo "✓ config.sh found"

if [ ! -d "${STAGES_DIR}" ]; then
    echo "Error: stages directory not found at ${STAGES_DIR}" >&2
    exit 1
fi
echo "✓ stages directory found"

# Check for all stage definition files
for stage_num in $(seq 0 10); do
    stage_file="${STAGES_DIR}/stage_$(printf "%02d" ${stage_num})_*.def"
    if ! ls ${stage_file} 1>/dev/null 2>&1; then
        echo "Error: Stage ${stage_num} definition file not found" >&2
        exit 1
    fi
done
echo "✓ All stage definition files found (0-10)"

# Check for container-scripts and scripts directories
if [ ! -d "${BUILD_ROOT}/container-scripts" ]; then
    echo "Error: container-scripts directory not found" >&2
    exit 1
fi
echo "✓ container-scripts directory found"

if [ ! -d "${BUILD_ROOT}/scripts" ]; then
    echo "Error: scripts directory not found" >&2
    exit 1
fi
echo "✓ scripts directory found"

# Check for test_cases.sh (optional but recommended)
if [ -f "${BUILD_ROOT}/test_cases.sh" ]; then
    echo "✓ test_cases.sh found (test suite will run after each stage)"
else
    echo "⚠ test_cases.sh not found (test suite will be skipped)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CUMULATIVE BUILD: Stages 0 to 10"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Runtime: ${CONTAINER_RUNTIME}"
echo "Build Root: ${BUILD_ROOT}"
echo "Output Directory: ${OUTPUT_DIR}"
echo "Logs Directory: ${LOGS_DIR}"
echo "Cache Directory: ${MAIN_CACHE_DIR}"
if [ -d "${MAIN_CACHE_DIR}" ]; then
    CACHE_SIZE=$(du -sh "${MAIN_CACHE_DIR}" 2>/dev/null | cut -f1 || echo "unknown")
    echo "  ✓ Reusing existing cache (${CACHE_SIZE}) from main build scripts"
else
    echo "  ⚠ Cache directory will be created (no existing cache found)"
fi
if [ "${KEEP_INTERMEDIATE}" = true ]; then
    echo "Mode: Keep all intermediate images (for debugging)"
else
    echo "Mode: Single final image (intermediate images deleted after use)"
fi
echo ""

# Function to update paths in definition file
update_def_paths() {
    local def_file="$1"
    local temp_file="${def_file}.tmp"
    
    # Replace absolute paths with BUILD_ROOT-relative paths
    # CRITICAL: Handle path replacement carefully to avoid duplicates
    # Strategy: Only replace if the path doesn't already match BUILD_ROOT
    
    # First, fix any existing duplicates (shouldn't happen after our fixes, but be safe)
    sed "s|${BUILD_ROOT}/cumulative_build_stages_0_to_10|${BUILD_ROOT}|g" \
        "${def_file}" > "${temp_file}.1"
    
    # Then replace the full path (including cumulative_build_stages_0_to_10) with BUILD_ROOT
    # This handles: /home/midhun/.../cumulative_build_stages_0_to_10/... -> ${BUILD_ROOT}/...
    sed "s|/home/midhun/Documents/Singularity_image_creation_script_xubuntu_robotics_base/cumulative_build_stages_0_to_10|${BUILD_ROOT}|g" \
        "${temp_file}.1" > "${temp_file}.2"
    
    # Then replace just the base repo path (for paths that don't include cumulative_build_stages_0_to_10)
    # But only if it's not already been replaced (avoid creating duplicates)
    sed "s|/home/midhun/Documents/Singularity_image_creation_script_xubuntu_robotics_base\([^/]\)|${BUILD_ROOT}\1|g" \
        "${temp_file}.2" > "${temp_file}"
    
    # Final cleanup: remove any duplicates that might have been created
    sed "s|${BUILD_ROOT}/cumulative_build_stages_0_to_10|${BUILD_ROOT}|g" \
        "${temp_file}" > "${temp_file}.final"
    
    mv "${temp_file}.final" "${temp_file}"
    rm -f "${temp_file}.1" "${temp_file}.2" 2>/dev/null || true
    
    # Replace the original file
    mv "${temp_file}" "${def_file}"
}

# Function to build a single stage
build_stage() {
    local stage_num="$1"
    local prev_stage_num=$((stage_num - 1))
    local is_final_stage="${2:-false}"
    
    # Find the definition file for this stage
    local def_file=$(ls "${STAGES_DIR}/stage_$(printf "%02d" ${stage_num})_"*.def | head -1)
    local def_basename=$(basename "${def_file}")
    
    # Determine output file name
    # For intermediate stages: use temp location if not keeping them
    # For final stage: always use final output location
    if [ "${is_final_stage}" = "true" ]; then
        local output_file="${OUTPUT_DIR}/stage_$(printf "%02d" ${stage_num})_final.sif"
    elif [ "${KEEP_INTERMEDIATE}" = true ]; then
        local output_file="${OUTPUT_DIR}/stage_$(printf "%02d" ${stage_num})_final.sif"
    else
        # Use temporary location for intermediate stages
        local output_file="${BUILD_ROOT}/tmp/stage_$(printf "%02d" ${stage_num})_temp.sif"
    fi
    local log_file="${LOGS_DIR}/stage_$(printf "%02d" ${stage_num})_build.log"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "BUILDING STAGE ${stage_num}: ${def_basename}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Update paths in definition file to use BUILD_ROOT
    echo "Updating paths in definition file..."
    update_def_paths "${def_file}"
    
        # For stages > 0, update the From: path to point to previous stage
        if [ ${stage_num} -gt 0 ]; then
            # Determine previous stage output location
            local prev_output
            if [ "${KEEP_INTERMEDIATE}" = true ]; then
                prev_output="${OUTPUT_DIR}/stage_$(printf "%02d" ${prev_stage_num})_final.sif"
            else
                # Previous stage might be in temp location
                prev_output="${BUILD_ROOT}/tmp/stage_$(printf "%02d" ${prev_stage_num})_temp.sif"
                # Fallback to output directory if not in temp
                if [ ! -f "${prev_output}" ]; then
                    prev_output="${OUTPUT_DIR}/stage_$(printf "%02d" ${prev_stage_num})_final.sif"
                fi
            fi
            
            if [ ! -f "${prev_output}" ]; then
                echo "Error: Previous stage image not found: ${prev_output}" >&2
                echo "       Please build Stage ${prev_stage_num} first" >&2
                exit 1
            fi
            
            # Get absolute path (resolve any symlinks or relative paths)
            # Use readlink -f first (GNU), fallback to realpath (BSD/macOS), then use original if both fail
            local prev_output_abs
            if command -v readlink >/dev/null 2>&1; then
                prev_output_abs=$(readlink -f "${prev_output}" 2>/dev/null || echo "${prev_output}")
            elif command -v realpath >/dev/null 2>&1; then
                prev_output_abs=$(realpath "${prev_output}" 2>/dev/null || echo "${prev_output}")
            else
                # If neither is available, convert to absolute path manually
                if [[ "${prev_output}" = /* ]]; then
                    prev_output_abs="${prev_output}"
                else
                    prev_output_abs="${BUILD_ROOT}/${prev_output}"
                fi
            fi
            
            # Verify the absolute path exists
            if [ ! -f "${prev_output_abs}" ]; then
                echo "Error: Previous stage image not found at resolved path: ${prev_output_abs}" >&2
                echo "       Original path: ${prev_output}" >&2
                echo "       Build root: ${BUILD_ROOT}" >&2
                echo "       Please verify Stage ${prev_stage_num} completed successfully" >&2
                exit 1
            fi
            
            # Update the Bootstrap and From: lines in the definition file
            # CRITICAL: When using a local SIF file, Bootstrap must be "localimage", not "docker"
            # Escape special characters in path for sed replacement string:
            # - Escape backslash (\)
            # - Escape ampersand (&) - represents matched text in replacement
            # - Escape delimiter (|) - our sed delimiter
            local prev_output_escaped=$(printf '%s\n' "${prev_output_abs}" | sed 's/\\/\\\\/g; s/&/\\&/g; s/|/\\|/g')
            
            # Change Bootstrap from docker to localimage when using local SIF
            sed -i "s|^Bootstrap:.*|Bootstrap: localimage|g" "${def_file}"
            
            # Update the From: line with the absolute path to the previous stage SIF
            sed -i "s|^From:.*|From: ${prev_output_escaped}|g" "${def_file}"
            echo "✓ Updated Bootstrap to 'localimage' and From: path to previous stage image: ${prev_output_abs}"
        fi
    
    # Setup bind mounts
    # CRITICAL: Use the SAME cache directory as main build scripts for reuse
    # This allows reusing packages already downloaded by build_xubuntu_robotics_base.sh
    local cache_dir="${MAIN_CACHE_DIR}"
    local tmp_dir="${BUILD_ROOT}/tmp"
    
    # Create cache directory structure if it doesn't exist (reuse existing if present)
    if [ ! -d "${cache_dir}" ]; then
        echo "  Creating cache directory: ${cache_dir}"
        mkdir -p "${cache_dir}"/{binaries,apt/archives,apt-temp,conda_pkgs,debs,julia_pkgs,wheels}
        chmod -R 755 "${cache_dir}" 2>/dev/null || true
    else
        echo "  ✓ Reusing existing cache directory: ${cache_dir}"
        echo "    Cache size: $(du -sh "${cache_dir}" 2>/dev/null | cut -f1 || echo 'unknown')"
        # Ensure subdirectories exist even if cache already exists
        mkdir -p "${cache_dir}"/{binaries,apt/archives,apt-temp,conda_pkgs,debs,julia_pkgs,wheels} 2>/dev/null || true
    fi
    
    mkdir -p "${tmp_dir}"
    chmod 1777 "${tmp_dir}" 2>/dev/null || chmod 777 "${tmp_dir}" 2>/dev/null || true
    
    local bind_spec="${cache_dir}:/container_cache:rw,${tmp_dir}:/tmp:rw,${tmp_dir}:/var/tmp:rw"
    
    # Set environment variables for bind mounts
    export APPTAINER_BINDPATH="${bind_spec}"
    export SINGULARITY_BINDPATH="${bind_spec}"
    export APPTAINER_TMPDIR="${tmp_dir}"
    export SINGULARITY_TMPDIR="${tmp_dir}"
    
    # Build command
    local build_cmd
    if [ "${USE_FAKEROOT}" = true ]; then
        build_cmd=(
            env "APPTAINER_BINDPATH=${bind_spec}" "APPTAINER_TMPDIR=${tmp_dir}" \
            "${CONTAINER_RUNTIME}" build \
            --fakeroot \
            --tmpdir "${tmp_dir}" \
            --force \
            "${output_file}" \
            "${def_file}"
        )
    else
        build_cmd=(
            sudo env "APPTAINER_BINDPATH=${bind_spec}" "APPTAINER_TMPDIR=${tmp_dir}" \
            "${CONTAINER_RUNTIME}" build \
            --tmpdir "${tmp_dir}" \
            --force \
            "${output_file}" \
            "${def_file}"
        )
    fi
    
    # Execute build with logging
    echo "Building Stage ${stage_num}..."
    echo "  Definition: ${def_file}"
    echo "  Output: ${output_file}"
    echo "  Log: ${log_file}"
    echo ""
    
    local build_start=$(date +%s)
    
    if "${build_cmd[@]}" 2>&1 | tee "${log_file}"; then
        local build_end=$(date +%s)
        local build_duration=$((build_end - build_start))
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✓ STAGE ${stage_num} BUILD COMPLETE"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Duration: ${build_duration} seconds"
        echo "  Output: ${output_file}"
        echo "  Size: $(du -h "${output_file}" | cut -f1)"
        echo ""
        
        # Verify image is valid
        if "${CONTAINER_RUNTIME}" inspect "${output_file}" >/dev/null 2>&1; then
            echo "  ✓ Image is valid"
        else
            echo "  ✗ Image validation failed" >&2
            exit 1
        fi
        
        # Set correct permissions
        chmod 644 "${output_file}" 2>/dev/null || sudo chmod 644 "${output_file}" 2>/dev/null || true
        
        # Run test cases for this stage (if test_cases.sh exists)
        if [ -f "${BUILD_ROOT}/test_cases.sh" ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "POST-BUILD: Running test suite for Stage ${stage_num}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # Create test script for container-side tests
            TEST_SCRIPT_TMP="${BUILD_ROOT}/tmp/test_stage_${stage_num}_container_$$.sh"
            mkdir -p "${BUILD_ROOT}/tmp"
            cat > "${TEST_SCRIPT_TMP}" <<TESTEOF
#!/bin/bash
set -euo pipefail

# Export environment variables needed for container-side tests
export HOST_CACHE_BIND_SRC="${cache_dir}"
export CONTAINER_TMP_BIND="${tmp_dir}"

# Source test cases (embedded)
$(cat "${BUILD_ROOT}/test_cases.sh")

# Run container-side tests
run_stage_tests ${stage_num} container
TESTEOF
            chmod +x "${TEST_SCRIPT_TMP}"
            
            # Check if runtime supports --writable-tmpfs
            OVERLAY_OPTS=""
            if "${CONTAINER_RUNTIME}" --version 2>/dev/null | grep -qE "apptainer|singularity.*3\.[0-9]|singularity.*[4-9]" 2>/dev/null; then
                OVERLAY_OPTS="--writable-tmpfs"
            fi
            
            # Run tests inside container
            if cat "${TEST_SCRIPT_TMP}" | "${CONTAINER_RUNTIME}" exec ${OVERLAY_OPTS} --bind "${bind_spec}" "${output_file}" bash -s 2>&1; then
                echo ""
                echo "  ✓ All tests passed for Stage ${stage_num}"
            else
                TEST_EXIT=$?
                echo ""
                echo "  ✗ Tests failed for Stage ${stage_num} (exit code: ${TEST_EXIT})" >&2
                echo "  Build will continue, but please review test failures" >&2
                # Don't exit - allow build to continue, but warn user
            fi
            
            rm -f "${TEST_SCRIPT_TMP}" 2>/dev/null || true
        else
            echo ""
            echo "  ⚠ test_cases.sh not found - skipping test suite"
        fi
        
        # Cleanup previous stage image if not keeping intermediate images
        if [ "${KEEP_INTERMEDIATE}" != true ] && [ ${stage_num} -gt 0 ]; then
            local prev_output
            if [ ${prev_stage_num} -eq 0 ] || [ "${KEEP_INTERMEDIATE}" = true ]; then
                prev_output="${OUTPUT_DIR}/stage_$(printf "%02d" ${prev_stage_num})_final.sif"
            else
                prev_output="${BUILD_ROOT}/tmp/stage_$(printf "%02d" ${prev_stage_num})_temp.sif"
            fi
            
            if [ -f "${prev_output}" ]; then
                local prev_size=$(du -h "${prev_output}" | cut -f1)
                rm -f "${prev_output}"
                echo "  ✓ Cleaned up previous stage image (${prev_size} freed)"
            fi
        fi
        
        return 0
    else
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✗ STAGE ${stage_num} BUILD FAILED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Check log file: ${log_file}"
        echo ""
        exit 1
    fi
}

# Build all stages sequentially
TOTAL_START=$(date +%s)

for stage_num in $(seq 0 10); do
    # Determine if this is the final stage
    if [ ${stage_num} -eq 10 ]; then
        build_stage "${stage_num}" "true"
    else
        build_stage "${stage_num}" "false"
    fi
done

TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ CUMULATIVE BUILD COMPLETE: Stages 0 to 10"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total Duration: ${TOTAL_DURATION} seconds ($((${TOTAL_DURATION} / 60)) minutes)"
echo "  Final Image: ${OUTPUT_DIR}/stage_10_final.sif"
echo "  Final Image Size: $(du -h "${OUTPUT_DIR}/stage_10_final.sif" | cut -f1)"
echo ""

# Cleanup any remaining temporary files
if [ "${KEEP_INTERMEDIATE}" != true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CLEANUP: Removing any remaining temporary files"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    rm -f "${BUILD_ROOT}/tmp"/stage_*_temp.sif 2>/dev/null || true
    echo "  ✓ Cleanup complete"
    echo ""
fi

# Show final result
if [ "${KEEP_INTERMEDIATE}" = true ]; then
    echo "All stage images (kept for debugging):"
    ls -lh "${OUTPUT_DIR}"/stage_*_final.sif 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
else
    echo "Final image (intermediate stages were built and discarded):"
    ls -lh "${OUTPUT_DIR}"/stage_10_final.sif 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    echo "Note: Use --keep-intermediate to keep all stage images for debugging"
fi

echo ""
echo "✓ Build completed successfully!"
echo "  Only one SIF file created: stage_10_final.sif"
echo ""

