#!/usr/bin/env bash
#
# install-nix.sh - Install Nix offline on remote machine
#

set -euo pipefail

# Default installation type
INSTALL_TYPE="${1:-single-user}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

echo_step() {
    echo -e "${BLUE}→${RESET} $1"
}

# Check if Nix is already installed
if command -v nix >/dev/null 2>&1; then
    echo_warn "Nix is already installed: $(nix --version)"
    echo_info "Skipping installation"
    exit 0
fi

echo_info "Installing Nix (offline mode)"
echo_info "Installation type: $INSTALL_TYPE"

# Check for root (not allowed for single-user)
if [[ "$INSTALL_TYPE" == "single-user" ]] && [[ $EUID -eq 0 ]]; then
    echo_error "Single-user installation cannot be run as root"
    exit 1
fi

# Check for root (required for multi-user)
if [[ "$INSTALL_TYPE" == "multi-user" ]] && [[ $EUID -ne 0 ]]; then
    echo_error "Multi-user installation must be run as root"
    exit 1
fi

# Find Nix installer package
NIX_INSTALLER=""
if [[ -f "nix-installer.tar.gz" ]]; then
    NIX_INSTALLER="nix-installer.tar.gz"
elif [[ -f "nix.tar.xz" ]]; then
    NIX_INSTALLER="nix.tar.xz"
else
    echo_error "No Nix installer package found"
    echo_info "Expected: nix-installer.tar.gz or nix.tar.xz"
    exit 1
fi

echo_step "Extracting Nix installer..."
INSTALLER_DIR="nix-installer-tmp"
rm -rf "$INSTALLER_DIR"
mkdir -p "$INSTALLER_DIR"

case "$NIX_INSTALLER" in
    *.tar.gz)
        tar -xzf "$NIX_INSTALLER" -C "$INSTALLER_DIR"
        ;;
    *.tar.xz)
        tar -xf "$NIX_INSTALLER" -C "$INSTALLER_DIR"
        ;;
    *)
        echo_error "Unknown installer format: $NIX_INSTALLER"
        exit 1
        ;;
esac

# Find the actual Nix directory
NIX_DIR=$(find "$INSTALLER_DIR" -maxdepth 2 -name "nix-*" -type d | head -1)
if [[ -z "$NIX_DIR" ]]; then
    echo_error "Could not find Nix directory in installer"
    exit 1
fi

echo_info "Found Nix at: $NIX_DIR"

# Detect platform for WSL workarounds
IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
    echo_info "WSL environment detected"
fi

# Single-user installation
if [[ "$INSTALL_TYPE" == "single-user" ]]; then
    echo_step "Performing single-user installation..."

    # Create necessary directories
    echo_info "Creating Nix directories..."
    mkdir -p "$HOME/.local/state/nix/profiles"
    mkdir -p "$HOME/.config/nix"

    # For single-user on systems where we can't modify /nix
    if [[ ! -d /nix ]] && [[ ! -w / ]]; then
        echo_warn "Cannot create /nix, trying user-local installation"
        # This is more complex and may not work well
        echo_error "User-local Nix installation not fully supported"
        echo_info "Please ask your administrator to create /nix with appropriate permissions"
        exit 1
    fi

    # Create /nix if possible
    if [[ ! -d /nix ]]; then
        if $IS_WSL; then
            echo_info "Creating /nix for WSL..."
            # WSL may need special handling
            if ! sudo mkdir -p /nix; then
                echo_error "Failed to create /nix"
                echo_info "Please run: sudo mkdir -p /nix && sudo chown $(whoami) /nix"
                exit 1
            fi
            sudo chown "$(whoami)" /nix
        else
            echo_info "Creating /nix..."
            if ! mkdir -p /nix; then
                echo_error "Failed to create /nix"
                echo_info "You may need sudo: sudo mkdir -p /nix && sudo chown $(whoami) /nix"
                exit 1
            fi
        fi
    fi

    # Check /nix ownership
    if [[ ! -w /nix ]]; then
        echo_error "/nix is not writable by current user"
        echo_info "Please run: sudo chown $(whoami) /nix"
        exit 1
    fi

    # Run installer
    echo_step "Running Nix installer..."
    cd "$NIX_DIR"

    # Create a minimal install script if the standard one doesn't exist
    if [[ ! -f "install" ]]; then
        echo_warn "Standard installer not found, using fallback method"

        # Copy Nix store
        echo_info "Copying Nix store..."
        cp -r store /nix/

        # Set up profile
        echo_info "Setting up profile..."
        PROFILE_DIR="/nix/var/nix/profiles/per-user/$(whoami)"
        mkdir -p "$PROFILE_DIR"
        ln -sf /nix/store/*-nix-*/bin/nix-env "$HOME/.local/bin/nix-env" 2>/dev/null || true

        # Basic setup script
        cat > "$HOME/.config/nix/nix.sh" << 'EOF'
