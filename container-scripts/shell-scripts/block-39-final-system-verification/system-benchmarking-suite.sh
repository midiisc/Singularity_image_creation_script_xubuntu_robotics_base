#!/usr/bin/env bash
# Comprehensive Remote Desktop Performance Benchmark

set -euo pipefail

# Print the benchmark header banner.
print_header() {
  printf '==========================================\n'
  printf 'Remote Desktop Performance Benchmark\n'
  printf '==========================================\n\n'
}

# Display CPU, memory, and GPU inventory details.
report_system_info() {
  printf 'SYSTEM INFORMATION:\n'

  if [ -r /proc/cpuinfo ]; then
    local cpu_model=""
    cpu_model=$(awk -F':' '/^model name/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo || true)
    if [ -n "${cpu_model}" ]; then
      printf '  CPU: %s\n' "${cpu_model}"
    fi
  fi

  if command -v nproc >/dev/null 2>&1; then
    printf '  Cores: %s\n' "$(nproc)"
  fi

  if command -v free >/dev/null 2>&1; then
    local total_mem=""
    total_mem=$(free -h | awk '/^Mem:/ {print $2; exit}' || true)
    if [ -n "${total_mem}" ]; then
      printf '  Memory: %s\n' "${total_mem}"
    fi
  fi

  report_gpu_info
  printf '\n'
}

# Collect GPU model and memory using nvidia-smi when present.
report_gpu_info() {
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    return 0
  fi

  local gpu_name=""
  local gpu_vram=""

  if command -v timeout >/dev/null 2>&1; then
    gpu_name=$(timeout 5 nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)
    gpu_vram=$(timeout 5 nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
  else
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)
    gpu_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
  fi

  if [ -n "${gpu_name}" ]; then
    printf '  GPU: %s\n' "${gpu_name}"
  fi

  if [ -n "${gpu_vram}" ]; then
    printf '  VRAM: %s MB\n' "${gpu_vram}"
  fi
}

# Exercise VirtualGL rendering if the stack is available.
run_virtualgl_benchmark() {
  printf 'VIRTUALGL PERFORMANCE:\n'

  if [ -z "${DISPLAY:-}" ] || ! command -v vglrun >/dev/null 2>&1 || ! command -v glxspheres64 >/dev/null 2>&1; then
    printf '  ⚠ DISPLAY not set or vglrun/glxspheres64 not available\n\n'
    return 0
  fi

  printf '  Testing GPU rendering...\n'
  local result=""

  if command -v timeout >/dev/null 2>&1; then
    result=$(timeout 10s vglrun glxspheres64 2>&1 | grep 'frames' | tail -1 || true)
  else
    result=$(vglrun glxspheres64 2>&1 | grep 'frames' | tail -1 || true)
  fi

  if [ -n "${result}" ]; then
    printf '  %s\n\n' "${result}"
  else
    printf '  ⚠ GPU test failed or incomplete\n\n'
  fi
}

# Run sysbench CPU test when available.
run_cpu_benchmark() {
  printf 'CPU PERFORMANCE:\n'

  if ! command -v sysbench >/dev/null 2>&1; then
    printf '  ⚠ sysbench not available\n\n'
    return 0
  fi

  printf '  Running CPU benchmark...\n'
  local cores="1"
  cores=$(nproc 2>/dev/null || printf '1\n')

  local sb_output=""
  sb_output=$(sysbench cpu --threads="${cores}" --time=10 run 2>&1 || true)

  local events=""
  events=$(grep 'events per second' <<< "${sb_output}" || true)

  if [ -n "${events}" ]; then
    printf '  %s\n\n' "${events}"
  else
    printf '  ⚠ CPU benchmark failed\n\n'
  fi
}

# Measure disk throughput using a temporary file that is always cleaned up.
run_disk_benchmark() {
  printf 'DISK I/O:\n'

  if ! command -v dd >/dev/null 2>&1; then
    printf '  ⚠ dd not available\n\n'
    return 0
  fi

  local tmp_file=""
  if ! tmp_file=$(mktemp /tmp/benchmark.dd.XXXXXX); then
    printf '  ⚠ Failed to create temp file for disk benchmark\n\n'
    return 0
  fi

  trap 'rm -f "${tmp_file}" 2>/dev/null || true' RETURN

  local dd_output=""
  local dd_status=0
  local -a dd_cmd=(dd if=/dev/zero of="${tmp_file}" bs=1M count=256 conv=fdatasync)

  if command -v timeout >/dev/null 2>&1; then
    dd_output=$(timeout 60s "${dd_cmd[@]}" 2>&1) || dd_status=$?
  else
    dd_output=$("${dd_cmd[@]}" 2>&1) || dd_status=$?
  fi

  if [ "${dd_status}" -eq 0 ]; then
    local copied_line=""
    copied_line=$(grep 'copied' <<< "${dd_output}" || true)
    if [ -n "${copied_line}" ]; then
      printf '  %s\n\n' "${copied_line}"
    else
      printf '  ⚠ Disk I/O test failed to capture throughput\n\n'
    fi
  else
    printf '  ⚠ Disk I/O test failed\n\n'
  fi

  rm -f "${tmp_file}" 2>/dev/null || true
  trap - RETURN
}

# Issue a short latency probe to a public endpoint when tools permit.
run_network_check() {
  printf 'NETWORK:\n'

  if ! command -v ping >/dev/null 2>&1; then
    printf '  ⚠ ping not available\n\n'
    return 0
  fi

  local ping_output=""
  ping_output=$(ping -c 4 8.8.8.8 2>&1 || true)

  local summary=""
  summary=$(grep -E 'rtt|round-trip' <<< "${ping_output}" || true)

  if [ -n "${summary}" ]; then
    printf '  %s\n\n' "${summary}"
  else
    printf '  ⚠ Network test skipped or failed\n\n'
  fi
}

main() {
  print_header
  report_system_info
  run_virtualgl_benchmark
  run_cpu_benchmark
  run_disk_benchmark
  run_network_check
  printf '==========================================\n'
  printf 'Benchmark Complete\n'
  printf '==========================================\n'
}

main "$@"
