#!/usr/bin/env bash
# Home Manager Configuration Application
# Functions for applying Home Manager configurations with backup support

set -euo pipefail

# Guard against multiple sourcing
if [[ -n "${HOMEMANAGER_SETUP_LOADED:-}" ]]; then
    return 0
fi
HOMEMANAGER_SETUP_LOADED=1

# Source common utilities
_HM_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$_HM_MODULE_DIR/../common.sh"

# Home Manager application
apply_home_manager() {
    log_info "Applying Home Manager configuration"

    # Backup existing configurations if requested
    if $CREATE_BACKUPS; then
        log_info "Creating backups of existing configurations"
        for config_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
            if [[ -f "$config_file" ]]; then
                backup_file "$config_file"
            fi
        done
    fi

    # Apply configuration
    # Export CURRENT_USER for dynamic user detection in flake.nix
    export CURRENT_USER="$TARGET_USER"

    # Show what will be built (if not in quiet mode)
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        log_info "Checking configuration target..."
        nix build --impure --dry-run --no-link ".#homeConfigurations.$TARGET_USER.activationPackage" 2>&1 | head -n 20
    fi

    local home_manager_cmd="nix run home-manager/release-25.05 -- switch --impure --flake \".#$TARGET_USER\""

    log_info "Executing: $home_manager_cmd"
    if ! eval "$home_manager_cmd"; then
        die "Home Manager configuration failed"
    fi

    log_info "Home Manager configuration applied successfully"
}
