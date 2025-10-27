#!/bin/bash
#===============================================================================
# SMART GPU NODE SELECTOR v2.0 - OPTIMIZED
#===============================================================================
# Purpose: Score HPC nodes using normalized metrics for immediate allocation
# With automatic overlay detection and intelligent fallback
#===============================================================================

set -e

#===============================================================================
# CONFIGURATION
#===============================================================================

# Arguments with defaults
IMAGE="${1:-ros2_jazzy_ubuntu_noble_opencv_4.12_cuda.sif}"
PARTITION="${2:-p1}"
TIME="${3:-24:00:00}"
GPUS=1
REQUIRED_GPUS=${GPUS}
REQUIRED_CPUS=4

# Options
AUTO_FALLBACK=${AUTO_FALLBACK:-true}
MAX_FALLBACK_ATTEMPTS=${MAX_FALLBACK_ATTEMPTS:-10}
QUEUE_WAIT_TIMEOUT=${QUEUE_WAIT_TIMEOUT:-20}
VERBOSE=${VERBOSE:-false}

# Check image exists
if [ ! -f "$IMAGE" ]; then
  echo "ERROR: Image not found: $IMAGE" >&2
  exit 1
fi

IMAGE_ABS=$(readlink -f "$IMAGE")

#===============================================================================
# COLORS
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

#===============================================================================
# AUTO-DETECT OVERLAY
#===============================================================================

OVERLAY_FILE=""
OVERLAY_ABS=""

shopt -s nullglob
for pattern in "ml_conda_overlay.img" "*overlay*.img" "overlay.img" "*conda*.img"; do
  if [ -f "$pattern" ]; then
    OVERLAY_FILE="$pattern"
    OVERLAY_ABS=$(readlink -f "$pattern")
    break
  fi
done
shopt -u nullglob

#===============================================================================
# HEADER
#===============================================================================

echo "" >&2
echo "═══════════════════════════════════════════════════════════════" >&2
echo "  Smart GPU Node Selector v2.0 (Optimized)" >&2
echo "═══════════════════════════════════════════════════════════════" >&2
echo "" >&2
echo " Image: $(basename "$IMAGE_ABS")" >&2

if [ -n "$OVERLAY_ABS" ]; then
  OVERLAY_SIZE=$(du -h "$OVERLAY_ABS" | cut -f1)
  OVERLAY_FS=$(blkid -s TYPE -o value "$OVERLAY_ABS" 2>/dev/null || echo "unknown")
  echo " Overlay: $(basename "$OVERLAY_ABS") ($OVERLAY_SIZE, $OVERLAY_FS)" >&2
else
  echo -e "${YELLOW} Overlay: None (read-only mode)${NC}" >&2
fi

echo " Partition: ${PARTITION}" >&2
echo " Timeout: ${QUEUE_WAIT_TIMEOUT}s" >&2
echo " Fallback: $( [ "$AUTO_FALLBACK" = true ] && echo "ENABLED ($MAX_FALLBACK_ATTEMPTS attempts)" || echo "DISABLED" )" >&2
echo "" >&2

FALLBACK_ATTEMPT=0

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

get_pending_jobs() {
  # Get pending jobs in this partition (not per-node, but partition-wide)
  local partition=$1
  squeue -p $partition -h -t PENDING 2>/dev/null | wc -l
}

get_user_jobs_on_node() {
  # Fixed: Added -h flag and fixed typo
  squeue -w $1 -u $USER -h 2>/dev/null | wc -l
}

#===============================================================================
# OPTIMIZED SCORING (Normalized 0-100 scale)
#===============================================================================

