#!/usr/bin/env bash
# Launch VSCode with agent-safe environment
# Usage: ./scripts/vscode-agent-wrapper.sh [vscode-args]
#
# This wrapper ensures VSCode runs with the agent mode environment
# variables set, which configures terminals to use POSIX tools only.

# Set the agent mode environment variables
export DOTFILES_AGENT_MODE=1

# Debug output if DOTFILES_DEBUG is set
if [[ -n "${DOTFILES_DEBUG}" ]]; then
    echo "[DEBUG] Launching VSCode in agent mode" >&2
    echo "[DEBUG] DOTFILES_AGENT_MODE=${DOTFILES_AGENT_MODE}" >&2
    echo "[DEBUG] Checking for code in PATH..." >&2
fi

# Check if code is available in PATH
if command -v code >/dev/null 2>&1; then
    if [[ -n "${DOTFILES_DEBUG}" ]]; then
        echo "[DEBUG] Found code at: $(command -v code)" >&2
        echo "[DEBUG] Executing: code $*" >&2
    fi
    exec code "$@"
else
    echo "Error: code not found in PATH" >&2
    echo "Please ensure Visual Studio Code is installed and 'code' is available in your PATH" >&2
    echo "" >&2
    echo "To install the 'code' command in PATH (macOS/Linux):" >&2
    echo "  1. Open VSCode" >&2
    echo "  2. Press Cmd/Ctrl+Shift+P" >&2
    echo "  3. Type 'Shell Command: Install code command in PATH'" >&2
    echo "" >&2
    echo "Current PATH:" >&2
    echo "  ${PATH}" >&2
    exit 1
fi