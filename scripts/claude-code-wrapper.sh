#!/usr/bin/env bash
# Launch Claude Code with agent-safe environment
# Usage: ./scripts/claude-code-wrapper.sh [claude-code-args]
#
# This wrapper ensures Claude Code runs with the agent mode environment
# variables set, which configures the shell to use POSIX tools only.

# Set the agent mode environment variables
export DOTFILES_AGENT_MODE=1

# Debug output if DOTFILES_DEBUG is set
if [[ -n "${DOTFILES_DEBUG}" ]]; then
    echo "[DEBUG] Launching Claude Code in agent mode" >&2
    echo "[DEBUG] DOTFILES_AGENT_MODE=${DOTFILES_AGENT_MODE}" >&2
    echo "[DEBUG] Checking for claude-code in PATH..." >&2
fi

# Check if claude-code is available in PATH
if command -v claude-code >/dev/null 2>&1; then
    if [[ -n "${DOTFILES_DEBUG}" ]]; then
        echo "[DEBUG] Found claude-code at: $(command -v claude-code)" >&2
        echo "[DEBUG] Executing: claude-code $*" >&2
    fi
    exec claude-code "$@"
else
    echo "Error: claude-code not found in PATH" >&2
    echo "Please ensure claude-code is installed and available in your PATH" >&2
    echo "" >&2
    echo "Current PATH:" >&2
    echo "  ${PATH}" >&2
    exit 1
fi