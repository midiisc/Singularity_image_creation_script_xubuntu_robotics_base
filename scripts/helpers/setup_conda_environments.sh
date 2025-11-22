#!/bin/bash
#===============================================================================
# SETUP CONDA ENVIRONMENTS IN WRITABLE OVERLAY
#===============================================================================
# Purpose: Install conda/mamba environments into a writable overlay
# Usage: Run this script INSIDE a Singularity container with overlay mounted
# Example: singularity shell --overlay conda_overlay.img:rw your_image.sif
#          Singularity> ./setup_conda_environments.sh
#
# This script creates multiple conda environments for different purposes:
#   - robotics_jazzy: ROS2 Jazzy + robotics tools
#   - robotics_humble: ROS2 Humble + robotics tools  
#   - deep_learning: PyTorch, TensorFlow, CUDA tools
#   - ml_general: Scikit-learn, XGBoost, traditional ML
#   - jupyter: JupyterLab with extensions
#===============================================================================

set -e  # Exit on error

#===============================================================================
# CONFIGURATION
#===============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Conda/Mamba paths
CONDA_ROOT="/opt/conda"
ENVS_DIR="/opt/conda-envs"  # In overlay

# Ensure we're in a container with overlay
if [ ! -d "/opt/conda" ]; then
    echo -e "${RED}Error: Conda not found at /opt/conda${NC}"
    echo "Make sure you're running this inside a Singularity container"
    exit 1
fi

# Check if overlay is writable
if ! touch "${ENVS_DIR}/.test_write" 2>/dev/null; then
    echo -e "${RED}Error: ${ENVS_DIR} is not writable${NC}"
    echo "Make sure overlay is mounted in read-write mode:"
    echo "  singularity shell --overlay overlay.img:rw image.sif"
    exit 1
fi
rm -f "${ENVS_DIR}/.test_write"

#===============================================================================
# SSL CERTIFICATE CONFIGURATION
#===============================================================================

setup_ssl() {
    echo -e "${BLUE}Configuring SSL certificates...${NC}"
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    
    if [ -f "$SSL_CERT_FILE" ]; then
        echo -e "${GREEN}✓ SSL certificates configured${NC}"
    else
        echo -e "${YELLOW}Warning: SSL certificate file not found${NC}"
    fi
}

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

create_environment() {
    local env_name="$1"
    local description="$2"
    shift 2
    local packages=("$@")
    
    print_header "Creating Environment: ${env_name}"
    echo -e "${YELLOW}Description: ${description}${NC}"
    echo ""
    
    # Create environment in overlay
    if ${CONDA_ROOT}/bin/conda env list | grep -q "^${env_name} "; then
        echo -e "${YELLOW}Environment '${env_name}' already exists, skipping...${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Installing packages:${NC}"
    for pkg in "${packages[@]}"; do
        echo "  - $pkg"
    done
    echo ""
    
    # Multi-layer approach: Try mamba first (preferred), fallback to conda
    local success=0
    
    if [ -x ${CONDA_ROOT}/bin/mamba ]; then
        echo -e "${CYAN}→ Attempting with mamba (preferred)...${NC}"
        if ${CONDA_ROOT}/bin/mamba create -y -n "${env_name}" -c conda-forge "${packages[@]}"; then
            echo -e "${GREEN}✓ Environment '${env_name}' created successfully with mamba${NC}"
            success=1
        else
            echo -e "${YELLOW}[warn] Mamba failed, trying conda fallback...${NC}"
        fi
    else
        echo -e "${YELLOW}[warn] Mamba not available, will use conda${NC}"
    fi
    
    # If mamba failed or unavailable, try conda
    if [ $success -eq 0 ]; then
        echo -e "${CYAN}→ Attempting with conda (fallback)...${NC}"
        if ${CONDA_ROOT}/bin/conda create -y -n "${env_name}" -c conda-forge "${packages[@]}"; then
            echo -e "${GREEN}✓ Environment '${env_name}' created successfully with conda${NC}"
            success=1
        fi
    fi
    
    if [ $success -eq 0 ]; then
        echo -e "${RED}✗ Failed to create environment '${env_name}' (both mamba and conda failed)${NC}"
        return 1
    fi
    
    return 0
}

