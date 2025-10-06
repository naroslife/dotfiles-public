#!/usr/bin/env bash
#
# detect-platform.sh - Detect remote platform characteristics
#

set -euo pipefail

# Platform detection
detect_platform() {
    local platform="unknown"
    local is_wsl=false

    # Check for WSL
    if grep -qi microsoft /proc/version 2>/dev/null || \
       [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
        is_wsl=true
        platform="wsl"
    elif [[ -f /etc/os-release ]]; then
        # Regular Linux
        . /etc/os-release
        platform="${ID:-unknown}"
    fi

    echo "$platform"
}

# Architecture detection
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        armv7l)
            echo "armv7l"
            ;;
        *)
            echo "$(uname -m)"
            ;;
    esac
}

# OS version detection
detect_os_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${VERSION_ID:-unknown}"
    else
        echo "unknown"
    fi
}

# Check for Nix
check_nix() {
    if command -v nix >/dev/null 2>&1; then
        echo "installed"
        nix --version | head -1
    else
        echo "not_installed"
    fi
}

# Check disk space
check_disk_space() {
    local path="${1:-/}"
    df -h "$path" | tail -1 | awk '{print $4}'
}

# Check memory
check_memory() {
    free -h | grep "^Mem:" | awk '{print $2}'
}

# Check for systemd
check_systemd() {
    if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
        echo "available"
    else
        echo "not_available"
    fi
}

# Check for existing Home Manager
check_home_manager() {
    if command -v home-manager >/dev/null 2>&1; then
        echo "installed"
        home-manager --version 2>/dev/null || echo "version_unknown"
    else
        echo "not_installed"
    fi
}

# Check for corporate proxy
check_proxy() {
    if [[ -n "${HTTP_PROXY:-}" ]] || [[ -n "${HTTPS_PROXY:-}" ]]; then
        echo "configured"
        echo "HTTP_PROXY: ${HTTP_PROXY:-not_set}"
        echo "HTTPS_PROXY: ${HTTPS_PROXY:-not_set}"
    else
        echo "not_configured"
    fi
}

# WSL-specific checks
wsl_checks() {
    if [[ "$(detect_platform)" == "wsl" ]]; then
        echo "WSL_VERSION: ${WSL_DISTRO_NAME:-unknown}"

        # Check WSL version
        if [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
            echo "WSL2: yes"
        else
            echo "WSL1: maybe"
        fi

        # Check Windows interop
        if [[ -n "${WSLENV:-}" ]]; then
            echo "WINDOWS_INTEROP: enabled"
        else
            echo "WINDOWS_INTEROP: disabled"
        fi

        # Check systemd in WSL
        if [[ -f /etc/wsl.conf ]]; then
            if grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
                echo "SYSTEMD_WSL: enabled"
            else
                echo "SYSTEMD_WSL: disabled"
            fi
        fi
    fi
}

# Main output
main() {
    cat << EOF
{
  "platform": "$(detect_platform)",
  "arch": "$(detect_arch)",
  "os_version": "$(detect_os_version)",
  "kernel": "$(uname -r)",
  "nix": "$(check_nix)",
  "home_manager": "$(check_home_manager)",
  "disk_space": "$(check_disk_space /)",
  "memory": "$(check_memory)",
  "systemd": "$(check_systemd)",
  "proxy": "$(check_proxy)",
  "user": "$(whoami)",
  "home": "$HOME",
  "shell": "$SHELL",
  "path_separator": ":",
  "temp_dir": "${TMPDIR:-/tmp}"
}
EOF

    # Add WSL-specific information if applicable
    if [[ "$(detect_platform)" == "wsl" ]]; then
        echo "WSL_INFO:"
        wsl_checks
    fi
}

main "$@"