find_best_nodes() {
  local return_count=${1:-10}
  
  echo -e "${YELLOW}═══ Analyzing partition '$PARTITION' with normalized scoring...${NC}" >&2
  echo "" >&2
  
  # Query with GPU allocation info
  local sinfo_data=$(sinfo -p $PARTITION -h -o "%N|%T|%C|%O|%m|%e|%G")
  
  if [ -z "$sinfo_data" ]; then
    echo -e "${RED}ERROR: No nodes found${NC}" >&2
    return 1
  fi
  
  # Get partition-wide pending jobs once (more efficient)
  local partition_pending=$(get_pending_jobs "$PARTITION")
  
  echo "GPU Nodes (Normalized Scoring 0-100, higher = better):" >&2
  echo "" >&2
  printf "%-16s %-6s %-16s %-6s %-8s %-8s %-6s\n" \
    "NODE" "STATE" "CPU(A/I/O/T)" "LOAD" "FREE_MEM" "GPU_FREE" "SCORE" >&2
  echo "───────────────────────────────────────────────────────────────────────────────" >&2
  
  declare -a node_scores
  declare -a node_names
  local idx=0
  
  while IFS="|" read -r node state cpus load mem gpus free_mem; do
    # Filter: Must have GPUs (format: gpu:4)
    [[ ! "$gpus" =~ gpu ]] && continue
    
    # Filter: Skip down/drain nodes
    [[ "$state" =~ DOWN|DRAIN ]] && continue
    
    # Extract GPU count (format: gpu:4)
    local gpu_count=$(echo "$gpus" | grep -oP 'gpu:\K\d+' || echo "0")
    [ "$gpu_count" -lt "$REQUIRED_GPUS" ] && continue
    
    # Get GPU allocation from scontrol (more accurate)
    local alloc_gpus=0
    local gpu_alloc_info=$(scontrol show node $node 2>/dev/null | grep "AllocTRES" | grep -oP 'gres/gpu=\K\d+' || echo "0")
    alloc_gpus=${gpu_alloc_info:-0}
    local free_gpus=$((gpu_count - alloc_gpus))
    
    # Skip if no GPUs available
    [ "$free_gpus" -lt "$REQUIRED_GPUS" ] && continue
    
    # Parse CPU info
    local alloc_cpus=$(echo "$cpus" | cut -d'/' -f1)
    local idle_cpus=$(echo "$cpus" | cut -d'/' -f2)
    local total_cpus=$(echo "$cpus" | cut -d'/' -f4)
    
    # Skip if insufficient CPUs
    [ "$idle_cpus" -lt "$REQUIRED_CPUS" ] && continue
    
    # Parse load (float value)
    local cpu_load=$(echo "$load" | awk '{printf "%.2f", $1}')
    
    # Parse memory (in MB from sinfo)
    local total_mem=$mem
    local free_mem_mb=$free_mem
    local free_mem_gb=$(echo "$free_mem_mb" | awk '{print int($1/1024)}')
    
    local user_jobs=$(get_user_jobs_on_node "$node")
    
    #==========================================================================
    # NORMALIZED SCORING (0-100 scale, 100 = BEST)
    #==========================================================================
    
    # 1. STATE SCORE (0-100)
    local state_score=0
    case "$state" in
      IDLE)
        state_score=100
        ;;
      MIXED)
        state_score=50
        ;;
      ALLOCATED)
        state_score=20
        ;;
      *)
        state_score=0
        ;;
    esac
    
    # 2. CPU AVAILABILITY SCORE (0-100)
    local cpu_avail_score=0
    if [ "$total_cpus" -gt 0 ]; then
      cpu_avail_score=$((idle_cpus * 100 / total_cpus))
    fi
    
    # 3. CPU LOAD SCORE (0-100) - Lower load = better
    local cpu_load_score=100
    if [ "$total_cpus" -gt 0 ]; then
      local load_ratio=$(echo "$cpu_load $total_cpus" | awk '{printf "%.0f", ($1/$2)*100}')
      cpu_load_score=$((100 - load_ratio))
      [ "$cpu_load_score" -lt 0 ] && cpu_load_score=0
    fi
    
    # 4. MEMORY SCORE (0-100)
    local mem_score=0
    if [ "$total_mem" -gt 0 ]; then
      mem_score=$((free_mem_mb * 100 / total_mem))
    fi
    
    # 5. GPU AVAILABILITY SCORE (0-100)
    local gpu_score=0
    if [ "$gpu_count" -gt 0 ]; then
      gpu_score=$((free_gpus * 100 / gpu_count))
    fi
    
    # 6. QUEUE PRESSURE SCORE (0-100)
    local queue_score=100
    if [ "$partition_pending" -gt 0 ]; then
      queue_score=$((100 - partition_pending * 5))
      [ "$queue_score" -lt 0 ] && queue_score=0
    fi
    
    # 7. USER CONTENTION SCORE (0-100)
    local user_score=100
    if [ "$user_jobs" -gt 0 ]; then
      user_score=$((100 - user_jobs * 20))
      [ "$user_score" -lt 0 ] && user_score=0
    fi
    
    #==========================================================================
    # WEIGHTED FINAL SCORE (0-100)
    #==========================================================================
    # Weights optimized for immediate allocation + performance
    local final_score=$(awk -v s=$state_score -v c=$cpu_avail_score \
                            -v l=$cpu_load_score -v m=$mem_score \
                            -v g=$gpu_score -v q=$queue_score -v u=$user_score \
                            'BEGIN {printf "%.0f", s*0.25 + c*0.20 + l*0.15 + m*0.10 + g*0.20 + q*0.05 + u*0.05}')
    
    # Rating based on final score
    local rating color
    if [ "$final_score" -ge 90 ]; then
      rating="★★★★★ EXCELLENT"
      color=$GREEN
    elif [ "$final_score" -ge 70 ]; then
      rating="★★★★  GOOD"
      color=$CYAN
    elif [ "$final_score" -ge 50 ]; then
      rating="★★★   OKAY"
      color=$YELLOW
    else
      rating="★     BUSY"
      color=$RED
    fi
    
    printf "%-16s %-6s %-16s %-6.2f %-8s %-8s ${color}%-6s${NC}\n" \
      "$node" "$state" "$cpus" "$cpu_load" "${free_mem_gb}GB" "${free_gpus}/${gpu_count}" "$final_score $rating" >&2
    
    # Store as integer (multiply by 1000 to preserve precision for sorting)
    node_scores[$idx]=$((final_score * 1000))
    node_names[$idx]=$node
    idx=$((idx+1))
  done <<< "$sinfo_data"
  
  echo "" >&2
  
  [ "$idx" -eq 0 ] && return 1
  
  # Sort nodes by score DESCENDING (highest first)
  for ((i=0; i<$idx; i++)); do
    for ((j=i+1; j<$idx; j++)); do
      if [ "${node_scores[$i]}" -lt "${node_scores[$j]}" ]; then
        local tmp=${node_scores[$i]}
        node_scores[$i]=${node_scores[$j]}
        node_scores[$j]=$tmp
        
        tmp=${node_names[$i]}
        node_names[$i]=${node_names[$j]}
        node_names[$j]=$tmp
      fi
    done
  done
  
  # Check for excellent nodes
  local excellent_count=0
  for ((i=0; i<$idx; i++)); do
    if [ "${node_scores[$i]}" -ge 90000 ]; then
      ((excellent_count++))
    fi
  done
  
  if [ "$excellent_count" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No excellent nodes found. Best available will be tried.${NC}" >&2
    echo "" >&2
  fi
  
  # Show top candidates
  local top_n=$((idx < return_count ? idx : return_count))
  echo "Top $top_n Candidates (sorted by score - higher = better):" >&2
  for ((i=0; i<top_n; i++)); do
    local score=$((node_scores[i] / 1000))
    local rating
    if [ "$score" -ge 90 ]; then
      rating="★★★★★ EXCELLENT"
    elif [ "$score" -ge 70 ]; then
      rating="★★★★  GOOD"
    elif [ "$score" -ge 50 ]; then
      rating="★★★   OKAY"
    else
      rating="★     BUSY"
    fi
    echo " $((i+1)). ${node_names[$i]} (score: $score) $rating" >&2
  done
  
  echo "" >&2
  
  # Return space-separated list
  local result=""
  for ((i=0; i<top_n; i++)); do
    result="$result${node_names[$i]} "
  done
  echo "$result"
}

