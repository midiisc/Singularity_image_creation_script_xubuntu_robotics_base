#!/usr/bin/env bash
# shellcheck shell=bash

# Modern Rust-based tool aliases (compiled from source)
alias cat='bat --paging=never'
alias catp='bat'  # with paging
alias ls='eza --icons'
alias ll='eza --icons -l'
alias la='eza --icons -la'
alias tree='eza --tree'
alias find='fd'
alias grep='rg'
alias top='btm'
alias ps='procs'

# Add /root/.local/bin to PATH for zoxide (if not already present)
if [ -d "/root/.local/bin" ]; then
  case ":${PATH}:" in
    *:/root/.local/bin:*)
      # Already in PATH
      ;;
    *)
      export PATH="/root/.local/bin:${PATH}"
      ;;
  esac
  # Initialize zoxide (better cd) - installed earlier via curl script
  if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash 2>/dev/null)" || true
    alias cd='z'
  fi
fi
