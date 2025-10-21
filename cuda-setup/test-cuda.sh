#!/usr/bin/env bash
#
# Quick CUDA verification script
# Tests that CUDA environment is properly configured
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

failed=0

echo
echo "=========================================="
echo "  CUDA Installation Verification"
echo "=========================================="
echo

# Test 1: Check WSL2
log_info "Checking WSL2..."
if is_wsl2; then
    log_success "Running on WSL2"
else
    log_warning "Not running on WSL2"
fi
echo

# Test 2: Check nvidia-smi
log_info "Checking nvidia-smi..."
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
        log_success "nvidia-smi working"
        log_success "Driver version: $driver_version"
        log_success "GPU: $gpu_name"
    else
        log_error "nvidia-smi command failed"
        failed=$((failed + 1))
    fi
else
    log_error "nvidia-smi not found"
    failed=$((failed + 1))
fi
echo

# Test 3: Check CUDA environment variables
log_info "Checking CUDA environment variables..."
if [[ -n "${CUDA_HOME:-}" ]]; then
    log_success "CUDA_HOME=$CUDA_HOME"
else
    log_error "CUDA_HOME not set"
    failed=$((failed + 1))
fi

if [[ -n "${CUDA_PATH:-}" ]]; then
    log_success "CUDA_PATH=$CUDA_PATH"
else
    log_error "CUDA_PATH not set"
    failed=$((failed + 1))
fi
echo

# Test 4: Check PATH
log_info "Checking PATH for CUDA binaries..."
if [[ "$PATH" == *"/usr/local/cuda/bin"* ]]; then
    log_success "/usr/local/cuda/bin in PATH"
else
    log_error "/usr/local/cuda/bin not in PATH"
    failed=$((failed + 1))
fi
echo

# Test 5: Check LD_LIBRARY_PATH
log_info "Checking LD_LIBRARY_PATH..."
if [[ "$LD_LIBRARY_PATH" == *"/usr/lib/wsl/lib"* ]]; then
    log_success "/usr/lib/wsl/lib in LD_LIBRARY_PATH"
else
    log_error "/usr/lib/wsl/lib not in LD_LIBRARY_PATH"
    failed=$((failed + 1))
fi

if [[ "$LD_LIBRARY_PATH" == *"/usr/local/cuda/lib64"* ]]; then
    log_success "/usr/local/cuda/lib64 in LD_LIBRARY_PATH"
else
    log_error "/usr/local/cuda/lib64 not in LD_LIBRARY_PATH"
    failed=$((failed + 1))
fi
echo

# Test 6: Check nvcc
log_info "Checking nvcc (CUDA compiler)..."
if command -v nvcc &> /dev/null; then
    nvcc_version=$(nvcc --version | grep "release" | awk '{print $5}' | sed 's/,//')
    log_success "nvcc found"
    log_success "CUDA version: $nvcc_version"
else
    log_error "nvcc not found"
    log_error "Make sure CUDA toolkit is installed"
    failed=$((failed + 1))
fi
echo

# Test 7: Check CUDA installation directory
log_info "Checking CUDA installation..."
if [[ -d /usr/local/cuda ]]; then
    log_success "CUDA directory exists: /usr/local/cuda"

    if [[ -L /usr/local/cuda ]]; then
        cuda_target=$(readlink -f /usr/local/cuda)
        log_success "Symlink points to: $cuda_target"
    fi

    if [[ -f /usr/local/cuda/bin/nvcc ]]; then
        log_success "nvcc binary found"
    else
        log_error "nvcc binary not found in /usr/local/cuda/bin"
        failed=$((failed + 1))
    fi

    if [[ -d /usr/local/cuda/lib64 ]]; then
        log_success "Library directory exists"
    else
        log_error "Library directory not found"
        failed=$((failed + 1))
    fi
else
    log_error "CUDA directory not found: /usr/local/cuda"
    log_error "CUDA toolkit may not be installed"
    failed=$((failed + 1))
fi
echo

# Summary
echo "=========================================="
if [ $failed -eq 0 ]; then
    log_success "All checks passed!"
    echo
    echo "Your CUDA installation appears to be correctly configured."
    echo
    echo "Next steps:"
    echo "  - Run './compile-test.sh' to compile and run the test program"
    echo "  - Check 'cuda-test.cu' for a comprehensive CUDA test"
    echo
    exit 0
else
    log_error "$failed check(s) failed"
    echo
    echo "Your CUDA installation has issues. Please review the errors above."
    echo
    echo "Common fixes:"
    echo "  1. Run: source ~/.bashrc (or restart your shell)"
    echo "  2. Ensure CUDA toolkit is installed: sudo apt install cuda-toolkit-12-9"
    echo "  3. Check driver compatibility: ./check-driver.sh"
    echo "  4. Verify Windows NVIDIA drivers support CUDA 12.9 (minimum: 528.33)"
    echo
    exit 1
fi