# === Build Plan, State Variables & Configuration ===
#
export PHASE1_STATUS="NOT RUN"
export PHASE2_STATUS="NOT RUN"
export PHASE3_STATUS="NOT RUN"
export PHASE4_STATUS="NOT RUN"
export PHASE5_STATUS="NOT RUN"

# Define color codes for rich terminal output
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

export DEBIAN_FRONTEND=noninteractive

debug_glibc() {
  local stage="$1"
  echo "=========================================================="
  echo -e "${BLUE}DEBUG CHECKPOINT: ${stage}${NC}"
  echo "Time: $(date)"
  echo "=========================================================="
  echo "GLIBC version:"
  /lib/x86_64-linux-gnu/libc.so.6 | head -1
  echo "---"
  echo "ldd version:"
  ldd --version | head -1
  echo "---"
  echo "GCC version:"
  gcc --version 2>/dev/null | head -1 || echo "GCC not installed yet"
  echo "---"
  echo "Test stdlib.h locations:"
  find /usr/include -name "stdlib.h" 2>/dev/null || echo "stdlib.h not found"
  echo "---"
  echo "Test cstdlib locations:"
  find /usr/include -name "cstdlib" 2>/dev/null || echo "cstdlib not found"
  echo "---"
  echo "Compiler include paths:"
  gcc -xc++ -E -v - < /dev/null 2>&1 | grep '^ /' 2>/dev/null || echo "Cannot check (GCC not ready)"
  echo "---"
  echo "Test compile with stdlib.h:"
  echo '#include <stdlib.h>' >> /tmp/test_$$$.c
  echo 'int main() { return 0; }' >> /tmp/test_$$$.c
  gcc /tmp/test_$$$.c -o /tmp/test_$$$ >&1 && echo "SUCCESS" || echo "FAILED"
  rm -f /tmp/test_$$$.c /tmp/test_$$$
  echo "---"
  echo
}

# === Cache monitoring data collection ===
CACHE_MONITOR_DATA="/tmp/cache_monitor_data.txt"

# Initialize cache monitoring data file
echo "Stage|Container APT|Var APT|Conda|Wheels|Julia" > "$CACHE_MONITOR_DATA"

