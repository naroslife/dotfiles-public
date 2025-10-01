#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to print step headers
print_step() {
    echo
    print_color "$BLUE" "══════════════════════════════════════════════════"
    print_color "$BLUE" "  $1"
    print_color "$BLUE" "══════════════════════════════════════════════════"
    echo
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect WSL
is_wsl() {
    [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]
}

# Main script
print_color "$GREEN" "🚀 Dotfiles Setup Script"
print_color "$GREEN" "========================"

# Step 1: Check for Nix
print_step "Checking for Nix installation"
if ! command_exists nix; then
    print_color "$YELLOW" "Nix is not installed."
    read -p "Would you like to install Nix? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_color "$GREEN" "Installing Nix..."
        sh <(curl -L https://nixos.org/nix/install) --daemon

        # Source Nix
        # shellcheck disable=SC1091
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
            . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        fi
    else
        print_color "$RED" "Nix is required. Exiting."
        exit 1
    fi
else
    print_color "$GREEN" "✓ Nix is installed"
fi

# Step 2: Enable flakes and nix-command
print_step "Checking Nix experimental features"
if ! nix --version 2>&1 | grep -q "flakes"; then
    print_color "$YELLOW" "Enabling experimental features..."
    mkdir -p ~/.config/nix
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
fi
print_color "$GREEN" "✓ Experimental features enabled"

# Step 3: Check for git
print_step "Checking for git"
if ! command_exists git; then
    print_color "$RED" "Git is not installed. Please install git first."
    exit 1
fi
print_color "$GREEN" "✓ Git is installed"

# Step 4: Initialize/update git submodules if .gitmodules exists
if [ -f .gitmodules ]; then
    print_step "Initializing git submodules"
    git submodule update --init --recursive
    print_color "$GREEN" "✓ Git submodules initialized"
fi

# Step 5: Detect username
print_step "Detecting user configuration"
CURRENT_USER=$(whoami)
print_color "$BLUE" "Current user: $CURRENT_USER"

# Check if user has a configuration
if grep -q "\"$CURRENT_USER\"" flake.nix 2>/dev/null; then
    print_color "$GREEN" "✓ Configuration found for $CURRENT_USER"
    USERNAME=$CURRENT_USER
else
    print_color "$YELLOW" "No configuration found for $CURRENT_USER"
    print_color "$YELLOW" "Available configurations: naroslife, enterpriseuser"
    read -r -p "Enter username to use: " USERNAME

    if ! grep -q "\"$USERNAME\"" flake.nix 2>/dev/null; then
        print_color "$RED" "Invalid username. Exiting."
        exit 1
    fi
fi

# Step 6: Backup old configuration if it exists
if [ -f home.nix ] && [ ! -f home.nix.backup ]; then
    print_step "Backing up old configuration"
    cp home.nix home.nix.backup
    print_color "$GREEN" "✓ Old configuration backed up to home.nix.backup"
fi

# Step 7: Apply the configuration
print_step "Applying Home Manager configuration"
print_color "$YELLOW" "This will:"
print_color "$YELLOW" "  • Install all packages defined in modules/"
print_color "$YELLOW" "  • Configure shells (bash, zsh, elvish)"
print_color "$YELLOW" "  • Set up development tools"
print_color "$YELLOW" "  • Configure modern CLI tools"
if is_wsl; then
    print_color "$YELLOW" "  • Apply WSL-specific optimizations"
fi

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_color "$RED" "Aborted."
    exit 1
fi

# Use the new flake configuration
print_color "$GREEN" "Building and activating configuration..."
if nix run home-manager/master -- switch --impure --flake ".#$USERNAME" -b backup; then
    print_color "$GREEN" "✅ Configuration applied successfully!"
else
    print_color "$RED" "❌ Configuration failed. Please check the error messages above."
    exit 1
fi

# Step 8: WSL-specific setup
if is_wsl; then
    print_step "WSL-specific setup"

    # Check APT network configuration
    if [ -x "$HOME/.nix-profile/bin/apt-network-switch" ]; then
        print_color "$YELLOW" "Checking APT network configuration..."
        "$HOME/.nix-profile/bin/apt-network-switch" --quiet || true
    fi

    print_color "$GREEN" "✓ WSL setup complete"
fi

# Step 9: Post-installation tasks
print_step "Post-installation tasks"

# Configure GitHub CLI if installed
if command_exists gh; then
    read -p "Would you like to authenticate GitHub CLI? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh auth login
    fi
fi

# Final instructions
print_step "Setup Complete! 🎉"
print_color "$GREEN" "Your dotfiles have been successfully installed!"
print_color "$YELLOW" ""
print_color "$YELLOW" "Next steps:"
print_color "$YELLOW" "  1. Restart your shell or run: source ~/.bashrc"
print_color "$YELLOW" "  2. Try some modern CLI tools:"
print_color "$YELLOW" "     • 'eza' instead of 'ls'"
print_color "$YELLOW" "     • 'bat' instead of 'cat'"
print_color "$YELLOW" "     • 'fd' instead of 'find'"
print_color "$YELLOW" "     • 'rg' instead of 'grep'"
print_color "$YELLOW" ""
print_color "$YELLOW" "To update your configuration:"
print_color "$YELLOW" "  • Edit files in modules/"
print_color "$YELLOW" "  • Run: ./apply.sh"
print_color "$YELLOW" ""
print_color "$YELLOW" "For more information, see README.md"
