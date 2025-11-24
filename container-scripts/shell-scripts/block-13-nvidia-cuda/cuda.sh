#!/bin/sh
# D1-D4: Quote variables to prevent word splitting
export PATH="/usr/local/cuda-${CUDA_VERSION:-12.6}/bin\${PATH:+:\$PATH}"
export LD_LIBRARY_PATH="/usr/local/cuda-${CUDA_VERSION:-12.6}/lib64\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export CUDA_HOME="/usr/local/cuda-${CUDA_VERSION:-12.6}"
