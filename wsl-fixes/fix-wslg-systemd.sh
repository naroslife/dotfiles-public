#!/usr/bin/env bash
#
# Fix WSLg systemd service conflicts
#
# WSLg provides its own audio via /mnt/wslg/PulseServer
# Ubuntu's systemd pulseaudio services conflict with this
# and cause "degraded" systemd status on home-manager activation
#

echo "Checking WSLg systemd service conflicts..."

# Check if services are masked
NEEDS_FIX=false

if ! systemctl --user is-enabled pulseaudio.service 2>&1 | grep -q "masked"; then
    NEEDS_FIX=true
fi

if [[ "$NEEDS_FIX" == "true" ]]; then
    echo "Masking conflicting systemd services..."

    # Stop services first
    systemctl --user stop pulseaudio.service pulseaudio.socket wslg-runtime-dir.service 2>/dev/null || true

    # Mask them to prevent future activation
    systemctl --user mask pulseaudio.service pulseaudio.socket wslg-runtime-dir.service 2>/dev/null || true

    echo "✓ Fixed WSLg systemd conflicts"
    echo
    echo "Note: Audio still works via WSLg's native /mnt/wslg/PulseServer"
else
    echo "✓ WSLg systemd services already masked"
fi