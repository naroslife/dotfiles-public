#!/usr/bin/env bash
# Launch a shell in agent-safe mode (POSIX tools only)
# Usage: ./scripts/launch-agent-shell.sh [shell_args]
#
# This script launches a new shell with environment variables configured
# for AI agent mode, ensuring only POSIX-compliant tools are used.

# Set the agent mode environment variables
export DOTFILES_PROFILE=agent
export DOTFILES_AGENT_MODE=1

# Debug output if DOTFILES_DEBUG is set
if [[ -n "${DOTFILES_DEBUG}" ]]; then
    echo "[DEBUG] Launching shell in agent mode" >&2
    echo "[DEBUG] DOTFILES_PROFILE=${DOTFILES_PROFILE}" >&2
    echo "[DEBUG] DOTFILES_AGENT_MODE=${DOTFILES_AGENT_MODE}" >&2
    echo "[DEBUG] SHELL=${SHELL:-/bin/bash}" >&2
fi

# Launch the shell with any provided arguments
# Use the user's preferred shell, fallback to bash if not set
exec "${SHELL:-/bin/bash}" "$@"