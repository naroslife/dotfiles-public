#!/usr/bin/env bash
# Test runner for dotfiles repository
#
# This script runs all test suites and provides a comprehensive
# test report with performance metrics.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"

# Test configuration
PARALLEL_TESTS=false
COVERAGE_REPORT=false
PERFORMANCE_BENCHMARK=false
VERBOSE_OUTPUT=false

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Parse command line arguments
parse_test_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--parallel)
                PARALLEL_TESTS=true
                shift
                ;;
            -c|--coverage)
                COVERAGE_REPORT=true
                shift
                ;;
            -b|--benchmark)
                PERFORMANCE_BENCHMARK=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_OUTPUT=true
                export DEBUG_TESTS=1
                shift
                ;;
            -h|--help)
                show_test_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_test_help
                exit 1
                ;;
        esac
    done
}

show_test_help() {
    cat << EOF
Test Runner for Dotfiles Repository

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -p, --parallel     Run test suites in parallel (faster but less readable output)
    -c, --coverage     Generate code coverage report (requires shellcheck)
    -b, --benchmark    Run performance benchmarks
    -v, --verbose      Enable verbose output
    -h, --help         Show this help message

EXAMPLES:
    $0                 # Run all tests with default settings
    $0 -v -b           # Verbose output with benchmarks
    $0 -p -c           # Parallel execution with coverage

EOF
}

# Performance benchmarking
benchmark_function() {
    local function_name="$1"
    local test_file="$2"
    local iterations="${3:-10}"

    echo "Benchmarking $function_name..."

    local start_time
    local end_time
    local total_time=0

    for ((i=1; i<=iterations; i++)); do
        start_time=$(date +%s%N)

        # Run the function (source the test file and run specific function)
        (
            # shellcheck source=/dev/null
            source "$test_file"
            "$function_name" >/dev/null 2>&1 || true
        )

        end_time=$(date +%s%N)
        local duration=$((end_time - start_time))
        total_time=$((total_time + duration))

        if $VERBOSE_OUTPUT; then
            echo "  Iteration $i: $((duration / 1000000))ms"
        fi
    done

    local average_time=$((total_time / iterations / 1000000))
    echo "  Average time: ${average_time}ms (over $iterations iterations)"
}

# Code coverage analysis
generate_coverage_report() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "⚠️  Shellcheck not found - skipping coverage analysis"
        return 0
    fi

    echo "Generating code coverage report..."

    local coverage_dir="$ROOT_DIR/coverage"
    mkdir -p "$coverage_dir"

    # Analyze shell scripts for potential issues
    local script_files
    script_files=$(find "$ROOT_DIR" -name "*.sh" -not -path "*/tests/*" -not -path "*/.git/*")

    local total_files=0
    local clean_files=0

    while IFS= read -r script_file; do
        if [[ -n "$script_file" ]]; then
            total_files=$((total_files + 1))
            local output_file="$coverage_dir/$(basename "$script_file").report"

            if shellcheck -f json "$script_file" > "$output_file" 2>/dev/null; then
                local issues
                issues=$(jq length "$output_file" 2>/dev/null || echo "0")
                if [[ "$issues" -eq 0 ]]; then
                    clean_files=$((clean_files + 1))
                    echo "✅ $script_file: No issues"
                else
                    echo "⚠️  $script_file: $issues issues found"
                fi
            else
                echo "❌ $script_file: Analysis failed"
            fi
        fi
    done <<< "$script_files"

    local coverage_percentage=$((clean_files * 100 / total_files))
    echo
    echo "Coverage Summary:"
    echo "  Total files analyzed: $total_files"
    echo "  Files without issues: $clean_files"
    echo "  Code quality score: $coverage_percentage%"

    # Generate HTML report if pandoc is available
    if command -v pandoc >/dev/null 2>&1; then
        echo "  HTML report: $coverage_dir/index.html"
        cat > "$coverage_dir/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Dotfiles Code Quality Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .summary { background: #f5f5f5; padding: 20px; border-radius: 5px; }
        .good { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
    </style>
</head>
<body>
    <h1>Dotfiles Code Quality Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Total files analyzed: <strong>$total_files</strong></p>
        <p>Files without issues: <strong>$clean_files</strong></p>
        <p>Code quality score: <strong class="good">$coverage_percentage%</strong></p>
    </div>
    <p>Generated on: $(date)</p>
</body>
</html>
EOF
    fi
}

