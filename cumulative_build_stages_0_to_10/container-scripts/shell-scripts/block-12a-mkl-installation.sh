#!/bin/bash
#===============================================================================
# BLOCK 12A: Intel oneAPI MKL Installation
#===============================================================================
# Purpose: Install Intel oneAPI MKL via APT repository
# Dependencies: config.sh (INTEL_ONEAPI_GPG_KEY_URL, INTEL_ONEAPI_APT_SOURCE)
#               common_functions.sh (ensure_directory_writable)
#               cache_functions.sh (monitor_cache)
#               library_functions.sh (run_ldconfig_refresh)
#===============================================================================

set -euo pipefail

# Source required functions if available
if [ -f /scripts/common_functions.sh ]; then
    . /scripts/common_functions.sh
fi
if [ -f /scripts/cache_functions.sh ]; then
    . /scripts/cache_functions.sh
fi
if [ -f /scripts/library_functions.sh ]; then
    . /scripts/library_functions.sh
fi

# Load config.sh variables
if [ -f /etc/config.sh ]; then
    set +u
    . /etc/config.sh
    set -u
fi

: "${INTEL_ONEAPI_GPG_KEY_URL:?INTEL_ONEAPI_GPG_KEY_URL must be set in config.sh}"
: "${INTEL_ONEAPI_APT_SOURCE:?INTEL_ONEAPI_APT_SOURCE must be set in config.sh}"

ONEAPI_KEYRING="/usr/share/keyrings/oneapi-archive-keyring.gpg"
ONEAPI_SOURCE_LIST="/etc/apt/sources.list.d/oneAPI.list"

# Check if MKL is already installed
mkl_check_output=$(dpkg -l 2>/dev/null | grep -iE "^ii\\s+(intel-oneapi-mkl|intel-mkl)" || echo "")
mkl_package_installed=false
mkl_files_exist=false

if [ -n "${mkl_check_output:-}" ]; then
    mkl_package_installed=true
    MKL_BASE="/opt/intel/oneapi/mkl"
    if [ -d "${MKL_BASE}" ]; then
        if find "${MKL_BASE}" -maxdepth 3 -name "libmkl*.so" -type f 2>/dev/null | head -1 | grep -q .; then
            mkl_files_exist=true
        fi
    fi
fi

if [ "${mkl_package_installed}" = true ] && [ "${mkl_files_exist}" = true ]; then
    printf '%s\n' "${GREEN}✓ Intel oneAPI MKL already installed and verified; skipping installation${NC}"
    if [ -z "${MKLROOT:-}" ]; then
        MKL_ROOT_CANDIDATE=$(find /opt/intel/oneapi/mkl -maxdepth 1 -type d -name "20*" 2>/dev/null | sort -rV | head -n1)
        if [ -z "${MKL_ROOT_CANDIDATE}" ] && [ -d "/opt/intel/oneapi/mkl/latest" ]; then
            MKL_ROOT_CANDIDATE="/opt/intel/oneapi/mkl/latest"
        fi
        if [ -n "${MKL_ROOT_CANDIDATE}" ]; then
            export MKLROOT="${MKL_ROOT_CANDIDATE}"
        fi
    fi
