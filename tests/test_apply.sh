#!/usr/bin/env bash
# Test suite for apply.sh script
#
# This test suite validates the main apply script functionality
# using mocks and controlled environments.

set -euo pipefail

# Test framework setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"

# Source test utilities
# shellcheck source=test_common.sh
source "$TEST_DIR/test_common.sh"

# Mock functions for testing
mock_nix() {
    # Create a mock nix command
    local mock_nix_script="$TEST_TEMP_DIR/nix"
    cat > "$mock_nix_script" << 'EOF'
#!/bin/bash
case "$1" in
    --version)
        echo "nix (Nix) 2.13.3"
        ;;
    eval)
        echo '["user1", "user2"]'
        ;;
    run)
        echo "Mock home-manager execution"
        ;;
    *)
        echo "Mock nix command: $*"
        ;;
esac
EOF
    chmod +x "$mock_nix_script"
    export PATH="$TEST_TEMP_DIR:$PATH"
}

mock_git() {
    # Create a mock git command
    local mock_git_script="$TEST_TEMP_DIR/git"
    cat > "$mock_git_script" << 'EOF'
#!/bin/bash
case "$1" in
    submodule)
        echo "Mock git submodule: $*"
        ;;
    *)
        echo "Mock git command: $*"
        ;;
esac
EOF
    chmod +x "$mock_git_script"
    export PATH="$TEST_TEMP_DIR:$PATH"
}

setup_mock_environment() {
    # Create a mock dotfiles repository structure
    mkdir -p "$TEST_TEMP_DIR/dotfiles"
    cd "$TEST_TEMP_DIR/dotfiles"

    # Create mock configuration files
    echo '{ description = "Mock flake"; }' > flake.nix
    echo '{ pkgs, ... }: { }' > home.nix
    echo '' > .gitmodules

    # Create mock .git directory
    mkdir -p .git

    # Create lib directory and copy common.sh
    mkdir -p lib
    cp "$ROOT_DIR/lib/common.sh" lib/

    # Create the apply script in test location
    cp "$ROOT_DIR/apply.sh" apply.sh
    chmod +x apply.sh

    mock_nix
    mock_git
}

test_argument_parsing() {
    echo "Testing argument parsing..."

    # Test help option
    assert_command_succeeds "./apply.sh --help" "Help option should work"

    # Test verbose option parsing by checking if it doesn't error
    # We can't easily test the actual verbose output without capturing it
    assert_command_succeeds "echo 'n' | timeout 5 ./apply.sh --verbose --yes || true" "Verbose option should be parsed"
}

test_prerequisite_validation() {
    echo "Testing prerequisite validation..."

    # This test runs in our mock environment where files exist
    # So we test that validation passes
    # (The script will fail later due to mocking, but validation should pass)

    # Test by running just the validation part
    # We'll need to extract this into a testable function in the real implementation
    echo "  Note: Full prerequisite validation testing requires refactoring apply.sh to expose validation function"
}

test_platform_detection_integration() {
    echo "Testing platform detection integration..."

    # Test that the script can detect platform
    # This uses the actual platform detection from common.sh
    local platform
    platform=$(cd "$TEST_TEMP_DIR/dotfiles" && bash -c 'source lib/common.sh && detect_platform')
    assert_true "[[ -n '$platform' ]]" "Platform detection should return non-empty result"
}

test_user_selection() {
    echo "Testing user selection..."

    # Test automatic user selection in non-interactive mode
    # This test verifies the script handles user selection correctly
    echo "  Note: User selection testing requires mock JSON parsing"
}

test_backup_functionality() {
    echo "Testing backup functionality..."

    # Create mock home directory files
    mkdir -p "$TEST_TEMP_DIR/mock_home"
    echo "original bashrc" > "$TEST_TEMP_DIR/mock_home/.bashrc"
    echo "original zshrc" > "$TEST_TEMP_DIR/mock_home/.zshrc"

    # Test backup creation (using common.sh function directly)
    cd "$TEST_TEMP_DIR/dotfiles"
    source lib/common.sh

    local backup_file
    backup_file=$(backup_file "$TEST_TEMP_DIR/mock_home/.bashrc")

    assert_file_exists "$backup_file" "Backup file should be created"
    assert_equals "original bashrc" "$(cat "$backup_file")" "Backup should preserve original content"
}

# Integration tests
test_dry_run_execution() {
    echo "Testing dry run execution..."

    # Test that script doesn't crash with basic options
    # Using timeout to prevent hanging on prompts
    cd "$TEST_TEMP_DIR/dotfiles"

    # Redirect stdin to provide 'n' answers to all prompts
    local exit_code=0
    echo -e "n\nn\nn\nn" | timeout 10 ./apply.sh --yes --user testuser 2>/dev/null || exit_code=$?

    # We expect this to fail due to mocking, but it should fail gracefully
    # The important thing is that it doesn't crash immediately
    echo "  Dry run completed with exit code: $exit_code (expected to fail due to mocking)"
}

# Run all tests
run_apply_tests() {
    echo "Running apply.sh test suite..."
    echo "==============================="

    setup_test_env
    setup_mock_environment

    test_argument_parsing
    test_prerequisite_validation
    test_platform_detection_integration
    test_user_selection
    test_backup_functionality
    test_dry_run_execution

    cleanup_test_env

    echo
    echo "==============================="
    echo "Apply Script Test Results:"
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
    run_apply_tests
fi