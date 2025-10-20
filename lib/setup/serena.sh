#!/usr/bin/env bash
# Serena MCP Server Setup Module
#
# This module handles the setup of Serena global configuration.

# Source common utilities
_SERENA_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$_SERENA_MODULE_DIR/../common.sh"

# Setup Serena global configuration
setup_serena_config() {
	local serena_config_source="$SCRIPT_DIR/.serena/serena_config.yml"
	local serena_config_dir="$HOME/.serena"
	local serena_config_target="$serena_config_dir/serena_config.yml"

	log_info "🔧 Setting up Serena global configuration"

	# Create .serena directory if it doesn't exist
	if [[ ! -d "$serena_config_dir" ]]; then
		log_debug "Creating ~/.serena directory"
		mkdir -p "$serena_config_dir"
	fi

	# Check if source config exists
	if [[ ! -f "$serena_config_source" ]]; then
		log_warn "Serena config template not found: $serena_config_source"
		return 0
	fi

	# Handle existing config
	if [[ -f "$serena_config_target" ]]; then
		# Config exists - merge the web_dashboard_open_on_launch setting
		log_debug "Existing Serena config found - updating web_dashboard_open_on_launch setting"

		# Check if setting already exists
		if grep -q "^web_dashboard_open_on_launch:" "$serena_config_target" 2>/dev/null; then
			# Update existing setting
			if grep -q "^web_dashboard_open_on_launch: false" "$serena_config_target" 2>/dev/null; then
				log_debug "web_dashboard_open_on_launch already set to false"
			else
				log_info "Updating web_dashboard_open_on_launch to false"
				sed -i 's/^web_dashboard_open_on_launch:.*$/web_dashboard_open_on_launch: false/' "$serena_config_target"
			fi
		else
			# Add setting after web_dashboard line
			log_info "Adding web_dashboard_open_on_launch: false to Serena config"
			sed -i '/^web_dashboard:/a web_dashboard_open_on_launch: false' "$serena_config_target"
		fi

		log_info "✅ Serena configuration updated"
	else
		# No config exists - run serena to initialize it
		log_info "No Serena config found - initializing with Serena..."

		# Check if uvx is available
		if ! command -v uvx >/dev/null 2>&1; then
			log_warn "uvx not found - cannot initialize Serena config"
			log_info "   Install uv, then run: ./apply.sh again"
			return 0
		fi

		# Initialize Serena config by running a simple command (creates config on first run)
		log_debug "Running serena to initialize configuration"
		# Run with --help to avoid any interactive prompts
		if uvx --from git+https://github.com/oraios/serena serena --help >/dev/null 2>&1; then
			# Config should now exist - update the setting
			if [[ -f "$serena_config_target" ]]; then
				log_info "Serena config initialized - setting web_dashboard_open_on_launch=false"
				if grep -q "^web_dashboard_open_on_launch:" "$serena_config_target" 2>/dev/null; then
					sed -i 's/^web_dashboard_open_on_launch:.*$/web_dashboard_open_on_launch: false/' "$serena_config_target"
				else
					sed -i '/^web_dashboard:/a web_dashboard_open_on_launch: false' "$serena_config_target"
				fi
				log_info "✅ Serena configuration created and updated"
			else
				log_warn "Serena config not created - will be created on first Serena use"
			fi
		else
			log_warn "Could not initialize Serena config - will be created on first Serena use"
		fi
	fi
}
