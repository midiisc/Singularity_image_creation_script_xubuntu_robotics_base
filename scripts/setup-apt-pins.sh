#!/usr/bin/env bash
set -euo pipefail

PIN_FILE="/etc/apt/preferences.d/robotics-stack-pin"

echo "Writing APT pin configuration to ${PIN_FILE}"

sudo tee "${PIN_FILE}" >/dev/null <<'EOF'
# Prevent system packages from replacing custom MKL builds

Package: libceres*
Pin: release *
Pin-Priority: -1

Package: libgtsam*
Pin: release *
Pin-Priority: -1

Package: libg2o*
Pin: release *
Pin-Priority: -1

Package: libopencv*
Pin: release *
Pin-Priority: -1

Package: python3-opencv
Pin: release *
Pin-Priority: -1

Package: libopen3d*
Pin: release *
Pin-Priority: -1

Package: libsuitesparse*
Pin: release *
Pin-Priority: -1

Package: colmap
Pin: release *
Pin-Priority: -1

# Keep ROS core, Eigen, Boost, PCL, TBB, HDF5 managed by Ubuntu
EOF

echo "APT pin file created."
echo "Current pin priorities:"
apt-cache policy libceres-dev | sed -n '1,4p' || true

