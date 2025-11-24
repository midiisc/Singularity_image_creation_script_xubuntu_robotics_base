#!/usr/bin/env bash
# shellcheck shell=bash
# Purpose: Priority paths for compiled libraries
# This file is sourced to set library search paths for compiled libraries
# shellcheck disable=SC1083,SC2086
export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:\${LD_LIBRARY_PATH:-}"
export CMAKE_PREFIX_PATH="/usr/local:\${CMAKE_PREFIX_PATH:-}"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:\${PKG_CONFIG_PATH:-}"