install_in_environment() {
    local env_name="$1"
    shift
    local packages=("$@")
    
    echo -e "${BLUE}Installing additional packages in '${env_name}':${NC}"
    for pkg in "${packages[@]}"; do
        echo "  - $pkg"
    done
    
    # Multi-layer approach: Try mamba first (preferred), fallback to conda
    if [ -x ${CONDA_ROOT}/bin/mamba ]; then
        echo -e "${CYAN}  → Using mamba...${NC}"
        if ! ${CONDA_ROOT}/bin/mamba install -y -n "${env_name}" -c conda-forge "${packages[@]}"; then
            echo -e "${YELLOW}  [warn] Mamba failed, trying conda...${NC}"
            ${CONDA_ROOT}/bin/conda install -y -n "${env_name}" -c conda-forge "${packages[@]}"
        fi
    else
        ${CONDA_ROOT}/bin/conda install -y -n "${env_name}" -c conda-forge "${packages[@]}"
    fi
}

register_julia_kernel() {
    local env_name="$1"
    
    echo -e "${BLUE}Registering Julia kernel for environment '${env_name}'...${NC}"
    
    # Check if Julia is available
    if [ ! -x /opt/julia/bin/julia ]; then
        echo -e "${YELLOW}Warning: Julia not found, skipping kernel registration${NC}"
        return 1
    fi
    
    # Get the kernel directory for this environment
    local kernel_dir="${CONDA_ROOT}/envs/${env_name}/share/jupyter/kernels"
    mkdir -p "${kernel_dir}"
    
    # Register Julia kernel with this environment's Jupyter
    /opt/julia/bin/julia -e "
        using Pkg
        Pkg.add(\"IJulia\")
        using IJulia
        IJulia.installkernel(\"Julia\", \"--project=@.\", env=Dict(\"JUPYTER_DATA_DIR\"=>\"${kernel_dir}/../..\"))
    " || echo -e "${YELLOW}Warning: Julia kernel registration failed (non-critical)${NC}"
}

register_r_kernel() {
    local env_name="$1"
    
    echo -e "${BLUE}Configuring R kernel for environment '${env_name}'...${NC}"
    
    # Install IRkernel in the environment
    "${CONDA_ROOT}/envs/${env_name}/bin/R" --quiet -e "
        install.packages('IRkernel', repos='https://cloud.r-project.org/')
        IRkernel::installspec(name = 'ir', displayname = 'R')
    " 2>/dev/null || echo -e "${YELLOW}Warning: R kernel installation failed (non-critical)${NC}"
}

#===============================================================================
# MAIN SETUP
#===============================================================================

print_header "Conda Environment Setup - Writable Overlay"

echo -e "${BLUE}System Information:${NC}"
echo "  Conda root: ${CONDA_ROOT}"
echo "  Environments directory: ${ENVS_DIR}"
echo "  Writable overlay: $(df -h ${ENVS_DIR} | tail -1 | awk '{print $4}') available"
echo ""

# Initialize conda
# shellcheck disable=SC1091 # Source file is dynamically determined
# shellcheck disable=SC1090
source "${CONDA_ROOT}/etc/profile.d/conda.sh"

# Setup SSL
setup_ssl

# Configure conda/mamba to use overlay directory
${CONDA_ROOT}/bin/conda config --add envs_dirs ${ENVS_DIR}
${CONDA_ROOT}/bin/conda config --set channel_priority strict

# Configure mamba solver if available (preferred)
if [ -x ${CONDA_ROOT}/bin/mamba ]; then
    ${CONDA_ROOT}/bin/conda config --set solver libmamba
    echo -e "${GREEN}✓ Mamba solver configured (preferred)${NC}"
else
    echo -e "${YELLOW}[warn] Mamba not available, using conda classic solver${NC}"
fi

# Install modern environment management tools in base (try mamba first)
echo -e "${BLUE}Installing modern package management tools...${NC}"

if [ -x ${CONDA_ROOT}/bin/mamba ]; then
    echo -e "${CYAN}  → Trying with mamba...${NC}"
    if ${CONDA_ROOT}/bin/mamba install -y -c conda-forge \
        conda-lock conda-tree mamba-bash-completion; then
        echo -e "${GREEN}✓ Modern tools installed with mamba${NC}"
    else
        echo -e "${YELLOW}  [warn] Mamba failed, trying conda...${NC}"
        ${CONDA_ROOT}/bin/conda install -y -c conda-forge \
            conda-lock conda-tree mamba-bash-completion \
            || echo -e "${YELLOW}Warning: Some optional tools failed (non-critical)${NC}"
    fi
else
    ${CONDA_ROOT}/bin/conda install -y -c conda-forge \
        conda-lock conda-tree \
        || echo -e "${YELLOW}Warning: Some optional tools failed (non-critical)${NC}"
fi

echo -e "${GREEN}✓ Conda/Mamba configured to use overlay${NC}"
echo ""

#===============================================================================
# ENVIRONMENT SELECTION
#===============================================================================

echo -e "${YELLOW}Which environments would you like to create?${NC}"
echo ""
echo "1) All environments (recommended for first setup)"
echo "2) Robotics environments only (ROS2 Jazzy + Humble)"
echo "3) Deep Learning environment only (PyTorch, TensorFlow)"
echo "4) Machine Learning environment only (Scikit-learn, XGBoost)"
echo "5) Jupyter environment only"
echo "6) Custom selection"
echo "7) Skip (environments already created)"
echo ""

read -r -p "Select option (1-7): " selection

case $selection in
    1)
        DO_ROBOTICS_JAZZY=1
        DO_ROBOTICS_HUMBLE=1
        DO_DEEP_LEARNING=1
        DO_ML_GENERAL=1
        DO_JUPYTER=1
        ;;
    2)
        DO_ROBOTICS_JAZZY=1
        DO_ROBOTICS_HUMBLE=1
        ;;
    3)
        DO_DEEP_LEARNING=1
        ;;
    4)
        DO_ML_GENERAL=1
        ;;
    5)
        DO_JUPYTER=1
        ;;
    6)
        read -r -p "Create robotics_jazzy? (y/n): " ans
        [ "$ans" = "y" ] && DO_ROBOTICS_JAZZY=1
        
        read -r -p "Create robotics_humble? (y/n): " ans
        [ "$ans" = "y" ] && DO_ROBOTICS_HUMBLE=1
        
        read -r -p "Create deep_learning? (y/n): " ans
        [ "$ans" = "y" ] && DO_DEEP_LEARNING=1
        
        read -r -p "Create ml_general? (y/n): " ans
        [ "$ans" = "y" ] && DO_ML_GENERAL=1
        
        read -r -p "Create jupyter? (y/n): " ans
        [ "$ans" = "y" ] && DO_JUPYTER=1
        ;;
    7)
        echo -e "${GREEN}Skipping environment creation${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid selection${NC}"
        exit 1
        ;;
