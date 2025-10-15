#!/usr/bin/env bash
# User Configuration Module
#
# This module handles interactive user data collection for dotfiles setup.
# It collects username, git configuration, and environment-specific variables.
#
# Version: 2.0.0

set -euo pipefail

# Source common utilities
# Determine the lib directory where this script resides
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
# Common.sh is in the same directory as user_config.sh
source "$LIB_DIR/common.sh"

# Configuration version for migration support
readonly CONFIG_VERSION="2.0.0"

# Configuration file paths
USER_CONFIG_FILE="${USER_CONFIG_FILE:-$HOME/.config/dotfiles/user.conf}"
USER_CONFIG_DIR="${USER_CONFIG_DIR:-$(dirname "$USER_CONFIG_FILE")}"
TEMP_CONFIG_FILE="${TEMP_CONFIG_FILE:-$(mktemp)}"

# Default values
# Note: These are intentionally empty. Actual defaults are defined in modules/defaults.nix
# This shell script only collects user preferences, Nix provides the defaults
DEFAULT_GIT_NAME=""
DEFAULT_GIT_EMAIL=""
DEFAULT_CORP_TEST_IPS=""

# Configuration structure
declare -A USER_CONFIG

# Validation patterns centralized for maintainability
declare -A VALIDATION_PATTERNS
VALIDATION_PATTERNS[username]="^[a-z_][a-z0-9_-]*$"
VALIDATION_PATTERNS[username_error]="Username must start with a letter or underscore and contain only lowercase letters, numbers, underscores, and hyphens"

VALIDATION_PATTERNS[git_name]="^.{2,}$"
VALIDATION_PATTERNS[git_name_error]="Name must be at least 2 characters long"

VALIDATION_PATTERNS[git_email]="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
VALIDATION_PATTERNS[git_email_error]="Please enter a valid email address"

VALIDATION_PATTERNS[git_signing_key]="^[A-F0-9]{16,}$"
VALIDATION_PATTERNS[git_signing_key_error]="GPG key ID must be at least 16 hexadecimal characters"

VALIDATION_PATTERNS[corp_test_ips]="^([0-9]{1,3}\.){3}[0-9]{1,3}(,([0-9]{1,3}\.){3}[0-9]{1,3})*$"
VALIDATION_PATTERNS[corp_test_ips_error]="Please enter valid IP addresses separated by commas (e.g., 192.168.1.1,10.0.0.1)"

VALIDATION_PATTERNS[proxy_url]="^https?://.*$"
VALIDATION_PATTERNS[proxy_url_error]="Proxy URL must start with http:// or https://"

VALIDATION_PATTERNS[shell]="^(bash|zsh|fish|elvish)$"
VALIDATION_PATTERNS[shell_error]="Please choose from: bash, zsh, fish, elvish"

VALIDATION_PATTERNS[editor]="^(vim|nvim|emacs|nano|code)$"
VALIDATION_PATTERNS[editor_error]="Please choose from: vim, nvim, emacs, nano, code"

VALIDATION_PATTERNS[timezone]="^[A-Z][A-Za-z_/]+$"
VALIDATION_PATTERNS[timezone_error]="Please enter a valid timezone (e.g., America/New_York, Europe/London)"

# Initialize configuration with defaults
# Note: Most defaults are now managed in modules/defaults.nix
# This just initializes the array with empty/detected values
init_user_config() {
    # Ensure array is declared
    if [[ -z "${USER_CONFIG+x}" ]]; then
        declare -gA USER_CONFIG
    fi

    USER_CONFIG[username]="$(whoami)"
    USER_CONFIG[git_name]="$DEFAULT_GIT_NAME"
    USER_CONFIG[git_email]="$DEFAULT_GIT_EMAIL"
    USER_CONFIG[corp_test_ips]="$DEFAULT_CORP_TEST_IPS"
    # Shell, editor, timezone: empty here, defaults come from modules/defaults.nix
    USER_CONFIG[shell]=""
    USER_CONFIG[editor]=""
    USER_CONFIG[timezone]=""
}

