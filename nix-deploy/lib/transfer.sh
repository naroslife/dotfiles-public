#!/usr/bin/env bash
#
# transfer.sh - SSH transfer operations for nix-deploy using nix copy
#

# Current phase
export CURRENT_PHASE="transfer"

# Transfer closure and scripts to remote using nix copy
transfer_to_remote() {
	local build_result="$1"

	if [[ ! -e "$build_result" ]]; then
		log_error "Build result not found: $build_result"
		return 1
	fi

	log_info "Starting deployment to remote using nix copy"

	# Get connection details
	local host=$(get_config_value "connection.host")
	local port=$(get_config_value "connection.port" "22")
	local user=$(get_config_value "connection.user")
	local identity_file=$(get_config_value "connection.identity_file")
	local proxy_jump=$(get_config_value "connection.proxy_jump")

	# Remote paths
	local remote_temp=$(get_config_value "deployment.paths.temp_dir" "/tmp/nix-deploy")

	# Build SSH command options
	local ssh_opts="-p $port"

	if [[ -n "$identity_file" ]]; then
		ssh_opts="$ssh_opts -i $(eval echo "$identity_file")"
	fi

	if [[ -n "$proxy_jump" ]]; then
		ssh_opts="$ssh_opts -J $proxy_jump"
	fi

	# Enable SSH multiplexing for performance
	if $(get_config_value "deployment.ssh.control_master" "true"); then
		local control_path="/tmp/nix-deploy-ssh-%r@%h:%p"
		ssh_opts="$ssh_opts -o ControlMaster=auto -o ControlPath=$control_path"
		ssh_opts="$ssh_opts -o ControlPersist=$(get_config_value "deployment.ssh.control_persist" "10m")"
	fi

	# Connection timeout
	local timeout=$(get_config_value "deployment.ssh.connection_timeout" "30")
	ssh_opts="$ssh_opts -o ConnectTimeout=$timeout"

	# Keep alive
	local keepalive=$(get_config_value "deployment.ssh.keepalive_interval" "60")
	ssh_opts="$ssh_opts -o ServerAliveInterval=$keepalive"

	log_debug "SSH options: $ssh_opts"

	# SCP requires -P (uppercase) for port, while SSH uses -p (lowercase)
	# Convert ssh_opts to scp_opts by replacing -p with -P
	local scp_opts="${ssh_opts/-p /-P }"

	# Full remote connection string
	local remote="$user@$host"

	# Step 0: VPN Connection Check (before first SSH attempt)
	local vpn_check=$(get_config_value "deployment.ssh.vpn_check" "true")
	if $INTERACTIVE && [[ "$vpn_check" == "true" ]]; then
		print_step "Preparing to connect to remote..."
		log_info ""
		log_info "⚠️  VPN CONNECTION CHECK"
		log_info ""
		log_info "If the remote host requires VPN access, please ensure:"
		log_info "  1. Your VPN client is connected"
		log_info "  2. You can reach the remote network"
		log_info ""
		log_info "Remote host: $host"
		log_info ""

		# Prompt for confirmation
		echo -n "Is your VPN connected and ready? [y/N] "
		read -r vpn_response

		if [[ ! "$vpn_response" =~ ^[Yy] ]]; then
			log_warn "Deployment paused by user"
			log_info ""
			log_info "Please connect to your VPN and run the command again."
			log_info ""
			log_info "To skip this check:"
			log_info "  - Use --non-interactive mode, or"
			log_info "  - Set deployment.ssh.vpn_check: false in config"
			return 1
		fi

		log_info "Proceeding with deployment..."
		log_info ""
	fi

	# Step 1: Create remote directory
	print_step "Creating remote directory..."
	if ! ssh $ssh_opts "$remote" "mkdir -p $remote_temp"; then
		log_error "Failed to create remote directory"
		log_error ""
		log_error "This could indicate:"
		log_error "  - VPN is not connected"
		log_error "  - Hostname is incorrect: $host"
		log_error "  - SSH access is denied"
		log_error "  - Network connectivity issues"
		return 1
	fi

	# Step 2: Detect remote platform
	print_step "Detecting remote platform..."
	local platform_info
	# Preserve stderr for debug/error logging
	platform_info=$(detect_remote_platform "$remote" "$ssh_opts" 2>&2)
	if [[ -z "$platform_info" ]]; then
		log_error "Failed to detect remote platform"
		return 1
	fi
	log_info "Remote platform: $platform_info"

	# Step 3: Check if Nix is installed on remote
	print_step "Checking for Nix installation on remote..."
	if ssh $ssh_opts "$remote" "command -v nix >/dev/null 2>&1"; then
		log_info "Nix is already installed on remote"
		local nix_installed=true
	else
		log_warn "Nix not found on remote, will install first"
		local nix_installed=false
	fi

	# Step 4: If Nix not installed, transfer installer and install
	if ! $nix_installed; then
		print_step "Preparing Nix installer..."

		# Download installer if needed
		local installer_path
		installer_path=$(download_determinate_installer)
		if [[ -z "$installer_path" ]]; then
			log_error "Failed to download Determinate Nix installer"
			return 1
		fi

		# Transfer installer script
		print_step "Transferring Nix installer to remote..."
		if ! scp $scp_opts "$installer_path" "$remote:$remote_temp/nix-installer.sh"; then
			log_error "Failed to transfer Nix installer"
			return 1
		fi

		# Transfer install-nix.sh script
		if ! scp $scp_opts "$REMOTE_DIR/install-nix.sh" "$remote:$remote_temp/install-nix.sh"; then
			log_error "Failed to transfer install-nix.sh"
			return 1
		fi

		# Install Nix on remote
		print_step "Installing Nix on remote..."
		log_info "This may take a few minutes..."
		# Use -t to allocate pseudo-TTY for sudo password prompt
		if ! ssh -t $ssh_opts "$remote" "cd $remote_temp && bash ./install-nix.sh"; then
			log_error "Failed to install Nix on remote"
			return 1
		fi
		log_info "Nix installed successfully on remote"
	fi

	# Step 5: Get store path
	local store_path=$(readlink -f "$build_result")
	log_info "Store path to transfer: $store_path"

	# Step 6: Transfer closure using nix copy
	print_step "Transferring closure using nix copy..."
	log_info "This transfers only missing store paths (efficient incremental updates)"

	# Build nix copy command
	local nix_copy_dest="ssh://$remote"
	if [[ "$port" != "22" ]]; then
		# nix copy uses ssh-ng:// protocol which supports port in the URI
		nix_copy_dest="ssh-ng://$user@$host:$port"
	fi

	# Set SSH options for nix copy via NIX_SSHOPTS
	export NIX_SSHOPTS="$ssh_opts"

	log_debug "Running: nix copy --to '$nix_copy_dest' '$store_path'"

	if ! nix copy --to "$nix_copy_dest" "$store_path"; then
		log_error "Failed to transfer closure with nix copy"
		log_error "This could be due to:"
		log_error "  - SSH connection issues"
		log_error "  - Nix not properly installed on remote"
		log_error "  - Insufficient disk space on remote"
		return 1
	fi

	log_info "Closure transferred successfully"

	# Step 7: Transfer activation scripts
	print_step "Transferring activation scripts..."
	local scripts=(
		"$REMOTE_DIR/activate-profile.sh"
		"$REMOTE_DIR/setup-shell.sh"
		"$REMOTE_DIR/validate.sh"
	)

	for script in "${scripts[@]}"; do
		if [[ -f "$script" ]]; then
			if ! scp $scp_opts "$script" "$remote:$remote_temp/$(basename "$script")"; then
				log_warn "Failed to transfer $(basename "$script") (non-fatal)"
			fi
		fi
	done

	# Step 8: Generate metadata file
	print_step "Generating deployment metadata..."
	if ! generate_metadata "$remote" "$ssh_opts" "$remote_temp" "$store_path"; then
		log_warn "Failed to generate metadata (non-fatal)"
	fi

	# Step 9: Generate instructions for user
	print_step "Generating deployment instructions..."
	if ! generate_instructions "$remote" "$ssh_opts" "$remote_temp" "$store_path"; then
		log_warn "Failed to generate instructions (non-fatal)"
	fi

	log_info "Transfer completed successfully"
	log_info ""
	log_info "===== NEXT STEPS ====="
	log_info "SSH to the remote machine and complete the deployment:"
	log_info ""
	log_info "  ssh $remote"
	log_info "  cd $remote_temp"
	log_info "  cat INSTRUCTIONS.md"
	log_info ""
	log_info "Then follow the instructions in INSTRUCTIONS.md"
	log_info "======================"

	return 0
}

