#!/usr/bin/env bash
#
# builder.sh - Nix build operations for nix-deploy
#

# Current build phase
export CURRENT_PHASE="build"

# Build Nix environment
build_nix_environment() {
	local profile=$(get_config_value "deployment.home_manager.profile_name")
	local flake_ref=$(get_config_value "deployment.home_manager.flake_ref")
	local system=$(get_config_value "platform.arch" "x86_64")

	# Convert architecture to Nix system format
	case "$system" in
		x86_64 | amd64)
			system="x86_64-linux"
			;;
		aarch64 | arm64)
			system="aarch64-linux"
			;;
		auto)
			system="$(     detect_local_system)"
			;;
		*)
			log_error      "Unsupported architecture: $system"
			return      1
			;;
	esac

	# Expand flake reference if it starts with .
	# if [[ "$flake_ref" =~ ^\. ]]; then
	#     flake_ref="$(pwd)${flake_ref#.}"
	# fi

	log_info "Building Nix environment"
	log_info "  Profile: $profile"
	log_info "  Flake: $flake_ref"
	log_info "  System: $system"

	if $DRY_RUN; then
		print_info   "Would build: nix build $flake_ref --system $system"
		echo   "/nix/store/dry-run-build-result"
		return   0
	fi

	# Check if we're resuming and have a build result
	if $RESUME && [[ -n "${RESUME_BUILD_RESULT:-}" ]] && [[ -e "$RESUME_BUILD_RESULT" ]]; then
		log_info   "Using previous build result: $RESUME_BUILD_RESULT"
		echo   "$RESUME_BUILD_RESULT"
		return   0
	fi

	local out_link="$TEMP_DIR/build-result"

	# Build command with progress
	local build_cmd=(
		nix build
		"$flake_ref"
		--system "$system"
		--impure
		--out-link "$out_link"
	)

	# Add build options from config
	local jobs=$(get_config_value "deployment.build.jobs" "8")
	build_cmd+=(--max-jobs "$jobs")

	if $(get_config_value "deployment.build.keep_failed" "false"); then
		build_cmd+=(--keep-failed)
	fi

	# Add extra build arguments
	local extra_args=$(get_config_value "deployment.build.extra_args" "")
	if [[ -n "$extra_args" ]]; then
		# shellcheck disable=SC2206
		build_cmd+=($extra_args)
	fi

	log_debug "Build command: ${build_cmd[*]}"

	# Execute build
	print_step "Building Nix environment (this may take a while)..."

	local build_log="$TEMP_DIR/build.log"
	# Redirect all build output to stderr and log file, only return value goes to stdout
	{
		"${build_cmd[@]}" 2>&1 | tee "$build_log"
	} >&2

	local build_status=$?
	if [[ $build_status -eq 0 ]]; then
		local   build_result=$(readlink -f "$out_link")
		log_info   "Build successful: $build_result"

		# Calculate and log closure size
		local   closure_size
		closure_size=$(  calculate_closure_size "$build_result")
		log_info   "Closure size: $(human_size "$closure_size")"

		# Save build result for potential resume
		echo   "$build_result" >"$TEMP_DIR/build-result.path"

		# Only output: the store path (for command substitution capture)
		echo   "$build_result"
		return   0
	else
		log_error   "Build failed. Check log: $build_log"
		return   1
	fi
}

# Detect local system architecture
detect_local_system() {
	local arch=$(uname -m)

	case "$arch" in
		x86_64 | amd64)
			echo      "x86_64-linux"
			;;
		aarch64 | arm64)
			echo      "aarch64-linux"
			;;
		*)
			log_error      "Unsupported local architecture: $arch"
			echo      "x86_64-linux"  # Default fallback
			;;
	esac
}

# Calculate closure size
calculate_closure_size() {
	local store_path="$1"

	if [[ ! -e "$store_path" ]]; then
		log_error   "Store path does not exist: $store_path"
		echo   "0"
		return   1
	fi

	# Use nix path-info to get size
	local size
	size=$(nix path-info -S "$store_path" 2>/dev/null | awk '{sum+=$2} END {print sum}')

	if [[ -z "$size" ]]; then
		# Fallback to du
		size=$(  du -sb "$store_path" | awk '{print $1}')
	fi

	echo "${size:-0}"
}

