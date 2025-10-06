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

# Configuration
readonly NIX_INSTALL_URL="https://nixos.org/nix/install"
readonly NIX_INSTALL_CHECKSUM="751c3bb0b72d2b1c79975e8b45325ce80ee17f5c64ae59e11e1d2fce01aeccad"
readonly CONFIG_DIR="$HOME/.config"

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
install_nix() {
    log_info "Installing Nix package manager"

    local temp_installer
    temp_installer=$(mktemp)
    TEMP_FILES="${TEMP_FILES:-} $temp_installer"

    # Download with checksum verification
    fetch_url "$NIX_INSTALL_URL" "$temp_installer" "$NIX_INSTALL_CHECKSUM"

    # Install Nix
    if ! sh "$temp_installer" --daemon; then
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
    local home_manager_cmd="nix run home-manager/master -- switch --impure --flake \".#$TARGET_USER\""

    log_info "Executing: $home_manager_cmd"
    if ! eval "$home_manager_cmd"; then
        die "Home Manager configuration failed"
    fi

    log_info "Home Manager configuration applied successfully"
}

# WSL-specific optimizations
apply_wsl_optimizations() {
    if ! is_wsl; then
        return 0
    fi

    log_info "Applying WSL-specific optimizations"

    # Check if WSL init script exists and is executable
    local wsl_init_script="$SCRIPT_DIR/wsl-init.sh"
    if [[ -f "$wsl_init_script" && -x "$wsl_init_script" ]]; then
        log_info "Running WSL initialization script"
        if ! "$wsl_init_script"; then
            log_warn "WSL initialization script failed, continuing anyway"
        fi
    else
        log_debug "WSL init script not found or not executable: $wsl_init_script"
    fi
}

# GitHub CLI setup
setup_github_cli() {
    if ! $SETUP_GITHUB_CLI; then
        return 0
    fi

    log_info "Setting up GitHub CLI"

    if ! command -v gh >/dev/null 2>&1; then
        log_warn "GitHub CLI not found. Install it through your package manager."
        return 0
    fi

    if ! gh auth status >/dev/null 2>&1; then
        log_info "GitHub CLI not authenticated"
        if $ASSUME_YES || ask_yes_no "Would you like to authenticate GitHub CLI now?"; then
            if ! gh auth login; then
                log_warn "GitHub CLI authentication failed"
            else
                log_info "GitHub CLI authenticated successfully"
            fi
        fi
    else
        log_info "GitHub CLI already authenticated"
    fi
}

# Run interactive user configuration
run_user_configuration() {
    # Source the user config module
    # shellcheck source=lib/user_config.sh
    source "$SCRIPT_DIR/lib/user_config.sh"

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
    select_user
    apply_home_manager
    apply_wsl_optimizations

    # Optional GitHub CLI setup
    if ! $ASSUME_YES && ask_yes_no "Would you like to set up GitHub CLI authentication?"; then
        SETUP_GITHUB_CLI=true
        setup_github_cli
    fi

    log_info "✅ Dotfiles setup completed successfully!"
    log_info ""
    log_info "🔄 Please restart your shell or run: source ~/.bashrc"

    if is_wsl; then
        log_info "🖥️  WSL detected - GUI applications should work after restart"
    fi
}

# Run main function with all arguments
main "$@"