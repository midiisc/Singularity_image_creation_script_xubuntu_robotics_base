# V2 Planned Improvements

This document tracks planned improvements for version 2 of the Singularity image creation script. These improvements will be implemented one by one after V1 (with current features) is successfully compiled, tested, and released.

## Planned Steps

### 1. libMETIS Compilation with Flags

**Status:** Planned  
**Priority:** High  
**Description:** Compile libMETIS from source with optimized compilation flags instead of using the system package (`libmetis-dev`).

**Current State:**
- METIS is currently installed via apt package manager (`libmetis-dev`)
- Used by GTSAM with `GTSAM_USE_SYSTEM_METIS=ON`
- Used by Ceres with `EIGENMETIS=ON`
- No custom compilation flags applied

**Proposed Implementation:**
- Download METIS source code (latest stable version)
- Compile with optimization flags matching other libraries:
  - `-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops`
  - Link-time optimization (`-flto`)
  - OpenMP support
- Install to `/usr/local` to replace system package
- Update build script to use compiled version instead of apt package
- Ensure compatibility with GTSAM and Ceres dependencies

**Benefits:**
- Better performance through optimized compilation
- Consistent optimization flags across all compiled libraries
- Full control over build configuration
- Potential for better integration with other optimized libraries

**Dependencies:**
- METIS source code
- CMake or Make build system (depending on METIS version)
- OpenMP support
- Math library (`-lm`)

**Notes:**
- Need to verify METIS version compatibility with GTSAM and Ceres
- May need to adjust GTSAM flags if switching from system to compiled METIS
- Consider METIS version used by bundled GTSAM METIS (currently 5.1.0 based on analysis)

---

*Additional improvements will be added to this document as they are planned.*

