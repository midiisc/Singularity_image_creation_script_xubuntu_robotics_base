#!/usr/bin/env bash
# shellcheck shell=bash
# Purpose: OpenBLAS environment configuration
# This file is sourced to set OpenBLAS-related environment variables
# shellcheck disable=SC1083,SC2086
export PATH=${OPENBLAS_INSTALL_PREFIX}/bin:\${PATH}
export LD_LIBRARY_PATH=${OPENBLAS_INSTALL_PREFIX}/lib:\${LD_LIBRARY_PATH}
export PKG_CONFIG_PATH=${OPENBLAS_INSTALL_PREFIX}/lib/pkgconfig:\${PKG_CONFIG_PATH}
export OpenBLAS_DIR=${OPENBLAS_INSTALL_PREFIX}/lib/cmake/openblas
export CMAKE_PREFIX_PATH=${OPENBLAS_INSTALL_PREFIX}:\${CMAKE_PREFIX_PATH}
