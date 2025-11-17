#!/usr/bin/env bash
#
# config.sh - Configuration management for nix-deploy
#

# Configuration variables
TARGET_CONFIG=""
GLOBAL_CONFIG=""
MERGED_CONFIG=""

# Initialize configuration
init_config() {
	local target="$1"
	local config_file="${2:-}"

	# Load global configuration
	GLOBAL_CONFIG="$CONFIG_DIR/config.yaml"
	if [[ ! -f "$GLOBAL_CONFIG" ]]; then
		create_default_config
	fi

	# Load target configuration
	if [[ -n "$config_file" ]] && [[ -f "$config_file" ]]; then
		TARGET_CONFIG="$config_file"
	else
		TARGET_CONFIG="$CONFIG_DIR/targets/${target}.yaml"
	fi

	if [[ ! -f "$TARGET_CONFIG" ]]; then
		if $INTERACTIVE; then
			print_warn "Target configuration not found: $TARGET_CONFIG"
			if prompt_yes_no "Would you like to create it now?" "y"; then
				create_target_config "$target"
			else
				print_error "Cannot proceed without target configuration"
				exit 1
			fi
		else
			print_error "Target configuration not found: $TARGET_CONFIG"
			exit 1
		fi
	fi

	# Merge configurations
	merge_configurations

	log_info "Configuration loaded for target: $target"
}

# Create default global configuration
create_default_config() {
	mkdir -p "$CONFIG_DIR"

	cat >"$GLOBAL_CONFIG" <<'EOF'
# Global deployment settings
deployment:
  # Default build options
  build:
    jobs: 8
    max_cpu_percent: 80
    keep_failed: false

  # Transfer options
  transfer:
    compression: zstd
    compression_level: 19
    chunk_size: "100MB"
    resume_enabled: true
    checksum_algorithm: sha256

  # SSH options
  ssh:
    control_master: true
    control_persist: "10m"
    connection_timeout: 30
    keepalive_interval: 60
    compression: true
    vpn_check: true  # Prompt to confirm VPN connection before deployment

# Default values for interactive prompts
defaults:
  shell: "bash"
EOF

	log_info "Created default global configuration: $GLOBAL_CONFIG"
}

# Create target configuration interactively
create_target_config() {
	local target="${1:-}"

	if [[ -z "$target" ]]; then
		target=$(prompt "Enter target name")
	fi

	local config_file="$CONFIG_DIR/targets/${target}.yaml"
	mkdir -p "$(dirname "$config_file")"

	print_header "Creating Target Configuration: $target"

	# Detect current profile and flake reference
	local detected_profile
	local detected_flake
	detected_profile=$(detect_current_profile)
	detected_flake=$(detect_current_flake_ref)

	# Gather configuration interactively
	local host=$(prompt "Remote host" "")
	local port=$(prompt "SSH port" "22")
	local user=$(prompt "Remote user" "$(whoami)")
	local identity_file=$(prompt "SSH identity file" "~/.ssh/id_rsa")
	local platform_type=$(select_option "Platform type:" "wsl" "ubuntu" "debian" "auto")
	local arch=$(select_option "Architecture:" "x86_64" "aarch64" "auto")

	# Use detected profile or fall back to user
	local default_profile="${detected_profile:-$user}"
	local profile=$(prompt "Nix profile name" "$default_profile")

	# Build flake reference with detected info
	local default_flake
	if [[ -n "$detected_flake" ]]; then
		# If we detected a flake path, use it
		default_flake="${detected_flake}#${profile}"
	else
		# Fall back to relative path
		default_flake=".#${profile}"
	fi
	local flake_ref=$(prompt "Flake reference" "$default_flake")

	cat >"$config_file" <<EOF
# Target identification
target:
  name: "$target"
  description: "$(prompt "Target description" "Remote Nix deployment target")"

# Connection details
connection:
  host: "$host"
  port: $port
  user: "$user"
  identity_file: "$identity_file"
  proxy_jump: "$(prompt "Proxy jump host (optional)" "")"

# Platform information
platform:
  type: "$platform_type"
  arch: "$arch"
  os_version: "auto"

# Deployment configuration
deployment:
  # Home Manager configuration
  home_manager:
    flake_ref: "$flake_ref"
    profile_name: "$profile"

  # Nix installation (used by Determinate Nix installer)
  nix:
    install_if_missing: true

  # Remote paths
  paths:
    nix_root: "/nix"
    profile_dir: "/home/$user/.nix-profile"
    state_dir: "/home/$user/.local/state/nix"
    temp_dir: "/tmp/nix-deploy"

  # WSL-specific settings (if applicable)
  wsl:
    fix_permissions: $([ "$platform_type" = "wsl" ] && echo "true" || echo "false")
    disable_interop: false
    automount_fix: $([ "$platform_type" = "wsl" ] && echo "true" || echo "false")

# Resource limits
resources:
  min_disk_space: "5GB"
  max_transfer_size: "10GB"
  transfer_timeout: 3600
EOF

	print_info "Target configuration created: $config_file"

	if prompt_yes_no "Would you like to edit the configuration?" "n"; then
		edit_target_config "$target"
	fi
}