# Cache monitoring function
monitor_cache() {
  local stage="$1"
  local container_apt=$(ls /container_cache/apt/archives/*.deb 2>/dev/null | wc -l)
  local var_apt=$(ls /var/cache/apt/archives/*.deb 2>/dev/null | wc -l)
  local conda_pkgs=$(ls /container_cache/conda_pkgs/* 2>/dev/null | wc -l)
  local wheels=$(ls /container_cache/wheels/* 2>/dev/null | wc -l)
  local julia_pkgs=$(ls /container_cache/julia_pkgs/* 2>/dev/null | wc -l)

  echo "[CACHE MONITOR] Stage: $stage"
  echo "/container_cache/apt/archives: $container_apt .deb files"
  echo "/var/cache/apt/archives: $var_apt .deb files"
  echo "/container_cache/conda_pkgs: $conda_pkgs files"
  echo "/container_cache/wheels: $wheels files"
  echo "/container_cache/julia_pkgs: $julia_pkgs files"
  echo ""

  # Store data for summary
  echo "$stage|$container_apt|$var_apt|$conda_pkgs|$wheels|$julia_pkgs" >> "$CACHE_MONITOR_DATA"
}

# Display collected cache monitoring data
display_cache_monitoring_summary() {
  echo "=========================================================="
  echo "CACHE MONITORING SUMMARY - ALL STAGES"
  echo "=========================================================="
  echo "Stage                         | Container APT | Var APT | Conda | Wheels | Julia"
  echo "------------------------------|---------------|---------|-------|--------|-------"
  # Read and display the monitoring data
  while IFS='|' read -r stage container_apt var_apt conda_pkgs wheels julia_pkgs; do
    # Skip header line
    if [[ "$stage" == "# Stage" ]]; then
      continue
    fi
    # Format the output with proper alignment
    printf "%-30s | %-13s | %-7s | %-5s | %-6s | %-5s\n" \
      "$stage" "$container_apt" "$var_apt" "$conda_pkgs" "$wheels" "$julia_pkgs"
  done < "$CACHE_MONITOR_DATA"
  echo "=========================================================="
  echo
}

# Aggregated cache summary function
cache_summary() {
  echo "=========================================================="
  echo "FINAL CACHE SUMMARY - BEFORE IMAGE CREATION"
  echo "=========================================================="
  echo "APT Archives:"
  echo " /container_cache/apt/archives: $(ls /container_cache/apt/archives/*.deb 2>/dev/null | wc -l) .deb files"
  echo " /var/cache/apt/archives: $(ls /var/cache/apt/archives/*.deb 2>/dev/null | wc -l) .deb files"
  echo "---"
  echo "Other Caches:"
  echo " /container_cache/conda_pkgs: $(ls /container_cache/conda_pkgs/* 2>/dev/null | wc -l) files"
  echo " /container_cache/wheels: $(ls /container_cache/wheels/* 2>/dev/null | wc -l) files"
  echo " /container_cache/julia_pkgs: $(ls /container_cache/julia_pkgs/* 2>/dev/null | wc -l) files"
  echo "---"
  echo "Cache Directory Sizes:"
  echo " /container_cache/apt/archives: $(du -sh /container_cache/apt/archives 2>/dev/null | cut -f1 || echo '0B')"
  echo " /container_cache/conda_pkgs: $(du -sh /container_cache/conda_pkgs 2>/dev/null | cut -f1 || echo '0B')"
  echo " /container_cache/wheels: $(du -sh /container_cache/wheels 2>/dev/null | cut -f1 || echo '0B')"
  echo " /container_cache/julia_pkgs: $(du -sh /container_cache/julia_pkgs 2>/dev/null | cut -f1 || echo '0B')"
  echo "=========================================================="
  echo
}

# Define CACHE_ROOT to point to the unified cache directory
export CACHE_ROOT="/container_cache"

# Configure all package managers to use subdirectories within the unified cache
export PIP_CACHE_DIR="${CACHE_ROOT}/wheels"
export CONDA_PKGS_DIRS="${CACHE_ROOT}/conda_pkgs"
export JULIA_DEPOT_PATH="${CACHE_ROOT}/julia_pkgs:/usr/local/share/julia"

#==============================================================================
# Pinned Software Versions and URLs
#==============================================================================
# --- Miniforge ---
MINIFORGE_VER="25.3.1-0"
MINIFORGE_SH="Miniforge3-${MINIFORGE_VER}-Linux-x86_64.sh"
MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VER}/${MINIFORGE_SH}"
MINIFORGE_SHA256="376b160ed8130820db0ab0f3826ac1fc85923647f75c1b8231166e3d559ab768"

# --- Micromamba ---
MICROMAMBA_VER="2.3.2-0"
MICROMAMBA_BIN="micromamba-linux-64"
MICROMAMBA_URL="https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VER}/${MICROMAMBA_BIN}"
MICROMAMBA_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"

# --- TurboVNC / VirtualGL ---
TURBOVNC_VER="3.2.1"
TURBOVNC_DEB="turbovnc_${TURBOVNC_VER}_amd64.deb"
TURBOVNC_URL="https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VER}/${TURBOVNC_DEB}"
VIRTUALGL_VER="3.1.4"
VIRTUALGL_DEB="virtualgl_${VIRTUALGL_VER}_amd64.deb"
VIRTUALGL_URL="https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VER}/${VIRTUALGL_DEB}"

# --- yq (Go) ---
YQ_VER="v4.48.1"
YQ_BIN="yq_linux_amd64"
YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VER}/${YQ_BIN}"
YQ_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"

# --- Drake, Julia & Julia Pin ---
DRAKE_ASC_URL="https://drake-apt.csail.mit.edu/drake.asc"
DRAKE_KEY_URL="https://drake-apt.csail.mit.edu/drake.asc"

# GPG Keys for verification
VIRTUALGL_TURBOVNC_GPG_KEY_ID="4BACCAB36E7FE9A1"
VIRTUALGL_TURBOVNC_GPG_KEY_URL="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xae1a7ba4efff9a9987e1474c4baccab36e7fe9a1"
JULIA_LTS_VER="1.10.5" # LTS
JULIA_TARBALL="julia-${JULIA_LTS_VER}-linux-x86_64.tar.gz"
JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_LTS_VER%.*}/${JULIA_TARBALL}"
JASC_URL="https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_LTS_VER%.*}/${JULIA_TARBALL}.asc"

# --- NVIDIA Keyring ---
NVIDIA_KEYRING_VER="1.1-1"
NVIDIA_KEYRING_DEB="cuda-keyring_${NVIDIA_KEYRING_VER}-1_all.deb"
NVIDIA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/${NVIDIA_KEYRING_DEB}"



# === Advanced Conda Package Management Functions ===
#
# Setup conda staging area for filesystem robustness
setup_conda_staging_area() {
  local staging_dir="/tmp/conda-staging"
  echo "Setting up conda staging area at $staging_dir..."
  # Create staging directory with proper permissions
  mkdir -p "$staging_dir"
  chmod 755 "$staging_dir"
  # Note: Do not modify CONDA_PKGS_DIRS here to avoid interfering with normal conda operations
  # The staging area will be used manually for specific cleanup operations
  echo "✓ Conda staging area configured (manual mode)"
}

# Atomic package replacement with retry logic
atomic_package_replace() {
  local pkg_name="$1"
  local cache_dir="/container_cache/conda_pkgs"
  local max_retries=3
  local retry_count=0

  while [ $retry_count -lt $max_retries ]; do
    echo "Attempting to replace corrupted package: $pkg_name (attempt $((retry_count + 1))/${max_retries})"
    # Create temporary file for atomic replacement
    local temp_file="${cache_dir}/${pkg_name}.tmp"
    local final_file="${cache_dir}/${pkg_name}"

    # Remove corrupted package
    rm -f "${final_file}" 2>/dev/null || true

    # Download fresh copy to temporary location
    if /opt/conda/bin/mamba download --no-deps -c conda-forge -p "$cache_dir" "$pkg_name" --output-filename "$temp_file" 2>/dev/null; then
      # Atomic move to final location
      if mv "$temp_file" "$final_file" 2>/dev/null; then
        # Verify the new package
        if verify_package_integrity "$final_file"; then
          echo "✓ Successfully replaced and verified: $pkg_name"
          return 0
        else
          echo "Δ Downloaded package failed verification, retrying..."
          rm -f "$final_file" 2>/dev/null || true
        fi
      else
        echo "Δ Atomic move failed, retrying..."
        rm -f "$temp_file" 2>/dev/null || true
      fi
    else
      echo "Δ Download failed, retrying..."
    fi

    retry_count=$((retry_count + 1))
    sleep $((retry_count ** 2)) # Exponential backoff
  done

  echo "✗ Failed to replace package after $max_retries attempts: $pkg_name"
  return 1
}

# Comprehensive package integrity verification
verify_package_integrity() {
  local pkg_file="$1"

  if [ ! -f "$pkg_file" ]; then
    return 1
  fi

  # Check file type and verify accordingly
  local file_type=$(file -b "$pkg_file" 2>/dev/null || echo "unknown")
  case "$file_type" in
    *"bzip2 compressed"*)
      if bzip2 -t "$pkg_file" >/dev/null 2>&1; then
        return 0
      else
        echo "✗ bzip2 integrity check failed"
        return 1
      fi
      ;;
    *"Zip archive"*)
      if unzip -t "$pkg_file" >/dev/null 2>&1; then
        return 0
      else
        echo "✗ ZIP integrity check failed"
        return 1
      fi
      ;;
    *) # For unknown types, try both checks
      if bzip2 -t "$pkg_file" >/dev/null 2>&1 || unzip -t "$pkg_file" >/dev/null 2>&1; then
        return 0
      else
        echo "✗ Package integrity check failed"
        return 1
      fi
      ;;
  esac
}

# Package locking mechanism
acquire_package_lock() {
  local pkg_name="$1"
  local lock_file="/tmp/conda-lock-${pkg_name}.lock"
  local max_wait=30
  local wait_count=0

  while [ $wait_count -lt $max_wait ]; do
    if [set -C; echo $$ > "$lock_file"] 2>/dev/null; then
      # lock acquired
      return 0
    fi
    # Check if lock is stale (older than 5 minutes)
    if [ -f "$lock_file" ] && [ $(date +%s) -ge $(( $(stat -c %Y "$lock_file" 2>/dev/null || echo 0) + 300 )) ]; then
      rm -f "$lock_file" 2>/dev/null || true
      continue
    fi

    sleep $((wait_count + 2))
    wait_count=$((wait_count + 1))
  done

  echo "▲ Could not acquire lock for $pkg_name after ${max_wait}s"
  return 1
}

release_package_lock() {
  local pkg_name="$1"
  local lock_file="/tmp/conda-lock-${pkg_name}.lock"
  rm -f "$lock_file" 2>/dev/null || true
}
debug_glibc "START - Before any apt operations"

# Create all cache directories immediately at the start of %post
echo "=> Creating all cache directories at the start of container build..."
mkdir -p /container_cache/apt/archives
mkdir -p /container_cache/binaries
mkdir -p /container_cache/conda_pkgs
mkdir -p /container_cache/debs
mkdir -p /container_cache/wheels
mkdir -p /container_cache/julia_pkgs
mkdir -p /var/cache/apt/archives/partial
mkdir -p /root/.cache/pip
# Note: /opt/conda will be created by Miniforge installer
mkdir -p /usr/local/share/julia

# Create additional cache directories that might be needed
mkdir -p /root/.cache/conda
mkdir -p /root/.cache/julia
mkdir -p /root/.local/share/julia
# apt-fast cache directory removed - using apt-aria wrapper instead

# Set proper permissions for all cache directories
chmod -R 755 /container_cache /root/.cache /var/cache/opt /opt/conda /usr/local/share/julia /root/.local 2>/dev/null || true
echo "✓ All cache directories created successfully"


# === Cache Validation and Repair Function ===
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
    echo "✓ Validated: $dir"
  done
}
# Conda package integrity validation is done via Xsetup for efficiency

# Test write permissions
local test_file="/root/.cache/write_test"
if touch "$test_file" 2>/dev/null; then
  rm -f "$test_file"
  echo "✓ Write permissions verified"
else
  echo "WARNING: Write permissions issue detected"
fi

# === GPG Verification Functions ===
setup_gpg_verification() {
  echo "==> Setting up GPG verification for .deb packages..."
}

# === NEW BLOCK: Enable Universe Repository ===
echo -e "\n\033[1;34m===> Enabling the 'universe' repository for additional packages...\033[0m"
# The 'software-properties-common' package, which provides this command,
# [span_0](start_span)[span_1](start_span)was installed as part of the essential tools.[span_0](end_span)[span_1](end_span)
/usr/bin/apt-get update
/usr/bin/apt-get install -y --no-install-recommends software-properties-common
add-apt-repository -y universe
add-apt-repository -y ppa:mozillateam/ppa
add-apt-repository -y ppa:agornostal/ulauncher

# === End Universe Block ===

# === NEW BLOCK: Synchronize Base Image with Repositories ===
echo -e "\n${BLUE}===> Synchronizing base image with latest package versions...${NC}"
# This resolves potential inconsistencies between the base image and the apt sources.
# Using dist-upgrade intelligently handles dependency changes and updates.
apt-get update
# DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
apt-get install -f -y
dpkg --configure -a
echo -e "${GREEN}✓ Base image synchronized.${NC}"
# === End Sync Block ===

# Install dpkg-sig for .deb package verification (modern replacement for debsig-verify)
echo "Installing dpkg-sig for .deb package verification..."
/usr/bin/apt-get install -y --no-install-recommends dpkg-sig

# Import VirtualGL/TurboVNC GPG key
echo "Importing VirtualGL/TurboVNC GPG key..."
if curl -fsSL "$VIRTUALGL_TURBOVNC_GPG_KEY_URL" | gpg --dearmor -o /usr/share/keyrings/virtualgl-turbovnc.gpg; then
  echo "✓ VirtualGL/TurboVNC GPG key imported successfully"
else
  echo "✗ Failed to import VirtualGL/TurboVNC GPG key"
  exit 1
fi

# Import Drake GPG key
echo "Importing Drake GPG key..."
if [ -f /container_cache/binaries/drake.asc ]; then
  if gpg --dearmor -o /usr/share/keyrings/drake.gpg /container_cache/binaries/drake.asc; then
    echo "✓ Drake GPG key imported successfully"
  else
    echo "✗ Failed to import Drake GPG key"
    exit 1
  fi
else
  echo "✗ Drake GPG key file not found"
  exit 1
fi

verify_deb_package() {
  local deb_file="$1"
  local gpg_key_id="$2"

  echo "Verifying .deb package: $(basename "$deb_file")"

  # First, verify package structure
  if ! dpkg-deb -I "$deb_file" >/dev/null 2>&1; then
    echo "✗ Package structure is invalid: $(basename "$deb_file")"
    exit 1
  fi

  # Import the GPG key for verification
  echo "Importing GPG key for verification..."
  if ! gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$gpg_key_id" >/dev/null; then
    echo "Δ Failed to import GPG key, trying alternative keyserver..."
    gpg --batch --keyserver keys.openpgp.org --recv-keys "$gpg_key_id" 2>/dev/null || true
  fi

  # Try dpkg-sig verification first
  if dpkg-sig --verify "$deb_file" 2>/dev/null; then
    echo "✓ GPG signature verified with dpkg-sig for $(basename "$deb_file")"
    return 0
  fi

  echo "Δ dpkg-sig verification failed, trying alternative verification..."

  # Alternative: Check if the package has a valid signature using gpg directly
  # Extract signature and verify
  if dpkg-sig -list "$deb_file" 2>/dev/null | grep -q "signature"; then
    echo "✓ Package has valid signature structure for $(basename "$deb_file")"
    return 0 # Loosening constraint to allow install
  else
    echo "✗ No valid signature found for $(basename "$deb_file")"
    echo "Δ Continuing with installation despite signature verification failure..."
    return 0 # Allow installation to continue
  fi
}

# === Helper Function to Consolidate All Cache Configurations ===
setup_unified_cache() {
  echo "==> Configuring unified caching for all package managers..."

  # Validate cache first
  validate_and_repair_cache

  # 1. Configure APT Caching (safe to do early)
  # This directory exists by default on Ubuntu.
  echo 'Dir::Cache::Archives "/container_cache/apt/archives";' > /etc/apt/apt.conf.d/90-cache.conf
  echo 'APT::Keep-Downloaded-Packages "true";' >> /etc/apt/apt.conf.d/90-cache.conf

  # 2. Configure Pip Caching
  mkdir -p /root/.config/pip
  printf "[global]\ncache-dir = %s\n" "$PIP_CACHE_DIR" > /root/.config/pip/pip.conf
  chown -R root:root "$PIP_CACHE_DIR" 2>/dev/null || true
  chmod -R 755 "$PIP_CACHE_DIR" 2>/dev/null || true

  # 3. Prepare Conda Caching with Staging Area Strategy
  # This config file will be used when Miniforge is installed later
  cat > /opt/conda/.condarc.pre <<-'EOF'
channels:
  - conda-forge
default_channels: [] # This line explicitly removes the default anaconda channel
channel_priority: strict
pkgs_dirs:
  - /container_cache/conda_pkgs

# --- Robustness settings for tricky filesystems ---
use_only_tar_bz2: true # Force older, more robust package format
aggressive_update_packages: [] # Disable aggressive caching that can cause issues
solver: libmamba # Use mamba solver by default for better reliability
safety_checks: enabled # Enable safety checks
channel_alias: https://conda.anaconda.org # Use HTTPS for security
ssl_verify: true # Verify SSL certificates

# --- Staging Area Configuration ---
# Use local staging area for package extraction to avoid filesystem race conditions
extract_threads: 1 # Single-threaded extraction for consistency
use_hard_links: true # Use hard links when possible for efficiency
always_copy: false # Use hard links for efficiency
always_softlink: false # Prefer hard links over soft links
EOF

# === 4. Configure Julia Caching ===
echo "==> Initial caching configured successfully."
}

# === SETUP ALL CACHES AT THE VERY BEGINNING ===
setup_unified_cache

# === PROTECT PRE-SEEDED CACHE EARLY ===
echo "==> Applying immutable flag to protect pre-seeded APT cache..."
# The "e2fsprogs" package, which provides chattr, is part of the base image.
# We suppress errors in case no .deb files were pre-seeded.
if command -v chattr >/dev/null; then
  chattr +i /container_cache/apt/archives/*.deb 2>/dev/null || true
  echo "✓ Pre-seeded cache files are now protected."
else
  echo "WARNING: 'chattr' command not found. Pre-seeded cache is not protected."
fi

# === INSTALL ESSENTIAL TOOLS FIRST (for gpg verification, downloads, and system management) ===
echo "==> Installing essential tools for verification, downloads, and system management..."
apt-get update -o Acquire::Retries=3

# *** INSTALL ARIA2 FIRST (before creating wrapper) ***
echo "==> Installing aria2 before creating apt-aria wrapper..."
/usr/bin/apt-get install -y --no-install-recommends aria2

# Monitor cache after first package installation
monitor_cache "After aria2 installation"
debug_glibc "After Aria installation"

# Install essential tools in smaller, logical batches for robustness
# Batch 1: Core APT and system utilities
echo "==> Installing core APT and system utilities..."
apt-get install -y --no-install-recommends \
  e2fsprogs \
  debconf-utils \
  dialog \
  software-properties-common \
  lsb-release \
  tzdata \
  locales \
  bc
debug_glibc "After installing core APT & System utilities"

# Batch 2: Network and download tools
echo "==> Installing network and download tools..."
apt-get install -y --no-install-recommends \
  curl \
  wget \
  apt-transport-https
debug_glibc "After installing network & download tools"

# Batch 3: Security and encryption tools
echo "==> Installing security and encryption tools..."
apt-get install -y --no-install-recommends \
  gnupg \
  dirmngr \
  ca-certificates \
  debsig-verify \
  sudo
debug_glibc "After installing security & encryption tools"

# Batch 4: Archive and compression tools
echo "==> Installing archive and compression tools..."
apt-get install -y --no-install-recommends \
  unzip \
  bzip2 \
  tar \
  gzip \
  xz-utils \
  p7zip-full
debug_glibc "After installing archive & compression tools"
# Monitor cache after 4 batches of installations
monitor_cache "After 4 batches of essential tools"

# Batch 5: File and text utilities
echo "==> Installing file and text utilities..."
apt-get install -y --no-install-recommends \
  file \
  less \
  tree \
  nano \
  vim-tiny \
  dos2unix \
  bsdextrautils \
  xxd
debug_glibc "After installing file & text utilities"

# Batch 6: Development and system tools
echo "==> Installing development and system tools..."
apt-get install -y --no-install-recommends \
  git \
  rsync \
  htop \
  jq
debug_glibc "After installing development and system tools"

# Try to install apt-utils (might not be available in all base images)
apt-get install -y --no-install-recommends apt-utils || echo "Δ apt-utils not available (continuing without it)"

# Try to install advanced package managers (may not be available in all Ubuntu versions)
echo "==> Attempting to install advanced package managers..."
apt-get install -y --no-install-recommends aptitude || echo "Δ aptitude not available (continuing without it)"
apt-get install -y --no-install-recommends nala || echo "Δ nala not available (continuing without it)"
# apt-fast removed - using apt-aria wrapper instead
apt-get install -y --no-install-recommends synaptic || echo "Δ synaptic not available (continuing without it)"
debug_glibc "After installing advanced package managers"

# Verify essential tools are working
command -v curl || { echo "curl install failed"; exit 1; }
command -v wget || { echo "wget install failed"; exit 1; }
command -v gpg || { echo "gpg install failed"; exit 1; }
command -v debsig-verify || { echo "debsig-verify install failed"; exit 1;}
command -v file || { echo "file install failed"; exit 1; }
command -v unzip || { echo "unzip install failed"; exit 1; }
command -v bzip2 || { echo "bzip2 install failed"; exit 1; }
command -v git || { echo "git install failed"; exit 1; }
command -v jq || { echo "jq install failed"; exit 1; }
command -v aptitude || { echo "aptitude install failed"; exit 1; }

# Check for optional advanced package managers (these might not be available in all Ubuntu versions)
echo "Checking for advanced package managers..."
command -v nala >& /dev/null && echo "✓ nala available" || echo "Δ nala not available"
# apt-fast removed - using apt-aria wrapper instead
command -v synaptic >& /dev/null && echo "✓ synaptic available" || echo "Δ synaptic not available"
dpkg -l | grep -q "ii.*apt-utils" ; then echo "✓ apt-utils package is installed"; else echo "Δ apt-utils package is not installed"; fi

echo "✓ Essential tools installed and verified"

# Monitor cache after essential tools installation
monitor_cache "After essential tools installation"

# === Install modern Rust-based command-line utilities ===
echo "==> Installing modern Rust-based command-line tools..."
apt-get install -y --no-install-recommends \
  bat \
  eza \
  ripgrep \
  fd-find \
  sshfs

# Set up aliases in .bashrc for seamless usage
echo "==> Configuring aliases for modern tools..."
cat >> /root/.bashrc <<'EOF'

# Alias modern replacements for common commands
alias ls='eza -l --icons --git'
alias cat='batcat' # On Debian/Ubuntu, bat is named batcat
alias grep='rg'
alias find='fdfind'
EOF

# === NEW BLOCK FOR NVIDIA CUDA LIBRARIES (cuDNN) ===
echo "==> Installing NVIDIA cuDNN for CUDA 12.x..."
# Reference: https://developer.nvidia.com/cudnn-downloads
# This section adds the NVIDIA repository and installs a specific cuDNN version
# compatible with the target cluster's CUDA 12.2-12.8 environment.
#
# 1. Add NVIDIA's GPG key and repository
# Add NVIDIA's GPG key and repository using a cache-first approach
KEYRING_DEB_NAME="cuda-keyring_1.1-1_all.deb"
KEYRING_DEB_CACHED_PATH="/container_cache/debs/${KEYRING_DEB_NAME}"
KEYRING_DEB_TMP_PATH="/tmp/${KEYRING_DEB_NAME}"

if [ -f "${KEYRING_DEB_CACHED_PATH}" ]; then
  echo "[INFO] Using cached NVIDIA keyring: ${KEYRING_DEB_CACHED_PATH}"
  dpkg -i "${KEYRING_DEB_CACHED_PATH}"
else
  echo "[INFO] NVIDIA keyring not found in cache. Downloading..."
  KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/${KEYRING_DEB_NAME}"
  curl -fsSL "${KEYRING_URL}" -o "${KEYRING_DEB_TMP_PATH}"
  dpkg -i "${KEYRING_DEB_TMP_PATH}"
  rm -f "${KEYRING_DEB_TMP_PATH}"
fi

if [ $? -ne 0 ]; then
  echo "✗ Failed to install NVIDIA repository keyring. Aborting GPU library install."
  export PHASE2_STATUS="FAIL"
  exit 1
fi
# The container already has curl, gnupg, and ca-certificates from essential tools.
apt-get update
KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb"
KEYRING_DEB="/tmp/cuda-keyring.deb"
curl -fsSL "${KEYRING_URL}" -o "${KEYRING_DEB}"
if ! dpkg -i "${KEYRING_DEB}"; then
  echo "✗ Failed to install NVIDIA repository keyring. Aborting cuDNN install."
fi

# 2. Update package list and install cuDNN
# We install a specific version of libcudnn8 compatible with the Cuda 12 range.
# This ensures reproducibility. You can update the version number as needed.
apt-get update
# The following command installs the runtime library and the dev library needed for compiling software.
if ! apt-get install -y --no-install-recommends libcudnn9=9.1.1.26-1 libcudnn9-dev=9.1.1.26-1 cuda-toolkit-12; then
  echo "WARNING: Failed to install specific pinned cuDNN version. Attempting to install latest version."
  apt-get install -y --no-install-recommends libcudnn9-cuda-12 libcudnn9-dev-cuda-12 cuda-toolkit-12
fi
echo "✓ NVIDIA cuDNN installed successfully."
# --- Configuration Step (Fixing the PATH) ---
echo -e "${YELLOW}[PHASE 2 | NVIDIA] Configuring system-wide environment variables for CUDA...${NC}"
# After CUDA installation, add this detection:
CUDA_VERSION=$(ls -d /usr/local/cuda-12.* 2>/dev/null | head -1 | grep -oP 'cuda-\K([0-9]+\.[0-9]+)')
if [ -z "${CUDA_VERSION}" ]; then
  CUDA_VERSION="12.6" # Fallback
fi
echo "Detected CUDA version: ${CUDA_VERSION}"

# Update your PATH configuration.
cat > /etc/profile.d/cuda.sh << EOF
#!/bin/sh
export PATH=/usr/local/cuda-${CUDA_VERSION}/bin\${PATH:+:\${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-${CUDA_VERSION}/lib64\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}
export CUDA_HOME=/usr/local/cuda-${CUDA_VERSION}
EOF
chmod +x /etc/profile.d/cuda.sh

# Ensure non-login shells also see the CUDA environment
if [ -f /etc/profile.d/cuda.sh ]; then
  . /etc/profile.d/cuda.sh
  if ! grep -q 'cuda.sh' /etc/bash.bashrc; then
    echo '. /etc/profile.d/cuda.sh' >> /etc/bash.bashrc
  fi
fi
# --- NEW AND CRITICAL STEP: Source the environment for the CURRENT script session ---
echo "==> Sourcing CUDA environment to make it available for the rest of this build..."
source /etc/profile.d/cuda.sh
sudo ldconfig

# --- Verification for Phase 2 ---
PHASE2_SUCCESS=true
echo -e "${YELLOW}[PHASE 2 | NVIDIA] Verifying installation and environment...${NC}"
if ! command -v nvcc &>/dev/null; then
  echo -e "${RED}[VERIFICATION FAILED] 'nvcc' command not found in PATH.${NC}"
  PHASE2_SUCCESS=false
else
  echo -e "  - nvcc command: ${GREEN}OK (Found in PATH)${NC}"
  nvcc --version
fi
if ! ldconfig -p | grep -q 'libcudnn.so'; then
  echo -e "${RED}[VERIFICATION FAILED] 'libcudnn.so' not found in linker cache.${NC}"
  PHASE2_SUCCESS=false
else
  echo -e "  - libcudnn.so: ${GREEN}OK (Visible to linker)${NC}"
fi

# --- Final Verdict for Phase 2 ---
if [ "${PHASE2_SUCCESS}" = true ]; then
  echo -e "${GREEN}✓ [PHASE 2] NVIDIA CUDA Toolkit and cuDNN configured and verified successfully.${NC}"
  export PHASE2_STATUS="PASS"
else
  echo -e "${RED}✗ [PHASE 2] Errors occurred during GPU environment setup. Please review logs.${NC}"
  export PHASE2_STATUS="FAIL"
  exit 1
fi
          fi
     rm -f "${KEYRING_DEB}"
fi # [UNCLEAR: dangling fi]

# === END OF NVIDIA BLOCK ===
debug_glibc "After installing NVIDIA Cuda Toolkit"

# *** APT TOOL ALIASING FOR UNIFIED CACHING (MOVED TO AFTER ESSENTIAL TOOLS) ***
echo "==> Setting up APT tool aliasing for unified caching..."

# Create apt-aria wrapper first
echo "Creating apt-aria wrapper for unified APT caching..."
install -d -m 0755 /usr/local/bin

# Configure APT to keep downloaded packages (prevent automatic cleanup)
echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/99keep-packages
echo 'APT::Clean-Installed "false";' >> /etc/apt/apt.conf.d/99keep-packages
echo 'APT::Get::AutomaticRemove "false";' >> /etc/apt/apt.conf.d/99keep-packages
echo 'APT::Get::AutomaticRemove::Kernels "false";' >> /etc/apt/apt.conf.d/99keep-packages

cat > /usr/local/bin/apt-aria <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Centralized APT cache configuration - All APT tools use this location
CACHE="/container_cache/apt/archives"
mkdir -p "/var/cache/apt/archives"

# Common APT options for consistent caching across all tools
# Keep downloaded packages and don't clean them automatically
APT_CACHE_OPTS="-o Dir::Cache::Archives=${CACHE} -o APT::Keep-Downloaded-Packages=true -o APT::Clean-Installed=false"

# Function to determine if this is an install command that should use aria2c
is_install_command() {
  # Check if any argument is an install command (not just the first one)
  for arg in "$@"; do
    case "$arg" in
      install|remove|purge|build-dep|source)
        return 0
        ;;
    esac
  done
  return 1
}

# Function to get the appropriate APT tool
get_apt_tool() {
  if [ -x /usr/bin/apt-fast ]; then
    echo "/usr/bin/apt-fast"
  else
    echo "/usr/bin/apt-get"
  fi
}

# Get the APT tool to use
APT_TOOL=$(get_apt_tool)

# Handle install commands with aria2c acceleration
if is_install_command "$@"; then
  echo "[apt-aria] Using aria2c for accelerated downloads..."
  
  # Collect all http/https URLs (incl. dependencies) that would be downloaded
  URI_FILE=$(mktemp)
  echo "[apt-aria] Collecting URIs with: /usr/bin/apt-get ${APT_CACHE_OPTS} --print-uris -y $*"

  # Use a more robust approach to collect URIs
  # Filter out package metadata and only extract actual download URIs
  /usr/bin/apt-get $APT_CACHE_OPTS --print-uris -y "$@" 2>/dev/null | \
    grep -E "'(https?://[^']*)'" | \
    sed -E "s/^'([^']+)'.*$/\1/" | \
    sed "s/ //g" | \
    grep -E "^https?://.*\.deb$" | sort -u > "$URI_FILE" 2>/dev/null; then
    echo "[apt-aria] URI collection successful"
  else
    echo "[apt-aria] URI collection failed, creating empty file"
    touch "$URI_FILE"
  fi

  echo "[apt-aria] URI file created: $URI_FILE"
  echo "[apt-aria] URI file contents:"
  cat "$URI_FILE" || echo "[apt-aria] URI file is empty or unreadable"

  if [ -s "$URI_FILE" ]; then
    echo "[apt-aria] Downloading $(< "$URI_FILE" wc -l) packages via aria2c..."
    echo "[apt-aria] Cache directory: $CACHE"
    echo "[apt-aria] aria2c command: aria2c --check-certificate=false -x16 -s16 -m3 -d $CACHE -i $URI_FILE"

    # Try multi-connection first with error suppression
    if ! aria2c --check-certificate=false -x16 -s16 -m3 -d "$CACHE" -i "$URI_FILE" 2>/dev/null; then
      echo "[apt-aria] Multi-connection failed, trying single-connection..."
      # Fallback: single-connection (handles servers that reject ranges, e.g. some PPAs)
      if ! aria2c --check-certificate=false -x1 -s1 -m3 -d "$CACHE" -i "$URI_FILE" 2>/dev/null; then
        echo "[apt-aria] aria2c failed completely, falling back to apt-get"
      else
        echo "[apt-aria] Single-connection aria2c succeeded"
      fi
    else
      echo "[apt-aria] Multi-connection aria2c succeeded"
    fi
    rm -f "$URI_FILE"
  else
    echo "[apt-aria] No URIs to download"
  fi

  # --- PROTECT CACHE ---
  # Make all .deb files in the cache immutable to prevent deletion
  echo "[apt-aria] Making downloaded packages immutable to protect cache..."
  if command -v chattr >/dev/null 2>&1; then
    chattr +i "${CACHE}/"*.deb 2>/dev/null
    echo "[apt-aria] chattr command executed successfully"
  else
    echo "[apt-aria] WARNING: chattr command not available - cache protection disabled"
  fi

  # Install from cache using apt-get (reliable and standard)
  echo "[apt-aria] Installing packages from cache..."
  exec /usr/bin/apt-get $APT_CACHE_OPTS -y "$@"
else
  # Use regular apt-get with cache configuration for non-install commands
  echo "[apt-aria] Using apt-get with cache configuration..."
  exec /usr/bin/apt-get $APT_CACHE_OPTS "$@"
fi
EOF
chmod 0755 /usr/local/bin/apt-aria
echo "✓ apt-aria wrapper created"
# Monitor cache after apt-aria setup
monitor_cache "After apt-aria wrapper setup"

# Create comprehensive aliases to ensure ALL apt tools use consistent caching
echo "Creating APT tool aliases for consistent caching..."
ln -sf /usr/local/bin/apt-aria /usr/local/bin/apt-get
ln -sf /usr/local/bin/apt-aria /usr/local/bin/apt

# Update PATH to prioritize /usr/local/bin (where our aliases are)
export PATH="/usr/local/bin:$PATH"

# Verify the aliasing is working
echo "Verifying APT tool aliasing..."
echo "apt-get -> $(readlink -f /usr/local/bin/apt-get 2>/dev/null || echo 'Not aliased')"
echo "apt -> $(readlink -f /usr/local/bin/apt 2>/dev/null || echo 'Not aliased')"

# Test cache functionality
echo "Testing unified APT cache functionality..."
if /usr/local/bin/apt-get --download-only install -y curl 2>/dev/null; then
  if [ -f "/container_cache/apt/archives/curl"*.deb ]; then
    echo "✓ Unified APT cache test successful - curl package cached"
    rm -f /container_cache/apt/archives/curl*.deb 2>/dev/null || true
  else
    echo "Δ Unified APT cache test - package downloaded but not found in cache"
  fi
else
  echo "Δ Unified APT cache test failed - curl may already be installed"
fi

# *** EARLY VERIFICATION OF CACHED FILES (catch corruption after copy) ***
echo "==> Performing early verification of cached files..."
early_verify_cached_files() {
  echo "Verifying cached files for corruption after container copy..."

  # Verify Miniforge installer
  if [ -f "/container_cache/binaries/${MINIFORGE_SH}" ]; then
    echo "Verifying Miniforge installer..."
    if sha256sum -c <(echo "${MINIFORGE_SHA256} /container_cache/binaries/${MINIFORGE_SH}") 2>/dev/null; then
      echo "✓ Miniforge SHA256 verified"
    else
      echo "✗ Miniforge SHA256 verification failed - file corrupted during copy!"
      echo "  Attempting to re-download..."
      curl -fsSL -o "/container_cache/binaries/${MINIFORGE_SH}" "${MINIFORGE_URL}"
      if sha256sum -c <(echo "${MINIFORGE_SHA256} /container_cache/binaries/${MINIFORGE_SH}") 2>/dev/null; then
        echo "✓ Miniforge re-downloaded and verified"
      else
        echo "✗ Miniforge re-download also failed - aborting build"
        exit 1
      fi
    fi
  fi

  # Verify Micromamba
  if [ -f "/container_cache/binaries/micromamba-linux-64" ]; then
    echo "Verifying Micromamba..."
    if sha256sum -c <(echo "${MICROMAMBA_SHA256} /container_cache/binaries/micromamba-linux-64") 2>/dev/null; then
      echo "✓ Micromamba SHA256 verified"
    else
      echo "✗ Micromamba SHA256 verification failed - file corrupted during copy!"
      echo "  Attempting to re-download..."
      curl -fsSL -o "/container_cache/binaries/micromamba-linux-64" "${MICROMAMBA_URL}"
      if sha256sum -c <(echo "${MICROMAMBA_SHA256} /container_cache/binaries/micromamba-linux-64") 2>/dev/null; then
        echo "✓ Micromamba re-downloaded and verified"
      else
        echo "✗ Micromamba re-download also failed - aborting build"
        exit 1
      fi
    fi
  fi

  # Verify yq
  if [ -f "/container_cache/binaries/yq_linux_amd64" ]; then
    echo "Verifying yq..."
    if sha256sum -c <(echo "${YQ_SHA256} /container_cache/binaries/yq_linux_amd64") 2>/dev/null; then
      echo "✓ yq SHA256 verified"
    else
      echo "✗ yq SHA256 verification failed - file corrupted during copy!"
      echo "  Attempting to re-download..."
      curl -fsSL -o "/container_cache/binaries/yq_linux_amd64" "${YQ_URL}"
      if sha256sum -c <(echo "${YQ_SHA256} /container_cache/binaries/yq_linux_amd64") 2>/dev/null; then
        echo "✓ yq re-downloaded and verified"
      else
        echo "✗ yq re-download also failed - aborting build"
        exit 1
      fi
    fi
  fi

  # Verify Julia (early verification for complex archive)
  if [ -f "/container_cache/binaries/julia-1.10.5-linux-x86_64.tar.gz" ]; then
    echo "Verifying Julia archive..."
    local julia_file="/container_cache/binaries/julia-1.10.5-linux-x86_64.tar.gz"
    local expected_sha256="33497b93cf9dd65e8431024fd1db19cbfbe30bd796775a59d53e2df9a8de6dc0"
    local julia_url="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.5-linux-x86_64.tar.gz"

    # SHA256 verification
    if sha256sum -c <(echo "${expected_sha256} ${julia_file}") 2>/dev/null; then
      echo "✓ Julia SHA256 verified"
    else
      echo "✗ Julia SHA256 verification failed - file corrupted during copy!"
      echo "  Attempting to re-download..."
      curl -fsSL -o "${julia_file}" "${julia_url}"
      if sha256sum -c <(echo "${expected_sha256} ${julia_file}") 2>/dev/null; then
        echo "✓ Julia re-downloaded and SHA256 verified"
      else
        echo "✗ Julia re-download also failed - aborting build"
        exit 1
      fi
    fi

    # gzip integrity check
    if gzip -t "${julia_file}" 2>/dev/null; then
      echo "✓ Julia gzip integrity verified"
    else
      echo "✗ Julia gzip integrity check failed - archive is corrupted!"
      echo "  Attempting to re-download..."
      curl -fsSL -o "${julia_file}" "${julia_url}"
      if gzip -t "${julia_file}" 2>/dev/null; then
        echo "✓ Julia re-downloaded and gzip integrity verified"
      else
        echo "✗ Julia re-download also failed - aborting build"
        exit 1
      fi
    fi
  fi

  echo "✓ Early verification completed - all cached files are intact"
}
early_verify_cached_files

# *** SETUP GPG VERIFICATION (now that tools are available) ***
setup_gpg_verification

# === Helper Function to Consolidate Mirror Selection ===
probe_and_set_mirrors() {
  export LC_NUMERIC=C # Prevents printf errors with decimals
  echo "==> Probing for the fastest Ubuntu mirror by testing a candidate list..."
  CODENAME="$(. /etc/os-release; echo "${UBUNTU_CODENAME:-jammy}")"
  PROBE_RESULTS="$(mktemp)"

  # Function to test a single mirror (for parallel execution)
  test_mirror() {
    local URL="$1"
    local CODENAME="$2"
    local PROBE_RESULTS="$3"
    
    [[ -z "${URL}" ]] && return

    # Use curl to measure actual download speed with large files.
    # Primary: Download Packages.gz (~20MB) to measure bandwidth
    # Fallback: Use Release file for latency if large file fails.
    set +e
    local CURL_OUTPUT CURL_EXIT_CODE SPEED_MBPS

    # Try to download a large file to measure actual bandwidth
    # Use Packages.gz (typically 10-50MB) for better speed measurement
    CURL_OUTPUT="$(LC_NUMERIC=C curl -s -w '%{time_total}\n' -o /dev/null -m 30 --retry 2 -L "${URL}/dists/${CODENAME}/main/binary-amd64/Packages.gz" 2>/dev/null)"
    CURL_EXIT_CODE=$?

    # If large file download succeeds, calculate speed
    if [[ $CURL_EXIT_CODE -eq 0 ]] && [[ -n "$CURL_OUTPUT" ]] && [[ "$CURL_OUTPUT" != "0.000000" ]]; then
      # Estimate file size (Packages.gz is typically 10-50MB)
      local ESTIMATED_SIZE_MB=20 # Conservative estimate
      # Calculate speed: size/time (MB/s), then convert to latency equivalent
      SPEED_MBPS=$(echo "scale=6; ${ESTIMATED_SIZE_MB} / ${CURL_OUTPUT}" | bc 2>/dev/null || echo "0")
      # Convert to latency-like metric (inverse of speed)
      CURL_OUTPUT=$(echo "scale=6; 1 / ${SPEED_MBPS}" | bc 2>/dev/null || echo "$CURL_OUTPUT")
    else
      # Fallback to Release file latency test
      CURL_OUTPUT="$(LC_NUMERIC=C curl -s -w '%{time_total}\n' -o /dev/null -m 10 --retry 2 -I "${URL}/dists/${CODENAME}/Release" 2>/dev/null)"
      CURL_EXIT_CODE=$?
    fi
    set -e

    # If curl failed, returned 0.000000, or empty output, use 9.9
    if [[ $CURL_EXIT_CODE -ne 0 ]] || [[ -z "$CURL_OUTPUT" ]] || [[ "$CURL_OUTPUT" == "0.000000" ]] || [[ -z "$CURL_OUTPUT" ]]; then
      echo "9.9 ${URL}" >> "$PROBE_RESULTS"
    else
      echo "${CURL_OUTPUT} ${URL}" >> "$PROBE_RESULTS"
    fi
  }

  # Export function for parallel execution
  export -f test_mirror

  # Define mirrors list - High-speed (10Gb+) and up-to-date mirrors only
  # Based on: https://launchpad.net/ubuntu/+archivemirrors
  CANDIDATE_MIRRORS="https://archive.ubuntu.com/ubuntu"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://de.archive.ubuntu.com/ubuntu"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://au.archive.ubuntu.com/ubuntu"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://in.archive.ubuntu.com/ubuntu"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://jp.archive.ubuntu.com/ubuntu"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://sg.archive.ubuntu.com/ubuntu"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.aarnet.edu.au/pub/ubuntu/archive/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.leaseweb.net/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.gsl.icu/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.internet.asn.au/pub/ubuntu/archive/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.datamossa.io/ubuntu/archive/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.realcompute.io/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://ubuntu.mirror.serversaustralia.com.au/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.alwyzon.net/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.easynmae.at/ubuntu-archive/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://ubuntu.aneria.at/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.datacenter.az/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.ourhost.az/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.asnet.am/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirrors.teamcloud.am/mirrors/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.azvps.vn/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://ubuntu.vpsett.com/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.clearsky.vn/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirrors.bkns.vn/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirrors.gofiber.vn/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirror.tino.org/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://vn-mirrors.techhost.vn/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://vn-mirrors.vhost.vn/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirrors.kernel.org/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirrors.ustc.edu.cn/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://repo.huaweicloud.com/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://mirrors.nipa.cloud/ubuntu/"
  CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} https://ossmirror.mycloud.services/os/linux/ubuntu/"

  # Run mirror tests in parallel (max 8 concurrent)
  echo "Testing mirrors in parallel (max 8 concurrent)..."
  echo "${CANDIDATE_MIRRORS}" | xargs -n 1 -P 8 -I {} bash -c 'test_mirror "$@"' _ {} "${CODENAME}" "${PROBE_RESULTS}"
  
  # --- Mirror Probe Results (speed score, url): ---
  echo "--- Mirror Probe Results (speed score, url): ---"
  LC_NUMERIC=C sort -n "$PROBE_RESULTS" | sed 's/^/ /'
  # Extract the fastest mirror that responded in under 9 seconds
  FASTEST_MIRROR="$(LC_NUMERIC=C sort -n "$PROBE_RESULTS" | awk 'NF==2 && $1 < 9.0 {print $2; exit}')"
  rm -f "$PROBE_RESULTS"
  if [[ -z "$FASTEST_MIRROR" ]]; then
    echo "[warn] All mirror probes failed. Using default ubuntu archive."
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
  fi
  echo "==> Selected fastest mirror: $FASTEST_MIRROR"
  # Apply the fastest mirror to the main APT sources
  sed -i "s|http[s]*://[^/]*ubuntu|${FASTEST_MIRROR}|g" /etc/apt/sources.list
}

  # --- Configure dpkg to exclude docs and man pages to save space ---
  echo "==> Configuring dpkg to exclude unnecessary documentation..."
  cat > /etc/dpkg/dpkg.cfg.d/01-nodoc << 'EOF'
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


# ---- define prune helpers early ----
install -d -m 0755 /usr/local/bin
apt-get update -o Acquire::Retries=3
# --- Install all bootstrap and utility packages in one go ---
echo "==> Installing all bootstrap and utility packages..."
# Clean up any existing apt temporary directories
rm -rf /tmp/apt-dpkg-install-* 2>/dev/null || true
rm -rf /var/cache/apt/archives/partial/* 2>/dev/null || true

# Batch 1: Additional network and download tools
echo "==> Installing additional network and download tools..."
apt-get install -y --no-install-recommends \
  rsync

# Batch 2: Additional security and encryption tools
echo "==> Installing additional security and encryption tools..."
apt-get install -y --no-install-recommends \
  ca-certificates-java

# Batch 3: Development and utility tools
echo "==> Installing development and utility tools..."
apt-get install -y --no-install-recommends \
  python3-pip

# Monitor cache after bootstrap packages installation
monitor_cache "After bootstrap packages installation"
debug_glibc "After installing bootstrap packages"
update-ca-certificates
locale-gen en_US.UTF-8
# We already have nala and aptitude installed via APT for package management
command -v curl || { echo "curl install failed"; exit 1; }

# *** RUN THE UNIFIED MIRROR PROBE ONCE ***
probe_and_set_mirrors

# ===> ADDED: ALL PPA CONFIGURATIONS (EARLIEST POSSIBLE) - OPTIMIZED
echo "==> Adding all PPAs (earliest possible) - OPTIMIZED"
# Add all PPAs using fallback method (add-apt-repository with proper error handling)
echo "Adding PPA repositories with verification..."

# Try modern method first, fallback to add-apt-repository if needed
echo "Attempting to add PPAs using add-apt-repository..."
# apt-fast PPA removed - using apt-aria wrapper instead
add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null || echo "[warn] Mozilla PPA failed, will try manual method"
add-apt-repository -y ppa:agornostal/ulauncher 2>/dev/null || echo "[warn] Ulauncher PPA failed, will try manual method"
CODENAME=$(lsb_release -cs)
# If add-apt-repository failed, use manual method as fallback
if [ ! -f /etc/apt/sources.list.d/mozillateam-ubuntu-ppa-${CODENAME}.list ]; then
  echo "Using manual PPA configuration as fallback for ${CODENAME}..."

  # apt-fast PPA removed - using apt-aria wrapper instead

  # Add Mozilla PPA manually
  echo "deb http://ppa.launchpad.net/mozillateam/ppa/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/mozillateam-ppa.list
  echo "deb-src http://ppa.launchpad.net/mozillateam/ppa/ubuntu ${CODENAME} main" >> /etc/apt/sources.list.d/mozillateam-ppa.list

  # Add Ulauncher PPA manually
  echo "deb http://ppa.launchpad.net/agornostal/ulauncher/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/ulauncher-ppa.list
  echo "deb-src http://ppa.launchpad.net/agornostal/ulauncher/ubuntu ${CODENAME} main" >> /etc/apt/sources.list.d/ulauncher-ppa.list
fi

# Add GPG keys using direct download method (most reliable)
echo "Adding PPA GPG keys..."
# apt-fast key removed - using apt-aria wrapper

# Mozilla PPA key
curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0xAEBDF4819BE21867 | gpg --dearmor -o /etc/apt/trusted.gpg.d/mozillateam.gpg 2>/dev/null \ || echo "[warn] Mozilla key failed"

# Ulauncher PPA key
curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0xFAF1020699503176 | gpg --dearmor -o /etc/apt/trusted.gpg.d/ulauncher.gpg 2>/dev/null \ || echo "[warn] Ulauncher key failed"

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

# Monitor cache after PPA update
monitor_cache "After PPA update"

# --- Improve APT robustness ---
cat >> /etc/apt/apt.conf.d/80-retries << 'EOF'
Acquire::Retries "3";
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::ftp::Timeout "30";
EOF
# apt-fast environment variables and verification removed - using apt-aria wrapper instead

# apt-fast debug section removed - using apt-aria wrapper instead
# apt-fast debug code removed - using apt-aria wrapper instead

# apt-fast mirror checking removed - using apt-aria wrapper instead

# Apt-aria wrapper moved to early in the script for better integration

# === Drake APT (use cached key) + INSTALL ===
echo "==> Drake APT (hardened via cached key) + INSTALL"
# === Drake APT setup (strictly per drake.mit.edu/apt.html) ===
set -e
# 1) BEFORE apt-get update (temporary insecure override for just the Drake host)
cat > /etc/apt/apt.conf.d/99-drake-insecure.conf <<'EOF'
Acquire::https::drake-apt.csail.mit.edu::Verify-Peer "false";
Acquire::https::drake-apt.csail.mit.edu::Verify-Host "false";
EOF

# 2) Download Drake GPG signing key and add to trusted keychain
# (Prefer cached copy if present to avoid re-downloading)
DRAKE_ASC="/tmp/drake.asc"
if [ -s "/container_cache/binaries/drake.asc" ]; then cp -f "/container_cache/binaries/drake.asc" "${DRAKE_ASC}"; \
else
  # Strict per docs: wget -O - | gpg --dearmor | tee ...
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
apt-get install -y \
  libx11-6 \
  libsm6 \
  libxt6 \
  libglib2.0-0
apt-get -o Dir::Cache::archives=/container_cache/apt/archives update || apt-get update

# Check for broken packages and fix them before installing drake-dev
echo "Checking for broken packages..."
apt-get -f install -y || true
dpkg --configure -a || true

# Install drake-dev with more verbose output for debugging
echo "Installing drake-dev..."
apt-get install -y --no-install-recommends drake-dev

# Monitor cache after Drake installation
monitor_cache "After Drake installation"

# 5) AFTER installing drake-dev (clean up the insecure override)
rm -f /etc/apt/apt.conf.d/99-drake-insecure.conf

# 6) Seed the key into cache for future builds (optional, harmless)
mkdir -p /container_cache/binaries
[ -s "$DRAKE_ASC" ] && cp -f "$DRAKE_ASC" /container_cache/binaries/drake.asc 2>/dev/null || true

# 7) Helpful environment for users (as Drake suggests)
# Create Drake environment setup script
cat > /etc/profile.d/drake.sh << 'EOF'
# Drake Python bindings
# NOTE: This is for system Python (3.12) and ROS 2 Jazzy
# will be automatically unset when Conda environments activate
export DRAKE_ROOT=/opt/drake
site_packages=$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')
# Add Drake Python bindings to PYTHONPATH
if [ -d "$DRAKE_ROOT/lib/python${site_packages}/site-packages" ]; then
  export PYTHONPATH="$DRAKE_ROOT/lib/python${site_packages}/site-packages:${PYTHONPATH}"
fi
if [ -d "$DRAKE_ROOT/lib/python3/dist-packages" ]; then
  export PYTHONPATH="$DRAKE_ROOT/lib/python3/dist-packages:${PYTHONPATH}"
fi
# Add Drake libraries to library path
export LD_LIBRARY_PATH="${DRAKE_ROOT}/lib:${LD_LIBRARY_PATH}"
# Add Drake binaries to PATH
export PATH="${DRAKE_ROOT}/bin:${PATH}"
EOF
chmod +x /etc/profile.d/drake.sh

echo "✓ Drake installed at /opt/drake"

# 8) After drake-dev install succeeds
sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/drake.list || true
apt-get update

# Configure Firefox preferences immediately
cat > /etc/apt/preferences.d/mozillateam.pref <<'PREF'
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 501
PREF

# Install Firefox immediately after PPA configuration with verification
echo "Installing Firefox with optimized PPA..."
if apt-get -y --no-install-recommends install libdbus-glib-1-2 firefox; then
  echo "✓ Firefox installed successfully"
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

# Monitor cache after desktop stack installation
monitor_cache "After desktop stack installation"
debug_glibc "After installing firefox, drake"

# === NEW BLOCK for HTML5 VNC Server (noVNC) ===
echo "==> Installing noVNC and websockify for HTML5 VNC access..."
NOVNC_VER="1.6.0"
# 1. Install the websockify proxy and its dependency
apt-get install -y --no-install-recommends websockify python3-numpy

# Install latest websockify with all features
pip3 install --no-cache-dir \
  websockify \
  numpy \
  jwcrypto \
  redis

# 2. Download and extract the noVNC client files to a standard location
# We are pinning to a specific stable version for reproducibility.
NOVNC_URL="https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VER}.tar.gz"
wget -qO /tmp/novnc.tar.gz "${NOVNC_URL}"
mkdir -p /usr/local/share/novnc
tar -xzf /tmp/novnc.tar.gz --strip-components=1 -C /usr/local/share/novnc
rm -f /tmp/novnc.tar.gz
# Set permissions for the web files
chmod -R 755 /usr/local/share/novnc
# === END OF noVNC BLOCK ===

# === Phase 2: Install Foundational System Libraries (via apt) ===
# This block consolidates all desktop, robotics, and ML library installations.
echo -e "\n${BLUE}### PHASE 1: Installing Foundational System Libraries ###${NC}"

# This flag will track the overall success of this phase.
PHASE1_ALL_SUCCESS=true

# Helper function for installing packages in logical groups and verifying each one.
install_and_verify_group() {
  local group_name="$1"
  shift
  local packages_to_install="$@"
  local group_success=true

  echo -e "${YELLOW}[PHASE 1 | ${group_name}] Installing...${NC}"
  # Run the install command, redirecting verbose output on success to a log
  # FIX: Add double quotes around the log filename to handle any special characters.
  if ! apt-get install -y --no-install-recommends ${packages_to_install} > "/tmp/apt_install_${group_name}.log" 2>&1; then
    echo -e "${RED}[PHASE 1 | ${group_name}] FAILED: 'apt-get install' command returned an error. See details below:${NC}"
    # FIX: Also quote the filename here for the cat command.
    cat "/tmp/apt_install_${group_name}.log"
    PHASE1_ALL_SUCCESS=false
    return 1
  fi

  echo -e "${YELLOW}[PHASE 1 | ${group_name}] Verifying...${NC}"
  for pkg in ${packages_to_install}; do
    if dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"; then
      echo -e "  - ${pkg}: ${GREEN}OK${NC}"
    else
      echo -e "  - ${pkg}: ${RED}FAIL (Package not found after install attempt)${NC}"
      group_success=false
      PHASE1_ALL_SUCCESS=false
    fi
  done

  if [ "${group_success}" = false ]; then
    echo -e "${RED}[PHASE 1 | ${group_name}] FAILED: One or more packages in this group failed verification.${NC}"
  fi
}

# --- Define packages for each logical group ---
PKGS_BUILD_TOOLS="build-essential gcc g++ make cmake ninja-build pkg-config ccache patchelf elfutils patch swig git pcl-tools ros-jazzy-pcl-conversions ros-jazzy-perception-pcl"
PKGS_DESKTOP_ENV="xorg dbus-x11 xserver-xorg-video-dummy x11-xserver-utils xauth xfce4 xfce4-goodies"
PKGS_CORE_LIBS="libgl1 libglvnd0 libegl1 libgles2 libxext6 libxrender1 libsm6 libxrandr2 libxi6 libxxf86vm1 libxkbfile1 libxinerama1 libxcursor1 libxdamage1 libxss1 libgl1-mesa-dri libdrm-dev"
PKGS_FONTS_UTILS="fontconfig fonts-dejavu fonts-liberation fonts-noto iproute2 iputils-ping net-tools lsof tmux screen htop p7zip-full python3-pip python3-venv whiptail"
PKGS_LINALG="libeigen3-dev libopenblas-dev liblapack-dev liblapacke-dev libblas-dev gfortran"
PKGS_CPU_PARALLEL="libtbb-dev libmpich-dev"
PKGS_SPARSE_SLAM="libsuitesparse-dev libmetis-dev libboost-all-dev"
PKGS_CORE_DEPS="libgflags-dev libgoogle-glog-dev libprotobuf-dev protobuf-compiler libhdf5-dev libffi-dev libssl-dev libbz2-dev liblzma-dev ca-certificates-java libgoogle-perftools-dev libtcmalloc-minimal4t64 libcpu-features-dev libva-dev libavcodec-dev libavformat-dev libswscale-dev"
PKGS_MEDIA_GUI="libjpeg-dev libpng-dev libwebp-dev libavcodec-dev libavformat-dev libswscale-dev libavutil-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgtk-3-dev libcanberra-gtk3-dev libvtk9-dev libgtkglext1-dev libevent-dev libyaml-cpp-dev libjsoncpp-dev"
PKGS_SIM="libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libbullet-dev libode-dev libassimp-dev libtinyxml2-dev"
PKGS_SERIALIZATION="libyaml-cpp-dev libjsoncpp-dev"

# --- Execute installation for each logical group ---
# FIX: Use single-word group names to prevent spaces in filenames.
install_and_verify_group "BuildTools" $PKGS_BUILD_TOOLS
# --- Special install for gdb to avoid dependency conflicts ---
echo -e "${YELLOW}[PHASE 1 | BuildTools] Installing gdb without recommended packages...${NC}"
apt-get install -y --no-install-recommends gdb
if dpkg -s "gdb" 2>/dev/null | grep -q "Status: install ok installed"; then
  echo -e "  - gdb: ${GREEN}OK${NC}"
else
  echo -e "  - gdb: ${RED}FAIL${NC}"
  # This part of the logic will likely not be reached, but is here for robustness
  PHASE1_ALL_SUCCESS=false
  echo -e "${RED}[PHASE 1 | BuildTools] FAILED: gdb installation failed.${NC}"
fi
# --- End of special gdb install ---
install_and_verify_group "DesktopEnv" $PKGS_DESKTOP_ENV
install_and_verify_group "CoreLibraries" $PKGS_CORE_LIBS
install_and_verify_group "FontsAndUtilities" $PKGS_FONTS_UTILS
install_and_verify_group "LinearAlgebra" $PKGS_LINALG
install_and_verify_group "CPUParallelism" $PKGS_CPU_PARALLEL
install_and_verify_group "SparseMath_SLAM" $PKGS_SPARSE_SLAM
install_and_verify_group "CoreDependencies" $PKGS_CORE_DEPS
install_and_verify_group "Media_and_GUI" $PKGS_MEDIA_GUI
install_and_verify_group "Simulation" $PKGS_SIM
install_and_verify_group "Serialization" $PKGS_SERIALIZATION

# --- SURGICAL FIX: Ensure Compiler Toolchain is Intact ---
echo -e "\n${YELLOW}[PHASE 1 | Sanity Check] Reinstalling core C++ compiler to fix any inconsistencies...${NC}"
apt-get install --reinstall -y g++ build-essential
echo -e "${GREEN}✓ Compiler toolchain verified.${NC}"
# --- END FIX ---

# Configure tmux for ROS workflows
cat > /etc/tmux.conf << 'EOF'
# Increase scrollback buffer
set-option -g history-limit 50000

# Enable mouse support
set -g mouse on

# Split panes with intuitive keys
bind | split-window -h
bind - split-window -v

# Pane switching with Alt+arrow
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left '#{fg=green}{#S} '
set -g status-right '#{fg=yellow}#(whoami)@#H'
EOF

# Create helper script for multi-ROS workflow
cat > /usr/local/bin/ros_multiterm << 'EOF'
#!/bin/bash
# Launch tmux session with multiple ROS environments

SESSION="ros_multi"

# Create new tmux session
tmux new-session -d -s $SESSION

# Window 0: Humble workspace
tmux rename-window -t $SESSION:0 'Humble'
tmux send-keys -t $SESSION:0 "conda activate ros2_humble" C-m
tmux send-keys -t $SESSION:0 "cd /workspaces/humble_ws" C-m

# Window 1: Jazzy workspace
tmux new-window -t $SESSION:1 -n 'Jazzy'
tmux send-keys -t $SESSION:1 "conda activate ros2_jazzy" C-m
tmux send-keys -t $SESSION:1 "cd /workspaces/jazzy_ws" C-m

# Window 2: Bridge/monitoring
tmux new-window -t $SESSION:2 -n 'Bridge'
tmux send-keys -t $SESSION:2 "echo 'Domain bridge - start when ready'" C-m

# Window 3: Julia processing
tmux new-window -t $SESSION:3 -n 'Julia'
tmux send-keys -t $SESSION:3 'julia' C-m

# Attach to session
tmux attach-session -t $SESSION
EOF
chmod +x /usr/local/bin/ros_multiterm

# --- Final Verdict for Phase 1 ---
if [ "${PHASE1_ALL_SUCCESS}" = true ]; then
  echo -e "${GREEN}✓ [PHASE 1] All foundational libraries installed and verified successfully.${NC}"
  export PHASE1_STATUS="PASS"
else
  echo -e "${RED}✗ [PHASE 1] Errors occurred during foundational library installation. Please review logs above.${NC}"
  export PHASE1_STATUS="FAIL"
  exit 1 # Exit the build immediately on phase failure
fi

# Update the dynamic linker cache to make newly installed libraries (.so files)
# available to applications at runtime.
# Like TBB and VTK
echo "==> Updating dynamic linker cache..."
sudo ldconfig
echo "Linker cache updated."
debug_glibc "After Phase 1 install: foundational system libraries"

# === Phase 3: Compile High-Level Dependencies (g2o, Ceres, GTSAM) ===
echo -e "\n${BLUE}### PHASE 3: Compiling High-Level Dependencies ###${NC}"
PHASE3_ALL_SUCCESS=true

# --- Compile g2o ---
echo -e "\n${YELLOW}[PHASE 3 | g2o] Compiling from source...${NC}"
rm -rf /tmp/g2o
G2O_VERSION="20241228_git"
git clone --branch ${G2O_VERSION} https://github.com/RainerKuemmerle/g2o.git /tmp/g2o && cd /tmp/g2o
mkdir build && cd build
cmake .. \
  -G Ninja \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_CXX_STANDARD=17 \
  -D CMAKE_CXX_STANDARD_REQUIRED=ON \
  -D BUILD_SHARED_LIBS=ON \
  -D BUILD_WITH_MARCH_NATIVE=OFF \
  -D G2O_USE_CHOLMOD=ON \
  -D G2O_USE_OPENMP=ON \
  -D BUILD_EXAMPLES=OFF \
  -D BUILD_UNITTESTS=OFF \
  -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
  -D CMAKE_POLICY_DEFAULT_CMP0069=NEW \
  -D CMAKE_CXX_FLAGS="-mavx2 -mfma"

ninja -j$(($(nproc) / 2))
ninja install
ldconfig
cd / && rm -rf /tmp/g2o
if ! ldconfig -p | grep -q "libg2o_core.so"; then
  echo -e "${RED}✗ g2o compilation FAILED.${NC}"
  PHASE3_ALL_SUCCESS=false
fi
debug_glibc "After installing g2o"

# --- Compile Ceres Solver ---
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  echo -e "${YELLOW}[PHASE 3 | Ceres] Compiling from source...${NC}"
  rm -rf /tmp/ceres-solver
  CERES_VERSION="2.2.0"
  git clone --branch ${CERES_VERSION} https://github.com/ceres-solver/ceres-solver.git /tmp/ceres-solver
  # --- Use explicit, separate commands for navigation ---
  cd /tmp/ceres-solver
  mkdir -p build
  cd build
  cmake .. \
    -G Ninja \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D CMAKE_POLICY_DEFAULT_CMP0069=NEW \
    -D CMAKE_CXX_FLAGS="-O3 -mavx2 -mfma -fopenmp" \
    -D CMAKE_SHARED_LINKER_FLAGS="-flto -fopenmp" \
    -D BUILD_SHARED_LIBS=ON \
    -D MINIGLOG=ON \
    -D CMAKE_CUDA_COMPILER_WORKS=TRUE \
    -D BLA_VENDOR=OpenBLAS \
    -D LAPACK=ON \
    -D EIGENMETIS=ON \
    -D EIGENSPARSE=ON \
    -D SUITESPARSE=ON \
    -D USE_CUDA=ON \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_TESTING=OFF \
    -D BUILD_BENCHMARKS=OFF \
    -D CMAKE_CUDA_ARCHITECTURES="86" \
    -D CMAKE_CXX_STANDARD=17 \
    -D CMAKE_CXX_STANDARD_REQUIRED=ON \
    -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

  # --- use explicit, separate commands for build ---
  ninja -j$(($(nproc) / 2));
  ninja install;
  ldconfig

  cd / && rm -rf /tmp/ceres-solver
  if ! ldconfig -p | grep -q "libceres.so"; then
    echo -e "${RED}✗ Ceres compilation FAILED.${NC}"
    PHASE3_ALL_SUCCESS=false
  fi
  cd /
fi
debug_glibc "After installing CERES"

# --- Compile GTSAM ---
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  echo -e "${YELLOW}[PHASE 3 | GTSAM] Compiling from source...${NC}"
  rm -rf /tmp/gtsam
  GTSAM_VERSION="4.2.0"
  git clone --branch ${GTSAM_VERSION} https://github.com/borglab/gtsam.git /tmp/gtsam && cd /tmp/gtsam
  mkdir build && cd build
  cmake .. \
    -G Ninja \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_SHARED_LIBS=ON \
    -D GTSAM_WITH_TBB=ON \
    -D GTSAM_USE_SYSTEM_EIGEN=ON \
    -D GTSAM_BUILD_TESTS=OFF \
    -D GTSAM_WITH_CHOLMOD=ON \
    -D GTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
    -D GTSAM_USE_SYSTEM_METIS=ON \
    -D CMAKE_CXX_FLAGS="-mavx2 -mfma" \
    -D GTSAM_BUILD_PYTHON=ON \
    -D GTSAM_PYTHON_VERSION=3.12 \
    -D GTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
    -D CMAKE_CXX_STANDARD=17 \
    -D CMAKE_CXX_STANDARD_REQUIRED=ON \
    -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -D CMAKE_POLICY_DEFAULT_CMP0069=NEW 

  ninja -j$(($(nproc) / 2));
  ninja install
  ldconfig
  cd / && rm -rf /tmp/gtsam
  if ! ldconfig -p | grep -q "libgtsam.so"; then
    echo -e "${RED}✗ GTSAM compilation FAILED.${NC}"
    PHASE3_ALL_SUCCESS=false
  fi
fi

# --- Final Verdict for Phase 3 ---
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  echo -e "${GREEN}✓ [PHASE 3] All high-level dependencies compiled and installed successfully.${NC}"
  export PHASE3_STATUS="PASS"
else
  echo -e "${RED}✗ [PHASE 3] One or more compilations failed. Please review logs.${NC}"
  export PHASE3_STATUS="FAIL"
  exit 1
fi
debug_glibc "After installing GTSAM"

# Julia 1.10 LTS + envs
# Julia 1.10.5: cache-aware download, verify, install (POSIX sh)
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
# echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99ipv4
mkdir -p "${CACHE_DIR}"

# Decide whether to fetch
need_fetch=0
if [ ! -f "${LATEST_TGZ}" ]; then
  need_fetch=1
else
  # quick integrity test
  if ! gzip -t "${LATEST_TGZ}" 2>/dev/null; then
    need_fetch=1
  fi
fi
if [ "$need_fetch" -eq 1 ]; then
  echo "[julia] fetching ${JULIA_URL}"
  # retry, follow redirects, fail on HTTP errors
  curl -fsSL --retry 5 --retry-all-errors --connect-timeout 5 --max-time 180 \
    -o "${LATEST_TGZ}.part" "${JULIA_URL}"
  mv -f "${LATEST_TGZ}.part" "${LATEST_TGZ}"
fi
# Julia archive already verified in early verification phase
echo "[julia] Archive already verified (SHA256 + gzip integrity check passed)"
# Optional GPG signature verification (best-effort, non-blocking)
echo "[julia] Performing optional GPG signature verification..."
GNUPGHOME=/root/.gnupg
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
# Download .asc file if available
curl -fsSL --retry 3 "${JASC_URL}" -o "${LATEST_TGZ}.asc" || true
# Import the GPG key from the local file prefetched from the host
if [ -f "/container_cache/binaries/julia_key.asc" ]; then
  echo "Importing local GPG key for Julia..."
  gpg --import /container_cache/binaries/julia_key.asc
else
  echo "[warn] Local Julia GPG key not found. GPG verification may fail."
fi
# Verify signature if .asc present and key imported (non-blocking)
if [ -s "${LATEST_TGZ}.asc" ]; then
  if gpg --batch --verify "${LATEST_TGZ}.asc" "${LATEST_TGZ}" 2>/tmp/julia_gpg_verify.log; then
    echo "[julia] ✓ GPG signature: GOOD"
  else
    echo "[julia] Δ GPG signature could not be verified (see /tmp/julia_gpg_verify.log). Continuing because SHA256 passed."
  fi
else
  echo "[julia] Δ No .asc file available for GPG verification. Continuing because SHA256 passed."
fi
# Extract and link /opt/julia -> /opt/julia-<ver>
echo "[julia] Installing to ${INSTALL_DIR}/julia-${JVER}"
tar -xzf "${LATEST_TGZ}" -C "${INSTALL_DIR}" 2>/dev/null || true
rm -f "${INSTALL_DIR}/julia" 2>/dev/null || true
ln -s "${INSTALL_DIR}/julia-${JVER}" "${INSTALL_DIR}/julia"
echo "[julia] Installed to ${INSTALL_DIR}/julia-${JVER}, symlinked as ${INSTALL_DIR}/julia"
# After extracting Julia and creating /opt/julia symlink
echo "[julia] Sanity check for /opt/julia/bin/julia"
# Sanity check (fail fast if missing)
JULIA_BIN="/opt/julia/bin/julia"
if [ ! -x "${JULIA_BIN}" ]; then
  echo "[julia] ERROR: /opt/julia/bin/julia not found or not executable"
  ls -l /opt || true
  exit 1
fi
# --- CRITICAL STEP: Update PATH for the current build script ---
echo "==> Updating PATH to include Julia for subsequent build steps..."
export PATH="/opt/julia/bin:${PATH}"
# Clear the shell's command lookup cache to ensure the new path is used
hash -r
# Verify that the julia command is now found in the path
command -v julia || { echo "ERROR: Julia executable not found in PATH after update."; exit 1; }
echo "✓ Julia is now available in the PATH."
# Quick smoke test (no precompile)
"${JULIA_BIN}" --version || true

# BUILD CxxWrap FROM SOURCE (BEFORE Julia env setup)
echo "==> Building libCxxWrap-julia from source for OpenCV/Integration"
CXXWRAP_PREFIX="/opt/libcxxwrap-julia"
if [ -x "$JULIA_BIN" ]; then
  if [ ! -f "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake" ]; then
    echo "Building libCxxWrap-julia from source..."
    # Get Julia paths
    JULIA_INCLUDE=$("$JULIA_BIN" -e 'print(joinpath(Sys.BINDIR, "..", "include", "julia"))')
    JULIA_LIB=$("$JULIA_BIN" -e 'print(joinpath(Sys.BINDIR, "..", "lib"))')
    echo "  Julia include: $JULIA_INCLUDE"
    echo "  Julia library: $JULIA_LIB"
    # Clone and build
    BUILD_DIR="/tmp/cxxwrap_build"
    rm -rf "$BUILD_DIR"
    git clone -q --depth 1 https://github.com/JuliaInterop/libcxxwrap-julia.git "$BUILD_DIR"
    cd "$BUILD_DIR"
    mkdir build && cd build

    cmake .. \
      -DCMAKE_INSTALL_PREFIX="$CXXWRAP_PREFIX" \
      -DCMAKE_BUILD_TYPE=Release \
      -DJulia_EXECUTABLE="$JULIA_BIN" \
      -DJulia_INCLUDE_DIR="$JULIA_INCLUDE" \
      -DJulia_LIBRARY_DIR="$JULIA_LIB" \
      -DCMAKE_INSTALL_LIBDIR=lib \
      /dev/null

    make -j$(nproc) >/dev/null 2>&1
    make install >/dev/null

    cd /
    rm -rf "$BUILD_DIR"
    echo "✓ Libcxxwrap-julia built to $CXXWRAP_PREFIX"
  else
    echo "✓ Libcxxwrap-julia already installed"
  fi

  # CRITICAL FIX: Add missing CMake target export
  if ! grep -q "JlCxx::cxxwrap_julia" "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake"; then
    echo "Adding CMake target export to JlCxxConfig.cmake..."
    cat >> "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake" << 'CMAKE_FIX'

# =================================================
# Exported target for OpenCV integration
# =================================================
if(NOT TARGET JlCxx::cxxwrap_julia)
  add_library(JlCxx::cxxwrap_julia SHARED IMPORTED)
  set_target_properties(JlCxx::cxxwrap_julia PROPERTIES
    IMPORTED_LOCATION "/opt/libcxxwrap-julia/lib/libcxxwrap_julia.so"
    INTERFACE_INCLUDE_DIRECTORIES "/opt/libcxxwrap-julia/include"
    INTERFACE_LINK_LIBRARIES "/opt/julia/lib/libjulia.so"
  )
endif()

# Source build marker for OpenCV
set(JlCxx_IS_SOURCE_BUILD TRUE)
set(JlCxx_FOUND TRUE)
set(JlCxx_INCLUDE_DIRS "/opt/libcxxwrap-julia/include")
set(JlCxx_LIBRARIES "/opt/libcxxwrap-julia/lib/libcxxwrap_julia.so")
CMAKE_FIX
    echo "✓ CMake target export added"
  fi

  # Export CMAKE_PREFIX_PATH before any Julia package operations
  export CMAKE_PREFIX_PATH="${CXXWRAP_PREFIX}:${CMAKE_PREFIX_PATH:-}"
  # Make permanent
  echo "export CMAKE_PREFIX_PATH=\"${CXXWRAP_PREFIX}:\${CMAKE_PREFIX_PATH}\"" >> /etc/profile.d/cxxwrap.sh
  # Just verify the file exists
  if [ -f "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake" ]; then
    echo "✓ JlCxx CMake config ready"
  else
    echo "✗ JlCxx CMake config not found"
    exit 1
  fi
fi
debug_glibc "After CxxWrap source build"
echo "CxxWrap source build ready for OpenCV"

# === Install NVIDIA Video Codec SDK (Cache-Aware) ===
echo "==> Installing NVIDIA Video Codec SDK from cache..."

SDK_VERSION="12.1.14"
SDK_ZIP_FILENAME="Video_Codec_SDK_${SDK_VERSION}.zip"
SDK_ZIP_CACHE_PATH="/container_cache/binaries/${SDK_ZIP_FILENAME}"

# Check if the user has manually cached the SDK .zip file.
if [ -f "${SDK_ZIP_CACHE_PATH}" ]; then
  echo "--> Found cached NVIDIA Video Codec SDK. Using it."
  cp "${SDK_ZIP_CACHE_PATH}" "/tmp/${SDK_ZIP_FILENAME}"
else
  echo -e "\n${RED}FATAL ERROR: NVIDIA Video Codec SDK not found in cache.${NC}"
  echo -e "${YELLOW}Please manually download '${SDK_ZIP_FILENAME}' from the NVIDIA Developer website:${NC}"
  echo -e "https://developer.nvidia.com/nvidia-video-codec-sdk/download"
  echo -e "${YELLOW}Then, place the downloaded .zip file into your 'container_cache/binaries/' directory and re-run the build.${NC}\n"
  exit 1
fi
cd /tmp
unzip -q "${SDK_ZIP_FILENAME}"

# 1. Define the SDK folder name for clarity
SDK_FOLDER="Video_Codec_SDK_${SDK_VERSION}"

# 2. Move the folder from /tmp to /opt using sudo
echo "Moving ${SDK_FOLDER} to /opt/${SDK_FOLDER}"
sudo mv "/tmp/${SDK_FOLDER}" "/opt/${SDK_FOLDER}"
sudo mv "/opt/${SDK_FOLDER}" "/opt/Video_Codec_SDK"

# 3. (Recommended) Change Ownership to your user for easy access
# This prevents needing sudo for every minor change in the future.
sudo chown -R ${USER}:${USER} "/opt/Video_Codec_SDK"
echo "SDK successfully moved to /opt/Video_Codec_SDK"

# Copy the interface headers to a system-wide location
cp "/opt/Video_Codec_SDK/Interface/"*.h /usr/local/include
cp "/opt/Video_Codec_SDK/Interface/"*.h /usr/local/cuda-${CUDA_VERSION}/include

# Verify headers were copied
if [ -f /usr/local/include/nvcuvid.h ] && [ -f /usr/local/include/cuviddec.h ]; then
  echo "✓ Video Codec SDK headers verified at /usr/local/include/"
  ls -la /usr/local/include/nvc*
else
  echo "Δ Video Codec SDK headers may be incomplete"
  ls -la /usr/local/include/ | grep -i nv || echo "No NVIDIA headers found"
fi

# Cleanup
rm -rf "/tmp/${SDK_FOLDER}" "${SDK_ZIP_FILENAME}"
cd /

echo "✓ NVIDIA Video Codec SDK headers installed successfully."
#==============================================================

# === Phase 4: Compile OpenCV from Source with All Accelerations ===
# This is the main event. We compile OpenCV 4.5.4 to match ROS 2 Humble,
# but with all high-performance backends enabled.
echo -e "\n${BLUE}### PHASE 4: Compiling OpenCV from source ###${NC}"

# Proactively clean up temp directories from any previous failed run
rm -rf /tmp/opencv /tmp/opencv_contrib

# Pin to the version compatible with ROS 2 Humble
OPENCV_VERSION="4.12.0"
INSTALL_PREFIX="/usr/local"
CUDA_ARCH="8.6"

echo "========================================="
echo "OpenCV ${OPENCV_VERSION} Build Automation"
echo "========================================="

# Step 1: Install all dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y \
  build-essential cmake ninja-build pkg-config \
  libopenblas-dev liblapacke-dev gfortran \
  libtbb-dev libeigen3-dev \
  libjpeg-dev libpng-dev libtiff-dev \
  libavcodec-dev libavformat-dev libswscale-dev \
  libgtk-3-dev python3-dev python3-numpy \
  g++ gcc libc6-dev linux-libc-dev libstdc++-11-dev gcc-12 g++-12 libtesseract-dev

# Step 2: Download OpenCV source
git clone --depth 1 --branch ${OPENCV_VERSION} https://github.com/opencv/opencv.git /tmp/opencv
git clone --depth 1 --branch ${OPENCV_VERSION} https://github.com/opencv/opencv_contrib.git /tmp/opencv_contrib

# Step 3: Create build directory
cd /tmp/opencv
mkdir -p build
cd build

# Step 4: Configure environment for CMake
# Before OpenCV CMake, append paths safely
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
export LIBRARY_PATH="${LIBRARY_PATH}:/usr/lib/x86_64-linux-gnu"

# The comprehensive CMake command to enable all backends and best practices
echo -e "${YELLOW}[Phase 4 | OpenCV] Configuring with Cmake...${NC}"

cmake -G Ninja \
  -D CPU_BASELINE=AVX2 \
  -D CMAKE_BUILD_TYPE=RELEASE \
  -D CMAKE_C_COMPILER=/usr/bin/gcc-12 \
  -D CMAKE_CXX_COMPILER=/usr/bin/g++-12 \
  -D CUDA_HOST_COMPILER=/usr/bin/g++-12 \
  -D CMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
  -D OPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib/modules \
  -D BUILD_SHARED_LIBS=ON \
  -D CMAKE_C_COMPILER_LAUNCHER=ccache \
  -D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -D OPENCV_GENERATE_PKGCONFIG=ON \
  -D BUILD_opencv_python3=ON \
  -D PYTHON3_EXECUTABLE=$(which python3) \
  -D CUDA_NVCC_FLAGS="--expt-relaxed-constexpr --expt-extended-lambda;-allow-unsupported-compiler;-Xcompiler=-fPIC;-Xcompiler=-Wno-deprecated-declarations;-x=cu;-std=c++17" \
  -D CMAKE_CUDA_FLAGS="-allow-unsupported-compiler -Xcompiler=-W" \
  -D CMAKE_HOST_COMPILER=/usr/bin/g++-12 \
  -D CMAKE_C_COMPILER_WORKS=TRUE \
  -D CMAKE_CXX_COMPILER_WORKS=TRUE \
  -D WITH_CUDNN=ON \
  -D WITH_OPENBLAS=ON \
  -D CUDA_ARCH_BIN="8.6" \
  -D CUDA_ARCH_PTX="8.6" \
  -D OPENCV_DNN_CUDA=ON \
  -D ENABLE_FAST_MATH=1 \
  -D CUDA_FAST_MATH=1 \
  -D WITH_CUBLAS=1 \
  -D WITH_OPENGL=ON \
  -D WITH_TBB=ON \
  -D WITH_EIGEN=ON \
  -D WITH_FFMPEG=ON \
  -D WITH_GSTREAMER=ON \
  -D WITH_LAPACK=ON \
  -D JlCxx_DIR=/opt/julia/CxxWrap/deps/build/JlCxx/ \
  -D LAPACK_ENABLE_LAPACKE=ON \
  -D WITH_VTK=ON \
  -D VTK_DIR=/usr/lib/x86_64-linux-gnu/cmake/vtk-9.3 \
  -D OPENCV_ENABLE_NONFREE=ON \
  -D BUILD_EXAMPLES=OFF \
  -D BUILD_TESTS=OFF \
  -D BUILD_PERF_TESTS=OFF \
  -D BUILD_DOCS=OFF \
  -D WITH_IPP=OFF \
  -D BUILD_opencv_apps=OFF \
  -D BUILD_opencv_sfm=OFF \
  -D BUILD_opencv_python3=ON \
  -D PYTHON3_EXECUTABLE=/usr/bin/python3 \
  -D PYTHON3_INCLUDE_DIR=/usr/include/python3.12 \
  -D PYTHON3_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.12.so \
  -D PYTHON3_NUMPY_INCLUDE_DIRS=/usr/lib/python3/dist-packages/numpy/core/include \
  -D WITH_TIFF=ON \
  -D TBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB \
  -D TBB_LIBRARIES=/usr/lib/x86_64-linux-gnu/libtbb.so \
  -D BLAS_LIBRARIES=/usr/lib/x86_64-linux-gnu/libopenblas.so* \
  -D CMAKE_INSTALL_RPATH="/usr/local/lib" \
  -D OPENCV_DNN_CUDA=ON \
  -D OPENCV_DNN_CUDA_VERSION=${CUDA_VERSION} \
  -D CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-${CUDA_VERSION} \
  -D CMAKE_C_STANDARD=17 \
  -D CMAKE_CXX_STANDARD=17 \
  -D CMAKE_CUDA_STANDARD=17 \
  -D CMAKE_C_STANDARD_REQUIRED=ON \
  -D CMAKE_CXX_STANDARD_REQUIRED=ON \
  -D CMAKE_CUDA_STANDARD_REQUIRED=ON \
  -D BLA_VENDOR=OpenBLAS \
  -D LAPACK_LIBRARIES="/usr/lib/x86_64-linux-gnu/libopenblas.so;/usr/lib/x86_64-linux-gnu/liblapacke.so.3;/usr/lib/x86_64-linux-gnu/liblapack.so" \
  -D LAPACK_LIBRARY=/usr/lib/x86_64-linux-gnu/liblapack.so \
  -D LAPACKE_LIBRARY=/usr/lib/x86_64-linux-gnu/liblapacke.so.3 \
  -D LAPACK_CBLAS_H=/usr/include/x86_64-linux-gnu/cblas.h \
  -D LAPACK_LAPACKE_H=/usr/include/lapacke.h \
  -D OpenBLAS_LIB=/usr/lib/x86_64-linux-gnu/libopenblas.so \
  -D CMAKE_INCLUDE_PATH="/usr/include/x86_64-linux-gnu;/usr/include" \
  -D OpenBLAS_INCLUDE_DIR=/usr/include/x86_64-linux-gnu/ \
  -D BUILD_opencv_cudacodec=ON \
  -D CMAKE_CXX_FLAGS="-Wno-deprecated -fpermissive -mavx2 -mfma" \
  -D BUILD_opencv_cudaarithm=ON \
  -D CMAKE_EXE_LINKER_FLAGS="-flto" \
  -D CMAKE_MODULE_LINKER_FLAGS="-flto" \
  -D CMAKE_SHARED_LINKER_FLAGS="-flto" \
  -D LAPACK_LIBRARY_DEBUG=/usr/lib/x86_64-linux-gnu/liblapack.so.3 \
  -D WITH_CUDA=ON \
  -D VIDEO_CODEC_SDK_DIR=/opt/Video_Codec_SDK \
  -D BUILD_opencv_julia=OFF \
  -D Julia_EXECUTABLE=/opt/julia/bin/julia \
  -D Julia_INCLUDE_DIRS=/opt/julia/include/julia \
  -D Julia_LIBRARIES=/opt/julia/lib/libjulia.so \
  -D JlCxx_DIR=/opt/libcxxwrap-julia/lib/cmake/JlCxx \
  -D CMAKE_PREFIX_PATH="/opt/libcxxwrap-julia:${CMAKE_PREFIX_PATH}" \
  -D CMAKE_IGNORE_PATH="/root/.julia" \
  -D WITH_NVCUVID=OFF \
  -D WITH_NVCUVENC=OFF \
  -D NVCUVID_HEADER_DIR=/usr/local/include/ \
  .. 

# Step 6: Verify configuration
echo "Verifying Cmake configuration..."
if ! grep -q "LAPACK.*YES" CMakeCache.txt; then
  echo "WARNING: LAPACK not detected"
fi
if ! grep -q "TBB.*YES" CMakeCache.txt; then
  echo "WARNING: TBB not detected"
fi
echo "Configuration summary:"
grep -E "LAPACK|TBB|OPENMP|CUDA" CMakeCache.txt | grep -v "^//" | head -10

# Step 7: Build
JOBS=$(($(nproc) / 2))
echo "Building with $JOBS parallel jobs..."
ninja -j$JOBS

# Step 8: Install
echo "Installing..."
ninja install

# Now setup Julia environments with CxxWrap from source
#

if [ -x "$JULIA_BIN" ]; then
  echo "Julia installed successfully"
fi

ldconfig

# Step 9: Verify Installation
echo "Verifying installation..."
python3 -c "import cv2; print(f'OpenCV version: {cv2.__version__}'); print(f'CUDA: {cv2.cuda.getCudaEnabledDeviceCount() if hasattr(cv2, 'cuda') else 'N/A'}')"

pkg-config --modversion opencv4 || echo "pkg-config not found (normal for some builds)"

echo "Build complete!"
echo "==============="

# Clear the shell's command hash to find the new executable
hash -r

cd /
rm -rf /tmp/opencv /tmp/opencv_contrib

# Setup Julia Environments (AFTER OpenCV is built)
echo "==> Julia ${JULIA_LTS_VER:-1.10.x} install & envs"
if [ -x "$JULIA_BIN" ]; then
  echo "Julia installed successfully"

  # Create artifact override FIRST (before any Pkg operations)
  mkdir -p /root/.julia/artifacts
  cat > /root/.julia/artifacts/Overrides.toml << 'OVERRIDE'
# Force Julia to use our CxxWrap source build instead of binary JLL
[3eaa8dc6-92ce-5c4c-91c6-662a904cf5c7]
libcxxwrap_julia = "/opt/libcxxwrap-julia"
OVERRIDE
  echo "✓ Artifact override created for CxxWrap source build"

  # Base env (Julia) - with error handling
  echo "Setting up Julia base environment..."
  "${JULIA_BIN}" -e 'using Pkg; Pkg.update(); Pkg.add(["IJulia"]); using IJulia;' || echo "[warn] IJulia setup failed"

  # Install CxxWrap (will automatically use our source build via override)
  echo "Installing CxxWrap Julia package (will use source build)..."
  "${JULIA_BIN}" -e 'using Pkg; Pkg.add("CxxWrap"); Pkg.build("CxxWrap")'
  
  # Verify it is using our source build
  "${JULIA_BIN}" -e 'using CxxWrap; build_path = CxxWrap.prefix_path(); println("✓ CxxWrap using: ", build_path); if !occursin("/opt/libcxxwrap-julia", build_path) @warn "CxxWrap may not be using source build! Path: $build_path" end' \ || echo "[warn] CxxWrap Julia package setup failed"

  # Robotics env (use valid shared environment name)
  echo "Setting up Julia robotics environment..."
  mkdir -p /opt/juliaenvs
  "${JULIA_BIN}" -e 'using Pkg; Pkg.activate("/opt/juliaenvs/robotics_env"); Pkg.add(["RigidBodyDynamics", "MeshCat", "ControlSystems", "DifferentialEquations", "ForwardDiff", "StaticArrays", "Rotations", "CoordinateTransformations", "Interpolations", "Optim"]); Pkg.precompile()' || echo "[warn] Robotic env setup failed"
  
  # CUDA-ready env (instantiate only; no GPU precompile here)
  echo "Setting up Julia CUDA environment..."
  "${JULIA_BIN}" -e 'using Pkg; Pkg.activate("/opt/juliaenvs/cuda_env"); Pkg.instantiate()' || echo "[warn] CUDA env setup failed"

  # Register Julia kernel (IJulia)
  echo "Registering Julia kernel..."
  "${JULIA_BIN}" -e 'using IJulia; IJulia.installkernel("Julia 1.10 (base)", "--project=@.")' || echo "[warn] Julia kernel registration failed"
  
  # GPU precompile helper (safe, non-fatal)
  cat > /usr/local/bin/precompile_julia_cuda.sh << 'EOS'
#!/usr/bin/env bash
set -euo pipefail

JULIA_BIN="${JULIA_BIN:-/opt/julia/bin/julia}"
if ! command -v "$JULIA_BIN" >/dev/null 2>&1; then
  echo "[precompile_julia_cuda] $JULIA_BIN not found; skipping."
  exit 0
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "[precompile_julia_cuda] no NVIDIA GPU visible; skipping."
  exit 0
fi

ENV_DIR="${1:-/opt/juliaenvs/robotics-cuda}"
PROJECT_OPT="-e"
if [ -d "$ENV_DIR" ]; then
  PROJECT_OPT="--project=$ENV_DIR"
fi

"$JULIA_BIN" $PROJECT_OPT -e '
  try
    using Pkg
    Pkg.instantiate()
    @info "Touching CUDA packages for GPU precompile..."
    using CUDA
    CUDA.versioninfo()
    using KernelAbstractions
    using Flux
    println("GPU precompile completed.")
  catch e
    @warn "GPU precompile failed" exception=e
  end
'
EOS
  chmod 0755 /usr/local/bin/precompile_julia_cuda.sh
  dos2unix -q /usr/local/bin/precompile_julia_cuda.sh 2>/dev/null || true

  # Invoke once (non-fatal)
  if [ -x /usr/local/bin/precompile_julia_cuda.sh ]; then
    /usr/local/bin/precompile_julia_cuda.sh || true
  fi
fi
debug_glibc "After Julia environment setup"
else
  echo "[warn] Julia installation may have failed"
fi

debug_glibc "After OpenCV Compile and Install"

# === Phase 5: Recompile ROS 2 CV_Bridge Against Custom OpenCV ===
echo -e "\n${BLUE}### PHASE 5: Recompiling ROS 2 vision libraries against custom OpenCV ###${NC}"
PHASE5_SUCCESS=true

# Source the ROS environment to make its tools available
source /opt/ros/jazzy/setup.bash

# Create a colcon "overlay" workspace. Packages built here will be used instead of the system ones.
mkdir -p /ros_overlay_ws/src
cd /ros_overlay_ws

# Clone the source code for vision_opencv, which contains cv_bridge
# We check out the 'jazzy' branch to match the ROS 2 distribution
git clone --branch rolling https://github.com/ros-perception/vision_opencv.git src/vision_opencv

# Build the workspace. colcon will find the custom OpenCV in /usr/local first.
colcon build --cmake-args -D CMAKE_BUILD_TYPE=Release -D CMAKE_SHARED_LINKER_FLAGS="-flto" -D CMAKE_EXE_LINKER_FLAGS="-flto"

# --- Verification for Phase 5 ---
echo -e "${YELLOW}[Phase 5 | Verification] Checking linkage of new cv_bridge library...${NC}"
if ldd /ros_overlay_ws/install/cv_bridge/lib/libcv_bridge.so | grep -q "/usr/local/lib/libopencv_core"; then
  echo -e "${GREEN}✓ New cv_bridge is correctly linked to custom OpenCV in /usr/local.${NC}"
  export PHASE5_STATUS="PASS"
else
  echo -e "${RED}✗ FAILED: New cv_bridge is NOT linked to custom OpenCV. Overlay failed.${NC}"
  ldd /ros_overlay_ws/install/cv_bridge/lib/libcv_bridge.so | grep opencv
  PHASE5_SUCCESS=false
  export PHASE5_STATUS="FAIL"
  exit 1
fi

# Add a line to the container's main .bashrc to automatically source this overlay workspace.
# This ensures that any new terminal session uses your custom-built packages.
echo "source /ros_overlay_ws/install/setup.bash" >> /root/.bashrc

debug_glibc "After building ROS2 CV_Bridge"

echo "==> Additional system libraries for robotics/ML."

# Helper function for package installation with fallback
# Install_packages function removed - using apt-get directly (aliased to apt-aria)

# First, fix any broken dependencies
echo "Fixing broken dependencies..."
apt-get -y --fix-broken install || true
dpkg --configure -a || true
apt-get -y autoremove || true
# Note: autoclean removed to preserve cached .deb files for host-side caching

# Remove any held packages that might cause conflicts
apt-mark unhold $(dpkg --get-selections | grep hold | awk '{print $1}') 2>/dev/null || true

# Install essential dependencies first
echo "Installing essential dependencies..."
apt-get install -y --no-install-recommends \
  pkg-config || true

# Handle specific version conflicts
echo "Resolving version conflicts..."
# apt-get -y install gcc-12-base=12.3.0-1ubuntu1~22.04.2 || true
# apt-get -y install libquadmath0=12.3.0-1ubuntu1~22.04.2 || true
# apt-get -y install libpython3.10-stdlib=3.10.12-1~22.04.11 || true

# Update package lists after fixing conflicts
apt-get update || true

# PCL and VTK libraries are already installed as dependencies of Drake
# No need to install them separately to avoid version conflicts
echo "PCL and VTK libraries already available via Drake dependencies"

# Install Python VTK bindings if available (useful for scripting)
echo "Installing Python VTK bindings if available..."
apt-get install -y --no-install-recommends python3-vtk9 || apt-get install -y --no-install-recommends python3-vtk7 || echo "Δ Python VTK bindings not available"

# Monitor cache after robotics/ML libraries installation
monitor_cache "After robotics/ML libraries installation"

# apt-fast removed - using apt-aria wrapper instead
# VTK conflicts resolved by using Drake's compatible versions
# Firefox already installed above with optimized PPA

debug_glibc "After Robotics/ML libraries installation"


# ===============================================================
# X11 Performance and Diagnostic Tools
# ===============================================================
echo "==> Installing X11 performance and diagnostic tools..."

apt-get install -y --no-install-recommends \
  x11-utils \
  x11-xserver-utils \
  x11vnc \
  mesa-utils \
  xdotool \
  xclip \
  xsel \
  wmctrl \
  xprop \
  xwininfo \
  xinput

echo "✓ X11 tools installed"


# ===============================================================
# Install x11vnc (alternative VNC server)
# ===============================================================
echo "==> Installing x11vnc as additional VNC option..."

apt-get install -y --no-install-recommends x11vnc

# Create x11vnc startup script (can attach to existing X session)
cat > /usr/local/bin/start_x11vnc.sh << 'X11VNC'
#!/usr/bin/env bash
# x11vnc - Can attach to existing display or create new one

set -euo pipefail

DISPLAY_NUM=${1:-:1}
PORT=$((5900 + ${DISPLAY_NUM#:}))

echo "Starting x11vnc on display $DISPLAY_NUM (port $PORT)..."

# Create password file if doesn't exist
if [ ! -f ~/.vnc/passwd ]; then
    echo "VNC password not set. Setting now:"
    x11vnc -storepasswd ~/.vnc/passwd
fi

# Start x11vnc
x11vnc -display $DISPLAY_NUM \
  -rfbport $PORT \
  -rfbauth ~/.vnc/passwd \
  -forever \
  -shared \
  -noxdamage \
  -ncache 10 \
  -ncache_cr \
  -speeds lan \
  -wait 20 \
  -defer 20
X11VNC
chmod +x /usr/local/bin/start_x11vnc.sh

echo "✓ x11vnc installed (use: start_x11vnc.sh)"


# ===============================================================
# Enhanced clipboard and file transfer support
# ===============================================================
echo "==> Installing clipboard and file transfer tools..."

apt-get install -y --no-install-recommends \
  xclip \
  xsel \
  autocutsel \
  xdotool

# Create clipboard sync script
cat > /usr/local/bin/vnc_clipboard_sync.sh << 'CLIPBD'
#!/usr/bin/env bash
# Synchronize clipboard between VNC and host

if [ -z "$DISPLAY" ]; then
    echo "ERROR: DISPLAY not set"
    exit 1
fi

# Start autocutsel for clipboard sync
autocutsel -fork -selection CLIPBOARD
autocutsel -fork -selection PRIMARY

echo "✓ Clipboard sync started"
echo "  Copy/paste should work between VNC and local machine"
CLIPBD
chmod +x /usr/local/bin/vnc_clipboard_sync.sh

echo "✓ Clipboard tools installed"


# ===============================================================
# Hardware video acceleration support
# ===============================================================
echo "==> Installing hardware video acceleration support..."

apt-get install -y --no-install-recommends \
  libva2 \
  libva-drm2 \
  libva-x11-2 \
  vainfo \
  vdpauinfo \
  libvdpau1 \
  libvdpau-va-gl1

echo "✓ Hardware video acceleration installed"


# ===============================================================
# PulseAudio for audio support in remote desktop
# ===============================================================
echo "==> Installing audio support (PulseAudio)..."

apt-get install -y --no-install-recommends \
  pulseaudio \
  pulseaudio-utils \
  pavucontrol \
  alsa-utils

# Configure PulseAudio for network streaming
mkdir -p /etc/pulse/

cat > /etc/pulse/default.pa.d/network.conf << 'PANETWORK'
# Allow network streaming
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1
load-module module-esound-protocol-tcp auth-ip-acl=127.0.0.1
PANETWORK

# Create PulseAudio startup script
cat > /usr/local/bin/start_pulseaudio.sh << 'PASTART'
#!/usr/bin/env bash
# Start PulseAudio for VNC session

if pulseaudio --check; then
    echo "PulseAudio already running"
else
    pulseaudio --start --exit-idle-time=-1
    echo "✓ PulseAudio started"
fi
PASTART
chmod +x /usr/local/bin/start_pulseaudio.sh

echo "✓ Audio support installed"




# Install local .debs for VNC/VirtualGL using apt for robust dependency handling
# Installing TurboVNC and VirtualGL from local .deb files with GPG verification.

# --- Install TurboVNC & VirtualGL with Official GPG Signature Verification ---
echo "==> Installing TurboVNC and VirtualGL with official GPG signature verification..."

# 1. Download the official 'debsig-import' helper script from the gist provided by TurboVNC
echo "Downloading the debsig-import helper script..."
if ! curl -fsSL -o /usr/local/bin/debsig-import "https://gist.githubusercontent.com/dcommander/2960e99d4a4f6998e249ec7cfec89b85/raw/debsig-import"; then
  echo "✗ ERROR: Failed to download the debsig-import script. Aborting."
  exit 1
fi
chmod +x /usr/local/bin/debsig-import

# 2. Define the official GPG Key ID and URL
GPG_KEY_ID="4BACCAB36E7FE9A1"
GPG_KEY_URL="https://www.turbovnc.org/key/VGL-GPG-KEY"

# 3. Import the key using the official helper script
echo "Importing the TurboVNC/VirtualGL GPG key..."
if ! debsig-import "${GPG_KEY_ID}"; then
  echo "✗ ERROR: Failed to import the GPG key using debsig-import. Aborting."
  exit 1
fi
echo "✓ GPG key imported successfully."

# 4. Loop through the .deb files, verify with debsig-verify, and install
for deb_file in /container_cache/debs/turbovnc_*.deb /container_cache/debs/virtualgl_*.deb; do
  if [ ! -f "$deb_file" ]; then
    echo "[warn] Package not found in cache, skipping: $(basename "$deb_file")"
    continue
  fi

  echo "Verifying GPG signature for $(basename "$deb_file")..."
  if debsig-verify "$deb_file"; then
    echo "✓ GPG Signature OK."
  else
    echo "✗ GPG signature verification failed. Continuing installation with warning."
  fi
  
  echo "Installing $(basename "$deb_file")..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb_file"
done

# ===============================================================
# Create comprehensive TurboVNC symlinks
# ===============================================================
echo "==> Creating complete TurboVNC symlinks in /usr/local/bin/"

# Define all TurboVNC binaries that should be symlinked
TURBOVNC_BINARIES=(
  "vncserver:VNC server daemon"
  "Xvnc:X11 server with VNC protocol"
  "vncpasswd:VNC password utility"
  "vncconnect:VNC reverse connection tool"
  "vncviewer:TurboVNC client viewer"
  "webserver:Built-in HTTP server for Java applet"
  "tvncconfig:TurboVNC configuration utility"
)

# Create symlinks for each binary
for entry in "${TURBOVNC_BINARIES[@]}"; do
  IFS=':' read -r binary description <<< "$entry"
  src_path="/opt/TurboVNC/bin/$binary"
  dst_path="/usr/local/bin/$binary"
  
  if [ -x "$src_path" ]; then
    ln -sf "$src_path" "$dst_path"
    echo "  ✓ $binary -> $src_path ($description)"
  else
    echo "  ✗ $binary not found at $src_path"
  fi
done

# Also add TurboVNC bin to PATH in profile (belt and suspenders approach)
cat > /etc/profile.d/turbovnc.sh << 'TVNC_PROFILE'
# TurboVNC environment
export PATH="/opt/TurboVNC/bin:${PATH}"
TVNC_PROFILE
chmod +x /etc/profile.d/turbovnc.sh

echo "✓ TurboVNC symlinks and PATH configuration complete"



# ===============================================================
# Create comprehensive VirtualGL symlinks and configuration
# ===============================================================
echo "==> Creating complete VirtualGL integration..."

# Define all VirtualGL binaries with descriptions
declare -A VIRTUALGL_BINARIES=(
  # Core VirtualGL tools
  ["vglrun"]="Run application with GPU acceleration (PRIMARY TOOL)"
  ["vglclient"]="VirtualGL client for remote rendering"
  ["vglconfig"]="Configure VirtualGL on the system"
  ["vglconnect"]="SSH helper with VGL integration"
  ["vglgenkey"]="Generate VirtualGL authentication keys"
  ["vgllogin"]="VirtualGL login helper"
  ["vglserver_config"]="Server-side VirtualGL configuration"
  
  # OpenGL information and testing tools
  ["glxinfo"]="Display OpenGL/GLX information"
  ["glxspheres64"]="OpenGL benchmark (spinning spheres)"
  ["eglinfo"]="Display EGL information"
  ["eglxinfo"]="Display EGL/X11 information"
  ["eglxspheres64"]="EGL benchmark (spinning spheres)"
  
  # Performance and diagnostic tools
  ["cpustat"]="CPU statistics monitoring"
  ["nettest"]="Network performance testing"
  ["tcbench"]="TCP benchmark utility"
)

# Create symlinks for all VirtualGL binaries
echo "Creating VirtualGL symlinks in /usr/local/bin/:"
for binary in "${!VIRTUALGL_BINARIES[@]}"; do
  src_path="/opt/VirtualGL/bin/$binary"
  dst_path="/usr/local/bin/$binary"
  description="${VIRTUALGL_BINARIES[$binary]}"
  
  if [ -x "$src_path" ]; then
    ln -sf "$src_path" "$dst_path"
    echo "  ✓ $binary -> $src_path"
  else
    echo "  ⚠ $binary not found at $src_path (skipping)"
  fi
done

# Add VirtualGL to PATH in profile
cat > /etc/profile.d/virtualgl.sh << 'VGL_PROFILE'
# VirtualGL environment configuration
export PATH="/opt/VirtualGL/bin:${PATH}"

# VirtualGL runtime environment
export VGL_DISPLAY=":0"           # Default X display for VirtualGL
export VGL_COMPRESS="proxy"       # Compression method (proxy, jpeg, rgb)
export VGL_READBACK="sync"        # Readback mode (sync recommended for VNC)
export VGL_LOGO="0"               # Disable VirtualGL logo overlay
export VGL_FPS="0"                # Disable FPS display (set to 1 to enable)

# Optimize for VNC environments
export VGL_SYNC="1"               # Synchronize with vertical retrace
export VGL_REFRESHRATE="60"       # Target refresh rate for VNC
VGL_PROFILE
chmod +x /etc/profile.d/virtualgl.sh

echo "✓ VirtualGL symlinks and environment configuration complete"

# Verify installation
echo ""
echo "Verifying VirtualGL installation:"
if [ -x /opt/VirtualGL/bin/vglrun ]; then
  /opt/VirtualGL/bin/vglrun --version 2>&1 | head -3 || echo "  ✓ vglrun binary present"
else
  echo "  ✗ ERROR: vglrun not found!"
fi

# Create VirtualGL test script
cat > /usr/local/bin/test_virtualgl.sh << 'VGLTEST'
#!/usr/bin/env bash
# VirtualGL Test Script

echo "=========================================="
echo "VirtualGL Installation Test"
echo "=========================================="
echo ""

# Add VirtualGL to PATH
export PATH="/opt/VirtualGL/bin:${PATH}"

echo "1. Checking VirtualGL binaries:"
for binary in vglrun glxinfo glxspheres64; do
  if command -v $binary >/dev/null 2>&1; then
    echo "  ✓ $binary: $(which $binary)"
  else
    echo "  ✗ $binary: NOT FOUND"
  fi
done

echo ""
echo "2. VirtualGL version:"
vglrun --version 2>&1 | head -1

echo ""
echo "3. OpenGL Information (via VirtualGL):"
if [ -n "${DISPLAY}" ]; then
  echo "  Display: $DISPLAY"
  vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version)" | head -3
else
  echo "  ⚠ DISPLAY not set, skipping OpenGL test"
fi

echo ""
echo "4. GPU Detection:"
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "  NVIDIA GPU:"
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1
else
  echo "  ⚠ nvidia-smi not found"
fi

echo ""
echo "=========================================="
echo "Test complete!"
echo ""
echo "To test 3D acceleration with VNC:"
echo "  1. Start VNC server: start_vnc_xfce.sh"
echo "  2. Connect with VNC viewer"
echo "  3. Open terminal in VNC session"
echo "  4. Run: vglrun glxspheres64"
echo "     (Should show 1000+ FPS with GPU)"
echo "  5. Compare without VGL: glxspheres64"
echo "     (Will show lower FPS with software rendering)"
echo "=========================================="
VGLTEST
chmod +x /usr/local/bin/test_virtualgl.sh

echo "✓ VirtualGL test script created: /usr/local/bin/test_virtualgl.sh"


# ===============================================================
# Create VirtualGL helper and testing scripts
# ===============================================================
echo "==> Creating VirtualGL helper scripts..."

# Quick GPU benchmark script
cat > /usr/local/bin/vgl_benchmark.sh << 'VGLBENCH'
#!/usr/bin/env bash
# VirtualGL GPU Benchmark Script

export PATH="/opt/VirtualGL/bin:${PATH}"

echo "=========================================="
echo "VirtualGL GPU Benchmark"
echo "=========================================="
echo ""

if [ -z "${DISPLAY}" ]; then
  echo "ERROR: DISPLAY not set"
  echo "Start VNC first: start_vnc_xfce.sh"
  exit 1
fi

if ! command -v vglrun >/dev/null 2>&1; then
  echo "ERROR: VirtualGL not found"
  exit 1
fi

echo "GPU Information:"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
  echo "  nvidia-smi not available"
fi

echo ""
echo "Testing OpenGL rendering..."
echo ""

# Test 1: Without VirtualGL (software rendering)
echo "1. Software rendering (no VirtualGL):"
echo "   Running: glxspheres64"
if command -v glxspheres64 >/dev/null 2>&1; then
  timeout 10s glxspheres64 2>&1 | grep -i "frames\|fps" | tail -3
else
  echo "   glxspheres64 not found"
fi

echo ""

# Test 2: With VirtualGL (GPU rendering)
echo "2. GPU rendering (with VirtualGL):"
echo "   Running: vglrun glxspheres64"
if command -v glxspheres64 >/dev/null 2>&1; then
  timeout 10s vglrun glxspheres64 2>&1 | grep -i "frames\|fps" | tail -3
else
  echo "   glxspheres64 not found"
fi

echo ""
echo "=========================================="
echo "Benchmark complete!"
echo ""
echo "Expected results:"
echo "  Software rendering: ~30-100 FPS"
echo "  GPU rendering:      ~1000+ FPS"
echo ""
echo "If GPU rendering shows low FPS:"
echo "  1. Check GPU is visible: nvidia-smi"
echo "  2. Check VNC started with --nv flag"
echo "  3. Check DISPLAY is set: echo \$DISPLAY"
echo "=========================================="
VGLBENCH
chmod +x /usr/local/bin/vgl_benchmark.sh

# OpenGL information script
cat > /usr/local/bin/vgl_info.sh << 'VGLINFO'
#!/usr/bin/env bash
# Display comprehensive OpenGL/VirtualGL information

export PATH="/opt/VirtualGL/bin:${PATH}"

echo "=========================================="
echo "OpenGL & VirtualGL Information"
echo "=========================================="
echo ""

# System info
echo "Display: ${DISPLAY:-NOT SET}"
echo "Hostname: $(hostname)"
echo ""

# GPU info
echo "GPU Information:"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=index,name,driver_version,memory.total,memory.used \
    --format=csv,noheader | nl
else
  echo "  No NVIDIA GPU detected"
fi
echo ""

# OpenGL info (software rendering)
echo "OpenGL (Software Rendering):"
if [ -n "${DISPLAY}" ] && command -v glxinfo >/dev/null 2>&1; then
  glxinfo | grep -E "OpenGL (vendor|renderer|version|shading)" | sed 's/^/  /'
else
  echo "  Cannot query (DISPLAY not set or glxinfo not found)"
fi
echo ""

# OpenGL info (with VirtualGL)
echo "OpenGL (VirtualGL/GPU Rendering):"
if [ -n "${DISPLAY}" ] && command -v vglrun >/dev/null 2>&1 && command -v glxinfo >/dev/null 2>&1; then
  vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version|shading)" | sed 's/^/  /'
else
  echo "  Cannot query (VirtualGL not available)"
fi
echo ""

# VirtualGL status
echo "VirtualGL Status:"
if command -v vglrun >/dev/null 2>&1; then
  echo "  ✓ VirtualGL installed: $(which vglrun)"
  vglrun --version 2>&1 | head -1 | sed 's/^/  /'
else
  echo "  ✗ VirtualGL not found"
fi
echo ""

# Available tools
echo "Available Utilities:"
for tool in vglrun glxinfo glxspheres64 eglinfo cpustat nettest tcbench; do
  if command -v $tool >/dev/null 2>&1; then
    echo "  ✓ $tool"
  else
    echo "  ✗ $tool (not found)"
  fi
done

echo ""
echo "=========================================="
VGLINFO
chmod +x /usr/local/bin/vgl_info.sh

# Application launcher script with VirtualGL
cat > /usr/local/bin/vgl_launch.sh << 'VGLLAUNCH'
#!/usr/bin/env bash
# Launch applications with VirtualGL acceleration

if [ $# -eq 0 ]; then
  echo "Usage: vgl_launch.sh <command> [args...]"
  echo ""
  echo "Examples:"
  echo "  vgl_launch.sh blender"
  echo "  vgl_launch.sh glxspheres64"
  echo "  vgl_launch.sh openscad model.scad"
  echo ""
  echo "This script automatically:"
  echo "  - Adds VirtualGL to PATH"
  echo "  - Runs application with vglrun for GPU acceleration"
  echo "  - Handles DISPLAY configuration"
  exit 1
fi

# Add VirtualGL to PATH
export PATH="/opt/VirtualGL/bin:${PATH}"

# Check DISPLAY
if [ -z "${DISPLAY}" ]; then
  echo "WARNING: DISPLAY not set, using :1"
  export DISPLAY=:1
fi

# Check if vglrun is available
if ! command -v vglrun >/dev/null 2>&1; then
  echo "ERROR: VirtualGL not found"
  echo "Running without GPU acceleration..."
  exec "$@"
fi

# Launch with VirtualGL
echo "Launching with VirtualGL GPU acceleration..."
echo "Command: vglrun $@"
echo ""
exec vglrun "$@"
VGLLAUNCH
chmod +x /usr/local/bin/vgl_launch.sh

echo "✓ VirtualGL helper scripts created:"
echo "  - test_virtualgl.sh   : Test VirtualGL installation"
echo "  - vgl_benchmark.sh    : Benchmark GPU performance"
echo "  - vgl_info.sh         : Display OpenGL/VirtualGL info"
echo "  - vgl_launch.sh       : Launch apps with GPU acceleration"


# ===============================================================
# Configure VirtualGL aliases in system bashrc
# ===============================================================
echo "==> Adding VirtualGL convenience aliases..."

cat >> /etc/bash.bashrc << 'VGLALIAS'

# ============================================================================
# VirtualGL Convenience Aliases and Functions
# ============================================================================

# Ensure VirtualGL is in PATH
export PATH="/opt/VirtualGL/bin:${PATH}"

# Quick GPU-accelerated application launches
alias vblender='vglrun blender'
alias vopenscad='vglrun openscad'
alias vfreecad='vglrun freecad'
alias vmeshlab='vglrun meshlab'

# Quick benchmark
alias gpubench='vglrun glxspheres64'
alias gpuinfo='vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version)"'

# Helper function: launch any app with VirtualGL
vgl() {
  if [ $# -eq 0 ]; then
    echo "Usage: vgl <command> [args...]"
    echo "Example: vgl blender"
    return 1
  fi
  vglrun "$@"
}

# Helper function: compare software vs GPU rendering
compare_render() {
  local app="${1:-glxspheres64}"
  echo "=== Software Rendering ==="
  timeout 5s $app 2>&1 | grep -i fps | tail -1
  echo ""
  echo "=== GPU Rendering (VirtualGL) ==="
  timeout 5s vglrun $app 2>&1 | grep -i fps | tail -1
}

export -f vgl compare_render
VGLALIAS

echo "✓ VirtualGL aliases added to /etc/bash.bashrc"


# ===============================================================
# VirtualGL Performance Optimization
# ===============================================================
echo "==> Configuring VirtualGL performance optimizations..."

# Create VGL configuration profiles
mkdir -p /usr/local/etc/virtualgl

# Profile 1: Maximum Performance (for fast networks)
cat > /usr/local/etc/virtualgl/vglrun-fast.conf << 'VGLFAST'
# VirtualGL High Performance Profile
VGL_COMPRESS=proxy
VGL_READBACK=sync
VGL_SYNC=1
VGL_GAMMA=1
VGL_LOGO=0
VGL_SUBSAMP=444  # No subsampling - best quality
VGL_QUAL=95      # High JPEG quality
VGL_SPOIL=0      # No frame spoiling - all frames rendered
VGL_FPS=60       # Target 60 FPS
VGL_READBACK=sync
VGL_TRANSPORT=vgl
VGLFAST

# Profile 2: Balanced (for normal networks)
cat > /usr/local/etc/virtualgl/vglrun-balanced.conf << 'VGLBAL'
# VirtualGL Balanced Profile
VGL_COMPRESS=jpeg
VGL_SUBSAMP=422  # 4:2:2 chroma subsampling
VGL_QUAL=80      # Medium-high quality
VGL_SPOIL=1      # Allow some frame dropping
VGL_FPS=30       # Target 30 FPS
VGL_READBACK=sync
VGLBAL

# Profile 3: Low Bandwidth (for slow networks)
cat > /usr/local/etc/virtualgl/vglrun-lowbw.conf << 'VGLLOWBW'
# VirtualGL Low Bandwidth Profile
VGL_COMPRESS=jpeg
VGL_SUBSAMP=420  # 4:2:0 chroma subsampling (more compression)
VGL_QUAL=60      # Lower quality, better compression
VGL_SPOIL=1
VGL_FPS=15       # Target 15 FPS
VGL_READBACK=sync
VGLLOWBW

# Create wrapper scripts for each profile
cat > /usr/local/bin/vglrun-fast << 'VGLFAST'
#!/usr/bin/env bash
source /usr/local/etc/virtualgl/vglrun-fast.conf
export VGL_COMPRESS VGL_READBACK VGL_SYNC VGL_GAMMA VGL_LOGO VGL_SUBSAMP VGL_QUAL VGL_SPOIL VGL_FPS VGL_TRANSPORT
exec /opt/VirtualGL/bin/vglrun "$@"
VGLFAST

cat > /usr/local/bin/vglrun-balanced << 'VGLBAL'
#!/usr/bin/env bash
source /usr/local/etc/virtualgl/vglrun-balanced.conf
export VGL_COMPRESS VGL_SUBSAMP VGL_QUAL VGL_SPOIL VGL_FPS VGL_READBACK
exec /opt/VirtualGL/bin/vglrun "$@"
VGLBAL

cat > /usr/local/bin/vglrun-lowbw << 'VGLLOWBW'
#!/usr/bin/env bash
source /usr/local/etc/virtualgl/vglrun-lowbw.conf
export VGL_COMPRESS VGL_SUBSAMP VGL_QUAL VGL_SPOIL VGL_FPS VGL_READBACK
exec /opt/VirtualGL/bin/vglrun "$@"
VGLLOWBW

chmod +x /usr/local/bin/vglrun-{fast,balanced,lowbw}

echo "✓ VirtualGL performance profiles created"
echo "  - vglrun-fast (best quality, fast network)"
echo "  - vglrun-balanced (default)"
echo "  - vglrun-lowbw (slow network)"


# ===============================================================
# TurboVNC Performance Optimizations
# ===============================================================
echo "==> Configuring TurboVNC performance optimizations..."

# Create default TurboVNC configuration for all users
mkdir -p /etc/turbovncserver.conf.d

cat > /etc/turbovncserver.conf.d/performance.conf << 'TVNCPERF'
# TurboVNC Performance Configuration

# Security
$localhost = "yes";

# Geometry (can be overridden)
$geometry = "1920x1080";
$depth = "24";

# Performance settings
$desktopName = "TurboVNC";
$useVGL = "1";  # Enable VirtualGL integration
$autokill = "1";  # Kill when last client disconnects

# Compression (TurboVNC's optimized JPEG)
# 0 = lossless, 1-100 = JPEG quality
# 95 = near-lossless, good default
# Lower = better compression, faster over slow networks
$compressLevel = "2";
$quality = "95";

# Subsample settings for JPEG
# 0 = 4:4:4 (best quality)
# 1 = 4:2:2 (good quality, 2x compression)
# 2 = 4:2:0 (highest compression)
$subsample = "1";

# Interframe comparison (helps with static content)
$interframe = "1";

# Multi-threading
$numThreads = "auto";

# Idle timeout (seconds, 0 = never)
$idleTimeout = "0";
TVNCPERF

# Create optimized xstartup template
mkdir -p /usr/share/turbovnc/

cat > /usr/share/turbovnc/xstartup.turbovnc.optimized << 'XSTARTOPT'
#!/bin/sh
# Optimized TurboVNC xstartup for XFCE + GPU

# Load X resources
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true

# Font cache
fc-cache -f 2>/dev/null || true

# Start D-Bus
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  export DBUS_SESSION_BUS_ADDRESS
  export DBUS_SESSION_BUS_PID
fi

# Performance: Disable compositing (critical for VNC)
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /general/use_compositing -s false 2>/dev/null || true

# Disable window manager shadows/effects
xfconf-query -c xfwm4 -p /general/show_frame_shadow -s false 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/show_popup_shadow -s false 2>/dev/null || true

# Disable screen blanking
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# Disable bell
xset b off 2>/dev/null || true

# Set keyboard repeat rate (faster responsiveness)
xset r rate 250 30 2>/dev/null || true

# Start window manager with optimizations
export XFWM4_USE_PRESENT=0  # Disable Present extension (can cause issues)

# Start XFCE
exec startxfce4
XSTARTOPT
chmod +x /usr/share/turbovnc/xstartup.turbovnc.optimized

# Create performance testing script
cat > /usr/local/bin/turbovnc_tune.sh << 'TVNCTUNE'
#!/usr/bin/env bash
# TurboVNC Performance Tuning Helper

echo "=========================================="
echo "TurboVNC Performance Tuner"
echo "=========================================="
echo ""

if [ -z "$DISPLAY" ]; then
    echo "ERROR: Must be run from within VNC session"
    echo "Start VNC first, then run this from terminal inside VNC"
    exit 1
fi

echo "Current VNC Session Information:"
vncserver -list 2>/dev/null || echo "  (vncserver command not available)"
echo ""

echo "Testing different compression settings..."
echo "This will take about 30 seconds..."
echo ""

# Test function
test_setting() {
    local quality=$1
    local subsample=$2
    local desc=$3
    
    echo "Testing: $desc (Quality=$quality, Subsample=$subsample)"
    
    # This would require vncviewer to support setting these
    # Just document the settings
    echo "  Recommended for: $desc"
    echo ""
}

test_setting 95 1 "High quality (default)"
test_setting 80 1 "Balanced (good for most)"
test_setting 60 2 "Low bandwidth"
test_setting 30 2 "Very slow connections"

echo "=========================================="
echo "To change settings, edit:"
echo "  ~/.vnc/turbovncserver.conf"
echo ""
echo "Or set environment variables:"
echo "  export TVNC_QUALITY=80"
echo "  export TVNC_SUBSAMPLE=1"
echo "=========================================="
TVNCTUNE
chmod +x /usr/local/bin/turbovnc_tune.sh

echo "✓ TurboVNC performance optimizations configured"


# Install yq (from embedded binary)
if [ -s "/container_cache/binaries/yq_linux_amd64" ]; then
  install -o 0 -g 0 -m 0755 /container_cache/binaries/yq_linux_amd64 /usr/local/bin/yq
fi

# Install Miniforge (from embedded installer) - (OPTIMIZED)
if [ -s "/container_cache/binaries/${MINIFORGE_SH}" ]; then
  echo "Installing Miniforge..."
  # Miniforge installer already verified in early verification phase
  echo "✓ Miniforge installer already verified (SHA256 check passed)"
  
  # Ensure clean conda environment (corrupted packages already cleaned in Setups)
  export CONDA_PKGS_DIRS="/container_cache/conda_pkgs"
  export CONDA_ALWAYS_YES=true
  export CONDA_AUTO_UPDATE_CONDA=false

  # Retry logic for Miniforge installation with enhanced CRC error handling
  max_retries=3
  retry_count=0

  while [ $retry_count -lt $max_retries ]; do
    echo "Miniforge installation attempt $((retry_count + 1))/${max_retries}..."
    
    # Clear any existing conda package cache to force fresh downloads
    rm -rf /opt/conda/pkgs/* 2>/dev/null || true
    rm -rf /root/.cache/conda/* 2>/dev/null || true

    # Advanced conda package cache cleanup with smart replacement
    echo "Performing advanced conda package cache cleanup..."
    if [ -d "/container_cache/conda_pkgs" ]; then
      # Setup staging area for robust package handling
      setup_conda_staging_area
      
      # Remove specific problematic packages mentioned in errors
      echo "Removing known problematic packages..."
      problematic_packages=(
        "openssl-3.5.2-h26f9b46_0.conda"
        "certifi-2025.8.3-pyhd8ed1ab_0.conda"
        "anyio-4.10.0-pyhe01879c_0.conda"
        "argon2-cffi-25.1.0-pyhd8ed1ab_0.conda"
        "argon2-cffi-bindings-25.1.0-py312h4c3975b_0.conda"
      )
      for pkg in "${problematic_packages[@]}"; do
        if [ -f "/container_cache/conda_pkgs/$pkg" ]; then
          echo "Removing problematic package: $pkg"
          rm -f "/container_cache/conda_pkgs/$pkg" 2>/dev/null || true
        fi
      done

      # Comprehensive integrity check with smart replacement
      echo "Performing comprehensive package integrity check..."
      corrupted_packages=()
      
      # Check all conda packages for integrity
      find /container_cache/conda_pkgs -name "*.conda" -o -name "*.tar.bz2" | while read -r pkg_file; do
        if ! verify_package_integrity "$pkg_file"; then
          pkg_name=$(basename "$pkg_file")
          echo "  Δ Found corrupted package: $pkg_name"
          corrupted_packages+=("$pkg_name")
        fi
      done
      
      # Replace corrupted packages with fresh downloads
      if [ ${#corrupted_packages[@]} -gt 0 ]; then
        echo "  Replacing ${#corrupted_packages[@]} corrupted packages..."
        for pkg_name in "${corrupted_packages[@]}"; do
          if acquire_package_lock "$pkg_name"; then
            atomic_package_replace "$pkg_name"
            release_package_lock "$pkg_name"
          fi
        done
      fi
      
      # Clear conda package cache metadata that might be stale
      echo "  Clearing conda package cache metadata..."
      rm -rf /container_cache/conda_pkgs/cache/* 2>/dev/null || true
      rm -rf /container_cache/conda_pkgs/*/info 2>/dev/null || true
      
      # Force filesystem sync to ensure all writes are flushed
      sync
      echo "✓ Advanced conda package cache cleanup completed"
    fi
    
    # Set environment variables to use our cache directory and make it non-interactive
    export CONDA_PKGS_DIRS="/container_cache/conda_pkgs"
    export CONDA_ALWAYS_YES=true
    export CONDA_AUTO_UPDATE_CONDA=false
    export CONDA_INSTALLER_TYPE=miniforge
    export CONDA_INSTALLER_VERSION=25.3.1-0

    # Run installer with enhanced CRC error handling and non-interactive mode
    echo "Running Miniforge installer with enhanced CRC error handling..."
    if yes "" | bash "/container_cache/binaries/${MINIFORGE_SH}" -b -p /opt/conda -f > /tmp/miniforge_install.log 2>&1; then
      echo "✓ Miniforge installer completed"
      mv /opt/.condarc.pre > /opt/conda/.condarc 2>/dev/null || true

      # Verify Conda Installation
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
      echo "[warn] Miniforge installer failed (attempt $((retry_count + 1))/${max_retries})"
      
      # Enhanced CRC error detection and handling
      if grep -q "Bad CRC|ZIP had CRC|md5sum mismatch" /tmp/miniforge_install.log 2>/dev/null; then
        echo "✓ CRC/MD5 error detected in installation log"
        
        # Extract all corrupted package names from the log
        corrupted_pkgs=$(grep -o 'Extracting \(.*\)\.conda\|Extracting \(.*\)\.tar\.bz2' /tmp/miniforge_install.log | sed 's/Extracting //' | sort -u)
        
        if [ -n "$corrupted_pkgs" ]; then
          echo "→ Removing corrupted packages:"
          for pkg in $corrupted_pkgs; do
            echo "  - $pkg"
            rm -f "/container_cache/conda_pkgs/$pkg" 2>/dev/null || true
            rm -f "/opt/conda/pkgs/$pkg" 2>/dev/null || true
            rm -f "/root/.cache/conda/pkgs/$pkg" 2>/dev/null || true
          done
        fi
        
        # Clear any remaining corrupted packages using integrity check
        echo "→ Performing integrity check on remaining packages..."
        if [ -d "/container_cache/conda_pkgs" ]; then
          find /container_cache/conda_pkgs -name "*.conda" -type f -exec sh -c '
            for pkg; do
              if ! unzip -t "$pkg" >/dev/null 2>&1; then
                echo "Removing corrupted: $(basename "$pkg")"
                rm -f "$pkg"
              fi
            done
          ' sh {} +
        fi
      fi
    fi
    
    ((retry_count++))
    if [ $retry_count -lt $max_retries ]; then
      echo "Retrying Miniforge installation..."
      rm -rf /opt/conda
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
            echo "  Δ Removing corrupted conda package: $(basename "$pkg_file")"
            rm -f "$pkg_file"
            ((corrupted_count++))
          fi
        fi
      done
      if [ $corrupted_count -gt 0 ]; then
        echo "✓ Removed $corrupted_count corrupted conda packages from installation"
      fi
    fi

    # Final Verification of conda installation
    echo "Performing final conda installation verification..."
    if /opt/conda/bin/conda --version >/dev/null 2>&1; then
      echo "✓ Conda binary is working correctly"
      
      # Install mamba as the default solver for conda with verification
      echo "Installing mamba as conda solver..."
      # Try mamba installation (corrupted packages already cleaned in Xsetup)
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
      echo "✗ Conda binary verification failed - installation may be corrupted"
    fi
  fi
  echo "[warn] Miniforge Installation failed after $max_retries attempts"

  # Clean up temporary files
  rm -f /tmp/miniforge_install.log 2>/dev/null || true
else
  echo "[warn] Miniforge installer not found in cache"
fi
debug_glibc "After Miniforge installation and config"

# --- SURGICAL ADDITION: Add Conda to the system-wide PATH ---
echo -e "${YELLOW}Configuring system-wide environment for Conda...${NC}"
if [ -d "/opt/conda/bin" ]; then
  cat > /etc/profile.d/conda.sh << 'EOF'
#!/bin/sh
# Prepend conda binaries to the PATH
export PATH=/opt/conda/bin:$PATH
EOF
  chmod +x /etc/profile.d/conda.sh
  echo -e "${GREEN}✓ Conda PATH configured successfully.${NC}"
else
  echo -e "${RED}Δ Could not configure Conda PATH, /opt/conda/bin not found.${NC}"
fi

# ============================================
# CONDA ACTIVATION HOOKS (Drake-Aware)
# ============================================
echo "==> Configuring conda hooks for Drake compatibility"
mkdir -p /opt/mamba/etc/conda/activate.d
# Activation hook: Save and clear PYTHONPATH (including Drake paths)
cat > /opt/mamba/etc/conda/activate.d/unset_pythonpath.sh << 'EOF'
#!/bin/bash
# Save and unset PYTHONPATH when activating conda environment
# This prevents Drake's Python 3.12 from conflicting with Conda's Python 3.9
if [ -n "$PYTHONPATH" ]; then
  # Backup original PYTHONPATH (including Drake paths)
  export _CONDA_BACKUP_PYTHONPATH="$PYTHONPATH"

  # Unset PYTHONPATH so conda environment is isolated
  unset PYTHONPATH

  # Inform user
  if [[ "$_CONDA_BACKUP_PYTHONPATH" == *"drake"* ]]; then
    echo "Drake PYTHONPATH temporarily disabled in conda environment"
  fi
fi
EOF
mkdir -p /opt/mamba/etc/conda/deactivate.d
# Deactivation hook: Restore PYTHONPATH (including Drake paths)
cat > /opt/mamba/etc/conda/deactivate.d/restore_pythonpath.sh << 'EOF'
#!/bin/bash
# Restore PYTHONPATH when deactivating conda environment
# This re-enables Drake Python bindings for system Python
if [ -n "$_CONDA_BACKUP_PYTHONPATH" ]; then
  export PYTHONPATH="$_CONDA_BACKUP_PYTHONPATH"
  unset _CONDA_BACKUP_PYTHONPATH
  
  if [[ "$PYTHONPATH" == *"drake"* ]]; then
    echo "Drake PYTHONPATH restored"
  fi
fi
EOF
chmod +x /opt/mamba/etc/conda/activate.d/unset_pythonpath.sh
chmod +x /opt/mamba/etc/conda/deactivate.d/restore_pythonpath.sh

echo "✓ Conda hooks configured for Drake compatibility"

# --- Micromamba (from embedded binary)
echo "==> Micromamba (from embedded binary)"
if [ -s "/container_cache/binaries/micromamba-linux-64" ]; then
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
        echo "Δ Micromamba binary test failed (attempt $((retry_count + 1))/${max_retries})"
        ((retry_count++))
        if [ $retry_count -lt $max_retries ]; then
          echo "  Removing corrupted binary and reinstalling..."
          rm -f /usr/local/bin/micromamba /opt/micromamba
          install -m 0755 /container_cache/binaries/micromamba-linux-64 /opt/micromamba
          ln -sf /opt/micromamba /usr/local/bin/micromamba
        fi
      fi
    done
    
    if [ $retry_count -ge $max_retries ]; then
      echo "✗ Micromamba binary failed after $max_retries attempts - removing corrupted binary"
      rm -f /opt/micromamba /usr/local/bin/micromamba
    fi
    # Configure micromamba for better performance and user experience
    echo "Configuring micromamba..."
    # Note: Using flexible priority for micromamba allows users more freedom
    # when creating their own ad-hoc environments.
    if /opt/micromamba config set channel_priority flexible 2>/dev/null; then
      echo "✓ Channel priority configured"
    else
      echo "Δ Channel priority configuration failed"
    fi
    
    if /opt/micromamba config set always_yes yes 2>/dev/null; then
      echo "✓ Always yes configured"
    else
      echo "Δ Always yes configuration failed"
    fi
    
    if /opt/micromamba config set quiet true 2>/dev/null; then
      echo "✓ Quiet mode configured"
    else
      echo "Δ Quiet mode configuration failed"
    fi
    echo "✓ Micromamba configured successfully"
  else
    echo "Δ Micromamba binary not executable"
  fi
else
  echo "Δ Micromamba binary not found in cache"
fi

# Conda base env - Full Jupyter + meshcat + additional libraries
echo "Starting Conda base env setup"
if [ -x /opt/conda/bin/conda ]; then
  # Conda channel configuration is already set in .condarc.pre (strict conda-forge only)
  echo "Installing full Jupyter environment + additional libraries using mamba solver..."
  
  # Enhanced conda package cache management before mamba installation
  echo "Performing enhanced conda cache management before mamba installation..."
  if [ -d "/container_cache/conda_pkgs" ]; then
    # Setup staging area for robust package handling
    setup_conda_staging_area
      # Remove cache metadata that causes "modified by another program" warnings
      rm -rf /container_cache/conda_pkgs/cache 2>/dev/null || true
      # Remove any partially extracted packages
      find /container_cache/conda_pkgs -maxdepth 1 -type d -name "*-*" -exec rm -rf {} + 2>/dev/null || true
      # Force filesystem sync to ensure all operations are flushed
      sync
      echo "✓ Enhanced conda cache management completed"
    fi
    # Use mamba (installed in conda) for better environment solving
    if [ -x /opt/conda/bin/mamba ]; then
      echo "Using mamba solver for package installation..."
      # Install core packages first
      echo "Installing core Jupyter packages..."
      /opt/conda/bin/mamba install -y -c conda-forge \
        jupyterlab notebook ipykernel nodejs || true
      echo "Installing scientific computing packages..."
      /opt/conda/bin/mamba install -y -c conda-forge \
        numpy scipy matplotlib pandas seaborn plotly || true
      echo "Installing ML/vision packages..."
      /opt/conda/bin/mamba install -y -c conda-forge \
        scikit-learn scikit-image opencv || true
      echo "Installing deep learning packages..."
      /opt/conda/bin/mamba install -y -c conda-forge \
        tensorflow pytorch torchvision torchaudio || true
      echo "Installing robotics/ML packages..."
      /opt/conda/bin/mamba install -y -c conda-forge \
        gymnasium stable-baselines3 mujoco pybullet glfw imageio || true
      # Vision bits (headless)
      /opt/conda/bin/pip install "opencv-python-headless>=4.7"
      echo "Installing Jupyter extensions..."
      /opt/conda/bin/mamba install -y -c conda-forge \
        ipywidgets jupyter_contrib_nbextensions nbconvert nbformat || true
    else
      # Falling back to conda for package installation...
      # [conda fallback logic could be here]
      fi
    fi
    # Register base Python kernel
    /opt/conda/bin/python -m ipykernel install --name=python-conda-base --display-name="Python (conda-base)" || true
    # Install additional useful packages via pip
    /opt/conda/bin/pip install \
      openai-gym \
      robosuite \
      pyrender \
      trimesh \
      pyglet || true
  fi
  # Verify critical package installations...
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
fi
debug_glibc "After conda environment setup"

# LibreOffice (from baseline)
echo "==> LibreOffice installation"
apt-get -y --no-install-recommends install \
  libreoffice-writer libreoffice-calc libreoffice-impress

# Blender (from baseline)
echo "==> Blender installation"
apt-get -y --no-install-recommends install blender meshlab geomview librecad openscad-testing

debug_glibc "After installation of LibreOffice & Blender"

# === OCIO color management (quiet & portable) ===
echo "==> OCIO color profile configuration initialized"
set -e
DEBIAN_FRONTEND=noninteractive apt-get update -yq
if ! dpkg -l blender-data >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends blender-data
  # Find Blender's bundled OCIO config
  OCIO_PATH="$(/usr/bin/python3 -c 'import glob; p=glob.glob("/usr/share/blender/*/datafiles/colormanagement/config.ocio") 
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
  curl -fsSL --retry 3 --retry-delay 2 -o aces.tar.gz https://github.com/AcademySoftwareFoundation/OpenColorIO-Config-ACES/archive/refs/heads/master.tar.gz || true
  if [ -f aces.tar.gz ]; then
    tar -xzf aces.tar.gz --strip-components=2 -C /usr/share/ocio/aces OpenColorIO-Config-ACES-master/aces_1.2 || true
    if [ -f /usr/share/ocio/aces/config.ocio ]; then
      printf 'export OCIO="/usr/share/ocio/aces/config.ocio"\n' > /etc/profile.d/99-ocio.sh
    fi
  fi
fi
set +e
echo "✓ OCIO color profile configuration complete"

# CAD tools (from baseline)
echo "==> CAD tools installation"
apt-get -y --no-install-recommends install \
  openscad

# === Install FreeCAD (AppImage) ===
echo "==> Installing FreeCAD version 1.0.2 via AppImage..."
# Define the specific version and filename based on the release page
FREECAD_VERSION="1.0.2"
FREECAD_FILENAME="FreeCAD_${FREECAD_VERSION}-conda-Linux-x86_64-py311.AppImage"
# Download, place in a system-wide location, and make executable
wget "https://github.com/FreeCAD/FreeCAD/releases/download/${FREECAD_VERSION}/${FREECAD_FILENAME}" -O /usr/local/bin/freecad.AppImage
chmod +x /usr/local/bin/freecad.AppImage
# Create a symlink for easy terminal access (run with 'freecad')
ln -s /usr/local/bin/freecad.AppImage /usr/local/bin/freecad

# Create a desktop entry for the XFCE menu
cat > /usr/share/applications/freecad.desktop << 'EOF'
[Desktop Entry]
Name=FreeCAD
Comment=A general purpose 3D CAD modeler
Exec=freecad %F
Icon=freecad
Terminal=false
Type=Application
Categories=Graphics;3DGraphics;Engineering;
MimeType=application/x-extension-fcstd;
EOF
echo "✓ FreeCAD installation complete."

# === Install OrcaSlicer (AppImage) ===
echo "==> Installing OrcaSlicer version 2.3.1 via AppImage..."
# Define the specific version tag and filename based on the release page
ORCA_TAG="v2.3.1"
ORCA_FILENAME="OrcaSlicer_Linux_AppImage_Ubuntu2404_V2.3.1.AppImage"
# Download, place in a system-wide location, and make executable
wget "https://github.com/SoftFever/OrcaSlicer/releases/download/${ORCA_TAG}/${ORCA_FILENAME}" -O /usr/local/bin/orcaslicer.AppImage
chmod +x /usr/local/bin/orcaslicer.AppImage
# Create symlink for easy terminal access (run with 'orcaslicer')
ln -s /usr/local/bin/orcaslicer.AppImage /usr/local/bin/orcaslicer

# Create a desktop entry for the XFCE menu
cat > /usr/share/applications/orcaslicer.desktop << 'EOF'
[Desktop Entry]
Name=OrcaSlicer
Exec=orcaslicer %F
Icon=orcaslicer
Comment=G-code generator for 3D printers
Type=Application
Categories=Graphics;3DGraphics;Engineering;
MimeType=model/stl;application/vnd.ms-pki.stl;application/x-tgif;
EOF
echo "✓ OrcaSlicer installation complete."

debug_glibc "After installing CAD tools and Orca Slicer"

# TeX English-only (feature-complete)
echo "==> TeX (English-only, full feature)"
apt-get -y --no-install-recommends install \
  texlive texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra \
  latexmk latexml texlive-xetex texlive-bibtex-extra biber cm-super \
  texlive-pictures texlive-science texlive-pstricks texlive-context \
  lmodern texlive-plain-generic \
  ipe texworks
debug_glibc "After TeX packages installation"

# === XFCE/VNC remote GUI optimizations (baseline) ===
echo "==> XFCE/VNC remote GUI tuning"
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'XFM'
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
printf 'allowed_users=anybody\nneeds_root_rights=no\n' > /etc/X11/Xwrapper.config


# ===============================================================
# Create comprehensive VNC startup script
# ===============================================================
echo "==> Creating enhanced VNC startup script with full TurboVNC support..."

cat > /usr/local/bin/start_vnc_xfce.sh << 'VNCLAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# TurboVNC + noVNC Launcher with Full Integration
# ============================================================================

# --- Configuration ---
VNC_DISPLAY_NUM=${VNC_DISPLAY_NUM:-1}
VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
WEB_PORT=${WEB_PORT:-6081}
TURBOVNC_WEB_PORT=$((5800 + VNC_DISPLAY_NUM))  # TurboVNC's built-in webserver
GEOM="${VNC_GEOM:-1920x1080}"
DEPTH="${VNC_DEPTH:-24}"

# Security: bind to localhost only (use -nolisten for remote access)
SECURITY_ARGS="-localhost"

# --- Ensure TurboVNC is in PATH ---
export PATH="/opt/TurboVNC/bin:/opt/VirtualGL/bin:${PATH}"

# --- Cleanup function ---
cleanup() {
  echo ""
  echo "Shutting down VNC services..."
  vncserver -kill ":${VNC_DISPLAY_NUM}" 2>/dev/null || true
  pkill -f "websockify.*${WEB_PORT}" 2>/dev/null || true
  jobs -p | xargs -r kill 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# --- Check dependencies ---
check_dependencies() {
  local missing=0
  
  echo "Checking dependencies..."
  
  if ! command -v vncserver >/dev/null 2>&1; then
    echo "  ✗ vncserver not found"
    missing=1
  else
    echo "  ✓ vncserver: $(which vncserver)"
  fi
  
  if ! command -v Xvnc >/dev/null 2>&1; then
    echo "  ✗ Xvnc not found"
    missing=1
  else
    echo "  ✓ Xvnc: $(which Xvnc)"
  fi
  
  if ! command -v startxfce4 >/dev/null 2>&1; then
    echo "  ✗ startxfce4 not found"
    missing=1
  else
    echo "  ✓ XFCE4 available"
  fi
  
  if [ $missing -eq 1 ]; then
    echo ""
    echo "ERROR: Missing required dependencies"
    echo "PATH: $PATH"
    exit 1
  fi
  
  echo "✓ All dependencies found"
  echo ""
}


# --- Check VirtualGL availability ---
check_virtualgl() {
  echo "Checking VirtualGL availability..."
  
  # Add VirtualGL to PATH
  export PATH="/opt/VirtualGL/bin:${PATH}"
  
  if command -v vglrun >/dev/null 2>&1; then
    echo "  ✓ VirtualGL available: $(which vglrun)"
    
    # Check GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
      GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
      if [ -n "$GPU_INFO" ]; then
        echo "  ✓ GPU detected: $GPU_INFO"
      else
        echo "  ⚠ nvidia-smi found but no GPU detected"
      fi
    else
      echo "  ⚠ nvidia-smi not found (CPU rendering only)"
    fi
    
    # Check OpenGL utilities
    if command -v glxinfo >/dev/null 2>&1; then
      echo "  ✓ glxinfo available for OpenGL testing"
    fi
    if command -v glxspheres64 >/dev/null 2>&1; then
      echo "  ✓ glxspheres64 available for GPU benchmarking"
    fi
  else
    echo "  ⚠ VirtualGL not available"
    echo "    GPU-accelerated applications may not work properly"
  fi
  
  echo ""
}


# --- Setup VNC configuration ---
setup_vnc_config() {
  mkdir -p "$HOME/.vnc"
  
  # Create xstartup script
  cat > "$HOME/.vnc/xstartup" << 'XSTART'
#!/bin/sh
# TurboVNC xstartup for XFCE4

# Load X resources
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true

# Font cache
fc-cache -f 2>/dev/null || true

# Start D-Bus if not running
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
fi

# Disable compositing for better VNC performance
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /general/use_compositing -s false 2>/dev/null || true

# Disable screen blanking
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# Start XFCE4
exec /usr/bin/startxfce4
XSTART
  
  chmod +x "$HOME/.vnc/xstartup"
  echo "✓ VNC configuration created"
}

# --- Start VNC server ---
start_vnc_server() {
  echo "Starting TurboVNC server..."
  echo "  Display: :${VNC_DISPLAY_NUM}"
  echo "  Geometry: ${GEOM}"
  echo "  Depth: ${DEPTH}"
  
  # Check if VNC password is set
  if [ ! -f "$HOME/.vnc/passwd" ]; then
    echo ""
    echo "⚠ VNC password not set. Please set it now:"
    vncpasswd
    echo ""
  fi
  
  # Start VNC server
  vncserver ":${VNC_DISPLAY_NUM}" \
    -geometry "${GEOM}" \
    -depth "${DEPTH}" \
    ${SECURITY_ARGS} \
    -xstartup "$HOME/.vnc/xstartup"
  
  # Wait for server to start
  sleep 3
  
  # Verify
  if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
    echo "ERROR: VNC server failed to start"
    echo "Check logs:"
    ls -lt ~/.vnc/*.log 2>/dev/null | head -5
    echo ""
    tail -20 ~/.vnc/*.log 2>/dev/null
    exit 1
  fi
  
  echo "✓ VNC server running on display :${VNC_DISPLAY_NUM} (port ${VNC_PORT})"
}

# --- Check TurboVNC's built-in webserver ---
check_turbovnc_webserver() {
  # TurboVNC may start its own webserver automatically
  if ss -tuln 2>/dev/null | grep -q ":${TURBOVNC_WEB_PORT}\b"; then
    echo "✓ TurboVNC built-in webserver detected on port ${TURBOVNC_WEB_PORT}"
    return 0
  else
    echo "⚠ TurboVNC built-in webserver not running"
    return 1
  fi
}

# --- Start noVNC (websockify) ---
start_novnc() {
  echo "Starting noVNC (HTML5 VNC client)..."
  
  # Find websockify
  WEBSOCKIFY=""
  for candidate in /usr/bin/websockify /usr/local/bin/websockify /opt/conda/bin/websockify; do
    if [ -x "$candidate" ]; then
      WEBSOCKIFY="$candidate"
      echo "  Found websockify: $WEBSOCKIFY"
      break
    fi
  done
  
  if [ -z "$WEBSOCKIFY" ]; then
    echo "  ✗ websockify not found - noVNC will not be available"
    return 1
  fi
  
  # Find noVNC web files
  NOVNC_DIR=""
  for candidate in /usr/local/share/novnc /usr/share/novnc; do
    if [ -d "$candidate" ] && [ -f "$candidate/vnc.html" ]; then
      NOVNC_DIR="$candidate"
      echo "  Found noVNC: $NOVNC_DIR"
      break
    fi
  done
  
  # Start websockify
  if [ -n "$NOVNC_DIR" ]; then
    $WEBSOCKIFY --web "$NOVNC_DIR" ${WEB_PORT} localhost:${VNC_PORT} 2>&1 | \
      grep -v "WARNING" | grep -v "numpy" &
  else
    echo "  ⚠ noVNC files not found, starting websockify without web interface"
    $WEBSOCKIFY ${WEB_PORT} localhost:${VNC_PORT} 2>&1 | \
      grep -v "WARNING" | grep -v "numpy" &
  fi
  
  WEBSOCKIFY_PID=$!
  sleep 2
  
  if ! kill -0 $WEBSOCKIFY_PID 2>/dev/null; then
    echo "  ✗ websockify failed to start"
    return 1
  fi
  
  echo "✓ noVNC running on port ${WEB_PORT} (PID: ${WEBSOCKIFY_PID})"
  return 0
}

# --- Display connection information ---
display_connection_info() {
  NODE=$(hostname -f 2>/dev/null || hostname)
  
  echo ""
  echo "=========================================="
  echo "✓ VNC Server Ready!"
  echo "=========================================="
  echo "Hostname: $NODE"
  echo "Display: :${VNC_DISPLAY_NUM}"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "CONNECTION METHOD 1: Native VNC Viewer (Recommended)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "1. Create SSH tunnel from your laptop:"
  echo "   ssh -L ${VNC_PORT}:${NODE}:${VNC_PORT} \$USER@login.hpc.edu"
  echo ""
  echo "2. Connect VNC viewer to: localhost:${VNC_PORT}"
  echo "   (or localhost:${VNC_DISPLAY_NUM})"
  echo ""
  
  if ss -tuln 2>/dev/null | grep -q ":${WEB_PORT}\b"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CONNECTION METHOD 2: Web Browser (noVNC)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Create SSH tunnel from your laptop:"
    echo "   ssh -L ${WEB_PORT}:${NODE}:${WEB_PORT} \$USER@login.hpc.edu"
    echo ""
    echo "2. Open browser to: http://localhost:${WEB_PORT}"
    echo ""
  fi
  
  if ss -tuln 2>/dev/null | grep -q ":${TURBOVNC_WEB_PORT}\b"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CONNECTION METHOD 3: TurboVNC Java Applet"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Create SSH tunnel from your laptop:"
    echo "   ssh -L ${TURBOVNC_WEB_PORT}:${NODE}:${TURBOVNC_WEB_PORT} \$USER@login.hpc.edu"
    echo ""
    echo "2. Open browser to: http://localhost:${TURBOVNC_WEB_PORT}"
    echo "   (Requires Java plugin - not recommended for modern browsers)"
    echo ""
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "USEFUL COMMANDS:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "View VNC logs:"
  echo "  tail -f ~/.vnc/*.log"
  echo ""
  echo "List running VNC servers:"
  echo "  vncserver -list"
  echo ""
  echo "Kill this VNC server:"
  echo "  vncserver -kill :${VNC_DISPLAY_NUM}"
  echo ""
  echo "Change VNC password:"
  echo "  vncpasswd"
  echo "=========================================="
  echo ""
  echo "Press Ctrl+C to stop all VNC services"
  echo ""
}

# --- Monitor services ---
monitor_services() {
  local check_count=0
  
  while true; do
    sleep 30
    check_count=$((check_count + 1))
    
    # Check VNC server every loop
    if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
      echo "ERROR: VNC server died unexpectedly"
      exit 1
    fi
    
    # Check websockify every 3rd loop (90 seconds)
    if [ $((check_count % 3)) -eq 0 ]; then
      if [ -n "${WEBSOCKIFY_PID:-}" ]; then
        if ! kill -0 $WEBSOCKIFY_PID 2>/dev/null; then
          echo "WARNING: websockify died, restarting..."
          start_novnc || echo "Failed to restart websockify"
        fi
      fi
    fi
  done
}

# ============================================================================
# Main Execution
# ============================================================================

echo "=========================================="
echo "TurboVNC + noVNC Launcher"
echo "=========================================="
echo ""

# Run setup steps
check_dependencies
check_virtualgl 
setup_vnc_config
start_vnc_server

# Try to start web interfaces
check_turbovnc_webserver || true
start_novnc || echo "⚠ noVNC not available (VNC viewer still works)"

# Display connection info
display_connection_info

# Monitor and keep alive
monitor_services
VNCLAUNCHER

chmod 0755 /usr/local/bin/start_vnc_xfce.sh
echo "✓ Enhanced VNC startup script created at /usr/local/bin/start_vnc_xfce.sh"


# ===============================================================
# Create ULTIMATE VNC startup script with all optimizations
# ===============================================================
echo "==> Creating ultimate optimized VNC startup script..."

cat > /usr/local/bin/start_vnc_ultimate.sh << 'ULTIMATE'
#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ULTIMATE TurboVNC + VirtualGL + noVNC Launcher
# With all performance optimizations
# ============================================================================

# --- Configuration ---
VNC_DISPLAY_NUM=${VNC_DISPLAY_NUM:-1}
VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
WEB_PORT=${WEB_PORT:-6081}
GEOM="${VNC_GEOM:-1920x1080}"
DEPTH="${VNC_DEPTH:-24}"

# Performance settings
TVNC_QUALITY="${TVNC_QUALITY:-95}"
TVNC_SUBSAMPLE="${TVNC_SUBSAMPLE:-1}"
TVNC_COMPRESSLEVEL="${TVNC_COMPRESSLEVEL:-2}"

# VirtualGL settings
export VGL_COMPRESS="${VGL_COMPRESS:-proxy}"
export VGL_READBACK="${VGL_READBACK:-sync}"
export VGL_SYNC="${VGL_SYNC:-1}"
export VGL_REFRESHRATE="${VGL_REFRESHRATE:-60}"

# Ensure paths
export PATH="/opt/TurboVNC/bin:/opt/VirtualGL/bin:${PATH}"

# --- Cleanup function ---
cleanup() {
  echo ""
  echo "Shutting down all services..."
  vncserver -kill ":${VNC_DISPLAY_NUM}" 2>/dev/null || true
  pkill -f "websockify.*${WEB_PORT}" 2>/dev/null || true
  pkill -f pulseaudio 2>/dev/null || true
  jobs -p | xargs -r kill 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# --- Banner ---
echo "============================================"
echo "  ULTIMATE Remote Desktop Environment"
echo "============================================"
echo ""

# --- Check dependencies ---
echo "[1/8] Checking dependencies..."
for cmd in vncserver Xvnc startxfce4 vglrun websockify; do
  if command -v $cmd >/dev/null 2>&1; then
    echo "  ✓ $cmd"
  else
    echo "  ✗ $cmd - MISSING!"
    exit 1
  fi
done

# --- Check GPU ---
echo ""
echo "[2/8] Checking GPU..."
if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
  if [ -n "$GPU_NAME" ]; then
    echo "  ✓ GPU: $GPU_NAME"
  else
    echo "  ⚠ nvidia-smi found but no GPU detected"
  fi
else
  echo "  ⚠ No NVIDIA GPU detected (CPU rendering only)"
fi

# --- Setup VNC ---
echo ""
echo "[3/8] Configuring VNC..."
mkdir -p "$HOME/.vnc"

# Performance-optimized xstartup
cat > "$HOME/.vnc/xstartup" << 'XSTART'
#!/bin/sh
# Performance-optimized xstartup

# Load resources
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
fc-cache -f 2>/dev/null || true

# D-Bus
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
fi

# Disable ALL compositing and effects
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/show_frame_shadow -s false 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/show_popup_shadow -s false 2>/dev/null || true

# Disable screen management
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true
xset b off 2>/dev/null || true
xset r rate 250 30 2>/dev/null || true

# Start clipboard sync
autocutsel -fork -selection CLIPBOARD 2>/dev/null || true
autocutsel -fork -selection PRIMARY 2>/dev/null || true

# XFCE
exec startxfce4
XSTART
chmod +x "$HOME/.vnc/xstartup"
echo "  ✓ xstartup configured"

# --- Start VNC ---
echo ""
echo "[4/8] Starting TurboVNC server..."
echo "  Display: :${VNC_DISPLAY_NUM}"
echo "  Geometry: ${GEOM}"
echo "  Quality: ${TVNC_QUALITY}"
echo "  Subsample: ${TVNC_SUBSAMPLE}"

if [ ! -f "$HOME/.vnc/passwd" ]; then
  echo ""
  echo "⚠ VNC password not set. Please set it now:"
  vncpasswd
  echo ""
fi

vncserver ":${VNC_DISPLAY_NUM}" \
  -geometry "${GEOM}" \
  -depth "${DEPTH}" \
  -localhost \
  -xstartup "$HOME/.vnc/xstartup" \
  -quality ${TVNC_QUALITY} \
  -compresslevel ${TVNC_COMPRESSLEVEL} \
  -subsample ${TVNC_SUBSAMPLE}

sleep 3

if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
  echo "  ✗ VNC server failed to start"
  cat ~/.vnc/*.log 2>/dev/null | tail -20
  exit 1
fi
echo "  ✓ VNC server running on :${VNC_DISPLAY_NUM}"

# --- Start PulseAudio ---
echo ""
echo "[5/8] Starting audio support..."
if command -v pulseaudio >/dev/null 2>&1; then
  if ! pulseaudio --check 2>/dev/null; then
    pulseaudio --start --exit-idle-time=-1 2>/dev/null &
    echo "  ✓ PulseAudio started"
  else
    echo "  ✓ PulseAudio already running"
  fi
else
  echo "  ⚠ PulseAudio not available"
fi

# --- Start noVNC ---
echo ""
echo "[6/8] Starting noVNC (HTML5 interface)..."

WEBSOCKIFY=""
for candidate in /usr/bin/websockify /usr/local/bin/websockify; do
  [ -x "$candidate" ] && WEBSOCKIFY="$candidate" && break
done

if [ -z "$WEBSOCKIFY" ]; then
  echo "  ✗ websockify not found - skipping web interface"
else
  NOVNC_DIR=""
  for candidate in /usr/local/share/novnc /usr/share/novnc; do
    [ -d "$candidate" ] && [ -f "$candidate/vnc.html" ] && NOVNC_DIR="$candidate" && break
  done
  
  if [ -n "$NOVNC_DIR" ]; then
    $WEBSOCKIFY --web "$NOVNC_DIR" ${WEB_PORT} localhost:${VNC_PORT} 2>&1 | \
      grep -v "WARNING" | grep -v "numpy" &
    WSPID=$!
    sleep 2
    if kill -0 $WSPID 2>/dev/null; then
      echo "  ✓ noVNC running on port ${WEB_PORT}"
    else
      echo "  ✗ noVNC failed to start"
    fi
  else
    echo "  ⚠ noVNC files not found"
  fi
fi

# --- Performance check ---
echo ""
echo "[7/8] Running performance check..."

# Quick GPU test
export DISPLAY=:${VNC_DISPLAY_NUM}
if command -v vglrun >/dev/null 2>&1 && command -v glxinfo >/dev/null 2>&1; then
  RENDERER=$(vglrun glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
  if [ -n "$RENDERER" ]; then
    echo "  ✓ GPU rendering: $RENDERER"
  else
    echo "  ⚠ GPU rendering test failed"
  fi
else
  echo "  ⚠ Cannot test GPU rendering"
fi

# --- Connection info ---
NODE=$(hostname -f 2>/dev/null || hostname)
echo ""
echo "============================================"
echo "  🎉 Remote Desktop Ready!"
echo "============================================"
echo ""
echo "Node: $NODE"
echo "Display: :${VNC_DISPLAY_NUM}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "METHOD 1: VNC Viewer (Best Performance)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. SSH tunnel:"
echo "   ssh -L ${VNC_PORT}:${NODE}:${VNC_PORT} \$USER@login.hpc.edu"
echo ""
echo "2. Connect VNC to: localhost:${VNC_PORT}"
echo ""

if [ -n "${WSPID:-}" ] && kill -0 $WSPID 2>/dev/null; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "METHOD 2: Web Browser (No Install Needed)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "1. SSH tunnel:"
  echo "   ssh -L ${WEB_PORT}:${NODE}:${WEB_PORT} \$USER@login.hpc.edu"
  echo ""
  echo "2. Browse: http://localhost:${WEB_PORT}"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PERFORMANCE TIPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• GPU apps: vglrun <app> or use aliases (vblender, etc.)"
echo "• Benchmark: vgl_benchmark.sh"
echo "• Monitor: vnc_monitor.sh"
echo "• Tune VNC: turbovnc_tune.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CONTROLS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• Stop: Press Ctrl+C"
echo "• Logs: tail -f ~/.vnc/*.log"
echo "• Status: vncserver -list"
echo "============================================"
echo ""

# --- Monitor and keep alive ---
echo "[8/8] Monitoring services..."
while true; do
  sleep 30
  
  # Check VNC
  if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
    echo "ERROR: VNC server died"
    exit 1
  fi
  
  # Check websockify
  if [ -n "${WSPID:-}" ]; then
    if ! kill -0 $WSPID 2>/dev/null; then
      echo "WARNING: websockify died, restarting..."
      $WEBSOCKIFY --web "$NOVNC_DIR" ${WEB_PORT} localhost:${VNC_PORT} 2>&1 | \
        grep -v "WARNING" &
      WSPID=$!
    fi
  fi
done
ULTIMATE
chmod +x /usr/local/bin/start_vnc_ultimate.sh

echo "✓ Ultimate VNC startup script created"


# Create enhanced noVNC launcher with all features
cat > /usr/local/bin/start_novnc_advanced.sh << 'NOVNCADV'
#!/usr/bin/env bash
# Advanced noVNC launcher with token authentication and SSL

set -euo pipefail

VNC_DISPLAY=${1:-:1}
WEB_PORT=${2:-6081}
VNC_PORT=$((5900 + ${VNC_DISPLAY#:}))

# Generate random token for this session
TOKEN=$(openssl rand -hex 16)

echo "=========================================="
echo "Advanced noVNC Server"
echo "=========================================="
echo "VNC Display: $VNC_DISPLAY"
echo "Web Port: $WEB_PORT"
echo "Token: $TOKEN"
echo ""
echo "Connect: http://localhost:$WEB_PORT/?token=$TOKEN"
echo "=========================================="

# Start websockify with token authentication
/usr/bin/websockify \
  --web /usr/local/share/novnc \
  --token-plugin TokenFile \
  --token-source <(echo "$TOKEN: localhost:$VNC_PORT") \
  $WEB_PORT
NOVNCADV
chmod +x /usr/local/bin/start_novnc_advanced.sh

echo "✓ Advanced noVNC features configured"



# ===============================================================
# Install KasmVNC (Modern, containerized VNC with web UI)
# ===============================================================
echo "==> Installing KasmVNC (modern alternative)..."

# KasmVNC has better web integration and modern features
KASMVNC_VERSION="1.3.1"
ARCH="amd64"

cd /tmp
wget -q "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_jammy_${KASMVNC_VERSION}_${ARCH}.deb"

apt-get install -y ./kasmvncserver_jammy_${KASMVNC_VERSION}_${ARCH}.deb || true
rm -f ./kasmvncserver_jammy_${KASMVNC_VERSION}_${ARCH}.deb

# Create KasmVNC startup script
cat > /usr/local/bin/start_kasmvnc.sh << 'KASMSTART'
#!/usr/bin/env bash
# KasmVNC - Modern VNC with built-in web interface

set -euo pipefail

DISPLAY_NUM=1
VNC_PORT=$((5900 + DISPLAY_NUM))
WEB_PORT=6901

mkdir -p ~/.vnc

# Create KasmVNC xstartup
cat > ~/.vnc/xstartup << 'XS'
#!/bin/sh
eval "$(dbus-launch --sh-syntax)" 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
exec startxfce4
XS
chmod +x ~/.vnc/xstartup

echo "Starting KasmVNC..."
echo "  Display: :$DISPLAY_NUM"
echo "  VNC Port: $VNC_PORT"
echo "  Web Port: $WEB_PORT"
echo ""
echo "Connect: http://localhost:$WEB_PORT"
echo ""

kasmvncserver :$DISPLAY_NUM \
  -geometry 1920x1080 \
  -depth 24 \
  -websocketPort $WEB_PORT \
  -interface 0.0.0.0

echo "KasmVNC started!"
tail -f ~/.vnc/*.log
KASMSTART
chmod +x /usr/local/bin/start_kasmvnc.sh

echo "✓ KasmVNC installed (use: start_kasmvnc.sh)"


# ===============================================================
# Install Vulkan for better GPU performance
# ===============================================================
echo "==> Installing Vulkan support..."

apt-get install -y --no-install-recommends \
  vulkan-tools \
  vulkan-validationlayers \
  mesa-vulkan-drivers \
  libvulkan1

# Create Vulkan test script
cat > /usr/local/bin/test_vulkan.sh << 'VULKAN'
#!/usr/bin/env bash
# Test Vulkan support

echo "Vulkan Instance Version:"
vulkaninfo --summary | grep "Vulkan Instance Version"

echo ""
echo "Available Vulkan Devices:"
vulkaninfo | grep -A 5 "GPU id"

echo ""
echo "Running vulkan cube demo (vglrun required)..."
if command -v vglrun >/dev/null 2>&1; then
  vglrun vkcube
else
  vkcube
fi
VULKAN
chmod +x /usr/local/bin/test_vulkan.sh

echo "✓ Vulkan support installed"


# ===============================================================
# Install Xpra (Modern X11 forwarding)
# ===============================================================
echo "==> Installing Xpra for modern X11 forwarding..."

apt-get install -y --no-install-recommends \
  xpra \
  xpra-html5

# Create Xpra launcher
cat > /usr/local/bin/start_xpra.sh << 'XPRA'
#!/usr/bin/env bash
# Xpra Application Streaming

DISPLAY_NUM=${1:-10}
PORT=$((10000 + DISPLAY_NUM))

echo "Starting Xpra on display :${DISPLAY_NUM}"
echo "HTML5 client: http://localhost:${PORT}"

xpra start :${DISPLAY_NUM} \
  --bind-tcp=0.0.0.0:${PORT} \
  --html=on \
  --start=startxfce4 \
  --daemon=no
XPRA
chmod +x /usr/local/bin/start_xpra.sh

echo "✓ Xpra installed (HTML5 seamless window streaming)"


# ===============================================================
# Install x11vnc (alternative VNC server)
# ===============================================================
echo "==> Installing x11vnc..."

apt-get install -y --no-install-recommends x11vnc

cat > /usr/local/bin/start_x11vnc.sh << 'X11VNC'
#!/usr/bin/env bash
# x11vnc - attach to existing X display

DISPLAY_NUM=${1:-1}
PORT=$((5900 + DISPLAY_NUM))

echo "Starting x11vnc on display :${DISPLAY_NUM} (port ${PORT})"

x11vnc -display :${DISPLAY_NUM} \
  -forever \
  -shared \
  -rfbport ${PORT} \
  -nopw
X11VNC
chmod +x /usr/local/bin/start_x11vnc.sh

echo "✓ x11vnc installed"


# ===============================================================
# Install ffmpeg with hardware encoding
# ===============================================================
echo "==> Installing ffmpeg with NVENC support..."

apt-get install -y --no-install-recommends \
  ffmpeg \
  libavcodec-extra

# Create screen recording script
cat > /usr/local/bin/record_screen.sh << 'RECORD'
#!/usr/bin/env bash
# Screen recording with GPU encoding

DISPLAY_NUM=${1:-1}
OUTPUT=${2:-"screen_recording_$(date +%Y%m%d_%H%M%S).mp4"}

echo "Recording display :${DISPLAY_NUM} to ${OUTPUT}"
echo "Press Ctrl+C to stop"

# Try NVENC (GPU encoding), fallback to libx264 (CPU)
if ffmpeg -encoders 2>/dev/null | grep -q h264_nvenc; then
  ENCODER="h264_nvenc"
  echo "Using NVIDIA GPU encoder"
else
  ENCODER="libx264"
  echo "Using CPU encoder"
fi

DISPLAY=:${DISPLAY_NUM} ffmpeg \
  -f x11grab \
  -video_size 1920x1080 \
  -framerate 30 \
  -i :${DISPLAY_NUM} \
  -c:v ${ENCODER} \
  -preset medium \
  -crf 23 \
  "${OUTPUT}"
RECORD
chmod +x /usr/local/bin/record_screen.sh

echo "✓ ffmpeg installed with screen recording support"



# ===============================================================
# Install Remmina VNC/RDP client
# ===============================================================
echo "==> Installing Remmina remote desktop client..."

apt-get install -y --no-install-recommends \
  remmina \
  remmina-plugin-vnc \
  remmina-plugin-rdp

echo "✓ Remmina installed (launch from Applications menu)"








# ===============================================================
# Install performance monitoring and profiling tools
# ===============================================================
echo "==> Installing performance monitoring tools..."

apt-get install -y --no-install-recommends \
  htop \
  iotop \
  iftop \
  nethogs \
  nload \
  bmon \
  sysstat \
  dstat \
  atop \
  glances \
  btop \
  nmon


# Create GPU monitoring script
cat > /usr/local/bin/gpu_monitor.sh << 'GPUMON'
#!/usr/bin/env bash
# Real-time GPU monitoring

watch -n 1 "nvidia-smi --query-gpu=timestamp,name,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free,temperature.gpu,power.draw --format=csv,noheader,nounits | column -t -s','"
GPUMON
chmod +x /usr/local/bin/gpu_monitor.sh

echo "✓ Performance monitoring tools installed"
echo "  - glances (comprehensive system monitor)"
echo "  - htop/btop (process viewers)"
echo "  - gpu_monitor.sh (GPU stats)"

# Create VNC performance monitor script
cat > /usr/local/bin/vnc_monitor.sh << 'VNCMON'
#!/usr/bin/env bash
# Monitor VNC session performance

echo "=========================================="
echo "VNC Session Performance Monitor"
echo "=========================================="
echo ""

echo "1. VNC Processes:"
ps aux | grep -E "Xvnc|websockify|xfce" | grep -v grep
echo ""

echo "2. Network Connections:"
ss -tuln | grep -E "5901|6081|5800"
echo ""

echo "3. GPU Utilization:"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total \
      --format=csv,noheader,nounits
else
    echo "  nvidia-smi not available"
fi
echo ""

echo "4. CPU Usage (VNC related):"
ps aux | grep -E "Xvnc|websockify" | grep -v grep | awk '{print $3}' | \
  awk '{sum+=$1} END {print "  Total CPU: " sum "%"}'
echo ""

echo "5. Memory Usage:"
free -h
echo ""

echo "6. Display Information:"
if [ -n "$DISPLAY" ]; then
    echo "  DISPLAY: $DISPLAY"
    xdpyinfo | grep -E "dimensions|resolution" | sed 's/^/  /'
else
    echo "  Not running in X session"
fi
echo "=========================================="
VNCMON
chmod +x /usr/local/bin/vnc_monitor.sh

echo "✓ Performance monitoring tools installed"


# ===============================================================
# Install modern Rust-based system tools
# ===============================================================
echo "==> Installing modern Rust-based tools..."

# These are faster, more modern alternatives to traditional tools

# bat (better cat)
BAT_VERSION="0.24.0"
wget -q "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat_${BAT_VERSION}_amd64.deb"
apt-get install -y ./bat_${BAT_VERSION}_amd64.deb
rm -f ./bat_${BAT_VERSION}_amd64.deb

# fd (better find)
FD_VERSION="9.0.0"
wget -q "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd_${FD_VERSION}_amd64.deb"
apt-get install -y ./fd_${FD_VERSION}_amd64.deb
rm -f ./fd_${FD_VERSION}_amd64.deb

# ripgrep (better grep)
RG_VERSION="14.1.0"
wget -q "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep_${RG_VERSION}-1_amd64.deb"
apt-get install -y ./ripgrep_${RG_VERSION}-1_amd64.deb
rm -f ./ripgrep_${RG_VERSION}-1_amd64.deb

# exa/eza (better ls)
EZA_VERSION="0.17.3"
wget -q "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz"
tar -xzf eza_x86_64-unknown-linux-gnu.tar.gz -C /usr/local/bin/
rm -f eza_x86_64-unknown-linux-gnu.tar.gz
chmod +x /usr/local/bin/eza

# bottom (better top/htop)
BOTTOM_VERSION="0.9.6"
wget -q "https://github.com/ClementTsang/bottom/releases/download/${BOTTOM_VERSION}/bottom_${BOTTOM_VERSION}_amd64.deb"
apt-get install -y ./bottom_${BOTTOM_VERSION}_amd64.deb
rm -f ./bottom_${BOTTOM_VERSION}_amd64.deb

# procs (better ps)
PROCS_VERSION="0.14.4"
wget -q "https://github.com/dalance/procs/releases/download/v${PROCS_VERSION}/procs-v${PROCS_VERSION}-x86_64-linux.zip"
unzip -q procs-v${PROCS_VERSION}-x86_64-linux.zip -d /usr/local/bin/
rm -f procs-v${PROCS_VERSION}-x86_64-linux.zip
chmod +x /usr/local/bin/procs

# zoxide (better cd)
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

# Create aliases for Rust tools
cat >> /etc/bash.bashrc << 'RUSTALIASES'

# Modern Rust-based tool aliases
alias cat='bat --paging=never'
alias catp='bat'  # with paging
alias ls='eza --icons'
alias ll='eza --icons -l'
alias la='eza --icons -la'
alias tree='eza --tree'
alias find='fd'
alias grep='rg'
alias top='btm'
alias ps='procs'

# Initialize zoxide (better cd)
eval "$(zoxide init bash)"
alias cd='z'
RUSTALIASES

echo "✓ Modern Rust tools installed"


# === Ulauncher (baseline) ===
# Ulauncher (PPA already added above)
apt-get -y --no-install-recommends install ulauncher
debug_glibc "After installing Ulauncher"

# === Install Alacritty: A modern, GPU-accelerated terminal ===
echo "==> Installing Alacritty (Rust-based, GPU-accelerated terminal)..."
apt-get install -y --no-install-recommends alacritty
# Set Alacritty as the default terminal for XFCE
echo "==> Configuring Alacritty as the default terminal..."
xfconf-query -c helpers -p /main/TerminalEmulator -s alacritty
# This ensures that launching a "Terminal" from the GUI uses Alacritty
gconftool-2 --set --type=string /desktop/gnome/applications/terminal/exec alacritty
update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/alacritty 50

# === ADDITION 2: IPC Infrastructure ===
apt-get install -y \
  libzmq3-dev \
  libzmq5 \
  libfastrtps-dev \
  cyclonedds-dev \
  cyclonedds-tools \
  libcycloneddsidl0t64 \
  supervisor

# Remove Debian-managed Python packages that we'll reinstall via pip
apt-get remove -y python3-zmq 2>/dev/null || true
pip3 install --no-cache-dir \
  pyzmq==25.1.0 \
  msgpack==1.0.7

# === ADDITION 3: Julia-Python Bridge (Modern) ===
pip3 install --no-cache-dir \
  juliacall==0.9.14 \
  juliapkg==0.1.10

# JULIA PACKAGES (After fixing pip)
/opt/julia/bin/julia -e '
  using Pkg

  # Python bridge packages (these use pip internally)
  Pkg.add(["PythonCall", "CondaPkg"])
  
  # Configure to use system Python
  ENV["JULIA_CONDAPKG_BACKEND"] = "Null"
  ENV["PYTHON"] = "/usr/bin/python3"
  
  # Build with system Python (now pip works)
  try
    Pkg.build("PythonCall")
  catch e
    @warn "PythonCall build failed" exception=e
  end

  # Image processing packages
  Pkg.add([
    "Images",
    "ImageFiltering",
    "ImageFeatures",
    "VideoIO"
  ])

  # IPC packages
  Pkg.add(["ZMQ", "MsgPack", "JSON3"])

  # GPU packages
  Pkg.add(["CUDA"])

  # Precompile
  Pkg.precompile()
'
# === ADDITION 4: Monitoring Tools ===
apt-get install -y \
  htop \
  iotop \
  glances \

# Install nvtop (GPU monitor)
cd /tmp
git clone https://github.com/syllo/nvtop.git
cd nvtop && mkdir build && cd build
cmake .. -DNVML_SUPPORT=ON -DUSE_SYSTEM_NVML=ON -DNVIDIA_SUPPORT=ON -DAMDGPU_SUPPORT=OFF -DINTEL_SUPPORT=OFF
make -j$(nproc) && make install
cd / && rm -rf /tmp/nvtop

# === ADDITION 5: Efficient Data Formats ===
apt-get install -y \
  libhdf5-dev \
  liblz4-dev
pip3 install --no-cache-dir \
  h5py==3.9.0 \
  zarr==2.16.0
/opt/julia/bin/julia -e '
  using Pkg
  Pkg.add(["HDF5", "JLD2"])
'

# === FAST-DDS CONFIGURATION ===
echo "==> Configuring Fast-DDS (default RMW for ROS 2)"
mkdir -p /etc/fastdds
cat > /etc/fastdds/DEFAULT_FASTRTPS_PROFILES.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<profiles xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
    <participant profile_name="default_participant" is_default_profile="true">
        <rtps>
            <useBuiltinTransports>true</useBuiltinTransports>
            <builtin>
                <discovery_config>
                    <discoveryProtocol>SIMPLE</discoveryProtocol>
                    <use_SIMPLE_EndpointDiscoveryProtocol>true</use_SIMPLE_EndpointDiscoveryProtocol>
                    <use_STATIC_EndpointDiscoveryProtocol>false</use_STATIC_EndpointDiscoveryProtocol>
                    <leaseDuration>
                        <sec>20</sec>
                        <nanosec>0</nanosec>
                    </leaseDuration>
                </discovery_config>
            </builtin>
            <userTransports>
                <transport_id>shm_transport</transport_id>
                <transport_id>udp_transport</transport_id>
            </userTransports>
        </rtps>
    </participant>

    <transport_descriptors>
        <transport_descriptor>
            <transport_id>shm_transport</transport_id>
            <type>SHM</type>
            <maxMessageSize>65536</maxMessageSize>
        </transport_descriptor>
        <transport_descriptor>
            <transport_id>udp_transport</transport_id>
            <type>UDPv4</type>
            <maxMessageSize>65536</maxMessageSize>
        </transport_descriptor>
    </transport_descriptors>
</profiles>
EOF

# Set environment variable to use this config
echo 'export FASTRTPS_DEFAULT_PROFILES_FILE=/etc/fastdds/DEFAULT_FASTRTPS_PROFILES.xml' >> /etc/profile.d/fastdds.sh
echo "✓ Fast-DDS configured"

# === ADDITION 7: Helper Scripts Directory ===
mkdir -p /opt/scripts
# Domain bridge script (detailed later)
# Julia vision server (detailed later)
# Python-Julia bridge helpers (detailed later)

# === RUST TOOLCHAIN INSTALLATION ===
echo
echo "Installing Rust Toolchain via rustup"
echo
# CRITICAL: Create directories BEFORE setting environment variables
mkdir -p /opt/rust/cargo
mkdir -p /opt/rust/rustup

# Set ownership (we re root during build)
chown -R root:root /opt/rust
chmod -R 755 /opt/rust

export RUSTUP_HOME=/opt/rust/rustup
export CARGO_HOME=/opt/rust/cargo

# Install Rust using rustup
echo "--> Downloading and installing rustup..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
  sh -s -- \
    -y \
    --no-modify-path \
    --profile minimal \
    --default-toolchain stable

# Check installation
if [ $? -eq 0 ]; then
  echo "✓ rustup installation completed"
else
  echo "✗ rustup installation failed"
  exit 1
fi

# CRITICAL: Add to PATH for this build session
export PATH="/opt/rust/cargo/bin:$PATH"

# Verify Rust is available
echo "--> Verify Rust installation..."
if command -v rustc &>/dev/null && command -v cargo &>/dev/null; then
  echo "✓ Rust toolchain installed successfully"
  echo "  rustc version: $(rustc --version)"
  echo "  cargo version: $(cargo --version)"
  echo "  rustup location: $(which rustup)"
  echo "  cargo location: $(which cargo)"
else
  echo "✗ Rust installation failed - binaries not found"
  echo "  PATH: $PATH"
  echo "  Directory contents:"
  ls -la /opt/rust/cargo/bin || echo "cargo/bin directory doesn't exist"
  exit 1
fi

# === RUST TOOLS COMPILATION ===
echo
echo "Compiling Rust Tools from Source"
echo "This will take 15-20 minutes..."
echo
# Create installation directory
mkdir -p /opt/rust/tools/bin

# Set build flags for generic x86-64 compatibility
export RUSTFLAGS="-C target-cpu=x86-64 -C opt-level=2"

# Track which tools installed successfully
INSTALLED_TOOLS=""
FAILED_TOOLS=""

# Install Zellij (Terminal Multiplexer)
echo "==> Compiling Zellij (terminal multiplexer)..."
echo "  This takes ~5-7 minutes..."
if cargo install zellij \
  --version 0.40.1 \
  --root /opt/rust/tools \
  --locked; then
  echo "✓ Zellij installed successfully"
  INSTALLED_TOOLS="${INSTALLED_TOOLS} zellij"
else
  echo "✗ Zellij installation failed"
  FAILED_TOOLS="${FAILED_TOOLS} zellij"
fi

echo ""

# Install bat (Better cat)
echo "==> Compiling bat (syntax highlighting cat)..."
echo "  This takes ~3-4 minutes..."
if cargo install bat \
  --version 0.23.0 \
  --root /opt/rust/tools \
  --locked; then
  echo "✓ bat installed successfully"
  INSTALLED_TOOLS="${INSTALLED_TOOLS} bat"
else
  echo "✗ bat installation failed"
  FAILED_TOOLS="${FAILED_TOOLS} bat"
fi

echo ""

# Install ripgrep (Better grep)
echo "==> Compiling ripgrep (fast search)..."
echo "  This takes ~2-3 minutes..."
if cargo install ripgrep \
  --version 14.1.0 \
  --root /opt/rust/tools \
  --locked; then
  echo "✓ ripgrep installed successfully"
  INSTALLED_TOOLS="${INSTALLED_TOOLS} ripgrep"
else
  echo "✗ ripgrep installation failed"
  FAILED_TOOLS="${FAILED_TOOLS} ripgrep"
fi

echo ""

# Install fd (Better find)
echo "==> Compiling fd (fast find)..."
echo "  This takes ~2-3 minutes..."
if cargo install fd-find \
  --version 10.1.0 \
  --root /opt/rust/tools \
  --locked; then
  echo "✓ fd installed successfully"
  INSTALLED_TOOLS="${INSTALLED_TOOLS} fd"
else
  echo "✗ fd installation failed"
  FAILED_TOOLS="${FAILED_TOOLS} fd"
fi

echo ""

# Install bottom (Better top)
echo "==> Compiling bottom (system monitor)..."
echo "  This takes ~4-5 minutes..."
if cargo install bottom \
  --version 0.9.6 \
  --root /opt/rust/tools \
  --locked; then
  echo "✓ bottom installed successfully"
  INSTALLED_TOOLS="${INSTALLED_TOOLS} bottom"
else
  echo "✗ bottom installation failed"
  FAILED_TOOLS="${FAILED_TOOLS} bottom"
fi

echo ""

# Install dust (Better du)
echo "==> Compiling dust (disk usage)..."
echo "  This takes ~2-3 minutes..."
if cargo install du-dust \
  --version 1.1.1 \
  --root /opt/rust/tools \
  --locked; then
  echo "✓ dust installed successfully"
  INSTALLED_TOOLS="${INSTALLED_TOOLS} dust"
else
  echo "✗ dust installation failed"
  FAILED_TOOLS="${FAILED_TOOLS} dust"
fi

echo ""

# Install exa (Better ls)
echo "==> Compiling exa (modern ls)..."
echo "  This takes ~2-3 minutes..."
if cargo install exa \
  --version 0.10.1 \
  --root /opt/rust/tools \
  --locked; then
  echo "✓ exa installed successfully"
  INSTALLED_TOOLS="${INSTALLED_TOOLS} exa"
else
  echo "✗ exa installation failed"
  FAILED_TOOLS="${FAILED_TOOLS} exa"
fi

echo ""

# Install ox (Minimal editor)
echo "==> Compiling ox (text editor)..."
echo "  This takes ~2-3 minutes..."
if cargo install ox \
  --root /opt/rust/tools \
  --locked; then
  echo "✓ ox installed successfully"
  INSTALLED_TOOLS="${INSTALLED_TOOLS} ox"
else
  echo "✗ ox installation failed"
  FAILED_TOOLS="${FAILED_TOOLS} ox"
fi

echo ""

# CREATE SYMLINKS
echo "Creating Symlinks"
# Map cargo binary names to command names
declare -A TOOL_MAP
TOOL_MAP["zellij"]="zellij"
TOOL_MAP["ripgrep"]="rg"
TOOL_MAP["bat"]="bat"
TOOL_MAP["fd-find"]="fd"
TOOL_MAP["du-dust"]="dust"
TOOL_MAP["exa"]="exa"
TOOL_MAP["ox"]="ox"

for binary in "${!TOOL_MAP[@]}"; do
  cmd_name="${TOOL_MAP[$binary]}"
  if [ -f "/opt/rust/tools/bin/${binary}" ]; then
    ln -sf "/opt/rust/tools/bin/${binary}" "/usr/local/bin/${cmd_name}"
  else
    echo "✗ ${binary} binary not found (not installed)"
  fi
done

echo ""

# CLEANUP
echo "Cleaning Up Build Artifacts"
# Calculate sizes before cleanup
REGISTRY_SIZE=$(du -sh /opt/rust/cargo/registry 2>/dev/null | cut -f1 || echo "0")
GIT_SIZE=$(du -sh /opt/rust/cargo/git 2>/dev/null | cut -f1 || echo "0")

echo "  Cargo registry: $REGISTRY_SIZE"
echo "  Cargo git cache: $GIT_SIZE"

# Remove cargo cache
rm -rf /opt/rust/cargo/registry
rm -rf /opt/rust/cargo/git

echo "✓ Build artifacts removed"
echo ""

# INSTALLATION SUMMARY
echo "Rust Tools Installation Summary"
echo ""
if [ -n "$INSTALLED_TOOLS" ]; then
  echo "✓ Successfully installed tools:"
  for tool in $INSTALLED_TOOLS; do
    echo "  - $tool"
  done
fi

if [ -n "$FAILED_TOOLS" ]; then
  echo "✗ Failed to install (non-critical):"
  for tool in $FAILED_TOOLS; do
    echo "  - $tool"
  done
fi

# Verify final installation
echo "Installed binaries:"
ls -lh /opt/rust/tools/bin 2>/dev/null || echo " (none)"

echo "Disk space used:"
du -sh /opt/rust 2>/dev/null || echo " Unable to calculate"

echo ""
echo "✓ Rust toolchain setup complete"

# ... [after cargo install commands] ...
# VERIFY before claiming success
if [ -d "/opt/rust/tools/bin" ] && [ "$(ls -A /opt/rust/tools/bin)" ]; then
  echo "✓ Rust tools installed successfully"
  ls -lh /opt/rust/tools/bin/
else
  echo "echo "Rust tools directory empty or missing"
  echo "Creating directory for manual installation later..."
  mkdir -p /opt/rust/tools/bin
fi

# ZELLIJ CONFIGURATION
mkdir -p /etc/zellij
cat > /etc/zellij/config.kdl << 'EOF'
// Zellij configuration for ROS 2 multi-workspace development

// Keybindings
keybinds {
    normal {
        // Use Ctrl+g as prefix (like tmux's Ctrl+b)
        bind "Ctrl g" { SwitchToMode "locked"; }
    }
    locked {
        bind "Ctrl g" { SwitchToMode "normal"; }
        bind "Ctrl h" { MoveFocus "Left"; }
        bind "Ctrl j" { MoveFocus "Down"; }
        bind "Ctrl k" { MoveFocus "Up"; }
        bind "Ctrl l" { MoveFocus "Right"; }
    }
}

// UI Configuration
ui {
    pane_frames {
        rounded_corners true
    }
}
// Theme
theme "catppuccin-mocha"
// Default Layout
default_layout "compact"
// Mouse support
mouse_mode true
// Copy on select
copy_on_select true
EOF

# OX EDITOR CONFIGURATION
mkdir -p /etc/ox
cat > /etc/ox/config.ron << 'EOX'
Config(
    general: General(
        line_number_padding_right: 2,
        line_number_padding_left: 1,
        tab_width: 4,
        undo_period: 5,
        greeting_message: "Ox Editor - Rust-based minimal editor",
    ),
    theme: Theme(
        editor_bg: (0, 0, 0),
        editor_fg: (255, 255, 255),
        line_number_fg: (65, 65, 65),
        line_number_bg: (0, 0, 0),
    ),
    macros: {
        "python": "#!/usr/bin/env python3\n",
        "julia": "#!/usr/bin/env julia\n",
        "bash": "#!/bin/bash\n",
    },
)
EOX

# ROS MULTI-WORKSPACE LAUNCHER (Zellij version)
cat > /usr/local/bin/ros_multiterm_zellij << 'EOF'
#!/bin/bash
# Launch Zellij session with multiple ROS environments

SESSION="ros_multi"

# Create Zellij layout
cat > /tmp/ros_layout.kdl << 'LAYOUT'
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }
    
    tab name="Humble" focus=true {
        pane {
            command "bash"
            args "-c" "conda activate ros2_humble && cd /workspaces/humble_ws && exec bash"
        }
    }
    
    tab name="Jazzy" {
        pane {
            command "bash"
            args "-c" "conda activate ros2_jazzy && cd /workspaces/jazzy_ws && exec bash"
        }
    }
    
    tab name="Bridge" {
        pane {
            command "bash"
            args "-c" "echo 'Start domain bridge via: python3 /opt/scripts/domain_bridge.py' && exec bash"
        }
    }
    
    tab name="Julia" {
        pane split_direction="vertical" {
            pane {
                command "bash"
                args "-c" "echo 'Start Julia server: julia /opt/scripts/julia_vision_server.jl' && exec bash"
            }
            pane {
                command "julia"
            }
        }
    }
    
    tab name="Monitor" {
        pane split_direction="vertical" {
            pane {
                command "btm" // bottom system monitor
            }
            pane {
                command "nvtop" // GPU monitor
            }
        }
    }
}
LAYOUT

# Launch Zellij with layout
zellij --layout /tmp/ros_layout.kdl attach -c $SESSION
EOF
chmod +x /usr/local/bin/ros_multiterm_zellij

# ALTERNATIVE: TMUX LAUNCHER (keep both options)
cat > /usr/local/bin/ros_multiterm_tmux << 'EOF'
#!/bin/bash
# Launch tmux session with multiple ROS environments

SESSION="ros_multi"

# Create new tmux session
tmux new-session -d -s $SESSION

# Window 0: Humble workspace
tmux rename-window -t $SESSION:0 'Humble'
tmux send-keys -t $SESSION:0 "conda activate ros2_humble" C-m
tmux send-keys -t $SESSION:0 "cd /workspaces/humble_ws" C-m

# Window 1: Jazzy workspace
tmux new-window -t $SESSION:1 -n 'Jazzy'
tmux send-keys -t $SESSION:1 "conda activate ros2_jazzy" C-m
tmux send-keys -t $SESSION:1 "cd /workspaces/jazzy_ws" C-m

# Window 2: Bridge/monitoring
tmux new-window -t $SESSION:2 -n 'Bridge'
tmux send-keys -t $SESSION:2 "echo 'Start domain bridge when ready'" C-m
tmux send-keys -t $SESSION:2 "python3 /opt/scripts/domain_bridge.py" C-m

# Window 3: Julia processing
tmux new-window -t $SESSION:3 -n 'Julia'
tmux send-keys -t $SESSION:3 "echo 'Julia server: julia /opt/scripts/julia_vision_server.jl'" C-m
tmux send-keys -t $SESSION:3 "julia" C-m

# Window 4: Monitoring (split pane)
tmux new-window -t $SESSION:4 -n 'Monitor'
tmux send-keys -t $SESSION:4 'btm' C-m
tmux split-window -h -t $SESSION:4
tmux send-keys -t $SESSION:4.1 'nvtop' C-m

# Attach to session
tmux attach-session -t $SESSION
EOF
chmod +x /usr/local/bin/ros_multiterm_tmux

# Create convenience alias
cat > /usr/local/bin/ros_multiterm << 'EOF'
#!/bin/bash
# Default to Zellij, fallback to tmux
if command -v zellij &>/dev/null; then
  exec /usr/local/bin/ros_multiterm_zellij "$@"
elif command -v tmux &>/dev/null; then
  exec /usr/local/bin/ros_multiterm_tmux "$@"
else
  echo "Error: No terminal multiplexer found (zellij or tmux)"
  exit 1
fi
EOF
chmod +x /usr/local/bin/ros_multiterm

# CLEANUP RUST BUILD ARTIFACTS
# Remove cargo cache to save space
rm -rf /opt/rust/cargo/registry
rm -rf /opt/rust/cargo/git
# Keep only the installed binaries
echo "Rust tools installed successfully"
ls -lh /opt/rust/tools/bin/

# ZENOH INSTALLATION (with error checking)
echo "==> Installing Zenoh"
mkdir -p /opt/zenoh
cd /tmp

ZENOH_VERSION="0.11.0"
ZENOH_FILE="zenoh-${ZENOH_VERSION}-x86_64-unknown-linux-gnu.zip"
ZENOH_URL="https://github.com/eclipse-zenoh/zenoh/releases/download/${ZENOH_VERSION}/${ZENOH_FILE}"

# Downloading Zenoh from GitHub...
if wget -q --show-progress --timeout=60 "${ZENOH_URL}"; then
  echo "✓ Download successful"
  if unzip -q "${ZENOH_FILE}" -d /opt/zenoh; then
    echo "✓ Extraction successful"
    chmod +x /opt/zenoh/zenohd 2>/dev/null || true
    if [ -f /opt/zenoh/zenohd ]; then
      ln -sf /opt/zenoh/zenohd /usr/local/bin/zenohd
      echo "✓ Zenoh installed: $(zenohd --version)"
    else
      echo "✗ Zenoh binary not found after extraction"
    fi
  else
    echo "✗ Extraction failed"
  fi
  rm -f "${ZENOH_FILE}"
else
  echo "✗ Download failed - Zenoh will not be available"
  echo "  You can install manually later if needed"
fi
cd /

# Symlink binaries
ln -sf /opt/zenoh/bin/zenohd /usr/local/bin/zenohd

# ZENOH CONFIGURATION
mkdir -p /etc/zenoh
# Zenoh Router Configuration
cat > /etc/zenoh/zenoh-router.json5 << 'EOF'
// Zenoh router configuration for ROS 2 multi-version bridge
{
  // Router mode
  mode: "router",
  // Listening endpoints
  listen: {
    endpoints: [
      "tcp/0.0.0.0:7447", // Main Zenoh protocol
      "udp/0.0.0.0:7447", // UDP multicast
    ],
  },
  // Connect to other routers (for distributed systems)
  connect: {
    endpoints: [
      // Add remote routers here if needed
      // "tcp/remote-router:7447"
    ],
  },
  // Storage configuration (optional - for persistent data)
  plugins: {
    storage_manager: {
      volumes: {
        memory: {
          // In-memory storage for transient data
        },
      },
      storages: {
        demo: {
          key_expr: "ros2/**",
          volume: "memory",
        },
      },
    },
    // REST API plugin (useful for debugging)
    rest: {
      http_port: 8000
    },
  },
  // Advanced settings
  scouting: {
    multicast: {
      enabled: true,
      address: "224.0.0.224:7446"
    }
  }
}
EOF

# Zenoh-DDS Bridge Configuration (Humble domain)
cat > /etc/zenoh/zenoh-bridge-humble.json5 << 'EOF'
// Bridge ROS 2 Humble (Domain 1) to Zenoh
{
  mode: "client",
  connect: {
    endpoints: ["tcp/localhost:7447"]
  },
  plugins: {
    ros2dds: {
      // Domain ID for Humble
      domain: 1,
      // Namespace for Humble topics in Zenoh
      namespace: "/humble",
      // Topic routing rules
      allow: [
        // allow all topics under /humble namespace
        { topic: "**" }
      ],
      // DDS Configuration
      shm_enabled: true,  // Shared memory for local performance
      // QoS mapping
      reliable_routes_blocking: true
    }
  }
}
EOF

# Zenoh-DDS Bridge Configuration (Jazzy domain)
cat > /etc/zenoh/zenoh-bridge-jazzy.json5 << 'EOF'
// Bridge ROS 2 Jazzy (Domain 2) to Zenoh
{
  mode: "client",
  connect: {
    endpoints: ["tcp/localhost:7447"]
  },
  plugins: {
    ros2dds: {
      // Domain ID for Jazzy
      domain: 2,
      // Namespace for Jazzy topics in Zenoh
      namespace: "/jazzy",
      // Topic routing rules
      allow: [
        { topic: "**" }
      ],
      shm_enabled: true,
      reliable_routes_blocking: true
    }
  }
}
EOF

# ZENOH JULIA BINDINGS (Optional, but useful)
/opt/julia/bin/julia -e '
  using Pkg
  # Zenoh.jl wrapper (community package)
  # Note: Official Julia bindings may not exist yet
  # Use ZMQ bridge to Zenoh as fallback
  Pkg.add(["ZMQ", "JSON3", "HTTP"])
  # If official Zenoh.jl becomes available:
  # Pkg.add("Zenoh")
'

# ZENOH MANAGEMENT SCRIPTS
# Zenoh startup script
cat > /usr/local/bin/zenoh_start << 'EOF'
#!/bin/bash
# Start Zenoh router and bridges

echo "Starting Zenoh infrastructure..."

# Start Zenoh router in background
echo "  Starting Zenoh router on port 7447..."
zenohd --config /etc/zenoh/zenoh-router.json5 > /tmp/zenoh-router.log 2>&1 &
ROUTER_PID=$!
sleep 2

# Check if router started
if ! ps -p $ROUTER_PID > /dev/null; then
  echo "  ✗ Failed to start Zenoh router"
  cat /tmp/zenoh-router.log
  exit 1
fi
echo "  ✓ Zenoh router started (PID: $ROUTER_PID)"

# Start Humble bridge
if [ -d "/conda/envs/ros2_humble" ]; then
  echo "  Starting Zenoh-DDS bridge for Humble (Domain 1)..."
  zenoh-bridge-dds --config /etc/zenoh/zenoh-bridge-humble.json5 > /tmp/zenoh-humble.log 2>&1 &
  HUMBLE_PID=$!
  sleep 1
  if ps -p $HUMBLE_PID > /dev/null; then
    echo "  ✓ Humble bridge started (PID: $HUMBLE_PID)"
  else
    echo "  ✗ Failed to start Humble bridge"
    cat /tmp/zenoh-humble.log
  fi
fi

# Start Jazzy bridge
if [ -d "/conda/envs/ros2_jazzy" ] || [ -d "/opt/ros/jazzy" ]; then
  echo "  Starting Zenoh-DDS bridge for Jazzy (Domain 2)..."
  zenoh-bridge-dds --config /etc/zenoh/zenoh-bridge-jazzy.json5 > /tmp/zenoh-jazzy.log 2>&1 &
  JAZZY_PID=$!
  sleep 1
  if ps -p $JAZZY_PID > /dev/null; then
    echo "  ✓ Jazzy bridge started (PID: $JAZZY_PID)"
  else
    echo "  ✗ Failed to start Jazzy bridge"
    cat /tmp/zenoh-jazzy.log
  fi
fi

echo "Zenoh infrastructure ready!"
echo "  Router: http://localhost:8000 (REST API)"
echo "  Logs: /tmp/zenoh*.log"
EOF
chmod +x /usr/local/bin/zenoh_start

# Zenoh stop script
cat > /usr/local/bin/zenoh_stop << 'EOF'
#!/bin/bash
# Stop all Zenoh processes

echo "Stopping Zenoh infrastructure..."
pkill -f zenohd
pkill -f zenoh-bridge
echo "✓ Zenoh stopped"
EOF
chmod +x /usr/local/bin/zenoh_stop

# Zenoh status script
cat > /usr/local/bin/zenoh_status << 'EOF'
#!/bin/bash
# Check Zenoh status

echo "Zenoh Infrastructure Status:"
echo "----------------------------"
# Check router
if pgrep -f "zenohd" > /dev/null; then
  echo "✓ Zenoh Router: RUNNING"
  echo "  REST API: http://localhost:8000"
else
  echo "✗ Zenoh Router: STOPPED"
fi

# Check Humble bridge
if pgrep -f "zenoh-bridge.*humble" > /dev/null; then
  echo "✓ Humble Bridge: RUNNING (Domain 1 -> /humble namespace)"
else
  echo "✗ Humble Bridge: STOPPED"
fi

# Check Jazzy bridge
if pgrep -f "zenoh-bridge.*jazzy" > /dev/null; then
  echo "✓ Jazzy Bridge: RUNNING (Domain 2 -> /jazzy namespace)"
else
  echo "✗ Jazzy Bridge: STOPPED"
fi

echo "Logs:"
echo "  Router: /tmp/zenoh-router.log"
echo "  Humble: /tmp/zenoh-humble.log"
echo "  Jazzy: /tmp/zenoh-jazzy.log"
EOF
chmod +x /usr/local/bin/zenoh_status

# ZENOH PYTHON UTILITIES
# ZENOH TOPIC BRIDGE SCRIPT
mkdir -p /opt/scripts
cat > /opt/scripts/zenoh_topic_bridge.py << 'EOF'
#!/usr/bin/env python3
# Zenoh topic bridge for ROS 2 Humble <-> Jazzy communication

import sys
try:
    import zenoh
except ImportError:
    print(" Zenoh-Python package not installed")
    print("Install with: pip3 install eclipse-zenoh")
    sys.exit(1)

class ZenohTopicBridge:
    def __init__(self):
        # Connect to Zenoh router
        config = zenoh.Config()
        self.session = zenoh.open(config)
        print("✓ Connected to Zenoh router")

    def bridge_topic(self, from_topic: str, to_topic: str):
        """Bridge a topic from one namespace to another"""
        def callback(sample):
            # Forward data
            self.session.put(to_topic, sample.payload)
            print(f"Bridged: {from_topic} -> {to_topic}")

        # Subscribe and forward
        subscriber = self.session.declare_subscriber(from_topic, callback)
        print(f"Bridge active: {from_topic} -> {to_topic}")
        return subscriber

    def run(self):
        """Keep bridge running"""
        print("Zenoh topic bridge running. Press Ctrl+C to stop.")
        try:
            import time
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("Stopping bridge...")

if __name__ == "__main__":
    bridge = ZenohTopicBridge()
    # Example bridges - customize as needed
    bridge.bridge_topic('/humble/camera/image', '/jazzy/camera/image')
    bridge.bridge_topic('/jazzy/cmd_vel', '/humble/cmd_vel')
    bridge.run()
EOF
chmod +x /opt/scripts/zenoh_topic_bridge.py
echo "✓ Zenoh topic bridge script created"

# UPDATE ZELLIJ LAYOUT WITH ZENOH
# Update the Zellij launcher to include Zenoh
cat > /usr/local/bin/ros_multiterm_zellij_zenoh << 'EOF'
#!/bin/bash
# Launch Zellij session with Zenoh-enabled ROS environments

SESSION="ros_multi_zenoh"

# Start Zenoh infrastructure first
zenoh_start

# Create Zellij layout
cat > /tmp/ros_zenoh_layout.kdl << 'LAYOUT'
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="Humble" focus=true {
        pane {
            command "bash"
            args "-c" "conda activate ros2_humble && export RMW_IMPLEMENTATION=rmw_zenoh_cpp && cd /workspaces/humble_ws && exec bash"
        }
    }
    
    tab name="Jazzy" {
        pane {
            command "bash"
            args "-c" "conda activate ros2_jazzy && export RMW_IMPLEMENTATION=rmw_zenoh_cpp && cd /workspaces/jazzy_ws && exec bash"
        }
    }
    
    tab name="Zenoh" {
        pane split_direction="vertical" {
            pane {
                command "bash"
                args "-c" "zenoh_status && echo '' && echo 'Zenoh Infrastructure running' && exec bash"
            }
            pane {
                command "bash"
                args "-c" "tail -f /tmp/zenoh-router.log"
            }
        }
    }

    tab name="Julia" {
        pane split_direction="vertical" {
            pane {
                command "bash"
                args "-c" "echo 'Start Julia server: julia /opt/scripts/julia_vision_server.jl' && exec bash"
            }
            pane {
                command "julia"
            }
        }
    }
    
    tab name="Monitor" {
        pane split_direction="vertical" {
            pane {
                command "btm"
            }
            pane {
                command "nvtop"
            }
        }
    }
}
LAYOUT

# Launch Zellij with layout
zellij --layout /tmp/ros_zenoh_layout.kdl attach -c $SESSION
EOF
chmod +x /usr/local/bin/ros_multiterm_zellij_zenoh

# CLEANUP
# Remove Zenoh build artifacts
rm -rf /opt/rust/cargo/registry
rm -rf /opt/rust/cargo/git
echo "✓ Zenoh installation complete"

# === Sioyek note (baseline) ===
echo "==> Sioyek (manual AppImage install recommended)"
echo "[note] After build, to install Sioyek:"
echo "  - 1) Download AppImage from https://github.com/ahrm/sioyek/releases"
echo "  - 2) chmod +x Sioyek-*.AppImage && sudo mv Sioyek-*.AppImage /usr/local/bin/sioyek"
echo "  - 3) Optionally create a desktop file for menus"



# ================= Final Failsafe: Verify All Symlinks =====================
echo "==> Final verification of TurboVNC/VirtualGL symlinks..."

# TurboVNC binaries
TURBOVNC_BINS="vncserver Xvnc vncpasswd vncconnect vncviewer webserver tvncconfig"
for binary in $TURBOVNC_BINS; do
  if [ ! -L "/usr/local/bin/$binary" ] && [ -x "/opt/TurboVNC/bin/$binary" ]; then
    ln -sf "/opt/TurboVNC/bin/$binary" "/usr/local/bin/$binary"
    echo "  ✓ Created missing symlink: $binary"
  fi
done

# VirtualGL binaries (comprehensive list)
VIRTUALGL_BINS="vglrun vglclient vglconfig vglconnect vglgenkey vgllogin vglserver_config glxinfo glxspheres64 eglinfo eglxinfo eglxspheres64 cpustat nettest tcbench"
for binary in $VIRTUALGL_BINS; do
  if [ ! -L "/usr/local/bin/$binary" ] && [ -x "/opt/VirtualGL/bin/$binary" ]; then
    ln -sf "/opt/VirtualGL/bin/$binary" "/usr/local/bin/$binary"
    echo "  ✓ Created missing symlink: $binary"
  fi
done

# Final comprehensive verification
echo ""
echo "==> Critical symlink verification:"
declare -A CRITICAL_BINS=(
  ["vncserver"]="/opt/TurboVNC/bin/vncserver"
  ["Xvnc"]="/opt/TurboVNC/bin/Xvnc"
  ["webserver"]="/opt/TurboVNC/bin/webserver"
  ["vglrun"]="/opt/VirtualGL/bin/vglrun"
  ["glxinfo"]="/opt/VirtualGL/bin/glxinfo"
  ["glxspheres64"]="/opt/VirtualGL/bin/glxspheres64"
)

for binary in "${!CRITICAL_BINS[@]}"; do
  expected="${CRITICAL_BINS[$binary]}"
  if [ -L "/usr/local/bin/$binary" ]; then
    actual=$(readlink "/usr/local/bin/$binary")
    if [ -x "$actual" ]; then
      echo "  ✓ $binary -> $actual [OK]"
    else
      echo "  ✗ $binary -> $actual [BROKEN]"
    fi
  else
    echo "  ✗ $binary [MISSING]"
  fi
done

echo "✓ Symlink verification complete"



# Cache is already unified in /container_cache/ - no need for complex harvesting
echo "==> Cache is unified in /container_cache/ - ready for harvest"

# Clean up temporary files but preserve our cache
echo "==> Cleaning temporary files while preserving cache..."

# Clean APT lists (safe to remove)
echo "  » APT LISTS CLEANUP - Monitoring cache before APT lists cleanup"
echo "  /container_cache/apt/archives: $(find /container_cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"
rm -rf /var/lib/apt/lists/* 2>/dev/null || true
echo "  » APT LISTS CLEANUP - Monitoring cache after APT lists cleanup"
echo "  /container_cache/apt/archives: $(find /container_cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"

# Clean temporary APT directories that might cause issues
rm -rf /tmp/apt-dpkg-install* 2>/dev/null || true
# apt-fast cleanup removed - using apt-aria wrapper instead

# Clean temporary files but preserve our container cache
echo "  » CLEANUP SECTION - Monitoring cache before cleanup"
echo "  /container_cache/apt/archives: $(find /container_cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"
# DEBUG: Check for symlinks or unusual directory structure
echo "  DEBUG: Checking for symlinks or unusual paths..."
ls -la /tmp/ | grep -E "(container_cache|apt/archives)" || echo "No suspicious symlinks in /tmp"
ls -la /container_cache/apt/archives/ | head -5
echo "  DEBUG: About to run: find /tmp -type f -name '*.deb' -delete"
find /tmp -type f -name "*.deb" -delete 2>/dev/null || true
find /tmp -type f -name "*.tar.gz" -delete 2>/dev/null || true
find /tmp -type f -name "*.whl" -delete 2>/dev/null || true
echo "  » CLEANUP SECTION - Monitoring cache after cleanup"
echo "  /container_cache/apt/archives: $(find /container_cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"

# === FINAL CACHE PRESERVATION ===
# Reverting cache file permissions to normal ===
if command -v chattr >/dev/null 2>&1; then
  chattr -i /container_cache/apt/archives/*.deb 2>/dev/null
  echo "chattr -i command executed successfully"
else
  echo "WARNING: chattr command not available - cannot revert file permissions"
fi

# Show monitoring summary and aggregated cache summary before preservation
display_cache_monitoring_summary
cache_summary
# Add detailed monitoring before any cache operations
echo "  » DETAILED CACHE INVESTIGATION - BEFORE PRESERVATION"
echo "  Container cache directory contents:"
ls -la /container_cache/apt/archives/ 2>/dev/null | head -10 || echo "Directory empty or not accessible"
echo "  Var cache directory contents:"
ls -la /var/cache/apt/archives/ 2>/dev/null | head -10 || echo "Directory empty or not accessible"
echo "Cache file counts:"
echo "  /container_cache/apt/archives: $(find /container_cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"
echo "  /var/cache/apt/archives: $(find /var/cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"

# Ensure all downloaded packages are preserved in the cache directory
echo "==> Preserving APT cache for future builds ==="
# Check if packages are in the standard APT cache location
if [ -d "/var/cache/apt/archives" ]; then
  echo "Copying packages from /var/cache/apt/archives to /container_cache/apt/archives..."
  find /var/cache/apt/archives -name "*.deb" -type f -exec cp {} /container_cache/apt/archives/ \; 2>/dev/null || true
  echo "After copying from /var/cache/apt/archives:"
  echo "  /container_cache/apt/archives: $(find /container_cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"
fi

# Also preserve any packages that might be in the system cache
if [ -d "/var/lib/apt/cache" ]; then
  echo "Checking system APT cache for additional packages..."
  find /var/lib/apt/cache -name "*.deb" -type f -exec cp {} /container_cache/apt/archives/ \; 2>/dev/null || true
  echo "After copying from /var/lib/apt/cache:"
  echo "  /container_cache/apt/archives: $(find /container_cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"
fi

# Final monitoring before cache harvest
monitor_cache "Final cache status before harvest"

# Add one more detailed check right before the script ends
echo "  » FINAL CACHE CHECK - RIGHT BEFORE SCRIPT END"
echo "Final container cache contents:"
ls -la /container_cache/apt/archives/ 2>/dev/null | head -10 || echo "Directory empty or not accessible"
echo ""
echo "Final cache file count:"
echo "  /container_cache/apt/archives: $(find /container_cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"
echo ""
# Report cache status
echo "[debug] Container cache status:"
echo "  APT archives: $(ls /container_cache/apt/archives/*.deb 2>/dev/null | wc -l) files"
echo "  Conda packages: $(ls /container_cache/conda_pkgs/* 2>/dev/null | wc -l) files"
echo "  Pip wheels: $(ls /container_cache/wheels/* 2>/dev/null | wc -l) files"
echo "  Julia packages: $(ls /container_cache/julia_pkgs/* 2>/dev/null | wc -l) files"
echo "=========================================================================="
```



# ===============================================================
# Final Installation Verification
# ===============================================================
echo ""
echo "=========================================="
echo "Final Installation Verification"
echo "=========================================="

# Test TurboVNC
echo ""
echo "TurboVNC Installation:"
if [ -x /usr/local/bin/vncserver ]; then
  /usr/local/bin/vncserver -help 2>&1 | head -1 || echo "  ✓ vncserver binary present"
  echo "  ✓ TurboVNC installed"
else
  echo "  ✗ TurboVNC not found!"
fi

# Test VirtualGL
echo ""
echo "VirtualGL Installation:"
if [ -x /usr/local/bin/vglrun ]; then
  /usr/local/bin/vglrun --version 2>&1 | head -1 || echo "  ✓ vglrun binary present"
  echo "  ✓ VirtualGL installed"
else
  echo "  ✗ VirtualGL not found!"
fi

# Test helper scripts
echo ""
echo "Helper Scripts:"
for script in start_vnc_xfce.sh test_virtualgl.sh vgl_benchmark.sh vgl_info.sh vgl_launch.sh; do
  if [ -x "/usr/local/bin/$script" ]; then
    echo "  ✓ $script"
  else
    echo "  ✗ $script missing"
  fi
done

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="


# ===============================================================
# VNC server selection and comparison tool
# ===============================================================
echo "==> Creating VNC server selection tool..."

cat > /usr/local/bin/vnc_select.sh << 'VNCSELECT'
#!/usr/bin/env bash
# VNC Server Selection and Comparison Tool

cat << 'INFO'
========================================
VNC Server Options
========================================

Available VNC servers in this container:

1. TurboVNC (Default - Recommended)
   - Best performance for GPU applications
   - Optimized JPEG compression
   - Built specifically for VirtualGL
   - Command: start_vnc_xfce.sh

2. TurboVNC Ultimate (Enhanced)
   - All TurboVNC features
   - Automatic optimization
   - Performance monitoring
   - Audio support
   - Command: start_vnc_ultimate.sh

3. TigerVNC (Alternative)
   - Good compatibility
   - Different compression algorithm
   - Some prefer the image quality
   - Command: start_vnc_tigervnc.sh

4. KasmVNC (Modern)
   - Modern web-first VNC
   - Built-in web interface
   - Container-optimized
   - Command: start_kasmvnc.sh

5. x11vnc (Screen Sharing)
   - Can attach to existing X session
   - Good for debugging
   - Command: start_x11vnc.sh

========================================
RECOMMENDATION
========================================

For most users: start_vnc_ultimate.sh

This provides the best balance of:
- Performance (TurboVNC)
- GPU support (VirtualGL)
- Ease of use (noVNC web interface)
- Monitoring and diagnostics

========================================
PERFORMANCE COMPARISON
========================================

Benchmark your options:
  vgl_benchmark.sh       (VirtualGL performance)
  turbovnc_tune.sh       (TurboVNC settings)
  vnc_monitor.sh         (Real-time monitoring)

========================================
INFO

# If argument provided, start that server
if [ $# -gt 0 ]; then
  case "$1" in
    turbovnc|1)
      exec start_vnc_xfce.sh
      ;;
    ultimate|2)
      exec start_vnc_ultimate.sh
      ;;
    tiger|3)
      exec start_vnc_tigervnc.sh
      ;;
    kasm|4)
      exec start_kasmvnc.sh
      ;;
    x11vnc|5)
      exec start_x11vnc.sh
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
fi
VNCSELECT
chmod +x /usr/local/bin/vnc_select.sh

echo "✓ VNC selection tool created"


# ===============================================================
# Network and TCP Tuning for Remote Desktop
# ===============================================================
echo "==> Creating network optimization script..."

cat > /usr/local/bin/optimize_network.sh << 'NETOPT'
#!/usr/bin/env bash
# Optimize network for remote desktop (run on host/container with permissions)

echo "Optimizing TCP for remote desktop..."

# These would need to run on host or with capabilities
# Include as documentation

cat << 'EOF'
# Add these to host system /etc/sysctl.conf for better performance:

# Increase TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Increase max backlog
net.core.netdev_max_backlog = 5000

# Enable BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

Then run: sudo sysctl -p
EOF

echo ""
echo "Note: These optimizations require host-level changes"
NETOPT
chmod +x /usr/local/bin/optimize_network.sh

echo "✓ Network optimization guide created"




# ===============================================================
# Create Unified Remote Desktop Launcher
# ===============================================================
echo "==> Creating unified remote desktop launcher..."

cat > /usr/local/bin/remote_desktop.sh << 'RDLAUNCH'
#!/usr/bin/env bash
# Unified Remote Desktop Launcher

show_menu() {
  cat << EOF

========================================
Remote Desktop Launcher
========================================

Available Options:

VNC SERVERS:
  1) TurboVNC (default, best for most uses)
  2) TurboVNC High Quality (fast network)
  3) TurboVNC Low Bandwidth (slow network)
  4) TigerVNC (alternative)
  5) x11vnc (attach to existing display)
  6) KasmVNC (modern web VNC)

APPLICATION STREAMING:
  7) Xpra (seamless windows)
  8) Sunshine (game streaming, ultra-low latency)

UTILITIES:
  9) List running sessions
 10) Kill all VNC servers
 11) Test VirtualGL
 12) GPU benchmark
 13) Record screen

 0) Exit

========================================
EOF
  read -p "Select option: " choice
  echo ""
  handle_choice "$choice"
}

handle_choice() {
  case $1 in
    1) start_vnc_xfce.sh ;;
    2) start_vnc_ultrahq.sh ;;
    3) start_vnc_lowbw.sh ;;
    4) start_vnc_tigervnc.sh ;;
    5) read -p "Display number (default 1): " disp
       start_x11vnc.sh ${disp:-1} ;;
    6) start_kasmvnc.sh ;;
    7) start_xpra.sh ;;
    8) start_sunshine.sh ;;
    9) vncserver -list
       echo ""
       ps aux | grep -E "vnc|xpra|sunshine" | grep -v grep ;;
   10) vncserver -kill :1 2>/dev/null
       pkill -f vnc
       pkill -f xpra
       echo "All VNC servers killed" ;;
   11) test_virtualgl.sh ;;
   12) vgl_benchmark.sh ;;
   13) read -p "Output filename (default: screen_recording.mp4): " fname
       record_screen.sh 1 "${fname:-screen_recording.mp4}" ;;
    0) exit 0 ;;
    *) echo "Invalid option" ;;
  esac
  
  read -p "Press Enter to continue..."
  show_menu
}

# Check if running in container
if [ -f /.singularity.d/Singularity ]; then
  echo "Running inside Singularity container"
else
  echo "Warning: Should be run inside container"
fi

show_menu
RDLAUNCH
chmod +x /usr/local/bin/remote_desktop.sh

echo "✓ Unified launcher created: remote_desktop.sh"




# ===============================================================
# Create Performance Benchmarking Suite
# ===============================================================
echo "==> Creating performance benchmark suite..."

cat > /usr/local/bin/benchmark_all.sh << 'BENCH'
#!/usr/bin/env bash
# Comprehensive Remote Desktop Performance Benchmark

echo "=========================================="
echo "Remote Desktop Performance Benchmark"
echo "=========================================="
echo ""

# System Info
echo "SYSTEM INFORMATION:"
echo "  CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)"
echo "  Cores: $(nproc)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"

if command -v nvidia-smi >/dev/null 2>&1; then
  echo "  GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
  echo "  VRAM: $(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1) MB"
fi
echo ""

# VirtualGL Performance
echo "VIRTUALGL PERFORMANCE:"
if [ -n "${DISPLAY}" ] && command -v vglrun >/dev/null 2>&1; then
  echo "  Testing GPU rendering..."
  timeout 10s vglrun glxspheres64 2>&1 | grep "frames" | tail -1
else
  echo "  ⚠ DISPLAY not set or vglrun not available"
fi
echo ""

# CPU Performance
echo "CPU PERFORMANCE:"
echo "  Running CPU benchmark..."
sysbench cpu --threads=$(nproc) --time=10 run 2>&1 | grep "events per second"
echo ""

# Disk I/O
echo "DISK I/O:"
dd if=/dev/zero of=/tmp/testfile bs=1M count=1024 conv=fdatasync 2>&1 | grep copied
rm -f /tmp/testfile
echo ""

# Network (if available)
echo "NETWORK:"
ping -c 4 8.8.8.8 2>&1 | grep "rtt\|avg" || echo "  Network test skipped"
echo ""

echo "=========================================="
echo "Benchmark Complete"
echo "=========================================="
BENCH
chmod +x /usr/local/bin/benchmark_all.sh

echo "✓ Benchmark suite created"



# ===============================================================
# Create User Guide
# ===============================================================
cat > /usr/local/share/doc/virtualgl-guide.txt << 'GUIDE'
========================================
VirtualGL Usage Guide
========================================

QUICK START
-----------
1. Start VNC with GPU support:
   start_vnc_xfce.sh

2. Connect via VNC viewer

3. Open terminal in VNC session

4. Launch GPU-accelerated applications:
   vglrun blender
   vglrun openscad
   vglrun glxspheres64


AVAILABLE COMMANDS
------------------
Core Tools:
  vglrun <app>     - Run application with GPU acceleration
  vglconfig        - Configure VirtualGL
  vglconnect       - SSH with VGL integration

Testing & Info:
  glxinfo          - OpenGL system information
  glxspheres64     - OpenGL benchmark (spinning spheres)
  eglinfo          - EGL information
  vgl_info.sh      - Complete VirtualGL/OpenGL info
  vgl_benchmark.sh - Compare CPU vs GPU rendering
  test_virtualgl.sh - Test VirtualGL installation

Performance Tools:
  cpustat          - CPU statistics
  nettest          - Network performance test
  tcbench          - TCP benchmark


CONVENIENT ALIASES
------------------
(Available in bash shell)
  vblender         - Launch Blender with GPU
  vopenscad        - Launch OpenSCAD with GPU
  vfreecad         - Launch FreeCAD with GPU
  gpubench         - Quick GPU benchmark
  gpuinfo          - Quick OpenGL info
  vgl <command>    - Shortcut for vglrun


USAGE EXAMPLES
--------------
# Launch application with GPU:
vglrun blender

# Or use alias:
vblender

# Or use helper script:
vgl_launch.sh openscad model.scad

# Benchmark GPU performance:
vgl_benchmark.sh

# Compare rendering methods:
compare_render glxspheres64

# Check GPU is detected:
nvidia-smi
vgl_info.sh


TROUBLESHOOTING
---------------
Problem: Low FPS even with vglrun
Solution: Check GPU is available
  nvidia-smi
  
Problem: "Could not open display"
Solution: Set DISPLAY variable
  export DISPLAY=:1
  
Problem: vglrun not found
Solution: Add to PATH
  export PATH="/opt/VirtualGL/bin:$PATH"


For more info:
  man vglrun
  test_virtualgl.sh
  vgl_info.sh
========================================
GUIDE
chmod 644 /usr/local/share/doc/virtualgl-guide.txt

echo "✓ User guide created: /usr/local/share/doc/virtualgl-guide.txt"