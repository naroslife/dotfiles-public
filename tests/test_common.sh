#!/usr/bin/env bash
# Test suite for common.sh library
#
# This test suite validates all functions in the common library
# to ensure they work correctly across different environments.

set -euo pipefail

# Test framework setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"

# Source the library under test
# shellcheck source=../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
setup_test_env() {
    # Create temporary directory for tests
    TEST_TEMP_DIR=$(mktemp -d)
    export TEST_TEMP_DIR

    # Suppress log output during tests unless debug mode
    if [[ "${DEBUG_TESTS:-}" != "1" ]]; then
        LOG_LEVEL=$LOG_LEVEL_ERROR
    fi
}

cleanup_test_env() {
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ PASS: $message"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ FAIL: $message"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$condition"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ PASS: $message"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ FAIL: $message"
        echo "  Condition failed: $condition"
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if ! eval "$condition"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ PASS: $message"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ FAIL: $message"
        echo "  Condition should have failed: $condition"
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File $file should exist}"

    assert_true "[[ -f '$file' ]]" "$message"
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$value" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ PASS: $message"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ FAIL: $message"
        echo "  Got empty string"
    fi
}

assert_command_succeeds() {
    local command="$1"
    local message="${2:-Command should succeed: $command}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$command" >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ PASS: $message"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ FAIL: $message"
        echo "  Command failed: $command"
    fi
}

assert_fail() {
    local message="${1:-Assertion failed}"

    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ FAIL: $message"
}

# Aliases for compatibility
test_pass() {
    local message="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ PASS: $message"
}

test_fail() {
    local message="$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ FAIL: $message"
}

# Test functions

test_logging_functions() {
    echo "Testing logging functions..."

    # Test that logging functions exist and are callable
    assert_command_succeeds "log_info 'test message'" "log_info function should be callable"
    assert_command_succeeds "log_warn 'test warning'" "log_warn function should be callable"
    assert_command_succeeds "log_error 'test error'" "log_error function should be callable"
    assert_command_succeeds "log_debug 'test debug'" "log_debug function should be callable"
}

test_platform_detection() {
    echo "Testing platform detection..."

    # Test that detect_platform returns a valid platform
    local platform
    platform=$(detect_platform)
    assert_true "[[ '$platform' =~ ^(linux|wsl|macos|unknown)$ ]]" "detect_platform should return valid platform: $platform"

    # Test platform-specific functions
    case "$platform" in
        linux)
            assert_true "is_linux" "is_linux should return true on Linux"
            assert_false "is_wsl" "is_wsl should return false on non-WSL Linux"
            assert_false "is_macos" "is_macos should return false on Linux"
            ;;
        wsl)
            assert_true "is_wsl" "is_wsl should return true on WSL"
            assert_false "is_linux" "is_linux should return false on WSL"
            assert_false "is_macos" "is_macos should return false on WSL"
            ;;
        macos)
            assert_true "is_macos" "is_macos should return true on macOS"
            assert_false "is_linux" "is_linux should return false on macOS"
            assert_false "is_wsl" "is_wsl should return false on macOS"
            ;;
    esac
}

test_file_operations() {
    echo "Testing file operations..."

    # Test backup_file function
    local test_file="$TEST_TEMP_DIR/test_file.txt"
    echo "test content" > "$test_file"

    local backup_path
    backup_path=$(backup_file "$test_file")

    assert_file_exists "$backup_path" "Backup file should be created"
    assert_equals "test content" "$(cat "$backup_path")" "Backup file should have correct content"

    # Test backup of non-existent file
    local non_existent_backup
    non_existent_backup=$(backup_file "$TEST_TEMP_DIR/non_existent.txt" || echo "")
    assert_equals "" "$non_existent_backup" "Backup of non-existent file should return empty string"
}

test_config_validation() {
    echo "Testing configuration validation..."

    # Test valid JSON
    local valid_json="$TEST_TEMP_DIR/valid.json"
    echo '{"test": "value"}' > "$valid_json"
    assert_command_succeeds "validate_config_file '$valid_json' json" "Valid JSON should pass validation"

    # Test invalid JSON
    local invalid_json="$TEST_TEMP_DIR/invalid.json"
    echo '{"test": invalid}' > "$invalid_json"
    assert_false "validate_config_file '$invalid_json' json" "Invalid JSON should fail validation"

    # Test valid YAML (if yq is available)
    if command -v yq >/dev/null 2>&1; then
        local valid_yaml="$TEST_TEMP_DIR/valid.yaml"
        echo 'test: value' > "$valid_yaml"
        assert_command_succeeds "validate_config_file '$valid_yaml' yaml" "Valid YAML should pass validation"
    fi
}

test_require_command() {
    echo "Testing command requirement checking..."

    # Test with a command that should exist
    assert_command_succeeds "require_command bash" "require_command should succeed for existing commands"

    # Test with a command that shouldn't exist
    # Note: require_command calls die() which exits, so we test in a subshell
    assert_false "(require_command this_command_definitely_does_not_exist_12345 2>/dev/null)" "require_command should fail for non-existent commands"
}

test_fetch_url() {
    echo "Testing URL fetching..."

    # Only test if we have internet connectivity
    if ping -c 1 httpbin.org >/dev/null 2>&1; then
        local output_file="$TEST_TEMP_DIR/fetch_test.txt"

        # Test basic fetch (without checksum for simplicity)
        assert_command_succeeds "fetch_url 'https://httpbin.org/robots.txt' '$output_file'" "URL fetch should succeed"
        assert_file_exists "$output_file" "Fetched file should exist"

        # Clean up
        rm -f "$output_file"
    else
        echo "  Skipping URL fetch tests (no internet connectivity)"
    fi
}

# Run all tests
run_all_tests() {
    echo "Running common.sh test suite..."
    echo "================================"

    setup_test_env

    test_logging_functions
    test_platform_detection
    test_file_operations
    test_config_validation
    test_require_command
    test_fetch_url

    cleanup_test_env

    echo
    echo "================================"
    echo "Test Results:"
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
    run_all_tests
fi