# VirtualGL and TurboVNC Testing Guide

This guide provides step-by-step instructions to test VirtualGL and TurboVNC after mounting your Singularity image from commit `cb5195dd62162fa47efce3f8d202dfa4538e554f`.

## Quick Fix: Mamba Deprecation Warning

If you see mamba deprecation warnings when starting a shell (related to `/opt/conda/etc/profile.d/mamba.sh`), this is a harmless warning from mamba 2.0+. You have several options:

### Option 1: Quick Workaround (No Image Modification)

The warning occurs because `MAMBA_ROOT_PREFIX` might not be set early enough. Since it's already in the environment section, you can suppress it by ensuring it's set:

```bash
# Add to your shell startup (inside container)
export MAMBA_ROOT_PREFIX=/opt/mamba-envs
```

### Option 2: Permanent Fix (With Writable Overlay)

```bash
# 1. Create writable overlay if you don't have one
./create_writable_overlay.sh

# 2. Mount image with overlay
singularity shell --writable-tmpfs --overlay overlay.img /path/to/your/image.sif

# 3. Remove deprecated file
mv /opt/conda/etc/profile.d/mamba.sh /opt/conda/etc/profile.d/mamba.sh.deprecated
exit
```

### Option 3: Ignore It

The warning is harmless and doesn't affect functionality. You can safely ignore it.

**Note:** This fix is already included in newer builds (after the mamba 2.0+ update). For existing images from earlier commits, use one of the options above.

## Prerequisites

1. **Mounted Singularity Image**: Your image should be mounted and accessible
2. **NVIDIA GPU**: GPU should be available (for GPU-accelerated testing)
3. **NVIDIA Drivers**: Host system should have NVIDIA drivers installed
4. **X11 Forwarding**: If testing remotely, ensure X11 forwarding is configured

## Step 1: Mount/Enter the Image

```bash
# Option 1: Shell into the image with GPU support
singularity shell --nv /path/to/your/image.sif

# Option 2: Execute commands directly
singularity exec --nv /path/to/your/image.sif <command>

# Option 3: Run with bind mounts (if needed)
singularity shell --nv --bind /tmp:/tmp /path/to/your/image.sif
```

## Step 2: Verify Installation

### 2.1 Check VirtualGL Installation

```bash
# Check if VirtualGL binaries are available
singularity exec --nv /path/to/your/image.sif which vglrun
singularity exec --nv /path/to/your/image.sif vglrun --version

# Check VirtualGL location
singularity exec --nv /path/to/your/image.sif ls -la /opt/VirtualGL/bin/

# Check if symlinks exist
singularity exec --nv /path/to/your/image.sif ls -la /usr/local/bin/vgl*
```

### 2.2 Check TurboVNC Installation

```bash
# Check TurboVNC binaries
singularity exec --nv /path/to/your/image.sif which vncserver
singularity exec --nv /path/to/your/image.sif vncserver --version

# Check TurboVNC location
singularity exec --nv /path/to/your/image.sif ls -la /opt/TurboVNC/bin/

# Check if symlinks exist
singularity exec --nv /path/to/your/image.sif ls -la /usr/local/bin/vnc*
```

### 2.3 Check Environment Variables

```bash
# Check VirtualGL environment
singularity exec --nv /path/to/your/image.sif env | grep VGL_

# Check TurboVNC environment
singularity exec --nv /path/to/your/image.sif env | grep TVNC_

# Check PATH includes VirtualGL and TurboVNC
singularity exec --nv /path/to/your/image.sif echo $PATH | grep -E "(VirtualGL|TurboVNC|turbovnc)"
```

## Step 3: Run Built-in Test Script

The image includes a comprehensive test script at `/usr/local/bin/test_virtualgl.sh`:

```bash
# Run the comprehensive test
singularity exec --nv /path/to/your/image.sif test_virtualgl.sh

# If you're inside the container shell:
test_virtualgl.sh
```

This script will:
- Check VirtualGL binaries (vglrun, glxinfo, glxspheres64)
- Display VirtualGL version
- Show OpenGL information (if DISPLAY is set)
- Detect NVIDIA GPU
- Provide testing instructions

## Step 4: Test VirtualGL Without VNC (Direct GPU Access)

### 4.1 Test GPU Detection

```bash
# Check NVIDIA GPU access
singularity exec --nv /path/to/your/image.sif nvidia-smi

# Check CUDA
singularity exec --nv /path/to/your/image.sif nvcc --version

# Check OpenGL libraries
singularity exec --nv /path/to/your/image.sif ldconfig -p | grep -i opengl
```

### 4.2 Test VirtualGL Directly (requires X11 display)

