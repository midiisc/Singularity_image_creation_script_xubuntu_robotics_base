# Xubuntu Robotics & Perception Workflow Base Image

Production-ready Singularity/Apptainer container image for robotics research, 3D reconstruction, SLAM, and perception workflows.

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

### Optimization Flags
- **CPU**: x86-64-v3 architecture (AVX2, FMA, BMI2)
- **CUDA**: Architecture-specific optimizations (sm_86 for A6000)
- **Compiler**: -O3 -march=native -mtune=native
- **Link-Time Optimization**: Enabled where supported

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
- **`.cursor/rules/001-agent-behavior.mdc`** - AI behavior rules (file creation, planning, code review)
- **`.cursor/rules/002-repository-workflow.mdc`** - Repository workflow rules (git, branches, files)

**These files are the single source of truth and are STRICTLY ENFORCED. To update rules, edit the `.mdc` files directly.**

### Quick Reference

**Behavior Rules** (See `.cursor/rules/001-agent-behavior.mdc`):
- No automatic file creation for summaries/plans/documentation
- Inline responses only (files only when explicitly requested)
- First plan, then execute approach
- Chunked code review protocol

**Workflow Rules** (See `.cursor/rules/002-repository-workflow.mdc`):
- Beta branch only (never create new branches)
- Core files only (strict file editing restrictions)
- No git operations without explicit user approval
- Mandatory verification checklist before completing work

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

### Requesting Files

To get the AI to create a file, use explicit phrases:
- "create a file named X"
- "write this to a file"
- "save as filename.ext"
- "export to file"
- "generate documentation file"

## 📖 Documentation

For detailed usage instructions:
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
- **Last Updated**: 2025-10-27
- **Base**: Ubuntu 24.04 + ROS 2 Jazzy
- **Build System**: Singularity/Apptainer 1.x

---

**Built with ❤️ for robotics research and 3D perception workflows**