# Load existing configuration if available with version checking
load_user_config() {
    if [[ ! -f "$USER_CONFIG_FILE" ]]; then
        return 1
    fi

    log_info "Loading existing user configuration from $USER_CONFIG_FILE"

    # Load configuration in a subshell to check version first
    local file_version
    file_version=$(grep "^CONFIG_VERSION=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)

    # Handle legacy configurations without version
    if [[ -z "$file_version" ]]; then
        log_warn "Configuration file has no version. Assuming legacy format (1.0.0)"
        file_version="1.0.0"
    fi

    # Check if migration is needed
    if [[ "$file_version" != "$CONFIG_VERSION" ]]; then
        log_info "Configuration version mismatch (file: $file_version, current: $CONFIG_VERSION)"

        # Backup before migration
        local migration_backup
        migration_backup=$(backup_file "$USER_CONFIG_FILE" ".pre-migration")
        log_info "Created pre-migration backup: $migration_backup"

        # Perform migration based on version
        if migrate_config "$file_version" "$CONFIG_VERSION"; then
            log_info "Configuration migrated successfully from $file_version to $CONFIG_VERSION"
        else
            log_warn "Configuration migration failed. Using as-is."
        fi
    fi

    # Source the configuration file
    # shellcheck source=/dev/null
    if source "$USER_CONFIG_FILE" 2>/dev/null; then
        # Validate that required fields are present
        if [[ -z "${USER_CONFIG[username]:-}" ]]; then
            log_warn "Configuration missing required field: username"
            return 1
        fi
        return 0
    else
        log_error "Failed to load configuration file"
        return 1
    fi
}

# Migrate configuration between versions
migrate_config() {
    local from_version="$1"
    local to_version="$2"

    log_debug "Migrating configuration from $from_version to $to_version"

    # Version-specific migrations
    case "$from_version" in
        "1.0.0")
            # Legacy format - add version field
            log_debug "Migrating from legacy format (1.0.0)"

            # Load existing config
            # shellcheck source=/dev/null
            source "$USER_CONFIG_FILE"

            # Add version and re-save
            save_user_config
            ;;
        "2.0.0")
            # Current version - no migration needed
            log_debug "Configuration is already at current version"
            return 0
            ;;
        *)
            log_warn "Unknown configuration version: $from_version"
            return 1
            ;;
    esac

    return 0
}

# Save configuration to file with atomic operations
save_user_config() {
    log_info "Saving user configuration"

    # Create config directory if it doesn't exist
    mkdir -p "$USER_CONFIG_DIR"

    # Backup existing config if it exists
    local backup_file=""
    if [[ -f "$USER_CONFIG_FILE" ]]; then
        backup_file=$(backup_file "$USER_CONFIG_FILE" ".backup")
        log_debug "Created backup at $backup_file"
    fi

    # Create temp file with proper permissions from the start
    local temp_file
    temp_file=$(mktemp "$USER_CONFIG_DIR/.config.XXXXXX")
    chmod 600 "$temp_file"

    # Write configuration to temp file with error handling
    if ! {
        echo "# Dotfiles User Configuration"
        echo "# Version: $CONFIG_VERSION"
        echo "# Generated on: $(date)"
        echo "# This file is automatically generated. Manual edits may be overwritten."
        echo ""
        echo "# Configuration version for migration support"
        echo "CONFIG_VERSION=\"$CONFIG_VERSION\""
        echo ""

        for key in "${!USER_CONFIG[@]}"; do
            # Escape special characters in values
            local escaped_value="${USER_CONFIG[$key]}"
            escaped_value="${escaped_value//\\/\\\\}"  # Escape backslashes
            escaped_value="${escaped_value//\"/\\\"}"  # Escape quotes
            escaped_value="${escaped_value//\$/\\\$}"  # Escape dollar signs
            escaped_value="${escaped_value//\`/\\\`}"  # Escape backticks
            echo "USER_CONFIG[$key]=\"${escaped_value}\""
        done
    } > "$temp_file" 2>/dev/null; then
        # If write failed, restore from backup and clean up
        rm -f "$temp_file"
        if [[ -n "$backup_file" ]]; then
            log_error "Failed to write configuration. Backup preserved at $backup_file"
        fi
        return 1
    fi

    # Atomically move temp file to final location
    if ! mv -f "$temp_file" "$USER_CONFIG_FILE" 2>/dev/null; then
        # If move failed, restore from backup
        rm -f "$temp_file"
        if [[ -n "$backup_file" && -f "$backup_file" ]]; then
            mv "$backup_file" "$USER_CONFIG_FILE"
            log_error "Failed to save configuration. Restored from backup."
        fi
        return 1
    fi

    # Success - remove backup (keep last 3 backups)
    if [[ -n "$backup_file" ]]; then
        # Keep only the 3 most recent backups
        local backup_count
        backup_count=$(find "$USER_CONFIG_DIR" -name "$(basename "$USER_CONFIG_FILE").backup_*" 2>/dev/null | wc -l)

        if [[ $backup_count -gt 3 ]]; then
            find "$USER_CONFIG_DIR" -name "$(basename "$USER_CONFIG_FILE").backup_*" -type f -print0 2>/dev/null | \
                xargs -0 ls -t 2>/dev/null | tail -n +4 | xargs -r rm -f
            log_debug "Cleaned old backups, keeping 3 most recent"
        fi
    fi

    log_info "Configuration saved to $USER_CONFIG_FILE"
    return 0
}

