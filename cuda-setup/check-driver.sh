#!/usr/bin/env bash
#
# NVIDIA Driver Compatibility Checker for CUDA 12.9
# Verifies that Windows NVIDIA drivers meet CUDA 12.9 requirements
#

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/common.sh"
elif [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/../lib/common.sh"
else
    echo "Error: Could not find common.sh" >&2
    exit 1
fi

# CUDA 12.9 minimum driver requirements
# Source: https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html
  CUDA_VERSION="12.9"
  MIN_WINDOWS_DRIVER="528.33"  # Minimum Windows driver for CUDA 12.9
  RECOMMENDED_DRIVER="566.03"   # Latest stable driver (as of March 2024)

# Fix nvidia-smi segfault by using Windows version
fix_nvidia_smi() {
    local wsl_nvidia_smi="/usr/lib/wsl/lib/nvidia-smi"
    local windows_nvidia_smi="/mnt/c/Windows/System32/nvidia-smi.exe"

    # Check if Windows nvidia-smi exists
    if [[ ! -f "$windows_nvidia_smi" ]]; then
        return 1  # Will be caught by get_driver_version
    fi

    # Check if already a working symlink
    if [[ -L "$wsl_nvidia_smi" ]]; then
        if timeout 3 nvidia-smi >/dev/null 2>&1; then
            return 0  # Already fixed and working
        fi
    fi

    # Test if nvidia-smi needs fixing
    if [[ -f "$wsl_nvidia_smi" ]] && ! [[ -L "$wsl_nvidia_smi" ]]; then
        if ! timeout 3 "$wsl_nvidia_smi" >/dev/null 2>&1; then
            log_warning "nvidia-smi is segfaulting, applying automatic fix..."

            # Backup old version
            sudo mv "$wsl_nvidia_smi" "${wsl_nvidia_smi}.old" 2>/dev/null || true

            # Create symlink to Windows version
            sudo ln -sf "$windows_nvidia_smi" "$wsl_nvidia_smi"

            if timeout 3 nvidia-smi >/dev/null 2>&1; then
                log_success "nvidia-smi fixed automatically"
            else
                log_warning "Automatic fix applied but nvidia-smi may still have issues"
            fi
        fi
    elif [[ ! -e "$wsl_nvidia_smi" ]]; then
        # nvidia-smi doesn't exist, create symlink
        sudo mkdir -p "$(dirname "$wsl_nvidia_smi")" 2>/dev/null || true
        sudo ln -sf "$windows_nvidia_smi" "$wsl_nvidia_smi" 2>/dev/null || true
    fi

    return 0
}

# Compare version numbers (returns 0 if ver1 >= ver2)
version_ge() {
    local ver1="$1"
    local ver2="$2"

    # Handle versions with different number of components
    printf '%s\n%s\n' "$ver2" "$ver1" | sort -V -C 2>/dev/null
}

# Get Windows NVIDIA driver version
get_driver_version() {
    if [[ ! -f /mnt/c/Windows/System32/nvidia-smi.exe ]]; then
        return 1
    fi

    local driver_output
    driver_output=$(/mnt/c/Windows/System32/nvidia-smi.exe 2>&1 || true)

    if echo "$driver_output" | command grep -q "Driver Version:"; then
        echo "$driver_output" | command grep -oP 'Driver Version: \K[0-9.]+' | head -1
        return 0
    fi

    return 1
}

# Get CUDA version supported by driver
get_driver_cuda_version() {
    if [[ ! -f /mnt/c/Windows/System32/nvidia-smi.exe ]]; then
        return 1
    fi

    local driver_output
    driver_output=$(/mnt/c/Windows/System32/nvidia-smi.exe 2>&1 || true)

    if echo "$driver_output" | command grep -q "CUDA Version:"; then
        echo "$driver_output" | command grep -oP 'CUDA Version: \K[0-9.]+' | head -1
        return 0
    fi

    return 1
}

# Get GPU name
get_gpu_name() {
    if [[ ! -f /mnt/c/Windows/System32/nvidia-smi.exe ]]; then
        return 1
    fi

    local gpu_info
    gpu_info=$(/mnt/c/Windows/System32/nvidia-smi.exe --query-gpu=name --format=csv,noheader 2>/dev/null || true)

    if [[ -n "$gpu_info" ]]; then
        echo "$gpu_info"
        return 0
    fi

    return 1
}

# Print driver download instructions
print_driver_update_instructions() {
    local current_version="$1"

    echo
    echo "=========================================="
    echo "Driver Update Required"
    echo "=========================================="
    echo
    log_error "Your current driver ($current_version) does not support CUDA $CUDA_VERSION"
    log_info "Minimum required: $MIN_WINDOWS_DRIVER"
    log_info "Recommended: $RECOMMENDED_DRIVER or newer"
    echo
    log_info "How to update your NVIDIA driver on Windows:"
    echo
    echo "Option 1: GeForce Experience (Easiest)"
    echo "  1. Open GeForce Experience on Windows"
    echo "  2. Go to 'Drivers' tab"
    echo "  3. Click 'Check for Updates'"
    echo "  4. Download and install the latest driver"
    echo
    echo "Option 2: Manual Download"
    echo "  1. Visit: https://www.nvidia.com/Download/index.aspx"
    echo "  2. Select your GPU model"
    echo "  3. Download the latest driver (Game Ready or Studio)"
    echo "  4. Run the installer on Windows"
    echo
    echo "Option 3: Windows Update"
    echo "  1. Open Windows Settings → Update & Security"
    echo "  2. Click 'Check for updates'"
    echo "  3. Install any NVIDIA driver updates"
    echo
    log_warning "After updating the driver on Windows:"
    echo "  1. Restart Windows (recommended)"
    echo "  2. Restart WSL: wsl --shutdown (in PowerShell)"
    echo "  3. Relaunch Ubuntu"
    echo "  4. Run this script again to verify"
    echo
}

# Print success summary
print_success_summary() {
    local driver_version="$1"
    local cuda_version="$2"
    local gpu_name="$3"

    echo
    echo "=========================================="
    echo "Driver Compatibility Check Passed"
    echo "=========================================="
    echo
    log_success "Your NVIDIA driver supports CUDA $CUDA_VERSION"
    echo
    echo "System Information:"
    echo "  GPU: $gpu_name"
    echo "  Windows Driver: $driver_version"
    echo "  Max CUDA Version: $cuda_version"
    echo "  Required for CUDA 12.9: $MIN_WINDOWS_DRIVER+"
    echo

    if ! version_ge "$driver_version" "$RECOMMENDED_DRIVER"; then
        log_info "A newer driver ($RECOMMENDED_DRIVER+) is available"
        log_info "Consider updating for latest features and bug fixes"
        log_info "Download from: https://www.nvidia.com/Download/index.aspx"
        echo
    fi

    log_success "You can proceed with CUDA 12.9 installation"
    echo
}

# Main check function
main() {
    echo
    log_info "NVIDIA Driver Compatibility Checker for CUDA $CUDA_VERSION"
    echo

    # Check if WSL2
    if ! is_wsl2; then
        exit 1
    fi

    # Fix nvidia-smi if needed
    log_info "Checking nvidia-smi..."
    fix_nvidia_smi

    # Get driver version
    log_info "Checking Windows NVIDIA driver..."

    local driver_version
    if ! driver_version=$(get_driver_version); then
        log_error "Windows NVIDIA driver not found"
        log_error "Please install NVIDIA drivers on Windows first"
        echo
        log_info "Download from: https://www.nvidia.com/Download/index.aspx"
        exit 1
    fi

    log_info "Found driver version: $driver_version"

    # Get GPU info
    local gpu_name
    if gpu_name=$(get_gpu_name); then
        log_info "GPU: $gpu_name"
    fi

    # Get CUDA version supported by driver
    local driver_cuda_version
    if driver_cuda_version=$(get_driver_cuda_version); then
        log_info "Driver supports CUDA: $driver_cuda_version"
    fi

    # Check if driver meets minimum requirements
    echo
    log_info "Checking compatibility with CUDA $CUDA_VERSION..."

    if version_ge "$driver_version" "$MIN_WINDOWS_DRIVER"; then
        print_success_summary "$driver_version" "${driver_cuda_version:-unknown}" "${gpu_name:-unknown}"
        exit 0
    else
        print_driver_update_instructions "$driver_version"
        exit 1
    fi
}

main "$@"
