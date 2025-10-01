#!/usr/bin/env bash
#
# AppImage Launcher for WSL2
# Fixes common Electron/AppImage issues on WSL2
#
# Usage: launch-appimage.sh <path-to-appimage> [args...]
#

set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: $(basename "$0") <path-to-appimage> [args...]"
    exit 1
fi

APPIMAGE="$1"
shift

if [[ ! -f "$APPIMAGE" ]]; then
    echo "Error: AppImage not found: $APPIMAGE"
    exit 1
fi

if [[ ! -x "$APPIMAGE" ]]; then
    echo "Error: AppImage is not executable: $APPIMAGE"
    echo "Run: chmod +x $APPIMAGE"
    exit 1
fi

# Ensure DBus session exists
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    # Try to restore from saved session
    if [[ -f ~/.dbus-session ]]; then
        source ~/.dbus-session
    fi

    # If still not set, start a new session
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        eval $(dbus-launch --sh-syntax)
        echo "export DBUS_SESSION_BUS_ADDRESS='$DBUS_SESSION_BUS_ADDRESS'" > ~/.dbus-session
        echo "export DBUS_SESSION_BUS_PID='$DBUS_SESSION_BUS_PID'" >> ~/.dbus-session
    fi
fi

# Set XDG_RUNTIME_DIR if not set
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Ensure DISPLAY is set
export DISPLAY="${DISPLAY:-:0}"

# Environment cleanup for Electron performance
# Investigation showed that environment variable COUNT (not specific variables)
# causes slow startup. Threshold is ~15-18 variables. With 155 vars from Nix/CUDA
# setup, Electron takes 60+ seconds. We use env -i below to start clean.
# See ELECTRON_ENV_INVESTIGATION.md for full analysis.

# Disable VA-API to prevent libva errors
export LIBVA_DRIVER_NAME=none

# GPU rendering configuration for WSL2
# Enable GPU acceleration with optimized flags for WSLg
export MESA_LOADER_DRIVER_OVERRIDE=d3d12
export MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA

# Electron flags optimized for WSL2/WSLg performance
# Try software rendering first for compatibility, then GPU if that's slow
# To enable GPU: uncomment the GPU line and comment the software line
export ELECTRON_EXTRA_LAUNCH_ARGS="--no-sandbox --disable-dev-shm-usage --disable-gpu --in-process-gpu --disable-software-rasterizer"
# GPU acceleration (comment above, uncomment below):
# export ELECTRON_EXTRA_LAUNCH_ARGS="--no-sandbox --disable-dev-shm-usage --disable-gpu-sandbox --enable-features=VulkanFromANGLE --use-gl=angle --ignore-gpu-blocklist --disable-features=VaapiVideoDecoder"

# Disable Wayland (use X11 instead for better compatibility)
export GDK_BACKEND=x11

echo "Starting AppImage with WSL2 fixes..."
echo "  DISPLAY: $DISPLAY"
echo "  DBUS: $DBUS_SESSION_BUS_ADDRESS"
echo "  XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
echo

# Detect config directory for the app
# Extract app name from AppImage filename (e.g., Next-Client-1.10.0.AppImage -> Next-Client)
APPIMAGE_BASENAME=$(basename "$APPIMAGE")
APP_NAME=$(echo "$APPIMAGE_BASENAME" | sed -E 's/-[0-9]+\.[0-9]+\.[0-9]+\.AppImage$//')

# Change to app config directory if it exists
# This helps apps that look for settings.json in the current directory
CONFIG_DIR="$HOME/.config/$APP_NAME"
if [[ -d "$CONFIG_DIR" ]]; then
    cd "$CONFIG_DIR"
    echo "Working directory: $CONFIG_DIR"
    echo
fi

# Launch with clean environment (env -i) to avoid slow startup
# Critical: Keep total variables under 15-18 for fast startup (see investigation doc)
# We pass only 10-12 essential variables here for ~2-3 second startup vs 60+ seconds
exec env -i \
    HOME="$HOME" \
    USER="$USER" \
    SHELL="$SHELL" \
    DISPLAY="$DISPLAY" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    LIBVA_DRIVER_NAME="$LIBVA_DRIVER_NAME" \
    GDK_BACKEND="$GDK_BACKEND" \
    ELECTRON_EXTRA_LAUNCH_ARGS="$ELECTRON_EXTRA_LAUNCH_ARGS" \
    MESA_LOADER_DRIVER_OVERRIDE="$MESA_LOADER_DRIVER_OVERRIDE" \
    MESA_D3D12_DEFAULT_ADAPTER_NAME="$MESA_D3D12_DEFAULT_ADAPTER_NAME" \
    PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin" \
    "$APPIMAGE" "$@"