# Interactive prompt with validation
prompt_with_validation() {
    local prompt_text="$1"
    local var_name="$2"
    local default_value="${3:-}"
    local validation_key="${4:-}"
    local custom_pattern="${5:-}"
    local custom_message="${6:-}"

    local input_value=""
    local display_default=""
    local validation_pattern
    local validation_message

    # Use centralized patterns if validation_key provided, otherwise use custom
    if [[ -n "$validation_key" && -n "${VALIDATION_PATTERNS[$validation_key]:-}" ]]; then
        validation_pattern="${VALIDATION_PATTERNS[$validation_key]}"
        validation_message="${VALIDATION_PATTERNS[${validation_key}_error]:-Invalid input}"
    elif [[ -n "$custom_pattern" ]]; then
        validation_pattern="$custom_pattern"
        validation_message="${custom_message:-Invalid input}"
    else
        validation_pattern=".*"
        validation_message="Invalid input"
    fi

    if [[ -n "$default_value" ]]; then
        display_default=" [$default_value]"
    fi

    local attempt=0
    while true; do
        # Show hint after first failed attempt
        if [[ $attempt -gt 0 ]]; then
            echo -e "${COLOR_CYAN}Hint: $validation_message${COLOR_NC}"
        fi

        read -p "${prompt_text}${display_default}: " -r input_value

        # Use default if no input provided
        if [[ -z "$input_value" && -n "$default_value" ]]; then
            input_value="$default_value"
        fi

        # Skip validation if input is empty and no default
        if [[ -z "$input_value" && -z "$default_value" ]]; then
            log_warn "This field is required. Please provide a value."
            ((attempt++))
            continue
        fi

        # Validate input
        if [[ "$input_value" =~ $validation_pattern ]]; then
            USER_CONFIG[$var_name]="$input_value"
            break
        else
            log_warn "$validation_message"
            ((attempt++))
        fi
    done
}

# Collect username configuration
collect_username() {
    echo
    log_info "Username Configuration"
    echo "---------------------"

    prompt_with_validation \
        "Enter your username" \
        "username" \
        "${USER_CONFIG[username]}" \
        "username"  # Use validation key
}

# Collect git configuration
collect_git_config() {
    echo
    log_info "Git Configuration"
    echo "----------------"

    # Git user name
    prompt_with_validation \
        "Enter your full name for Git commits" \
        "git_name" \
        "${USER_CONFIG[git_name]}" \
        "git_name"  # Use validation key

    # Git email
    prompt_with_validation \
        "Enter your email for Git commits" \
        "git_email" \
        "${USER_CONFIG[git_email]}" \
        "git_email"  # Use validation key

    # Git signing key (optional)
    if ask_yes_no "Do you want to configure Git commit signing?" n; then
        prompt_with_validation \
            "Enter your GPG key ID" \
            "git_signing_key" \
            "${USER_CONFIG[git_signing_key]:-}" \
            "git_signing_key"  # Use validation key
    fi
}

# Collect environment-specific configuration
collect_environment_config() {
    echo
    log_info "Environment Configuration"
    echo "------------------------"

    # Corporate test IPs (optional)
    if ask_yes_no "Do you have corporate test IPs to configure?" n; then
        prompt_with_validation \
            "Enter corporate test IPs (comma-separated)" \
            "corp_test_ips" \
            "${USER_CONFIG[corp_test_ips]}" \
            "corp_test_ips"  # Use validation key
    fi

    # Proxy configuration (optional)
    if ask_yes_no "Do you need to configure a proxy?" n; then
        prompt_with_validation \
            "Enter HTTP proxy URL" \
            "http_proxy" \
            "${USER_CONFIG[http_proxy]:-}" \
            "proxy_url"  # Use validation key

        prompt_with_validation \
            "Enter HTTPS proxy URL" \
            "https_proxy" \
            "${USER_CONFIG[https_proxy]:-${USER_CONFIG[http_proxy]}}" \
            "proxy_url"  # Use validation key

        prompt_with_validation \
            "Enter no-proxy domains (comma-separated)" \
            "no_proxy" \
            "${USER_CONFIG[no_proxy]:-localhost,127.0.0.1}" \
            "" \
            "^.+$" \
            "Please enter at least one domain"
    fi
}

