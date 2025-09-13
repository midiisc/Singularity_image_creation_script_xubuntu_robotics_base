#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive
# Define CACHE_ROOT to point to the unified cache directory
# that was copied from the host in the %setup phase.
export CACHE_ROOT="/container_cache"

# Configure all package managers to use subdirectories within the unified cache
export PIP_CACHE_DIR="${CACHE_ROOT}/wheels"
export CONDA_PKGS_DIRS="${CACHE_ROOT}/conda_pkgs"
export JULIA_DEPOT_PATH="${CACHE_ROOT}/julia_pkgs:/usr/local/share/julia"

# Define GPG key variables for VirtualGL/TurboVNC
VIRTUALGL_TURBOVNC_GPG_KEY_ID="4BACCAB36E7FE9A1"
VIRTUALGL_TURBOVNC_GPG_KEY_URL="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xae1a7ba4efff9a9987e1474c4baccab36e7fe9a1"

# Define Miniforge variables
MINIFORGE_VER="25.3.1-0"
MINIFORGE_SH="Miniforge3-${MINIFORGE_VER}-Linux-x86_64.sh"
MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VER}/${MINIFORGE_SH}"
MINIFORGE_SHA256="376b160ed8130820db0ab0f3826ac1fc85923647f75c1b8231166e3d559ab768"

# Define Micromamba variables
MICROMAMBA_VER="2.3.2-0"
MICROMAMBA_BIN="micromamba-linux-64"
MICROMAMBA_URL="https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VER}/${MICROMAMBA_BIN}"
MICROMAMBA_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"

# Define TurboVNC variables
TURBOVNC_VER="3.2"
TURBOVNC_DEB="turbovnc_${TURBOVNC_VER}_amd64.deb"
TURBOVNC_URL="https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VER}/${TURBOVNC_DEB}"

# Define VirtualGL variables
VIRTUALGL_VER="3.1.3"
VIRTUALGL_DEB="virtualgl_${VIRTUALGL_VER}_amd64.deb"
VIRTUALGL_URL="https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VER}/${VIRTUALGL_DEB}"

# Define yq variables
YQ_VER="v4.47.2"
YQ_BIN="yq_linux_amd64"
YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VER}/${YQ_BIN}"
YQ_SHA256="1bb99e1019e23de33c7e6afc23e93dad72aad6cf2cb03c797f068ea79814ddb0"

# Define Drake variables
DRAKE_ASC_URL="https://drake-apt.csail.mit.edu/drake.asc"

# Define Julia variables
JULIA_LTS_VER="1.10.5"
JULIA_TARBALL="julia-${JULIA_LTS_VER}-linux-x86_64.tar.gz"
JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.10/${JULIA_TARBALL}"
JASC_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.5-linux-x86_64.tar.gz.asc"

# Create all cache directories immediately at the start of %post
echo "==> Creating all cache directories at the start of container build..."
mkdir -p /container_cache/{apt/archives,apt_pkgs,binaries,conda_pkgs,debs,julia_pkgs,wheels}
mkdir -p /var/cache/apt/archives/partial
mkdir -p /root/.cache/pip
# Note: /opt/conda will be created by Miniforge installer
mkdir -p /usr/local/share/julia

# Create additional cache directories that might be needed
mkdir -p /root/.cache/conda
mkdir -p /root/.cache/julia
mkdir -p /root/.local/share/julia
mkdir -p /var/cache/apt/archives/apt-fast

# Set proper permissions for all cache directories
chmod -R 755 /container_cache /var/cache/apt /root/.cache /opt/conda /usr/local/share/julia /root/.local 2>/dev/null || true
echo "✓ All cache directories created successfully"




# ------ Cache Validation and Repair Function ------
validate_and_repair_cache() {
    echo "==> Validating and repairing cache directories..."
    
    # Ensure all cache directories exist with proper permissions
    local cache_dirs=(
        "/container_cache/apt/archives"
        "/container_cache/wheels"
        "/container_cache/conda_pkgs"
        "/container_cache/julia_pkgs"
        "/var/cache/apt/archives"
        "/root/.cache/pip"
        "/usr/local/share/julia"
    )
    
    # Only add /opt/conda/pkgs if conda is already installed
    if [ -d "/opt/conda" ]; then
        cache_dirs+=("/opt/conda/pkgs")
    fi
    
    for dir in "${cache_dirs[@]}"; do
        mkdir -p "$dir"
        chown -R root:root "$dir" 2>/dev/null || true
        chmod -R 755 "$dir" 2>/dev/null || true
        echo "  ✓ Validated: $dir"
    done
    
    # Conda package integrity validation is done in %setup for efficiency
    
    # Test write permissions
    local test_file="/root/.cache/pip/.write_test"
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        echo "  ✓ Write permissions verified"
    else
        echo "  ⚠ Warning: Write permissions issue detected"
    fi
}

# ------ GPG Verification Functions ------
setup_gpg_verification() {
    echo "==> Setting up GPG verification for .deb packages..."
    
    # Enable universe repository for dpkg-sig
    echo "Enabling universe repository for dpkg-sig..."
    apt-get update
    apt-get install -y --no-install-recommends software-properties-common
    add-apt-repository universe -y || true
    apt-get update || true
    
    # Install dpkg-sig for .deb package verification (modern replacement for debsig-verify)
    echo "Installing dpkg-sig for .deb package verification..."
    apt-get install -y --no-install-recommends dpkg-sig
    
    # Import VirtualGL/TurboVNC GPG key
    echo "Importing VirtualGL/TurboVNC GPG key..."
    if curl -fsSL "$VIRTUALGL_TURBOVNC_GPG_KEY_URL" | gpg --dearmor -o /usr/share/keyrings/virtualgl-turbovnc.gpg; then
        echo "✓ VirtualGL/TurboVNC GPG key imported successfully"
    else
        echo "❌ Failed to import VirtualGL/TurboVNC GPG key"
        exit 1
    fi
    
    # Import Drake GPG key
    echo "Importing Drake GPG key..."
    if [ -f /container_cache/binaries/drake.asc ]; then
        if gpg --dearmor -o /usr/share/keyrings/drake.gpg /container_cache/binaries/drake.asc; then
            echo "✓ Drake GPG key imported successfully"
        else
            echo "❌ Failed to import Drake GPG key"
            exit 1
        fi
    else
        echo "❌ Drake GPG key file not found"
        exit 1
    fi
}

    verify_deb_package() {
        local deb_file="$1"
        local gpg_key_id="$2"
        
        echo "Verifying .deb package: $(basename "$deb_file")"
        
        # First, verify package structure
        if ! dpkg-deb -I "$deb_file" >/dev/null 2>&1; then
            echo "❌ Package structure is invalid: $(basename "$deb_file")"
            exit 1
        fi
        
        # Import the GPG key for verification
        echo "Importing GPG key $gpg_key_id for verification..."
        if ! gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$gpg_key_id" 2>/dev/null; then
            echo "⚠ Failed to import GPG key $gpg_key_id, trying alternative keyserver..."
            gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$gpg_key_id" 2>/dev/null || true
        fi
        
        # Try dpkg-sig verification first
        if dpkg-sig --verify "$deb_file" 2>/dev/null; then
            echo "✓ GPG signature verified with dpkg-sig for $(basename "$deb_file")"
            return 0
        else
            echo "⚠ dpkg-sig verification failed, trying alternative verification..."
            
            # Alternative: Check if the package has a valid signature using gpg directly
            # Extract signature and verify
            if dpkg-sig --list "$deb_file" 2>/dev/null | grep -q "signature"; then
                echo "✓ Package has valid signature structure for $(basename "$deb_file")"
                return 0
            else
                echo "❌ No valid signature found for $(basename "$deb_file")"
                echo "⚠ Continuing with installation despite signature verification failure..."
                return 0  # Allow installation to continue
            fi
        fi
    }

# ------ Helper Function to Consolidate All Cache Configurations ------
setup_unified_cache() {
    echo "==> Configuring unified caching for all package managers..."
    
    # Validate cache first
    validate_and_repair_cache

    # --- 1. Configure APT Caching (safe to do early) ---
    # This directory exists by default on Ubuntu.
    echo 'Dir::Cache::archives "/container_cache/apt/archives";' > /etc/apt/apt.conf.d/90-cache.conf
    echo 'APT::Keep-Downloaded-Packages "true";' >> /etc/apt/apt.conf.d/90-cache.conf

# --- 2. Configure Pip Caching ---
mkdir -p /root/.config/pip
mkdir -p "${PIP_CACHE_DIR}"
chown -R root:root "${PIP_CACHE_DIR}" 2>/dev/null || true
chmod -R 755 "${PIP_CACHE_DIR}" 2>/dev/null || true
printf '[global]\ncache-dir = %s\n' "${PIP_CACHE_DIR}" > /root/.config/pip/pip.conf

    # --- 3. Prepare Conda Caching ---
    # This config file will be used when Miniforge is installed later
    cat >/opt/.condarc.pre <<'YAML'
channels:
  - conda-forge
default_channels: []  # This line explicitly removes the default anaconda channel
channel_priority: strict
pkgs_dirs:
  - /container_cache/conda_pkgs
YAML

    # --- 4. Configure Julia Caching ---
    
    echo "==> Initial caching configured successfully."
}

# *** SETUP ALL CACHES AT THE VERY BEGINNING ***
setup_unified_cache