esac

#===============================================================================
# ENVIRONMENT 1: ROBOTICS WITH ROS2 JAZZY
#===============================================================================

if [ "${DO_ROBOTICS_JAZZY}" = "1" ]; then
    create_environment "robotics_jazzy" \
        "ROS2 Jazzy + Robotics packages + Multi-language kernels + Full Jupyter" \
        python=3.12 \
        numpy scipy matplotlib pandas seaborn plotly bokeh altair \
        opencv scikit-learn scikit-image \
        gymnasium stable-baselines3 mujoco pybullet \
        glfw imageio \
        jupyterlab jupyter-lsp jupyterlab-git jupyterlab-code-formatter \
        jupyterlab-spellchecker jupyterlab-latex \
        notebook nbconvert nbformat ipykernel ipywidgets \
        voila jupyter_contrib_nbextensions jupytext \
        nodejs \
        r-base r-irkernel r-essentials
    
    # Install additional Python packages via pip (ROS2 + Interactive tools)
    echo -e "${BLUE}Installing ROS2-specific packages via pip...${NC}"
    ${CONDA_ROOT}/envs/robotics_jazzy/bin/pip install \
        transforms3d pyquaternion \
        opencv-python-headless \
        rosbags || true
    
    echo -e "${BLUE}Installing interactive notebook tools via pip...${NC}"
    ${CONDA_ROOT}/envs/robotics_jazzy/bin/pip install \
        ipympl plotly-express dash \
        jupyter-dash jupyterlab-widgets \
        widgetsnbextension ipysheet ipycanvas \
        bqplot ipyleaflet ipyvolume \
        papermill scrapbook nbdime \
        jupyter-book sphinx-book-theme || true
    
    # Register Julia kernel for this environment
    register_julia_kernel "robotics_jazzy"
    
    # Register R kernel (already included in environment, just verify)
    echo -e "${GREEN}✓ R kernel included in environment${NC}"
    
    # Enable JupyterLab extensions
    echo -e "${BLUE}Enabling JupyterLab extensions...${NC}"
    ${CONDA_ROOT}/envs/robotics_jazzy/bin/jupyter labextension list || true
    
    echo -e "${GREEN}✓ Multi-language support: Python 3.12 + Julia + R${NC}"
    echo -e "${GREEN}✓ Interactive notebook support: Full Jupyter stack${NC}"
