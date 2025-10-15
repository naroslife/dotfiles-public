#!/usr/bin/env bash
# AI Agent Detection Library
# Provides functions to detect when shell commands are being executed by AI agents
# vs. human users, allowing for context-aware tool selection (POSIX vs modern)

# Function: is_agent_context
# Returns 0 (true) if running in an AI agent/automation context, 1 (false) if human context
# This comprehensive detection covers multiple scenarios where AI agents might execute commands
is_agent_context() {
    # 1. Explicit agent mode - environment variable for manual override
    # Users or systems can set DOTFILES_AGENT_MODE=1 to force agent behavior
    if [[ "${DOTFILES_AGENT_MODE:-0}" == "1" ]]; then
        return 0
    fi

    # 2. Non-interactive shell detection
    # AI agents typically run in non-interactive shells (no prompt)
    # Check if the shell is not interactive (i flag is missing)
    if [[ $- != *i* ]]; then
        return 0
    fi

    # 3. Terminal type detection
    # AI agents often run without a proper terminal or with 'dumb' terminal
    if [[ -z "${TERM:-}" || "${TERM}" == "dumb" ]]; then
        return 0
    fi

    # 4. Parent process detection
    # Check if any parent process suggests AI agent execution
    # This covers VSCode, Claude, Cursor, GitHub Copilot, and generic agent processes
    local parent_chain=""
    if command -v ps >/dev/null 2>&1; then
        # Get the full process tree up to init
        parent_chain=$(ps -o comm= -p $$ 2>/dev/null)
        local ppid=$PPID
        while [[ $ppid -gt 1 ]]; do
            local parent_name=$(ps -o comm= -p $ppid 2>/dev/null)
            parent_chain="$parent_chain $parent_name"
            ppid=$(ps -o ppid= -p $ppid 2>/dev/null | tr -d ' ')
        done

        # Check for AI/IDE agent processes in the parent chain
        if echo "$parent_chain" | grep -qiE "(code|claude|cursor|agent|copilot|ai-assist|vscode|codium)"; then
            return 0
        fi
    fi

    # 5. CI/Automation environment detection
    # Check for common CI/CD and automation environment variables
    # These indicate automated execution contexts where POSIX compliance is important
    if [[ -n "${CI:-}" ]] || \
       [[ -n "${AUTOMATION:-}" ]] || \
       [[ -n "${GITHUB_ACTIONS:-}" ]] || \
       [[ -n "${GITLAB_CI:-}" ]] || \
       [[ -n "${JENKINS_HOME:-}" ]] || \
       [[ -n "${TRAVIS:-}" ]] || \
       [[ -n "${CIRCLECI:-}" ]] || \
       [[ -n "${BUILDKITE:-}" ]] || \
       [[ -n "${DRONE:-}" ]] || \
       [[ -n "${BUILD_ID:-}" ]] || \
       [[ -n "${CONTINUOUS_INTEGRATION:-}" ]]; then
        return 0
    fi

    # 6. SSH without TTY detection
    # Non-interactive SSH sessions (like those used by automation) won't have a TTY
    if [[ -n "${SSH_CLIENT:-}" || -n "${SSH_CONNECTION:-}" ]] && ! tty -s 2>/dev/null; then
        return 0
    fi

    # 7. Script execution detection
    # If we're inside a script (not directly in shell), might be automation
    # Check if $0 indicates script execution
    if [[ "$0" != "-bash" && "$0" != "bash" && "$0" != "-zsh" && "$0" != "zsh" ]] && \
       [[ "$0" == *".sh" || -f "$0" ]]; then
        # This is a script file, could be automation
        # Additional check: if stdin is not a terminal, likely automation
        if ! [ -t 0 ]; then
            return 0
        fi
    fi

    # If none of the above conditions match, assume human context
    return 1
}

# Function: _smart_alias
# Creates a smart alias that chooses between modern and POSIX tools based on context
# Usage: _smart_alias modern_tool posix_tool [additional_args...]
# Example: _smart_alias "bat --style=plain" "cat"
_smart_alias() {
    local modern_cmd="$1"
    local posix_cmd="$2"
    shift 2
    local args="$@"

    # Check context at runtime (when alias is executed)
    if is_agent_context; then
        # Agent context: use POSIX-compliant tool
        command $posix_cmd $args
    else
        # Human context: use modern tool if available, fall back to POSIX
        local modern_tool="${modern_cmd%% *}"  # Extract tool name from command
        if command -v "$modern_tool" >/dev/null 2>&1; then
            eval "$modern_cmd $args"
        else
            # Fallback to POSIX if modern tool not found
            command $posix_cmd $args
        fi
    fi
}

# Export functions for use in shell configurations
export -f is_agent_context 2>/dev/null || true  # export -f may not work in all shells
export -f _smart_alias 2>/dev/null || true

# Debug mode: Set DOTFILES_DEBUG=1 to see detection results
if [[ "${DOTFILES_DEBUG:-0}" == "1" ]]; then
    echo "[Agent Detection Debug]"
    echo "  DOTFILES_AGENT_MODE: ${DOTFILES_AGENT_MODE:-not set}"
    echo "  Interactive shell: $([ $- == *i* ] && echo "yes" || echo "no")"
    echo "  TERM: ${TERM:-not set}"
    echo "  CI: ${CI:-not set}"
    echo "  GITHUB_ACTIONS: ${GITHUB_ACTIONS:-not set}"
    echo "  SSH_CLIENT: ${SSH_CLIENT:-not set}"
    if is_agent_context; then
        echo "  Detection result: AI AGENT CONTEXT"
    else
        echo "  Detection result: HUMAN CONTEXT"
    fi
    echo ""
fi