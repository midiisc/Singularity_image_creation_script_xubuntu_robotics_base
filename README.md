# Xubuntu Robotics & Perception Workflow Base Image

Production-ready Singularity/Apptainer container image for robotics research, 3D reconstruction, SLAM, and perception workflows.

<!-- Test commit to trigger GitHub Actions AI review -->

## 🚀 Quick Start

```bash
# Build the image
./build_xubuntu_robotics_base.sh

# Create writable overlay for persistent storage
./create_writable_overlay.sh

# Run on best available compute node
./run_on_best_node.sh

# Setup conda environments
./setup_conda_environments.sh
```

## 📦 Base System

- **OS**: Ubuntu 24.04 LTS (Noble Numbat)
- **Desktop**: Xubuntu (XFCE4)
- **ROS**: ROS 2 Jazzy Desktop Full
- **Python**: 3.12 (system) + Miniforge3 25.3.1
- **Architecture**: x86_64 with GPU support

## 🎯 Core Features

### Remote Desktop & Visualization
- **TurboVNC** 3.2.1 - High-performance remote desktop
- **VirtualGL** 3.1.4 - OpenGL acceleration over network
- **noVNC** 1.6.0 - Web-based VNC client
- **KasmVNC** 1.3.1 - Modern web-native VNC

### GPU & CUDA Support
- **CUDA** 12.6 (sm_86 architecture optimized for NVIDIA A6000)
- **cuDNN** 9.14.0.64
- **NVIDIA Video Codec SDK** 12.1.14
- GPU-accelerated computing for ML, reconstruction, and rendering

### Programming Languages & Environments
- **Julia** 1.10.5 LTS with dedicated package environments
- **Python** 3.12 via Miniforge3/Micromamba
- **Rust** toolchain (for modern CLI tools)
- **C/C++** GCC 13.x with optimization flags

## 📚 Robotics & SLAM Libraries

### Structure-from-Motion & 3D Reconstruction
- **COLMAP** 3.12.6 - Multi-view geometry and SfM
  - With PyCOLMAP Python bindings
  - CUDA, CGAL, and OpenMP enabled
- **Open3D** 0.19.0 - 3D data processing
  - Python 3.12 support
  - CUDA 12 acceleration
  - Comprehensive Python bindings (~95% API coverage)
- **OpenCV** 4.12.0 - Computer vision library
  - CUDA support
  - Python bindings

### Optimization & SLAM
- **Ceres Solver** 2.2.0 - Non-linear least squares optimization
- **g2o** 20241228_git - Graph optimization framework
- **GTSAM** 4.2.0 - Factor graph-based SLAM

### Robotics Frameworks
- **ROS 2 Jazzy** Desktop Full
  - Navigation2, MoveIt 2
  - Gazebo simulation
  - All standard ROS 2 tools
- **Drake** - Model-based design and verification for robotics

## 🛠️ Development Tools

### Modern CLI Tools (Rust-based)
All built from source with optimizations (updated to latest versions):
- **bat** 0.26.0 - Syntax-highlighting cat replacement
- **fd** 10.3.0 - Fast alternative to find
- **ripgrep** 15.1.0 - Fast recursive grep
- **eza** 0.23.4 - Modern ls replacement
- **bottom** 0.11.2 - System monitor
- **procs** 0.14.10 - Modern ps replacement
- **zellij** 0.43.1 - Terminal multiplexer
- **dust** 1.2.3 - Intuitive du replacement
- **ox** - Modern text editor

### Build & Validation Tools (NEW)
Repository includes automated validation and build tools:
- **CMake Flag Validator** (`scripts/helpers/validate_cmake_flags.sh`) - Validates CMake flags against official library documentation
- **CMakeCache Verifier** (`scripts/helpers/verify_cmake_cache.sh`) - Post-configuration validation (TBB, BLAS, CUDA checks)
- **Flag Documentation Generator** (`scripts/generate_flag_docs.sh`) - Auto-generates Markdown documentation for CMake flags
- **Pre-commit Hook** (`scripts/hooks/pre-commit-cmake-validator`) - Enforces CMake validation before commits

