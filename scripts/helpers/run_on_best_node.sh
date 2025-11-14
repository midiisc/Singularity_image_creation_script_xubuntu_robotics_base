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
# BLUE unused - removed to fix SC2034
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

#===============================================================================
# AUTO-DETECT OVERLAY
#===============================================================================

# OVERLAY_FILE unused - only OVERLAY_ABS is used (fixes SC2034)
OVERLAY_ABS=""

shopt -s nullglob
for pattern in "ml_conda_overlay.img" "*overlay*.img" "overlay.img" "*conda*.img"; do
  if [ -f "$pattern" ]; then
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
  local sinfo_data
  sinfo_data=$(sinfo -p $PARTITION -h -o "%N|%T|%C|%O|%m|%e|%G")
  
  if [ -z "$sinfo_data" ]; then
    echo -e "${RED}ERROR: No nodes found${NC}" >&2
    return 1
  fi
  
  # Get partition-wide pending jobs once (more efficient)
  local partition_pending
  partition_pending=$(get_pending_jobs "$PARTITION")
  
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
    local gpu_count
    gpu_count=$(echo "$gpus" | grep -oP 'gpu:\K\d+' || echo "0")
    [ "$gpu_count" -lt "$REQUIRED_GPUS" ] && continue
    
    # Get GPU allocation from scontrol (more accurate)
    local alloc_gpus=0
    local gpu_alloc_info
    gpu_alloc_info=$(scontrol show node $node 2>/dev/null | grep "AllocTRES" | grep -oP 'gres/gpu=\K\d+' || echo "0")
    alloc_gpus=${gpu_alloc_info:-0}
    local free_gpus
    free_gpus=$((gpu_count - alloc_gpus))
    
    # Skip if no GPUs available
    [ "$free_gpus" -lt "$REQUIRED_GPUS" ] && continue
    
    # Parse CPU info
    # alloc_cpus unused - removed to fix SC2034
    local idle_cpus
    idle_cpus=$(echo "$cpus" | cut -d'/' -f2)
    local total_cpus
    total_cpus=$(echo "$cpus" | cut -d'/' -f4)
    
    # Skip if insufficient CPUs
    [ "$idle_cpus" -lt "$REQUIRED_CPUS" ] && continue
    
    # Parse load (float value)
    local cpu_load
    cpu_load=$(echo "$load" | awk '{printf "%.2f", $1}')
    
    # Parse memory (in MB from sinfo)
    local total_mem=$mem
    local free_mem_mb=$free_mem
    local free_mem_gb
    free_mem_gb=$(echo "$free_mem_mb" | awk '{print int($1/1024)}')
    
    local user_jobs
    user_jobs=$(get_user_jobs_on_node "$node")
    
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
      local load_ratio
      load_ratio=$(echo "$cpu_load $total_cpus" | awk '{printf "%.0f", ($1/$2)*100}')
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
    local final_score
    final_score=$(awk -v s=$state_score -v c=$cpu_avail_score \
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
  local top_n
  top_n=$((idx < return_count ? idx : return_count))
  echo "Top $top_n Candidates (sorted by score - higher = better):" >&2
  for ((i=0; i<top_n; i++)); do
    local score
    score=$((node_scores[i] / 1000))
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
  
  # Use array for singularity options to handle paths with spaces safely
  local sing_opts=("--nv")
  
  if [ -n "$OVERLAY_ABS" ]; then
    echo -e "${GREEN}    Mounting overlay: $(basename "$OVERLAY_ABS")${NC}" >&2
    sing_opts+=("--overlay" "${OVERLAY_ABS}:rw")
  else
    echo -e "${YELLOW}    No overlay - using tmpfs${NC}" >&2
    sing_opts+=("--writable-tmpfs")
  fi
  
  [ -d "$HOME/data" ] && sing_opts+=("--bind" "${HOME}/data:/data:rw")
  [ -d "$HOME/workspace" ] && sing_opts+=("--bind" "${HOME}/workspace:/workspace:rw")
  [ -d "/scratch/$USER" ] && sing_opts+=("--bind" "/scratch/$USER:/scratch:rw")
  
  echo "" >&2
  
  srun \
    -w "$node" \
    --gres=gpu:$GPUS \
    --time="$TIME" \
    -p "$PARTITION" \
    --immediate="$QUEUE_WAIT_TIMEOUT" \
    --pty \
    singularity exec "${sing_opts[@]}" "$IMAGE_ABS" bash
  
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
# CHECK FOR EXISTING JOBS
#===============================================================================

check_existing_jobs() {
  # Check if user has any running or pending jobs
  # Focus on interactive/interactive-like jobs (pty sessions) since HPC typically allows only one interactive session
  local existing_jobs
  existing_jobs=$(squeue -u "$USER" -h -o "%i|%j|%T|%N|%M|%l|%R" 2>/dev/null)
  
  if [ -z "$existing_jobs" ]; then
    return 0  # No existing jobs
  fi
  
  # Filter for interactive jobs (those with --pty flag or interactive-like characteristics)
  # Also include all running jobs since they might be interactive sessions
  local interactive_jobs=""
  while IFS="|" read -r job_id job_name state nodes time_used time_limit reason; do
    # Include all RUNNING jobs (likely interactive) and PENDING jobs that might be interactive
    if [ "$state" = "RUNNING" ] || [ "$state" = "PENDING" ]; then
      if [ -z "$interactive_jobs" ]; then
        interactive_jobs="${job_id}|${job_name}|${state}|${nodes}|${time_used}|${time_limit}|${reason}"
      else
        interactive_jobs="${interactive_jobs}"$'\n'"${job_id}|${job_name}|${state}|${nodes}|${time_used}|${time_limit}|${reason}"
      fi
    fi
  done <<< "$existing_jobs"
  
  if [ -z "$interactive_jobs" ]; then
    return 0  # No active interactive jobs
  fi
  
  # Count jobs by state
  local running_jobs
  running_jobs=$(echo "$interactive_jobs" | grep -c "RUNNING" || echo "0")
  local pending_jobs
  pending_jobs=$(echo "$interactive_jobs" | grep -c "PENDING" || echo "0")
  local total_jobs
  total_jobs=$((running_jobs + pending_jobs))
  
  if [ "$total_jobs" -eq 0 ]; then
    return 0  # No active jobs
  fi
  
  echo "" >&2
  echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}" >&2
  echo -e "${YELLOW}  WARNING: Existing Job(s) Detected${NC}" >&2
  echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}" >&2
  echo "" >&2
  echo "You have $total_jobs existing job(s):" >&2
  echo "  - Running: $running_jobs" >&2
  echo "  - Pending: $pending_jobs" >&2
  echo "" >&2
  echo "Job Details:" >&2
  echo "───────────────────────────────────────────────────────────────────────────────" >&2
  printf "%-10s %-30s %-10s %-20s %-10s %-15s\n" "JOB_ID" "JOB_NAME" "STATE" "NODES" "TIME" "TIME_LIMIT" >&2
  echo "───────────────────────────────────────────────────────────────────────────────" >&2
  
  while IFS="|" read -r job_id job_name state nodes time_used time_limit reason; do
    printf "%-10s %-30s %-10s %-20s %-10s %-15s\n" \
      "$job_id" "${job_name:0:30}" "$state" "${nodes:0:20}" "${time_used:0:10}" "${time_limit:0:15}" >&2
  done <<< "$interactive_jobs"
  
  echo "" >&2
  
  # Find running jobs with node information for login instructions
  local running_job_info
  running_job_info=$(echo "$interactive_jobs" | grep "RUNNING" | head -1)
  if [ -n "$running_job_info" ]; then
    local running_job_id
    running_job_id=$(echo "$running_job_info" | cut -d'|' -f1)
    local running_nodes
    running_nodes=$(echo "$running_job_info" | cut -d'|' -f4)
    
    echo -e "${CYAN}To log in to your existing running job:${NC}" >&2
    echo "  Job ID: $running_job_id" >&2
    echo "  Node(s): $running_nodes" >&2
    echo "" >&2
    echo "  Option 1: Use sattach to attach to the interactive session:" >&2
    echo "    sattach $running_job_id" >&2
    echo "" >&2
    echo "  Option 2: SSH to the node and find your container:" >&2
    if [ -n "$running_nodes" ] && [ "$running_nodes" != "N/A" ] && [ "$running_nodes" != "(null)" ]; then
      # Extract first node from various SLURM NodeList formats:
      # Step 1: 's/,.*//'      - Remove comma-separated list: "node001,node002" → "node001"
      # Step 2: 's/\[.*\]//'   - Remove bracket ranges: "node[001-002]" → "node"
      # Step 3: 's/-.*//'      - Remove dash ranges: "node001-002" → "node001"
      # Result: "node001" from any format
      local first_node
      first_node=$(echo "$running_nodes" | sed 's/,.*//' | sed 's/\[.*\]//' | sed 's/-.*//')
      if [ -n "$first_node" ]; then
        echo "    ssh $first_node" >&2
        echo "    # Then find your singularity container:" >&2
        echo "    ps aux | grep singularity | grep $USER" >&2
        echo "    # Or check scontrol for job details:" >&2
        echo "    scontrol show job $running_job_id" >&2
      fi
    else
      echo "    # Get node information first:" >&2
      echo "    scontrol show job $running_job_id | grep NodeList" >&2
    fi
    echo "" >&2
  fi
  
  # Ask user what to do
  echo -e "${YELLOW}What would you like to do?${NC}" >&2
  echo "  1) Cancel all existing jobs and start a new one" >&2
  echo "  2) Exit and keep existing jobs running" >&2
  echo "" >&2
  read -p "Enter choice [1/2]: " user_choice
  
  case "$user_choice" in
    1)
      echo "" >&2
      echo -e "${YELLOW}Cancelling existing jobs...${NC}" >&2
      local cancelled_count=0
      while IFS="|" read -r job_id rest; do
        if scancel "$job_id" 2>/dev/null; then
          echo "  ✓ Cancelled job $job_id" >&2
          cancelled_count=$((cancelled_count + 1))
        else
          echo "  ⚠ Failed to cancel job $job_id" >&2
        fi
      done <<< "$interactive_jobs"
      
      if [ "$cancelled_count" -gt 0 ]; then
        echo "" >&2
        echo -e "${GREEN}✓ Cancelled $cancelled_count job(s). Waiting 3 seconds for cleanup...${NC}" >&2
        sleep 3
        return 0  # Continue with new job
      else
        echo -e "${RED}✗ Failed to cancel jobs. Exiting.${NC}" >&2
        return 1
      fi
      ;;
    2)
      echo "" >&2
      echo -e "${CYAN}Keeping existing jobs. Exiting.${NC}" >&2
      echo "" >&2
      if [ -n "$running_job_info" ]; then
        local running_job_id
        running_job_id=$(echo "$running_job_info" | cut -d'|' -f1)
        echo "To attach to your running job, use:" >&2
        echo "  sattach $running_job_id" >&2
        echo "" >&2
      fi
      exit 0
      ;;
    *)
      echo "" >&2
      echo -e "${RED}Invalid choice. Exiting.${NC}" >&2
      exit 1
      ;;
  esac
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

# Check for existing jobs before proceeding
if ! check_existing_jobs; then
  exit 1
fi

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