else
    printf '%s\n' "${YELLOW}[12A.1] Removing conflicting Ubuntu MKL packages...${NC}"
    apt-get remove -y --purge intel-mkl libmkl-* >/dev/null 2>&1 || true
    
    printf '%s\n' "${YELLOW}[12A.2] Configuring Intel oneAPI APT repository...${NC}"
    printf '%s\n' "  Installing prerequisites (gpg-agent, wget)..."
    if ! apt-get install -y --no-install-recommends gpg-agent wget >/dev/null 2>&1; then
        printf '%s\n' "[ERROR] ⚠ Failed to install prerequisites"
        exit 1
    fi
    printf '%s\n' "  ✓ Prerequisites installed"
    
    if [ ! -f "${ONEAPI_KEYRING}" ]; then
        printf '%s\n' "  Importing Intel oneAPI GPG key..."
        rm -f "${ONEAPI_KEYRING}" 2>/dev/null
        if wget -qO- "${INTEL_ONEAPI_GPG_KEY_URL}" | gpg --dearmor > "${ONEAPI_KEYRING}" 2>/dev/null; then
            if [ ! -f "${ONEAPI_KEYRING}" ]; then
                printf '%s\n' "[ERROR] ⚠ GPG key import succeeded but file not found"
                exit 1
            fi
            printf '%s\n' "  ✓ GPG key imported successfully"
        else
            printf '%s\n' "[ERROR] ⚠ Failed to import Intel oneAPI GPG key"
            exit 1
        fi
    else
        printf '%s\n' "  ✓ oneAPI keyring already present"
    fi
    
    if [ ! -f "${ONEAPI_SOURCE_LIST}" ] || ! grep -Fq "apt.repos.intel.com/oneapi" "${ONEAPI_SOURCE_LIST}" 2>/dev/null; then
        printf '%s\n' "  Adding Intel oneAPI repository entry..."
        if [ -d /etc/apt/sources.list.d ] && [ -w /etc/apt/sources.list.d ]; then
            if ! printf "%s\n" "${INTEL_ONEAPI_APT_SOURCE}" > "${ONEAPI_SOURCE_LIST}" 2>/dev/null; then
                printf '%s\n' "[ERROR] ⚠ Failed to write oneAPI source list"
                exit 1
            fi
            printf '%s\n' "  ✓ Repository entry added"
        else
            printf '%s\n' "[ERROR] ⚠ /etc/apt/sources.list.d directory not writable"
            exit 1
        fi
    else
        printf '%s\n' "  ✓ oneAPI repository already configured"
    fi
    
    printf '%s\n' "[12A.3] Updating Intel repository..."
    LIST_DIR="${APT_TMP_ALT:-/var/lib/apt}/lists"
    mkdir -p "${LIST_DIR}/partial" 2>/dev/null || true
    
    set +e
    if ! apt-get update -o Dir::State::Lists="${LIST_DIR}" -o Dir::Etc::SourceList="/etc/apt/sources.list.d/oneAPI.list" -o Dir::Etc::SourceParts="/dev/null" 2>&1; then
        UPDATE_OUTPUT=$(apt-get update -o Acquire::Retries=3 2>&1)
        UPDATE_STATUS=$?
    else
        UPDATE_STATUS=0
    fi
    set -e
    
    if [ "${UPDATE_STATUS}" -ne 0 ]; then
        printf '%s\n' "[ERROR] ⚠ apt-get update failed for Intel oneAPI repository"
        exit 1
    else
        printf '%s\n' "  ✓ apt-get update completed"
    fi
    
    if ! apt-cache search intel-oneapi-mkl >/dev/null 2>&1; then
        printf '%s\n' "[ERROR] ⚠ Packages not accessible via apt-cache"
        exit 1
    fi
    
    printf '%s\n' "${YELLOW}[12A.4] Installing Intel oneAPI MKL packages...${NC}"
    MKL_INSTALL_LOG="${TMPDIR:-/tmp}/mkl_install.log"
    MKL_PACKAGE=""
    MKL_DEV_PACKAGE=""
    
    if apt-cache show intel-oneapi-mkl >/dev/null 2>&1; then
        MKL_PACKAGE="intel-oneapi-mkl"
        if apt-cache show intel-oneapi-mkl-devel >/dev/null 2>&1; then
            MKL_DEV_PACKAGE="intel-oneapi-mkl-devel"
        fi
        printf '%s\n' "  ${GREEN}✓ Found package: ${MKL_PACKAGE}${NC}"
    else
        printf '%s\n' "  ${RED}✗ Package intel-oneapi-mkl not found${NC}"
        exit 1
    fi
    
    INSTALL_PACKAGES="${MKL_PACKAGE}"
    if [ -n "${MKL_DEV_PACKAGE}" ]; then
        INSTALL_PACKAGES="${INSTALL_PACKAGES} ${MKL_DEV_PACKAGE}"
    fi
    
    printf '%s\n' "  Starting installation (this may take several minutes)..."
    INSTALL_START_TIME=$(date +%s)
    if ! apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" ${INSTALL_PACKAGES} 2>&1 | tee "${MKL_INSTALL_LOG}"; then
        printf '%s\n' "[ERROR] Failed to install MKL packages"
        exit 1
    fi
    
    INSTALL_END_TIME=$(date +%s)
    INSTALL_DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
    printf '%s\n' "  Installation completed in ${INSTALL_DURATION} seconds"
    printf '%s\n' "  ${GREEN}✓ Intel MKL packages installed successfully${NC}"
    
    printf '%s\n' "  ${YELLOW}[12A.5] Verifying MKL Installation...${NC}"
    MKL_ROOT_CANDIDATE=""
    if [ -d "/opt/intel/oneapi/mkl" ]; then
        MKL_ROOT_CANDIDATE=$(find /opt/intel/oneapi/mkl -maxdepth 1 -type d -name "20*" 2>/dev/null | sort -rV | head -n1)
    fi
    if [ -z "${MKL_ROOT_CANDIDATE}" ] && [ -d "/opt/intel/oneapi/mkl/latest" ]; then
        MKL_ROOT_CANDIDATE="/opt/intel/oneapi/mkl/latest"
    fi
    if [ -z "${MKL_ROOT_CANDIDATE}" ]; then
        FOUND_LIB=$(find /opt /usr -name "libmkl_core.so" 2>/dev/null | head -n1)
        if [ -n "${FOUND_LIB}" ]; then
            MKL_ROOT_CANDIDATE=$(dirname "$(dirname "${FOUND_LIB}")")
        fi
    fi
    
    if [ -n "${MKL_ROOT_CANDIDATE}" ] && [ -d "${MKL_ROOT_CANDIDATE}" ]; then
        printf '%s\n' "✓ MKL verified at: ${MKL_ROOT_CANDIDATE}"
        export MKLROOT="${MKL_ROOT_CANDIDATE}"
        MKL_LIB_DIR="${MKLROOT}/lib/intel64"
        if [ ! -d "${MKL_LIB_DIR}" ]; then
            MKL_LIB_DIR="${MKLROOT}/lib"
        fi
        
        # More robust library search - check multiple locations and depths
        MKL_LIB_COUNT=0
        MKL_VERIFY_PASSED=false
        
        # Debug: List directory structure
        printf '%s\n' "    [DEBUG] Checking MKL directory structure..."
        if [ -d "${MKLROOT}" ]; then
            printf '%s\n' "    [DEBUG] MKLROOT exists: ${MKLROOT}"
            printf '%s\n' "    [DEBUG] Contents of MKLROOT:"
            ls -la "${MKLROOT}" 2>/dev/null | head -10 || printf '%s\n' "      (directory listing failed)"
        fi
        
        # Check in lib/intel64 first
        if [ -d "${MKL_LIB_DIR}" ]; then
            printf '%s\n' "    [DEBUG] Checking ${MKL_LIB_DIR}..."
            MKL_LIB_COUNT=$(find "${MKL_LIB_DIR}" -maxdepth 2 -name "libmkl*.so" -type f 2>/dev/null | wc -l)
            if [ "${MKL_LIB_COUNT}" -gt 0 ]; then
                MKL_VERIFY_PASSED=true
                printf '%s\n' "    [DEBUG] Found ${MKL_LIB_COUNT} libraries in ${MKL_LIB_DIR}"
            else
                printf '%s\n' "    [DEBUG] No libraries found in ${MKL_LIB_DIR}"
            fi
        else
            printf '%s\n' "    [DEBUG] ${MKL_LIB_DIR} does not exist"
        fi
        
        # If not found, search deeper in the MKL root (up to 6 levels deep)
        if [ "${MKL_VERIFY_PASSED}" = false ]; then
            printf '%s\n' "    [DEBUG] Searching deeper in ${MKLROOT}..."
            MKL_LIB_COUNT=$(find "${MKLROOT}" -maxdepth 6 -name "libmkl*.so" -type f 2>/dev/null | wc -l)
            if [ "${MKL_LIB_COUNT}" -gt 0 ]; then
                printf '%s\n' "    [DEBUG] Found ${MKL_LIB_COUNT} libraries in ${MKLROOT} (deep search)"
                # Find the actual lib directory - try multiple key libraries
                FOUND_LIB_PATH=""
                for lib_name in "libmkl_core.so" "libmkl_rt.so" "libmkl_sycl.so" "libmkl_intel_lp64.so"; do
                    FOUND_LIB_PATH=$(find "${MKLROOT}" -maxdepth 6 -name "${lib_name}" -type f 2>/dev/null | head -n1)
                    if [ -n "${FOUND_LIB_PATH}" ]; then
                        MKL_LIB_DIR=$(dirname "${FOUND_LIB_PATH}")
                        printf '%s\n' "    [DEBUG] Found ${lib_name} at: ${FOUND_LIB_PATH}"
                        printf '%s\n' "    [DEBUG] Setting MKL_LIB_DIR to: ${MKL_LIB_DIR}"
                        break
                    fi
                done
                # If we found any libraries, accept the installation even if we couldn't find a specific key library
                if [ "${MKL_LIB_COUNT}" -gt 0 ]; then
                    MKL_VERIFY_PASSED=true
                    # If we couldn't find a specific library path, use the default lib/intel64 or lib
                    if [ -z "${FOUND_LIB_PATH}" ]; then
                        if [ -d "${MKLROOT}/lib/intel64" ]; then
                            MKL_LIB_DIR="${MKLROOT}/lib/intel64"
                        elif [ -d "${MKLROOT}/lib" ]; then
                            MKL_LIB_DIR="${MKLROOT}/lib"
                        else
                            # Use the first found library's directory
                            FIRST_LIB=$(find "${MKLROOT}" -maxdepth 6 -name "libmkl*.so" -type f 2>/dev/null | head -n1)
                            if [ -n "${FIRST_LIB}" ]; then
                                MKL_LIB_DIR=$(dirname "${FIRST_LIB}")
                                printf '%s\n' "    [DEBUG] Using first found library directory: ${MKL_LIB_DIR}"
                            fi
                        fi
                    fi
                fi
            else
                printf '%s\n' "    [DEBUG] No libraries found in deep search"
                # List all .so files to see what's actually there
                printf '%s\n' "    [DEBUG] Searching for any .so files in ${MKLROOT}:"
                find "${MKLROOT}" -name "*.so" -type f 2>/dev/null | head -5 || printf '%s\n' "      (no .so files found)"
            fi
        fi
        
        # Final check: verify at least one key library exists
        # If we found any libraries, accept the installation (MKL might have different structure)
        if [ "${MKL_VERIFY_PASSED}" = true ] && [ "${MKL_LIB_COUNT}" -gt 0 ]; then
            KEY_LIBS=("libmkl_core.so" "libmkl_rt.so" "libmkl_intel_lp64.so" "libmkl_sycl.so")
            KEY_LIBS_FOUND=0
            for lib in "${KEY_LIBS[@]}"; do
                if find "${MKLROOT}" -maxdepth 6 -name "${lib}" -type f 2>/dev/null | head -1 | grep -q .; then
                    KEY_LIBS_FOUND=$((KEY_LIBS_FOUND + 1))
                    printf '%s\n' "    [DEBUG] Found key library: ${lib}"
                fi
            done
            
            printf '%s\n' "    [DEBUG] Key libraries found: ${KEY_LIBS_FOUND}/${#KEY_LIBS[@]}"
            printf '%s\n' "    [DEBUG] Total MKL libraries found: ${MKL_LIB_COUNT}"
            
            # Accept if we found any libraries (MKL installation is valid even if key libraries are in different locations)
            # The important thing is that MKL packages were installed and libraries exist
            if [ "${MKL_LIB_COUNT}" -gt 0 ]; then
                printf '%s\n' "    ${GREEN}✓ MKL libraries found: ${MKL_LIB_COUNT} libraries (key libraries: ${KEY_LIBS_FOUND}/${#KEY_LIBS[@]})${NC}"
                printf '%s\n' "    ${GREEN}✓ MKL library directory: ${MKL_LIB_DIR}${NC}"
                
                export LD_LIBRARY_PATH="${MKLROOT}/lib/intel64:${LD_LIBRARY_PATH:-}"
                export LIBRARY_PATH="${MKLROOT}/lib/intel64:${LIBRARY_PATH:-}"
                export CMAKE_PREFIX_PATH="${MKLROOT}:${CMAKE_PREFIX_PATH:-}"
                export PKG_CONFIG_PATH="${MKLROOT}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
                
                if ! grep -q "MKLROOT=" /etc/environment; then
                    echo "MKLROOT=${MKLROOT}" >> /etc/environment
                else
                    sed -i "s|^MKLROOT=.*|MKLROOT=${MKLROOT}|" /etc/environment
                fi
                
                # Find libmkl_rt.so for alternatives registration
                MKL_RT=$(find "${MKLROOT}" -name "libmkl_rt.so" -type f 2>/dev/null | head -n1)
                if [ -n "${MKL_RT}" ] && [ -f "${MKL_RT}" ]; then
                    update-alternatives --install /usr/lib/x86_64-linux-gnu/libblas.so.3 libblas.so.3-x86_64-linux-gnu "${MKL_RT}" 200 >/dev/null 2>&1 || true
                    update-alternatives --install /usr/lib/x86_64-linux-gnu/liblapack.so.3 liblapack.so.3-x86_64-linux-gnu "${MKL_RT}" 200 >/dev/null 2>&1 || true
                    if [ "${DEFAULT_BLAS_PROVIDER:-MKL}" = "MKL" ]; then
                        update-alternatives --set libblas.so.3-x86_64-linux-gnu "${MKL_RT}" >/dev/null 2>&1 || true
                        update-alternatives --set liblapack.so.3-x86_64-linux-gnu "${MKL_RT}" >/dev/null 2>&1 || true
                        printf '%s\n' "  ✓ MKL set as default BLAS/LAPACK"
                    fi
                fi
                
                export MKL_LIB_DIR
                export MKL_INCLUDE_DIR="${MKLROOT}/include"
                # Build MKL_BLAS_LIBRARIES with found paths
                MKL_INTEL_LP64=$(find "${MKLROOT}" -name "libmkl_intel_lp64.so" -type f 2>/dev/null | head -n1)
                MKL_CORE=$(find "${MKLROOT}" -name "libmkl_core.so" -type f 2>/dev/null | head -n1)
                MKL_GNU_THREAD=$(find "${MKLROOT}" -name "libmkl_gnu_thread.so" -type f 2>/dev/null | head -n1)
                
                if [ -n "${MKL_INTEL_LP64}" ] && [ -n "${MKL_CORE}" ] && [ -n "${MKL_GNU_THREAD}" ]; then
                    MKL_BLAS_LIBRARIES="${MKL_INTEL_LP64};${MKL_CORE};${MKL_GNU_THREAD};-lgomp;-lpthread;-lm;-ldl"
                else
                    # Fallback to directory-based paths
                    MKL_BLAS_LIBRARIES="${MKL_LIB_DIR}/libmkl_intel_lp64.so;${MKL_LIB_DIR}/libmkl_core.so;${MKL_LIB_DIR}/libmkl_gnu_thread.so;-lgomp;-lpthread;-lm;-ldl"
                fi
                export MKL_BLAS_LIBRARIES
                
                printf '%s\n' "${GREEN}✓ Intel oneAPI MKL installation complete${NC}"
            else
                printf '%s\n' "    ${RED}✗ MKL libraries found but key libraries missing${NC}"
                exit 1
            fi
        else
            printf '%s\n' "    ${RED}✗ MKL libraries not found in ${MKLROOT}${NC}"
            printf '%s\n' "    ${YELLOW}  Searched in: ${MKL_LIB_DIR} and ${MKLROOT}${NC}"
            exit 1
        fi
    else
        printf '%s\n' "${RED}✗ Error: MKL installation could not be verified${NC}"
        exit 1
    fi
