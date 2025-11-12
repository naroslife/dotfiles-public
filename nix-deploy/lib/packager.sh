#!/usr/bin/env bash
#
# packager.sh - Closure packaging for nix-deploy
#

# Current phase
export CURRENT_PHASE="package"

# Download Determinate Nix installer script to cache
download_determinate_installer() {
	local cache_dir="${HOME}/.config/nix-deploy/cache"
	local cached_installer="${cache_dir}/nix-installer.sh"
	local installer_url="https://install.determinate.systems/nix"

	mkdir -p "$cache_dir"

	# Check if cached installer exists and is recent (less than 7 days old)
	if [[ -f "$cached_installer" ]]; then
		local file_age=$(($( date +%s) - $(stat -c %Y "$cached_installer")))
		local max_age=$((7 * 24 * 60 * 60))  # 7 days in seconds

		if [[ $file_age -lt $max_age ]]; then
			log_info    "Using cached Determinate Nix installer (age: $((file_age / 86400)) days)"
			echo    "$cached_installer"
			return    0
		else
			log_info    "Cached installer is stale, downloading fresh copy"
		fi
	fi

	# Download installer script
	print_step "Downloading Determinate Nix installer..."
	log_info "Fetching from: $installer_url"

	if command_exists curl; then
		if curl -L -f -o "$cached_installer" "$installer_url"; then
			chmod    +x "$cached_installer"
			log_info    "Installer downloaded and cached: $cached_installer"
			echo    "$cached_installer"
			return    0
		fi
	elif command_exists wget; then
		if wget -O "$cached_installer" "$installer_url"; then
			chmod    +x "$cached_installer"
			log_info    "Installer downloaded and cached: $cached_installer"
			echo    "$cached_installer"
			return    0
		fi
	else
		log_error "Neither curl nor wget available for download"
		return 1
	fi

	log_error "Failed to download Determinate Nix installer"
	return 1
}

