#!/usr/bin/env bash
#
# Diagnose WSL2 GUI/WSLg issues
#

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            WSL2 GUI Diagnostics                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

echo "=== WSL Version ==="
wsl.exe --version 2>&1 | head -10
echo

echo "=== Display Configuration ==="
echo "DISPLAY: ${DISPLAY:-NOT SET}"
echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-NOT SET}"
echo

echo "=== X11 Sockets ==="
command ls -la /tmp/.X11-unix/ 2>&1 | head -5
command ls -la /mnt/wslg/.X11-unix/ 2>&1 | head -5
echo

echo "=== WSLg Directory ==="
command ls -la /mnt/wslg/ 2>&1 | head -10
echo

echo "=== X Server Test ==="
if xdpyinfo -display :0 >/dev/null 2>&1; then
    echo "✓ X server is responsive on :0"
    xdpyinfo -display :0 2>&1 | head -5
else
    echo "✗ X server not responding on :0"
fi
echo

echo "=== DBus Configuration ==="
echo "DBUS_SESSION_BUS_ADDRESS: ${DBUS_SESSION_BUS_ADDRESS:-NOT SET}"
if [[ -n "$DBUS_SESSION_BUS_ADDRESS" ]]; then
    if dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
        echo "✓ DBus session is responsive"
    else
        echo "✗ DBus session not responding"
    fi
fi
echo

echo "=== GPU/Rendering Libraries ==="
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo 2>&1 | grep -i "opengl\|direct rendering" | head -5
else
    echo "glxinfo not installed (optional)"
fi
echo

echo "=== Simple X11 Test ==="
echo "Attempting to run xclock for 3 seconds..."
if command -v xclock >/dev/null 2>&1; then
    timeout 3 xclock -display :0 &>/dev/null &
    sleep 1
    if ps -p $! >/dev/null 2>&1; then
        echo "✓ xclock is running (window should appear)"
        kill $! 2>/dev/null || true
    else
        echo "✗ xclock failed to start"
    fi
else
    echo "xclock not installed (optional test)"
fi
echo

echo "=== Electron/Chrome Sandbox ==="
if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
    clone_value=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null)
    echo "unprivileged_userns_clone: $clone_value"
    if [[ "$clone_value" == "1" ]]; then
        echo "✓ User namespaces enabled (Electron sandbox supported)"
    else
        echo "⚠ User namespaces disabled (use --no-sandbox flag)"
    fi
else
    echo "✓ User namespaces check not applicable"
fi
echo

echo "=== Recommendations ==="
if [[ -z "$DISPLAY" ]]; then
    echo "✗ DISPLAY not set - add to shell: export DISPLAY=:0"
fi

if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
    echo "✗ DBus not configured - run: source ~/dotfiles-public/wsl-fixes/fix-dbus-wsl.sh"
fi

if ! xdpyinfo -display :0 >/dev/null 2>&1; then
    echo "✗ X server not working - try: wsl --shutdown then restart WSL"
fi

echo
echo "For Electron apps that don't show windows, try:"
echo "  LIBGL_ALWAYS_SOFTWARE=1 --disable-gpu --no-sandbox"
echo
