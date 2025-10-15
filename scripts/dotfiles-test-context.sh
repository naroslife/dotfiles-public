#!/usr/bin/env bash
# Test AI agent context detection
# Usage: ./scripts/dotfiles-test-context.sh
#
# This script tests the agent detection functionality and shows which
# tools/aliases are active based on the current context.

# Source detection library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
DETECTION_LIB="${LIB_DIR}/agent-detection.sh"

# Check if detection library exists
if [[ ! -f "${DETECTION_LIB}" ]]; then
    echo "Warning: Agent detection library not found at: ${DETECTION_LIB}" >&2
    echo "Creating a simple fallback detection function..." >&2

    # Provide a fallback detection function
    is_agent_context() {
        [[ -n "${DOTFILES_AGENT_MODE}" ]] || \
        [[ "${DOTFILES_PROFILE}" == "agent" ]]
    }
else
    source "${DETECTION_LIB}"
fi

echo "=== AI Agent Context Detection Test ==="
echo ""
echo "Environment:"
echo "  DOTFILES_AGENT_MODE: ${DOTFILES_AGENT_MODE:-not set}"
echo "  DOTFILES_PROFILE: ${DOTFILES_PROFILE:-auto}"
echo "  TERM: ${TERM:-not set}"
echo "  Interactive: $([[ $- == *i* ]] && echo "yes" || echo "no")"
echo "  Shell: ${SHELL##*/}"
echo "  PID: $$"
echo ""

# Function to check command type safely
check_command_type() {
    local cmd="$1"
    local type_output

    # Try to get type information
    if type_output=$(type "$cmd" 2>&1); then
        # Parse the output to determine the type
        if echo "$type_output" | grep -q "is aliased to"; then
            echo "alias -> $(echo "$type_output" | sed "s/.*is aliased to '\(.*\)'/\1/")"
        elif echo "$type_output" | grep -q "is a function"; then
            echo "function"
        elif echo "$type_output" | grep -q "is a shell builtin"; then
            echo "builtin"
        elif echo "$type_output" | grep -q "is.*hashed"; then
            # Extract path from hashed output
            echo "$(echo "$type_output" | sed 's/.*(\(.*\))/\1/')"
        else
            # Try to extract the path from the output
            local path=$(echo "$type_output" | awk '{print $NF}')
            if [[ -x "$path" ]]; then
                echo "$path"
            else
                echo "$type_output"
            fi
        fi
    else
        # If type fails, try which as fallback
        if command -v "$cmd" >/dev/null 2>&1; then
            command -v "$cmd"
        else
            echo "not found"
        fi
    fi
}

if is_agent_context; then
    echo "✓ Context: AGENT (using POSIX tools)"
    echo ""
    echo "Active tools (should be POSIX originals):"
    echo "  cat  -> $(check_command_type cat)"
    echo "  ls   -> $(check_command_type ls)"
    echo "  grep -> $(check_command_type grep)"
    echo "  find -> $(check_command_type find)"
    echo "  sed  -> $(check_command_type sed)"
    echo "  awk  -> $(check_command_type awk)"
    echo ""
    echo "Modern tool availability (should be disabled or unaliased):"
    echo "  bat     -> $(check_command_type bat)"
    echo "  eza     -> $(check_command_type eza)"
    echo "  rg      -> $(check_command_type rg)"
    echo "  fd      -> $(check_command_type fd)"
    echo "  sd      -> $(check_command_type sd)"
    echo "  gawk    -> $(check_command_type gawk)"
else
    echo "✓ Context: HUMAN (using modern tools)"
    echo ""
    echo "Active aliases/functions (may be enhanced):"
    echo "  cat  -> $(check_command_type cat)"
    echo "  ls   -> $(check_command_type ls)"
    echo "  grep -> $(check_command_type grep)"
    echo "  find -> $(check_command_type find)"
    echo "  sed  -> $(check_command_type sed)"
    echo "  awk  -> $(check_command_type awk)"
    echo ""
    echo "Modern tool availability:"
    echo "  bat     -> $(check_command_type bat)"
    echo "  eza     -> $(check_command_type eza)"
    echo "  rg      -> $(check_command_type rg)"
    echo "  fd      -> $(check_command_type fd)"
    echo "  sd      -> $(check_command_type sd)"
    echo "  gawk    -> $(check_command_type gawk)"
fi

echo ""
echo "=== Test Complete ==="