# Package closure for transfer
package_closure() {
	local build_result="$1"

	if [[ ! -e "$build_result" ]]; then
		log_error "Build result not found: $build_result"
		return 1
	fi

	log_info "Packaging closure for transfer"

	if $DRY_RUN; then
		print_info "Would package closure: $build_result"
		echo "$TEMP_DIR/closure-package.tar.zst"
		return 0
	fi

	# Check if we're resuming and have a package
	if $RESUME && [[ -n "${RESUME_PACKAGE_PATH:-}" ]] && [[ -f "$RESUME_PACKAGE_PATH" ]]; then
		log_info "Using previous package: $RESUME_PACKAGE_PATH"
		echo "$RESUME_PACKAGE_PATH"
		return 0
	fi

	local package_dir="$TEMP_DIR/package"
	mkdir -p "$package_dir"

	# Step 1: Query closure paths
	print_step "Querying closure dependencies..."
	local closure_list="$package_dir/closure.list"
	if ! query_closure_paths "$build_result" >"$closure_list"; then
		log_error "Failed to query closure paths"
		return 1
	fi

	local num_paths=$(wc -l <"$closure_list")
	log_info "Closure contains $num_paths store paths"

	# Step 2: Export closure to NAR
	print_step "Exporting Nix store closure..."
	local nar_file="$package_dir/closure.nar"
	local compression=$(get_config_value "deployment.transfer.compression" "zstd")
	local compression_level=$(get_config_value "deployment.transfer.compression_level" "19")

	# Export with progress
	local total_size
	total_size=$(calculate_closure_size "$build_result")
	log_info "Total closure size: $(human_size "$total_size")"

	if ! export_closure "$build_result" "$nar_file" "$total_size"; then
		log_error "Failed to export closure"
		return 1
	fi

	# Step 3: Compress NAR
	print_step "Compressing closure ($(human_size "$(stat -c%s "$nar_file")"))"
	local compressed_file

	case "$compression" in
		zstd)
			compressed_file="$package_dir/closure.nar.zst"
			if    ! compress_with_zstd "$nar_file" "$compressed_file" "$compression_level"; then
				log_error       "Compression failed"
				return       1
			fi
			;;
		gzip)
			compressed_file="$package_dir/closure.nar.gz"
			if    ! compress_with_gzip "$nar_file" "$compressed_file" "$compression_level"; then
				log_error       "Compression failed"
				return       1
			fi
			;;
		none)
			compressed_file="$nar_file"
			log_info    "Skipping compression"
			;;
		*)
			log_error    "Unknown compression type: $compression"
			return    1
			;;
	esac

	# Remove uncompressed NAR to save space
	if [[ "$compressed_file" != "$nar_file" ]]; then
		rm -f "$nar_file"
	fi

	local compressed_size=$(stat -c%s "$compressed_file")
	log_info "Compressed size: $(human_size "$compressed_size") ($(((total_size - compressed_size) * 100 / total_size))% reduction)"

	# Step 4: Generate metadata
	print_step "Generating package metadata..."
	local metadata_file="$package_dir/metadata.json"
	if ! generate_package_metadata "$build_result" "$compressed_file" "$metadata_file"; then
		log_error "Failed to generate metadata"
		return 1
	fi

	# Step 5: Download and cache Determinate Nix installer
	print_step "Downloading Determinate Nix installer..."
	local installer_path
	installer_path=$(download_determinate_installer)
	if [[ -z "$installer_path" ]]; then
		log_error "Failed to download Determinate Nix installer"
		return 1
	fi
	cp "$installer_path" "$package_dir/nix-installer.sh"
	log_info "Installer included in package"

	# Step 6: Add remote deployment scripts
	print_step "Adding deployment scripts..."
	cp "$REMOTE_DIR"/*.sh "$package_dir/" 2>/dev/null || true

	# Step 7: Create final package archive
	print_step "Creating deployment package..."
	local final_package="$TEMP_DIR/nix-deploy-$(date +%Y%m%d-%H%M%S).tar"
	tar -cf "$final_package" -C "$package_dir" .

	log_info "Package created: $final_package"
	log_info "Package size: $(human_size "$(stat -c%s "$final_package")")"

	# Save package path for potential resume
	echo "$final_package" >"$TEMP_DIR/package.path"

	echo "$final_package"
}

# Export closure to NAR
export_closure() {
	local store_path="$1"
	local output="$2"
	local total_size="${3:-0}"

	log_debug "Exporting closure: $store_path -> $output"

	# Get closure paths
	local closure_paths
	closure_paths=$(nix-store -qR "$store_path")

	# Export with progress tracking
	if command_exists pv && [[ "$total_size" -gt 0 ]]; then
		# Use pv for progress
		nix-store --export $closure_paths | pv -s "$total_size" >"$output"
	else
		# No progress bar
		nix-store --export $closure_paths >"$output"
	fi

	local result=$?
	if [[ $result -eq 0 ]]; then
		log_info "Closure exported successfully"
	fi

	return $result
}

# Compress with zstd
compress_with_zstd() {
	local input="$1"
	local output="$2"
	local level="${3:-19}"

	log_debug "Compressing with zstd (level $level): $input -> $output"

	# Use all CPU cores for compression
	local threads=$(nproc)

	if command_exists pv; then
		# With progress bar
		pv "$input" | zstd -"$level" -T"$threads" -o "$output"
	else
		# Without progress bar
		zstd -"$level" -T"$threads" "$input" -o "$output"
	fi
}

# Compress with gzip
compress_with_gzip() {
	local input="$1"
	local output="$2"
	local level="${3:-9}"

	log_debug "Compressing with gzip (level $level): $input -> $output"

	if command_exists pigz; then
		# Use parallel gzip if available
		pigz -"$level" -c "$input" >"$output"
	elif command_exists pv; then
		# With progress bar
		pv "$input" | gzip -"$level" >"$output"
	else
		# Standard gzip
		gzip -"$level" -c "$input" >"$output"
	fi
}

# Generate package metadata
generate_package_metadata() {
	local store_path="$1"
	local package_file="$2"
	local output="$3"

	local profile=$(get_config_value "deployment.home_manager.profile_name")
	local system=$(get_config_value "platform.arch")
	local checksum
	checksum=$(calculate_checksum "$package_file")

	# Get closure paths
	local closure_paths
	closure_paths=$(nix-store -qR "$store_path" | jq -R . | jq -s .)

	# Get package size
	local package_size=$(stat -c%s "$package_file")

	cat >"$output" <<EOF
{
  "version": "1.0.0",
  "timestamp": "$(date -Iseconds)",
  "profile": "$profile",
  "system": "$system",
  "store_path": "$store_path",
  "closure_paths": $closure_paths,
  "package": {
    "file": "$(basename "$package_file")",
    "size": $package_size,
    "checksum": "$checksum",
    "algorithm": "sha256"
  },
  "deployment": {
    "target": "$TARGET",
    "flake_ref": "$(get_config_value "deployment.home_manager.flake_ref")"
  }
}
EOF

	log_debug "Metadata generated: $output"
}

# Split large packages into chunks
split_package() {
	local package_file="$1"
	local chunk_size=$(get_config_value "deployment.transfer.chunk_size" "100MB")

	# Convert chunk size to bytes
	local size_bytes
	case "$chunk_size" in
		*GB)
			size_bytes=$((${chunk_size%GB} * 1024 * 1024 * 1024))
			;;
		*MB)
			size_bytes=$((${chunk_size%MB} * 1024 * 1024))
			;;
		*KB)
			size_bytes=$((${chunk_size%KB} * 1024))
			;;
		*)
			size_bytes="$chunk_size"
			;;
	esac

	local package_size=$(stat -c%s "$package_file")

	if [[ $package_size -le $size_bytes ]]; then
		log_debug "Package size ($package_size) within chunk limit ($size_bytes), no splitting needed"
		echo "$package_file"
		return 0
	fi

	log_info "Splitting package into chunks of $(human_size "$size_bytes")"

	local chunk_dir="$TEMP_DIR/chunks"
	mkdir -p "$chunk_dir"

	# Split file
	split -b "$size_bytes" "$package_file" "$chunk_dir/chunk-"

	# Create manifest
	local manifest="$chunk_dir/manifest.json"
	cat >"$manifest" <<EOF
{
  "original_file": "$(basename "$package_file")",
  "original_size": $package_size,
  "chunk_size": $size_bytes,
  "chunks": [
EOF

	local first=true
	for chunk in "$chunk_dir"/chunk-*; do
		if [[ -f "$chunk" ]]; then
			local    chunk_checksum
			chunk_checksum=$(   calculate_checksum "$chunk")

			if    ! $first; then
				echo       "," >>"$manifest"
			fi
			first=false

			cat    >>"$manifest"  <<EOF
    {
      "file": "$(basename "$chunk")",
      "size": $(stat -c%s "$chunk"),
      "checksum": "$chunk_checksum"
    }
EOF
		fi
	done

	cat >>"$manifest" <<EOF

  ]
}
EOF

	echo "$chunk_dir"
}

# Verify package integrity
verify_package() {
	local package_file="$1"
	local metadata_file="$2"

	if [[ ! -f "$package_file" ]]; then
		log_error "Package file not found: $package_file"
		return 1
	fi

	if [[ ! -f "$metadata_file" ]]; then
		log_error "Metadata file not found: $metadata_file"
		return 1
	fi

	# Verify checksum
	local expected_checksum
	expected_checksum=$(jq -r '.package.checksum' "$metadata_file")
	local actual_checksum
	actual_checksum=$(calculate_checksum "$package_file")

	if [[ "$expected_checksum" != "$actual_checksum" ]]; then
		log_error "Package checksum mismatch"
		log_error "Expected: $expected_checksum"
		log_error "Actual:   $actual_checksum"
		return 1
	fi

	log_info "Package integrity verified"
	return 0
}

# Export functions
export -f download_determinate_installer
export -f package_closure export_closure
export -f compress_with_zstd compress_with_gzip
export -f generate_package_metadata split_package
export -f verify_package
