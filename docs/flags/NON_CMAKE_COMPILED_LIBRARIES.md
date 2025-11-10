# Non-CMake Compiled Libraries

This document lists libraries that are compiled from source in the build script but **do not use CMake** as their build system. These libraries use different build systems (Python setup.py/pip, Rust cargo, etc.).

---

## Python Packages (Built from Source)

### PyCeres
- **Version:** 2.5 (from config.sh: `PYCERES_VERSION`)
- **Source Repository:** https://github.com/cvg/pyceres
- **Build System:** Python setup.py / pip
- **Build Command:** `pip3 install --no-deps .`
- **Dependencies:** Compiled Ceres Solver (must be in `/usr/local` or `LD_LIBRARY_PATH`)
- **Location in Script:** Lines 3133-3185
- **Notes:** 
  - Built from source to link against compiled Ceres
  - Required by PyCOLMAP for cost functions feature
  - Uses `--no-deps` to avoid overwriting compiled libraries
  - Fallback to PyPI if source build fails

**Build Flags (Python/pip):**
- `--no-deps`: Don't install dependencies (protects compiled libraries)
- `--no-binary opencv-python,opencv-contrib-python`: Prevent OpenCV binary overwrites
- Environment variables:
  - `LD_LIBRARY_PATH=/usr/local/lib`: Points to compiled Ceres
  - `CMAKE_PREFIX_PATH=/usr/local`: Helps find Ceres via CMake

### PyCOLMAP
- **Version:** Matches COLMAP version (3.12.6)
- **Source Repository:** Bundled with COLMAP repository
- **Build System:** Python setup.py / pip
- **Build Command:** `python3 -m pip install --no-deps .`
- **Dependencies:** Compiled COLMAP (must be in `/usr/local` or `LD_LIBRARY_PATH`), optional PyCeres
- **Location in Script:** Lines 4893-5006
- **Notes:**
  - Built from source if found in COLMAP repository (`pycolmap/`, `python/pycolmap/`, or `scripts/python/pycolmap/`)
  - Falls back to PyPI if source not found
  - Uses `--no-binary opencv-python,opencv-contrib-python` to protect compiled OpenCV
  - PyCeres (optional) enables cost functions feature

**Build Flags (Python/pip):**
- `--no-deps`: Don't install dependencies (protects compiled libraries)
- `--no-binary opencv-python,opencv-contrib-python`: Prevent OpenCV binary overwrites
- Environment variables:
  - `LD_LIBRARY_PATH=/usr/local/lib`: Points to compiled COLMAP
  - `CMAKE_PREFIX_PATH=/usr/local`: Helps find COLMAP via CMake

**Python Build Configuration:**
- `setup.py` or `pyproject.toml` in PyCOLMAP directory
- No CMake flags - uses Python standard build system

---

## Rust CLI Tools (Built from Source)

All Rust tools are compiled from source using `cargo install`. These tools **do not use CMake**.

### Tools List (from config.sh):
1. **bat** - Version: `0.24.0` (`BAT_VERSION`)
   - Syntax highlighting for cat
   - Build time: ~3-4 minutes

2. **fd-find** - Version: `9.0.0` (`FD_VERSION`)
   - Fast find alternative
   - Build time: ~2-3 minutes
   - Binary name: `fd`

3. **ripgrep** - Version: `14.1.0` (`RIPGREP_VERSION`)
   - Fast grep alternative
   - Build time: ~2-3 minutes
   - Binary name: `rg`

4. **eza** - Version: `0.17.3` (`EZA_VERSION`)
   - Modern ls replacement
   - Build time: ~2-3 minutes

5. **bottom** - Version: `0.9.6` (`BOTTOM_VERSION`)
   - System monitor
   - Build time: ~4-5 minutes
   - Binary name: `btm`

6. **procs** - Version: `0.14.4` (`PROCS_VERSION`)
   - Modern ps replacement
   - Build time: ~2-3 minutes