# Collect shell preferences
collect_shell_preferences() {
    echo
    log_info "Shell Preferences"
    echo "----------------"

    # Default shell
    echo "Available shells: bash, zsh, fish, elvish"
    prompt_with_validation \
        "Choose your default shell" \
        "shell" \
        "${USER_CONFIG[shell]}" \
        "shell"  # Use validation key

    # Default editor
    echo "Available editors: vim, nvim, emacs, nano, code"
    prompt_with_validation \
        "Choose your default editor" \
        "editor" \
        "${USER_CONFIG[editor]}" \
        "editor"  # Use validation key

    # Timezone
    local current_tz
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
    prompt_with_validation \
        "Enter your timezone" \
        "timezone" \
        "${USER_CONFIG[timezone]:-$current_tz}" \
        "timezone"  # Use validation key
}

# Display configuration summary
show_config_summary() {
    echo
    log_info "Configuration Summary"
    echo "===================="
    echo

    # Core settings
    echo "Core Settings:"
    echo "  Username:     ${USER_CONFIG[username]}"
    echo "  Shell:        ${USER_CONFIG[shell]}"
    echo "  Editor:       ${USER_CONFIG[editor]}"
    echo "  Timezone:     ${USER_CONFIG[timezone]}"
    echo

    # Git settings
    echo "Git Settings:"
    echo "  Name:         ${USER_CONFIG[git_name]}"
    echo "  Email:        ${USER_CONFIG[git_email]}"
    if [[ -n "${USER_CONFIG[git_signing_key]:-}" ]]; then
        echo "  Signing Key:  ${USER_CONFIG[git_signing_key]}"
    fi
    echo

    # Environment settings
    if [[ -n "${USER_CONFIG[corp_test_ips]:-}" || -n "${USER_CONFIG[http_proxy]:-}" ]]; then
        echo "Environment Settings:"
        [[ -n "${USER_CONFIG[corp_test_ips]:-}" ]] && echo "  Corp Test IPs: ${USER_CONFIG[corp_test_ips]}"
        [[ -n "${USER_CONFIG[http_proxy]:-}" ]] && echo "  HTTP Proxy:    ${USER_CONFIG[http_proxy]}"
        [[ -n "${USER_CONFIG[https_proxy]:-}" ]] && echo "  HTTPS Proxy:   ${USER_CONFIG[https_proxy]}"
        [[ -n "${USER_CONFIG[no_proxy]:-}" ]] && echo "  No Proxy:      ${USER_CONFIG[no_proxy]}"
        echo
    fi
}

# Generate Nix configuration from user data
# shellcheck disable=SC2120
generate_nix_config() {
    local output_file="${1:-$HOME/.config/dotfiles/user.nix}"

    log_info "Generating Nix configuration"

    # Build optional fields
    local git_signing=""
    if [[ -n "${USER_CONFIG[git_signing_key]:-}" ]]; then
        git_signing="signingKey = \"${USER_CONFIG[git_signing_key]}\";"
    fi

    local corp_ips=""
    if [[ -n "${USER_CONFIG[corp_test_ips]:-}" ]]; then
        corp_ips="corpTestIps = \"${USER_CONFIG[corp_test_ips]}\";"
    fi

    local http_proxy=""
    if [[ -n "${USER_CONFIG[http_proxy]:-}" ]]; then
        http_proxy="httpProxy = \"${USER_CONFIG[http_proxy]}\";"
    fi

    local https_proxy=""
    if [[ -n "${USER_CONFIG[https_proxy]:-}" ]]; then
        https_proxy="httpsProxy = \"${USER_CONFIG[https_proxy]}\";"
    fi

    local no_proxy=""
    if [[ -n "${USER_CONFIG[no_proxy]:-}" ]]; then
        no_proxy="noProxy = \"${USER_CONFIG[no_proxy]}\";"
    fi

    # Validate required fields
    if [[ -z "${USER_CONFIG[username]:-}" ]]; then
        log_error "Cannot generate Nix config: username is required"
        return 1
    fi
    if [[ -z "${USER_CONFIG[git_name]:-}" ]]; then
        log_error "Cannot generate Nix config: git_name is required"
        return 1
    fi
    if [[ -z "${USER_CONFIG[git_email]:-}" ]]; then
        log_error "Cannot generate Nix config: git_email is required"
        return 1
    fi

    cat > "$output_file" << EOF
# User-specific Nix configuration
# Generated from interactive setup on $(date)
{
  username = "${USER_CONFIG[username]}";

  git = {
    userName = "${USER_CONFIG[git_name]}";
    userEmail = "${USER_CONFIG[git_email]}";
    $git_signing
  };

  shell = {${USER_CONFIG[shell]:+
    default = \"${USER_CONFIG[shell]}\";
}${USER_CONFIG[editor]:+
    editor = \"${USER_CONFIG[editor]}\";
}
  };

  environment = {${USER_CONFIG[timezone]:+
    timezone = \"${USER_CONFIG[timezone]}\";
}    $corp_ips
    $http_proxy
    $https_proxy
    $no_proxy
  };
}
EOF

    log_info "Nix configuration generated at $output_file"
}

