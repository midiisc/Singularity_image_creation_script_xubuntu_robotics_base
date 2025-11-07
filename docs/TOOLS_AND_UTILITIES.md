# Tools and Utilities Guide

This document provides comprehensive information about all preinstalled tools, utilities, and scripts in the Xubuntu Robotics Base image, including how to configure and use them.

## Table of Contents

1. [Remote Desktop Tools](#remote-desktop-tools)
2. [GPU Acceleration & VirtualGL](#gpu-acceleration--virtualgl)
3. [Monitoring & System Tools](#monitoring--system-tools)
4. [ROS 2 Tools](#ros-2-tools)
5. [3D Reconstruction Tools](#3d-reconstruction-tools)
6. [Development & CLI Tools](#development--cli-tools)
7. [Conda/Mamba Environment Management](#condamamba-environment-management)
8. [Julia Environment](#julia-environment)
9. [Zenoh Middleware](#zenoh-middleware)
10. [Audio Support](#audio-support)

---

## Remote Desktop Tools

### Overview

The image includes comprehensive remote desktop infrastructure with multiple VNC servers and web-based access options, all optimized for GPU-accelerated applications.

### Available VNC Servers

#### 1. TurboVNC (Recommended)
- **Script**: `start_vnc_xfce.sh`
- **Best for**: GPU-accelerated applications, high-performance rendering
- **Features**:
  - Optimized JPEG compression
  - Built specifically for VirtualGL integration
  - Multiple performance profiles
  - Built-in webserver on port 5800+N (where N is display number)

**Usage:**
```bash
# Basic start (display :1, port 5901)
start_vnc_xfce.sh

# Custom display and geometry
start_vnc_xfce.sh --vnc-display 2 --geometry 2560x1440

# With VirtualGL debugging
start_vnc_xfce.sh --vgl-debug --vgl-verbose

# Disable VirtualGL integration
start_vnc_xfce.sh --no-vgl
```

**Environment Variables:**
- `VNC_DISPLAY_NUM` - Display number (default: 1)
- `VNC_GEOM` - Resolution (default: 1920x1080)
- `VNC_DEPTH` - Color depth (default: 24)
- `WEB_PORT` - noVNC web port (default: 6081)
- `VGL_DISPLAY` - VirtualGL display (auto-detected by default)

#### 2. TurboVNC Ultimate (Enhanced)
- **Script**: `start_vnc_ultimate.sh`
- **Best for**: Maximum performance with all features
- **Features**: All TurboVNC features + automatic optimization + performance monitoring + audio support

**Usage:**
```bash
start_vnc_ultimate.sh
```

#### 3. TigerVNC (Alternative)
- **Script**: `start_vnc_tigervnc.sh` (if installed)
- **Best for**: Different compression algorithm, some prefer image quality

#### 4. KasmVNC (Modern Web VNC)
- **Script**: `start_kasmvnc.sh`
- **Best for**: Modern web-first VNC, container-optimized
- **Features**: Built-in web interface, optimized for containerized environments

**Usage:**
```bash
start_kasmvnc.sh [display] [web-port]
```

#### 5. x11vnc (Screen Sharing)
- **Script**: `start_x11vnc.sh`
- **Best for**: Attaching to existing X session, debugging
- **Features**: Can share existing display, useful for troubleshooting

**Usage:**
```bash
# Attach to display :1
start_x11vnc.sh :1

# Custom port
start_x11vnc.sh :1 5900
```

### Interactive VNC Selection Tool

**Script**: `vnc_select.sh`

Provides an interactive menu to compare and select VNC servers:

```bash
vnc_select.sh              # Show comparison and recommendations
vnc_select.sh turbovnc     # Start TurboVNC
vnc_select.sh ultimate      # Start Ultimate version
vnc_select.sh kasm         # Start KasmVNC
vnc_select.sh x11vnc       # Start x11vnc
```

### noVNC (Web-Based Access)

noVNC provides browser-based access to VNC sessions without installing a client.

**Automatic Start**: Included in `start_vnc_xfce.sh` and `start_vnc_ultimate.sh`

**Manual Start**:
```bash
# Basic noVNC (requires running VNC server)
websockify --web /usr/local/share/novnc 6081 localhost:5901

# Advanced noVNC with token authentication
start_novnc_advanced.sh :1 6081
```

**Access**: Open browser to `http://localhost:6081` (or your forwarded port)

### Setting Up VNC Password

Before starting VNC, you must set a password:

```bash
vncpasswd
```

This creates `~/.vnc/passwd` which is used for authentication.

### Connection Methods

#### For HPC/Cluster Environments (Two-Stage SSH Tunneling)

**Stage 1** - From your local machine to login node:
```bash
ssh -L 5901:localhost:5901 -L 6081:localhost:6081 -p 22 username@login-node.example.com
```

**Stage 2** - From login node to compute node:
```bash
ssh -L 5901:localhost:5901 -L 6081:localhost:6081 username@compute-node
```

**Direct Two-Stage Tunnel** (single command):
```bash
ssh -J username@login-node.example.com:22 -L 5901:localhost:5901 -L 6081:localhost:6081 username@compute-node
```

Then connect VNC viewer to `localhost:5901` or open browser to `http://localhost:6081`

#### SSL Tunneling Script

**Script**: `vnc_ssl_tunnel.sh`

Automates SSL tunneling setup for secure connections:

```bash
vnc_ssl_tunnel.sh [display] [web-port]
```

### VNC Management Commands

```bash
# List running VNC servers
vncserver -list

# Kill specific VNC server
vncserver -kill :1

# Kill all VNC servers
vncserver -kill :*  # or
pkill -f vnc

# View VNC logs
tail -f ~/.vnc/*.log

# Monitor VNC server status
vnc_monitor.sh
```

### VNC Configuration Files

- `~/.vnc/xstartup` - Startup script for VNC session (auto-created by launcher)
- `~/.vnc/passwd` - VNC password file (created by `vncpasswd`)
- `/etc/turbovncserver.conf.d/performance.conf` - Global TurboVNC performance settings
- `~/.vnc/turbovncserver.conf` - User-specific TurboVNC configuration

### Performance Tuning

**Script**: `turbovnc_tune.sh`

Interactive tool to optimize TurboVNC settings based on network conditions:

```bash
turbovnc_tune.sh
```

Options:
- **Fast Network**: High quality, high bandwidth
- **Balanced**: Good default for most cases
- **Slow Network**: Maximum compression, lower bandwidth

### Unified Remote Desktop Launcher

**Script**: `remote_desktop.sh`

Interactive menu launcher for all remote desktop options:

```bash
remote_desktop.sh
```

Menu includes:
- VNC server selection
- Application streaming options (Xpra)
- Utilities (monitoring, testing, recording)
- GPU benchmarking

---

## GPU Acceleration & VirtualGL

### Overview

VirtualGL allows GPU-accelerated OpenGL applications to run over VNC connections by intercepting OpenGL calls and rendering on the GPU.

### Core VirtualGL Commands

#### vglrun - Run Applications with GPU Acceleration

```bash
# Basic usage
vglrun <application>

# Examples
vglrun glxspheres64          # Test OpenGL rendering
vglrun firefox               # GPU-accelerated Firefox
vglrun glxgears              # Test OpenGL performance
vglrun blender               # 3D modeling with GPU
```

#### Performance Profiles

Three pre-configured performance profiles:

```bash
# High performance (fast network, best quality)
vglrun-fast <application>

# Balanced (default, good for most cases)
vglrun-balanced <application>

# Low bandwidth (slow network, optimized compression)
vglrun-lowbw <application>
```

### VirtualGL Configuration

#### Environment Variables

```bash
# Display to use for GPU rendering
export VGL_DISPLAY=:1

# Compression method: proxy (default), jpeg, rgb, yuv
export VGL_COMPRESS=proxy

# Readback method: sync (default), async, memcpy
export VGL_READBACK=sync

# Enable FPS display
export VGL_FPS=1

# Verbose output
export VGL_VERBOSE=1

# Debug mode (enables verbose + logging)
export VGL_DEBUG=1

# Force specific GPU (if multiple GPUs)
export VGL_FORCE_GPU=0

# Disable VirtualGL logo overlay
export VGL_LOGO=0
```

#### Configuration Files

Profiles are stored in `/usr/local/etc/virtualgl/`:
- `vglrun-fast.conf` - High performance settings
- `vglrun-balanced.conf` - Balanced settings
- `vglrun-lowbw.conf` - Low bandwidth settings

### VirtualGL Helper Scripts

#### test_virtualgl.sh - Comprehensive Testing

```bash
test_virtualgl.sh
```

Tests:
- VirtualGL installation
- Display configuration
- OpenGL information
- GPU rendering capability
- X11 authentication

#### vgl_info.sh - Display OpenGL/VirtualGL Information

```bash
vgl_info.sh
```

Shows:
- OpenGL renderer information
- VirtualGL version and status
- Display configuration
- GPU capabilities

#### vgl_benchmark.sh - Performance Testing

```bash
vgl_benchmark.sh
```

Runs GPU performance benchmarks comparing:
- Software rendering (no VirtualGL)
- GPU rendering (with VirtualGL)

#### vgl_launch.sh - Launch Applications with VirtualGL

```bash
vgl_launch.sh <application> [args...]
```

Convenience wrapper that:
- Sets up VirtualGL environment
- Launches application with proper display configuration
- Handles DISPLAY setup automatically

### Troubleshooting VirtualGL

```bash
# Check VirtualGL installation
vglrun --version

# Test OpenGL access
vglrun -d :1 glxinfo | grep "OpenGL renderer"

# Check X11 authentication
xauth list | grep $VGL_DISPLAY

# Debug mode (detailed logging)
VGL_DEBUG=1 vglrun <application>

# Test with specific display
vglrun -d :1 glxspheres64
```

### VirtualGL Integration with VNC

VirtualGL is automatically integrated when starting VNC with `start_vnc_xfce.sh`. The integration:

1. Auto-detects VNC display
2. Sets `VGL_DISPLAY` environment variable
3. Configures xstartup script for VirtualGL
4. Enables OpenGL extensions in VNC server

To disable VirtualGL integration:
```bash
start_vnc_xfce.sh --no-vgl
```

---

## Monitoring & System Tools

### GPU Monitoring

#### gpu_monitor.sh - Real-time GPU Monitoring

```bash
gpu_monitor.sh
```

Monitors:
- GPU utilization
- Memory usage
- Temperature
- Power consumption
- Process usage

### VNC Monitoring

#### vnc_monitor.sh - VNC Server Monitoring

```bash
vnc_monitor.sh
```

Displays:
- Running VNC servers
- Connection status
- Port usage
- Process information
- Resource usage

### Screen Recording

#### record_screen.sh - Record VNC Sessions

```bash
# Record display :1 to file
record_screen.sh 1 output.mp4

# Record with custom options
record_screen.sh 1 recording.mp4 --fps 30 --quality high
```

### Network Optimization

#### optimize_network.sh - Network Tuning Guide

```bash
optimize_network.sh
```

Provides documentation for TCP tuning optimizations to improve remote desktop performance.

Note: Most optimizations require host-level system changes.

### System Information

#### 3d_recon_info - 3D Reconstruction Tools Info

```bash
3d_recon_info
```

Displays information about:
- COLMAP installation and features
- Open3D version and capabilities
- Usage examples
- Documentation links

---

## ROS 2 Tools

### ROS 2 Multiterminal Launchers

Multiple terminal launchers for ROS 2 workflows:

#### ros_multiterm - Default Terminal Launcher

```bash
ros_multiterm [command1] [command2] ...
```

Opens multiple terminals for ROS 2 development.

#### ros_multiterm_tmux - TMUX-based Launcher

```bash
ros_multiterm_tmux [command1] [command2] ...
```

Uses TMUX for terminal multiplexing.

#### ros_multiterm_zellij - Zellij-based Launcher

```bash
ros_multiterm_zellij [command1] [command2] ...
```

Uses Zellij (modern terminal multiplexer) for layout management.

#### ros_multiterm_zellij_zenoh - With Zenoh Integration

```bash
ros_multiterm_zellij_zenoh [command1] [command2] ...
```

Combines ROS 2 terminals with Zenoh middleware setup.

### ROS 2 Setup

The image includes ROS 2 Jazzy Desktop Full. To set up:

```bash
# Source ROS 2 setup
source /opt/ros/jazzy/setup.bash

# Or for fish shell
source /opt/ros/jazzy/setup.fish

# Verify installation
ros2 --help
```

---

## 3D Reconstruction Tools

### COLMAP

**Version**: 3.12.6  
**Features**: CUDA-accelerated, CGAL meshing, OpenMP parallelization

**Usage:**
```bash
# Launch GUI
colmap gui

# Automatic reconstruction pipeline
colmap automatic_reconstructor \
    --workspace_path /path/to/images \
    --image_path /path/to/images \
    --output_path /path/to/output

# Manual pipeline
colmap feature_extractor \
    --database_path database.db \
    --image_path /path/to/images

colmap exhaustive_matcher \
    --database_path database.db

colmap mapper \
    --database_path database.db \
    --image_path /path/to/images \
    --output_path /path/to/output
```

**Python Bindings (PyCOLMAP)**:
```python
import pycolmap
reconstruction = pycolmap.Reconstruction("/path/to/output")
```

### Open3D

**Version**: 0.19.0  
**Features**: CUDA 12 acceleration, comprehensive Python bindings

**Python Usage:**
```python
import open3d as o3d

# Read point cloud
pcd = o3d.io.read_point_cloud("pointcloud.ply")

# Visualize
o3d.visualization.draw_geometries([pcd])

# Process point cloud
pcd_down = pcd.voxel_down_sample(voxel_size=0.01)
```

**Cached Wheels**:
Built Open3D wheels are cached and can be reused:
```bash
# Check cached wheels (shown at build completion)
# Location: ${CACHE_ROOT}/wheels/open3d/

# Install from cache in conda environment
pip install --no-deps "${CACHE_ROOT}/wheels/open3d/open3d*.whl"
```

**Jupyter Extension**:
If built with `BUILD_JUPYTER_EXTENSION=ON`, Open3D includes Jupyter notebook widgets for interactive 3D visualization.

---

## Development & CLI Tools

### Modern Rust-based CLI Tools

All tools are built from source with optimizations:

- **bat** (0.26.0) - Syntax-highlighting cat replacement
  ```bash
  bat file.txt
  bat --list-themes
  ```

- **fd** (10.3.0) - Fast alternative to find
  ```bash
  fd "pattern" /search/path
  fd -e py  # Find all Python files
  ```

- **ripgrep** (15.1.0) - Fast recursive grep
  ```bash
  rg "pattern" /search/path
  rg -t py "import"  # Search in Python files
  ```

- **eza** (0.23.4) - Modern ls replacement
  ```bash
  eza -l --tree
  eza --long --git
  ```

- **bottom** (0.11.2) - System monitor
  ```bash
  btm
  btm --basic  # Basic mode
  ```

- **procs** (0.14.10) - Modern ps replacement
  ```bash
  procs
  procs python  # Filter by process name
  ```

- **zellij** (0.43.1) - Terminal multiplexer
  ```bash
  zellij
  zellij attach <session>
  ```

- **dust** (1.2.3) - Intuitive du replacement
  ```bash
  dust
  dust /path/to/analyze
  ```

### Other Utilities

- **yq** (4.48.1) - YAML/JSON processor
  ```bash
  yq eval '.key' file.yaml
  yq eval -P file.yaml  # Pretty print
  ```

- **jq** - JSON processor
  ```bash
  jq '.key' file.json
  ```

- **FreeCAD** (1.0.2) - 3D CAD modeling
  ```bash
  FreeCAD  # Launch GUI
  ```

- **apt-aria** - APT wrapper with aria2 for faster downloads
  ```bash
  apt-aria install package-name
  ```

---

## Conda/Mamba Environment Management

### Installation Locations

- **Miniforge3**: `/opt/conda/`
- **Mamba**: Included with Miniforge3
- **Environments**: `/opt/mamba-envs/` (configurable)

### Basic Usage

```bash
# Activate base environment
source /opt/conda/etc/profile.d/conda.sh
conda activate base

# Or use mamba (faster solver)
mamba activate base

# Create new environment
conda create -n myenv python=3.12
mamba create -n myenv python=3.12

# Install packages
conda install numpy pandas
mamba install numpy pandas  # Faster

# List environments
conda env list
mamba env list

# Export environment
conda env export > environment.yml

# Create from file
conda env create -f environment.yml
```

### Conda Updates

The image automatically updates conda and mamba after installation. To manually update:

```bash
conda update -y -n base -c conda-forge conda conda-build conda-env conda-libmamba-solver
mamba update -y -n base -c conda-forge mamba
```

### Python Versions

- **System Python**: 3.12 (Ubuntu 24.04)
- **Conda Python**: Latest via Miniforge3 (defaults to Python 3.12)
- **Multiple versions**: Can create environments with different Python versions

### Package Management

```bash
# Search packages
conda search package-name
mamba search package-name

# Show package information
conda info package-name

# Install from specific channel
conda install -c conda-forge package-name

# Install from pip in conda environment
conda activate myenv
pip install package-name

# Use pip wheels from cache (e.g., Open3D)
pip install --no-deps "${CACHE_ROOT}/wheels/open3d/open3d*.whl"
```

---

## Julia Environment

### Installation

- **Julia**: `/opt/julia/`
- **Environments**: `/opt/juliaenvs/` (configurable)
- **Version**: 1.10.5 LTS

### Basic Usage

```bash
# Start Julia REPL
julia

# Run Julia script
julia script.jl

# Install packages
julia -e 'using Pkg; Pkg.add("PackageName")'

# Update packages
julia -e 'using Pkg; Pkg.update()'
```

### Package Management

```julia
using Pkg

# Add package
Pkg.add("PackageName")

# Remove package
Pkg.rm("PackageName")

# Update package
Pkg.update("PackageName")

# Activate environment
Pkg.activate("/path/to/environment")

# Instantiate environment (install dependencies)
Pkg.instantiate()
```

### CUDA Precompilation Script

**Script**: `precompile_julia_cuda.sh`

Precompiles Julia packages for CUDA to speed up first runs:

```bash
precompile_julia_cuda.sh
```

### Jupyter Integration

IJulia is installed for Jupyter notebook support:

```julia
using Pkg
Pkg.add("IJulia")
```

Then restart Jupyter and Julia kernel will be available.

---

## Zenoh Middleware

### Overview

Zenoh (version 1.6.2) provides high-performance pub/sub middleware with ROS 2 DDS bridge support.

### Installation Location

- **Zenoh**: `/opt/zenoh/`
- **ROS 2 Bridge**: Included

### Management Scripts

#### zenoh_start - Start Zenoh Router

```bash
zenoh_start [options]
```

#### zenoh_stop - Stop Zenoh Router

```bash
zenoh_stop
```

#### zenoh_status - Check Zenoh Status

```bash
zenoh_status
```

### Basic Usage

```bash
# Start Zenoh router
zenoh_start

# Check status
zenoh_status

# Stop router
zenoh_stop
```

### ROS 2 Bridge

The Zenoh ROS 2 DDS bridge plugin allows bridging ROS 2 topics through Zenoh.

---

## Audio Support

### PulseAudio

PulseAudio is installed for audio support in remote desktop sessions.

#### start_pulseaudio.sh - Start PulseAudio Server

```bash
start_pulseaudio.sh
```

Starts PulseAudio in server mode for audio forwarding over network.

### Audio in VNC

Audio support is configured in VNC xstartup scripts. For full audio support:

1. Start PulseAudio server: `start_pulseaudio.sh`
2. Use VNC server with audio extensions
3. Configure client for audio forwarding

---

## Benchmarking & Performance Testing

### benchmark_all.sh - Comprehensive Performance Suite

```bash
benchmark_all.sh
```

Tests:
- VNC server performance
- VirtualGL GPU rendering
- Network performance
- Compression effectiveness

### Individual Benchmarks

```bash
# GPU/VirtualGL benchmark
vgl_benchmark.sh

# TurboVNC tuning
turbovnc_tune.sh

# Full system benchmark
benchmark_all.sh
```

---

## Clipboard Synchronization

### vnc_clipboard_sync.sh - Clipboard Sync Tool

```bash
vnc_clipboard_sync.sh
```

Synchronizes clipboard between VNC session and local system (when using SSH tunnels).

---

## X11 Utilities

### Display Management

```bash
# List displays
xlsdisplays

# Get display information
xdpyinfo

# Test display
xwininfo -root

# X11 performance testing
x11perf
```

### X11 Diagnostic Tools

Installed tools:
- `x11-utils` - Basic X11 utilities
- `x11-xserver-utils` - X server utilities
- `x11vnc` - VNC server for existing displays
- `glxinfo` - OpenGL information
- `glxgears` - OpenGL test

---

## Vulkan Support

### test_vulkan.sh - Vulkan Testing

```bash
test_vulkan.sh
```

Tests Vulkan installation and GPU support.

---

## Application Streaming (Alternative to VNC)

### Xpra - Seamless Windows

**Script**: `start_xpra.sh`

Streams individual application windows instead of full desktop:

```bash
start_xpra.sh
```

Benefits:
- Lower bandwidth (only streamed windows)
- Seamless integration with local desktop
- Better for single applications

---

## Troubleshooting

### Common Issues

#### VNC Server Won't Start

```bash
# Check if port is in use
ss -tuln | grep 5901

# Check logs
tail -f ~/.vnc/*.log

# Verify password is set
ls -la ~/.vnc/passwd

# Check X11 permissions
ls -la /tmp/.X11-unix/
```

#### VirtualGL Not Working

```bash
# Test VirtualGL
test_virtualgl.sh

# Check display
echo $VGL_DISPLAY
vglrun -d :1 glxinfo

# Verify GPU access
nvidia-smi
```

#### Conda/Mamba Issues

```bash
# Reinitialize conda
source /opt/conda/etc/profile.d/conda.sh

# Update conda
conda update conda

# Clean cache
conda clean --all
```

#### Connection Issues (HPC)

```bash
# Verify SSH tunnel
ss -tuln | grep 5901

# Test local connection
vncviewer localhost:5901

# Check firewall
# (May need to request port opening from admin)
```

### Getting Help

- Check script help: `script_name.sh --help` or `script_name.sh -h`
- View logs: `~/.vnc/*.log`, `/tmp/*.log`
- Test components individually using test scripts
- Check system information: `3d_recon_info`, `vgl_info.sh`

---

## Quick Reference

### Start Remote Desktop

```bash
# Recommended: Ultimate VNC with all features
start_vnc_ultimate.sh

# Or interactive menu
remote_desktop.sh

# Or basic TurboVNC
start_vnc_xfce.sh
```

### Run GPU-Accelerated Applications

```bash
# Use VirtualGL
vglrun <application>

# Test GPU rendering
vglrun glxspheres64

# With performance profile
vglrun-fast <application>
```

### Monitor System

```bash
gpu_monitor.sh      # GPU monitoring
vnc_monitor.sh      # VNC monitoring
btm                 # System monitor (bottom)
```

### Manage Environments

```bash
# Conda/Mamba
conda activate myenv
mamba install package

# Julia
julia
# Then: using Pkg; Pkg.add("Package")
```

---

## Additional Resources

- **TurboVNC**: https://turbovnc.org/
- **VirtualGL**: https://virtualgl.org/
- **noVNC**: https://novnc.com/
- **COLMAP**: https://colmap.github.io/
- **Open3D**: http://www.open3d.org/
- **ROS 2**: https://docs.ros.org/en/jazzy/
- **Julia**: https://julialang.org/
- **Zenoh**: https://zenoh.io/

---

*Last Updated: Based on image build scripts as of current commit*