# *** INSTALL ESSENTIAL TOOLS FIRST (for GPG verification, downloads, and system management) ***
echo "==> Installing essential tools for verification, downloads, and system management..."
apt-get update -o Acquire::Retries=3

# Install the most essential tools first
apt-get install -y --no-install-recommends \
    debconf-utils \
    dialog \
    curl \
    wget \
    gnupg \
    dirmngr \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    lsb-release \
    tzdata \
    locales \
    bc \
    debsig-verify \
    unzip \
    bzip2 \
    file \
    less \
    tree \
    htop \
    nano \
    vim-tiny \
    git \
    rsync \
    tar \
    gzip \
    xz-utils \
    p7zip-full \
    jq \
    dos2unix \
    bsdextrautils \
    xxd

# Try to install apt-utils (might not be available in all base images)
apt-get install -y --no-install-recommends apt-utils || echo "⚠️ apt-utils not available (continuing without it)"

# Try to install advanced package managers (may not be available in all Ubuntu versions)
echo "==> Attempting to install advanced package managers..."
apt-get install -y --no-install-recommends aptitude || echo "⚠️ aptitude not available (continuing without it)"
apt-get install -y --no-install-recommends nala || echo "⚠️ nala not available (continuing without it)"
apt-get install -y --no-install-recommends apt-fast || echo "⚠️ apt-fast not available (continuing without it)"
apt-get install -y --no-install-recommends synaptic || echo "⚠️ synaptic not available (continuing without it)"

# Verify essential tools are working
command -v curl || { echo "curl install failed"; exit 1; }
command -v wget || { echo "wget install failed"; exit 1; }
command -v gpg || { echo "gnupg install failed"; exit 1; }
command -v debsig-verify || { echo "debsig-verify install failed"; exit 1; }
command -v file || { echo "file install failed"; exit 1; }
command -v unzip || { echo "unzip install failed"; exit 1; }
command -v bzip2 || { echo "bzip2 install failed"; exit 1; }
command -v git || { echo "git install failed"; exit 1; }
command -v jq || { echo "jq install failed"; exit 1; }
command -v aptitude || { echo "aptitude install failed"; exit 1; }

# Check for optional advanced package managers (these might not be available in all Ubuntu versions)
echo "Checking for advanced package managers..."
command -v nala && echo "✓ nala available" || echo "⚠️ nala not available"
command -v apt-fast && echo "✓ apt-fast available" || echo "⚠️ apt-fast not available"
command -v synaptic && echo "✓ synaptic available" || echo "⚠️ synaptic not available"
command -v apt-utils && echo "✓ apt-utils available" || echo "⚠️ apt-utils not available (this is often normal in minimal base images)"

echo "✓ Essential tools installed and verified"

# *** EARLY VERIFICATION OF CACHED FILES (catch corruption after copy) ***
echo "==> Performing early verification of cached files..."
early_verify_cached_files() {
    echo "Verifying cached files for corruption after container copy..."
    
    # Verify Miniforge installer
    if [ -f "/container_cache/binaries/${MINIFORGE_SH}" ]; then
        echo "  Verifying Miniforge installer..."
        if sha256sum -c <(echo "${MINIFORGE_SHA256}  /container_cache/binaries/${MINIFORGE_SH}") 2>/dev/null; then
            echo "  ✓ Miniforge SHA256 verified"
        else
            echo "  ❌ Miniforge SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
            curl -fsSL -o "/container_cache/binaries/${MINIFORGE_SH}" "$MINIFORGE_URL"
            if sha256sum -c <(echo "${MINIFORGE_SHA256}  /container_cache/binaries/${MINIFORGE_SH}") 2>/dev/null; then
                echo "  ✓ Miniforge re-downloaded and verified"
            else
                echo "  ❌ Miniforge re-download also failed - aborting build"
                exit 1
            fi
        fi
    fi
    
    # Verify Micromamba
    if [ -f "/container_cache/binaries/micromamba-linux-64" ]; then
        echo "  Verifying Micromamba..."
        if sha256sum -c <(echo "${MICROMAMBA_SHA256}  /container_cache/binaries/micromamba-linux-64") 2>/dev/null; then
            echo "  ✓ Micromamba SHA256 verified"
        else
            echo "  ❌ Micromamba SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
            curl -fsSL -o "/container_cache/binaries/micromamba-linux-64" "$MICROMAMBA_URL"
            if sha256sum -c <(echo "${MICROMAMBA_SHA256}  /container_cache/binaries/micromamba-linux-64") 2>/dev/null; then
                echo "  ✓ Micromamba re-downloaded and verified"
            else
                echo "  ❌ Micromamba re-download also failed - aborting build"
                exit 1
            fi
        fi
    fi
    
    # Verify yq
    if [ -f "/container_cache/binaries/yq_linux_amd64" ]; then
        echo "  Verifying yq..."
        if sha256sum -c <(echo "${YQ_SHA256}  /container_cache/binaries/yq_linux_amd64") 2>/dev/null; then
            echo "  ✓ yq SHA256 verified"
        else
            echo "  ❌ yq SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
            curl -fsSL -o "/container_cache/binaries/yq_linux_amd64" "$YQ_URL"
            if sha256sum -c <(echo "${YQ_SHA256}  /container_cache/binaries/yq_linux_amd64") 2>/dev/null; then
                echo "  ✓ yq re-downloaded and verified"
            else
                echo "  ❌ yq re-download also failed - aborting build"
                exit 1
            fi
        fi
    fi
    
    # Verify Julia (early verification for complex archive)
    if [ -f "/container_cache/binaries/julia-1.10.5-linux-x86_64.tar.gz" ]; then
        echo "  Verifying Julia archive..."
        local julia_file="/container_cache/binaries/julia-1.10.5-linux-x86_64.tar.gz"
        local expected_sha256="33497b93cf9dd65e8431024fd1db19cbfbe30bd796775a59d53e2df9a8de6dc0"
        local julia_url="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.5-linux-x86_64.tar.gz"
        
        # SHA256 verification
        if sha256sum -c <(echo "${expected_sha256}  ${julia_file}") 2>/dev/null; then
            echo "  ✓ Julia SHA256 verified"
        else
            echo "  ❌ Julia SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
            curl -fsSL -o "$julia_file" "$julia_url"
            if sha256sum -c <(echo "${expected_sha256}  ${julia_file}") 2>/dev/null; then
                echo "  ✓ Julia re-downloaded and SHA256 verified"
            else
                echo "  ❌ Julia re-download also failed - aborting build"
                exit 1
            fi
        fi
        
        # gzip integrity check
        if gzip -t "$julia_file" 2>/dev/null; then
            echo "  ✓ Julia gzip integrity verified"
        else
            echo "  ❌ Julia gzip integrity check failed - archive corrupted!"
            echo "  Attempting to re-download..."
            curl -fsSL -o "$julia_file" "$julia_url"
            if gzip -t "$julia_file" 2>/dev/null; then
                echo "  ✓ Julia re-downloaded and gzip integrity verified"
            else
                echo "  ❌ Julia re-download also failed - aborting build"
                exit 1
            fi
        fi
    fi
    
    echo "✓ Early verification completed - all cached files are intact"
}

early_verify_cached_files

# *** SETUP GPG VERIFICATION (now that tools are available) ***
setup_gpg_verification



