#!/usr/bin/env bash
# Dotfiles Cleanup Script
#
# This script safely removes all configurations, installations, and changes
# made by the dotfiles repository setup process.
#
# Usage:
#   ./cleanup.sh [OPTIONS]
#
# Options:
#   -y, --yes           Answer yes to all prompts (dangerous!)
#   -b, --backup        Create backups before removing (default)
#   --no-backup         Don't create backups
#   -k, --keep-nix      Keep Nix installation (only remove Home Manager)
#   -v, --verbose       Enable verbose logging
#   -h, --help          Show this help message
#
# Safety Features:
#   - Interactive confirmations by default
#   - Automatic backups of removed configurations
#   - Detailed logging of all operations
#   - Dry-run capability to preview changes

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$HOME/.dotfiles-cleanup.log"

# Script state
ASSUME_YES=false
CREATE_BACKUPS=true
KEEP_NIX=false
VERBOSE=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
	echo  -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
	echo  -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
	echo  -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

log_debug() {
	if  $VERBOSE; then
		echo     -e "${BLUE}[DEBUG]${NC} $*" | tee -a "$LOG_FILE"
	fi
}

die() {
	log_error  "$*"
	exit  1
}

# Ask yes/no question
ask_yes_no() {
	local  question="$1"

	if  $ASSUME_YES; then
		return     0
	fi

	while  true; do
		read     -rp "$(echo -e "${YELLOW}?${NC} $question (y/n): ")" yn
		case $yn in
			[Yy]*)        return 0 ;;
			[Nn]*)        return 1 ;;
			*)        echo "Please answer yes or no." ;;
		esac
	done
}

# Show help message
show_help() {
	cat  <<EOF
Dotfiles Cleanup Script

This script safely removes all configurations, installations, and changes
made by the dotfiles repository setup process.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -y, --yes           Answer yes to all prompts (DANGEROUS!)
    -b, --backup        Create backups before removing (default)
    --no-backup         Don't create backups
    -k, --keep-nix      Keep Nix installation (only remove Home Manager)
    -v, --verbose       Enable verbose logging
    -n, --dry-run       Show what would be removed without actually removing
    -h, --help          Show this help message

SAFETY FEATURES:
    - Interactive confirmations by default
    - Automatic backups of removed configurations
    - Detailed logging to: $LOG_FILE
    - Dry-run mode to preview changes

EXAMPLES:
    $0                  # Interactive cleanup with backups
    $0 --dry-run        # Preview what would be removed
    $0 --keep-nix       # Remove only Home Manager, keep Nix
    $0 --no-backup -y   # Full cleanup without backups (DANGEROUS!)

WARNING:
    This script will remove all configurations and potentially uninstall Nix.
    Make sure you understand what will be removed before proceeding.
    Use --dry-run first to see what would be removed.

EOF
}

# Parse command line arguments
parse_arguments() {
	while  [[ $# -gt 0 ]]; do
		case $1 in
			-y |      --yes)
				ASSUME_YES=true
				shift
				;;
			-b |      --backup)
				CREATE_BACKUPS=true
				shift
				;;
			--no-backup)
				CREATE_BACKUPS=false
				shift
				;;
			-k |      --keep-nix)
				KEEP_NIX=true
				shift
				;;
			-v |      --verbose)
				VERBOSE=true
				shift
				;;
			-n |      --dry-run)
				DRY_RUN=true
				shift
				;;
			-h |      --help)
				show_help
				exit           0
				;;
			*)
				die           "Unknown option: $1. Use --help for usage information."
				;;
		esac
	done
}

# Backup a file or directory
backup_item() {
	local  item="$1"

	if  [[ ! -e "$item" ]]; then
		log_debug     "Item doesn't exist, skipping backup: $item"
		return     0
	fi

	if  ! $CREATE_BACKUPS; then
		log_debug     "Backups disabled, skipping: $item"
		return     0
	fi

	if  $DRY_RUN; then
		log_info     "[DRY-RUN] Would backup: $item"
		return     0
	fi

	# Create backup directory if it doesn't exist
	mkdir  -p "$BACKUP_DIR"

	local  item_name
	item_name="$( basename "$item")"
	local  backup_path="$BACKUP_DIR/$item_name"

	# Handle duplicate names
	local  counter=1
	while  [[ -e "$backup_path" ]]; do
		backup_path="$BACKUP_DIR/${item_name}.${counter}"
		((counter++))
	done

	log_debug  "Backing up: $item -> $backup_path"
	cp  -a "$item" "$backup_path"
}