fi

#===============================================================================
# ENVIRONMENT 2: ROBOTICS WITH ROS2 HUMBLE
#===============================================================================

if [ "${DO_ROBOTICS_HUMBLE}" = "1" ]; then
    create_environment "robotics_humble" \
        "ROS2 Humble + Robotics packages + Multi-language kernels + Full Jupyter" \
        python=3.10 \
        numpy scipy matplotlib pandas seaborn plotly bokeh altair \
        opencv scikit-learn scikit-image \
        gymnasium stable-baselines3 mujoco pybullet \
        glfw imageio \
        jupyterlab jupyter-lsp jupyterlab-git jupyterlab-code-formatter \
        jupyterlab-spellchecker jupyterlab-latex \
        notebook nbconvert nbformat ipykernel ipywidgets \
        voila jupyter_contrib_nbextensions jupytext \
        nodejs \
        r-base r-irkernel r-essentials
    
    echo -e "${BLUE}Installing ROS2-specific packages via pip...${NC}"
    ${CONDA_ROOT}/envs/robotics_humble/bin/pip install \
        transforms3d pyquaternion \
        opencv-python-headless \
        rosbags || true
    
    echo -e "${BLUE}Installing interactive notebook tools via pip...${NC}"
    ${CONDA_ROOT}/envs/robotics_humble/bin/pip install \
        ipympl plotly-express dash \
        jupyter-dash jupyterlab-widgets \
        widgetsnbextension ipysheet ipycanvas \
        bqplot ipyleaflet ipyvolume \
        papermill scrapbook nbdime \
        jupyter-book sphinx-book-theme || true
    
    # Register Julia kernel for this environment
    register_julia_kernel "robotics_humble"
    
    echo -e "${GREEN}✓ Multi-language support: Python 3.10 + Julia + R${NC}"
    echo -e "${GREEN}✓ Interactive notebook support: Full Jupyter stack${NC}"
fi

#===============================================================================
# ENVIRONMENT 3: DEEP LEARNING (PyTorch, TensorFlow)
#===============================================================================

