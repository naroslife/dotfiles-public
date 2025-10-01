#!/bin/bash
# WSL-specific initialization script

# Function to check if we're running in WSL
is_wsl() {
	grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null
}

if is_wsl; then
	# Set up Windows PATH integration (if needed)
	if [[ -d "/mnt/c/Windows/System32" ]]; then
		export PATH="$PATH:/mnt/c/Windows/System32"
	fi

	# WSL-specific aliases for clipboard integration
	alias pbcopy='clip.exe'
	alias pbpaste='powershell.exe -command "Get-Clipboard" | head -n -1'

	# Open files/URLs in Windows default applications
	alias open='wslview'

	# Check if we should show daily messages
	WSL_MESSAGES_FILE="$HOME/.cache/wsl-messages-last-shown"
	TODAY=$(date +%Y-%m-%d)
	SHOW_MESSAGES=false

	# Create cache directory if it doesn't exist
	mkdir -p "$HOME/.cache"

	# Check if we've already shown messages today
	if [[ ! -f "$WSL_MESSAGES_FILE" ]] || [[ "$(cat "$WSL_MESSAGES_FILE" 2>/dev/null)" != "$TODAY" ]]; then
		SHOW_MESSAGES=true
		echo "$TODAY" >"$WSL_MESSAGES_FILE"
	fi

	# Show messages only once per day
	if [ "$SHOW_MESSAGES" = true ]; then
		echo "🔧 WSL environment detected - applying optimizations..."

		# Auto-run APT network switch once per day (Enterprise and WSL specific)
		if command -v apt-network-switch &>/dev/null; then
			echo "🔄 Running daily APT network configuration check..."

			# Run the check in background to not block shell startup
			(
				apt-network-switch &>/dev/null
				if [ $? -eq 0 ]; then
					echo "✅ APT repositories configured for today's network"
				fi
			) &

			# Give it a moment to complete (but don't wait if it's slow)
			sleep 0.5
		fi

		# WSL utilities reminders
		echo "💡 WSL Tool Reminders:"
		echo "  wslview <file>     - Open file in Windows default app"
		echo "  wslpath <path>     - Convert between Windows and WSL paths"
		echo "  wslvar <var>       - Access Windows environment variables"
		echo "  clip.exe           - Copy to Windows clipboard"
		echo ""
	fi

	# Performance optimizations
	export WSLENV="PATH/l:XDG_CONFIG_HOME/up"

	# Ensure proper umask for Windows compatibility
	umask 022

	# Fix DBus for Electron/AppImage apps
	if [[ -f "$HOME/dotfiles-public/wsl-fixes/fix-dbus-wsl.sh" ]]; then
		source "$HOME/dotfiles-public/wsl-fixes/fix-dbus-wsl.sh" 2>/dev/null
	fi

	# Fix WSLg systemd conflicts (run once per session)
	if [[ ! -f ~/.cache/.wslg-systemd-fixed ]] && [[ -f "$HOME/dotfiles-public/wsl-fixes/fix-wslg-systemd.sh" ]]; then
		mkdir -p ~/.cache
		"$HOME/dotfiles-public/wsl-fixes/fix-wslg-systemd.sh" 2>/dev/null
		touch ~/.cache/.wslg-systemd-fixed
	fi
fi
