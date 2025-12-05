# Verification Tools

This directory contains HPC verification scripts for validating MKL and CUDA setup in the container.

## Scripts

### verify-mkl-env.sh

**Purpose**: Validates that the MKL environment is set up and working.

**What it does**:
1. Checks for MKL installation (detects `MKLROOT`, sources environment if needed)
2. Compiles a test C program that calls `cblas_dgemm` (matrix multiplication)
3. Runs the test and verifies the result
4. Inspects linkage using `ldd` to confirm MKL libraries and GNU OpenMP

**Usage**:
```bash
singularity exec your_image.sif verify-mkl-env.sh
```

**Output**: Reports MKL environment status, compilation results, and linkage verification.

### verify-cuda-mkl-linkage.sh

**Purpose**: Verifies that pre-built libraries are linked against MKL, CUDA, and OpenMP.

**What it checks**:
- SuiteSparse (CHOLMOD, SPQR, GraphBLAS)
- Ceres Solver
- g2o
- OpenCV

**For each library, verifies**:
- ✅ MKL libraries (`libmkl_*`)
- ✅ CUDA libraries (`libcudart`, `libcublas`, `libcusparse`, `libcusolver`)
- ✅ OpenMP runtime (`libgomp` or `libomp`)

**Usage**:
```bash
singularity exec your_image.sif verify-cuda-mkl-linkage.sh
```

**Output**: Reports linkage status for each library with ✅/❌/⚠️ indicators.

## Installation

These scripts are automatically copied to `/usr/local/bin/` in the container during build via the `%files` section in `build_xubuntu_robotics_base.sh`.

## Use Cases

1. **HPC Deployment Validation**: Run after deploying container to HPC node
2. **Debugging**: Identify MKL/CUDA setup issues
3. **Verification**: Confirm libraries are built with MKL/CUDA support
4. **Documentation**: Serves as documentation of expected dependencies

## Integration

These scripts are part of the `container-scripts/` directory structure for consistency with other container scripts. They are:

- ✅ Version controlled with the repository
- ✅ Organized alongside other container scripts
- ✅ Installed to `/usr/local/bin/` in the container
- ✅ Made executable during container build

## Related Documentation

See `docs/VERIFICATION_SCRIPTS_INTEGRATION.md` for detailed integration information.

