#!/usr/bin/env bash
set -euo pipefail

config_file="/usr/local/etc/virtualgl/vglrun-fast.conf"
vgl_binary="/opt/VirtualGL/bin/vglrun"

if [ ! -r "${config_file}" ]; then
  echo "Configuration file not found: ${config_file}" >&2
  exit 1
fi

if [ ! -x "${vgl_binary}" ]; then
  echo "VirtualGL binary not executable: ${vgl_binary}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${config_file}"
export VGL_COMPRESS VGL_READBACK VGL_SYNC VGL_GAMMA VGL_LOGO VGL_SUBSAMP VGL_QUAL VGL_SPOIL VGL_FPS VGL_TRANSPORT
exec "${vgl_binary}" "$@"
