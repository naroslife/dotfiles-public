#!/usr/bin/env bash
#
# Specific launcher for Next-Client with all known fixes
# This wraps launch-appimage.sh with Next-Client-specific workarounds
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE="$HOME/dev/Next-Client-1.10.0.AppImage"

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

# Force software rendering (most reliable for Electron apps on WSLg)
export LIBGL_ALWAYS_SOFTWARE=1

# Disable GPU entirely for maximum compatibility
export ELECTRON_EXTRA_LAUNCH_ARGS="--disable-gpu --no-sandbox --disable-dev-shm-usage --disable-software-rasterizer --disable-features=VaapiVideoDecoder"

# Use X11, not Wayland
export GDK_BACKEND=x11

# Disable hardware video decoding
export LIBVA_DRIVER_NAME=none

# Change to config directory
cd "$HOME/.config/Next-Client" || mkdir -p "$HOME/.config/Next-Client" && cd "$HOME/.config/Next-Client"

echo "Launching Next-Client with maximum compatibility settings..."
echo "  DISPLAY: $DISPLAY"
echo "  Software Rendering: ENABLED"
echo "  GPU: DISABLED"
echo "  Working directory: $(pwd)"
echo

# Launch with clean environment (env -i) for fast startup
# Passing only 10 essential variables keeps us well under the 15-18 threshold
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