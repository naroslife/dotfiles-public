#!/usr/bin/env bash
#
# transfer.sh - SSH transfer operations for nix-deploy
#

# Current phase
export CURRENT_PHASE="transfer"

# Transfer package to remote
transfer_to_remote() {
    local package_path="$1"

    if [[ ! -f "$package_path" ]]; then
        log_error "Package not found: $package_path"
        return 1
    fi

    log_info "Starting transfer to remote"

    # Get connection details
    local host=$(get_config_value "connection.host")
    local port=$(get_config_value "connection.port" "22")
    local user=$(get_config_value "connection.user")
    local identity_file=$(get_config_value "connection.identity_file")
    local proxy_jump=$(get_config_value "connection.proxy_jump")

    # Remote paths
    local remote_temp=$(get_config_value "deployment.paths.temp_dir" "/tmp/nix-deploy")

    # Build SSH command
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

    # Step 1: Create remote directory
    print_step "Creating remote directory..."
    if ! ssh $ssh_opts "$user@$host" "mkdir -p $remote_temp"; then
        log_error "Failed to create remote directory"
        return 1
    fi

    # Step 2: Detect remote platform
    print_step "Detecting remote platform..."
    local platform_info
    platform_info=$(detect_remote_platform "$user@$host" "$ssh_opts")
    if [[ -z "$platform_info" ]]; then
        log_error "Failed to detect remote platform"
        return 1
    fi
    log_info "Remote platform: $platform_info"

    # Step 3: Check remote disk space
    print_step "Checking remote disk space..."
    if ! check_remote_disk_space "$user@$host" "$ssh_opts" "$remote_temp"; then
        log_error "Insufficient disk space on remote"
        return 1
    fi

    # Step 4: Transfer package
    print_step "Transferring package..."
    local package_name=$(basename "$package_path")
    local remote_package="$remote_temp/$package_name"

    if $(get_config_value "deployment.transfer.resume_enabled" "true"); then
        # Use rsync for resume support
        if ! transfer_with_rsync "$package_path" "$user@$host:$remote_package" "$ssh_opts"; then
            log_error "Transfer failed"
            return 1
        fi
    else
        # Use scp for simple transfer
        if ! scp $ssh_opts "$package_path" "$user@$host:$remote_package"; then
            log_error "Transfer failed"
            return 1
        fi
    fi

    # Step 5: Verify transfer
    print_step "Verifying transfer..."
    if ! verify_remote_file "$user@$host" "$ssh_opts" "$remote_package" "$package_path"; then
        log_error "Transfer verification failed"
        return 1
    fi

    # Step 6: Extract package on remote
    print_step "Extracting package on remote..."
    if ! ssh $ssh_opts "$user@$host" "cd $remote_temp && tar -xf $package_name"; then
        log_error "Failed to extract package on remote"
        return 1
    fi

    log_info "Transfer completed successfully"
    return 0
}

# Detect remote platform
detect_remote_platform() {
    local remote="$1"
    local ssh_opts="$2"

    log_debug "Detecting remote platform"

    # Copy detection script to remote
    local detect_script="$REMOTE_DIR/detect-platform.sh"
    if [[ ! -f "$detect_script" ]]; then
        log_error "Platform detection script not found"
        return 1
    fi

    # Execute detection script
    ssh $ssh_opts "$remote" "bash -s" < "$detect_script"
}

# Check remote disk space
check_remote_disk_space() {
    local remote="$1"
    local ssh_opts="$2"
    local path="$3"

    local min_space=$(get_config_value "resources.min_disk_space" "5GB")

    # Convert to bytes
    local required_bytes
    case "$min_space" in
        *GB)
            required_bytes=$(( ${min_space%GB} * 1024 * 1024 * 1024 ))
            ;;
        *MB)
            required_bytes=$(( ${min_space%MB} * 1024 * 1024 ))
            ;;
        *KB)
            required_bytes=$(( ${min_space%KB} * 1024 ))
            ;;
        *)
            required_bytes="$min_space"
            ;;
    esac

    # Check available space
    local available
    available=$(ssh $ssh_opts "$remote" "df -B1 '$path' | tail -1 | awk '{print \$4}'")

    if [[ -z "$available" ]]; then
        log_warn "Could not determine available disk space"
        return 0  # Continue anyway
    fi

    log_info "Available disk space: $(human_size "$available")"

    if [[ $available -lt $required_bytes ]]; then
        log_error "Insufficient disk space. Required: $(human_size "$required_bytes"), Available: $(human_size "$available")"
        return 1
    fi

    return 0
}