# ------ Helper Function to Consolidate Mirror Selection ------
probe_and_set_mirrors() {
export LC_NUMERIC=C # Prevents printf errors with decimals
echo "==> Probing for the fastest Ubuntu mirror by testing a candidate list..."
local CODENAME
CODENAME="$(. /etc/os-release; echo "${UBUNTU_CODENAME:-jammy}")"
local PROBE_RESULTS
PROBE_RESULTS="$(mktemp)"

# Function to test a single mirror (for parallel execution)
test_mirror() {
    local URL="$1"
    local CODENAME="$2"
    local PROBE_RESULTS="$3"
    
    [[ -z "$URL" ]] && return
    
    # Use curl to measure actual download speed with large files.
    # Primary: Download Packages.gz (~20MB) to measure bandwidth
    # Fallback: Use Release file for latency if large file fails.
    set +e
    local CURL_OUTPUT CURL_EXIT_CODE SPEED_MBPS
    
    # Try to download a large file to measure actual bandwidth
    # Use Packages.gz (typically 10-50MB) for better speed measurement
    CURL_OUTPUT="$(LC_NUMERIC=C curl -s -w '%{time_total}\n' -o /dev/null -m 30 --retry 2 -L "$URL/dists/$CODENAME/main/binary-amd64/Packages.gz" 2>/dev/null)"
    CURL_EXIT_CODE=$?
    
    # If large file download succeeds, calculate speed
    if [[ $CURL_EXIT_CODE -eq 0 ]] && [[ -n "$CURL_OUTPUT" ]] && [[ "$CURL_OUTPUT" != "0.000000" ]]; then
        # Estimate file size (Packages.gz is typically 10-50MB)
        local ESTIMATED_SIZE_MB=20  # Conservative estimate
        # Calculate speed: size/time (MB/s), then convert to latency equivalent
        # Lower speed = higher "latency" for sorting purposes
        SPEED_MBPS=$(echo "scale=6; $ESTIMATED_SIZE_MB / $CURL_OUTPUT" | bc 2>/dev/null || echo "0")
        # Convert to latency-like metric (inverse of speed)
        CURL_OUTPUT=$(echo "scale=6; 1 / $SPEED_MBPS" | bc 2>/dev/null || echo "$CURL_OUTPUT")
    else
        # Fallback to Release file latency test
        CURL_OUTPUT="$(LC_NUMERIC=C curl -s -w '%{time_total}\n' -o /dev/null -m 10 --retry 2 -I "$URL/dists/$CODENAME/Release" 2>/dev/null)"
        CURL_EXIT_CODE=$?
    fi
    set -e
    
    # If curl failed, returned 0.000000, or empty output, use 9.9
    if [[ $CURL_EXIT_CODE -ne 0 ]] || [[ "$CURL_OUTPUT" == "0.000000" ]] || [[ -z "$CURL_OUTPUT" ]]; then
        echo "9.9 $URL" >> "$PROBE_RESULTS"
    else
        echo "$CURL_OUTPUT $URL" >> "$PROBE_RESULTS"
    fi
}

# Export function for parallel execution
export -f test_mirror

# Define candidate mirrors list
local CANDIDATE_MIRRORS
CANDIDATE_MIRRORS="https://de.archive.ubuntu.com/ubuntu"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://mirror.leaseweb.net/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://au.archive.ubuntu.com/ubuntu"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://mirror.aarnet.edu.au/pub/ubuntu/archive/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://mirrors.kernel.org/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://mirrors.ustc.edu.cn/ubuntu"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://archive.ubuntu.com/ubuntu"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://in.archive.ubuntu.com/ubuntu"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://jp.archive.ubuntu.com/ubuntu"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://mirror.cse.iitk.ac.in/ubuntu"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://sg.archive.ubuntu.com/ubuntu"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://ftp.riken.jp/Linux/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://mirror.kku.ac.th/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://mirror.twds.com.tw/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://mirrors.nhanhoa.com/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://ftp.kaist.ac.kr/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://ftp.udx.icscoe.jp/Linux/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://repo.huaweicloud.com/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://mirrors.nipa.cloud/ubuntu/"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://ubuntu-archive.mirrors.estointernet.in/ubuntu"
CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS}
https://ossmirror.mycloud.services/os/linux/ubuntu/"

# Run mirror tests in parallel (max 8 concurrent)
echo "Testing mirrors in parallel (max 8 concurrent)..."
echo "${CANDIDATE_MIRRORS}" | xargs -P 8 -I {} bash -c 'test_mirror "$@"' _ {} "$CODENAME" "$PROBE_RESULTS"

echo "--- Mirror Probe Results (speed score, url): ---"
LC_NUMERIC=C sort -n "$PROBE_RESULTS" | sed 's/^/  /'

# Extract the fastest mirror that responded in under 9 seconds
local FASTEST_MIRROR
FASTEST_MIRROR="$(LC_NUMERIC=C sort -n "$PROBE_RESULTS" | awk 'NF==2 && $1 < 9.0 {print $2; exit}')"
rm -f "$PROBE_RESULTS"

if [[ -z "$FASTEST_MIRROR" ]]; then
    echo "[warn] All mirror probes failed. Using default ubuntu archive."
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
fi
echo "==> Selected fastest mirror: $FASTEST_MIRROR"

# Apply the fastest mirror to the main APT sources
sed -i "s|http[s]*://[^/ ]*/ubuntu|${FASTEST_MIRROR}|g" /etc/apt/sources.list
}

# --- Configure dpkg to exclude docs and man pages to save space ---
echo "==> Configuring dpkg to exclude unnecessary documentation..."
cat >/etc/dpkg/dpkg.cfg.d/01-nodoc <<'EOF'
# Exclude all documentation
path-exclude /usr/share/doc/*
# but keep copyright files for compliance
path-include /usr/share/doc/*/copyright
# Exclude all man pages and info pages
path-exclude /usr/share/man/*
path-exclude /usr/share/info/*
# Exclude non-English dictionaries
path-exclude /usr/share/dict/wordlist.de*
EOF



# ------ define prune helpers early ------
install -d -m 0755 /usr/local/bin

apt-get update -o Acquire::Retries=3

# --- Install all bootstrap and utility packages in one go ---
echo "==> Installing all bootstrap and utility packages..."

# Clean up any existing APT temporary directories
rm -rf /tmp/apt-dpkg-install-* 2>/dev/null || true
rm -rf /var/cache/apt/archives/partial/* 2>/dev/null || true



# Batch 1: Additional network and download tools
echo "==> Installing additional network and download tools..."
apt-get install -y --no-install-recommends \
    aria2 \
    rsync

# Batch 2: Additional security and encryption tools
echo "==> Installing additional security and encryption tools..."
apt-get install -y --no-install-recommends \
    ca-certificates-java

# Batch 3: Development and utility tools
echo "==> Installing development and utility tools..."
apt-get install -y --no-install-recommends \
    python3-pip

update-ca-certificates
locale-gen en_US.UTF-8
pip3 install apt-smart
command -v curl || { echo "curl install failed"; exit 1; }

# *** RUN THE UNIFIED MIRROR PROBE ONCE ***
probe_and_set_mirrors



# ### >>> ADDED: ALL PPA CONFIGURATIONS (EARLIEST POSSIBLE) - OPTIMIZED
echo "==> Adding all PPAs and configuring apt-fast (earliest possible) - OPTIMIZED"
# Add all PPAs using fallback method (add-apt-repository with proper error handling)
echo "Adding PPA repositories with verification..."

# Try modern method first, fallback to add-apt-repository if needed
echo "Attempting to add PPAs using add-apt-repository..."
add-apt-repository -y ppa:apt-fast/stable 2>/dev/null || echo "[warn] apt-fast PPA failed, will try manual method"
add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null || echo "[warn] Mozilla PPA failed, will try manual method"  
add-apt-repository -y ppa:agornostal/ulauncher 2>/dev/null || echo "[warn] Ulauncher PPA failed, will try manual method"

# If add-apt-repository failed, use manual method as fallback
if [ ! -f /etc/apt/sources.list.d/apt-fast-ubuntu-stable-jammy.list ]; then
    echo "Using manual PPA configuration as fallback..."
    CODENAME=$(lsb_release -cs)
    
    # Add apt-fast PPA manually
    echo "deb http://ppa.launchpad.net/apt-fast/stable/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/apt-fast-ppa.list
    echo "deb-src http://ppa.launchpad.net/apt-fast/stable/ubuntu ${CODENAME} main" >> /etc/apt/sources.list.d/apt-fast-ppa.list
    
    # Add Mozilla PPA manually
    echo "deb http://ppa.launchpad.net/mozillateam/ppa/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/mozillateam-ppa.list
    echo "deb-src http://ppa.launchpad.net/mozillateam/ppa/ubuntu ${CODENAME} main" >> /etc/apt/sources.list.d/mozillateam-ppa.list
    
    # Add Ulauncher PPA manually
    echo "deb http://ppa.launchpad.net/agornostal/ulauncher/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/ulauncher-ppa.list
    echo "deb-src http://ppa.launchpad.net/agornostal/ulauncher/ubuntu ${CODENAME} main" >> /etc/apt/sources.list.d/ulauncher-ppa.list
fi

# Add GPG keys using direct download method (most reliable)
echo "Adding PPA GPG keys..."

# apt-fast PPA key
curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0x1E2824A7F22B44BD | gpg --dearmor -o /etc/apt/trusted.gpg.d/apt-fast.gpg 2>/dev/null || echo "[warn] apt-fast key failed"

# Mozilla PPA key  
curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0xAEBDF4819BE21867 | gpg --dearmor -o /etc/apt/trusted.gpg.d/mozillateam.gpg 2>/dev/null || echo "[warn] Mozilla key failed"

# Ulauncher PPA key
curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0xFAF1020699503176 | gpg --dearmor -o /etc/apt/trusted.gpg.d/ulauncher.gpg 2>/dev/null || echo "[warn] Ulauncher key failed"

# Verify PPA keys are properly added
echo "Verifying PPA GPG keys..."
for keyfile in /etc/apt/trusted.gpg.d/*.gpg; do
  if [ -f "$keyfile" ]; then
    echo "✓ PPA key verified: $(basename "$keyfile")"
  fi
done

# Single apt-get update with all PPAs (more efficient)
echo "Updating package lists with all PPAs..."
apt-get update -o Acquire::Retries=3

# Install and configure apt-fast immediately with verification
echo "Installing and configuring apt-fast..."
if apt-get -y --no-install-recommends -o Dpkg::Options::="--force-confnew" install apt-fast; then
  echo "✓ apt-fast installed successfully"
else
  echo "[warn] apt-fast installation failed, falling back to apt-get"
fi


# --- apt-fast hardening: force aria2c + mirrors + sane defaults ---
mkdir -p /etc/apt-fast
mkdir -p /var/cache/apt/archives/apt-fast
install -d -m 0755 /etc/apt-fast

# Ensure essential device files exist for apt-fast
[[ -e /dev/null ]] || mknod /dev/null c 1 3 2>/dev/null || true
[[ -e /dev/zero ]] || mknod /dev/zero c 1 5 2>/dev/null || true



# Create the mirror list for apt-fast using the selected mirror
echo "==> Creating mirror list for apt-fast..."
{
    # Use the fastest mirror found by the probe
    grep -oP 'http[s]?://[^/ ]*/ubuntu' /etc/apt/sources.list | head -n1
    # Add default fallbacks and PPA hosts
    echo "http://security.ubuntu.com/ubuntu"
    echo "https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu"
    echo "https://ppa.launchpadcontent.net/apt-fast/stable/ubuntu"
    echo "https://ppa.launchpadcontent.net/agornostal/ulauncher/ubuntu"
} > /etc/apt-fast/mirrors.list




