#!/usr/bin/env bash
#
# Compile and run CUDA test program
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

# Check if CUDA is available
if ! command -v nvcc &> /dev/null; then
    log_error "nvcc not found in PATH"
    log_error "Make sure CUDA is installed and PATH is set correctly"
    log_error "Run: source ~/.bashrc (or restart your shell)"
    exit 1
fi

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log_info "Compiling CUDA test program..."
log_info "Using nvcc: $(which nvcc)"
log_info "CUDA version: $(nvcc --version | grep release | awk '{print $5}' | sed 's/,//')"

# Compile
nvcc cuda-test.cu -o cuda-test

log_success "Compilation successful"
echo

log_info "Running CUDA test program..."
echo

# Run the test
./cuda-test

exit_code=$?

echo

if [ $exit_code -eq 0 ]; then
    log_success "All tests passed!"
else
    log_error "Some tests failed (exit code: $exit_code)"
fi

exit $exit_code