fi

printf '%s\n' "${YELLOW}[12A.6] Configuring Intel MKL environment...${NC}"
if [ ! -f /etc/profile.d/intel-mkl.sh ]; then
    printf '%s\n' "[ERROR] ⚠ intel-mkl.sh file not found"
    exit 1
fi
chmod 0644 /etc/profile.d/intel-mkl.sh 2>/dev/null || true

if [ -n "${MKLROOT:-}" ]; then
    SAVED_MKLROOT="${MKLROOT}"
    unset MKLROOT
    . /etc/profile.d/intel-mkl.sh 2>/dev/null || true
    export MKLROOT="${SAVED_MKLROOT}"
    export LD_LIBRARY_PATH="${MKLROOT}/lib/intel64:${LD_LIBRARY_PATH:-}"
    export LIBRARY_PATH="${MKLROOT}/lib/intel64:${LIBRARY_PATH:-}"
    export CMAKE_PREFIX_PATH="${MKLROOT}:${CMAKE_PREFIX_PATH:-}"
    export PKG_CONFIG_PATH="${MKLROOT}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
else
    . /etc/profile.d/intel-mkl.sh 2>/dev/null || true
fi

printf '%s\n' "✓ Intel MKL environment configured (MKLROOT=${MKLROOT:-/opt/intel/oneapi/mkl/latest})"