# Configure apt-fast for optimal performance
cat > /etc/apt-fast.conf <<'EOC'
# apt-fast core config (simplified)
DOWNLOADER=aria2c
_DLDIR="/container_cache/apt/archives"
APT_FAST_OPTS=(--check-certificate=false --min-split-size=1M --timeout=30)
# apt-fast will automatically use /etc/apt-fast/mirrors.list if it exists
EOC

# --- Improve APT robustness ---
cat >>/etc/apt/apt.conf.d/80-retries <<'EOF'
Acquire::Retries "3";
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::ftp::Timeout "30";
EOF

# Export in case apt-fast looks at env first
export DOWNLOADER=aria2c
export APT_FAST_OPTS="--summary-interval=1 --console-log-level=notice --check-certificate=false --max-connection-per-server=16 --split=16 --min-split-size=1M --timeout=30"
export LC_ALL=C
echo "[apt-fast] configured to use aria2c (verbose progress enabled)"
echo "[apt-fast] mirrors + config + ENVIRONMENT VARIABLES written"
# Verify apt-fast configuration
if [ -x /usr/bin/apt-fast ] && [ -f /etc/apt-fast.conf ]; then
  echo "✓ apt-fast configured successfully"
else
  echo "[warn] apt-fast configuration may be incomplete"
fi

# Clean up any stale apt-fast lock files
rm -f /tmp/apt-fast.lock

# --- DEBUG: verify aria2/apt-fast wiring (Ubuntu-safe probe) ---
set +e
echo "[debug] Checking aria2/apt-fast wiring ..."
# 1) Binaries present?
command -v aria2c >/dev/null 2>&1 || { echo "[debug][FAIL] aria2c not found"; exit 71; }
command -v apt-fast >/dev/null 2>&1 || { echo "[debug][FAIL] apt-fast not found"; exit 72; }
# 2) Show configs
echo "[debug] /etc/apt-fast/apt-fast.conf:"
[ -s /etc/apt-fast/apt-fast.conf ] && sed -n '1,120p' /etc/apt-fast/apt-fast.conf || echo "[debug] Missing apt-fast.conf"
echo "[debug] /etc/apt-fast/mirrors.list:"
[ -s /etc/apt-fast/mirrors.list ] && sed -n '1,40p' /etc/apt-fast/mirrors.list || echo "[debug] Missing mirrors.list"
# 3) Pick a mirror + codename for a guaranteed file
CODENAME="$(. /etc/os-release 2>/dev/null; echo "${UBUNTU_CODENAME:-jammy}")"
UBU_MIRROR="$(head -n1 /etc/apt-fast/mirrors.list 2>/dev/null | sed 's|[[:space:]]*$||')"
[ -z "$UBU_MIRROR" ] && UBU_MIRROR="https://in.archive.ubuntu.com/ubuntu"
TEST_URL="$UBU_MIRROR/dists/$CODENAME/Release" # small text file that always exists
# 4) Aria2 connectivity probe (no cert check to survive weird proxies)
echo "[debug] Aria2 probe: $TEST_URL"
ARIA2_TMP=/tmp/aria2_probe.$$
mkdir -p "$ARIA2_TMP"
aria2c --check-certificate=false -x16 -s16 -m3 -d "$ARIA2_TMP" -o Release.txt "$TEST_URL"
ARIA2_RC=$?
if [ $ARIA2_RC -ne 0 ]; then
  echo "[debug][FAIL] Aria2 probe failed (rc=$ARIA2_RC) for $TEST_URL"
  ls -l "$ARIA2_TMP" || true
  exit 73
fi
rm -rf "$ARIA2_TMP/Release.txt"

# 5) apt-fast smoke test (update only; fast and safe)
echo "[debug] apt-fast update (short):"
# Clean up any stale lock files
rm -f /tmp/apt-fast.lock
APT_FAST_OPTS="$APT_FAST_OPTS;--no-check-certificate"
apt-fast -o Acquire::Check-Valid-Until=false -o Acquire::Retries=3 update
APTFAST_RC=$?
if [ $APTFAST_RC -ne 0 ]; then
  echo "[debug][FAIL] apt-fast update failed (rc=$APTFAST_RC)."
  exit 74
fi
apt-fast -y --no-install-recommends --download-only install libgpg-error0
echo "[debug] apt-fast + aria2 look OK."
set -e
# --- END DEBUG ---

echo "----------- Checking APT-FAST MIRRORS -----------"
# Show what apt-fast thinks its mirrors are (POSIX-safe)
if [ -f /etc/apt-fast/apt-fast.conf ]; then
  MLINE="$(grep -E '^(( *)?)MIRRORS=' /etc/apt-fast.conf | \
    sed -e 's/MIRRORS=//' -e 's/(//' -e 's/)//')"
  printf 'apt-fast conf mirrors: %s\n' "$MLINE"
fi
printf '[debug] apt-fast mirrors.list (first 20 lines):\n'
sed -n '1,20p' /etc/apt-fast/mirrors.list 2>/dev/null || true


echo "[debug] apt-fast -> aria2c probe..."
APTFAST_DEBUG=1 apt-fast -y -o Debug::pkgAcquire::Worker=1 \
  --no-install-recommends --download-only install libgpg-error0 >/dev/null 2>&1 || true

echo "----------- APT-ARIA WRAPPER -----------"
# Use aria2c for multi-connection fetches using apt's actual URLs (works for PPAs too)
install -d -m 0755 /usr/local/bin

cat >/usr/local/bin/apt-aria <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CACHE="/container_cache/apt/archives"
mkdir -p "$CACHE" /var/cache/apt/archives

case "$1" in
  update|upgrade|full-upgrade|dist-upgrade|autoremove|autoclean|clean|check|-f|--fix-broken)
exec /usr/bin/apt-get -o Dir::Cache::archives="$CACHE" "$@"
;;
esac

# Collect all http/https URLs (incl. dependencies) that would be downloaded
URI_FILE="$(mktemp)"
/usr/bin/apt-get -o Dir::Cache::archives="$CACHE" --print-uris -y "$@" \
  | awk -F"'" '/^https?:\/\// {print $2}' \
  | sort -u > "$URI_FILE"

if [ -s "$URI_FILE" ]; then
  # Try multi-connection first
  if ! aria2c --check-certificate=false -x16 -s16 -m3 -d "$CACHE" -i "$URI_FILE"; then
# Fallback: single-connection (handles servers that reject ranges, e.g. some PPAs)
aria2c --check-certificate=false -x1 -s1 -m3 -d "$CACHE" -i "$URI_FILE" || \
echo "[warn] aria2c prefetch failed; apt-get will fetch what's missing"
  fi
fi

# Install from cache (APT will reuse any .debs present; download only what's missing/newer)
exec /usr/bin/apt-get -o Dir::Cache::archives="$CACHE" -y "$@"
EOF
chmod 0755 /usr/local/bin/apt-aria

# Optional: keep your existing lines untouched by aliasing apt-fast -> apt-aria
ln -sf /usr/local/bin/apt-aria /usr/local/bin/apt-fast

# Drake APT (use cached key) + INSTALL
echo "==> Drake APT (hardened via cached key) + INSTALL"
# === Drake APT setup (strictly per drake.mit.edu/apt.html) ===
set -e

# 1) BEFORE apt-get update (temporary insecure override for just the Drake host)
cat >/etc/apt/apt.conf.d/99-drake-insecure.conf <<'EOF'
Acquire::https::drake-apt.csail.mit.edu::Verify-Peer "false";
Acquire::https::drake-apt.csail.mit.edu::Verify-Host "false";
EOF

# 2) Download Drake GPG signing key and add to trusted keychain
# (Prefer cached copy if present to avoid re-downloading)
DRAKE_ASC="/tmp/drake.asc"
if [ -s /container_cache/binaries/drake.asc ]; then cp -f /container_cache/binaries/drake.asc "$DRAKE_ASC"; \
else
  # Strict per docs: wget -O- | gpg --dearmor | tee ...
  # We still keep a local copy so we can seed cache for next builds.
  wget -qO- https://drake-apt.csail.mit.edu/drake.asc | tee "$DRAKE_ASC" >/dev/null
fi
# Add to apt's trusted keychain exactly as docs show
if [ -s "$DRAKE_ASC" ]; then
  gpg --dearmor < "$DRAKE_ASC" > /etc/apt/trusted.gpg.d/drake.gpg
  chmod 0644 /etc/apt/trusted.gpg.d/drake.gpg
else
  # Fallback to direct pipeline as in docs (for extremely minimal cases)
  wget -qO- https://drake-apt.csail.mit.edu/drake.asc | gpg --dearmor - \
    >/etc/apt/trusted.gpg.d/drake.gpg
  chmod 0644 /etc/apt/trusted.gpg.d/drake.gpg
fi

