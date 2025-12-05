# Cumulative Build: Stages 0 to 10

This folder contains a self-contained cumulative build system that builds all stages from Stage 0 to Stage 10 sequentially, with each stage building on the previous stage's image.

## Folder Structure

```
cumulative_build_stages_0_to_10/
├── build_cumulative_stages_0_to_10.sh  # Main build script
├── config.sh                            # Centralized configuration (SINGLE SOURCE OF TRUTH)
├── container-scripts/                   # Container installation scripts
├── scripts/                             # Helper scripts (common_functions, cache_functions, etc.)
├── test_cases.sh                        # Test suite (runs after each stage)
├── stages/                              # Stage definition files (.def)
│   ├── stage_00_minimal.def
│   ├── stage_01_bootstrap.def
│   ├── stage_02_colors_block0.def
│   ├── stage_03_initialization.def
│   ├── stage_04_cache_mirror.def
│   ├── stage_05_cache_monitoring.def
│   ├── stage_06_package_management.def
│   ├── stage_07_build_start.def
│   ├── stage_08_mirror_apt.def
│   ├── stage_09_apt_aria.def
│   └── stage_10_mkl_installation.def
├── output/                              # Generated stage images (.sif files)
│   ├── stage_00_final.sif
│   ├── stage_01_final.sif
│   ├── ...
│   └── stage_10_final.sif
├── logs/                                 # Build logs for each stage
│   ├── stage_00_build.log
│   ├── stage_01_build.log
│   ├── ...
│   └── stage_10_build.log
├── tmp/                                  # Temporary build files
└── ../container_cache/                  # SHARED cache (same as main build scripts)
    ├── apt/archives/                    # Reuses packages from build_xubuntu_robotics_base.sh
    ├── binaries/
    ├── conda_pkgs/
    ├── debs/
    ├── julia_pkgs/
    └── wheels/
```

## Prerequisites

1. **Apptainer or Singularity** installed and available in PATH
2. **fakeroot** (recommended) or **sudo** access
3. **Sufficient disk space** (approximately 15-20 GB for all stages)
4. **Internet connection** (for downloading base images and packages)

## Usage

### Basic Usage (Recommended - Single Final Image)

```bash
cd cumulative_build_stages_0_to_10
./build_cumulative_stages_0_to_10.sh
```

**Default behavior**: Builds all stages sequentially (0 → 10) and creates **only one final SIF file**:
- Stages 0-9 are built temporarily and discarded after use
- Only `stage_10_final.sif` is saved (contains all cumulative features)
- **Saves disk space** - no intermediate images stored
- **Efficient** - only one image exists at a time during build

### Keep Intermediate Images (For Debugging)

```bash
# Build all stages and keep ALL intermediate images
./build_cumulative_stages_0_to_10.sh --keep-intermediate
```

This will:
- Build all stages sequentially (0 → 10)
- **Keep all intermediate images** (stage_00 through stage_10)
- Useful for debugging individual stages
- Uses more disk space (~15-20 GB total)

### Specify Runtime

```bash
# Use Apptainer (default) - single final image
./build_cumulative_stages_0_to_10.sh --runtime apptainer

# Use Singularity - single final image
./build_cumulative_stages_0_to_10.sh --runtime singularity

# Keep intermediate images with specific runtime
./build_cumulative_stages_0_to_10.sh --runtime apptainer --keep-intermediate
```

## How It Works

1. **Sequential Build**: The script builds stages 0 through 10 in order
2. **Cumulative**: Each stage builds on the previous stage's image:
   - Stage 0: Builds from Docker base image (`osrf/ros:jazzy-desktop-full-noble`)
   - Stage 1-10: Builds from previous stage's `.sif` image
3. **Single Final Image (Default)**:
   - Stages 0-9 are built to temporary locations
   - Each intermediate stage is deleted immediately after the next stage starts building
   - Only `stage_10_final.sif` is saved permanently
   - **Result**: One SIF file with all cumulative features
4. **Cache Reuse**: 
   - **Uses the SAME cache directory as main build scripts** (`../container_cache`)
   - **Reuses packages already downloaded** by `build_xubuntu_robotics_base.sh` and `xubuntu_robotics_base_debug.sh`
   - **No cache clearing** - existing packages are preserved and reused
   - Cache persists across all stages for faster builds
   - If cache doesn't exist, it will be created automatically
5. **Test Case Execution**:
   - Runs comprehensive test suite after each stage build
   - Tests permissions, bind mounts, functionality, and stage-specific features
   - Uses `test_cases.sh` (same as progressive build)
   - Test failures are reported but don't block build (warnings shown)
6. **Path Updates**: Automatically updates absolute paths in definition files to match the current folder location
7. **Bind Mounts**: Sets up cache and temporary directories for APT operations
8. **Logging**: Saves build logs for each stage in `logs/` directory

