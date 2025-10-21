#!/usr/bin/env bash
#
# Fix nvidia-smi Segfault on WSL2
# Replaces the broken WSL nvidia-smi with a symlink to the Windows version
#

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
if [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    source "$SCRIPT_DIR/../lib/common.sh"
else
    echo "Error: Cannot find lib/common.sh" >&2
    exit 1
fi

# Wrapper for log_warn (common.sh uses log_warn, not log_warning)
log_warning() {
    log_warn "$1"
}

# Check if running on WSL2
check_wsl2() {
    if ! is_wsl2; then
        log_error "This script is designed for WSL2"
        return 1
    fi
    return 0
}

# Fix nvidia-smi segfault by using Windows version
fix_nvidia_smi() {
    local wsl_nvidia_smi="/usr/lib/wsl/lib/nvidia-smi"
    local windows_nvidia_smi="/mnt/c/Windows/System32/nvidia-smi.exe"

    # Check if Windows nvidia-smi exists
    if [[ ! -f "$windows_nvidia_smi" ]]; then
        log_error "Windows nvidia-smi not found at $windows_nvidia_smi"
        log_error "Please install NVIDIA drivers on Windows first"
        return 1
    fi

    # Check if WSL nvidia-smi is a symlink already
    if [[ -L "$wsl_nvidia_smi" ]]; then
        local target=$(readlink -f "$wsl_nvidia_smi")
        log_success "nvidia-smi is already a symlink to: $target"

        # Verify the symlink works
        if timeout 3 nvidia-smi >/dev/null 2>&1; then
            log_success "nvidia-smi is working correctly"
            return 0
        else
            log_warning "Symlink exists but nvidia-smi still failing, recreating..."
            sudo rm "$wsl_nvidia_smi"
        fi
    fi

    # Test if nvidia-smi needs fixing
    if [[ -f "$wsl_nvidia_smi" ]] && ! [[ -L "$wsl_nvidia_smi" ]]; then
        log_info "Testing current nvidia-smi..."

        if timeout 3 "$wsl_nvidia_smi" >/dev/null 2>&1; then
            log_success "nvidia-smi is working correctly, no fix needed"
            return 0
        else
            log_warning "nvidia-smi is segfaulting, applying fix..."

            # Backup old version
            sudo mv "$wsl_nvidia_smi" "${wsl_nvidia_smi}.old.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
            log_info "Backed up old nvidia-smi"
        fi
    fi

    # Create directory if it doesn't exist
    if [[ ! -d "$(dirname "$wsl_nvidia_smi")" ]]; then
        log_info "Creating directory: $(dirname "$wsl_nvidia_smi")"
        sudo mkdir -p "$(dirname "$wsl_nvidia_smi")"
    fi

    # Create symlink to Windows version
    log_info "Creating symlink to Windows nvidia-smi..."
    sudo ln -sf "$windows_nvidia_smi" "$wsl_nvidia_smi"

    # Verify the fix worked
    if timeout 3 nvidia-smi >/dev/null 2>&1; then
        log_success "nvidia-smi fix applied successfully!"
        return 0
    else
        log_error "Fix applied but nvidia-smi still not working"
        return 1
    fi
}

# Main
main() {
    echo
    log_info "nvidia-smi Segfault Fix for WSL2"
    echo

    if ! check_wsl2; then
        exit 1
    fi

    if ! fix_nvidia_smi; then
        echo
        log_error "Failed to fix nvidia-smi"
        log_info "Manual fix:"
        log_info "  sudo mv /usr/lib/wsl/lib/nvidia-smi /usr/lib/wsl/lib/nvidia-smi.old"
        log_info "  sudo ln -s /mnt/c/Windows/System32/nvidia-smi.exe /usr/lib/wsl/lib/nvidia-smi"
        exit 1
    fi

    echo
    log_success "All done! Testing nvidia-smi output:"
    echo
    nvidia-smi --query-gpu=name,driver_version,cuda_version --format=csv,noheader
    echo
}

main "$@"
