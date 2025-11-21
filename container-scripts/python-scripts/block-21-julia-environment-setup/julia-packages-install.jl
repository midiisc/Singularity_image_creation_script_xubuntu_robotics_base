# Purpose: Install Julia packages for Python bridge, image processing, IPC, and GPU support
# This script is executed by the main build script after Julia-Python bridge pip packages are installed
#
# Parameters: None (uses environment variables for configuration)
# Returns: 0 on success, 1 on failure
# Side effects: Installs Julia packages, configures Python integration, precompiles packages
#
# Error handling:
# - PythonCall build failures are logged as warnings but don't stop execution
# - Package installation failures will throw exceptions (should be caught by caller)
# - Precompilation failures are logged but don't stop execution

using Pkg

# Phase 1: Install Python bridge packages (required for Python integration)
# These packages use pip internally and must be installed first
Pkg.add(["PythonCall", "CondaPkg"])

# Phase 2: Configure Python backend to use system Python
# Set CondaPkg backend to Null to disable Conda (use system Python instead)
ENV["JULIA_CONDAPKG_BACKEND"] = "Null"
ENV["PYTHON"] = "/usr/bin/python3"

# Phase 3: Build PythonCall with system Python configuration
# Note: This may fail if Python development headers are missing, but we continue
# with other package installations as they don't all depend on PythonCall
try
  Pkg.build("PythonCall")
catch e
  @warn "PythonCall build failed (this may be expected if Python dev headers are missing)" exception=e
  # Continue with other installations even if PythonCall build fails
  # The caller should verify PythonCall functionality if needed
end

# Phase 4: Install image processing packages
Pkg.add([
  "Images",
  "ImageFiltering",
  "ImageFeatures",
  "VideoIO"
])

# Phase 5: Install IPC (Inter-Process Communication) packages
Pkg.add(["ZMQ", "MsgPack", "JSON3"])

# Phase 6: Install GPU packages
Pkg.add(["CUDA"])

# Phase 7: Precompile all installed packages for faster loading
# This step may fail for some packages but doesn't prevent their use
try
  Pkg.precompile()
catch e
  @warn "Some packages failed to precompile (they will still work but may load slower)" exception=e
end