# Nix single-user installation
export NIX_PATH="$HOME/.nix-defexpr/channels"
export PATH="/nix/var/nix/profiles/per-user/$USER/profile/bin:$PATH"
export PATH="$HOME/.nix-profile/bin:$PATH"
EOF

    else
        # Use standard installer
        ./install --no-daemon --no-channel-add
    fi

    # Configure for offline use
    echo_step "Configuring Nix for offline use..."
    cat > "$HOME/.config/nix/nix.conf" << 'EOF'
# Offline configuration
substituters =
require-sigs = false
sandbox = false
EOF

    # Add to shell profile
    echo_step "Adding Nix to shell profile..."

    PROFILE_FILE=""
    if [[ -f "$HOME/.bashrc" ]]; then
        PROFILE_FILE="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        PROFILE_FILE="$HOME/.zshrc"
    elif [[ -f "$HOME/.profile" ]]; then
        PROFILE_FILE="$HOME/.profile"
    fi

    if [[ -n "$PROFILE_FILE" ]]; then
        if ! grep -q "nix.sh" "$PROFILE_FILE" 2>/dev/null; then
            cat >> "$PROFILE_FILE" << 'EOF'

# Nix single-user
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
elif [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
fi
EOF
            echo_info "Added Nix to $PROFILE_FILE"
        fi
    fi

else
    # Multi-user installation
    echo_step "Performing multi-user installation..."

    # This is more complex and requires root
    echo_warn "Multi-user installation in offline mode is complex"
    echo_info "Using standard installer if available..."

    cd "$NIX_DIR"
    if [[ -f "install" ]]; then
        ./install --daemon --no-channel-add
    else
        echo_error "Multi-user installation requires the standard installer"
        exit 1
    fi

    # Configure for offline use
    echo_step "Configuring Nix for offline use..."
    cat > /etc/nix/nix.conf << 'EOF'
# Offline configuration
substituters =
require-sigs = false
build-users-group = nixbld
EOF

    # Start daemon if systemd available
    if command -v systemctl >/dev/null 2>&1; then
        echo_info "Starting Nix daemon..."
        systemctl enable nix-daemon || true
        systemctl start nix-daemon || true
    fi
fi

# Clean up installer
echo_step "Cleaning up..."
cd ..
rm -rf "$INSTALLER_DIR"

# Verify installation
echo_step "Verifying installation..."

# Source Nix environment for current shell
if [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
elif [[ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
    source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
fi

if command -v nix >/dev/null 2>&1; then
    echo_info "✅ Nix installed successfully!"
    echo_info "Version: $(nix --version)"
else
    echo_warn "Nix installed but not available in current shell"
    echo_info "Please run: source ~/.bashrc"
    echo_info "Or start a new shell session"
fi

echo_info ""
echo_info "Installation complete!"
echo_info "Note: This is an offline installation - no binary cache is configured"
echo_info "All packages must be built from source or imported from closures"