#!/usr/bin/env bash
# User Configuration and Git Submodule Management
# Functions for user selection, git submodules, and interactive configuration

set -euo pipefail

# Guard against multiple sourcing
if [[ -n "${USER_SETUP_LOADED:-}" ]]; then
    return 0
fi
readonly USER_SETUP_LOADED=1

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../common.sh"

# Git submodule management
setup_git_submodules() {
    log_info "Setting up git submodules"

    # Check if submodules are configured
    if [[ ! -f ".gitmodules" ]] || [[ ! -s ".gitmodules" ]]; then
        log_info "No git submodules configured, skipping"
        return 0
    fi

    local use_submodules=false
    if $ASSUME_YES; then
        use_submodules=true
    else
        if ask_yes_no "Initialize git submodules for enhanced shell functionality?"; then
            use_submodules=true
        fi
    fi

    if $use_submodules; then
        log_info "Initializing git submodules"
        if ! git submodule update --init --recursive; then
            log_warn "Failed to initialize some submodules, continuing anyway"
        else
            log_info "Git submodules initialized successfully"
        fi
    else
        log_info "Skipping git submodules"
    fi
}

# User selection for flake mode
select_user() {
    if [[ -n "$TARGET_USER" ]]; then
        log_info "Using specified user: $TARGET_USER"
        return 0
    fi

    if $ASSUME_YES; then
        # Use current user as default in non-interactive mode
        TARGET_USER=$(whoami)
        log_info "Using current user: $TARGET_USER"
        return 0
    fi

    # Extract available users from flake.nix
    local available_users
    if ! available_users=$(nix eval --json .#homeConfigurations --apply 'configs: builtins.attrNames configs' 2>/dev/null | jq -r '.[]' 2>/dev/null); then
        log_warn "Could not extract user list from flake.nix, using current user"
        TARGET_USER=$(whoami)
        return 0
    fi

    echo "Available user configurations:"
    local user_array=()
    while IFS= read -r user; do
        echo "  - $user"
        user_array+=("$user")
    done <<< "$available_users"

    if [[ ${#user_array[@]} -eq 1 ]]; then
        TARGET_USER="${user_array[0]}"
        log_info "Only one user configuration available, using: $TARGET_USER"
    else
        while true; do
            read -p "Enter username for configuration: " -r TARGET_USER
            if [[ " ${user_array[*]} " == *" $TARGET_USER "* ]]; then
                break
            else
                log_warn "Invalid username. Please choose from: ${user_array[*]}"
            fi
        done
    fi
}

# Run interactive user configuration
run_user_configuration() {
    # Source the user config module
    # shellcheck source=lib/user_config.sh
    source "$SCRIPT_DIR/../user_config.sh"

    if $INTERACTIVE_CONFIG || (! $ASSUME_YES && ask_yes_no "Would you like to configure user-specific settings?" n); then
        log_info "Starting interactive user configuration"
        if run_interactive_config; then
            log_info "User configuration completed successfully"

            # Export configuration for use in Home Manager
            export_user_config
        else
            log_warn "User configuration skipped or cancelled"
        fi
    fi
}