### CMake Templates (NEW)
Standardized CMake configuration templates for HPC libraries:
- **Ceres Solver Template** (`docs/cmake-templates/ceres-solver-template.sh`) - Complete Ceres 2.2.0+ configuration with TBB verification
- **GTSAM Template** (`docs/cmake-templates/gtsam-template.sh`) - Complete GTSAM 4.2+ configuration with MKL/TBB integration
- All templates include built-in verification functions and conflict detection

### Utilities
- **yq** 4.48.1 - YAML/JSON processor
- **FreeCAD** 1.0.2 - 3D CAD modeling
- Standard development tools (git, cmake, build-essential, etc.)

### Middleware
- **Zenoh** 1.6.2 - High-performance pub/sub middleware
- **Zenoh ROS 2 DDS Bridge** 1.6.2 - Plugin for ROS 2 DDS communication bridge

## 📂 Directory Structure

```
/opt/                           # Main installation directory
├── conda/                      # Miniforge3 Python environment
├── mamba-envs/                # Conda environments
├── julia/                     # Julia installation
├── juliaenvs/                 # Julia environments
├── drake/                     # Drake robotics toolkit
├── rust/                      # Rust toolchain
├── zenoh/                     # Zenoh middleware
├── turbovnc/                  # TurboVNC installation
└── VirtualGL/                 # VirtualGL installation

/usr/local/                     # System-wide installations
├── bin/                       # Compiled tools (COLMAP, etc.)
├── lib/                       # Libraries
├── include/                   # Headers
└── cuda-12.6/                 # CUDA toolkit

/container_cache/              # Build cache (only during build)
├── binaries/                  # Downloaded binaries
├── debs/                      # Debian packages
├── apt/archives/             # APT package cache
├── conda_pkgs/               # Conda package cache
├── wheels/                   # Python wheels
└── julia_pkgs/               # Julia package cache
```

## 🔧 Build System Features

### Intelligent Caching
- **APT package caching** - Reuses downloaded .deb files
- **Conda package caching** - Prevents re-downloading packages
- **Python wheels caching** - Speeds up pip installations
- **Julia package caching** - Preserves compiled Julia packages
- **Binary artifact caching** - Stores large downloads (CUDA, TurboVNC, etc.)

### Parallel Operations
- Parallel artifact downloading (4 concurrent downloads)
- Multi-core compilation (uses all available cores)
- Optimized for fast rebuilds

### Error Handling
- Checksums verified for all downloads (SHA256)
- GPG signature verification where available
- Automatic fallback to alternative download sources
- Comprehensive logging with rotation

### Automated Validation (NEW - 2025-11-12)
- **CI/CD Enforcement** - GitHub Actions workflow validates all code changes
  - Unsafe pipe pattern detection
  - CMake flag validation
  - Multi-phase logic documentation checks
  - TBB verification block checks
  - Heredoc syntax validation
  - Bash compatibility checks
  - ShellCheck linting
- **Pre-commit Hooks** - CMake validation runs before every commit
- **Post-configuration Verification** - Automatic TBB/BLAS/CUDA validation after CMake
- See `.github/workflows/prompt-validation.yml` for details

### Optimization Flags
- **CPU**: x86-64-v3 architecture (AVX2, FMA, BMI2)
- **CUDA**: Architecture-specific optimizations (sm_86 for A6000)
- **Compiler**: -O3 -march=native -mtune=native
- **Link-Time Optimization**: Enabled where supported

### MKL & TBB CMake Flags
- The build orchestration exports canonical hints that downstream CMake projects (notably GTSAM) can reuse:
  - `MKLDIR=${MKLROOT}`
  - `MKL_LIBRARIES=${MKL_BLAS_LIBRARIES}`
  - `TBBROOT=${TBBROOT:-/usr}`
- GTSAM configuration consumes the supported cache entries:
  - `-D TBB_ROOT_DIR="${TBBROOT}"`
  - `-D MKL_ROOT_DIR="${MKLROOT}"`
  - `-D MKL_INCLUDE_DIR="${MKL_INCLUDE_DIR}"`
  - `-D MKL_LIBRARIES="${MKL_BLAS_LIBRARIES}"`
