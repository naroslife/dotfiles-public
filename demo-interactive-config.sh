#!/usr/bin/env bash
# Demo script for interactive user configuration
#
# This script demonstrates the interactive configuration feature
# without actually applying any changes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the libraries
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/user_config.sh"

# Override config location for demo
export USER_CONFIG_FILE="/tmp/demo-user.conf"
export USER_CONFIG_DIR="/tmp"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Interactive Configuration Demo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "This is a demonstration of the interactive user configuration system."
echo "Your actual configuration will NOT be modified."
echo

# Run the interactive configuration
if run_interactive_config; then
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Generated Configuration Files"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    if [[ -f "/tmp/demo-user.conf" ]]; then
        echo "Shell Configuration (/tmp/demo-user.conf):"
        echo "-------------------------------------------"
        cat "/tmp/demo-user.conf"
        echo
    fi

    if [[ -f "/tmp/user.nix" ]]; then
        echo "Nix Configuration (/tmp/user.nix):"
        echo "-------------------------------------------"
        cat "/tmp/user.nix"
        echo
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Demo completed successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "To use this feature in your actual setup, run:"
    echo "  ./apply.sh --interactive"
    echo

    # Cleanup demo files
    rm -f /tmp/demo-user.conf /tmp/user.nix
else
    echo
    echo "Demo cancelled or failed."
fi