If you have X11 forwarding or a local display:

```bash
# Set display (adjust :0 to your display number)
export DISPLAY=:0

# Test VirtualGL with glxinfo
singularity exec --nv -e DISPLAY=$DISPLAY /path/to/your/image.sif \
  vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version)"

# Test with glxspheres (interactive benchmark)
singularity exec --nv -e DISPLAY=$DISPLAY /path/to/your/image.sif \
  vglrun glxspheres64
```

## Step 5: Test TurboVNC Server

### 5.1 Set Up VNC Password

```bash
# Enter the container shell
singularity shell --nv /path/to/your/image.sif

# Set VNC password (inside container)
vncpasswd
# Enter your password when prompted

# Verify password file was created
ls -la ~/.vnc/passwd
```

### 5.2 Start VNC Server

```bash
# Option 1: Start VNC server directly
singularity exec --nv /path/to/your/image.sif \
  vncserver :1 -geometry 1920x1080 -depth 24

# Option 2: Check if start_vnc_xfce.sh exists
singularity exec --nv /path/to/your/image.sif \
  which start_vnc_xfce.sh

# If it exists, use it (provides better configuration)
singularity exec --nv /path/to/your/image.sif \
  start_vnc_xfce.sh
```

### 5.3 Verify VNC Server is Running

```bash
# List running VNC servers
singularity exec --nv /path/to/your/image.sif vncserver -list

# Check for Xvnc process
singularity exec --nv /path/to/your/image.sif \
  ps aux | grep -i vnc

# Check for display socket
singularity exec --nv /path/to/your/image.sif \
  ls -la /tmp/.X11-unix/
```

### 5.4 Connect to VNC Server

From your local machine (or another terminal):

```bash
# Option 1: Use TurboVNC viewer (if installed)
vncviewer <hostname>:5901

# Option 2: Use SSH tunnel (recommended for remote access)
ssh -L 5901:localhost:5901 user@remote-host

# Then connect locally
vncviewer localhost:5901

# Option 3: Use any VNC viewer
# VNC display :1 = port 5901
# VNC display :2 = port 5902
# etc.
```

## Step 6: Test VirtualGL with TurboVNC (GPU-Accelerated VNC)

### 6.1 Start VNC Server with VirtualGL Integration

The image should have VirtualGL integration configured in the VNC startup script. Check:

```bash
# Check VNC startup script
singularity exec --nv /path/to/your/image.sif \
  cat ~/.vnc/xstartup

# Look for VirtualGL-related environment variables and configuration
```

### 6.2 Test GPU Acceleration in VNC Session

Once connected to VNC:

1. **Open a terminal in the VNC session**

2. **Test without VirtualGL (software rendering)**:
   ```bash
   glxspheres64
   # Note the FPS (should be relatively low, e.g., 50-200 FPS)
   ```

3. **Test with VirtualGL (GPU-accelerated)**:
   ```bash
   vglrun glxspheres64
   # Note the FPS (should be much higher, e.g., 1000+ FPS)
   ```

4. **Compare OpenGL information**:
   ```bash
   # Without VirtualGL
   glxinfo | grep -E "OpenGL (vendor|renderer|version)"
   
   # With VirtualGL
   vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version)"
   ```

### 6.3 Test with 3D Applications

```bash
# Test with a simple 3D application
# Example: Test with glxgears (if available)
vglrun glxgears

# Or test with glxspheres (included with VirtualGL)
vglrun glxspheres64 -testduration 10
```

## Step 7: Performance Benchmarking

### 7.1 Run VirtualGL Benchmark Script

If the benchmark script exists:

```bash
# Check if benchmark script exists
singularity exec --nv /path/to/your/image.sif \
  which vgl_benchmark.sh

# Run benchmark
singularity exec --nv /path/to/your/image.sif \
  vgl_benchmark.sh
```

### 7.2 Manual Performance Comparison

```bash
# Inside VNC session, compare performance:

# Software rendering (no GPU)
time glxspheres64 -testduration 10

# GPU-accelerated (with VirtualGL)
time vglrun glxspheres64 -testduration 10
```

## Step 8: Troubleshooting

### 8.1 VirtualGL Not Found

```bash
# Check installation paths
singularity exec --nv /path/to/your/image.sif \
  ls -la /opt/VirtualGL/bin/

# Check PATH
singularity exec --nv /path/to/your/image.sif \
  echo $PATH

# Add VirtualGL to PATH manually if needed
export PATH=/opt/VirtualGL/bin:$PATH
```

### 8.2 GPU Not Detected