- Override these variables in the environment (or via `config.sh`) if you need to point at alternative MKL/TBB installations; the script keeps them in sync so FindMKL/FindTBB operate without emitting ignored-variable warnings.
- **Automated TBB Verification** (NEW) - Post-configuration checks for Ceres, g2o, and GTSAM ensure system TBB is used (not MKL TBB)

## 🐍 Python Packages

### Scientific Computing
Via Conda/Pip:
- NumPy, SciPy, Pandas
- Matplotlib, Seaborn, Plotly
- Jupyter, IPython

### Computer Vision & 3D
- Open3D 0.19.0 (with CUDA & GUI)
- PyCOLMAP 3.12.6 (COLMAP Python bindings)
- OpenCV with Python bindings
- PyTorch, TensorFlow (optional, install as needed)

### Robotics
- ROS 2 Python packages
- Drake Python bindings
- Standard robotics utilities

## 📝 Configuration Files

All configuration centralized in `config.sh`:
- Software versions
- Download URLs
- SHA256 checksums
- Build parameters
- Cache directories
- Installation paths

## 🎮 GPU Architecture Support

Optimized for NVIDIA A6000 (sm_86), but configurable for other architectures:
- **Ada Lovelace** (RTX 40 series): sm_89
- **Ampere** (RTX 30 series, A6000, A100): sm_86
- **Hopper** (H100): sm_90
- **Turing** (RTX 20 series): sm_75

Edit `CUDA_ARCH` in `config.sh` to match your hardware.

## 📊 Resource Requirements

### Build Requirements
- **Disk Space**: 150 GB minimum
- **RAM**: 16 GB recommended (8 GB minimum)
- **CPU**: Multi-core recommended for faster builds
- **Time**: 2-4 hours (depending on hardware and cache state)

### Runtime Requirements
- **Disk Space**: 20-30 GB (image size)
- **RAM**: 8 GB minimum (16 GB+ for heavy workloads)
- **GPU**: NVIDIA GPU with CUDA 12.x support (optional but recommended)

## 🔐 Security Features

- GPG signature verification for:
  - Julia releases
  - TurboVNC packages
  - VirtualGL packages
- SHA256 checksums for all downloads
- Secure package sources (official repositories only)

## 📋 Scripts Overview

### Core Build Scripts
- **`build_xubuntu_robotics_base.sh`** - Main orchestration script
  - Validates prerequisites
  - Manages caching system
  - Downloads artifacts in parallel
  - Generates Singularity definition file
  - Builds container image

- **`xubuntu_robotics_base_post.sh`** - Container post-install script
  - Installs all software (APT, compiled sources)
  - Configures system settings
  - Sets up GPU support
  - Compiles optimized binaries (COLMAP, Ceres, g2o, etc.)

- **`config.sh`** - Centralized configuration
  - All version numbers
  - Download URLs and checksums
  - Build parameters
  - Directory paths

### Utility Scripts
- **`create_writable_overlay.sh`** - Creates persistent storage overlay
  - ext3 filesystem for persistent changes
  - Configurable size
  - Automatic mounting

- **`run_on_best_node.sh`** - SLURM job submission
  - Finds nodes with GPUs
  - Selects best available hardware
  - Handles resource allocation

- **`setup_conda_environments.sh`** - Environment setup
  - Creates specialized conda environments
  - Installs Python packages
  - Configures Jupyter kernels

## ✅ Pre-Build Checks

Before building the container, verify these system requirements:

### /tmp Directory Permissions

**Critical**: The `/tmp` directory must be world-writable for container builds to succeed.

```bash
# Check current permissions
ls -ld /tmp
# Should show: drwxrwxrwt ... /tmp (permissions ending in 'rwxrwt')

# If permissions are incorrect (e.g., drwxr-xr-x), fix with:
sudo chmod 1777 /tmp
```

**Why this matters**: Container builds require write access to `/tmp` for temporary files (especially apt-key operations). Incorrect permissions will cause build failures with "Permission denied" errors.

### Other Requirements

- **Disk Space**: 150 GB minimum available
  - The build script will automatically use a `tmp/singularity_builds` directory in the workspace (where the script is launched)
  - This leverages the home filesystem which typically has more space (e.g., 2.44 TB)
  - Falls back to `/tmp` or `${HOME}/singularity_builds` if workspace lacks space
