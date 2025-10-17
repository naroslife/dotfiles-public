# Testing Guide

## Test Suite Overview

The project includes comprehensive testing infrastructure in the `tests/` directory:

```
tests/
├── test_common.sh         # Tests for lib/common.sh functions
├── test_apply.sh          # Tests for apply.sh script
├── test_user_config.sh    # Tests for user configuration module
└── run_tests.sh           # Test runner with coverage and benchmarks
```

## Running Tests

### Basic Test Execution

```bash
# Run all tests
./tests/run_tests.sh

# Expected output: Test results for each module
# ✓ indicates passed test
# ✗ indicates failed test
```

### Advanced Test Options

```bash
# Run with code coverage analysis
./tests/run_tests.sh --coverage

# Run with performance benchmarks
./tests/run_tests.sh --benchmark

# Run with verbose output (detailed logs)
./tests/run_tests.sh --verbose

# Combine options
./tests/run_tests.sh --coverage --benchmark --verbose
```

### Individual Test Files

```bash
# Run specific test file
./tests/test_common.sh

# Run specific test file with verbose output
bash -x ./tests/test_common.sh
```

## Test Structure

### Test File Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source the library being tested
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# Test setup function
setup_test() {
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)
    
    # Initialize test environment
    export TEST_MODE=true
    
    # Prepare test fixtures
}

# Cleanup function
teardown_test() {
    # Remove temporary files
    rm -rf "$TEST_DIR"
    
    # Reset environment
    unset TEST_MODE
}

# Individual test case
test_function_success() {
    local result
    local expected="success"
    
    result=$(function_under_test "valid_input")
    
    if [[ "$result" == "$expected" ]]; then
        log_info "✓ test_function_success passed"
        return 0
    else
        log_error "✗ test_function_success failed"
        log_error "  Expected: $expected"
        log_error "  Got: $result"
        return 1
    fi
}

# Test error handling
test_function_error() {
    if function_under_test "invalid_input" 2>/dev/null; then
        log_error "✗ test_function_error failed: should have returned error"
        return 1
    else
        log_info "✓ test_function_error passed"
        return 0
    fi
}

# Main test runner
main() {
    local failed=0
    
    setup_test
    
    test_function_success || ((failed++))
    test_function_error || ((failed++))
    
    teardown_test
    
    if [[ $failed -eq 0 ]]; then
        log_info "All tests passed!"
        return 0
    else
        log_error "$failed test(s) failed"
        return 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Test Coverage

### What Is Tested

1. **Common Library Functions** (`test_common.sh`)
   - Logging functions (log_info, log_warn, log_error, log_debug)
   - Platform detection (is_wsl, is_linux, is_macos)
   - Error handling functions
   - File operations (backup_file, restore_file)
   - Configuration validation (validate_json_file, validate_yaml_file)
   - Secure downloads (fetch_url with checksum verification)

2. **Apply Script** (`test_apply.sh`)
   - CLI argument parsing
   - User selection logic
   - Nix installation checks
   - Git submodule handling
   - Home Manager configuration application
   - Error recovery mechanisms

3. **User Configuration** (`test_user_config.sh`)
   - Interactive configuration prompts
   - Input validation (usernames, emails, paths)
   - Configuration persistence
   - Integration with Home Manager

### Coverage Requirements

- **Minimum Coverage**: 80%
- **Critical Paths**: 100% (installation, configuration, error handling)
- **Edge Cases**: All known edge cases should have tests
- **Error Conditions**: All error paths should be tested

## Test Quality Standards

### Test Organization

```bash
# Group related tests together
test_group_feature_success() { }
test_group_feature_failure() { }
test_group_feature_edge_case() { }
```

### Assertions

```bash
# Use clear assertions
if [[ "$actual" == "$expected" ]]; then
    return 0
else
    log_error "Assertion failed: expected '$expected', got '$actual'"
    return 1
fi

# Test for specific error messages
if ! command 2>&1 | grep -q "expected error"; then
    log_error "Expected error message not found"
    return 1
fi
```

### Test Isolation

```bash
# Each test should be independent
# Use temporary directories
TEST_DIR=$(mktemp -d)

# Clean up after tests
trap 'rm -rf "$TEST_DIR"' EXIT

# Don't rely on order of execution
# Each test should setup its own environment
```

## Continuous Integration

### Pre-Commit Checks

Before committing, ensure:

```bash
# 1. Nix syntax validation
nix flake check

# 2. Run all tests
./tests/run_tests.sh

# 3. Code coverage check
./tests/run_tests.sh --coverage

# All checks should pass
```

### Performance Benchmarks

```bash
# Run benchmarks to ensure no performance regression
./tests/run_tests.sh --benchmark

# Compare results against baseline:
# - Platform detection: ~12ms
# - File operations: ~45ms
# - Configuration validation: ~30ms
# - Full setup: 2-5 minutes
```

## Writing New Tests

### When to Add Tests

1. **New Features**: Every new function or feature needs tests
2. **Bug Fixes**: Add test that reproduces the bug, then fix it
3. **Edge Cases**: When you discover edge cases, add tests for them
4. **Refactoring**: Ensure tests pass before and after refactoring

### Test Naming Conventions

```bash
# Format: test_<function>_<scenario>
test_log_info_success
test_log_error_with_empty_message
test_is_wsl_on_linux
test_backup_file_already_exists
```

### Best Practices

1. **Descriptive Names**: Test names should clearly describe what they test
2. **One Assertion Per Test**: Each test should verify one specific behavior
3. **Clear Failure Messages**: When a test fails, it should be obvious why
4. **Fast Execution**: Tests should run quickly (mock external dependencies)
5. **No Side Effects**: Tests shouldn't affect the user's actual system
6. **Deterministic**: Tests should always produce the same result

## Mock Testing

### Mock External Commands

```bash
# Create mock functions for testing
git() {
    # Mock git command
    case "$1" in
        "status")
            echo "On branch main"
            ;;
        "clone")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Use in tests
test_with_mock_git() {
    # Git is mocked, no actual git operations
    result=$(function_that_uses_git)
    # Assert result
}
```

### Test Environment Variables

```bash
# Set test-specific environment
export HOME="$TEST_DIR/home"
export USER="testuser"
export NIX_PATH="$TEST_DIR/nix"

# Reset after tests
teardown_test() {
    unset HOME USER NIX_PATH
}
```

## Debugging Tests

### Verbose Output

```bash
# Run with bash debugging
bash -x ./tests/test_common.sh

# Or use verbose flag
./tests/run_tests.sh --verbose
```

### Isolate Failing Test

```bash
# Comment out other tests
main() {
    # test_passing_test  # Commented out
    test_failing_test     # Only run this one
}
```

### Add Debug Logging

```bash
test_function() {
    log_debug "Input: $input"
    result=$(function_under_test "$input")
    log_debug "Result: $result"
    log_debug "Expected: $expected"
    # Assertion
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: ./tests/run_tests.sh --coverage
      - name: Check Nix syntax
        run: nix flake check
```

## Test Maintenance

### Regular Tasks

1. **Weekly**: Run full test suite with coverage
2. **Before Release**: Run benchmarks to check performance
3. **After Updates**: Re-run tests after dependency updates
4. **Monthly**: Review test coverage and add missing tests

### Updating Tests

When updating code:
1. Update tests first (test-driven development)
2. Run tests to verify they fail
3. Update implementation
4. Run tests to verify they pass
5. Add new tests for new edge cases discovered
