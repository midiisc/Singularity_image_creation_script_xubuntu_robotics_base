#!/usr/bin/env bash
# Real-time GPU monitoring

if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "ERROR: nvidia-smi not found. NVIDIA drivers may not be installed." >&2
    exit 1
fi

if ! command -v watch >/dev/null 2>&1; then
    echo "ERROR: watch command not found. Please install procps package." >&2
    exit 1
fi

watch -n 1 "nvidia-smi --query-gpu=timestamp,name,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free,temperature.gpu,power.draw --format=csv,noheader,nounits | column -t -s','"
