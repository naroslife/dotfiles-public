#!/usr/bin/env bash
#
# setup-shell.sh - Setup shell integration for Home Manager
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Disable colors if NO_COLOR is set or output is not a terminal
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
	GREEN='' YELLOW='' RESET=''
fi

echo_info() {
	echo  -e "${GREEN}[INFO]${RESET} $1"
}

echo_warn() {
	echo  -e "${YELLOW}[WARN]${RESET} $1"
}

# Detect current shell
CURRENT_SHELL=$(basename "$SHELL")
echo_info "Current shell: $CURRENT_SHELL"

# Home Manager session variables
HM_SESSION_VARS="$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"

# Setup for different shells
setup_bash() {
	local  rc_file="$HOME/.bashrc"
	local  backup_file="$rc_file.backup-$(date +%Y%m%d-%H%M%S)"

	# Backup existing file
	if  [[ -f "$rc_file" ]]; then
		cp     "$rc_file" "$backup_file"
		echo_info     "Backed up $rc_file to $backup_file"
	fi

	# Check if already configured
	if  grep -q "home-manager" "$rc_file" 2>/dev/null; then
		echo_info     "Bash already configured for Home Manager"
		return     0
	fi

	# Add Home Manager integration
	cat  >>"$rc_file"  <<'EOF'

# Home Manager integration (added by nix-deploy)
if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

# Nix profile
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Add Home Manager bins to PATH
export PATH="$HOME/.nix-profile/bin:$PATH"
EOF

	echo_info  "Bash configuration updated"
}

setup_zsh() {
	local  rc_file="$HOME/.zshrc"
	local  backup_file="$rc_file.backup-$(date +%Y%m%d-%H%M%S)"

	# Backup existing file
	if  [[ -f "$rc_file" ]]; then
		cp     "$rc_file" "$backup_file"
		echo_info     "Backed up $rc_file to $backup_file"
	fi

	# Check if already configured
	if  grep -q "home-manager" "$rc_file" 2>/dev/null; then
		echo_info     "Zsh already configured for Home Manager"
		return     0
	fi

	# Add Home Manager integration
	cat  >>"$rc_file"  <<'EOF'

# Home Manager integration (added by nix-deploy)
if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

# Nix profile
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Add Home Manager bins to PATH
export PATH="$HOME/.nix-profile/bin:$PATH"
EOF

	echo_info  "Zsh configuration updated"
}

setup_fish() {
	local  config_dir="$HOME/.config/fish"
	local  config_file="$config_dir/config.fish"
	local  backup_file="$config_file.backup-$(date +%Y%m%d-%H%M%S)"

	# Create config directory if needed
	mkdir  -p "$config_dir"

	# Backup existing file
	if  [[ -f "$config_file" ]]; then
		cp     "$config_file" "$backup_file"
		echo_info     "Backed up $config_file to $backup_file"
	fi

	# Check if already configured
	if  grep -q "home-manager" "$config_file" 2>/dev/null; then
		echo_info     "Fish already configured for Home Manager"
		return     0
	fi

	# Add Home Manager integration
	cat  >>"$config_file"  <<'EOF'

# Home Manager integration (added by nix-deploy)
if test -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    bass source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
end

# Nix profile
if test -f "$HOME/.nix-profile/etc/profile.d/nix.sh"
    bass source "$HOME/.nix-profile/etc/profile.d/nix.sh"
end

# Add Home Manager bins to PATH
set -x PATH "$HOME/.nix-profile/bin" $PATH
EOF

	echo_info  "Fish configuration updated"
	echo_warn  "Note: Fish requires 'bass' for sourcing bash scripts"
}

setup_elvish() {
	local  config_dir="$HOME/.config/elvish"
	local  rc_file="$config_dir/rc.elv"
	local  backup_file="$rc_file.backup-$(date +%Y%m%d-%H%M%S)"

	# Create config directory if needed
	mkdir  -p "$config_dir"

	# Backup existing file
	if  [[ -f "$rc_file" ]]; then
		cp     "$rc_file" "$backup_file"
		echo_info     "Backed up $rc_file to $backup_file"
	fi

	# Check if already configured
	if  grep -q "home-manager" "$rc_file" 2>/dev/null; then
		echo_info     "Elvish already configured for Home Manager"
		return     0
	fi

	# Add Home Manager integration
	cat  >>"$rc_file"  <<'EOF'

# Home Manager integration (added by nix-deploy)
# Add Home Manager bins to PATH
set paths = [
  ~/.nix-profile/bin
  $@paths
]

# Note: Elvish cannot directly source bash scripts
# Environment variables should be set through Home Manager
EOF

	echo_info  "Elvish configuration updated"
	echo_info  "Note: Elvish users should rely on Home Manager for environment setup"
}

# Setup PATH for current session
setup_current_session() {
	export  PATH="$HOME/.nix-profile/bin:$PATH"

	if  [[ -f "$HM_SESSION_VARS" ]]; then
		source     "$HM_SESSION_VARS"
		echo_info     "Home Manager session variables loaded"
	fi
}

# Main setup
main() {
	echo_info  "Setting up shell integration..."

	# Setup for detected shell
	case "$CURRENT_SHELL" in
		bash)
			setup_bash
			;;
		zsh)
			setup_zsh
			;;
		fish)
			setup_fish
			;;
		elvish)
			setup_elvish
			;;
		*)
			echo_warn        "Unknown shell: $CURRENT_SHELL"
			echo_info        "Please manually add the following to your shell configuration:"
			echo        "  source $HM_SESSION_VARS"
			echo        "  export PATH=\"\$HOME/.nix-profile/bin:\$PATH\""
			;;
	esac

	# Also setup common profile for login shells
	if  [[ -f "$HOME/.profile" ]]; then
		if     ! grep -q "home-manager" "$HOME/.profile" 2>/dev/null; then
			cat        >>"$HOME/.profile"  <<'EOF'

# Home Manager integration (added by nix-deploy)
if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi
export PATH="$HOME/.nix-profile/bin:$PATH"
EOF
			echo_info        "Updated ~/.profile for login shells"
		fi
	fi

	# Setup current session
	setup_current_session

	echo_info  "Shell integration complete!"
	echo_info  "Please restart your shell or run: source ~/.$CURRENT_SHELL"
}

main "$@"