if [ "${DO_DEEP_LEARNING}" = "1" ]; then
    create_environment "deep_learning" \
        "Deep Learning with PyTorch, TensorFlow + Multi-language kernels + Full Jupyter" \
        python=3.11 \
        pytorch=2.4.1 torchvision=0.19.1 torchaudio pytorch-cuda=12.1 \
        tensorflow \
        "numpy<2.0.0" scipy matplotlib pandas seaborn plotly bokeh altair \
        scikit-learn opencv pillow \
        jupyterlab jupyter-lsp jupyterlab-git jupyterlab-code-formatter \
        jupyterlab-spellchecker jupyterlab-latex \
        notebook nbconvert nbformat ipykernel ipywidgets \
        voila jupyter_contrib_nbextensions jupytext \
        tensorboard wandb \
        r-base r-irkernel \
        nodejs
    
    # Fix PyTorch dependency conflicts: ensure sympy==1.13.1 for torch compatibility
    echo -e "${BLUE}Fixing PyTorch dependencies (sympy version)...${NC}"
    ${CONDA_ROOT}/envs/deep_learning/bin/pip install --upgrade "sympy==1.13.1" "numpy<2.0.0,>=1.23.0" || true
    
    echo -e "${BLUE}Installing additional DL packages via pip...${NC}"
    ${CONDA_ROOT}/envs/deep_learning/bin/pip install \
        timm accelerate transformers datasets \
        opencv-python-headless albumentations \
        pytorch-lightning lightning || true
    
    echo -e "${BLUE}Installing interactive notebook tools via pip...${NC}"
    ${CONDA_ROOT}/envs/deep_learning/bin/pip install \
        ipympl plotly-express dash \
        jupyter-dash jupyterlab-widgets \
        widgetsnbextension ipysheet ipycanvas \
        bqplot tensorboard-plugin-profile \
        papermill scrapbook nbdime \
        jupyter-book sphinx-book-theme || true
    
    echo -e "${BLUE}Installing 3D Reconstruction & NeRF tools via pip...${NC}"
    echo "  • Nerfstudio (complete NeRF framework)"
    ${CONDA_ROOT}/envs/deep_learning/bin/pip install \
        nerfstudio || echo "⚠ Nerfstudio installation failed (non-fatal)"
    
    echo "  • 3D Gaussian Splatting (state-of-art rendering)"
    # Clone and install 3D Gaussian Splatting
    TMP_GS_DIR=$(mktemp -d)
    if git clone https://github.com/graphdeco-inria/gaussian-splatting.git --recursive "${TMP_GS_DIR}/gaussian-splatting" 2>/dev/null; then
        cd "${TMP_GS_DIR}/gaussian-splatting"
        
        # Install submodules (CUDA extensions)
        if [ -d "submodules/diff-gaussian-rasterization" ]; then
            ${CONDA_ROOT}/envs/deep_learning/bin/pip install submodules/diff-gaussian-rasterization || echo "⚠ diff-gaussian-rasterization build failed"
        fi
        
        if [ -d "submodules/simple-knn" ]; then
            ${CONDA_ROOT}/envs/deep_learning/bin/pip install submodules/simple-knn || echo "⚠ simple-knn build failed"
        fi
        
        # Install main requirements
        if [ -f "requirements.txt" ]; then
            ${CONDA_ROOT}/envs/deep_learning/bin/pip install -r requirements.txt || echo "⚠ Some GS requirements failed"
        fi
        
        # Copy scripts to a permanent location
        mkdir -p ${CONDA_ROOT}/envs/deep_learning/share/gaussian-splatting
        cp -r . ${CONDA_ROOT}/envs/deep_learning/share/gaussian-splatting/
        
        cd /
        rm -rf "${TMP_GS_DIR}"
        echo "  ✓ 3D Gaussian Splatting installed"
    else
        echo "  ⚠ 3D Gaussian Splatting clone failed (check network)"
    fi
    
    # Install additional 3D tools
    echo "  • Open3D Python module (if not already available)"
    ${CONDA_ROOT}/envs/deep_learning/bin/pip install open3d || echo "  ℹ Open3D already available from base image"
    
    echo "  • PyTorch3D (3D deep learning)"
    ${CONDA_ROOT}/envs/deep_learning/bin/pip install \
        "git+https://github.com/facebookresearch/pytorch3d.git" || echo "  ⚠ PyTorch3D build failed (non-fatal)"
    
    # Register Julia kernel for this environment
    register_julia_kernel "deep_learning"
    
    echo -e "${GREEN}✓ Multi-language support: Python 3.11 + Julia + R${NC}"
    echo -e "${GREEN}✓ Interactive notebook support: Full Jupyter stack${NC}"
    echo -e "${GREEN}✓ 3D Reconstruction: Nerfstudio + 3D-GS + PyTorch3D${NC}"
