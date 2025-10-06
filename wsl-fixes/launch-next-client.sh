#!/usr/bin/env bash
#
# Specific launcher for Next-Client with all known fixes
# This wraps launch-appimage.sh with Next-Client-specific workarounds
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE="$HOME/dev/Next-Client-1.10.0.AppImage"
PREFERENCE_FILE="$HOME/.config/Next-Client/hw-accel-preference"

# Handle --reset-preference flag
if [[ "$1" == "--reset-preference" ]]; then
    if [[ -f "$PREFERENCE_FILE" ]]; then
        rm "$PREFERENCE_FILE"
        echo "Preference file removed. You'll be prompted on next launch."
    else
        echo "No preference file found."
    fi
    exit 0
fi

if [[ ! -f "$APPIMAGE" ]]; then
    echo "Error: AppImage not found at $APPIMAGE"
    exit 1
fi

# Source DBus fix
source "$SCRIPT_DIR/fix-dbus-wsl.sh"

# Next-Client specific environment
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Environment will be cleaned by env -i below
# See ELECTRON_ENV_INVESTIGATION.md for details on the 15-18 variable threshold

# Ensure config directory exists
mkdir -p "$HOME/.config/Next-Client"

# Check for existing preference or prompt user
USE_HW_ACCEL="yes"  # Default to hardware acceleration

if [[ ! -f "$PREFERENCE_FILE" ]]; then
    echo "==================== Next-Client Hardware Acceleration ===================="
    echo ""
    echo "Next-Client can use hardware or software rendering:"
    echo ""
    echo "  [H] Hardware acceleration (RECOMMENDED - faster, uses GPU)"
    echo "      - Better performance and visual quality"
    echo "      - May have compatibility issues on some systems"
    echo ""
    echo "  [S] Software rendering (fallback - more compatible)"
    echo "      - Maximum compatibility, slower performance"
    echo "      - Use if you experience crashes or visual glitches"
    echo ""
    echo "Your choice will be saved to: $PREFERENCE_FILE"
    echo "Use --reset-preference to change this later"
    echo ""
    echo "==========================================================================="
    echo ""

    read -p "Choose rendering mode [H/s]: " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Ss]$ ]]; then
        USE_HW_ACCEL="no"
        echo "software" > "$PREFERENCE_FILE"
        echo "Preference saved: Software rendering"
    else
        USE_HW_ACCEL="yes"
        echo "hardware" > "$PREFERENCE_FILE"
        echo "Preference saved: Hardware acceleration"
    fi
    echo ""
else
    # Read existing preference
    PREFERENCE=$(cat "$PREFERENCE_FILE" | tr -d '[:space:]')
    if [[ "$PREFERENCE" == "software" ]]; then
        USE_HW_ACCEL="no"
    else
        USE_HW_ACCEL="yes"
    fi
fi

# Change to config directory
cd "$HOME/.config/Next-Client" || exit 1

if [[ "$USE_HW_ACCEL" == "yes" ]]; then
    # Hardware acceleration mode (DEFAULT)
    echo "Launching Next-Client with hardware acceleration..."
    echo "  DISPLAY: $DISPLAY"
    echo "  Hardware Acceleration: ENABLED"
    echo "  Working directory: $(pwd)"
    echo "  (Use --reset-preference to switch to software rendering)"
    echo ""

    # Launch with clean environment for fast startup
    # Hardware mode - minimal Electron flags, let GPU work
    exec env -i \
        HOME="$HOME" \
        USER="$USER" \
        SHELL="$SHELL" \
        DISPLAY="$DISPLAY" \
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin" \
        "$APPIMAGE" --no-sandbox "$@"
else
    # Software rendering mode (FALLBACK)
    echo "Launching Next-Client with software rendering (fallback mode)..."
    echo "  DISPLAY: $DISPLAY"
    echo "  Software Rendering: ENABLED"
    echo "  GPU: DISABLED"
    echo "  Working directory: $(pwd)"
    echo "  (Use --reset-preference to switch to hardware acceleration)"
    echo ""

    # Software rendering environment variables
    export LIBGL_ALWAYS_SOFTWARE=1
    export ELECTRON_EXTRA_LAUNCH_ARGS="--disable-gpu --no-sandbox --disable-dev-shm-usage --disable-software-rasterizer --disable-features=VaapiVideoDecoder"
    export GDK_BACKEND=x11
    export LIBVA_DRIVER_NAME=none

    # Launch with clean environment for fast startup
    # Software mode - full compatibility flags
    exec env -i \
        HOME="$HOME" \
        USER="$USER" \
        SHELL="$SHELL" \
        DISPLAY="$DISPLAY" \
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        LIBVA_DRIVER_NAME="$LIBVA_DRIVER_NAME" \
        GDK_BACKEND="$GDK_BACKEND" \
        LIBGL_ALWAYS_SOFTWARE="$LIBGL_ALWAYS_SOFTWARE" \
        ELECTRON_EXTRA_LAUNCH_ARGS="$ELECTRON_EXTRA_LAUNCH_ARGS" \
        PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin" \
        "$APPIMAGE" "$@"
fi