# Transfer with rsync
transfer_with_rsync() {
    local source="$1"
    local dest="$2"
    local ssh_opts="$3"

    local rsync_opts="-avz --progress --partial"

    # Add SSH options to rsync
    rsync_opts="$rsync_opts -e 'ssh $ssh_opts'"

    # Add compression if enabled
    if $(get_config_value "deployment.ssh.compression" "true"); then
        rsync_opts="$rsync_opts -z"
    fi

    log_debug "Rsync command: rsync $rsync_opts $source $dest"

    # Execute transfer
    if eval "rsync $rsync_opts '$source' '$dest'"; then
        log_info "Transfer completed"
        return 0
    else
        log_error "Rsync transfer failed"
        return 1
    fi
}

# Verify remote file
verify_remote_file() {
    local remote="$1"
    local ssh_opts="$2"
    local remote_file="$3"
    local local_file="$4"

    # Calculate local checksum
    local local_checksum
    local_checksum=$(calculate_checksum "$local_file")

    # Calculate remote checksum
    local remote_checksum
    remote_checksum=$(ssh $ssh_opts "$remote" "sha256sum '$remote_file' | awk '{print \$1}'")

    if [[ "$local_checksum" != "$remote_checksum" ]]; then
        log_error "Checksum mismatch"
        log_error "Local:  $local_checksum"
        log_error "Remote: $remote_checksum"
        return 1
    fi

    log_info "Transfer verified successfully"
    return 0
}

# Execute remote installation
execute_remote_installation() {
    log_info "Starting remote installation"

    # Get connection details
    local host=$(get_config_value "connection.host")
    local port=$(get_config_value "connection.port" "22")
    local user=$(get_config_value "connection.user")
    local identity_file=$(get_config_value "connection.identity_file")
    local proxy_jump=$(get_config_value "connection.proxy_jump")

    # Remote paths
    local remote_temp=$(get_config_value "deployment.paths.temp_dir" "/tmp/nix-deploy")

    # Build SSH command
    local ssh_opts="-p $port"

    if [[ -n "$identity_file" ]]; then
        ssh_opts="$ssh_opts -i $(eval echo "$identity_file")"
    fi

    if [[ -n "$proxy_jump" ]]; then
        ssh_opts="$ssh_opts -J $proxy_jump"
    fi

    # Use existing SSH multiplexing connection
    if $(get_config_value "deployment.ssh.control_master" "true"); then
        local control_path="/tmp/nix-deploy-ssh-%r@%h:%p"
        ssh_opts="$ssh_opts -o ControlPath=$control_path"
    fi

    # Step 1: Check if Nix is installed
    print_step "Checking Nix installation..."
    local nix_installed=false
    if ssh $ssh_opts "$user@$host" "command -v nix >/dev/null 2>&1"; then
        nix_installed=true
        log_info "Nix is already installed"
    else
        log_info "Nix is not installed"
    fi

    # Step 2: Install Nix if needed
    if ! $nix_installed && $(get_config_value "deployment.nix.install_if_missing" "true"); then
        print_step "Installing Nix..."
        local install_type=$(get_config_value "deployment.nix.install_type" "single-user")

        # Execute Nix installer
        if ! ssh $ssh_opts "$user@$host" "cd $remote_temp && bash ./install-nix.sh $install_type"; then
            log_error "Nix installation failed"
            return 1
        fi

        # Source Nix environment
        ssh $ssh_opts "$user@$host" "source ~/.nix-profile/etc/profile.d/nix.sh"
    fi

    # Step 3: Import Nix closure
    print_step "Importing Nix closure..."
    if ! ssh $ssh_opts "$user@$host" "cd $remote_temp && bash ./import-closure.sh"; then
        log_error "Failed to import closure"
        return 1
    fi

    # Step 4: Activate Home Manager profile
    print_step "Activating Home Manager profile..."
    if ! ssh $ssh_opts "$user@$host" "cd $remote_temp && bash ./activate-profile.sh"; then
        log_error "Failed to activate profile"
        return 1
    fi

    # Step 5: Setup shell integration
    if $(get_config_value "deployment.options.setup_shell_integration" "true"); then
        print_step "Setting up shell integration..."
        if ! ssh $ssh_opts "$user@$host" "cd $remote_temp && bash ./setup-shell.sh"; then
            log_warn "Shell integration setup failed (non-fatal)"
        fi
    fi

    log_info "Remote installation completed"
    return 0
}