# Download Determinate Nix installer script to cache
download_determinate_installer() {
	local cache_dir="${HOME}/.config/nix-deploy/cache"
	local cached_installer="${cache_dir}/nix-installer.sh"
	local installer_url="https://install.determinate.systems/nix"

	mkdir -p "$cache_dir"

	# Check if cached installer exists and is recent (less than 7 days old)
	if [[ -f "$cached_installer" ]]; then
		local file_age=$(($(date +%s) - $(stat -c %Y "$cached_installer")))
		local max_age=$((7 * 24 * 60 * 60)) # 7 days in seconds

		if [[ $file_age -lt $max_age ]]; then
			log_info "Using cached Determinate Nix installer (age: $((file_age / 86400)) days)"
			echo "$cached_installer"
			return 0
		else
			log_info "Cached installer is stale, downloading fresh copy"
		fi
	fi

	# Download installer script
	log_info "Downloading Determinate Nix installer from: $installer_url"

	if command_exists curl; then
		if curl --insecure -L -f -o "$cached_installer" "$installer_url"; then
			chmod +x "$cached_installer"
			log_info "Installer downloaded and cached: $cached_installer"
			echo "$cached_installer"
			return 0
		fi
	elif command_exists wget; then
		if wget -O "$cached_installer" "$installer_url"; then
			chmod +x "$cached_installer"
			log_info "Installer downloaded and cached: $cached_installer"
			echo "$cached_installer"
			return 0
		fi
	else
		log_error "Neither curl nor wget available for download"
		return 1
	fi

	log_error "Failed to download Determinate Nix installer"
	return 1
}