## Build Process

For each stage:
1. Verify previous stage image exists (for stages > 0)
2. Update paths in definition file to use current folder
3. Update `From:` path to point to previous stage image
4. Set up bind mounts for cache and temporary directories
5. Build the stage image using Apptainer/Singularity
6. Verify the generated image
7. Set correct permissions (644)

## Output

### Default Mode (Single Final Image)
After successful build:
- **Final Image Only**: `output/stage_10_final.sif` (contains all cumulative features from stages 0-10)
- **Intermediate Images**: Built temporarily and discarded (never saved to disk)
- **Build Logs**: `logs/stage_*_build.log` for each stage (logs are kept for debugging)
- **Total Size**: ~2-3 GB (only final image)
- **Disk Space Saved**: ~10-15 GB (intermediate images never written to disk)

### With `--keep-intermediate` Flag
After successful build:
- **Final Image**: `output/stage_10_final.sif` (contains all cumulative features from stages 0-10)
- **Intermediate Images**: `output/stage_00_final.sif` through `output/stage_09_final.sif` (11 total images)
- **Build Logs**: `logs/stage_*_build.log` for each stage
- **Total Size**: ~15-20 GB (all intermediate images kept)

**Note**: Use `--keep-intermediate` only if you need to debug individual stages. The default mode is more efficient and produces the same final result.

## Features Included (Stages 0-10)

- **Stage 0**: Minimal base (bind mounts, essential tools)
- **Stage 1**: Bootstrap safe environment (APT robustness, directory structure)
- **Stage 2**: Terminal colors and container scripts installation
- **Stage 3**: Initialization blocks (phase tracking, debug functions, build jobs)
- **Stage 4**: Cache and mirror functions (cache management, mirror probing)
- **Stage 5**: Cache monitoring and configuration
- **Stage 6**: Package management functions (advanced package management)
- **Stage 7**: Main build execution start (cache directory structure)
- **Stage 8**: Mirror selection and APT setup (BLOCK 9 and BLOCK 10)
- **Stage 9**: APT-ARIA wrapper setup (BLOCK 11)
- **Stage 10**: Intel oneAPI MKL Installation (BLOCK 12A)

## Continuing from Stage 10

After building stages 0-10, you can continue building additional stages:

1. Copy the next stage definition file to `stages/`
2. Modify `build_cumulative_stages_0_to_10.sh` to include the new stage
3. Or create a new script that builds from `stage_10_final.sif`

Example for Stage 11:
```bash
# Build Stage 11 from Stage 10
apptainer build --fakeroot \
  --bind ./container_cache:/container_cache:rw \
  --bind ./tmp:/tmp:rw \
  output/stage_11_final.sif \
  stages/stage_11_new_feature.def
```

## Troubleshooting

### Build Fails at a Specific Stage

1. Check the log file: `logs/stage_N_build.log`
2. Verify the previous stage image exists: `ls -lh output/stage_N-1_final.sif`
3. Check disk space: `df -h`
4. Verify all required files exist in the folder

### Path Errors

The script automatically updates paths, but if you see path errors:
1. Verify `config.sh` exists in the root of this folder
2. Check that `container-scripts/` and `scripts/` directories exist
3. Ensure all stage definition files are in `stages/`

### Permission Errors

- If using `fakeroot`: Ensure `fakeroot` is installed
- If using `sudo`: Ensure you have sudo access
- Check file permissions: `ls -la build_cumulative_stages_0_to_10.sh`

### Disk Space Issues

- Each stage image is approximately 1-2 GB
- Total space needed: ~15-20 GB for all stages
- Clean up intermediate images if needed (but keep `stage_10_final.sif`)

## Cache Reuse

**IMPORTANT**: The cumulative build script **reuses the same cache directory** as the main build scripts:
- **Cache Location**: `../container_cache/` (parent directory's `container_cache`)
- **Reuses Packages**: All packages downloaded by `build_xubuntu_robotics_base.sh` are automatically reused
- **No Clearing**: Existing cache is never cleared or modified (only new packages are added)
- **Faster Builds**: Subsequent builds are much faster due to cached packages

If you've already run `build_xubuntu_robotics_base.sh`, the cumulative build will automatically reuse all those downloaded packages!

## Notes

- **Self-Contained**: This folder contains all necessary files for building
- **Portable**: Can be copied to another machine and built there
- **Cumulative**: Each stage includes all features from previous stages
- **Tested**: All stages have been tested individually before being included
- **Cache Reuse**: Automatically reuses cache from main build scripts (no duplication)

## Next Steps

After building stages 0-10:
1. Test the final image: `apptainer exec output/stage_10_final.sif bash`
2. Verify MKL installation: Check `MKLROOT` and MKL libraries
3. Continue with Stage 11 and beyond as needed

