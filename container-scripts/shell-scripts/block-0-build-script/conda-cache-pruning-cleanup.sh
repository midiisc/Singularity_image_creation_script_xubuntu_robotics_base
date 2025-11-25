#!/usr/bin/env bash
# Prune conda pkgs cache. Keep the latest N artifacts per base package name.
# Handles *.conda and *.tar.bz2 files.
# Usage: prune_conda_cache.sh --cache /path/to/conda/pkgs --keep 2 [--apply]
set -euo pipefail

# Purpose: Prune conda package cache, keeping only the latest N artifacts per package
# Parameters: --cache <path> --keep <N> [--apply]
# Returns: 0 on success, 1-2 on error
# Usage: prune_conda_cache.sh --cache /path/to/conda/pkgs --keep 2 [--apply]

CACHE=""; KEEP="2"; APPLY=""
# D1-D4: Quote positional parameters
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --cache) CACHE="$2"; shift 2;;
    --keep) KEEP="$2"; shift 2;;
    --apply) APPLY="1"; shift;;
    *) shift;;
  esac
done

# Validate inputs
if [[ -z "$CACHE" ]]; then echo "[conda-prune] ERROR: --cache path required" >&2; exit 2; fi
if [[ ! -d "$CACHE" ]]; then echo "[conda-prune] INFO: cache '$CACHE' missing; nothing to do"; exit 0; fi
if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then echo "[conda-prune] ERROR: --keep must be integer (got '$KEEP')" >&2; exit 2; fi
if (( KEEP < 1 )); then echo "[conda-prune] ERROR: --keep must be >= 1 (got '$KEEP')" >&2; exit 2; fi
cd "$CACHE" || { echo "[conda-prune] ERROR: could not cd to '$CACHE'" >&2; exit 1; }

# List package files (quiet if none)
# Use GNU find -printf (installed in BLOCK 3) for reliable file listing
mapfile -t PKGFILES < <(find . -maxdepth 1 -type f \( -name '*.conda' -o -name '*.tar.bz2' \) -printf '%f\n' 2>/dev/null)
if (( ${#PKGFILES[@]} == 0 )); then echo "[conda-prune] INFO: no conda artifacts found"; exit 0; fi

# Derive base names: strip version-build-suffix and extension
# Matches: name-version-build.(conda|tar.bz2)
mapfile -t BASES < <(printf '%s\n' "${PKGFILES[@]}" | \
  sed -E 's/-[0-9.-]+-[a-z0-9_]+(\.conda|\.tar\.bz2)$//' | sort -u)

removed_total=0
for base in "${BASES[@]}"; do
  # All variants for this base (sort with -V to respect 1.10 > 1.9 etc.)
    ALL_FOR_BASE=()
    # Use GNU find -printf (installed in BLOCK 3) for reliable file listing
    while IFS= read -r pkg_file; do
        [ -z "${pkg_file}" ] || [ ! -f "${pkg_file}" ] && continue
        ALL_FOR_BASE+=("$(basename "${pkg_file}")")
    done < <(find . -maxdepth 1 -type f \( -name "${base}-*.conda" -o -name "${base}-*.tar.bz2" \) -printf '%f\n' 2>/dev/null | sort -rV || true)
    if (( ${#ALL_FOR_BASE[@]} <= KEEP )); then continue; fi

#--- Sub-block: Section continuation (1053) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

    if (( (${#ALL_FOR_BASE[@]} - KEEP) > 0 )); then
    mapfile -t TO_REMOVE < <(printf '%s\n' "${ALL_FOR_BASE[@]}" | tail -n +$((KEEP+1)))
  else
    TO_REMOVE=()
  fi


#--- Sub-block: Code section 1035 ---
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
            printf '[conda-prune] Would remove %s\n' "${TO_REMOVE[@]}"
        fi
    fi
done

if [[ -n "$APPLY" ]] && (( removed_total > 0 )); then echo "[conda-prune] Removed ${removed_total} file(s)"; else echo "[conda-prune] Dry-run complete"; fi