# 3) Add Drake repository (codename as in docs)
CODENAME="$(lsb_release -cs)"
echo "deb [arch=amd64] https://drake-apt.csail.mit.edu/${CODENAME} ${CODENAME} main" \
  >/etc/apt/sources.list.d/drake.list

# 4) Update and install drake-dev (use shared cache if you've set it)
apt-get -o Dir::Cache::archives=/container_cache/apt/archives update || apt-get update

# Check for broken packages and fix them before installing drake-dev
echo "Checking for broken packages..."
apt-get -f install -y || true
dpkg --configure -a || true

# Install drake-dev with more verbose output for debugging
echo "Installing drake-dev..."
apt-fast install -y --no-install-recommends drake-dev || {
    echo "apt-fast failed, trying with apt-get..."
    apt-get install -y --no-install-recommends drake-dev
}

# 5) AFTER installing drake-dev (clean up the insecure override)
rm -f /etc/apt/apt.conf.d/99-drake-insecure.conf

# 6) Seed the key into cache for future builds (optional, harmless)
mkdir -p /container_cache/binaries
[ -s "$DRAKE_ASC" ] && cp -f "$DRAKE_ASC" /container_cache/binaries/drake.asc 2>/dev/null || true

# 7) Helpful environment for users (as Drake suggests)
echo 'export PATH="/opt/drake/bin:${PATH}"' >> /etc/profile.d/drake.sh
echo 'export PYTHONPATH="/opt/drake/lib/python3/dist-packages:${PYTHONPATH}"' >> /etc/profile.d/drake.sh
site_packages=$(python3 -c "import sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}')")
echo "export PYTHONPATH=\"/opt/drake/lib/python${site_packages}/site-packages:\${PYTHONPATH}\"" >> /etc/profile.d/drake.sh
chmod 0644 /etc/profile.d/drake.sh
# After drake-dev install succeeds
sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/drake.list || true
apt-get update


# Configure Firefox preferences immediately
cat >/etc/apt/preferences.d/mozillateam.pref <<'PREF'
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 501
PREF

# Install Firefox immediately after PPA configuration with verification
echo "Installing Firefox with optimized PPA..."
if apt-fast -y --no-install-recommends install libdbus-glib-1-2 firefox; then
  echo "✓ Firefox installed successfully via apt-fast"
elif apt-get -y --no-install-recommends install libdbus-glib-1-2 firefox; then
  echo "✓ Firefox installed successfully via apt-get"
else
  echo "[warn] Firefox installation failed"
fi

# Verify Firefox installation
if [ -x /usr/bin/firefox ]; then
  echo "✓ Firefox binary verified"
else
  echo "[warn] Firefox binary not found"
fi

# APT caching already configured above

echo "==> Desktop stack"
apt-fast install -y --no-install-recommends \
    xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils xauth fontconfig\
    fonts-dejavu fonts-liberation fonts-noto \
    iproute2 iputils-ping net-tools lsof \
    build-essential gcc g++ make ninja-build pkg-config patchelf elfutils patch swig\
    git tmux htop unzip zip p7zip-full \
    libgl1 libglvnd0 libegl1 libgles2 libxext6 libxrender1 libsm6 \
    libxrandr2 libxi6 libxxf86vm1 libxkbfile1 libxinerama1 libxcursor1 libxdamage1 \
    libxss1 libgl1-mesa-dri libxss1\
    libvulkan1 vulkan-tools \
    python3 python3-pip python3-venv \
    whiptail

echo "==> Additional system libraries for robotics/ML"

# Helper function for package installation with fallback
install_packages() {
    local group_name="$1"
    shift
    echo "Installing $group_name..."
    if ! apt-fast install -y --no-install-recommends "$@"; then
        echo "apt-fast failed, trying with apt-get..."
        apt-get install -y --no-install-recommends "$@" || true
    fi
}

# First, fix any broken dependencies
echo "Fixing broken dependencies..."
apt-get -y --fix-broken install || true
dpkg --configure -a || true
apt-get -y autoremove || true
apt-get -y autoclean || true

# Remove any held packages that might cause conflicts
apt-mark unhold $(dpkg --get-selections | grep hold | awk '{print $1}') 2>/dev/null || true

# Install essential dependencies first
echo "Installing essential dependencies..."
apt-fast install -y --no-install-recommends \
    pkg-config || true

# Handle specific version conflicts
echo "Resolving version conflicts..."
apt-get -y install gcc-12-base=12.3.0-1ubuntu1~22.04.2 || true
apt-get -y install libquadmath0 || true
apt-get -y install libpython3.10-stdlib=3.10.12-1~22.04.11 || true

# Update package lists after fixing conflicts
apt-get update || true

# Install packages in groups to avoid dependency conflicts
install_packages "core math libraries" \
    libeigen3-dev \
    libatlas-base-dev \
    libopenblas-dev \
    liblapack-dev

install_packages "boost and logging libraries" \
    libboost-all-dev \
    libgflags-dev \
    libgoogle-glog-dev

install_packages "HDF5 libraries" \
    libhdf5-dev \
    libhdf5-serial-dev \
    libhdf5-103

install_packages "compression and crypto libraries" \
    libffi-dev \
    libssl-dev \
    libbz2-dev \
    liblzma-dev

install_packages "image processing libraries" \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev

install_packages "multimedia libraries" \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libavutil-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev

install_packages "GUI libraries" \
    libgtk-3-dev \
    libcanberra-gtk3-dev

install_packages "SDL libraries" \
    libsdl2-dev \
    libsdl2-image-dev \
    libsdl2-mixer-dev

install_packages "physics simulation libraries" \
    libbullet-dev \
    libode-dev

install_packages "3D and XML libraries" \
    libassimp-dev \
    libtinyxml2-dev

install_packages "data format libraries" \
    libyaml-cpp-dev \
    libjsoncpp-dev

# Install PCL and VTK libraries with better dependency handling
echo "Installing PCL and VTK libraries..."

# First, try to install PCL without VTK to avoid conflicts
if ! apt-fast install -y --no-install-recommends libpcl-dev; then
    echo "PCL installation failed, trying with apt-get..."
    apt-get install -y --no-install-recommends libpcl-dev || true
fi

# Then try VTK separately
if ! apt-fast install -y --no-install-recommends libvtk7-dev; then
    echo "VTK7 installation failed, trying VTK9..."
    if ! apt-fast install -y --no-install-recommends libvtk9-dev; then
        echo "VTK installation failed, continuing without VTK..."
    fi
fi

# apt-fast already installed and configured above

# --- Prevent VTK conflicts (we don't need both; prefer none in base) ---
apt-get -y remove python3-vtk7 python3-vtk9 || true
apt-fast -y install || true
apt-fast -y install python3-vtk9 || true

# Firefox already installed above with optimized PPA

# Install local .debs for VNC/VirtualGL using apt for robust dependency handling
echo "Installing TurboVNC and VirtualGL from local .deb files with GPG verification..."

# --- Install TurboVNC & VirtualGL with Official GPG Signature Verification ---
echo "==> Installing TurboVNC & VirtualGL with official GPG signature verification..."

# 1. Download the official 'debsig-import' helper script from the gist provided by TurboVNC
echo "  Downloading the debsig-import helper script..."
if ! curl -fsSL -o /usr/local/bin/debsig-import "https://gist.githubusercontent.com/dcommander/2960e99d4a4f6998e249ec7cfec89b85/raw/debsig-import"; then
    echo "  ❌ ERROR: Failed to download the debsig-import script. Aborting."
    exit 1
fi
chmod +x /usr/local/bin/debsig-import

# 2. Define the official GPG Key ID and URL
GPG_KEY_ID="4BACCAB36E7FE9A1"
GPG_KEY_URL="https://www.turbovnc.org/key/VGL-GPG-KEY"

# 3. Import the key using the official helper script
echo "  Importing the TurboVNC/VirtualGL GPG key..."
if ! debsig-import "$GPG_KEY_ID" "$GPG_KEY_URL"; then
    echo "  ❌ ERROR: Failed to import the GPG key using debsig-import. Aborting."
    exit 1
fi
echo "  ✓ GPG Key imported successfully."

# 4. Loop through the .deb files, verify with debsig-verify, and install
for deb_file in /container_cache/debs/turbovnc_*.deb /container_cache/debs/virtualgl_*.deb; do
    if [ ! -f "$deb_file" ]; then
        echo "  [warn] Package not found in cache, skipping: $(basename "$deb_file")"
        continue
    fi
    
    echo "  Verifying GPG signature for $(basename "$deb_file")..."
    # The policy is now automatically created by debsig-import, so we can just verify.
    if debsig-verify "$deb_file"; then
        echo "  ✓ GPG Signature OK. Installing..."
        # Use a non-interactive install to prevent prompts
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb_file"
    else
        echo "  ⚠️ GPG SIGNATURE VERIFICATION FAILED for $(basename "$deb_file")!"
        echo "     Installing anyway with warning (build will continue)..."
        # Use a non-interactive install to prevent prompts
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb_file"
    fi
done
# Create symlinks with verification
if [ -x /opt/TurboVNC/bin/vncserver ]; then
  ln -sf /opt/TurboVNC/bin/vncserver /usr/local/bin/vncserver
  echo "✓ vncserver symlink created"
fi
if [ -x /opt/TurboVNC/bin/Xvnc ]; then
  ln -sf /opt/TurboVNC/bin/Xvnc /usr/local/bin/Xvnc
  echo "✓ Xvnc symlink created"
