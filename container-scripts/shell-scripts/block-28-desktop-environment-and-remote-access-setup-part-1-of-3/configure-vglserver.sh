#!/usr/bin/env bash
set -euo pipefail

# VirtualGL Server Configuration Helper
# Official docs: https://rawcdn.githack.com/VirtualGL/virtualgl/3.1.4/doc/index.html
# This script helps configure VirtualGL for system-wide use
# Note: In Singularity containers, this may not be necessary

readonly VGLSERVER_CONFIG="/opt/VirtualGL/bin/vglserver_config"

  if [ -x "${VGLSERVER_CONFIG}" ]; then
  printf 'Running VirtualGL server configuration...\n'
  printf 'This will set up permissions for VirtualGL to access the 3D X server\n'
  "${VGLSERVER_CONFIG}"
else
  printf 'ERROR: vglserver_config not found\n' >&2
  exit 1
fi