# Main interactive configuration flow
run_interactive_config() {
    local skip_existing="${1:-false}"

    # Initialize with defaults
    init_user_config

    # Check for existing configuration
    if load_user_config && [[ "$skip_existing" == "false" ]]; then
        log_info "Found existing configuration"
        show_config_summary

        if ! ask_yes_no "Do you want to update this configuration?" n; then
            log_info "Using existing configuration"
            return 0
        fi
    fi

    # Collect user information
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📝 Interactive User Configuration Wizard"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "This wizard will guide you through setting up your personal"
    echo "configuration for the dotfiles system."
    echo
    echo -e "${COLOR_CYAN}💡 Tips:${COLOR_NC}"
    echo "  • Press Enter to accept default values shown in [brackets]"
    echo "  • You can run this wizard again anytime with: ./apply.sh --interactive"
    echo "  • Your configuration is saved in: $USER_CONFIG_FILE"
    echo
    echo -e "${COLOR_GREEN}Progress: Step 1 of 4${COLOR_NC}"

    collect_username

    echo
    echo -e "${COLOR_GREEN}Progress: Step 2 of 4${COLOR_NC}"
    collect_git_config

    echo
    echo -e "${COLOR_GREEN}Progress: Step 3 of 4${COLOR_NC}"
    collect_shell_preferences

    echo
    echo -e "${COLOR_GREEN}Progress: Step 4 of 4${COLOR_NC}"
    collect_environment_config

    # Show summary
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_config_summary

    # Confirm before saving
    echo
    if ask_yes_no "Save this configuration?" y; then
        if save_user_config; then
            echo
            # Try to generate Nix config but don't fail if it errors
            # shellcheck disable=SC2119
            if generate_nix_config; then
                echo
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo -e "${COLOR_GREEN}✅ Configuration saved successfully!${COLOR_NC}"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo
                echo "Your configuration has been saved to:"
                echo "  • Shell config: $USER_CONFIG_FILE"
                echo "  • Nix config:   ${HOME}/.config/dotfiles/user.nix"
                echo
                echo "To apply these settings, run: ./apply.sh"
                echo
            else
                echo
                echo -e "${COLOR_YELLOW}⚠️  Configuration saved but Nix generation had issues${COLOR_NC}"
                echo "You may need to manually check the Nix configuration."
                echo
            fi
            return 0
        else
            echo
            echo -e "${COLOR_RED}❌ Failed to save configuration${COLOR_NC}"
            echo "Please check the error messages above and try again."
            return 1
        fi
    else
        echo
        echo -e "${COLOR_YELLOW}⚠️  Configuration cancelled${COLOR_NC}"
        echo "Your settings were not saved. You can run this wizard again anytime."
        return 1
    fi
}

# Export configuration as environment variables with proper escaping
export_user_config() {
    if ! load_user_config; then
        log_debug "No configuration to export"
        return 1
    fi

    local export_count=0
    local failed_count=0

    for key in "${!USER_CONFIG[@]}"; do
        local env_var_name="DOTFILES_${key^^}"
        local value="${USER_CONFIG[$key]}"

        # Export with proper handling of special characters
        # The value is already properly quoted in the array
        if export "${env_var_name}=${value}" 2>/dev/null; then
            ((export_count++))
            log_debug "Exported: ${env_var_name}"
        else
            ((failed_count++))
            log_warn "Failed to export: ${env_var_name}"
        fi
    done

    if [[ $failed_count -gt 0 ]]; then
        log_warn "Exported $export_count variables, $failed_count failed"
        return 1
    fi

    log_debug "User configuration exported to environment ($export_count variables)"
    return 0
}

# Get a specific configuration value
get_config_value() {
    local key="$1"

    load_user_config || init_user_config
    echo "${USER_CONFIG[$key]:-}"
}

# Update a specific configuration value
set_config_value() {
    local key="$1"
    local value="$2"

    load_user_config || init_user_config
    USER_CONFIG[$key]="$value"
    save_user_config
}

# Export functions for use by other scripts
export -f run_interactive_config
export -f load_user_config
export -f save_user_config
export -f get_config_value
export -f set_config_value
export -f export_user_config