# Remove a file or directory
remove_item() {
	local  item="$1"
	local  description="${2:-$item}"

	if  [[ ! -e "$item" ]]; then
		log_debug     "Item doesn't exist: $item"
		return     0
	fi

	if  $DRY_RUN; then
		log_info     "[DRY-RUN] Would remove: $description"
		return     0
	fi

	# Backup before removing
	backup_item  "$item"

	log_info  "Removing: $description"
	if  [[ -d "$item" && ! -L "$item" ]]; then
		rm     -rf "$item"
	else
		rm     -f "$item"
	fi
}

# Remove symlink
remove_symlink() {
	local  link="$1"
	local  description="${2:-$link}"

	if  [[ ! -L "$link" ]]; then
		log_debug     "Not a symlink: $link"
		return     0
	fi

	if  $DRY_RUN; then
		log_info     "[DRY-RUN] Would remove symlink: $description"
		return     0
	fi

	log_info  "Removing symlink: $description"
	rm  -f "$link"
}

# Remove lines from file
remove_lines_from_file() {
	local  file="$1"
	local  pattern="$2"
	local  description="${3:-$file}"

	if  [[ ! -f "$file" ]]; then
		log_debug     "File doesn't exist: $file"
		return     0
	fi

	if  ! grep -q "$pattern" "$file"; then
		log_debug     "Pattern not found in file: $file"
		return     0
	fi

	if  $DRY_RUN; then
		log_info     "[DRY-RUN] Would remove lines matching '$pattern' from: $description"
		return     0
	fi

	# Backup before modifying
	backup_item  "$file"

	log_info  "Removing lines from: $description"
	sed  -i "/$pattern/d" "$file"
}

# Clean Home Manager configurations
cleanup_home_manager() {
	log_info  "🧹 Cleaning up Home Manager configurations"

	# Remove Home Manager profile
	if  [[ -d "$HOME/.local/state/nix/profiles/home-manager" ]]; then
		if     ask_yes_no "Remove Home Manager profile and all managed packages?"; then
			remove_item        "$HOME/.local/state/nix/profiles/home-manager" "Home Manager profile"
		fi
	fi

	# Remove Home Manager-managed files
	log_info  "Removing Home Manager-managed configuration files"

	# Elvish configurations
	remove_item  "$HOME/.config/elvish/rc.elv" "Elvish RC"
	remove_item  "$HOME/.config/elvish/lib" "Elvish lib"
	remove_item  "$HOME/.config/elvish/aliases" "Elvish aliases"

	# Tmux scripts
	remove_item  "$HOME/.config/tmux/scripts" "Tmux scripts"
	remove_item  "$HOME/.config/tmux/tmux.conf" "Tmux config"

	# Carapace configuration
	remove_item  "$HOME/.config/carapace" "Carapace config"

	# Starship configuration
	remove_item  "$HOME/.config/starship.toml" "Starship config"

	# Atuin configuration
	remove_item  "$HOME/.config/atuin" "Atuin config"

	# SSH configuration (if managed by dotfiles)
	if  [[ -L "$HOME/.ssh/config" ]]; then
		remove_symlink     "$HOME/.ssh/config" "SSH config symlink"
	fi

	# Tool versions
	remove_item  "$HOME/.tool-versions" "ASDF tool versions"

	# Package manager configs
	remove_item  "$HOME/.npmrc" "NPM config"
	remove_item  "$HOME/.config/pip/pip.conf" "Pip config"

	# Package manager directories (empty markers)
	remove_item  "$HOME/.npm-global/.keep" "NPM global directory marker"
	remove_item  "$HOME/.gem/.keep" "Gem directory marker"

	# Git configuration (if managed by dotfiles)
	if  [[ -L "$HOME/.gitconfig" ]]; then
		remove_symlink     "$HOME/.gitconfig" "Git config symlink"
	fi

	# # VS Code configuration (if managed by dotfiles)
	# if  [[ -L "$HOME/.config/Code/User/settings.json" ]]; then
	# 	remove_symlink     "$HOME/.config/Code/User/settings.json" "VS Code settings symlink"
	# fi

	# Remove shell RC modifications
	log_info  "Cleaning up shell RC files"

	# Bash
	if  [[ -f "$HOME/.bashrc" ]]; then
		remove_item     "$HOME/.bashrc" "Bash RC"
	fi

	# Zsh
	if  [[ -f "$HOME/.zshrc" ]]; then
		remove_item     "$HOME/.zshrc" "Zsh RC"
	fi

	# Profile
	if  [[ -f "$HOME/.profile" ]]; then
		remove_item     "$HOME/.profile" ".profile"
	fi

	# Bash profile
	if  [[ -f "$HOME/.bash_profile" ]]; then
		remove_item     "$HOME/.bash_profile" "Bash Profile"
	fi
}

