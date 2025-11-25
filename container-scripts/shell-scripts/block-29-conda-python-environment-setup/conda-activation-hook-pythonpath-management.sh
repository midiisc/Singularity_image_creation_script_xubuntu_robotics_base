#!/bin/bash
# Save and unset PYTHONPATH when activating conda environment
# This prevents Drake's system Python from conflicting with Conda's Python
if [ -n "${PYTHONPATH:-}" ]; then
  # Backup original PYTHONPATH (including Drake paths)
  export _CONDA_BACKUP_PYTHONPATH="${PYTHONPATH}"

  # Unset PYTHONPATH so conda environment is isolated
  unset PYTHONPATH

  # Inform user
  if [[ "${_CONDA_BACKUP_PYTHONPATH:-}" == *"drake"* ]]; then
    echo "Drake PYTHONPATH temporarily disabled in conda environment"
  fi
fi