# Validate deployment
validate_deployment() {
    log_info "Validating deployment"

    if ! $(get_config_value "deployment.options.post_deploy_validation" "true"); then
        log_info "Post-deployment validation disabled"
        return 0
    fi

    # Get connection details
    local host=$(get_config_value "connection.host")
    local port=$(get_config_value "connection.port" "22")
    local user=$(get_config_value "connection.user")
    local identity_file=$(get_config_value "connection.identity_file")
    local proxy_jump=$(get_config_value "connection.proxy_jump")

    # Build SSH command
    local ssh_opts="-p $port"

    if [[ -n "$identity_file" ]]; then
        ssh_opts="$ssh_opts -i $(eval echo "$identity_file")"
    fi

    if [[ -n "$proxy_jump" ]]; then
        ssh_opts="$ssh_opts -J $proxy_jump"
    fi

    # Run validation script
    local remote_temp=$(get_config_value "deployment.paths.temp_dir" "/tmp/nix-deploy")
    if ! ssh $ssh_opts "$user@$host" "cd $remote_temp && bash ./validate.sh"; then
        log_error "Deployment validation failed"
        return 1
    fi

    log_info "Deployment validated successfully"
    return 0
}

# Rollback deployment
rollback_deployment() {
    log_info "Rolling back deployment"

    # Get connection details
    local host=$(get_config_value "connection.host")
    local port=$(get_config_value "connection.port" "22")
    local user=$(get_config_value "connection.user")
    local identity_file=$(get_config_value "connection.identity_file")
    local proxy_jump=$(get_config_value "connection.proxy_jump")

    # Build SSH command
    local ssh_opts="-p $port"

    if [[ -n "$identity_file" ]]; then
        ssh_opts="$ssh_opts -i $(eval echo "$identity_file")"
    fi

    if [[ -n "$proxy_jump" ]]; then
        ssh_opts="$ssh_opts -J $proxy_jump"
    fi

    # Execute rollback
    print_step "Rolling back to previous generation..."
    if ! ssh $ssh_opts "$user@$host" "nix-env --rollback"; then
        log_error "Rollback failed"
        return 1
    fi

    # Activate previous generation
    print_step "Activating previous generation..."
    if ! ssh $ssh_opts "$user@$host" "home-manager switch --rollback"; then
        log_warn "Home Manager rollback failed, trying alternative method"

        # Alternative: manually switch to previous generation
        local prev_gen
        prev_gen=$(ssh $ssh_opts "$user@$host" "nix-env --list-generations | tail -2 | head -1 | awk '{print \$1}'")

        if [[ -n "$prev_gen" ]]; then
            ssh $ssh_opts "$user@$host" "nix-env --switch-generation $prev_gen"
        fi
    fi

    log_info "Rollback completed"
    return 0
}

# Resume deployment
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
        package)
            log_info "Resuming from package phase"
            build_result="$RESUME_BUILD_RESULT"
            ;;
        transfer)
            log_info "Resuming from transfer phase"
            build_result="$RESUME_BUILD_RESULT"
            package_path="$RESUME_PACKAGE_PATH"
            ;;
        *)
            log_error "Unknown resume phase: $RESUME_PHASE"
            return 1
            ;;
    esac

    return 0
}

# Export functions
export -f transfer_to_remote detect_remote_platform
export -f check_remote_disk_space transfer_with_rsync
export -f verify_remote_file execute_remote_installation
export -f validate_deployment rollback_deployment resume_deployment