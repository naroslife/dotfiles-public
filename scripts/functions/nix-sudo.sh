#!/usr/bin/env bash
# Sudo wrapper that preserves Nix environment

# Usage: nsudo command [args...] - runs command with sudo while preserving Nix PATH
nsudo() {
  if [ $# -eq 0 ]; then
    echo "Usage: nsudo <command> [args...]"
    echo "Runs command with sudo while preserving Nix tools in PATH"
    return 1
  fi
  sudo env PATH="$PATH" "$@"
}

# Alternative: sudo with preserved environment
# Usage: sudo-nix command [args...] - same as nsudo but different name
sudo-nix() {
  nsudo "$@"
}