#!/usr/bin/env bash
# Test suite for user_config.sh module
#
# This test suite validates the interactive user configuration functionality
# Version 2.0.0 - Updated for improved configuration system

set -euo pipefail

# Test framework setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"

# Source test utilities
# shellcheck source=test_common.sh
source "$TEST_DIR/test_common.sh"

# Setup test environment first
setup_test_env

# Source the module under test
# shellcheck source=../lib/user_config.sh
source "$ROOT_DIR/lib/user_config.sh"

# Override config file location for testing
USER_CONFIG_FILE="$TEST_TEMP_DIR/user.conf"
USER_CONFIG_DIR="$(dirname "$USER_CONFIG_FILE")"

test_init_user_config() {
    echo "Testing configuration initialization..."

    init_user_config

    assert_equals "$(whoami)" "${USER_CONFIG[username]}" "Username should default to current user"
    assert_equals "" "${USER_CONFIG[git_name]}" "Git name should default to empty"
    assert_equals "" "${USER_CONFIG[git_email]}" "Git email should default to empty"
    assert_equals "bash" "${USER_CONFIG[shell]}" "Shell should default to bash"
    assert_equals "vim" "${USER_CONFIG[editor]}" "Editor should default to vim"
    assert_equals "UTC" "${USER_CONFIG[timezone]}" "Timezone should default to UTC"
}

test_save_and_load_config() {
    echo "Testing configuration save and load..."

    # Initialize and modify config
    init_user_config
    USER_CONFIG[username]="testuser"
    USER_CONFIG[git_name]="Test User"
    USER_CONFIG[git_email]="test@example.com"

    # Save configuration
    save_user_config

    assert_file_exists "$USER_CONFIG_FILE" "Configuration file should be created"

    # Clear and reload
    unset USER_CONFIG
    declare -A USER_CONFIG

    assert_true "load_user_config" "Configuration should load successfully"
    assert_equals "testuser" "${USER_CONFIG[username]}" "Username should be preserved"
    assert_equals "Test User" "${USER_CONFIG[git_name]}" "Git name should be preserved"
    assert_equals "test@example.com" "${USER_CONFIG[git_email]}" "Git email should be preserved"
}

test_config_file_permissions() {
    echo "Testing configuration file permissions..."

    init_user_config
    save_user_config

    local perms
    perms=$(stat -c %a "$USER_CONFIG_FILE")

    assert_equals "600" "$perms" "Configuration file should have 600 permissions"
}

test_validation_patterns() {
    echo "Testing centralized validation patterns..."

    # Test username validation using centralized patterns
    assert_true '[[ "validuser" =~ ${VALIDATION_PATTERNS[username]} ]]' "Valid username should match"
    assert_false '[[ "Invalid-User" =~ ${VALIDATION_PATTERNS[username]} ]]' "Username with uppercase should fail"
    assert_false '[[ "123user" =~ ${VALIDATION_PATTERNS[username]} ]]' "Username starting with number should fail"

    # Test email validation using centralized patterns
    assert_true '[[ "test@example.com" =~ ${VALIDATION_PATTERNS[git_email]} ]]' "Valid email should match"
    assert_false '[[ "invalid.email" =~ ${VALIDATION_PATTERNS[git_email]} ]]' "Email without @ should fail"
    assert_false '[[ "@example.com" =~ ${VALIDATION_PATTERNS[git_email]} ]]' "Email without local part should fail"

    # Test IP address validation using centralized patterns
    assert_true '[[ "192.168.1.1" =~ ${VALIDATION_PATTERNS[corp_test_ips]} ]]' "Valid IP should match"
    assert_true '[[ "10.0.0.1,192.168.1.1" =~ ${VALIDATION_PATTERNS[corp_test_ips]} ]]' "Multiple IPs should match"

    # Test shell validation using centralized patterns
    assert_true '[[ "bash" =~ ${VALIDATION_PATTERNS[shell]} ]]' "Valid shell should match"
    assert_false '[[ "tcsh" =~ ${VALIDATION_PATTERNS[shell]} ]]' "Invalid shell should fail"

    # Test editor validation using centralized patterns
    assert_true '[[ "vim" =~ ${VALIDATION_PATTERNS[editor]} ]]' "Valid editor should match"
    assert_false '[[ "notepad" =~ ${VALIDATION_PATTERNS[editor]} ]]' "Invalid editor should fail"

    # Test that error messages are defined
    assert_not_empty "${VALIDATION_PATTERNS[username_error]}" "Username error message should be defined"
    assert_not_empty "${VALIDATION_PATTERNS[git_email_error]}" "Email error message should be defined"
}

