#!/usr/bin/env bash
#
# CUDA 12 Installation Script for WSL2 Ubuntu
# This script installs and configures CUDA 12 toolkit on WSL2
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
        log_error "This script is designed for WSL2. Not running on WSL2."
        exit 1
    fi
    log_success "Running on WSL2"
    return 0
}

# CUDA 12.9 minimum driver requirements
readonly CUDA_VERSION="12.9"
readonly MIN_WINDOWS_DRIVER="528.33"

# Compare version numbers (returns 0 if ver1 >= ver2)
version_ge() {
    local ver1="$1"
    local ver2="$2"
    printf '%s\n%s\n' "$ver2" "$ver1" | sort -V -C 2>/dev/null
}

# Check Windows NVIDIA driver
check_windows_driver() {
    log_info "Checking Windows NVIDIA driver compatibility with CUDA $CUDA_VERSION..."

    if [[ ! -f /mnt/c/Windows/System32/nvidia-smi.exe ]]; then
        log_error "Windows NVIDIA driver not found"
        log_error "Please install NVIDIA drivers on Windows host first"
        log_error "Download from: https://www.nvidia.com/Download/index.aspx"
        exit 1
    fi

    local driver_output
    driver_output=$(/mnt/c/Windows/System32/nvidia-smi.exe 2>&1 || true)

    if ! echo "$driver_output" | grep -q "Driver Version:"; then
        log_error "Windows NVIDIA driver not working properly"
        log_error "Please reinstall NVIDIA drivers on Windows"
        exit 1
    fi

    local driver_version=$(echo "$driver_output" | grep -oP 'Driver Version: \K[0-9.]+' | head -1)
    local cuda_version=$(echo "$driver_output" | grep -oP 'CUDA Version: \K[0-9.]+' | head -1)

    log_success "Windows NVIDIA driver installed: $driver_version"
    log_info "Driver supports CUDA: $cuda_version"

    # Check if driver meets minimum requirements for CUDA 12.9
    if ! version_ge "$driver_version" "$MIN_WINDOWS_DRIVER"; then
        echo
        log_error "Driver version $driver_version does NOT support CUDA $CUDA_VERSION"
        log_error "Minimum required driver: $MIN_WINDOWS_DRIVER"
        echo
        log_warning "Please update your Windows NVIDIA driver:"
        log_info "  1. Visit: https://www.nvidia.com/Download/index.aspx"
        log_info "  2. Or use GeForce Experience on Windows"
        log_info "  3. After updating, restart WSL: wsl --shutdown"
        echo
        log_info "Run './check-driver.sh' for detailed update instructions"
        exit 1
    fi

    log_success "Driver supports CUDA $CUDA_VERSION (minimum: $MIN_WINDOWS_DRIVER)"
    return 0
}