# Query closure paths
query_closure_paths() {
	local store_path="$1"

	if [[ ! -e "$store_path" ]]; then
		log_error   "Store path does not exist: $store_path"
		return   1
	fi

	# Query all dependencies
	nix-store -qR "$store_path"
}

# Check if cross-compilation is needed
check_cross_compilation() {
	local target_system="$1"
	local local_system
	local_system=$(detect_local_system)

	if [[ "$target_system" != "$local_system" ]]; then
		log_info   "Cross-compilation required: $local_system -> $target_system"
		return   0
	else
		log_info   "Building for native system: $local_system"
		return   1
	fi
}

# Verify build output
verify_build_output() {
	local build_result="$1"

	if [[ ! -e "$build_result" ]]; then
		log_error   "Build result does not exist: $build_result"
		return   1
	fi

	# Check if it's a valid store path
	if [[ ! "$build_result" =~ ^/nix/store/ ]]; then
		log_error   "Invalid store path: $build_result"
		return   1
	fi

	# Check if it's an activation package
	if [[ ! -x "$build_result/activate" ]]; then
		log_warn   "Build result may not be an activation package (no activate script)"
	fi

	log_info "Build output verified: $build_result"
	return 0
}

# Build offline Nix installer
build_nix_installer() {
	local nix_version=$(get_config_value "deployment.nix.version" "2.18.1")
	local installer_path="$TEMP_DIR/nix-installer.tar.gz"

	log_info "Building offline Nix installer for version $nix_version"

	if $DRY_RUN; then
		print_info   "Would build Nix installer: $nix_version"
		echo   "$installer_path"
		return   0
	fi

	# Check if installer already exists in cache
	local cached_installer="$CACHE_DIR/nix-installer-${nix_version}.tar.gz"
	if [[ -f "$cached_installer" ]]; then
		log_info   "Using cached Nix installer: $cached_installer"
		cp   "$cached_installer" "$installer_path"
		echo   "$installer_path"
		return   0
	fi

	# Create installer package
	local installer_dir="$TEMP_DIR/nix-installer"
	mkdir -p "$installer_dir"

	# Download Nix binary tarball
	local nix_url="https://releases.nixos.org/nix/nix-${nix_version}/nix-${nix_version}-$(uname -m)-linux.tar.xz"
	local nix_tarball="$installer_dir/nix.tar.xz"

	log_info "Downloading Nix binary from: $nix_url"
	if ! curl --insecure -L -o "$nix_tarball" "$nix_url"; then
		log_error   "Failed to download Nix binary"
		return   1
	fi

	# Create installer script
	cat >"$installer_dir/install-nix.sh" <<'INSTALLER_EOF'
#!/usr/bin/env bash
# Offline Nix installer

set -euo pipefail

NIX_VERSION="@@NIX_VERSION@@"
INSTALL_TYPE="${1:-single-user}"

echo "Installing Nix $NIX_VERSION ($INSTALL_TYPE)"

# Extract Nix binary
tar -xf nix.tar.xz

# Run Nix installer
if [[ "$INSTALL_TYPE" == "single-user" ]]; then
    ./nix-*/install --no-daemon
else
    ./nix-*/install --daemon
fi

# Disable substituters for offline use
mkdir -p ~/.config/nix
echo "substituters = " >> ~/.config/nix/nix.conf
echo "require-sigs = false" >> ~/.config/nix/nix.conf

echo "Nix installation complete"
INSTALLER_EOF

	# Replace version placeholder
	sed -i "s/@@NIX_VERSION@@/$nix_version/g" "$installer_dir/install-nix.sh"
	chmod +x "$installer_dir/install-nix.sh"

	# Package installer
	tar -czf "$installer_path" -C "$installer_dir" .

	# Cache for future use
	cp "$installer_path" "$cached_installer"

	log_info "Nix installer created: $installer_path"
	echo "$installer_path"
}

# Export functions
export -f build_nix_environment detect_local_system
export -f calculate_closure_size query_closure_paths
export -f check_cross_compilation verify_build_output
export -f build_nix_installer