# Clean Claude Code configuration
cleanup_claude() {
	log_info  "🤖 NOT! Cleaning up Claude Code configuration"

	# if  ! ask_yes_no "Remove Claude Code configuration?"; then
	# 	log_info     "Skipping Claude Code cleanup"
	# 	return     0
	# fi

	# # Remove symlinks first
	# remove_symlink  "$HOME/.claude/CLAUDE.md" "Claude CLAUDE.md"
	# remove_symlink  "$HOME/.claude/settings.json" "Claude settings"
	# remove_symlink  "$HOME/.claude/.gitignore" "Claude .gitignore"
	# remove_symlink  "$HOME/.claude/setup-plugins.sh" "Claude setup script"
	# remove_symlink  "$HOME/.claude/README.md" "Claude README"
	# remove_symlink  "$HOME/.claude/ccline" "Claude ccline directory"
	# remove_symlink  "$HOME/.claude/.mcp" "Claude MCP directory"

	# # Ask about removing entire ~/.claude directory
	# if  [[ -d "$HOME/.claude" ]]; then
	# 	if     ask_yes_no "Remove entire ~/.claude directory (includes any personal changes)?"; then
	# 		remove_item        "$HOME/.claude" "Claude Code directory"
	# 	else
	# 		log_info        "Keeping ~/.claude directory with any personal configurations"
	# 	fi
	# fi
}

# Clean MCP configuration
cleanup_mcp() {
	log_info  "🔌 NOT! Cleaning up MCP configuration"

	# if  [[ -f "$HOME/.mcp.json" ]]; then
	# 	if     ask_yes_no "Remove MCP configuration (~/.mcp.json)?"; then
	# 		remove_item        "$HOME/.mcp.json" "MCP config"
	# 	fi
	# fi
}

# Clean Serena configuration
cleanup_serena() {
	log_info  "🧠 NOT! Cleaning up Serena configuration"

	# # Check if .serena is in the dotfiles repo
	# if  [[ -d "$SCRIPT_DIR/.serena" ]]; then
	# 	log_debug     "Serena configuration is in dotfiles repo, no system cleanup needed"
	# fi

	# # Check for global Serena config
	# if  [[ -d "$HOME/.serena" && "$HOME/.serena" != "$SCRIPT_DIR/.serena" ]]; then
	# 	if     ask_yes_no "Remove Serena configuration (~/.serena)?"; then
	# 		remove_item        "$HOME/.serena" "Serena config"
	# 	fi
	# fi
}

