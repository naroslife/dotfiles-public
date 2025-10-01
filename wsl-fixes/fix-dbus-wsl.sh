#!/usr/bin/env bash
#
# Fix DBus for Electron/GUI apps in WSL2
# This ensures a proper DBus session is available
#

# If DBUS_SESSION_BUS_ADDRESS is already set and working, nothing to do
if [[ -n "$DBUS_SESSION_BUS_ADDRESS" ]]; then
    if dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames &>/dev/null; then
        echo "DBus already configured: $DBUS_SESSION_BUS_ADDRESS"
        return 0 2>/dev/null || exit 0
    else
        # Address set but not working, clear it
        unset DBUS_SESSION_BUS_ADDRESS
        unset DBUS_SESSION_BUS_PID
    fi
fi

# Try to load existing DBus session from saved file
if [[ -f ~/.dbus-session ]]; then
    source ~/.dbus-session 2>/dev/null
    # Verify the loaded session is still valid
    if [[ -n "$DBUS_SESSION_BUS_ADDRESS" ]]; then
        if dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames &>/dev/null; then
            # Export the variables so they're available in the current shell
            export DBUS_SESSION_BUS_ADDRESS
            export DBUS_SESSION_BUS_PID
            if [[ -n "$DBUS_SESSION_BUS_PID" ]]; then
                echo "Reusing saved DBus session (PID: $DBUS_SESSION_BUS_PID)"
            else
                echo "Reusing saved DBus session"
            fi
            echo "DBus configured: $DBUS_SESSION_BUS_ADDRESS"
            return 0 2>/dev/null || exit 0
        else
            # Saved session not responsive, clear it
            rm -f ~/.dbus-session 2>/dev/null
            unset DBUS_SESSION_BUS_ADDRESS
            unset DBUS_SESSION_BUS_PID
        fi
    fi
fi

# Check if systemd DBus socket exists and is responsive
if [[ -S "/run/user/$(id -u)/bus" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    if dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames &>/dev/null; then
        # Save this for future shells
        echo "export DBUS_SESSION_BUS_ADDRESS='$DBUS_SESSION_BUS_ADDRESS'" > ~/.dbus-session
        echo "Using system DBus daemon at /run/user/$(id -u)/bus"
        echo "DBus configured: $DBUS_SESSION_BUS_ADDRESS"
        return 0 2>/dev/null || exit 0
    else
        # Socket exists but not responsive, unset and continue
        unset DBUS_SESSION_BUS_ADDRESS
    fi
fi

# No existing session found, start a new one with dbus-launch
echo "Starting new DBus session..."

# Kill any orphaned dbus-daemon processes
pkill -u $(id -u) dbus-daemon 2>/dev/null || true
sleep 0.2

# Start dbus-daemon and save the address
eval $(dbus-launch --sh-syntax --exit-with-session)

if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
    echo "Error: Failed to start DBus session"
    return 1 2>/dev/null || exit 1
fi

# Save for future shells
echo "export DBUS_SESSION_BUS_ADDRESS='$DBUS_SESSION_BUS_ADDRESS'" > ~/.dbus-session
if [[ -n "$DBUS_SESSION_BUS_PID" ]]; then
    echo "export DBUS_SESSION_BUS_PID='$DBUS_SESSION_BUS_PID'" >> ~/.dbus-session
fi

# Wait for daemon to be ready
sleep 0.3

if [[ -n "$DBUS_SESSION_BUS_PID" ]]; then
    echo "Started new DBus session (PID: $DBUS_SESSION_BUS_PID)"
else
    echo "Started new DBus session"
fi
echo "DBus configured: $DBUS_SESSION_BUS_ADDRESS"