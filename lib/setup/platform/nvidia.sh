#!/usr/bin/env bash
# NVIDIA GPU Detection and CUDA Setup
# Functions for NVIDIA GPU detection and CUDA configuration

set -euo pipefail

# Guard against multiple sourcing
if [[ -n "${NVIDIA_SETUP_LOADED:-}" ]]; then
    return 0
fi
readonly NVIDIA_SETUP_LOADED=1

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../../common.sh"

# Detect NVIDIA GPU
has_nvidia_gpu() {
    # Check if nvidia-smi is available and can detect GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
        if nvidia-smi >/dev/null 2>&1; then
            return 0
        fi
    fi

    # Check for NVIDIA device files
    if [[ -d /dev/nvidia0 ]] || [[ -c /dev/nvidia0 ]]; then
        return 0
    fi

    # Check lspci for NVIDIA devices
    if command -v lspci >/dev/null 2>&1; then
        if lspci 2>/dev/null | grep -qi "nvidia"; then
            return 0
        fi
    fi

    return 1
}

# Setup NVIDIA drivers verification (native Linux)
setup_nvidia_drivers() {
    if ! has_nvidia_gpu; then
        return 0
    fi

    if is_wsl; then
        return 0  # WSL CUDA setup handled separately
    fi

    log_info "NVIDIA GPU detected"

    if ! $ASSUME_YES && ask_yes_no "Would you like to verify NVIDIA driver installation?" y; then
        if command -v nvidia-smi >/dev/null 2>&1; then
            log_info "NVIDIA drivers are installed"
            nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
        else
            log_warn "NVIDIA GPU detected but nvidia-smi not found"
            log_info "Install NVIDIA drivers for your distribution"
        fi
    fi
}

# Setup CUDA for WSL
setup_cuda_wsl() {
    if ! is_wsl; then
        return 0
    fi

    if ! has_nvidia_gpu; then
        return 0
    fi

    log_info "NVIDIA GPU detected in WSL"

    if ! $ASSUME_YES && ask_yes_no "Would you like to configure CUDA support for WSL?" y; then
        log_info "Setting up CUDA support"

        # Check if CUDA is already installed
        if ! command -v nvcc >/dev/null 2>&1; then
            log_info "CUDA toolkit not found in PATH"
            log_info "To install CUDA in WSL:"
            log_info "  1. Install Windows NVIDIA GPU drivers (from NVIDIA website)"
            log_info "  2. Install CUDA toolkit in WSL:"
            log_info "     wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin"
            log_info "     sudo mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600"
            log_info "     wget https://developer.download.nvidia.com/compute/cuda/12.3.0/local_installers/cuda-repo-wsl-ubuntu-12-3-local_12.3.0-1_amd64.deb"
            log_info "     sudo dpkg -i cuda-repo-wsl-ubuntu-12-3-local_12.3.0-1_amd64.deb"
            log_info "     sudo cp /var/cuda-repo-wsl-ubuntu-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/"
            log_info "     sudo apt-get update"
            log_info "     sudo apt-get -y install cuda"

            if ask_yes_no "Would you like to add CUDA to your PATH now?" y; then
                local cuda_path_config="$HOME/.config/cuda-path.sh"
                cat > "$cuda_path_config" <<'EOF'
# CUDA configuration
export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
EOF
                log_info "Created CUDA PATH configuration at $cuda_path_config"
                log_info "Source this file or restart your shell to use CUDA"
            fi
        else
            log_info "CUDA toolkit is already available: $(nvcc --version | head -n1)"
        fi

        # Check for Docker with GPU support
        if command -v docker >/dev/null 2>&1; then
            log_info "Docker detected. For GPU support in Docker:"
            log_info "  1. Install nvidia-docker2:"
            log_info "     distribution=\$(. /etc/os-release;echo \$ID\$VERSION_ID)"
            log_info "     curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -"
            log_info "     curl -s -L https://nvidia.github.io/nvidia-docker/\$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list"
            log_info "     sudo apt-get update && sudo apt-get install -y nvidia-docker2"
            log_info "     sudo systemctl restart docker"
            log_info "  2. Test with: docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi"
        fi
    fi
}

# Offer WSL configuration optimizations
offer_wsl_config() {
    if ! is_wsl; then
        return 0
    fi

    if $ASSUME_YES || ! ask_yes_no "Would you like to apply WSL performance optimizations?" y; then
        return 0
    fi

    log_info "Applying WSL optimizations"

    # WSL.conf optimizations
    if [[ ! -f /etc/wsl.conf ]]; then
        log_info "Creating /etc/wsl.conf with optimizations"
        if ask_yes_no "This requires sudo access. Continue?" y; then
            sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=true

[network]
generateResolvConf=true

[user]
default=$USER
EOF
            log_info "WSL configuration created. Restart WSL for changes to take effect."
            log_info "To restart: wsl --shutdown (from Windows)"
        fi
    else
        log_debug "WSL configuration already exists at /etc/wsl.conf"
    fi

    # Check for systemd
    if ! systemctl --version >/dev/null 2>&1; then
        log_warn "Systemd is not running. Some services may not work properly."
        log_info "Enable systemd in /etc/wsl.conf and restart WSL"
    fi
}