# Clean Nix installation
cleanup_nix() {
	if  $KEEP_NIX; then
		log_info     "⏭️  Skipping Nix removal (--keep-nix flag set)"
		return     0
	fi

	log_warn  "🗑️  Nix uninstallation requested"

	if  ! ask_yes_no "⚠️  Remove Nix package manager? This will uninstall ALL Nix packages and profiles."; then
		log_info     "Keeping Nix installation"
		return     0
	fi

	if  ! command -v nix >/dev/null 2>&1; then
		log_info     "Nix is not installed or not in PATH"
		return     0
	fi

	log_info  "Uninstalling Nix package manager"

	if  $DRY_RUN; then
		log_info     "[DRY-RUN] Would uninstall Nix package manager"
		return     0
	fi

	# Check which Nix installer was used
	if  [[ -f /nix/receipt.json ]] && grep -q "determinate" /nix/receipt.json 2>/dev/null; then
		log_info     "Detected Determinate Systems Nix installer"

		# Use Determinate Systems uninstaller
		if     command -v /nix/nix-installer >/dev/null 2>&1; then
			log_info        "Running Nix uninstaller..."
			/nix/nix-installer        uninstall
		else
			log_warn        "Determinate Systems uninstaller not found, trying manual cleanup"
			manual_nix_cleanup
		fi
	else
		log_info     "Detected standard Nix installer"
		manual_nix_cleanup
	fi
  manual_nix_cleanup
}

# Manual Nix cleanup (for non-Determinate Systems installations)
manual_nix_cleanup() {
	log_info  "Performing manual Nix cleanup"

	# Stop and disable Nix daemon
	if  command -v systemctl >/dev/null 2>&1; then
		log_info     "Stopping Nix daemon"
		sudo     systemctl stop nix-daemon.service 2>/dev/null || true
		sudo     systemctl disable nix-daemon.service 2>/dev/null || true
	fi

	# Remove Nix directories
	log_info  "Removing Nix directories"
	sudo  rm -rf /nix

	# Remove Nix build users
	if  [[ -f /etc/passwd ]]; then
		log_info     "Removing Nix build users"
		for i in     {1..32}; do
			sudo        userdel nixbld$i 2>/dev/null || true
		done
		sudo     groupdel nixbld 2>/dev/null || true
	fi

	# Clean up profile modifications
	# remove_lines_from_file  "$HOME/.profile" "nix" "Profile (Nix lines)"
	# remove_lines_from_file  "$HOME/.bashrc" "nix" "Bash RC (Nix lines)"
	# remove_lines_from_file  "$HOME/.zshrc" "nix" "Zsh RC (Nix lines)"
	# remove_lines_from_file  "$HOME/.bash_profile" "nix" "Bash Profile (Nix lines)"

	log_info  "Manual Nix cleanup completed"
}


cleanup_nix_store() {
	log_info  "Performing manual Nix cleanup"

	# Stop and disable Nix daemon
	if  command -v systemctl >/dev/null 2>&1; then
		log_info     "Stopping Nix daemon"
		sudo     systemctl stop nix-daemon.service 2>/dev/null || true
	fi

	# Remove .nix-profile
	log_info  "Removing Nix profile directories"
	sudo  rm -rf $HOME/.nix-profile

	# Remove Nix directories
	log_info  "Removing Nix store directories"
	sudo  rm -rf /nix/store


  log_info     "Starting Nix daemon"
  sudo     systemctl start nix-daemon.service 2>/dev/null || true

	log_info  "Manual Nix store cleanup completed"
}

# Clean backup files created by apply.sh
cleanup_backups() {
	log_info  "🗂️  Cleaning up backup files"

	# Find backup files
	local  backup_files=(
		"$HOME/.bashrc.backup"*
		"$HOME/.zshrc.backup"*
		"$HOME/.profile.backup"*
		"$HOME/.gitconfig.backup"*
	)

	local  found_backups=false
	for pattern in  "${backup_files[@]}"; do
		# shellcheck disable=SC2086
		if     ls $pattern 2>/dev/null | grep -q .; then
			found_backups=true
			break
		fi
	done

	if  ! $found_backups; then
		log_debug     "No backup files found"
		return     0
	fi

	if  ask_yes_no "Remove backup files created by apply.sh?"; then
		for pattern in     "${backup_files[@]}"; do
			# shellcheck disable=SC2086
			for file in        $pattern; do
				if           [[ -f "$file" ]]; then
					remove_item              "$file" "Backup: $(basename "$file")"
				fi
			done
		done
	fi
}

# Clean completions
cleanup_completions() {
	log_info  "🔤 Cleaning up completions"

	# Bash completions
	if  [[ -d "$HOME/.local/share/bash-completion" ]]; then
		if     ask_yes_no "Remove bash completions (~/.local/share/bash-completion)?"; then
			remove_item        "$HOME/.local/share/bash-completion" "Bash completions"
		fi
	fi

	# Zsh completions
	if  [[ -d "$HOME/.local/share/zsh/site-functions" ]]; then
		if     ask_yes_no "Remove zsh completions (~/.local/share/zsh/site-functions)?"; then
			remove_item        "$HOME/.local/share/zsh/site-functions" "Zsh completions"
		fi
	fi
}

