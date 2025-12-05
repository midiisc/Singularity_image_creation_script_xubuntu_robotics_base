#!/bin/bash
#===============================================================================
# CREATE WRITABLE OVERLAY FOR SINGULARITY/APPTAINER IMAGE
#===============================================================================
# Purpose: Create optimized ext3/ext4 overlay for ML/DNN environments
# Usage: ./create_writable_overlay.sh [size_in_GB] [overlay_name]
# Example: ./create_writable_overlay.sh 100 my_conda_overlay.img
#
# Optimized for: Conda, Mamba, PyTorch, TensorFlow, OpenCV, ROS2, apt packages
# This script creates a writable overlay that can be mounted with your
# Singularity/Apptainer image to store conda/mamba environments persistently.
#===============================================================================

set -e  # Exit on error

#===============================================================================
# CONFIGURATION
#===============================================================================

# Default overlay size (GB) - can be overridden by command-line argument
DEFAULT_SIZE_GB=100

# Default overlay filename
DEFAULT_OVERLAY_NAME="conda_overlay.img"

# Default filesystem (ext3 for maximum compatibility, ext4 for better performance)
FILESYSTEM="ext3"

# Parse command-line arguments
OVERLAY_SIZE_GB="${1:-${DEFAULT_SIZE_GB}}"
OVERLAY_NAME="${2:-${DEFAULT_OVERLAY_NAME}}"

# Calculate size in MB
OVERLAY_SIZE_MB=$((OVERLAY_SIZE_GB * 1024))

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#===============================================================================
# HEADER
#===============================================================================

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Singularity/Apptainer Overlay Creator                ║${NC}"
echo -e "${BLUE}║              Optimized for ML/DNN Environments                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Name:       ${OVERLAY_NAME}"
echo "  Size:       ${OVERLAY_SIZE_GB} GB (${OVERLAY_SIZE_MB} MB)"
echo "  Filesystem: ${FILESYSTEM}"
echo "  Optimized for: Conda, Mamba, PyTorch, TensorFlow, OpenCV, ROS2, apt packages"
echo ""

#===============================================================================
# VALIDATION
#===============================================================================

