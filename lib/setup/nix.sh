#!/usr/bin/env bash
# Nix Installation and Management
# Functions for installing and validating Nix package manager

set -euo pipefail

# Guard against multiple sourcing
if [[ -n "${NIX_SETUP_LOADED:-}" ]]; then
    return 0
fi
NIX_SETUP_LOADED=1

# Source common utilities
_NIX_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$_NIX_MODULE_DIR/../common.sh"

# Nix installation with enhanced security
install_nix() {
    log_info "Installing Nix package manager"
    # Use Determinate Systems installer for enhanced reliability
    log_debug "Using Determinate Systems Nix installer"

    if ! curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate; then
        die "Nix installation failed"
    fi

    # Source Nix environment
    if [[ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
        # shellcheck source=/dev/null
        source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    fi

    log_info "Nix installation completed successfully"
}

# Enhanced Nix setup check
check_nix_installation() {
    log_info "Checking Nix installation"

    if ! command -v nix >/dev/null 2>&1; then
        log_warn "Nix is not installed or not in PATH"

        if $ASSUME_YES || ask_yes_no "Would you like to install Nix?"; then
            install_nix
        else
            die "Nix is required for this setup. Please install it manually."
        fi
    else
        log_info "Nix is already installed"

        # Verify Nix is working
        if ! nix --version >/dev/null 2>&1; then
            die "Nix is installed but not working properly. Please check your installation."
        fi

        log_debug "Nix version: $(nix --version)"
    fi
}