# Clean WSL-specific configurations
cleanup_wsl() {
	if  [[ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
		log_debug     "Not running on WSL, skipping WSL cleanup"
		return     0
	fi

	log_info  "🐧 Cleaning up WSL-specific configurations"

	# Check for WSL configuration in /etc/wsl.conf
	if  [[ -f /etc/wsl.conf ]]; then
		if     ask_yes_no "Remove /etc/wsl.conf modifications?"; then
			if        $DRY_RUN; then
				log_info           "[DRY-RUN] Would backup and remove /etc/wsl.conf"
			else
				log_warn           "Removing /etc/wsl.conf requires sudo access"
				sudo           cp /etc/wsl.conf "$BACKUP_DIR/wsl.conf.backup" 2>/dev/null || true
				sudo           rm -f /etc/wsl.conf
			fi
		fi
	fi
}

# Summary report
show_summary() {
	log_info  ""
	log_info  "═══════════════════════════════════════════════════════════"
	log_info  "Cleanup Summary"
	log_info  "═══════════════════════════════════════════════════════════"

	if  $DRY_RUN; then
		log_info     "Mode: DRY-RUN (no actual changes made)"
	else
		log_info     "Mode: LIVE (changes were applied)"
	fi

	if  $CREATE_BACKUPS && [[ -d "$BACKUP_DIR" ]]; then
		log_info     ""
		log_info     "Backups saved to: $BACKUP_DIR"
	fi

	log_info  "Full log saved to: $LOG_FILE"
	log_info  ""

	if  ! $DRY_RUN; then
		log_info     "✅ Cleanup completed successfully!"
		log_info     ""
		log_info     "📝 Next steps:"
		log_info     "   1. Restart your shell or logout/login"
		log_info     "   2. Verify configurations are removed"
		log_info     "   3. Check backups if you need to restore anything"

		if     ! $KEEP_NIX; then
			log_info        "   4. Reboot if Nix was removed (recommended)"
		fi
	fi

	log_info  "═══════════════════════════════════════════════════════════"
}

# Main cleanup orchestration
main() {
	# Parse arguments
	parse_arguments  "$@"

	# Initialize log
	echo  "Dotfiles Cleanup - $(date)" >"$LOG_FILE"

	log_info  "═══════════════════════════════════════════════════════════"
	log_info  "Dotfiles Cleanup Script"
	log_info  "═══════════════════════════════════════════════════════════"
	log_info  ""

	if  $DRY_RUN; then
		log_info     "🔍 DRY-RUN MODE: No actual changes will be made"
	fi

	# Show configuration
	log_debug  "Configuration:"
	log_debug  "  ASSUME_YES: $ASSUME_YES"
	log_debug  "  CREATE_BACKUPS: $CREATE_BACKUPS"
	log_debug  "  KEEP_NIX: $KEEP_NIX"
	log_debug  "  VERBOSE: $VERBOSE"
	log_debug  "  DRY_RUN: $DRY_RUN"
	log_debug  "  BACKUP_DIR: $BACKUP_DIR"
	log_debug  ""

	# Warning
	if  ! $DRY_RUN && ! $ASSUME_YES; then
		log_warn     "⚠️  WARNING ⚠️"
		log_warn     "This script will remove dotfiles configurations and potentially uninstall Nix."
		log_warn     ""
		if     ! ask_yes_no "Are you sure you want to continue?"; then
			log_info        "Cleanup cancelled by user"
			exit        0
		fi
		log_info     ""
	fi

	# Execute cleanup steps
	# cleanup_claude
	# cleanup_mcp
	# cleanup_serena
	cleanup_completions
	cleanup_backups
	cleanup_wsl
  cleanup_home_manager
  cleanup_nix_store
	# cleanup_nix   # Must be last

	# Show summary
	show_summary
}

# Run main function with all arguments
main "$@"