7. **du-dust** - Version: `1.1.1` (`DU_DUST_VERSION`)
   - Disk usage tool
   - Build time: ~2-3 minutes
   - Binary name: `dust`

8. **zellij** - Version: `0.40.1` (`ZELLIJ_VERSION`)
   - Terminal multiplexer
   - Build time: ~5-7 minutes
   - Has binary fallback if compilation fails

9. **ox** - Version: `latest` (no version pinning)
   - Text editor
   - Has binary fallback if compilation fails

**Build System:** Cargo (Rust package manager)  
**Build Command:** `cargo install <package> --version <version> --root /opt/rust/tools --locked`  
**Location in Script:** Lines 10570-10732

**Cargo Build Flags:**
- `--version <VERSION>`: Install specific version
- `--root /opt/rust/tools`: Installation root directory
- `--locked`: Use exact versions from Cargo.lock (respects lock file)
- Environment variables:
  - `RUSTUP_HOME=/opt/rust/rustup`: Rust toolchain home
  - `CARGO_HOME=/opt/rust/cargo`: Cargo home directory
  - `RUSTFLAGS="-C target-cpu=x86-64 -C opt-level=2"`: Optimization flags

**Cargo Configuration:**
- No CMake flags - uses Cargo.toml and Cargo.lock
- Compilation optimization via `RUSTFLAGS`
- Fallback to pre-built binaries for some tools (zellij, ox)

---

## Summary

### CMake-Based Libraries (Documented in this directory)
1. ✅ Ceres Solver 2.2.0 - `CERES_SOLVER_2.2.0_CMAKE_FLAGS_DOCUMENTATION.md`
2. ✅ g2o (latest) - `G2O_20241228_CMAKE_FLAGS_DOCUMENTATION.md`
3. ✅ GTSAM 4.2.0 - `GTSAM_4.2.0_CMAKE_FLAGS_DOCUMENTATION.md`
4. ✅ OpenCV 4.12.0 - `OPENCV_4.12.0_CMAKE_FLAGS_DOCUMENTATION.md`
5. ✅ COLMAP 3.12.6 - `COLMAP_3.12.6_CMAKE_FLAGS_DOCUMENTATION.md`
6. ✅ Open3D 0.19.0 - `OPEN3D_0.19.0_CMAKE_FLAGS_DOCUMENTATION.md`
7. ✅ nvtop (latest) - `NVTOP_LATEST_CMAKE_FLAGS_DOCUMENTATION.md`
8. ✅ libcxxwrap-julia (latest) - `LIBCXXWRAP_JULIA_LATEST_CMAKE_FLAGS_DOCUMENTATION.md`

### Non-CMake Libraries (This Document)
1. ⚠️ PyCeres 2.5 - Python/setup.py (no CMake flags)
2. ⚠️ PyCOLMAP 3.12.6 - Python/setup.py (no CMake flags)
3. ⚠️ Rust CLI Tools (9 tools) - Cargo (no CMake flags)

---

## Notes

1. **Python Packages:** PyCeres and PyCOLMAP use Python's standard build system (`setup.py` or `pyproject.toml`), not CMake. They have no CMake flags to document.

2. **Rust Tools:** All Rust CLI tools use Cargo, which has its own configuration system (`Cargo.toml`, `Cargo.lock`). They have no CMake flags.

3. **Build Optimization:** 
   - Python packages: Use `--no-deps` and `--no-binary` flags to protect compiled libraries
   - Rust tools: Use `RUSTFLAGS` for optimization (`-C target-cpu=x86-64 -C opt-level=2`)

4. **Dependency Linking:** Both Python packages and Rust tools link against compiled CMake libraries (Ceres, COLMAP) via `LD_LIBRARY_PATH` and `CMAKE_PREFIX_PATH`.

---

**Document Version:** 1.0  
**Last Updated:** Generated from build script analysis

