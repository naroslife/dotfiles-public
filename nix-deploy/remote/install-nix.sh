#!/usr/bin/env bash
#
# install-nix.sh - Install Nix with online/offline fallback
# Uses Determinate Nix Installer: https://github.com/DeterminateSystems/nix-installer
#

set -euo pipefail

# Default installation arguments
INSTALL_ARGS="${*:---no-confirm}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Disable colors if NO_COLOR is set or output is not a terminal
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
	RED='' GREEN='' YELLOW='' BLUE='' RESET=''
fi

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

echo_success() {
	echo -e "${GREEN}✅${RESET} $1"
}

# Check if Nix is already installed
if command -v nix >/dev/null 2>&1; then
	echo_warn "Nix is already installed: $(nix --version)"
	echo_info "Skipping installation"
	exit 0
fi

echo_info "Installing Nix using Determinate Nix Installer"
echo_info "Installation will try online method first, then fall back to offline"

# Detect platform for WSL workarounds
IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null; then
	IS_WSL=true
	echo_info "WSL environment detected"
fi

# WSL: Pre-create /nix directory with proper permissions
if $IS_WSL && [[ ! -d /nix ]]; then
	echo_step "Setting up /nix directory for WSL..."
	if sudo mkdir -p /nix 2>/dev/null; then
		sudo chown "$(whoami)" /nix
		echo_info "/nix directory created and owned by $(whoami)"
	else
		echo_error "Failed to create /nix directory"
		echo_info "Please run manually: sudo mkdir -p /nix && sudo chown $(whoami) /nix"
		exit 1
	fi
fi

# Phase 1: Try online installation
echo ""
echo_step "Phase 1: Attempting online installation..."
ONLINE_SUCCESS=false

if command -v curl >/dev/null 2>&1; then
	echo_info "Downloading installer from https://install.determinate.systems/nix"

	if curl --insecure -L https://install.determinate.systems/nix | sh -s -- install $INSTALL_ARGS; then
		ONLINE_SUCCESS=true
		echo_success "Online installation successful!"
	else
		echo_warn "Online installation failed (exit code: $?)"
	fi
else
	echo_warn "curl not available for online installation"
fi

# Phase 2: Fall back to offline installer if online failed
if ! $ONLINE_SUCCESS; then
	echo ""
	echo_step "Phase 2: Falling back to offline installation..."

	# Find offline installer
	OFFLINE_INSTALLER=""
	if [[ -f "nix-installer.sh" ]]; then
		OFFLINE_INSTALLER="nix-installer.sh"
	elif [[ -f "./nix-installer.sh" ]]; then
		OFFLINE_INSTALLER="./nix-installer.sh"
	else
		echo_error "Offline installer not found"
		echo_info "Expected: nix-installer.sh in current directory"
		echo_info ""
		echo_error "Both online and offline installation failed"
		exit 1
	fi

	echo_info "Using offline installer: $OFFLINE_INSTALLER"

	if bash "$OFFLINE_INSTALLER" install $INSTALL_ARGS; then
		echo_success "Offline installation successful!"
	else
		echo_error "Offline installation failed (exit code: $?)"
		echo_error ""
		echo_error "Installation failed. Please check the error messages above."
		exit 1
	fi
fi

# Phase 3: Configure for potential offline use
echo ""
echo_step "Phase 3: Configuring Nix..."

# Determine config file location
if [[ -d /etc/nix ]]; then
	# Multi-user installation
	CONFIG_FILE="/etc/nix/nix.conf"
	echo_info "Detected multi-user installation"
else
	# Single-user installation
	mkdir -p "$HOME/.config/nix"
	CONFIG_FILE="$HOME/.config/nix/nix.conf"
	echo_info "Detected single-user installation"
fi

# Add offline-friendly settings if not already present
if [[ -f "$CONFIG_FILE" ]]; then
	if ! grep -q "# nix-deploy offline configuration" "$CONFIG_FILE"; then
		echo_info "Adding offline-friendly settings to $CONFIG_FILE"
		cat >>"$CONFIG_FILE" <<'EOF'

# nix-deploy offline configuration
# These settings allow Nix to work without binary cache access
# Comment out if online access is restored
require-sigs = false
sandbox = false
EOF
	else
		echo_info "Offline settings already present in $CONFIG_FILE"
	fi
else
	echo_warn "Config file not found: $CONFIG_FILE"
fi

# Phase 4: Verify installation
echo ""
echo_step "Phase 4: Verifying installation..."

# Source Nix environment for current shell
if [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
	# shellcheck disable=SC1091
	source "$HOME/.nix-profile/etc/profile.d/nix.sh"
elif [[ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
	# shellcheck disable=SC1091
	source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
fi

if command -v nix >/dev/null 2>&1; then
	echo_success "Nix installed successfully!"
	echo_info "Version: $(nix --version)"
	echo_info "Install method: $([ "$ONLINE_SUCCESS" = "true" ] && echo "online" || echo "offline")"
else
	echo_warn "Nix installed but not available in current shell"
	echo_info "To use Nix in this shell, run:"
	if [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
		echo_info "  source ~/.nix-profile/etc/profile.d/nix.sh"
	elif [[ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
		echo_info "  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
	fi
	echo_info ""
	echo_info "Or start a new shell session"
fi

echo ""
echo_success "Installation complete!"
echo_info ""
echo_info "Next steps:"
echo_info "  1. Start a new shell or source the Nix profile"
echo_info "  2. Run: ./import-closure.sh"