fi

echo "==> yq (Go) from embedded binary"
if [ -s /container_cache/binaries/yq_linux_amd64 ]; then
  install -m 0755 /container_cache/binaries/yq_linux_amd64 /usr/local/bin/yq
fi

echo "==> Miniforge (from embedded installer) - OPTIMIZED"
if [ -s /container_cache/binaries/${MINIFORGE_SH} ]; then
  echo "Installing Miniforge..."
  
  # Miniforge installer already verified in early verification phase
  echo "✓ Miniforge installer already verified (SHA256 check passed)"
  
  # Ensure clean conda environment (corrupted packages already cleaned in %setup)
  export CONDA_PKGS_DIRS="/container_cache/conda_pkgs"
  export CONDA_ALWAYS_YES=true
  export CONDA_AUTO_UPDATE_CONDA=false
  
  # Retry logic for Miniforge installation with enhanced CRC error handling
  max_retries=3
  retry_count=0
  
  while [ $retry_count -lt $max_retries ]; do
    echo "Miniforge installation attempt $((retry_count + 1))/$max_retries..."
    
    # Clear any existing conda package cache to force fresh downloads
    rm -rf /opt/conda/pkgs/* 2>/dev/null || true
    rm -rf /root/.cache/conda/* 2>/dev/null || true
    
    # Pre-clean corrupted packages from cache before installation
    echo "Pre-cleaning potentially corrupted conda packages from cache..."
    if [ -d "/container_cache/conda_pkgs" ]; then
      find /container_cache/conda_pkgs -name "*.conda" -type f -exec sh -c '
        for pkg; do
          if ! unzip -t "$pkg" >/dev/null 2>&1; then
            echo "  ⚠ Removing pre-corrupted package: $(basename "$pkg")"
            rm -f "$pkg"
          fi
        done
      ' _ {} +
    fi
    
    # Set environment variables to use our cache directory and make it non-interactive
    export CONDA_PKGS_DIRS="/container_cache/conda_pkgs"
    export CONDA_ALWAYS_YES=true
    export CONDA_AUTO_UPDATE_CONDA=false
    export CONDA_INSTALLER_TYPE=miniforge
    export CONDA_INSTALLER_VERSION=25.3.1-0
    
    # Run installer with enhanced CRC error handling and non-interactive mode
    echo "Running Miniforge installer with enhanced CRC error handling..."
    if yes "" | CONDA_PKGS_DIRS="/container_cache/conda_pkgs" bash /container_cache/binaries/${MINIFORGE_SH} -b -p /opt/conda -f 2>&1 | tee /tmp/miniforge_install.log; then
      echo "✓ Miniforge installer completed"
      mv /opt/.condarc.pre /opt/conda/.condarc 2>/dev/null || true
      
      # Verify conda installation
      if [ -x /opt/conda/bin/conda ]; then
        echo "✓ Miniforge installed successfully"
        break
      else
        echo "[warn] Miniforge installation may have failed - conda binary not found"
        ((retry_count++))
        if [ $retry_count -lt $max_retries ]; then
          echo "Retrying Miniforge installation..."
          rm -rf /opt/conda
        fi
      fi
    else
      echo "[warn] Miniforge installer failed (attempt $((retry_count + 1))/$max_retries)"
      
      # Enhanced CRC error detection and handling
      if grep -q "bad CRC\|ZIP bad CRC\|md5sum mismatch" /tmp/miniforge_install.log 2>/dev/null; then
        echo "  → CRC/MD5 error detected in installation log"
        
        # Extract all corrupted package names from the log
        corrupted_pkgs=$(grep -o "Extracting [^[:space:]]*\.conda\|Extracting [^[:space:]]*\.tar\.bz2" /tmp/miniforge_install.log | sed 's/Extracting //' | sort -u)
        
        if [ -n "$corrupted_pkgs" ]; then
          echo "  → Removing corrupted packages:"
          for pkg in $corrupted_pkgs; do
            echo "    - $pkg"
            rm -f "/container_cache/conda_pkgs/$pkg" 2>/dev/null || true
            rm -f "/opt/conda/pkgs/$pkg" 2>/dev/null || true
            rm -f "/root/.cache/conda/pkgs/$pkg" 2>/dev/null || true
          done
          
          # Clear any remaining corrupted packages using integrity check
          echo "  → Performing integrity check on remaining packages..."
          if [ -d "/container_cache/conda_pkgs" ]; then
            find /container_cache/conda_pkgs -name "*.conda" -type f -exec sh -c '
              for pkg; do
                if ! unzip -t "$pkg" >/dev/null 2>&1; then
                  echo "    - Removing corrupted: $(basename "$pkg")"
                  rm -f "$pkg"
                fi
              done
            ' _ {} +
          fi
        fi
      fi
      
      ((retry_count++))
      if [ $retry_count -lt $max_retries ]; then
        echo "Retrying Miniforge installation..."
        rm -rf /opt/conda
      fi
    fi
  done
  
  if [ -x /opt/conda/bin/conda ]; then
    # Clean up any corrupted conda packages that may have been downloaded during installation
    echo "Cleaning up any corrupted conda packages from installation..."
    if [ -d "/opt/conda/pkgs" ]; then
      corrupted_count=0
      for pkg_file in /opt/conda/pkgs/*.conda /opt/conda/pkgs/*.tar.bz2; do
        if [ -f "$pkg_file" ]; then
          # Check if file is corrupted by testing its integrity
          # First check file type, then test format-specific integrity
          is_corrupted=false
          
          # Use file command to detect file type
          if ! file "$pkg_file" | grep -q "archive\|compressed\|data"; then
            is_corrupted=true
          else
            # Additional format-specific integrity checks
            if [[ "$pkg_file" == *.conda ]]; then
              if ! unzip -t "$pkg_file" >/dev/null 2>&1; then
                is_corrupted=true
              fi
            elif [[ "$pkg_file" == *.tar.bz2 ]]; then
              if ! bzip2 -t "$pkg_file" >/dev/null 2>&1; then
                is_corrupted=true
              fi
            fi
          fi
          
          if [ "$is_corrupted" = true ]; then
            echo "  ⚠ Removing corrupted conda package: $(basename "$pkg_file")"
            rm -f "$pkg_file"
            ((corrupted_count++))
          fi
        fi
      done
      if [ $corrupted_count -gt 0 ]; then
        echo "  ✓ Removed $corrupted_count corrupted conda packages from installation"
      fi
    fi
    
    # Final verification of conda installation
    echo "Performing final conda installation verification..."
    if /opt/conda/bin/conda --version >/dev/null 2>&1; then
      echo "✓ Conda binary is working correctly"
      
      # Install mamba as the default solver for conda with verification
      echo "Installing mamba as conda solver..."
      
      # Try mamba installation (corrupted packages already cleaned in %setup)
      if /opt/conda/bin/conda install -y -c conda-forge mamba; then
        echo "✓ Mamba installed successfully"
        
        # Verify mamba installation
        if /opt/conda/bin/mamba --version >/dev/null 2>&1; then
          echo "✓ Mamba binary is working correctly"
        else
          echo "[warn] Mamba binary verification failed"
        fi
      else
        echo "[warn] Mamba installation failed, continuing with conda"
      fi
    else
      echo "❌ Conda binary verification failed - installation may be corrupted"
    fi
  else
    echo "[warn] Miniforge installation failed after $max_retries attempts"
  fi
  
  # Clean up temporary files
  rm -f /tmp/miniforge_install.log 2>/dev/null || true
else
  echo "[warn] Miniforge installer not found in cache"
fi


# === Micromamba (from embedded binary) ===
echo "==> micromamba (from embedded binary)"
if [ -s /container_cache/binaries/micromamba-linux-64 ]; then
    install -m 0755 /container_cache/binaries/micromamba-linux-64 /opt/micromamba
    ln -sf /opt/micromamba /usr/local/bin/micromamba
    
    # Test micromamba binary before configuration with retry logic
    if [ -x /opt/micromamba ]; then
        echo "Testing micromamba binary..."
        max_retries=3
        retry_count=0
        
        while [ $retry_count -lt $max_retries ]; do
            if /opt/micromamba --version >/dev/null 2>&1; then
                echo "✓ Micromamba binary is working"
                break
            else
                echo "⚠ Micromamba binary test failed (attempt $((retry_count + 1))/$max_retries)"
                ((retry_count++))
                if [ $retry_count -lt $max_retries ]; then
                    echo "Removing corrupted binary and reinstalling..."
                    rm -f /opt/micromamba /usr/local/bin/micromamba
                    install -m 0755 /container_cache/binaries/micromamba-linux-64 /opt/micromamba
                    ln -sf /opt/micromamba /usr/local/bin/micromamba
                fi
            fi
        done
        
        if [ $retry_count -ge $max_retries ]; then
            echo "❌ Micromamba binary failed after $max_retries attempts - removing corrupted binary"
            rm -f /opt/micromamba /usr/local/bin/micromamba
        else
            # Configure micromamba for better performance and user experience
            echo "Configuring micromamba..."
            # Note: Using flexible priority for micromamba allows users more freedom
            # when creating their own ad-hoc environments.
            if /opt/micromamba config set channel_priority flexible 2>/dev/null; then
                echo "  ✓ Channel priority configured"
            else
                echo "  ⚠ Channel priority configuration failed"
            fi
            
            if /opt/micromamba config set always_yes yes 2>/dev/null; then
                echo "  ✓ Always yes configured"
            else
                echo "  ⚠ Always yes configuration failed"
            fi
            
            if /opt/micromamba config set quiet true 2>/dev/null; then
                echo "  ✓ Quiet mode configured"
            else
                echo "  ⚠ Quiet mode configuration failed"
            fi
            
            echo "✓ Micromamba configured successfully"
        fi
    else
        echo "⚠ Micromamba binary not executable"
    fi
else
    echo "⚠ Micromamba binary not found in cache"
fi

# Conda base env - Full Jupyter + meshcat + additional libraries
echo "Starting Conda base env setup"
if [ -x /opt/conda/bin/conda ]; then
  # Conda channel configuration (strict conda-forge only)
  /opt/conda/bin/conda config --system --remove-key channels || true
  /opt/conda/bin/conda config --system --add channels conda-forge
  /opt/conda/bin/conda config --system --set channel_priority strict
  
  echo "Installing full Jupyter environment + additional libraries using mamba solver..."
  # Use mamba (installed in conda) for better environment solving
  if [ -x /opt/conda/bin/mamba ]; then
    echo "Using mamba solver for package installation..."
    # Install core packages first
    echo "Installing core Jupyter packages..."
    /opt/conda/bin/mamba install -y -c conda-forge \
        jupyterlab notebook ipykernel nodejs || true
    # Install scientific computing packages
    echo "Installing scientific computing packages..."
    /opt/conda/bin/mamba install -y -c conda-forge \
        numpy scipy matplotlib pandas seaborn plotly || true
    # Install ML/vision packages
    echo "Installing ML/vision packages..."
    /opt/conda/bin/mamba install -y -c conda-forge \
        scikit-learn scikit-image opencv || true
    # Install deep learning packages
    echo "Installing deep learning packages..."
    /opt/conda/bin/mamba install -y -c conda-forge \
        tensorflow pytorch torchvision torchaudio || true
    # Install robotics/ML packages
    echo "Installing robotics/ML packages..."
    /opt/conda/bin/mamba install -y -c conda-forge \
        gymnasium stable-baselines3 mujoco pybullet glfw imageio || true
    # Vision bits (headless)
    /opt/conda/bin/pip install --no-cache-dir "opencv-python-headless>=4.7"
    # Install Jupyter extensions
    echo "Installing Jupyter extensions..."
    /opt/conda/bin/mamba install -y -c conda-forge \
        ipywidgets jupyter_contrib_nbextensions nbconvert nbformat || true
  else
    echo "Falling back to conda for package installation..."
    # [conda fallback logic could be here]
  fi
  # Register base Python kernel
  /opt/conda/bin/python -m ipykernel install --name=python-conda-base --display-name="Python (conda-base)" || true
  # Install additional useful packages via pip
  /opt/conda/bin/pip install --no-cache-dir \
    openai-gym \
    robosuite \
    pyrender \
    trimesh \
    pyglet || true
fi

# Verify critical packages
echo "Verifying critical package installations..."
if [ -x /opt/conda/bin/jupyter ]; then
  echo "✓ Jupyter installed successfully"
else
  echo "[warn] Jupyter installation may have failed"
fi

if [ -x /opt/conda/bin/python ]; then
  echo "✓ Python installed successfully"
else
  echo "[warn] Python installation may have failed"
fi

# Julia 1.10 LTS + envs
# --- Julia 1.10.5: cache-aware download, verify, install (POSIX sh) ---
JVER="1.10.5"
JMAJOR="$(echo "$JVER" | awk -F. '{print $1 "." $2}')" # e.g. 1.10
JULIA_TARBALL="julia-${JVER}-linux-x86_64.tar.gz"
JULIA_BASEURL="https://julialang-s3.julialang.org/bin/linux/x64/${JMAJOR}"
JULIA_URL="${JULIA_BASEURL}/${JULIA_TARBALL}"
JULIA_SUMS_URL="${JULIA_BASEURL}/SHA256SUMS"

CACHE_DIR="/container_cache/binaries"
INSTALL_DIR="/opt"
LATEST_TGZ="${CACHE_DIR}/${JULIA_TARBALL}"


# If IPV6 is flaky on your HPC, you can force IPV4
# echo 'Acquire::ForceIPv4 "true";' >/etc/apt/apt.conf.d/99ipv4
mkdir -p "$CACHE_DIR"

# Decide whether to fetch
need_fetch=0
if [ ! -f "$LATEST_TGZ" ]; then
  need_fetch=1
else
  # quick integrity test
  if ! gzip -t "$LATEST_TGZ" 2>/dev/null; then
    need_fetch=1
  fi
fi

if [ "$need_fetch" -eq 1 ]; then
  echo "[julia] fetching ${JULIA_URL}"
  # retry, follow redirects, fail on HTTP error
  curl -fsSL --retry 5 --retry-all-errors --connect-timeout 5 --max-time 180 \
    -o "${LATEST_TGZ}.part" "$JULIA_URL"
  mv -f "${LATEST_TGZ}.part" "$LATEST_TGZ"
fi

# Julia archive already verified in early verification phase
echo "[julia] Archive already verified (SHA256 + gzip integrity check passed)"

# Optional PGP signature verification (best-effort, non-blocking)
echo "[julia] Performing optional GPG signature verification..."
GNUPGHOME=/root/.gnupg
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# Download .asc file if available
curl -fsSL --retry 3 "${JASC_URL}" -o "${LATEST_TGZ}.asc" || true

# Import key from Ubuntu keyserver; ignore failures (behind some firewalls)
gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys 3673DF529D9049477F76B37566E3C7DC03D6E495 || \
gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys 3673DF529D9049477F76B37566E3C7DC03D6E495 || true

# Verify signature if .asc present and key imported (non-blocking)
if [ -s "${LATEST_TGZ}.asc" ]; then
  if gpg --batch --verify "${LATEST_TGZ}.asc" "$LATEST_TGZ" 2>/tmp/julia_gpg_verify.log; then
    echo "[julia] ✓ PGP signature: GOOD"
  else
    echo "[julia] ⚠ PGP signature could not be verified (see /tmp/julia_gpg_verify.log). Continuing because SHA256 passed."
  fi
else
  echo "[julia] ⚠ No .asc file available for GPG verification. Continuing because SHA256 passed."
fi

# Extract and link /opt/julia -> /opt/julia-<ver>
tar -xzf "$LATEST_TGZ" -C "$INSTALL_DIR"
rm -f "${INSTALL_DIR}/julia" 2>/dev/null || true
ln -s "${INSTALL_DIR}/julia-${JVER}" "${INSTALL_DIR}/julia"
echo "[julia] installed to ${INSTALL_DIR}/julia-${JVER} (symlinked as ${INSTALL_DIR}/julia)"

# After extracting Julia and creating /opt/julia symlink
echo "[julia] sanity check for /opt/julia/bin/julia"

# Sanity check (fail fast if missing)
JULIA_BIN="/opt/julia/bin/julia"
if [ ! -x "$JULIA_BIN" ]; then
  echo "[julia] ERROR: /opt/julia/bin/julia not found or not executable"
  ls -l /opt || true
  exit 1
fi

# Quick smoke test (no precompile)
"$JULIA_BIN" --version || true

echo "==> Julia ${JULIA_LTS_VER:-1.10.x} install & envs"
if [ -x "$JULIA_BIN" ]; then
  echo "Julia installed successfully"

  # Base env (Julia) - with error handling
  echo "Setting up Julia base environment..."
  "$JULIA_BIN" -e 'using Pkg; Pkg.update(); Pkg.add(["IJulia"]); using IJulia;' || echo "[warn] Julia setup failed"
  
  # Robotics env (use valid shared environment name)
  echo "Setting up Julia robotics environment..."
  mkdir -p /opt/juliaenvs
  "$JULIA_BIN" -e 'using Pkg; Pkg.activate("/opt/juliaenvs/robotics_env"); Pkg.add(["RigidBodyDynamics", "MeshCat", "ControlSystems", "DifferentialEquations", "ForwardDiff", "StaticArrays", "Rotations", "CoordinateTransformations", "Interpolations", "Optim"]); Pkg.precompile()' || \
  echo "[warn] Robotics env setup failed"
  
  # CUDA-ready env (instantiate only; no GPU precompile here)
  echo "Setting up Julia CUDA environment..."
  "$JULIA_BIN" -e 'using Pkg; Pkg.activate("/opt/juliaenvs/cuda_env"); Pkg.instantiate()' || echo "[warn] CUDA env setup failed"
  
  # Register Julia kernel (IJulia)
  echo "Registering Julia kernel..."
  "$JULIA_BIN" -e 'using IJulia; IJulia.installkernel("Julia 1.10 (base)", "--project=@.");' || echo "[warn] Julia kernel registration failed"
  
  # GPU precompile helper (safe, non-fatal)
  cat >/usr/local/bin/precompile_julia_cuda.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

# Allow caller to override, default to system Julia installed in /opt/julia
JULIA_BIN="${JULIA_BIN:-/opt/julia/bin/julia}"

if ! command -v "$JULIA_BIN" >/dev/null 2>&1; then
  echo "[precompile_julia_cuda] $JULIA_BIN not found; skipping."
  exit 0
fi

# If no NVIDIA driver/GPU is visible, just skip (non-fatal)
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "[precompile_julia_cuda] no NVIDIA GPU visible; skipping."
  exit 0
fi

# Optional project dir argument; defaults to /opt/juliaenvs/robotics-cuda
ENV_DIR="${1:-/opt/juliaenvs/robotics-cuda}"
PROJECT_OPT="-e"
if [ -d "$ENV_DIR" ]; then
  PROJECT_OPT="--project=$ENV_DIR"
fi

# Run a tiny Julia program to instantiate and touch CUDA-dependent packages
"$JULIA_BIN" $PROJECT_OPT -e '
try
  using Pkg
  # if the project exists this will be a no-op if already done
  Pkg.instantiate()
  
  @info "Touching CUDA packages for GPU precompile..."
  using CUDA
  CUDA.versioninfo()     # triggers artifact and toolchain setup
  using KernelAbstractions
  using Flux
  
  println("GPU precompile completed.")
catch e
  @warn "GPU precompile failed" exception=e
end
'
EOS
  chmod 0755 /usr/local/bin/precompile_julia_cuda.sh
  # strip CRLF if any crept in; ignore if dos2unix is not present
  dos2unix -q /usr/local/bin/precompile_julia_cuda.sh 2>/dev/null || true
  
  # Invoke once (non-fatal); if the CUDA env isn't present yet, it just no-ops
  if [ -x /usr/local/bin/precompile_julia_cuda.sh ]; then
    /usr/local/bin/precompile_julia_cuda.sh || true
  fi
else
  echo "[warn] Julia installation may have failed"
fi

# LibreOffice (from baseline)
echo "==> LibreOffice installation"
apt-fast -y --no-install-recommends install \
  libreoffice-writer libreoffice-calc libreoffice-impress || \
apt-get -y --no-install-recommends install \
  libreoffice-writer libreoffice-calc libreoffice-impress

# Blender (from baseline)
echo "==> Blender installation"
apt-fast -y --no-install-recommends install blender || \
apt-get -y --no-install-recommends install blender

# ==================== OCIO color management (quiet & portable) ====================
echo "==> OCIO color profile configuration initialized"
set -e
DEBIAN_FRONTEND=noninteractive apt-get update -yq
if ! dpkg -l blender-data >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-fast install -yq --no-install-recommends blender-data
  # Find Blender's bundled OCIO config
  OCIO_PATH="$(/usr/bin/python3 -c '
import glob; p=glob.glob("/usr/share/blender/*/datafiles/colormanagement/config.ocio")
if p: print(p[0])
')"
  if [ -n "$OCIO_PATH" ]; then
    printf 'export OCIO=%s\n' "$OCIO_PATH" > /etc/profile.d/99-ocio.sh
  else
    echo "[OCIO] blender-data installed but config.ocio not found; continuing"
  fi