# Validate size is a number
if ! [[ "$OVERLAY_SIZE_GB" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Size must be a positive integer (GB)${NC}"
    echo "Usage: $0 [size_in_GB] [overlay_name]"
    exit 1
fi

# Check if overlay file already exists
if [ -f "${OVERLAY_NAME}" ]; then
    echo -e "${YELLOW}⚠ Overlay already exists: ${OVERLAY_NAME}${NC}"
    echo ""
    
    # Get current overlay info
    local_size=$(du -h "$OVERLAY_NAME" | cut -f1)
    local_fs=$(blkid -s TYPE -o value "$OVERLAY_NAME" 2>/dev/null || echo "unknown")
    
    echo "  Current size: ${local_size}"
    echo "  Filesystem:   ${local_fs}"
    echo ""
    
    # Prompt for deletion
    read -r -p "Delete and recreate? (y/n): " REPLY
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Keeping existing overlay${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}Removing old overlay...${NC}"
    rm -f "${OVERLAY_NAME}"
    echo -e "${GREEN}✓ Old overlay removed${NC}"
    echo ""
fi

# Check available disk space
REQUIRED_MB=$((OVERLAY_SIZE_GB * 1024))
AVAILABLE_MB=$(df -m . | tail -1 | awk '{print $4}')

if [ "$AVAILABLE_MB" -lt "$REQUIRED_MB" ]; then
    echo -e "${RED}Error: Insufficient disk space${NC}"
    echo "  Required: ${REQUIRED_MB} MB"
    echo "  Available: ${AVAILABLE_MB} MB"
    exit 1
fi

#===============================================================================
# CREATE OVERLAY
#===============================================================================

echo -e "${BLUE}Creating overlay image...${NC}"
echo ""

# Try using native Singularity/Apptainer overlay creation first
# This is the recommended method and produces optimized overlays
if command -v singularity &>/dev/null; then
    echo "Using Singularity to create overlay..."
    if singularity overlay create --size "${OVERLAY_SIZE_MB}" "${OVERLAY_NAME}"; then
        echo -e "${GREEN}✓ Overlay created successfully with Singularity${NC}"
        CREATION_METHOD="singularity"
    else
        echo -e "${YELLOW}⚠ Singularity overlay create failed, falling back to manual method${NC}"
        CREATION_METHOD="manual"
    fi
elif command -v apptainer &>/dev/null; then
    echo "Using Apptainer to create overlay..."
    if apptainer overlay create --size "${OVERLAY_SIZE_MB}" "${OVERLAY_NAME}"; then
        echo -e "${GREEN}✓ Overlay created successfully with Apptainer${NC}"
        CREATION_METHOD="apptainer"
    else
        echo -e "${YELLOW}⚠ Apptainer overlay create failed, falling back to manual method${NC}"
        CREATION_METHOD="manual"
    fi
else
    echo -e "${YELLOW}Neither singularity nor apptainer found, using manual method${NC}"
    CREATION_METHOD="manual"
fi

# Manual overlay creation (fallback)
if [ "$CREATION_METHOD" = "manual" ]; then
    echo ""
    echo "Creating overlay manually with dd + mkfs..."
    
    # Create sparse file (doesn't use full space immediately)
    dd if=/dev/zero of="${OVERLAY_NAME}" bs=1M count=0 seek=$((OVERLAY_SIZE_GB * 1024))
    
    if [ ! -f "${OVERLAY_NAME}" ]; then
        echo -e "${RED}Error: Failed to create overlay file${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Overlay file created${NC}"
    
    # Format as ext3 (compatible with Singularity overlays)
    echo "Formatting as ${FILESYSTEM} filesystem..."
    if ! mkfs."${FILESYSTEM}" -F "${OVERLAY_NAME}"; then
        echo -e "${RED}Error: Failed to format overlay${NC}"
        rm -f "${OVERLAY_NAME}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Overlay formatted${NC}"
fi

#===============================================================================
# VERIFY OVERLAY
#===============================================================================

echo ""
echo -e "${BLUE}Verifying overlay...${NC}"
echo ""

# Show filesystem details using tune2fs (if available)
echo "Filesystem details:"
if command -v tune2fs &>/dev/null; then
    tune2fs -l "${OVERLAY_NAME}" 2>/dev/null | grep -E "Filesystem volume name|Block count|Inode count|Block size|Reserved block count" | sed 's/^/  /'
else
    echo "  (tune2fs not available - skipping detailed filesystem info)"
fi

echo ""
echo "Overlay file:"
find "${OVERLAY_NAME}" -maxdepth 0 -exec ls -lh {} \; | awk '{printf "  %s  %s  %s\n", $5, $6" "$7, $9}'

# Get file info
FILE_SIZE=$(du -h "${OVERLAY_NAME}" | cut -f1)

echo ""
echo -e "${GREEN}✓ Overlay verification complete${NC}"
echo ""
echo "  File: ${OVERLAY_NAME}"
echo "  Size on disk: ${FILE_SIZE} (sparse file)"
echo "  Maximum capacity: ${OVERLAY_SIZE_GB} GB"

#===============================================================================
# CREATE DIRECTORY STRUCTURE (for manual method only)
#===============================================================================

if [ "$CREATION_METHOD" = "manual" ]; then
    echo ""
    echo -e "${BLUE}Creating conda environment directory structure...${NC}"
    
    # Mount overlay temporarily to create directory structure
    TEMP_MOUNT=$(mktemp -d)
    
    if sudo mount -o loop "${OVERLAY_NAME}" "${TEMP_MOUNT}"; then
        # Create conda directory structure
        sudo mkdir -p "${TEMP_MOUNT}/opt/conda-envs"
        sudo mkdir -p "${TEMP_MOUNT}/opt/conda/pkgs"
        sudo mkdir -p "${TEMP_MOUNT}/opt/conda/envs"
        
        # Set permissions (allow user access)
        sudo chmod -R 777 "${TEMP_MOUNT}/opt"
        
        # Unmount
        sudo umount "${TEMP_MOUNT}"
        rmdir "${TEMP_MOUNT}"
        
        echo -e "${GREEN}✓ Directory structure created${NC}"
    else
        echo -e "${YELLOW}⚠ Could not mount overlay to create directory structure${NC}"
        echo "  You can create directories manually after mounting the overlay"
    fi
else
    echo ""
    echo -e "${GREEN}✓ Native overlay creation includes directory structure${NC}"
fi

#===============================================================================
# SUCCESS MESSAGE & USAGE INSTRUCTIONS
#===============================================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  Overlay Created Successfully!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Ready to use!${NC}"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "  1. Mount with your Singularity/Apptainer image:"
echo -e "     ${YELLOW}singularity shell --overlay ${OVERLAY_NAME} your_image.sif${NC}"
echo ""
echo "  2. Inside container, set up conda environments:"
echo -e "     ${YELLOW}./setup_conda_environments.sh${NC}"
echo ""
echo "  3. Activate and use your environments:"
echo -e "     ${YELLOW}conda activate your_env_name${NC}"
echo ""

echo -e "${BLUE}Advanced Usage:${NC}"
echo ""
echo "  Read-write mode (default):"
echo -e "    ${YELLOW}singularity shell --overlay ${OVERLAY_NAME}:rw your_image.sif${NC}"
echo ""
echo "  Read-only mode (for production):"
echo -e "    ${YELLOW}singularity shell --overlay ${OVERLAY_NAME}:ro your_image.sif${NC}"
echo ""
echo "  Multiple overlays:"
echo -e "    ${YELLOW}singularity shell --overlay overlay1.img --overlay overlay2.img your_image.sif${NC}"
echo ""
echo "  With GPU support:"
echo -e "    ${YELLOW}singularity shell --nv --overlay ${OVERLAY_NAME} your_image.sif${NC}"
echo ""

echo -e "${GREEN}Overlay location: $(pwd)/${OVERLAY_NAME}${NC}"
echo ""

#===============================================================================
# SLURM JOB EXAMPLE
#===============================================================================

echo -e "${BLUE}Example SLURM Job Script for HPC:${NC}"
echo ""
cat << 'EOF'
#!/bin/bash
#SBATCH --job-name=ml_singularity
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:1
#SBATCH --mem=32G
#SBATCH --time=24:00:00

# Load Singularity/Apptainer module (if needed on your HPC)
module load singularity  # or: module load apptainer

# Set paths
IMAGE_PATH="/path/to/your_image.sif"
OVERLAY_PATH="/path/to/conda_overlay.img"

# Run with overlay and GPU support
singularity exec --nv \
    --overlay ${OVERLAY_PATH}:rw \
    ${IMAGE_PATH} \
    bash -c "source /opt/conda/etc/profile.d/conda.sh && \
             conda activate pytorch_env && \
             python train_model.py"
EOF

echo ""
echo -e "${GREEN}Setup complete! 🎉${NC}"
echo ""
echo -e "${BLUE}Tip:${NC} For ML/DNN work, consider creating environment-specific overlays:"
echo "  • ml_pytorch_overlay.img (80GB) - for PyTorch projects"
echo "  • ml_tensorflow_overlay.img (80GB) - for TensorFlow projects"
echo "  • robotics_ros2_overlay.img (100GB) - for ROS2 + ML projects"
echo ""