# Detect remote platform
detect_remote_platform() {
	local remote="$1"
	local ssh_opts="$2"

	log_debug "Detecting remote platform"

	# Inline platform detection via SSH
	# This captures OS, distribution, WSL status, and architecture
	local platform_script='
	set -euo pipefail

	# Detect OS type
	os_type=$(uname -s | tr "[:upper:]" "[:lower:]")

	# Detect architecture
	arch=$(uname -m)
	case "$arch" in
		x86_64|amd64) arch="x86_64" ;;
		aarch64|arm64) arch="aarch64" ;;
	esac

	# Detect Linux distribution
	distro="unknown"
	if [[ -f /etc/os-release ]]; then
		source /etc/os-release
		distro="${ID:-unknown}"
	fi

	# Detect WSL
	is_wsl="false"
	if grep -qi microsoft /proc/version 2>/dev/null; then
		is_wsl="true"
	fi

	# Output platform information
	echo "${os_type}|${distro}|${arch}|${is_wsl}"
	'

	# Execute platform detection
	local platform_result
	platform_result=$(ssh $ssh_opts "$remote" "bash -c '$platform_script'" 2>/dev/null)

	if [[ -z "$platform_result" ]]; then
		log_error "Failed to detect remote platform"
		return 1
	fi

	# Parse result
	IFS='|' read -r os_type distro arch is_wsl <<<"$platform_result"

	# Format output
	local platform_str="$os_type/$distro ($arch)"
	if [[ "$is_wsl" == "true" ]]; then
		platform_str="$platform_str [WSL]"
	fi

	echo "$platform_str"
}

# Generate deployment metadata
generate_metadata() {
	local remote="$1"
	local ssh_opts="$2"
	local remote_temp="$3"
	local store_path="$4"

	log_debug "Generating deployment metadata"

	local profile=$(get_config_value "deployment.home_manager.profile_name")
	local system=$(get_config_value "platform.arch")

	# Create metadata JSON
	local metadata=$(
		cat <<EOF
{
  "version": "2.0.0",
  "timestamp": "$(date -Iseconds)",
  "profile": "$profile",
  "system": "$system",
  "store_path": "$store_path",
  "deployment": {
    "target": "$TARGET",
    "method": "nix-copy",
    "flake_ref": "$(get_config_value "deployment.home_manager.flake_ref")"
  }
}
EOF
	)

	# Write metadata to remote
	if ! ssh $ssh_opts "$remote" "cat > $remote_temp/metadata.json" <<<"$metadata"; then
		log_error "Failed to write metadata.json to remote"
		return 1
	fi

	log_info "Metadata generated: $remote_temp/metadata.json"
	return 0
}