- **RAM**: 16 GB recommended
- **Container Runtime**: Singularity or Apptainer installed

## 🚨 Known Issues & Notes

1. **Python Bindings**:
   - PyCOLMAP requires building from source (automatically handled)
   - Open3D wheel includes CUDA 12 support

2. **CUDA Version**:
   - CUDA 12.6 is installed
   - Some packages may require CUDA 11.x (install separately if needed)

3. **Build Time**:
   - First build: 3-4 hours
   - Subsequent builds with cache: 30-60 minutes

4. **Cache Management**:
   - Cache can grow to 50+ GB
   - Clean old cache versions periodically
   - Keep 2 most recent versions by default

## ❓ FAQ

### Build Fails with "Permission denied" in /tmp

**Symptom**: Build fails early with errors like "Couldn't create temporary file /tmp/apt.conf.XXXXXX" or "Permission denied" when accessing /tmp, even when running as root inside the container.

**Solution**: Check and fix /tmp permissions on the **host system**:
```bash
# Check permissions
ls -ld /tmp
# If not drwxrwxrwt, fix with:
sudo chmod 1777 /tmp
```

**Why This Happens Even As Root Inside Container**:

You're correct that only `/container_cache` is bind-mounted. Everything else, including `/tmp`, is inside the container filesystem. However, `/tmp` write failures can still occur:

1. **Base Image Permissions**: The container uses a Docker base image (`osrf/ros:jazzy-desktop-full-noble`). If the base Ubuntu/ROS Docker image has `/tmp` with incorrect permissions (e.g., 755 instead of 1777), those permissions are inherited when Singularity extracts the Docker image. The container's `/tmp` is part of the container filesystem, but it starts with whatever permissions the base image had.

2. **Build Process Host /tmp Access**: During `singularity build`, the build process itself uses the **host's `/tmp`** for:
   - Extracting Docker images
   - Creating temporary overlay filesystems
   - Storing build artifacts (controlled by `--tmpdir`, but some operations may still use host `/tmp`)
   
   If host `/tmp` has wrong permissions, the build process can fail before it even gets to the container's `/tmp`.

3. **Container /tmp Permissions**: Even though `/tmp` is inside the container (not bind-mounted), if the base image had wrong permissions, those persist. The build script fixes this automatically, but if the fix fails (e.g., due to filesystem restrictions during build), writes will fail.

**Root Cause**: 
- **Host `/tmp`**: Must be world-writable (1777) because the build process uses it
- **Container `/tmp`**: Inherits permissions from base Docker image, which may be incorrect. The build script automatically fixes container `/tmp` permissions, but if that fails, it uses alternative temp directories.

**The Fix**: 
- Fix host `/tmp` permissions: `sudo chmod 1777 /tmp`
- The container build script will automatically detect and handle `/tmp` issues inside the container by using alternative directories if needed.

### Build Fails with "Couldn't create temporary file /tmp/apt.conf.XXXXXX"

**Symptom**: Build fails with errors like "Couldn't create temporary file /tmp/apt.conf.XXXXXX" during "Updating package list" step or during signature verification/apt-key operations.

**Root Cause**: 
- **Host-side issue**: The error occurs on the **host system** when running `sudo apt-get update` (before container build starts)
- **Container-side issue**: The error can also occur inside the container during `%post` section if APT tries to use `/tmp` before alternative temp directory is configured
- **Permission issues**: User running the script may not have write access to `/tmp` when using `sudo`
- **Symlink issues**: If `container_cache` is a symlink, bind mount may not work correctly

**Solution**:
1. **Host-side fix** (automatic): The build script now configures APT on the host to use `/var/tmp/apt-temp` before running `apt-get update`
2. **Container-side fix** (automatic): The build script configures APT inside the container to use alternative temp directory at the very start of `%post` section
3. **Symlink fix** (automatic): The build script resolves `container_cache` symlink to actual path before bind mount
4. **Manual fix** (if automatic fails): 
   ```bash
   # Fix host /tmp permissions
   sudo chmod 1777 /tmp
   
   # Fix container_cache symlink target permissions
   sudo chown -R $USER:$USER /home/test/Midhun/xubuntu_base_image_complete/container_cache/
   sudo chmod -R 755 /home/test/Midhun/xubuntu_base_image_complete/container_cache/
   ```