#===============================================================================
# TRY LAUNCH ON NODE
#===============================================================================

try_launch_on_node() {
  local node=$1
  
  echo -e "${CYAN}═══ Attempt #$((FALLBACK_ATTEMPT + 1))/$MAX_FALLBACK_ATTEMPTS${NC}" >&2
  echo -e "${CYAN}    Targeting node: $node${NC}" >&2
  
  local sing_opts="--nv"
  
  if [ -n "$OVERLAY_ABS" ]; then
    echo -e "${GREEN}    Mounting overlay: $(basename "$OVERLAY_ABS")${NC}" >&2
    sing_opts="$sing_opts --overlay $OVERLAY_ABS:rw"
  else
    echo -e "${YELLOW}    No overlay - using tmpfs${NC}" >&2
    sing_opts="$sing_opts --writable-tmpfs"
  fi
  
  [ -d "$HOME/data" ] && sing_opts="$sing_opts --bind $HOME/data:/data:rw"
  [ -d "$HOME/workspace" ] && sing_opts="$sing_opts --bind $HOME/workspace:/workspace:rw"
  [ -d "/scratch/$USER" ] && sing_opts="$sing_opts --bind /scratch/$USER:/scratch:rw"
  
  echo "" >&2
  
  srun \
    -w "$node" \
    --gres=gpu:$GPUS \
    --time="$TIME" \
    -p "$PARTITION" \
    --immediate="$QUEUE_WAIT_TIMEOUT" \
    --pty \
    singularity exec $sing_opts $IMAGE_ABS bash
  
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}✓ Session completed - you exited normally${NC}" >&2
    exit 0
  elif [ $exit_code -eq 124 ]; then
    echo -e "${YELLOW}⚠ Timeout (${QUEUE_WAIT_TIMEOUT}s) - trying next node${NC}" >&2
    return 1
  else
    echo -e "${YELLOW}⚠ Node unavailable (exit: ${exit_code}) - trying next node${NC}" >&2
    return 1
  fi
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

TOP_NODES=$(find_best_nodes $MAX_FALLBACK_ATTEMPTS)
[ -z "$TOP_NODES" ] && exit 1

read -ra NODE_ARRAY <<< "$TOP_NODES"

if [ "$AUTO_FALLBACK" = false ]; then
  try_launch_on_node "${NODE_ARRAY[0]}"
  exit $?
fi

echo -e "${GREEN}═══ Auto-Fallback: Will try up to ${#NODE_ARRAY[@]} nodes${NC}" >&2
echo "" >&2

for FALLBACK_ATTEMPT in $(seq 0 $((${#NODE_ARRAY[@]} - 1))); do
  if try_launch_on_node "${NODE_ARRAY[$FALLBACK_ATTEMPT]}"; then
    exit 0
  fi
  [ $FALLBACK_ATTEMPT -lt $((${#NODE_ARRAY[@]} - 1)) ] && sleep 2
done

echo "" >&2
echo -e "${RED}✗ All attempts failed${NC}" >&2
exit 1
