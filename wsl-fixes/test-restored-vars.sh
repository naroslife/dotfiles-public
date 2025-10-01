#!/usr/bin/env bash
#
# Test launcher with restored environment variables
#
# Usage:
#   1. Edit wsl-fixes/restore-env-vars.conf and uncomment variables you want
#   2. Run this script: wsl-fixes/test-restored-vars.sh
#

set -euo pipefail

APPIMAGE="$HOME/dev/Next-Client-1.10.0/squashfs-root/next-client"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/restore-env-vars.conf"

echo "=== Testing Restored Environment Variables ==="
echo ""

# Extract uncommented variables from config file
RESTORED_VARS=()
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # If it looks like a variable assignment, add it
    if [[ "$line" =~ ^[A-Z_][A-Z0-9_]*= ]]; then
        RESTORED_VARS+=("$line")
    fi
done < "$CONFIG_FILE"

echo "Found ${#RESTORED_VARS[@]} uncommented variables to restore"
if [ ${#RESTORED_VARS[@]} -eq 0 ]; then
    echo "No variables uncommented in $CONFIG_FILE"
    echo "Edit the file and uncomment variables you want to test."
    exit 0
fi

echo "Variables to restore:"
for var in "${RESTORED_VARS[@]}"; do
    echo "  - ${var%%=*}"
done
echo ""

# Base variables (always included)
BASE_VARS=(
    "HOME=$HOME"
    "USER=$USER"
    "DISPLAY=${DISPLAY:-:0}"
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    "DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
    "PATH=/usr/local/bin:/usr/bin:/bin"
    "LIBVA_DRIVER_NAME=none"
    "SHELL=$SHELL"
)

# Combine base + restored variables
ALL_VARS=("${BASE_VARS[@]}" "${RESTORED_VARS[@]}")
TOTAL_VARS=${#ALL_VARS[@]}

echo "Total variables: $TOTAL_VARS (8 base + ${#RESTORED_VARS[@]} restored)"
echo ""

if [ $TOTAL_VARS -gt 15 ]; then
    echo "⚠️  WARNING: You have $TOTAL_VARS total variables."
    echo "   Investigation showed that >15 variables may cause slow startup."
    echo "   Consider reducing to 10-15 total variables for best performance."
    echo ""
fi

echo "Starting application with restored variables..."
echo "Press Ctrl+C to stop if it hangs."
echo ""

# Launch with restored variables
exec env -i "${ALL_VARS[@]}" "$APPIMAGE" "$@"