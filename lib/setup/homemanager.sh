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

# Ask user about shell integration mode
select_shell_mode() {
    # If already set via environment or command line, use it
    if [[ -n "${HM_MODIFY_SHELL:-}" ]]; then
        log_info "Shell mode already set to: $HM_MODIFY_SHELL"
        return 0
    fi

    if $ASSUME_YES; then
        # Default to dev shell mode (non-invasive)
        export HM_MODIFY_SHELL="false"
        log_info "Non-interactive mode: using dev shell mode (HM_MODIFY_SHELL=false)"
        return 0
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Home Manager Shell Integration Mode"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Choose how Home Manager should integrate with your shell:"
    echo ""
    echo "  1) Dev Shell Only (Recommended)"
    echo "     - Keeps your system environment unchanged"
    echo "     - Home Manager available via 'nix develop .#hm-env'"
    echo "     - Or use the 'hm-dev-shell' command"
    echo "     - Opt-in when you need the dev environment"
    echo ""
    echo "  2) Full Integration"
    echo "     - Modifies your shell RC files (.bashrc, .zshrc)"
    echo "     - Home Manager active in all new shells"
    echo "     - Traditional Home Manager behavior"
    echo ""

    local shell_mode
    read -p "Enter choice [1]: " -r shell_mode
    shell_mode="${shell_mode:-1}"

    if [[ "$shell_mode" == "1" ]]; then
        export HM_MODIFY_SHELL="false"
        log_info "✓ Dev shell mode selected - your system environment will remain unchanged"
        echo ""
        echo "After installation, use these commands to enter the dev environment:"
        echo "  • hm-dev-shell              (convenience script)"
        echo "  • nix develop .#hm-env      (from dotfiles directory)"
        echo "  • nix-shell shell.nix       (legacy nix-shell)"
        echo ""
    else
        export HM_MODIFY_SHELL="true"
        log_info "✓ Full integration mode selected - shell RC files will be modified"
        echo ""
    fi
}

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

    # Ensure HM_MODIFY_SHELL is set (default to false if not set)
    export HM_MODIFY_SHELL="${HM_MODIFY_SHELL:-false}"

    log_info "Configuration mode: HM_MODIFY_SHELL=$HM_MODIFY_SHELL"

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

    # Show next steps based on mode
    if [[ "$HM_MODIFY_SHELL" == "false" ]]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "  Next Steps - Dev Shell Mode"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Your system environment is unchanged. To use Home Manager tools:"
        echo ""
        echo "  1. Enter the dev environment:"
        echo "     hm-dev-shell"
        echo ""
        echo "  2. Or use nix develop:"
        echo "     cd ~/dotfiles-public && nix develop .#hm-env"
        echo ""
        echo "  3. Exit the dev shell to return to your normal environment:"
        echo "     exit"
        echo ""
    fi
}