# Generate deployment instructions
generate_instructions() {
	local remote="$1"
	local ssh_opts="$2"
	local remote_temp="$3"
	local store_path="$4"

	log_debug "Generating deployment instructions"

	local profile=$(get_config_value "deployment.home_manager.profile_name" "unknown")

	# Generate instructions (updated for nix copy workflow)
	local instructions="# Nix Deployment Instructions

Welcome to the nix-deploy manual deployment process!

## Deployment Summary

- Profile: $profile
- Store Path: $store_path
- Deployment Directory: $remote_temp
- Timestamp: $(date -Iseconds)
- Transfer Method: nix copy (direct store-to-store transfer)

## Step-by-Step Instructions

### Step 1: Verify Nix Installation

Check that Nix is installed and working:

\`\`\`bash
command -v nix
nix --version
\`\`\`

If Nix is installed, you should see version information.

**Note:** Nix should have been automatically installed during the transfer phase.
If you see errors, the installation may have failed. Check the output above.

### Step 2: Verify Closure Transfer

Verify that the Home Manager activation package is available:

\`\`\`bash
ls -lh $store_path
\`\`\`

You should see the store path with your Home Manager configuration.

**How it works:** The \`nix copy\` command transferred the closure directly to your
Nix store via SSH. No export/import needed!

### Step 3: Activate Home Manager Profile

Activate your Home Manager configuration:

\`\`\`bash
cd $remote_temp
bash ./activate-profile.sh
\`\`\`

This will:
- Register the new profile with nix-env
- Run the Home Manager activation script
- Set up your environment according to the profile

### Step 4: Setup Shell Integration (Optional)

Add Home Manager to your shell profile:

\`\`\`bash
cd $remote_temp
bash ./setup-shell.sh
\`\`\`

This ensures your configuration persists across shell sessions.

### Step 5: Validate Deployment

Verify the deployment was successful:

\`\`\`bash
cd $remote_temp
bash ./validate.sh
\`\`\`

This checks:
- Nix installation
- Profile activation
- Key packages availability

### Step 6: Start Using Your Environment

Either start a new shell or source your configuration:

\`\`\`bash
# Option 1: Start new shell
exec \$SHELL

# Option 2: Source configuration
source ~/.bashrc  # or ~/.zshrc, etc.
\`\`\`

### Step 7: Cleanup (Optional)

After successful deployment, you can clean up:

\`\`\`bash
# Remove deployment files (keep metadata for reference)
rm -f $remote_temp/*.sh $remote_temp/INSTRUCTIONS.md

# Optional: Clean old Nix generations
nix-collect-garbage -d
\`\`\`

## What's Different: nix copy vs Traditional Method

### Old Method (Export/Import):
1. Export closure to NAR file (2-5 minutes)
2. Compress NAR file
3. Transfer compressed file via scp
4. Decompress on remote (2-5 minutes)
5. Import into Nix store

### New Method (nix copy):
1. ✅ Direct store-to-store transfer via SSH
2. ✅ Only transfers missing paths (incremental)
3. ✅ Faster: No export/compress/decompress steps
4. ✅ More efficient: Saves 4-10 minutes per deployment

## Troubleshooting

### Nix Not Found

If Nix commands aren't found, source the Nix environment:

\`\`\`bash
source ~/.nix-profile/etc/profile.d/nix.sh
\`\`\`

Or check the installation output for errors.

### Store Path Not Found

If the store path doesn't exist, the nix copy transfer may have failed.
Check the output from the deployment command for errors.

You can manually verify with:

\`\`\`bash
nix-store --verify --check-contents
\`\`\`

### Profile Activation Fails

- Verify store path exists: \`ls $store_path\`
- Check for activation script: \`ls $store_path/activate\`
- Try sourcing Nix environment first
- Review activate-profile.sh output for specific errors

### SSH Connection Issues

If you see SSH-related errors during nix copy:
- Verify SSH access: \`ssh localhost\` (should work without password)
- Check SSH multiplexing: \`ls /tmp/nix-deploy-ssh-*\`
- Review SSH configuration: \`~/.ssh/config\`

## Getting Help

If you encounter issues:

1. Check script output for error messages
2. Review logs in $remote_temp
3. Verify Nix installation: \`nix doctor\`
4. Check Nix documentation: https://nixos.org/manual/nix/stable/
5. Check nix-deploy documentation: https://github.com/naroslife/dotfiles-public/tree/main/nix-deploy

## Complete!

Once all steps succeed, your Nix environment is deployed and ready to use!

The nix copy method is significantly faster than the old export/import approach,
especially for incremental updates where most packages are already present.

Enjoy your reproducible development environment! 🎉
"

	# Write instructions to remote
	if ! ssh $ssh_opts "$remote" "cat > $remote_temp/INSTRUCTIONS.md" <<<"$instructions"; then
		log_error "Failed to write INSTRUCTIONS.md to remote"
		return 1
	fi

	log_info "Instructions generated: $remote_temp/INSTRUCTIONS.md"
	return 0
}

# Resume deployment (simplified - no packaging phase)
resume_deployment() {
	log_info "Resuming deployment"

	# Load deployment state
	if ! load_deployment_state; then
		log_error "Failed to load deployment state"
		return 1
	fi

	# Resume from appropriate phase
	case "$RESUME_PHASE" in
		build)
			log_info "Resuming from build phase"
			;;
		transfer)
			log_info "Resuming from transfer phase"
			build_result="$RESUME_BUILD_RESULT"
			;;
		*)
			log_error "Unknown resume phase: $RESUME_PHASE"
			return 1
			;;
	esac

	return 0
}

# Export functions
export -f transfer_to_remote download_determinate_installer
export -f detect_remote_platform generate_metadata
export -f generate_instructions resume_deployment