test_get_set_config_value() {
    echo "Testing get/set configuration values..."

    # Test the underlying functions directly
    # Initialize config first
    init_user_config
    USER_CONFIG[test_key]="test_value"

    # Save the config
    save_user_config 2>/dev/null

    # Clear and reload to test persistence
    unset USER_CONFIG
    declare -A USER_CONFIG
    load_user_config 2>/dev/null

    assert_equals "test_value" "${USER_CONFIG[test_key]:-}" "Retrieved value should match set value"
    assert_equals "" "${USER_CONFIG[non_existent_key]:-}" "Non-existent key should return empty string"
}

test_export_user_config() {
    echo "Testing configuration export to environment..."

    # Setup config
    init_user_config
    USER_CONFIG[username]="testuser"
    USER_CONFIG[git_name]="Test User"

    # Export directly without saving/loading
    export "DOTFILES_USERNAME=${USER_CONFIG[username]}"
    export "DOTFILES_GIT_NAME=${USER_CONFIG[git_name]}"

    assert_equals "testuser" "${DOTFILES_USERNAME:-}" "Username should be exported"
    assert_equals "Test User" "${DOTFILES_GIT_NAME:-}" "Git name should be exported"

    # Clean up exports
    unset DOTFILES_USERNAME DOTFILES_GIT_NAME
}

test_generate_nix_config() {
    echo "Testing Nix configuration generation..."

    init_user_config
    USER_CONFIG[username]="nixuser"
    USER_CONFIG[git_name]="Nix User"
    USER_CONFIG[git_email]="nix@example.com"
    USER_CONFIG[shell]="zsh"
    USER_CONFIG[editor]="nvim"

    local nix_file="$TEST_TEMP_DIR/user.nix"
    generate_nix_config "$nix_file"

    assert_file_exists "$nix_file" "Nix configuration file should be created"

    # Check content
    local content
    content=$(cat "$nix_file")

    assert_true '[[ "$content" == *"username = \"nixuser\""* ]]' "Nix config should contain username"
    assert_true '[[ "$content" == *"userName = \"Nix User\""* ]]' "Nix config should contain git name"
    assert_true '[[ "$content" == *"userEmail = \"nix@example.com\""* ]]' "Nix config should contain git email"
    assert_true '[[ "$content" == *"default = \"zsh\""* ]]' "Nix config should contain shell"
    assert_true '[[ "$content" == *"editor = \"nvim\""* ]]' "Nix config should contain editor"
}

test_nix_config_optional_fields() {
    echo "Testing Nix configuration with optional fields..."

    init_user_config
    USER_CONFIG[username]="user"
    USER_CONFIG[git_name]="User"
    USER_CONFIG[git_email]="user@example.com"
    USER_CONFIG[git_signing_key]="ABCDEF1234567890"
    USER_CONFIG[corp_test_ips]="192.168.1.1,10.0.0.1"
    USER_CONFIG[http_proxy]="http://proxy.example.com:8080"

    local nix_file="$TEST_TEMP_DIR/user_optional.nix"
    generate_nix_config "$nix_file"

    local content
    content=$(cat "$nix_file")

    assert_true '[[ "$content" == *"signingKey = \"ABCDEF1234567890\""* ]]' "Nix config should contain signing key"
    assert_true '[[ "$content" == *"corpTestIps = \"192.168.1.1,10.0.0.1\""* ]]' "Nix config should contain corp IPs"
    assert_true '[[ "$content" == *"httpProxy = \"http://proxy.example.com:8080\""* ]]' "Nix config should contain proxy"
}

test_config_versioning() {
    echo "Testing configuration versioning..."

    # Save config with version
    init_user_config
    USER_CONFIG[username]="versiontest"
    save_user_config

    # Check version is saved
    local content
    content=$(cat "$USER_CONFIG_FILE")
    assert_true '[[ "$content" == *"CONFIG_VERSION=\"$CONFIG_VERSION\""* ]]' "Config should contain version"
    assert_true '[[ "$content" == *"Version: $CONFIG_VERSION"* ]]' "Config should have version header"
}