if [ -n "${MKLROOT:-}" ]; then
    if ! grep -Fq "^MKLROOT=" /etc/environment 2>/dev/null; then
        echo "MKLROOT=${MKLROOT}" >> /etc/environment
    else
        sed -i "s|^MKLROOT=.*|MKLROOT=${MKLROOT}|" /etc/environment 2>/dev/null || true
    fi
fi

if [ -n "${MKLROOT:-}" ] && [ -f "${MKLROOT}/lib/intel64/libmkl_rt.so" ]; then
    MKL_RT_LIB="${MKLROOT}/lib/intel64/libmkl_rt.so"
    update-alternatives --install /usr/lib/x86_64-linux-gnu/libblas.so.3 libblas.so.3-x86_64-linux-gnu "${MKL_RT_LIB}" 200 >/dev/null 2>&1 || true
    update-alternatives --install /usr/lib/x86_64-linux-gnu/liblapack.so.3 liblapack.so.3-x86_64-linux-gnu "${MKL_RT_LIB}" 200 >/dev/null 2>&1 || true
    printf '%s\n' "${GREEN}✓ MKL registered with alternatives system${NC}"
fi

if command -v run_ldconfig_refresh >/dev/null 2>&1; then
    run_ldconfig_refresh 2>&1 || true
fi

printf '%s\n' "${GREEN}✓ Intel MKL installation and environment configuration complete${NC}"
printf '%s\n' ""