**What the script does automatically**:
- Configures APT temp directory on host before any `apt-get` operations
- Configures APT temp directory inside container at start of `%post` section (before any APT operations)
- Resolves `container_cache` symlink to actual path before bind mount
- Creates `apt-temp` directory on host with proper permissions
- Sets `TMPDIR`, `TEMP`, and `TMP` environment variables to alternative directory
- Never falls back to `/tmp` - fails build with clear error if no alternative is available

**Prevention**: The script now proactively avoids `/tmp` for all APT operations, using alternative directories that are guaranteed to be writable.

## 🚀 Version 2 Improvements

Planned improvements for version 2 of the Singularity image creation script are documented in [`docs/planning/V2_IMPROVEMENTS.md`](docs/planning/V2_IMPROVEMENTS.md). These improvements will be implemented after V1 (with current features) is successfully compiled, tested, and released.

Key planned improvements include:
- **libMETIS Compilation with Flags**: Compile libMETIS from source with optimized compilation flags instead of using the system package, providing better performance and consistent optimization across all compiled libraries.

See the V2 improvements document for detailed implementation plans, dependencies, and benefits.

## 🤝 Contributing

When modifying the build:
1. Update version numbers in `config.sh` only
2. Test builds with clean cache to verify checksums
3. Update this README if adding new software
4. Document any new dependencies or requirements

## 🤖 AI Agent Protocols

This repository enforces strict AI agent behavior rules to maintain a clean, efficient workflow.

### ⚠️ Source of Truth

**All rules are centrally defined in `.cursor/rules/*.mdc` files**, which are automatically enforced by Cursor IDE.

- **`.cursor/rules/000-MANDATORY-READ-FIRST.mdc`** - Mandatory pre-work verification checklist (READ FIRST)
- **`.cursor/rules/MASTER-RULES-INDEX.mdc`** - **MASTER INDEX & SINGLE SOURCE OF TRUTH** - References all focused rule modules (all under 500 lines, Cursor-compliant)

**These files are the single source of truth and are STRICTLY ENFORCED. To update rules, edit the `.mdc` files directly.**

### Quick Reference

**Complete Rules** (See `.cursor/rules/MASTER-RULES-INDEX.mdc` - MASTER INDEX & SINGLE SOURCE OF TRUTH):

- **Part 1: Agent Behavior** - File creation restrictions, planning approach, code review protocol
- **Part 2: Git Workflow & Branch Management** - Feature branches, PRs, merge strategy, cleanup
- **Part 3: Code Quality & Validation** - Bash checks (auto-fix), CoT auto-trigger
- **Part 4: Automated Merge & Conflict Resolution** - Auto-merge with AI conflict resolution
- **Part 5: Cloud Agent Specifics** - Cloud agent lifecycle, multi-agent coordination
- **Part 6: User Communication & Feedback** - Immediate feedback, error reporting

**Key Features**:
- Feature branch workflow with PRs (not direct beta commits)
- Bash validation on push with auto-fixes
- Automated merge with conflict resolution
- Sequential PR merging (one at a time)
- Immediate feedback in chat

### Code Review & Validation (NEW - 2025-11-12)

**Prompt Framework**:
- **`prompts/Advanced-CoT-Multi-Agent-Prompt-PART1.md`** - Multi-agent Chain-of-Thought code review framework (split into parts for optimal context)
  - Updated with 8 new error pattern checks (D3, L5, M11, M12)
  - TBB conflict detection, CMake validation, pipe safety, multi-phase docs
- **`prompts/Code_check_prompt_manual.txt`** - Master entry point for comprehensive Bash code review checklist
  - Split into 4 parts (PART1-PART4) for optimal context window usage (each under 500 lines)
  - Loads all parts sequentially to ensure complete checklist coverage (A1-P5)
  - 80+ lines of new checks matching Advanced CoT updates

**Automated Enforcement**:
- **CI/CD Pipeline** (`.github/workflows/prompt-validation.yml`) - 7 automated checks on every PR/push
- **Pre-commit Hooks** - CMake validation runs before commits
- **Zero manual oversight** required for validation

