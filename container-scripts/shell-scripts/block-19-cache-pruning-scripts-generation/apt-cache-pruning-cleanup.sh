#!/usr/bin/env bash
# Prune APT deb cache. Keep the latest N per package base name.
# Usage: prune_apt_cache.sh --cache /path/to/apt/archives --keep 2 [--apply]
set -euo pipefail

CACHE=""; KEEP="2"; APPLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache) CACHE="$2"; shift 2;;
    --keep) KEEP="$2"; shift 2;;
    --apply) APPLY="1"; shift;;
    *) shift;;
  esac
done

# Validate inputs
if [[ -z "$CACHE" ]]; then echo "[apt-prune] ERROR: --cache path required" >&2; exit 2; fi
if [[ ! -d "$CACHE" ]]; then echo "[apt-prune] INFO: cache '$CACHE' missing; nothing to do"; exit 0; fi
if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then echo "[apt-prune] ERROR: --keep must be integer (got '$KEEP')" >&2; exit 2; fi
if (( KEEP < 1 )); then echo "[apt-prune] ERROR: --keep must be >= 1 (got '$KEEP')" >&2; exit 2; fi
cd "$CACHE" || { echo "[apt-prune] ERROR: could not cd to '$CACHE'" >&2; exit 1; }

# Collect .deb files quietly
# Use GNU find -printf (installed in BLOCK 3) for reliable file listing
mapfile -t ALL_DEBS < <(find . -maxdepth 1 -type f -name '*.deb' -printf '%f\n' 2>/dev/null)
if (( ${#ALL_DEBS[@]} == 0 )); then echo "[apt-prune] INFO: no .deb files to consider"; exit 0; fi

# Derive unique package bases (before first underscore)
mapfile -t BASES < <(printf '%s\n' "${ALL_DEBS[@]}" | awk -F '_' '{print $1}' | sort -u)

removed_total=0
for pkg in "${BASES[@]}"; do
    # List *this* package's debs newest first
    # Use GNU find -printf (installed in BLOCK 3) for reliable sorting
    ALL_FOR_PKG=()
    while IFS= read -r line; do
        [ -z "${line}" ] && continue
        ALL_FOR_PKG+=("$(echo "${line}" | cut -d' ' -f2-)")
    done < <(find . -maxdepth 1 -type f -name "${pkg}_*.deb" -printf '%T@ %f\n' 2>/dev/null | sort -rn | cut -d' ' -f2- || true)
    if (( ${#ALL_FOR_PKG[@]} <= KEEP )); then continue; fi

  # Determine files to prune
    if (( (${#ALL_FOR_PKG[@]} - KEEP) > 0 )); then
    mapfile -t TO_REMOVE < <(printf '%s\n' "${ALL_FOR_PKG[@]}" | tail -n +$((KEEP+1)))
  else
    TO_REMOVE=()
  fi

#--- Sub-block: Section continuation (991) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 970 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    if (( ${#TO_REMOVE[@]} > 0 )); then
        if [[ -n "$APPLY" ]]; then
            # Remove files directly from array (more portable than xargs)
            for file in "${TO_REMOVE[@]}"; do
                rm -f "${file}" 2>/dev/null || true
            done
            (( removed_total += ${#TO_REMOVE[@]} ))
        else
            printf '[apt-prune] Would remove %s\n' "${TO_REMOVE[@]}"
        fi
    fi
done

if [[ -n "$APPLY" ]] && (( removed_total > 0 )); then echo "[apt-prune] Removed ${removed_total} file(s)"; else echo "[apt-prune] Dry-run complete"; fi