# Run a single test suite
run_test_suite() {
    local test_file="$1"
    local suite_name
    suite_name=$(basename "$test_file" .sh)

    echo "🧪 Running test suite: $suite_name"
    echo "================================"

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    local start_time
    start_time=$(date +%s)

    local exit_code=0
    if $VERBOSE_OUTPUT; then
        bash "$test_file" || exit_code=$?
    else
        bash "$test_file" 2>/dev/null || exit_code=$?
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ $exit_code -eq 0 ]]; then
        PASSED_SUITES=$((PASSED_SUITES + 1))
        echo "✅ $suite_name completed successfully (${duration}s)"
    else
        FAILED_SUITES=$((FAILED_SUITES + 1))
        echo "❌ $suite_name failed (${duration}s)"
    fi

    echo

    return $exit_code
}

# Run all test suites
run_all_test_suites() {
    echo "🚀 Starting dotfiles test runner"
    echo "Platform: $(uname -s)"
    echo "Date: $(date)"
    echo

    # Find all test files
    local test_files
    test_files=$(find "$TEST_DIR" -name "test_*.sh" -type f | sort)

    if [[ -z "$test_files" ]]; then
        echo "❌ No test files found in $TEST_DIR"
        exit 1
    fi

    local test_file_count
    test_file_count=$(echo "$test_files" | wc -l)
    echo "Found $test_file_count test suite(s)"
    echo

    # Run tests
    if $PARALLEL_TESTS; then
        echo "Running tests in parallel mode..."
        echo "$test_files" | xargs -I {} -P 4 bash -c "$(declare -f run_test_suite); run_test_suite '{}'"
    else
        while IFS= read -r test_file; do
            if [[ -n "$test_file" ]]; then
                run_test_suite "$test_file"
            fi
        done <<< "$test_files"
    fi

    # Performance benchmarks
    if $PERFORMANCE_BENCHMARK; then
        echo "🏃 Running performance benchmarks"
        echo "================================="

        # Benchmark key functions
        if [[ -f "$TEST_DIR/test_common.sh" ]]; then
            benchmark_function "test_platform_detection" "$TEST_DIR/test_common.sh" 5
            benchmark_function "test_file_operations" "$TEST_DIR/test_common.sh" 5
        fi

        echo
    fi

    # Code coverage
    if $COVERAGE_REPORT; then
        echo "📊 Generating code coverage report"
        echo "================================="
        generate_coverage_report
        echo
    fi
}

# Show final test results
show_test_summary() {
    echo "📋 Test Summary"
    echo "==============="
    echo "Total test suites: $TOTAL_SUITES"
    echo "Passed: $PASSED_SUITES"
    echo "Failed: $FAILED_SUITES"

    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo "Result: ✅ ALL TESTS PASSED"
        echo
        echo "🎉 Congratulations! All tests are passing."
        echo "The dotfiles repository is in good shape."
    else
        echo "Result: ❌ SOME TESTS FAILED"
        echo
        echo "💡 Please review the failed tests above and fix any issues."
        echo "Run with -v flag for more detailed output."
    fi

    echo
    echo "To run specific test categories:"
    echo "  • Code quality: $0 --coverage"
    echo "  • Performance:  $0 --benchmark"
    echo "  • All options:  $0 --verbose --coverage --benchmark"
}

# Cleanup function
cleanup_test_runner() {
    # Clean up any temporary files created during testing
    if [[ -n "${TEST_RUNNER_TEMP:-}" && -d "$TEST_RUNNER_TEMP" ]]; then
        rm -rf "$TEST_RUNNER_TEMP"
    fi
}

# Set up cleanup trap
trap cleanup_test_runner EXIT INT TERM

# Main execution
main() {
    parse_test_arguments "$@"

    # Validate test environment
    if [[ ! -d "$TEST_DIR" ]]; then
        echo "❌ Test directory not found: $TEST_DIR" >&2
        exit 1
    fi

    # Change to test directory
    cd "$TEST_DIR"

    # Run all tests
    run_all_test_suites

    # Show summary
    show_test_summary

    # Exit with failure if any tests failed
    if [[ $FAILED_SUITES -gt 0 ]]; then
        exit 1
    fi
}

# Run main function with all arguments
main "$@"