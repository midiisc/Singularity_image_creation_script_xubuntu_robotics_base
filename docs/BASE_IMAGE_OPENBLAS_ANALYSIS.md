# Base Image OpenBLAS Analysis Report

**Date:** $(date)  
**Base Image:** `osrf/ros:jazzy-desktop-full-noble`  
**Analysis Method:** Docker container inspection

---

## Executive Summary

✅ **OpenBLAS is NOT installed in the base image**  
✅ **Reference BLAS implementation is used (libblas3)**  
✅ **Safe to install OpenBLAS - no conflicts expected**  
✅ **Alternatives system available for seamless switching**

---

## 1. Current BLAS Implementation

### Packages Installed
- **libblas3** (3.12.0-3build1.1) - Netlib reference BLAS implementation
- **libblas-dev** (3.12.0-3build1.1) - Development headers
- **liblapack3** (3.12.0-3build1.1) - Netlib reference LAPACK
- **liblapack-dev** (3.12.0-3build1.1) - Development headers

### Library Files
- **Actual library:** `/usr/lib/x86_64-linux-gnu/blas/libblas.so.3.12.0` (662KB)
- **Symlink chain:**
  - `/usr/lib/x86_64-linux-gnu/libblas.so.3` → `/etc/alternatives/libblas.so.3-x86_64-linux-gnu`
  - `/etc/alternatives/libblas.so.3-x86_64-linux-gnu` → `/usr/lib/x86_64-linux-gnu/blas/libblas.so.3.12.0`

### Alternatives System
✅ **Active and configured:**
- `/etc/alternatives/libblas.so.3-x86_64-linux-gnu` → Reference BLAS
- `/etc/alternatives/liblapack.so.3-x86_64-linux-gnu` → Reference LAPACK

---

## 2. Packages Linked to BLAS/LAPACK

### Critical Packages (Already Linked)
1. **OpenCV Libraries** (libopencv-core406t64, libopencv_ml, libopencv_objdetect, etc.)
   - All linked to `libblas.so.3` and `liblapack.so.3`
   - Will automatically use OpenBLAS after alternatives update

2. **Python NumPy/Scipy**
   - `python3-numpy` depends on `libblas3 | libblas.so.3`
   - `python3-scipy` depends on `libblas3 | libblas.so.3` and `liblapack3 | liblapack.so.3`
   - Will automatically use OpenBLAS after alternatives update

3. **Other Packages**
   - `libarmadillo12` - Linear algebra library
   - `libsuperlu6` - Sparse matrix library
   - `libarpack2t64` - Eigenvalue computation
   - `liblbfgsb0` - Optimization library

---

## 3. Safety Analysis

### ✅ Why It's Safe to Replace with OpenBLAS

1. **No OpenBLAS Installed**
   - Zero OpenBLAS packages in base image
   - No conflicts possible

2. **Alternatives System**
   - Ubuntu's alternatives system allows switching BLAS implementations
   - Packages depend on interface (`libblas.so.3`), not implementation
   - Safe to add OpenBLAS and make it default

3. **Reference BLAS Remains**
   - We don't remove reference BLAS
   - Can switch back if needed: `update-alternatives --config libblas.so.3-x86_64-linux-gnu`

4. **No Recompilation Needed**
   - Existing binaries use `libblas.so.3` (interface)
   - Will automatically link to OpenBLAS after alternatives update
   - No need to recompile OpenCV, NumPy, Scipy, etc.

5. **Package Dependencies**
   - Packages specify `libblas3 | libblas.so.3` (flexible)
   - OpenBLAS provides `libblas.so.3` interface
   - No dependency conflicts

---

## 4. Recommended Strategy

### Phase 1: Install Prerequisites (Early)
```bash
# Install build tools and dependencies
apt-get install -y --no-install-recommends \
    gcc g++ gfortran make cmake \
    libomp-dev \
    liblapack-dev liblapacke-dev \
    perl git wget curl
```

### Phase 2: Compile OpenBLAS
```bash
# Download OpenBLAS v0.3.30
# Compile with DYNAMIC_ARCH=1
# Install to /usr/local
```

### Phase 3: Update Alternatives System
```bash
# Add OpenBLAS to alternatives system
update-alternatives --install /usr/lib/x86_64-linux-gnu/libblas.so.3 \
    libblas.so.3-x86_64-linux-gnu \
    /usr/local/lib/libopenblas.so.0 100

update-alternatives --install /usr/lib/x86_64-linux-gnu/liblapack.so.3 \
    liblapack.so.3-x86_64-linux-gnu \
    /usr/local/lib/libopenblas.so.0 100
```

### Phase 4: Configure Library Paths
```bash
# Update ldconfig
echo "/usr/local/lib" > /etc/ld.so.conf.d/openblas-custom.conf
ldconfig

# Set environment variables (for compilation)
export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
```

### Phase 5: APT Pinning (Prevent Reinstallation)
```bash
# Prevent APT from installing system OpenBLAS
cat > /etc/apt/preferences.d/openblas-protect <<EOF
Package: libopenblas-dev libopenblas64-dev libopenblas0-pthread libopenblas0-serial
Pin: release *
Pin-Priority: -1
EOF
```

### Phase 6: Verify
```bash
# Verify OpenBLAS is being used
update-alternatives --display libblas.so.3-x86_64-linux-gnu
ldconfig -p | grep openblas
ldd /usr/lib/x86_64-linux-gnu/libopencv_core.so.406 | grep blas
```

---

## 5. Implementation Notes

### Timing
- **Execute BEFORE any other package installations** (after APT setup)
- **Before PHASE 1** (Foundational System Libraries)
- **After BLOCK 6.12A** (APT-ARIA wrapper setup)

### Benefits
1. **Performance:** OpenBLAS is 5-10x faster than reference BLAS
2. **Portability:** DYNAMIC_ARCH=1 enables CPU detection at runtime
3. **Compatibility:** All existing packages will automatically use OpenBLAS
4. **Safety:** Can revert via alternatives system if needed

### Risks
- **Low Risk:** Alternatives system provides rollback capability
- **No Breaking Changes:** All packages use standard BLAS interface
- **No Recompilation:** Existing binaries work immediately

---

## 6. Verification Checklist

After installation, verify:
- [ ] OpenBLAS library exists at `/usr/local/lib/libopenblas.so.0`
- [ ] Alternatives system points to OpenBLAS
- [ ] `ldconfig -p | grep openblas` shows OpenBLAS
- [ ] OpenCV libraries link to OpenBLAS (check with `ldd`)
- [ ] NumPy/Scipy can import and use BLAS
- [ ] DYNAMIC_ARCH support verified (check with `strings`)
- [ ] APT pinning prevents OpenBLAS reinstallation
- [ ] All existing packages still work

---

## 7. Rollback Plan

If issues occur:
```bash
# Switch back to reference BLAS
update-alternatives --config libblas.so.3-x86_64-linux-gnu
# Select reference BLAS option
ldconfig
```

---

## Conclusion

✅ **Safe to proceed with OpenBLAS installation**  
✅ **No conflicts with existing packages**  
✅ **Seamless integration via alternatives system**  
✅ **No recompilation required**  
✅ **Easy rollback if needed**

**Recommended Action:** Proceed with OpenBLAS compilation and installation as the FIRST step after APT setup, before any other package installations.