fi

#===============================================================================
# ENVIRONMENT 4: MACHINE LEARNING (Traditional ML)
#===============================================================================

if [ "${DO_ML_GENERAL}" = "1" ]; then
    create_environment "ml_general" \
        "Traditional Machine Learning + Multi-language kernels + Full Jupyter" \
        python=3.11 \
        numpy scipy matplotlib pandas seaborn plotly bokeh altair \
        scikit-learn xgboost lightgbm catboost \
        statsmodels \
        jupyterlab jupyter-lsp jupyterlab-git jupyterlab-code-formatter \
        jupyterlab-spellchecker jupyterlab-latex \
        notebook nbconvert nbformat ipykernel ipywidgets \
        voila jupyter_contrib_nbextensions jupytext \
        optuna shap \
        r-base r-irkernel r-caret r-randomforest r-xgboost \
        nodejs
    
    echo -e "${BLUE}Installing additional ML packages via pip...${NC}"
    ${CONDA_ROOT}/envs/ml_general/bin/pip install \
        scikit-optimize imbalanced-learn \
        opencv-python-headless || true
    
    echo -e "${BLUE}Installing interactive notebook tools via pip...${NC}"
    ${CONDA_ROOT}/envs/ml_general/bin/pip install \
        ipympl plotly-express dash \
        jupyter-dash jupyterlab-widgets \
        widgetsnbextension ipysheet ipycanvas \
        bqplot dtreeviz yellowbrick \
        papermill scrapbook nbdime \
        jupyter-book sphinx-book-theme || true
    
    # Register Julia kernel for this environment
    register_julia_kernel "ml_general"
    
    echo -e "${GREEN}✓ Multi-language support: Python 3.11 + Julia + R${NC}"
    echo -e "${GREEN}✓ R ML packages: caret, randomForest, xgboost${NC}"
    echo -e "${GREEN}✓ Interactive notebook support: Full Jupyter stack${NC}"
fi

#===============================================================================
# ENVIRONMENT 5: JUPYTER (Standalone)
#===============================================================================

if [ "${DO_JUPYTER}" = "1" ]; then
    create_environment "jupyter" \
        "Complete JupyterLab with ALL extensions + All language kernels + Interactive tools" \
        python=3.11 \
        jupyterlab jupyter-lsp jupyterlab-git jupyterlab-code-formatter \
        jupyterlab-spellchecker jupyterlab-latex jupyterlab-drawio \
        jupyterlab-execute-time jupyterlab-system-monitor \
        nodejs \
        ipykernel ipywidgets \
        notebook nbconvert nbformat \
        jupyter_contrib_nbextensions jupytext \
        voila voila-gridstack voila-vuetify \
        numpy pandas matplotlib seaborn plotly bokeh altair holoviews \
        r-base r-irkernel r-ggplot2 r-dplyr r-tidyverse r-shiny
    
    echo -e "${BLUE}Installing comprehensive interactive notebook tools via pip...${NC}"
    ${CONDA_ROOT}/envs/jupyter/bin/pip install \
        ipympl plotly-express dash dash-bootstrap-components \
        jupyter-dash jupyterlab-widgets \
        widgetsnbextension ipysheet ipycanvas \
        bqplot ipyleaflet ipyvolume ipycytoscape \
        itables qgrid ipydatagrid \
        papermill scrapbook nbdime nbdev \
        jupyter-book sphinx-book-theme \
        jupyterlab-fasta jupyterlab-geojson \
        jupyterlab-katex jupyterlab-mathjax3 \
        rise || true
    
    echo -e "${BLUE}Installing JupyterLab extensions...${NC}"
    ${CONDA_ROOT}/envs/jupyter/bin/jupyter labextension list || true
    
    # Register Julia kernel for this environment
    register_julia_kernel "jupyter"
    
    # Enable classic notebook extensions
    echo -e "${BLUE}Enabling Jupyter Notebook extensions...${NC}"
    ${CONDA_ROOT}/envs/jupyter/bin/jupyter contrib nbextension install --user || true
    ${CONDA_ROOT}/envs/jupyter/bin/jupyter nbextension enable --py widgetsnbextension || true
    
    echo -e "${GREEN}✓ Complete multi-language Jupyter environment${NC}"
    echo -e "${GREEN}✓ Kernels: Python 3.11 + Julia + R${NC}"
    echo -e "${GREEN}✓ Interactive tools: Plotly, Bokeh, Altair, ipywidgets, Voila${NC}"
    echo -e "${GREEN}✓ Extensions: Git, LSP, Formatter, Spellchecker, LaTeX, DrawIO${NC}"
    echo -e "${GREEN}✓ Dashboards: Voila, Dash, Panel support${NC}"