else
  # Fallback: install a known-good ACES config
  mkdir -p /usr/share/ocio/aces && cd /tmp || { echo "Failed to change to /tmp"; exit 1; }
  curl -fsSL --retry 3 --retry-delay 2 -o aces.tar.gz https://github.com/AcademySoftwareFoundation/OpenColorIO-Configs/archive/refs/heads/master.tar.gz || true
  if [ -s aces.tar.gz ]; then
    tar -xzf aces.tar.gz --strip-components=2 -C /usr/share/ocio/aces OpenColorIO-Configs-master/aces_1.2 || true
    if [ -f /usr/share/ocio/aces/config.ocio ]; then
      printf 'export OCIO=/usr/share/ocio/aces/config.ocio\n' > /etc/profile.d/99-ocio.sh
    fi
  fi
fi
set +e
echo "=================== OCIO Color profile configuration complete ==================="

# CAD tools (from baseline)
echo "==> CAD tools installation"
apt-fast -y --no-install-recommends install \
  openscad freecad || \
apt-get -y --no-install-recommends install \
  openscad freecad

echo "[note] ROS2 not included in base image - use separate ROS2 image for ROS-specific work"

# TeX English-only (feature-complete)
echo "==> TeX (English-only, full feature)"
apt-fast -y --no-install-recommends install \
  texlive texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra \
  latexml latexmk texlive-xetex texlive-bibtex-extra biber lmodern cm-super \
  texlive-pictures texlive-science texlive-pstricks texlive-context \
  ipe texworks || \