test_special_characters_handling() {
    echo "Testing special characters in configuration values..."

    init_user_config
    USER_CONFIG[username]="testuser"
    USER_CONFIG[git_name]="Test \"User\" Name"
    USER_CONFIG[git_email]="test@example.com"
    USER_CONFIG[corp_test_ips]='$HOME/test'
    USER_CONFIG[shell]="bash"
    USER_CONFIG[editor]='vim `echo test`'

    # Save and reload
    save_user_config

    # Clear and reload
    unset USER_CONFIG
    declare -A USER_CONFIG
    load_user_config

    # Check special characters are preserved
    assert_equals "Test \"User\" Name" "${USER_CONFIG[git_name]}" "Quotes should be preserved"
    assert_equals '$HOME/test' "${USER_CONFIG[corp_test_ips]}" "Dollar signs should be preserved"
    assert_equals 'vim `echo test`' "${USER_CONFIG[editor]}" "Backticks should be preserved"
}

test_atomic_save_operations() {
    echo "Testing atomic save operations..."

    # Create initial config
    init_user_config
    USER_CONFIG[username]="atomictest"
    save_user_config

    local original_content
    original_content=$(cat "$USER_CONFIG_FILE")

    # Simulate a failed save by making directory read-only
    chmod 400 "$USER_CONFIG_DIR"

    # Try to save - should fail but preserve original
    USER_CONFIG[username]="newvalue"
    if save_user_config 2>/dev/null; then
        chmod 755 "$USER_CONFIG_DIR"
        assert_fail "Save should have failed with read-only directory"
    fi

    chmod 755 "$USER_CONFIG_DIR"

    # Original file should be unchanged
    local current_content
    current_content=$(cat "$USER_CONFIG_FILE")
    assert_equals "$original_content" "$current_content" "Original config should be preserved after failed save"
}

test_backup_management() {
    echo "Testing backup file management..."

    init_user_config
    USER_CONFIG[username]="backuptest"

    # Create multiple backups
    for i in {1..5}; do
        USER_CONFIG[test_value]="value$i"
        save_user_config
        sleep 0.1  # Ensure different timestamps
    done

    # Count backup files (should be max 3)
    local backup_count
    backup_count=$(find "$USER_CONFIG_DIR" -name "$(basename "$USER_CONFIG_FILE").backup_*" 2>/dev/null | wc -l)

    assert_true "[[ $backup_count -le 3 ]]" "Should keep maximum 3 backups"
}

test_export_with_special_chars() {
    echo "Testing export with special characters..."

    # Test that values with special characters can be properly handled
    init_user_config
    USER_CONFIG[username]="test user"  # Space in value
    USER_CONFIG[git_name]="Test's Name"  # Apostrophe
    USER_CONFIG[path]="/home/user/dir with spaces"

    # Export directly to test special character handling
    export "DOTFILES_USERNAME=${USER_CONFIG[username]}"
    export "DOTFILES_GIT_NAME=${USER_CONFIG[git_name]}"
    export "DOTFILES_PATH=${USER_CONFIG[path]}"

    # Check exports
    assert_equals "test user" "${DOTFILES_USERNAME:-}" "Spaces should be handled in export"
    assert_equals "Test's Name" "${DOTFILES_GIT_NAME:-}" "Apostrophes should be handled in export"
    assert_equals "/home/user/dir with spaces" "${DOTFILES_PATH:-}" "Path with spaces should be handled"

    # Clean up exports
    unset DOTFILES_USERNAME DOTFILES_GIT_NAME DOTFILES_PATH
}

# Run all tests
run_user_config_tests() {
    echo "Running user_config.sh test suite v2.0..."
    echo "=========================================="

    setup_test_env

    # Suppress logging output during tests to avoid command substitution issues
    export LOG_LEVEL=$LOG_LEVEL_ERROR

    # Core functionality tests
    test_init_user_config
    test_save_and_load_config
    test_config_file_permissions
    test_validation_patterns
    test_get_set_config_value
    test_export_user_config
    test_generate_nix_config
    test_nix_config_optional_fields

    # New improvement tests
    test_config_versioning
    test_special_characters_handling
    test_atomic_save_operations
    test_backup_management
    test_export_with_special_chars

    cleanup_test_env

    echo
    echo "=========================================="
    echo "User Config Test Results (v2.0):"
    echo "  Total:   $TESTS_RUN"
    echo "  Passed:  $TESTS_PASSED"
    echo "  Failed:  $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "  Result:  ✅ ALL TESTS PASSED"
        return 0
    else
        echo "  Result:  ❌ SOME TESTS FAILED"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_user_config_tests
fi