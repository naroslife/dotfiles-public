#!/usr/bin/env bash
# Claude Code Setup Module
#
# This module handles the setup of Claude Code configuration files.
# It symlinks configuration from the dotfiles repo to ~/.claude/

# Source common utilities
_GH_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$_GH_MODULE_DIR/../common.sh"

# Setup Claude Code configuration
setup_claude_config() {
	local dotfiles_claude="$SCRIPT_DIR/.claude"
	local target_claude="$HOME/.claude"

	log_info "📝 Setting up Claude Code configuration"

	# Create target directory if it doesn't exist
	if [[ ! -d "$target_claude" ]]; then
		log_debug "Creating ~/.claude directory"
		mkdir -p "$target_claude"
	fi

	# Files to symlink
	local files_to_link=(
		"CLAUDE.md"
		"settings.json"
		".gitignore"
		"setup-plugins.sh"
		"README.md"
	)

	# Symlink configuration files
	for file in "${files_to_link[@]}"; do
		local source="$dotfiles_claude/$file"
		local target="$target_claude/$file"

		if [[ ! -f "$source" ]]; then
			log_debug "Source file not found, skipping: $file"
			continue
		fi

		if [[ -L "$target" ]]; then
			# Already a symlink, check if it points to the right place
			if [[ "$(readlink "$target")" == "$source" ]]; then
				log_debug "Symlink already correct: $file"
				continue
			else
				log_debug "Removing incorrect symlink: $file"
				rm "$target"
			fi
		elif [[ -f "$target" ]]; then
			# File exists but is not a symlink
			if $CREATE_BACKUPS; then
				local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
				log_info "  Backing up existing $file to $(basename "$backup")"
				mv "$target" "$backup"
			else
				log_debug "Removing existing file: $file"
				rm "$target"
			fi
		fi

		log_debug "Creating symlink: $file"
		ln -s "$source" "$target"
	done

	# Symlink ccline directory
	local ccline_source="$dotfiles_claude/ccline"
	local ccline_target="$target_claude/ccline"

	if [[ -d "$ccline_source" ]]; then
		if [[ -L "$ccline_target" ]]; then
			if [[ "$(readlink "$ccline_target")" == "$ccline_source" ]]; then
				log_debug "ccline symlink already correct"
			else
				log_debug "Removing incorrect ccline symlink"
				rm "$ccline_target"
				ln -s "$ccline_source" "$ccline_target"
			fi
		elif [[ -d "$ccline_target" ]]; then
			if $CREATE_BACKUPS; then
				local backup="${ccline_target}.backup.$(date +%Y%m%d_%H%M%S)"
				log_info "  Backing up existing ccline/ to $(basename "$backup")"
				mv "$ccline_target" "$backup"
			else
				log_debug "Removing existing ccline directory"
				rm -rf "$ccline_target"
			fi
			ln -s "$ccline_source" "$ccline_target"
		else
			log_debug "Creating ccline symlink"
			ln -s "$ccline_source" "$ccline_target"
		fi
	fi

	# Note: Global MCP servers are now added via `claude mcp add` commands
	# See setup_mcp_servers() function below

	# Symlink .mcp directory for memory.json
	local mcp_dir_source="$SCRIPT_DIR/.mcp"
	local mcp_dir_target="$target_claude/.mcp"

	if [[ -d "$mcp_dir_source" ]]; then
		if [[ -L "$mcp_dir_target" ]]; then
			if [[ "$(readlink "$mcp_dir_target")" == "$mcp_dir_source" ]]; then
				log_debug ".mcp directory symlink already correct"
			else
				log_debug "Removing incorrect .mcp directory symlink"
				rm "$mcp_dir_target"
				ln -s "$mcp_dir_source" "$mcp_dir_target"
			fi
		elif [[ -d "$mcp_dir_target" ]]; then
			if $CREATE_BACKUPS; then
				local backup="${mcp_dir_target}.backup.$(date +%Y%m%d_%H%M%S)"
				log_info "  Backing up existing .mcp/ to $(basename "$backup")"
				mv "$mcp_dir_target" "$backup"
			else
				log_debug "Removing existing .mcp directory"
				rm -rf "$mcp_dir_target"
			fi
			ln -s "$mcp_dir_source" "$mcp_dir_target"
		else
			log_debug "Creating .mcp directory symlink"
			ln -s "$mcp_dir_source" "$mcp_dir_target"
		fi
	fi

	log_info "✅ Claude Code configuration linked successfully"
}

