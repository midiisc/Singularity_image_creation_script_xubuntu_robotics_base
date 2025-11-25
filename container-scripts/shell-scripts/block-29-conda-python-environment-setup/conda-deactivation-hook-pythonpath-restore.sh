#!/bin/bash
# Restore PYTHONPATH when deactivating conda environment
# This re-enables Drake Python bindings for system Python
if [ -n "${_CONDA_BACKUP_PYTHONPATH:-}" ]; then
  unset _CONDA_BACKUP_PYTHONPATH

  if [[ "${PYTHONPATH:-}" == *"drake"* ]]; then
    echo "Drake PYTHONPATH restored"
  fi
fi
