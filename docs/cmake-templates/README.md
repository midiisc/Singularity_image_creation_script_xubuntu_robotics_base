# CMake Configuration Templates

This directory contains standardized CMake configuration templates for HPC libraries.

## Purpose

- Ensure consistent CMake flag usage across library builds
- Prevent invalid/undocumented flags
- Document required vs optional configuration
- Provide verification commands

## Templates Available

- `ceres-solver-template.sh` - Ceres Solver 2.2.0+ configuration
- `gtsam-template.sh` - GTSAM 4.2+ configuration
- `opencv-template.sh` - OpenCV 4.x configuration
- `g2o-template.sh` - g2o configuration

## Usage

```bash
# Source the template
source docs/cmake-templates/ceres-solver-template.sh

# Use the variables in your build
cmake "${CERES_CMAKE_ARGS[@]}" ..
```

## Validation

All templates reference official documentation in `docs/flags/` and can be validated with:

```bash
./scripts/helpers/validate_cmake_flags.sh <your_script> --strict
```