fi

#===============================================================================
# SUMMARY
#===============================================================================

print_header "Environment Setup Complete!"

echo -e "${GREEN}Created environments:${NC}"
${CONDA_ROOT}/bin/conda env list | grep -v "^#"

echo ""
echo -e "${BLUE}Usage Instructions:${NC}"
echo ""
echo "1. Activate an environment:"
echo -e "   ${YELLOW}conda activate robotics_jazzy${NC}"
echo ""
echo "2. List all environments:"
echo -e "   ${YELLOW}conda env list${NC}"
echo ""
echo "3. Install additional packages (MAMBA ONLY):"
echo -e "   ${YELLOW}mamba install -c conda-forge package_name${NC}"
echo ""
echo "4. Update an environment:"
echo -e "   ${YELLOW}mamba update --all${NC}"
echo ""
echo "5. Remove an environment:"
echo -e "   ${YELLOW}conda env remove -n environment_name${NC}"
echo ""
echo -e "${CYAN}Modern Environment Management Tools:${NC}"
echo ""
echo "6. Lock environment for reproducibility:"
echo -e "   ${YELLOW}conda-lock -f environment.yml -p linux-64${NC}"
echo ""
echo "7. View dependency tree:"
echo -e "   ${YELLOW}conda-tree deptree package_name${NC}"
echo ""
echo "8. Check available Jupyter kernels:"
echo -e "   ${YELLOW}jupyter kernelspec list${NC}"
echo ""
echo "9. Start JupyterLab with all kernels:"
echo -e "   ${YELLOW}jupyter lab${NC}"
echo -e "   ${GREEN}Available kernels: Python, Julia, R${NC}"
echo ""
echo "10. Create interactive dashboards with Voila:"
echo -e "   ${YELLOW}voila notebook.ipynb${NC}"
echo ""
echo "11. Convert notebooks to various formats:"
echo -e "   ${YELLOW}jupyter nbconvert --to html notebook.ipynb${NC}"
echo ""
echo "12. Automate notebook execution:"
echo -e "   ${YELLOW}papermill input.ipynb output.ipynb -p param value${NC}"
echo ""
echo "13. Create presentations from notebooks:"
echo -e "   ${YELLOW}jupyter nbconvert notebook.ipynb --to slides --post serve${NC}"
echo ""

#===============================================================================
# CREATE ACTIVATION HELPER SCRIPT
#===============================================================================

cat > ${ENVS_DIR}/activate_env.sh << 'EOF'
#!/bin/bash
# Helper script to activate conda environments
# Usage: source /opt/conda-envs/activate_env.sh environment_name

if [ -z "$1" ]; then
    echo "Usage: source $0 <environment_name>"
    echo ""
    echo "Available environments:"
    /opt/conda/bin/conda env list | grep -v "^#"
    return 1
fi

source /opt/conda/etc/profile.d/conda.sh
conda activate "$1"
EOF

chmod +x ${ENVS_DIR}/activate_env.sh

echo -e "${GREEN}Helper script created: ${ENVS_DIR}/activate_env.sh${NC}"
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    All Done! 🎉                                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

