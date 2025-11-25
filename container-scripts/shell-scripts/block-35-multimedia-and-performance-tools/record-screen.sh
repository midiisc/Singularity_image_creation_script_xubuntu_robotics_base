#!/usr/bin/env bash
# Screen recording with GPU encoding

# D1-D4: Quote variables to prevent word splitting
DISPLAY_NUM="${1:-1}"
OUTPUT="${2:-screen_recording_$(date +%Y%m%d_%H%M%S).mp4}"

echo "Recording display :${DISPLAY_NUM} to ${OUTPUT}"
echo "Press Ctrl+C to stop"

# Try NVENC (GPU encoding), fallback to libx264 (CPU)
if ffmpeg -encoders 2>/dev/null | grep -q h264_nvenc; then
  ENCODER="h264_nvenc"
  echo "Using NVIDIA GPU encoder"
else
  ENCODER="libx264"
  echo "Using CPU encoder"
fi

# DISPLAY variable assignment needs unquoted value, but use in command should be quoted
DISPLAY=":${DISPLAY_NUM}" ffmpeg \
  -f x11grab \
  -video_size 1920x1080 \
  -framerate 30 \
  -i ":${DISPLAY_NUM}" \
  -c:v "${ENCODER}" \
  -preset medium \
  -crf 23 \
  "${OUTPUT}"