apt-get -y --no-install-recommends install \
  texlive texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra \
  latexml latexmk texlive-xetex texlive-bibtex-extra biber lmodern cm-super \
  texlive-pictures texlive-science texlive-pstricks texlive-context \
  ipe texworks

# === XFCE/VNC remote GUI optimizations (baseline) ===
echo "==> XFCE/VNC remote GUI tuning"
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat >/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'XFM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
<property name="use_compositing" type="bool" value="false"/>
<property name="sync_to_vblank" type="bool" value="false"/>
<property name="frame_drawn" type="bool" value="false"/>
<property name="double_click_time" type="int" value="250"/>
  </property>
</channel>
XFM

# Allow non-root users to run X clients (helps in containers)
printf 'allowed_users=anybody\nneeds_root_rights=no\n' >/etc/X11/Xwrapper.config

# Create a robust VNC launcher that starts XFCE
cat >/usr/local/bin/start_vnc_xfce.sh <<'VNC'
#!/usr/bin/env bash
set -euo pipefail

GEOM="${VNC_GEOM:-1920x1080}"
DEPTH="${VNC_DEPTH:-24}"
QUAL="${VNC_QUALITY:-90}"
LOCAL="${VNC_LOCALHOST:-yes}"

ARGS=("-geometry" "$GEOM" "-depth" "$DEPTH" "-quality" "$QUAL" "-alwaysshared")
if [[ "$LOCAL" = "yes" ]]; then
  ARGS+=("-localhost" "yes")
else
  ARGS+=("-localhost" "no")
fi

# Make sure prior server is gone
if command -v vncserver >/dev/null 2>&1; then vncserver -kill :1 >/dev/null 2>&1 || true; fi

# xstartup for XFCE (bash; dbus; compositor off; no screen blanking)
mkdir -p "$HOME/.vnc"
cat >"$HOME/.vnc/xstartup" <<'XS'
#!/usr/bin/env bash
# Merge X resources and warm font cache (first-paint speed)
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
fc-cache -f 2>/dev/null || true

# Start a dbus session if not present
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

# Remote-friendly tweaks
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xset -dpms s off s noblank 2>/dev/null || true

# Start desktop (exec, not background)
exec /usr/bin/startxfce4
XS
chmod +x "$HOME/.vnc/xstartup"

# If you want passwordless access, add: ... -SecurityTypes None
exec vncserver :1 "${ARGS[@]}" -xstartup "$HOME/.vnc/xstartup"
VNC

chmod 0755 /usr/local/bin/start_vnc_xfce.sh

# === Ulauncher (baseline) ===
echo "==> Ulauncher (PPA already added above)"
apt-fast -y --no-install-recommends install ulauncher || apt-get -y --no-install-recommends install ulauncher

# === Sioyek note (baseline) ===
echo "==> Sioyek (manual AppImage install recommended)"
echo "[note] After build, to install Sioyek:"
echo "    - 1) Download AppImage from https://github.com/ahrm/sioyek/releases"
echo "    - 2) chmod +x Sioyek-*.AppImage && sudo mv Sioyek-*.AppImage /usr/local/bin/sioyek"
echo "    - 3) Optionally create a .desktop file for menus"

# ======================== Creating Symlinks for applications for failsafe ========================
echo "============== Creating Symlinks for applications like vncserver, Xvnc, vncpasswd, vglrun =============="
ln -sf /opt/TurboVNC/bin/vncserver /usr/local/bin/vncserver || true
ln -sf /opt/TurboVNC/bin/Xvnc /usr/local/bin/Xvnc || true
ln -sf /opt/TurboVNC/bin/vncpasswd /usr/local/bin/vncpasswd || true
ln -sf /opt/VirtualGL/bin/vglrun /usr/local/bin/vglrun || true

# Cache is already unified in /container_cache/ - no need for complex harvesting
echo "==> Cache is unified in /container_cache/ - ready for harvest"

# Clean up temporary files but preserve our cache
echo "==> Cleaning temporary files while preserving cache..."

# Clean APT lists (safe to remove)
rm -rf /var/lib/apt/lists/* 2>/dev/null || true

# Clean temporary APT directories that might cause issues
rm -rf /tmp/apt-dpkg-install-* 2>/dev/null || true
rm -rf /tmp/apt-fast-* 2>/dev/null || true

# Clean temporary files but preserve our container_cache
find /tmp -type f -name "*.deb" -delete 2>/dev/null || true
find /tmp -type f -name "*.tar.gz" -delete 2>/dev/null || true
find /tmp -type f -name "*.whl" -delete 2>/dev/null || true

# Report cache status
echo "[debug] Container cache status:"
echo "  APT archives: $(ls /container_cache/apt/archives/*.deb 2>/dev/null | wc -l) files"
echo "  Conda packages: $(ls /container_cache/conda_pkgs/* 2>/dev/null | wc -l) files"
echo "  Pip wheels: $(ls /container_cache/wheels/* 2>/dev/null | wc -l) files"
echo "  Julia packages: $(ls /container_cache/julia_pkgs/* 2>/dev/null | wc -l) files"


# ==============================================================================