# Edit target configuration
edit_target_config() {
	local target="$1"
	local config_file="$CONFIG_DIR/targets/${target}.yaml"

	if [[ ! -f "$config_file" ]]; then
		print_error "Target configuration not found: $config_file"
		return 1
	fi

	local editor="${EDITOR:-vim}"
	"$editor" "$config_file"
}

# List available targets
list_targets() {
	print_header "Available Targets"

	if [[ ! -d "$CONFIG_DIR/targets" ]]; then
		print_warn "No targets configured"
		return 0
	fi

	for config in "$CONFIG_DIR/targets"/*.yaml; do
		if [[ -f "$config" ]]; then
			local target_name=$(basename "$config" .yaml)
			local description=$(yq eval '.target.description // "No description"' "$config")
			local host=$(yq eval '.connection.host' "$config")
			local user=$(yq eval '.connection.user' "$config")

			printf "  ${BOLD}%-20s${RESET} %s@%s - %s\n" \
				"$target_name" "$user" "$host" "$description"
		fi
	done
}

# Show target configuration
show_target_config() {
	local target="$1"
	local config_file="$CONFIG_DIR/targets/${target}.yaml"

	if [[ ! -f "$config_file" ]]; then
		print_error "Target configuration not found: $config_file"
		return 1
	fi

	print_header "Configuration for target: $target"
	cat "$config_file"
}

# Merge global and target configurations
merge_configurations() {
	MERGED_CONFIG="$TEMP_DIR/merged-config.yaml"

	# Use yq to merge configurations (target overrides global)
	if command_exists yq; then
		yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
			"$GLOBAL_CONFIG" "$TARGET_CONFIG" >"$MERGED_CONFIG"
	else
		# Fallback: just use target config
		cp "$TARGET_CONFIG" "$MERGED_CONFIG"
	fi

	log_debug "Configurations merged to: $MERGED_CONFIG"
}

# Get configuration value
get_config_value() {
	local key="$1"
	local default="${2:-}"

	if [[ ! -f "$MERGED_CONFIG" ]]; then
		echo "$default"
		return
	fi

	local value
	value=$(yq eval ".$key // \"$default\"" "$MERGED_CONFIG" 2>/dev/null)

	if [[ "$value" == "null" ]] || [[ -z "$value" ]]; then
		echo "$default"
	else
		echo "$value"
	fi
}

# Set configuration value (for runtime updates)
set_config_value() {
	local key="$1"
	local value="$2"

	if [[ ! -f "$MERGED_CONFIG" ]]; then
		log_error "No merged configuration available"
		return 1
	fi

	yq eval ".$key = \"$value\"" -i "$MERGED_CONFIG"
	log_debug "Configuration updated: $key = $value"
}

# Validate configuration
validate_config() {
	local valid=true

	# Check required connection details
	local host=$(get_config_value "connection.host")
	if [[ -z "$host" ]]; then
		log_error "Missing required configuration: connection.host"
		valid=false
	fi

	local user=$(get_config_value "connection.user")
	if [[ -z "$user" ]]; then
		log_error "Missing required configuration: connection.user"
		valid=false
	fi

	# Check SSH connectivity (if not dry run)
	# if ! $DRY_RUN && $valid; then
	# 	if ! test_ssh_connection; then
	# 		log_warn    "SSH connection test failed"
	# 		valid=false
	# 	fi
	# fi

	# Check local flake reference
	local flake_ref=$(get_config_value "deployment.home_manager.flake_ref")
	if [[ -n "$flake_ref" ]]; then
		if ! validate_flake_ref "$flake_ref"; then
			log_warn "Flake reference validation failed: $flake_ref"
			# Not fatal, might be fixed interactively
		fi
	fi

	$valid
}

# Validate required configuration exists
validate_required_config() {
	local required=(
		"connection.host"
		"connection.user"
		"deployment.home_manager.flake_ref"
		"platform.type"
	)

	for key in "${required[@]}"; do
		local value=$(get_config_value "$key")
		if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
			log_debug "Missing required configuration: $key"
			return 1
		fi
	done

	return 0
}

# Test SSH connection
test_ssh_connection() {
	local host=$(get_config_value "connection.host")
	local port=$(get_config_value "connection.port" "22")
	local user=$(get_config_value "connection.user")
	local identity_file=$(get_config_value "connection.identity_file")
	local proxy_jump=$(get_config_value "connection.proxy_jump")

	local ssh_opts="-o ConnectTimeout=10 -o BatchMode=yes"

	if [[ -n "$identity_file" ]]; then
		ssh_opts="$ssh_opts -i $identity_file"
	fi

	if [[ -n "$proxy_jump" ]]; then
		ssh_opts="$ssh_opts -J $proxy_jump"
	fi

	log_debug "Testing SSH connection to $user@$host:$port"

	if ssh $ssh_opts -p "$port" "$user@$host" "echo 'SSH connection successful'" >/dev/null 2>&1; then
		log_info "SSH connection test successful"
		return 0
	else
		log_error "SSH connection test failed"
		return 1
	fi
}

# Validate flake reference
validate_flake_ref() {
	local flake_ref="$1"

	# Expand flake reference if it starts with .
	if [[ "$flake_ref" =~ ^\. ]]; then
		flake_ref="$(pwd)${flake_ref#.}"
	fi

	log_debug "Validating flake reference: $flake_ref"

	if nix flake show "$flake_ref" >/dev/null 2>&1; then
		log_info "Flake reference valid: $flake_ref"
		return 0
	else
		log_warn "Flake reference validation failed: $flake_ref"
		return 1
	fi
}

# Gather missing configuration interactively
gather_interactive_config() {
	print_info "Please provide missing configuration values:"

	# Connection details
	local host=$(get_config_value "connection.host")
	if [[ -z "$host" ]] || [[ "$host" == "null" ]]; then
		host=$(prompt "Remote host")
		set_config_value "connection.host" "$host"
	fi

	local user=$(get_config_value "connection.user")
	if [[ -z "$user" ]] || [[ "$user" == "null" ]]; then
		user=$(prompt "Remote user" "$(whoami)")
		set_config_value "connection.user" "$user"
	fi

	# Platform information
	local platform_type=$(get_config_value "platform.type")
	if [[ -z "$platform_type" ]] || [[ "$platform_type" == "null" ]] || [[ "$platform_type" == "auto" ]]; then
		platform_type=$(select_option "Platform type:" "wsl" "ubuntu" "debian" "auto")
		set_config_value "platform.type" "$platform_type"
	fi

	# Deployment configuration
	local flake_ref=$(get_config_value "deployment.home_manager.flake_ref")
	if [[ -z "$flake_ref" ]] || [[ "$flake_ref" == "null" ]]; then
		# Detect current setup
		local detected_profile
		local detected_flake
		detected_profile=$(detect_current_profile)
		detected_flake=$(detect_current_flake_ref)

		# Get or use detected profile
		local profile=$(get_config_value "deployment.home_manager.profile_name")
		if [[ -z "$profile" ]] || [[ "$profile" == "null" ]]; then
			profile="${detected_profile:-$user}"
		fi

		# Build default flake reference
		local default_flake
		if [[ -n "$detected_flake" ]]; then
			default_flake="${detected_flake}#${profile}"
		else
			default_flake=".#${profile}"
		fi

		flake_ref=$(prompt "Flake reference" "$default_flake")
		set_config_value "deployment.home_manager.flake_ref" "$flake_ref"
	fi

	# Validate gathered configuration
	if ! validate_required_config; then
		print_error "Still missing required configuration after interactive gathering"
		return 1
	fi

	return 0
}

# Validate all configurations
validate_all_configs() {
	print_header "Validating All Configurations"

	local all_valid=true

	# Validate global config
	if [[ -f "$GLOBAL_CONFIG" ]]; then
		if yq eval '.' "$GLOBAL_CONFIG" >/dev/null 2>&1; then
			print_info "✓ Global configuration valid"
		else
			print_error "✗ Global configuration invalid: $GLOBAL_CONFIG"
			all_valid=false
		fi
	else
		print_warn "Global configuration not found"
	fi

	# Validate each target config
	if [[ -d "$CONFIG_DIR/targets" ]]; then
		for config in "$CONFIG_DIR/targets"/*.yaml; do
			if [[ -f "$config" ]]; then
				local target_name=$(basename "$config" .yaml)
				if yq eval '.' "$config" >/dev/null 2>&1; then
					print_info    "✓ Target configuration valid: $target_name"
				else
					print_error    "✗ Target configuration invalid: $target_name"
					all_valid=false
				fi
			fi
		done
	fi

	$all_valid
}

# Detect current flake reference from active home-manager
detect_current_flake_ref() {
	local detected_ref=""

	# Method 1: Try to get from nix profile (most reliable)
	if command_exists nix; then
		# Look for home-manager in the profile list
		local profile_info
		profile_info=$(nix profile list 2>/dev/null | grep -i "home-manager" | head -1)

		if [[ -n "$profile_info" ]]; then
			# Extract flake reference from profile list output
			# Format: "0 github:nix-community/home-manager/release-24.05 - -"
			detected_ref=$(echo "$profile_info" | awk '{print $2}')
			log_debug "Detected flake ref from nix profile: $detected_ref"
		fi
	fi

	# Method 2: Check current flake.nix in pwd (where user likely is)
	if [[ -z "$detected_ref" ]] && [[ -f "$PWD/flake.nix" ]]; then
		# Check if this flake has homeConfigurations
		if nix flake show "$PWD" 2>/dev/null | grep -q "homeConfigurations"; then
			detected_ref="$PWD"
			log_debug "Detected local flake at: $detected_ref"
		fi
	fi

	# Method 3: Check for local flake.nix in standard locations
	if [[ -z "$detected_ref" ]]; then
		local flake_locations=(
			"$HOME/.config/home-manager/flake.nix"
			"$HOME/.config/nixpkgs/flake.nix"
		)

		for location in "${flake_locations[@]}"; do
			if [[ -f "$location" ]]; then
				local flake_dir
				flake_dir=$(dirname "$location")
				# Verify it has homeConfigurations
				if nix flake show "$flake_dir" 2>/dev/null | grep -q "homeConfigurations"; then
					detected_ref="$flake_dir"
					log_debug "Detected local flake at: $detected_ref"
					break
				fi
			fi
		done
	fi

	echo "$detected_ref"
}

# Detect current home-manager user/profile name
detect_current_profile() {
	local profile_name=""

	# Method 1: Extract from nix profile if available
	if command_exists nix; then
		local profile_list
		profile_list=$(nix profile list 2>/dev/null)

		# Try to find homeConfigurations.<profile> pattern
		if [[ -n "$profile_list" ]]; then
			profile_name=$(echo "$profile_list" | grep -oP 'homeConfigurations\.\K[^.#]+' | head -1)
			if [[ -n "$profile_name" ]]; then
				log_debug "Detected profile from nix profile: $profile_name"
				echo "$profile_name"
				return 0
			fi
		fi
	fi

	# Method 2: Check current flake for available profiles
	local flake_dir="${PWD}"
	if [[ -f "$flake_dir/flake.nix" ]]; then
		# Try to list homeConfigurations
		local configs
		configs=$(nix flake show "$flake_dir" 2>/dev/null | grep -A 1 "homeConfigurations" | grep "├───" | awk '{print $2}' | head -1)
		if [[ -n "$configs" ]]; then
			profile_name="$configs"
			log_debug "Detected profile from local flake: $profile_name"
			echo "$profile_name"
			return 0
		fi
	fi

	# Method 3: From USER environment variable or whoami
	if [[ -n "${USER:-}" ]]; then
		profile_name="$USER"
	elif command_exists whoami; then
		profile_name=$(whoami 2>/dev/null)
	elif [[ -n "${HOME:-}" ]]; then
		profile_name=$(basename "$HOME")
	fi

	echo "$profile_name"
}

# Get target configuration
get_target_config() {
	echo "$TARGET_CONFIG"
}

# Export functions
export -f init_config create_default_config create_target_config
export -f edit_target_config list_targets show_target_config
export -f merge_configurations get_config_value set_config_value
export -f validate_config validate_required_config
export -f test_ssh_connection validate_flake_ref
export -f gather_interactive_config validate_all_configs
export -f detect_current_flake_ref detect_current_profile
