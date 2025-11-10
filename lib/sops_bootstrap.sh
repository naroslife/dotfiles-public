#!/usr/bin/env bash
# SOPS-nix Bootstrap Helper
# Automatically sets up sops-nix encryption for secrets management

# shellcheck source=lib/common.sh
if [[ -z "${COMMON_SH_LOADED:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/common.sh"
fi

# Configuration
SOPS_CONFIG_FILE=".sops.yaml"
SECRETS_DIR="secrets"
SECRETS_FILE="$SECRETS_DIR/secrets.yaml"
SECRETS_EXAMPLE="$SECRETS_DIR/secrets.yaml.example"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

# Check if sops-nix is configured in the repository
is_sops_configured() {
    [[ -f "$SOPS_CONFIG_FILE" ]] && [[ -d "$SECRETS_DIR" ]]
}

# Check if bootstrap is needed
needs_bootstrap() {
    # If no sops config, no bootstrap needed
    if ! is_sops_configured; then
        return 1
    fi

    # Check if placeholder key exists in .sops.yaml
    if grep -q "YOUR_AGE_PUBLIC_KEY_HERE\|age1234567890" "$SOPS_CONFIG_FILE" 2>/dev/null; then
        return 0
    fi

    # Check if SSH key exists
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        return 0
    fi

    # Check if secrets.yaml exists
    if [[ ! -f "$SECRETS_FILE" ]]; then
        return 0
    fi

    return 1
}

# Ensure tools are available via nix-shell
# shellcheck disable=SC2120
ensure_sops_tools() {
    if command -v ssh-to-age >/dev/null 2>&1 && \
       command -v age >/dev/null 2>&1 && \
       command -v sops >/dev/null 2>&1; then
        return 0
    fi

    log_info "🔧 Loading sops-nix tools..."

    # Re-execute this script in nix-shell with tools
    if [[ -z "${SOPS_TOOLS_LOADED:-}" ]]; then
        export SOPS_TOOLS_LOADED=1
        exec nix-shell -p ssh-to-age age sops --run "bash $0 $*"
    fi

    die "Failed to load sops-nix tools"
}

# Generate Ed25519 SSH key if needed
setup_ssh_key() {
    if [[ -f "$SSH_KEY_PATH" ]]; then
        log_info "✓ Ed25519 SSH key already exists"
        return 0
    fi

    log_info "🔑 No Ed25519 SSH key found"

    # Check if RSA key exists
    if [[ -f "$HOME/.ssh/id_rsa" ]]; then
        log_info "   Found RSA key, but sops-nix requires Ed25519"
    fi

    if $ASSUME_YES || ask_yes_no "Generate Ed25519 SSH key for sops-nix?" y; then
        log_info "Generating Ed25519 SSH key..."

        # Get user email for key
        local git_email
        git_email=$(git config --global user.email 2>/dev/null || echo "")

        if [[ -z "$git_email" ]]; then
            if $ASSUME_YES; then
                git_email="$USER@$(hostname)"
            else
                read -p "Enter email for SSH key: " -r git_email
            fi
        fi

        # Generate key without passphrase for automation
        # User can add passphrase later with: ssh-keygen -p -f ~/.ssh/id_ed25519
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "$git_email" -N ""

        log_info "✓ Ed25519 SSH key generated"
        log_info "  Public key: $SSH_KEY_PATH.pub"
        log_info "  To add passphrase later: ssh-keygen -p -f $SSH_KEY_PATH"

        return 0
    else
        log_error "Ed25519 SSH key required for sops-nix"
        log_info "Generate manually with: ssh-keygen -t ed25519 -C \"your_email@example.com\""
        return 1
    fi
}

# Extract age public key from SSH key
# Usage: get_age_public_key output_var_name
# Returns: 0 on success, 1 on failure
# Sets the output variable to the extracted age public key
get_age_public_key() {
    local -n _out_age_key=$1

    if [[ ! -f "$SSH_KEY_PATH.pub" ]]; then
        die "SSH public key not found: $SSH_KEY_PATH.pub"
    fi

    log_debug "Extracting age public key from SSH key..."
    _out_age_key=$(ssh-to-age -i "$SSH_KEY_PATH.pub" 2>/dev/null)

    if [[ -z "$_out_age_key" ]]; then
        die "Failed to extract age public key from SSH key"
    fi

    return 0
}

# Update .sops.yaml with age public key
update_sops_config() {
    local age_key="$1"

    log_info "📝 Updating .sops.yaml with your age public key..."

    # Backup existing config
    if [[ -f "$SOPS_CONFIG_FILE" ]]; then
        backup_file "$SOPS_CONFIG_FILE"
    fi

    # Check if key already exists in config
    if grep -q "$age_key" "$SOPS_CONFIG_FILE" 2>/dev/null; then
        log_info "✓ Age key already in .sops.yaml"
        return 0
    fi

    # Replace placeholder or add new key
    if grep -q "YOUR_AGE_PUBLIC_KEY_HERE\|age1234567890" "$SOPS_CONFIG_FILE" 2>/dev/null; then
        # Replace placeholder
        sed -i.bak "s/YOUR_AGE_PUBLIC_KEY_HERE/$age_key/" "$SOPS_CONFIG_FILE"
        sed -i.bak "s/age1234567890[a-z0-9]*/$age_key/" "$SOPS_CONFIG_FILE"
        rm -f "${SOPS_CONFIG_FILE}.bak"
        log_info "✓ Replaced placeholder with your age key"
    else
        # Add as new key (multi-machine scenario)
        log_warn "Adding new age key to existing configuration"
        log_warn "You may need to manually update .sops.yaml for proper formatting"
    fi
}

# Create initial encrypted secrets file
create_secrets_file() {
    if [[ -f "$SECRETS_FILE" ]]; then
        log_info "✓ Secrets file already exists"
        return 0
    fi

    log_info "🔐 Creating encrypted secrets file..."

    # Prepare initial secrets content
    local temp_secrets
    temp_secrets=$(mktemp)
    TEMP_FILES="${TEMP_FILES:-} $temp_secrets"

    # Copy example or create basic template
    if [[ -f "$SECRETS_EXAMPLE" ]]; then
        cp "$SECRETS_EXAMPLE" "$temp_secrets"
        log_debug "Using secrets.yaml.example as template"
    else
        cat > "$temp_secrets" <<'EOF'
# Secrets managed by sops-nix
# Edit with: sops secrets/secrets.yaml

api_keys:
  # Add your API keys here
  # tavily: "your-tavily-api-key"
  # morph: "your-morph-api-key"
EOF
        log_debug "Created basic secrets template"
    fi

    # Get age key for encryption
    local age_key
    get_age_public_key age_key
    log_debug "Age key extracted successfully"

    # Encrypt and create secrets file
    log_info "Encrypting secrets file..."
    log_debug "Using age key: ${age_key:0:20}...${age_key: -20}"
    log_debug "Encrypting with: SOPS_AGE_RECIPIENTS=\"$age_key\" sops -e -i $SECRETS_FILE"
    log_debug "Contents of unencrypted secrets:"
    log_debug "$(cat "$temp_secrets")"

    # Copy template to target location first (SOPS needs the file to exist in secrets/ for creation rules)
    cp "$temp_secrets" "$SECRETS_FILE"

    # Encrypt in-place
    if SOPS_AGE_RECIPIENTS="$age_key" sops -e -i "$SECRETS_FILE" 2>/dev/null; then
        log_info "✓ Created encrypted secrets file: $SECRETS_FILE"
        log_info "  Edit with: sops $SECRETS_FILE"
        return 0
    else
        log_error "Failed to create encrypted secrets file"
        rm -f "$SECRETS_FILE"  # Clean up failed attempt
        return 1
    fi
}

# Interactive wizard for adding secrets
secrets_wizard() {
    log_info "🎯 Secrets Configuration Wizard"
    echo

    if ! $ASSUME_YES; then
        log_info "The encrypted secrets file has been created."
        log_info "You can add secrets now or later."
        echo

        if ! ask_yes_no "Would you like to add secrets now?" n; then
            log_info "Skipping secrets configuration"
            log_info "Add secrets later with: sops $SECRETS_FILE"
            return 0
        fi
    fi

    # Collect common secrets
    local tavily_key=""
    local morph_key=""

    if ! $ASSUME_YES; then
        echo
        log_info "Common API keys (press Enter to skip):"
        echo

        read -p "Tavily API key: " -r tavily_key
        read -p "Morph API key: " -r morph_key
    fi

    # If no secrets provided, skip
    if [[ -z "$tavily_key" ]] && [[ -z "$morph_key" ]]; then
        log_info "No secrets provided, using template defaults"
        return 0
    fi

    # Update secrets file with provided values
    log_info "Updating secrets file..."

    # Create temp file with secrets
    local temp_secrets
    temp_secrets=$(mktemp)
    TEMP_FILES="${TEMP_FILES:-} $temp_secrets"

    cat > "$temp_secrets" <<EOF
api_keys:
$([ -n "$tavily_key" ] && echo "  tavily: \"$tavily_key\"" || echo "  # tavily: \"your-key-here\"")
$([ -n "$morph_key" ] && echo "  morph: \"$morph_key\"" || echo "  # morph: \"your-key-here\"")
EOF

    # Encrypt and replace
    local age_key
    get_age_public_key age_key

    # Copy temp file to target location first (SOPS needs the file in secrets/ for creation rules)
    cp "$temp_secrets" "$SECRETS_FILE"

    # Encrypt in-place
    if SOPS_AGE_RECIPIENTS="$age_key" sops -e -i "$SECRETS_FILE" 2>/dev/null; then
        log_info "✓ Secrets configured successfully"
    else
        log_error "Failed to update secrets file"
        return 1
    fi
}

# Main bootstrap orchestration
bootstrap_sops() {
    log_info "🔐 Starting sops-nix automatic bootstrap"
    echo

    # Check if bootstrap needed
    if ! is_sops_configured; then
        log_debug "sops-nix not configured in repository, skipping bootstrap"
        return 0
    fi

    if ! needs_bootstrap; then
        log_info "✓ sops-nix already configured"
        return 0
    fi

    # Ensure tools are available
    # shellcheck disable=SC2119
    ensure_sops_tools

    # Step 1: SSH Key
    log_info "Step 1/4: SSH Key Setup"
    if ! setup_ssh_key; then
        return 1
    fi
    echo

    # Step 2: Age Key
    log_info "Step 2/4: Age Key Extraction"
    local age_key
    get_age_public_key age_key
    log_info "✓ Age public key: ${age_key:0:20}...${age_key: -20}"
    echo

    # Step 3: Update Config
    log_info "Step 3/4: Update .sops.yaml"
    if ! update_sops_config "$age_key"; then
        return 1
    fi
    echo

    # Step 4: Create Secrets
    log_info "Step 4/4: Secrets File Setup"
    if ! create_secrets_file; then
        return 1
    fi

    # Optional: Interactive secrets wizard
    if ! $ASSUME_YES; then
        echo
        secrets_wizard
    fi

    echo
    log_info "✅ sops-nix bootstrap completed successfully!"
    echo
    log_info "📚 Next steps:"
    log_info "  • Secrets are now encrypted and ready to use"
    log_info "  • Edit secrets: sops $SECRETS_FILE"
    log_info "  • After 'apply.sh' completes, secrets will be available as environment variables"
    log_info "  • Documentation: docs/SECRETS_MANAGEMENT.md"
    echo

    return 0
}

# Export functions for use in other scripts
export -f is_sops_configured needs_bootstrap ensure_sops_tools
export -f setup_ssh_key get_age_public_key update_sops_config
export -f create_secrets_file secrets_wizard bootstrap_sops
