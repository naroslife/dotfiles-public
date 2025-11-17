#!/usr/bin/env bash
#
# activate-profile.sh - Activate Home Manager profile on remote machine
#

set -euo pipefail

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

# Check if Nix is available
if ! command -v nix-env >/dev/null 2>&1; then
	echo_error "Nix is not installed or not in PATH"
	echo_info "Please source Nix environment: source ~/.nix-profile/etc/profile.d/nix.sh"
	exit 1
fi

# Get activation package path from metadata
ACTIVATION_PACKAGE=""
if [[ -f "metadata.json" ]] && command -v jq >/dev/null 2>&1; then
	ACTIVATION_PACKAGE=$(jq -r '.store_path' metadata.json)
elif [[ -f "metadata.json" ]]; then
	# Fallback: parse JSON without jq (brittle but works for simple cases)
	ACTIVATION_PACKAGE=$(grep -o '"store_path"[[:space:]]*:[[:space:]]*"[^"]*"' metadata.json | cut -d'"' -f4)
else
	echo_error "Cannot determine activation package path"
	echo_info "metadata.json not found. Ensure nix copy transfer completed successfully."
	exit 1
fi

echo_info "Activation package: $ACTIVATION_PACKAGE"

# Verify activation package exists
if [[ ! -e "$ACTIVATION_PACKAGE" ]]; then
	echo_error "Activation package not found: $ACTIVATION_PACKAGE"
	echo_info "Please ensure the nix copy transfer completed successfully"
	echo_info "Check the deployment output for errors during transfer"
	exit 1
fi

# Check if it's a valid activation package
if [[ ! -x "$ACTIVATION_PACKAGE/activate" ]]; then
	echo_error "Invalid activation package (no activate script)"
	exit 1
fi

# Backup existing profile (if requested in metadata)
BACKUP_EXISTING=true
if [[ -f "metadata.json" ]] && command -v jq >/dev/null 2>&1; then
	BACKUP_SETTING=$(jq -r '.deployment.options.backup_existing_profile // "true"' metadata.json 2>/dev/null || echo "true")
	if [[ "$BACKUP_SETTING" == "false" ]]; then
		BACKUP_EXISTING=false
	fi
fi

if $BACKUP_EXISTING && [[ -L "$HOME/.nix-profile" ]]; then
	echo_step "Backing up existing profile..."
	BACKUP_DIR="$HOME/.config/nix-deploy/backups"
	mkdir -p "$BACKUP_DIR"

	TIMESTAMP=$(date +%Y%m%d-%H%M%S)
	BACKUP_NAME="profile-backup-$TIMESTAMP"

	# Save current generation number
	CURRENT_GEN=$(nix-env --list-generations | tail -1 | awk '{print $1}' || echo "unknown")
	echo "$CURRENT_GEN" >"$BACKUP_DIR/$BACKUP_NAME.generation"

	# Save current profile path
	readlink -f "$HOME/.nix-profile" >"$BACKUP_DIR/$BACKUP_NAME.path"

	echo_info "Profile backed up to: $BACKUP_DIR/$BACKUP_NAME"
fi

# Check for WSL-specific issues
if grep -qi microsoft /proc/version 2>/dev/null; then
	echo_info "WSL environment detected, applying workarounds..."

	# Fix permissions if needed
	if [[ -d /nix/store ]]; then
		# Check if we can write to /nix/var/nix/profiles
		if   [[ ! -w /nix/var/nix/profiles/per-user/$(whoami) ]]; then
			echo_warn      "Permission issue detected in /nix/var/nix/profiles"
			echo_info      "You may need to run: sudo chown -R $(whoami) /nix/var/nix/profiles/per-user/$(whoami)"
		fi
	fi

	# Set proper umask for WSL
	umask 0022
fi

# Activate the profile
echo_step "Activating Home Manager profile..."

# First, add to nix-env for generation management
echo_info "Registering with nix-env..."
if nix-env --set "$ACTIVATION_PACKAGE"; then
	echo_info "Profile registered successfully"
else
	echo_warn "Failed to register with nix-env, continuing anyway"
fi

# Run the activation script
echo_info "Running activation script..."
if "$ACTIVATION_PACKAGE/activate"; then
	echo_info "Activation completed successfully"
else
	echo_error "Activation script failed"
	exit 1
fi

# Create convenience symlinks
echo_step "Creating convenience symlinks..."

# Link to home-manager command if it exists
if [[ -x "$ACTIVATION_PACKAGE/home-path/bin/home-manager" ]]; then
	mkdir -p "$HOME/.local/bin"
	ln -sf "$ACTIVATION_PACKAGE/home-path/bin/home-manager" "$HOME/.local/bin/home-manager"
	echo_info "home-manager command linked to ~/.local/bin/"
fi

# Verify activation
echo_step "Verifying activation..."

# Check if profile is properly linked
if [[ -L "$HOME/.nix-profile" ]]; then
	PROFILE_TARGET=$(readlink -f "$HOME/.nix-profile")
	echo_info "Profile linked to: $PROFILE_TARGET"
else
	echo_warn "Profile symlink not found at ~/.nix-profile"
fi

# Check generation
GENERATION=$(nix-env --list-generations | tail -1 | awk '{print $1}' || echo "unknown")
echo_info "Current generation: $GENERATION"

# List what was activated
echo_info "Activated packages:"
if command -v home-manager >/dev/null 2>&1; then
	home-manager packages | head -20
	TOTAL_PACKAGES=$(home-manager packages | wc -l)
	if [[ $TOTAL_PACKAGES -gt 20 ]]; then
		echo_info   "... and $((TOTAL_PACKAGES - 20)) more packages"
	fi
else
	nix-env -q | head -20
fi

echo_info ""
echo_info "✅ Profile activation complete!"
echo_info ""
echo_info "Next steps:"
echo_info "1. Source your shell configuration:"
echo_info "   source ~/.bashrc"
echo_info "   or start a new shell session"
echo_info ""
echo_info "2. Verify your environment:"
echo_info "   which elvish  # or your configured shell"
echo_info "   home-manager generations"
echo_info ""

if $BACKUP_EXISTING; then
	echo_info "3. If you need to rollback:"
	echo_info "   nix-env --rollback"
	echo_info "   or restore from: $BACKUP_DIR"
fi
