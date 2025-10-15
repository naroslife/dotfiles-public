#!/usr/bin/env bash
# Dotfiles Setup Script - Refactored Version
#
# This script provides an interactive setup experience for the dotfiles repository.
# It handles Nix installation, git submodules, and Home Manager configuration.
#
# Usage:
#   ./apply.sh [OPTIONS]
#
# Options:
#   -y, --yes           Answer yes to all prompts
#   -n, --no-backup     Don't create backups
#   -u, --user USER     Specify username for flake mode
#   -v, --verbose       Enable verbose logging
#   -h, --help          Show this help message

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/sops_bootstrap.sh
source "$SCRIPT_DIR/lib/sops_bootstrap.sh"

# Source setup modules
# shellcheck source=lib/setup/nix.sh
source "$SCRIPT_DIR/lib/setup/nix.sh"
# shellcheck source=lib/setup/user.sh
source "$SCRIPT_DIR/lib/setup/user.sh"
# shellcheck source=lib/setup/homemanager.sh
source "$SCRIPT_DIR/lib/setup/homemanager.sh"
# shellcheck source=lib/setup/github.sh
source "$SCRIPT_DIR/lib/setup/github.sh"
# shellcheck source=lib/setup/platform/wsl.sh
source "$SCRIPT_DIR/lib/setup/platform/wsl.sh"
# shellcheck source=lib/setup/platform/nvidia.sh
source "$SCRIPT_DIR/lib/setup/platform/nvidia.sh"

# Configuration (exported for use by sourced modules)
export CONFIG_DIR="$HOME/.config"

# Script state
ASSUME_YES=false
CREATE_BACKUPS=true
TARGET_USER=""
SETUP_GITHUB_CLI=false
INTERACTIVE_CONFIG=false

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                ASSUME_YES=true
                shift
                ;;
            -n|--no-backup)
                CREATE_BACKUPS=false
                shift
                ;;
            -u|--user)
                TARGET_USER="$2"
                shift 2
                ;;
            -v|--verbose)
                LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -i|--interactive)
                INTERACTIVE_CONFIG=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                die "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Dotfiles Setup Script

This script provides an interactive setup experience for the dotfiles repository.
It handles Nix installation, git submodules, and Home Manager configuration.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -y, --yes           Answer yes to all prompts
    -n, --no-backup     Don't create backups of existing configurations
    -u, --user USER     Specify username for flake mode
    -i, --interactive   Configure user-specific settings interactively
    -v, --verbose       Enable verbose logging
    -h, --help          Show this help message

EXAMPLES:
    $0                          # Interactive setup
    $0 -y -u myuser            # Non-interactive with specific user
    $0 --interactive           # Configure user-specific settings
    $0 --verbose --no-backup   # Verbose mode without backups

EOF
}

# Validation functions
validate_prerequisites() {
    log_info "Validating prerequisites"

    # Check if git is available
    require_command git "Please install git: sudo apt install git (Ubuntu/Debian) or brew install git (macOS)"

    # Validate repository state
    if [[ ! -d ".git" ]]; then
        die "This script must be run from the dotfiles repository root"
    fi

    # Check for required files
    local required_files=("flake.nix" "home.nix")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            die "Required file not found: $file"
        fi
    done

    # Validate Nix files
    if command -v nix >/dev/null 2>&1; then
        validate_config_file "flake.nix" "nix"
        validate_config_file "home.nix" "nix"
    fi

    log_info "Prerequisites validation passed"
}

# Nix installation with enhanced security
# All setup functions are now modularized in lib/setup/
# See lib/setup/README.md for documentation

# Main setup orchestration
main() {
    log_info "🚀 Starting dotfiles setup"
    log_info "Platform: $(detect_platform)"

    # Parse command line arguments
    parse_arguments "$@"

    # Show configuration
    log_debug "Configuration:"
    log_debug "  ASSUME_YES: $ASSUME_YES"
    log_debug "  CREATE_BACKUPS: $CREATE_BACKUPS"
    log_debug "  TARGET_USER: ${TARGET_USER:-auto}"
    log_debug "  INTERACTIVE_CONFIG: $INTERACTIVE_CONFIG"
    log_debug "  LOG_LEVEL: $LOG_LEVEL"

    # Setup steps
    validate_prerequisites
    run_user_configuration
    check_nix_installation
    setup_git_submodules

    # Bootstrap sops-nix if needed (before Home Manager)
    bootstrap_sops

    select_user
    apply_home_manager
    apply_wsl_optimizations

    # Optional GitHub CLI setup
    if ! $ASSUME_YES && ask_yes_no "Would you like to set up GitHub CLI authentication?"; then
        export SETUP_GITHUB_CLI=true
        setup_github_cli
    fi

    # Platform-specific post-configuration optimizations
    offer_wsl_config
    setup_cuda_wsl
    setup_nvidia_drivers

    log_info "✅ Dotfiles setup completed successfully!"
    log_info ""
    log_info "🔄 Please restart your shell or run: source ~/.bashrc"

    if is_wsl; then
        log_info "🖥️  WSL detected - GUI applications should work after restart"
    fi
}

# Run main function with all arguments
main "$@"