### Configuration

**Repository-Level Rules**:
- Located in `.cursor/rules/*.mdc` files (source of truth)
- Applied automatically to all AI agents working in this repository
- Rules are enforced by Cursor IDE

**Global Settings**:
- Configure global rules in Cursor Settings → Rules → User Rules
- See `docs/GLOBAL_CURSOR_SETTINGS.md` for setup instructions
- Global rules apply to all repositories
- Repository rules can override global rules for specific behavior

### Documentation

For more information:
- **Rule Files (Source of Truth)**: `.cursor/rules/*.mdc` (automatically enforced by Cursor IDE)
- **Global Settings**: `docs/GLOBAL_CURSOR_SETTINGS.md` (setup instructions for all repositories)
- **Checks, Rules & CI/CD** (NEW): `docs/CHECKS_RULES_CICD.md` (comprehensive documentation of all automated checks, workflow rules, and CI/CD integrations)

### Requesting Files

To get the AI to create a file, use explicit phrases:
- "create a file named X"
- "write this to a file"
- "save as filename.ext"
- "export to file"
- "generate documentation file"

## 📖 Documentation

### Repository Documentation

**Build & Validation:**
- **`docs/CHECKS_RULES_CICD.md`** (NEW) - Code checks, workflow rules, and CI/CD integrations documentation
- **`docs/CMAKE_FLAG_VALIDATOR_USAGE.md`** (NEW) - CMake flag validator guide
- **`docs/cmake-templates/`** (NEW) - Standardized CMake configuration templates
- **`docs/flags/`** - Library-specific CMake flag documentation
- **`docs/planning/`** - V2 improvements and planning documents
- **`docs/testing/`** - Testing documentation

**Tools & Scripts:**
- **`scripts/helpers/validate_cmake_flags.sh`** - CMake flag validator
- **`scripts/helpers/verify_cmake_cache.sh`** - Post-configuration verifier
- **`scripts/generate_flag_docs.sh`** - Documentation generator
- **`scripts/hooks/pre-commit-cmake-validator`** - Pre-commit validation hook

**Prompts & Code Review:**
- **`prompts/Advanced-CoT-Multi-Agent-Prompt-PART1.md`** - Multi-agent CoT code review framework (master entry point, loads all parts sequentially)
- **`prompts/Code_check_prompt_manual.txt`** - Master entry point for comprehensive Bash code checklist (loads PART1-PART4 sequentially)
- **`prompts/Enhanced-Code-Review-Prompt-PART1.md`** - Enhanced code review guidelines (master entry point, loads all parts sequentially)

**AI Agent Rules:**
- **`.cursor/rules/000-MANDATORY-READ-FIRST.mdc`** - Pre-work verification checklist
- **`.cursor/rules/MASTER-RULES-INDEX.mdc`** - **MASTER INDEX & SINGLE SOURCE OF TRUTH** - References all focused rule modules

### External Documentation

For software usage instructions:
- ROS 2: https://docs.ros.org/en/jazzy/
- COLMAP: https://colmap.github.io/
- Open3D: http://www.open3d.org/
- Drake: https://drake.mit.edu/
- Singularity: https://sylabs.io/docs/

## 📄 License

Components have individual licenses:
- Base OS: Ubuntu 24.04 (various open-source licenses)
- ROS 2: Apache 2.0
- COLMAP: BSD 3-Clause
- Open3D: MIT License
- See individual software documentation for details

## 🏷️ Version Information

- **Image Version**: Based on config.sh versions
- **Last Updated**: 2025-11-12
- **Base**: Ubuntu 24.04 + ROS 2 Jazzy
- **Build System**: Singularity/Apptainer 1.x
- **Major Updates (2025-11-12)**:
  - Added automated validation tools (CMake validator, CMakeCache verifier)
  - Implemented CI/CD pipeline (7 automated checks)
  - Updated AI agent rules (feature branch workflow, cloud agent coordination)
  - Created CMake configuration templates
  - Enhanced code review prompts (8 new error pattern checks)

---

**Built with ❤️ for robotics research and 3D perception workflows**

