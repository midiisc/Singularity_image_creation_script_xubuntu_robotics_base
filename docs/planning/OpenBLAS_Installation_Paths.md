# OpenBLAS Installation Paths Reference

## Version Information
- **OpenBLAS Version**: `v0.3.30` (released Jun 19, 2025)
- **Repository**: https://github.com/OpenMathLib/OpenBLAS
- **Release URL**: https://github.com/OpenMathLib/OpenBLAS/releases/download/v0.3.30/OpenBLAS-0.3.30.tar.gz

## Installation Prefix Structure

When OpenBLAS is built from source using `make install PREFIX=<prefix>`, the following directory structure is created:

### Default Installation Prefix
- **Test Script**: `/tmp/openblas_test_install` (for testing only)
- **Production Script**: `/usr/local` (for actual installation)

### Directory Structure

For `PREFIX=/usr/local`, files are installed to:

```
/usr/local/
├── lib/
│   ├── libopenblas.so          # Main shared library
│   ├── libopenblas.so.0         # Versioned symlink
│   ├── libopenblas.a            # Static library (if built)
│   └── pkgconfig/
│       └── openblas.pc          # pkg-config file
├── include/
│   ├── cblas.h                  # CBLAS header
│   ├── openblas_config.h        # OpenBLAS configuration header
│   └── f77blas.h                # Fortran BLAS header (if applicable)
└── bin/
    └── (no binaries for OpenBLAS)
```

## Installation Paths for Compilation Flags

### Library Paths
- **Shared Library**: `${PREFIX}/lib/libopenblas.so`
  - Example: `/usr/local/lib/libopenblas.so`
- **Library Directory**: `${PREFIX}/lib`
  - Example: `/usr/local/lib`

### Header Paths
- **Include Directory**: `${PREFIX}/include`
  - Example: `/usr/local/include`
- **Main Headers**:
  - `${PREFIX}/include/cblas.h`
  - `${PREFIX}/include/openblas_config.h`

### pkg-config Path
- **pkg-config File**: `${PREFIX}/lib/pkgconfig/openblas.pc`
  - Example: `/usr/local/lib/pkgconfig/openblas.pc`

## Usage in Compilation Flags

### For CMake Configuration

```cmake
# Library paths
-D BLAS_LIBRARIES=/usr/local/lib/libopenblas.so
-D LAPACK_LIBRARIES=/usr/local/lib/libopenblas.so
-D OpenBLAS_LIB=/usr/local/lib/libopenblas.so

# Include directory
-D OpenBLAS_INCLUDE_DIR=/usr/local/include
-D CMAKE_INCLUDE_PATH=/usr/local/include

# Vendor specification
-D BLA_VENDOR=OpenBLAS
```

### For GCC/Compiler Flags

```bash
# Include path
-I/usr/local/include

# Library path
-L/usr/local/lib

# Link library
-lopenblas
```

### For pkg-config

```bash
# Set PKG_CONFIG_PATH
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# Use pkg-config
pkg-config --cflags --libs openblas
```

### For Environment Variables

```bash
# Library path for runtime
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Include path (if needed)
export C_INCLUDE_PATH=/usr/local/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/local/include:$CPLUS_INCLUDE_PATH
```

## Build Configuration Used

The OpenBLAS build scripts use the following configuration:

```bash
make install \
    PREFIX=/usr/local \
    DYNAMIC_ARCH=1 \
    TARGET=GENERIC \
    USE_OPENMP=1 \
    NO_AFFINITY=1 \
    NUM_THREADS=64 \
    GEMM_MULTITHREAD_THRESHOLD=50 \
    BUILD_LAPACK_DEPRECATED=1 \
    NO_WARMUP=1 \
    BINARY=64 \
    CC=gcc \
    FC=gfortran \
    HOSTCC=gcc
```

## Integration with Main Build Script

### Current System OpenBLAS Paths (from apt packages)
- **Library**: `/usr/lib/x86_64-linux-gnu/libopenblas.so`
- **Headers**: `/usr/include/x86_64-linux-gnu/cblas.h` or `/usr/include/cblas.h`

### Custom Build OpenBLAS Paths (from source)
- **Library**: `/usr/local/lib/libopenblas.so`
- **Headers**: `/usr/local/include/cblas.h`

### Detection Logic

The main script should check for custom-built OpenBLAS first, then fall back to system OpenBLAS:

```bash
# Check for custom-built OpenBLAS
if [ -f "/usr/local/lib/libopenblas.so" ]; then
    OPENBLAS_LIB="/usr/local/lib/libopenblas.so"
    OPENBLAS_INCLUDE="/usr/local/include"
    echo "Using custom-built OpenBLAS from /usr/local"
# Fall back to system OpenBLAS
elif [ -f "/usr/lib/x86_64-linux-gnu/libopenblas.so" ]; then
    OPENBLAS_LIB="/usr/lib/x86_64-linux-gnu/libopenblas.so"
    OPENBLAS_INCLUDE="/usr/include/x86_64-linux-gnu"
    echo "Using system OpenBLAS"
fi
```

## Notes

1. **Version Consistency**: All build scripts use OpenBLAS `v0.3.30`
2. **DYNAMIC_ARCH**: The custom build includes `DYNAMIC_ARCH=1` for runtime CPU detection
3. **LAPACK Included**: OpenBLAS includes LAPACK, so both BLAS and LAPACK point to the same library
4. **Library Cache**: After installation, run `ldconfig` to update the library cache
5. **Priority**: Custom builds in `/usr/local` typically take precedence over system packages

## References

- OpenBLAS Installation Guide: http://www.openmathlib.org/OpenBLAS/docs/install/
- OpenBLAS Build System: http://www.openmathlib.org/OpenBLAS/docs/build_system/
- Test Script: `test_openblas_compilation.sh`
- PyTorch Build Script: `test_pytorch_compilation.sh`