# Check Ubuntu version
check_ubuntu_version() {
    log_info "Checking Ubuntu version..."

    if [[ ! -f /etc/lsb-release ]]; then
        log_error "Not running on Ubuntu"
        exit 1
    fi

    source /etc/lsb-release
    log_success "Ubuntu $DISTRIB_RELEASE ($DISTRIB_CODENAME)"

    if [[ "$DISTRIB_RELEASE" != "22.04" ]] && [[ "$DISTRIB_RELEASE" != "20.04" ]]; then
        log_warning "This script is tested on Ubuntu 20.04 and 22.04"
        log_warning "Your version: $DISTRIB_RELEASE"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Fix nvidia-smi segfault by using Windows version
fix_nvidia_smi() {
    log_info "Checking nvidia-smi..."

    local wsl_nvidia_smi="/usr/lib/wsl/lib/nvidia-smi"

    if [[ -f "$wsl_nvidia_smi" ]] && [[ ! -L "$wsl_nvidia_smi" ]]; then
        # Test if it segfaults
        if ! timeout 3 "$wsl_nvidia_smi" &>/dev/null; then
            log_warning "nvidia-smi segfaulting, replacing with Windows version"

            # Backup old version
            sudo mv "$wsl_nvidia_smi" "${wsl_nvidia_smi}.old"

            # Create symlink to Windows version
            sudo ln -s /mnt/c/Windows/System32/nvidia-smi.exe "$wsl_nvidia_smi"

            log_success "Replaced nvidia-smi with Windows version"
        else
            log_success "nvidia-smi working correctly"
        fi
    elif [[ -L "$wsl_nvidia_smi" ]]; then
        log_success "nvidia-smi already configured as symlink"
    else
        log_info "nvidia-smi not found in /usr/lib/wsl/lib, will use Windows version"
        sudo mkdir -p /usr/lib/wsl/lib
        sudo ln -s /mnt/c/Windows/System32/nvidia-smi.exe "$wsl_nvidia_smi"
    fi
}

# Install CUDA repository
install_cuda_repo() {
    log_info "Installing CUDA repository..."

    local keyring_url="https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb"
    local keyring_deb="/tmp/cuda-keyring.deb"

    # Download keyring
    wget -q -O "$keyring_deb" "$keyring_url"

    # Install keyring
    sudo dpkg -i "$keyring_deb"
    rm "$keyring_deb"

    # Update package lists
    sudo apt-get update

    log_success "CUDA repository installed"
}

# Install CUDA toolkit
install_cuda_toolkit() {
    log_info "Installing CUDA 12.9 toolkit..."
    log_info "This will download ~3GB of packages and may take several minutes..."

    sudo apt-get install -y \
        cuda-toolkit-12-9 \
        cuda-libraries-12-9 \
        cuda-libraries-dev-12-9

    log_success "CUDA toolkit installed"
}

# Configure environment
configure_environment() {
    log_info "Configuring environment variables..."

    local shell_rc=""
    local shell_name=$(basename "$SHELL")

    case "$shell_name" in
        bash)
            shell_rc="$HOME/.bashrc"
            ;;
        zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        *)
            log_warning "Unknown shell: $shell_name, using .bashrc"
            shell_rc="$HOME/.bashrc"
            ;;
    esac

    # Check if CUDA config already exists
    if grep -q "CUDA_HOME" "$shell_rc" 2>/dev/null; then
        log_warning "CUDA configuration already exists in $shell_rc"
        return 0
    fi

    # Add CUDA configuration
    cat >> "$shell_rc" << 'EOF'

# NVIDIA CUDA Configuration (added by install-cuda.sh)
export CUDA_HOME=/usr/local/cuda
export CUDA_PATH=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=/usr/lib/wsl/lib:$CUDA_HOME/lib64:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
EOF

    log_success "Environment variables added to $shell_rc"
    log_warning "Run 'source $shell_rc' or restart your shell to apply changes"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    # Source the environment
    export CUDA_HOME=/usr/local/cuda
    export CUDA_PATH=/usr/local/cuda
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=/usr/lib/wsl/lib:$CUDA_HOME/lib64:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

    # Check nvidia-smi
    if nvidia-smi &>/dev/null; then
        log_success "nvidia-smi working"
    else
        log_error "nvidia-smi not working"
        return 1
    fi

    # Check nvcc
    if nvcc --version &>/dev/null; then
        local nvcc_version=$(nvcc --version | grep "release" | awk '{print $5}' | sed 's/,//')
        log_success "nvcc working (version $nvcc_version)"
    else
        log_error "nvcc not found"
        return 1
    fi

    log_success "Installation verified"
}

# Print summary
print_summary() {
    echo
    echo "=========================================="
    echo "CUDA Installation Complete!"
    echo "=========================================="
    echo
    echo "Next steps:"
    echo "1. Run: source ~/.bashrc (or restart your shell)"
    echo "2. Test CUDA: ./test-cuda.sh"
    echo "3. Compile test program: ./compile-test.sh"
    echo
    echo "Installed versions:"
    echo "  - CUDA Toolkit: 12.9"
    echo "  - Location: /usr/local/cuda"
    echo
    echo "Environment variables set:"
    echo "  - CUDA_HOME=/usr/local/cuda"
    echo "  - CUDA_PATH=/usr/local/cuda"
    echo "  - PATH includes /usr/local/cuda/bin"
    echo "  - LD_LIBRARY_PATH includes /usr/lib/wsl/lib and /usr/local/cuda/lib64"
    echo
}

# Main installation flow
main() {
    log_info "Starting CUDA 12 installation for WSL2..."
    echo

    check_wsl2
    check_ubuntu_version
    check_windows_driver

    echo
    log_info "Ready to install CUDA 12.9 toolkit"
    log_warning "This will install ~6.5GB of packages"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi

    echo
    fix_nvidia_smi
    install_cuda_repo
    install_cuda_toolkit
    configure_environment

    echo
    verify_installation

    print_summary
}

main "$@"