# Setup global MCP servers using `claude mcp add`
setup_mcp_servers() {
	local mcp_global_config="$SCRIPT_DIR/.mcp/global.json"

	log_info "📡 Setting up global MCP servers"

	# Check if claude CLI is available
	if ! command -v claude &>/dev/null; then
		log_warn "Claude Code CLI not found - skipping MCP server setup"
		log_info "   Install Claude Code from: https://docs.claude.com/en/docs/claude-code/installation"
		return 0
	fi

	# Check if jq is available for JSON parsing
	if ! command -v jq &>/dev/null; then
		log_error "jq is required for MCP server setup but not found"
		log_info "   Install with: sudo apt install jq (Ubuntu/Debian) or brew install jq (macOS)"
		return 1
	fi

	# Check if global.json exists
	if [[ ! -f "$mcp_global_config" ]]; then
		log_warn "Global MCP config not found: $mcp_global_config"
		return 0
	fi

	# Parse and add each MCP server
	local server_names
	server_names=$(jq -r '.mcpServers | keys[]' "$mcp_global_config")

	for server_name in $server_names; do
		log_debug "Processing MCP server: $server_name"

		# Extract server configuration
		local command
		command=$(jq -r ".mcpServers.\"$server_name\".command" "$mcp_global_config")

		local args_json
		args_json=$(jq -c ".mcpServers.\"$server_name\".args // []" "$mcp_global_config")

		local env_json
		env_json=$(jq -c ".mcpServers.\"$server_name\".env // {}" "$mcp_global_config")

		# Build the claude mcp add command
		# Syntax: claude mcp add --transport stdio --scope user <name> [--env KEY=value] -- <command> <args...>
		local cmd_args=("claude" "mcp" "add" "--transport" "stdio" "--scope" "user" "$server_name")

		# Add environment variables (before the --)
		if [[ "$env_json" != "{}" ]]; then
			local env_keys
			env_keys=$(echo "$env_json" | jq -r 'keys[]')
			for key in $env_keys; do
				local value
				value=$(echo "$env_json" | jq -r ".$key")
				cmd_args+=("--env" "$key=$value")
			done
		fi

		# Add the separator
		cmd_args+=("--")

		# Add command
		cmd_args+=("$command")

		# Add command arguments (after the --)
		if [[ "$args_json" != "[]" ]]; then
			local args_count
			args_count=$(echo "$args_json" | jq 'length')
			for ((i = 0; i < args_count; i++)); do
				local arg
				arg=$(echo "$args_json" | jq -r ".[$i]")
				cmd_args+=("$arg")
			done
		fi

		# Execute the command
		log_info "  Adding MCP server: $server_name"
		log_debug "    Command: ${cmd_args[*]}"
		if "${cmd_args[@]}"; then
			log_debug "    ✓ Successfully added $server_name"
		else
			log_error "    ✗ Failed to add $server_name"
		fi
	done

	log_info "✅ Global MCP servers setup completed"
}

# Setup Claude Code plugins
setup_claude_plugins() {
	log_info "🔌 Setting up Claude Code plugins"

	# Check if claude CLI is available
	if ! command -v claude &>/dev/null; then
		log_warn "Claude Code CLI not found - skipping plugin installation"
		log_info "   Install Claude Code from: https://docs.claude.com/en/docs/claude-code/installation"
		return 0
	fi

	# Ask user if they want to install plugins
	if $ASSUME_YES || ask_yes_no "Would you like to install Claude Code plugins?"; then
		local plugin_script="$HOME/.claude/setup-plugins.sh"

		if [[ -x "$plugin_script" ]]; then
			log_info "Running plugin installation script..."
			if bash "$plugin_script"; then
				log_info "✅ Claude Code plugins installed successfully"
			else
				log_error "Failed to install some Claude Code plugins"
				log_info "   You can manually run: $plugin_script"
			fi
		else
			log_warn "Plugin setup script not found or not executable"
			log_info "   Expected location: $plugin_script"
		fi
	else
		log_info "Skipping Claude Code plugin installation"
		log_info "   You can manually run: ~/.claude/setup-plugins.sh"
	fi
}

# Main Claude Code setup function
setup_claude() {
	setup_claude_config
	setup_mcp_servers
	setup_claude_plugins
}
