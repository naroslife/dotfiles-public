#!/usr/bin/env bash
# WSL-Specific Optimizations
# Functions for Windows Subsystem for Linux configuration and optimization

set -euo pipefail

# Guard against multiple sourcing
if [[ -n "${WSL_SETUP_LOADED:-}" ]]; then
    return 0
fi
readonly WSL_SETUP_LOADED=1

# Source common utilities
_WSL_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$_WSL_MODULE_DIR/../../common.sh"

# WSL-specific optimizations
apply_wsl_optimizations() {
    if ! is_wsl; then
        return 0
    fi

    log_info "Applying WSL-specific optimizations"

    # Check if WSL init script exists and is executable
    local wsl_init_script="$ROOT_DIR/wsl-init.sh"
    if [[ -f "$wsl_init_script" && -x "$wsl_init_script" ]]; then
        log_info "Running WSL initialization script"
        if ! "$wsl_init_script"; then
            log_warn "WSL initialization script failed, continuing anyway"
        fi
    else
        log_debug "WSL init script not found or not executable: $wsl_init_script"
    fi
}