```bash
# Verify NVIDIA GPU access
singularity exec --nv /path/to/your/image.sif nvidia-smi

# Check CUDA
singularity exec --nv /path/to/your/image.sif nvcc --version

# Check OpenGL libraries
singularity exec --nv /path/to/your/image.sif \
  ldconfig -p | grep -i "libGL\|libEGL\|libGLX"
```

### 8.3 VNC Server Won't Start

```bash
# Check for existing VNC servers
singularity exec --nv /path/to/your/image.sif vncserver -list

# Kill existing server if needed
singularity exec --nv /path/to/your/image.sif vncserver -kill :1

# Check for lock files
singularity exec --nv /path/to/your/image.sif \
  ls -la /tmp/.X*-lock

# Check VNC log
singularity exec --nv /path/to/your/image.sif \
  cat ~/.vnc/*.log
```

### 8.4 VirtualGL Not Working in VNC

```bash
# Check VirtualGL environment variables
singularity exec --nv /path/to/your/image.sif env | grep VGL_

# Verify VGL_DISPLAY is set correctly
# Should match your VNC display (e.g., :1)

# Test VirtualGL configuration
singularity exec --nv /path/to/your/image.sif \
  vglconfig
```

### 8.5 Low Performance

```bash
# Check VirtualGL compression settings
singularity exec --nv /path/to/your/image.sif env | grep VGL_COMPRESS

# Try different compression methods:
export VGL_COMPRESS=proxy  # Best for local network
export VGL_COMPRESS=jpeg   # Good for slower networks
export VGL_COMPRESS=rgb    # Uncompressed (fastest, but high bandwidth)

# Enable verbose mode for debugging
export VGL_VERBOSE=1
export VGL_FPS=1  # Show FPS counter
```

## Step 9: Advanced Testing

### 9.1 Test with Multiple Displays

```bash
# Start multiple VNC servers
singularity exec --nv /path/to/your/image.sif vncserver :1
singularity exec --nv /path/to/your/image.sif vncserver :2

# Test VirtualGL with specific display
singularity exec --nv /path/to/your/image.sif \
  vglrun -d :1 glxspheres64
```

### 9.2 Test with Different Compression Methods

```bash
# Test different compression settings
for compress in proxy jpeg rgb; do
  echo "Testing $compress compression:"
  export VGL_COMPRESS=$compress
  singularity exec --nv /path/to/your/image.sif \
    vglrun glxspheres64 -testduration 5
done
```

### 9.3 Network Performance Testing

```bash
# Test network performance with VirtualGL
singularity exec --nv /path/to/your/image.sif \
  vglrun -c jpeg glxspheres64

# Monitor network usage
# (In another terminal)
iftop -i <network-interface>
```

## Step 10: Verification Checklist

After testing, verify:

- [ ] VirtualGL binaries are accessible (`vglrun`, `glxinfo`, `glxspheres64`)
- [ ] TurboVNC server starts successfully
- [ ] VNC connection works (can connect and see desktop)
- [ ] GPU is detected (`nvidia-smi` works)
- [ ] VirtualGL accelerates rendering (FPS difference is significant)
- [ ] OpenGL information shows GPU renderer (not software renderer)
- [ ] 3D applications run smoothly with `vglrun`
- [ ] Performance is acceptable for your use case

## Expected Results

### Successful VirtualGL Test:
- **glxspheres64 without vglrun**: 50-200 FPS (software rendering)
- **glxspheres64 with vglrun**: 1000+ FPS (GPU-accelerated)
- **OpenGL renderer**: Should show NVIDIA GPU name (not "llvmpipe" or "software")

### Successful TurboVNC Test:
- VNC server starts without errors
- Can connect to VNC session
- Desktop environment loads (XFCE4)
- Applications run normally
- No significant latency issues

## Additional Resources

- **VirtualGL Documentation**: https://virtualgl.org/Documentation
- **TurboVNC Documentation**: https://turbovnc.org/Documentation
- **VirtualGL Troubleshooting**: https://virtualgl.org/Documentation/Troubleshooting
- **TurboVNC Performance Tuning**: https://turbovnc.org/Documentation/PerformanceTuning

## Quick Reference Commands

```bash
# Quick test sequence
singularity exec --nv /path/to/your/image.sif test_virtualgl.sh
singularity exec --nv /path/to/your/image.sif vncserver :1
# Connect with VNC viewer to :1
# Inside VNC: vglrun glxspheres64

# Check everything
singularity exec --nv /path/to/your/image.sif nvidia-smi
singularity exec --nv /path/to/your/image.sif vglrun --version
singularity exec --nv /path/to/your/image.sif vncserver --version
singularity exec --nv /path/to/your/image.sif vncserver -list
```

