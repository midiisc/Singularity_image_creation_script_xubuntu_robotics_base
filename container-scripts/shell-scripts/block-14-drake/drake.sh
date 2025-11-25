#!/usr/bin/env bash
# shellcheck shell=bash
# Purpose: Drake Python bindings configuration
# NOTE: This is for system Python (${SYSTEM_PYTHON_VER:-3.12}) and ROS 2 ${ROS_DISTRO:-jazzy}
# will be automatically unset when Conda environments activate
# shellcheck disable=SC1083,SC2086,SC2034
export DRAKE_ROOT="${DRAKE_HOME:-/opt/drake}"
site_packages=$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")' 2>/dev/null || echo "3.12")
# Add Drake Python bindings to PYTHONPATH
if [ -d "\${DRAKE_ROOT}/lib/python\${site_packages}/site-packages" ]; then
  export PYTHONPATH="\${DRAKE_ROOT}/lib/python\${site_packages}/site-packages:\${PYTHONPATH}"
fi
if [ -d "\${DRAKE_ROOT}/lib/python3/dist-packages" ]; then
  export PYTHONPATH="\${DRAKE_ROOT}/lib/python3/dist-packages:\${PYTHONPATH}"
fi
# Add Drake libraries to library path
if [ -d "\${DRAKE_ROOT}/lib" ]; then
  export LD_LIBRARY_PATH="\${DRAKE_ROOT}/lib:\${LD_LIBRARY_PATH}"
fi
# Add Drake binaries to PATH
if [ -d "\${DRAKE_ROOT}/bin" ]; then
  export PATH="\${DRAKE_ROOT}/bin:\${PATH}"
fi
