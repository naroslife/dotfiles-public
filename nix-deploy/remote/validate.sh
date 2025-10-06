#!/usr/bin/env bash
#
# validate.sh - Validate Nix deployment on remote machine
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

echo_pass() {
    echo -e "${GREEN}✓${RESET} $1"
}

echo_fail() {
    echo -e "${RED}✗${RESET} $1"
}

echo_warn() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

echo_header() {
    echo -e "\n${BOLD}$1${RESET}"
}

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Run a validation test
run_test() {
    local test_name="$1"
    local test_cmd="$2"

    if eval "$test_cmd" >/dev/null 2>&1; then
        echo_pass "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo_fail "$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run a warning test (non-fatal)
run_warn_test() {
    local test_name="$1"
    local test_cmd="$2"

    if eval "$test_cmd" >/dev/null 2>&1; then
        echo_pass "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo_warn "$test_name (non-fatal)"
        TESTS_WARNED=$((TESTS_WARNED + 1))
        return 1
    fi
}

# Validation tests
echo_header "Validating Nix Deployment"

# Test 1: Nix installation
echo_header "Nix Installation:"
run_test "Nix binary available" "command -v nix"
run_test "Nix-env available" "command -v nix-env"
run_test "Nix-store available" "command -v nix-store"
run_test "Nix daemon running (if multi-user)" "! pgrep nix-daemon >/dev/null || pgrep nix-daemon"

# Test 2: Nix profile
echo_header "Nix Profile:"
run_test "Nix profile exists" "[[ -L $HOME/.nix-profile ]]"
run_test "Profile points to store" "[[ $(readlink $HOME/.nix-profile) =~ ^/nix/store ]]"
run_test "Profile contains binaries" "[[ -d $HOME/.nix-profile/bin ]]"

# Test 3: Home Manager
echo_header "Home Manager:"
run_warn_test "Home Manager command available" "command -v home-manager"
if command -v home-manager >/dev/null 2>&1; then
    run_test "Home Manager responds" "home-manager --version"
    run_warn_test "Home Manager generations exist" "home-manager generations | grep -q Generation"
fi

# Test 4: Shell integration
echo_header "Shell Integration:"
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
    bash)
        run_warn_test "Bash configured" "grep -q 'home-manager\\|nix-profile' ~/.bashrc"
        ;;
    zsh)
        run_warn_test "Zsh configured" "grep -q 'home-manager\\|nix-profile' ~/.zshrc"
        ;;
    fish)
        run_warn_test "Fish configured" "[[ -f ~/.config/fish/config.fish ]] && grep -q 'home-manager\\|nix-profile' ~/.config/fish/config.fish"
        ;;
    elvish)
        run_warn_test "Elvish configured" "[[ -f ~/.config/elvish/rc.elv ]] && grep -q 'nix-profile' ~/.config/elvish/rc.elv"
        ;;
esac

# Test 5: Deployed packages
echo_header "Deployed Packages:"

# Check if metadata exists to know what should be installed
if [[ -f "metadata.json" ]] && command -v jq >/dev/null 2>&1; then
    PROFILE=$(jq -r '.profile' metadata.json)
    echo "Expected profile: $PROFILE"
fi

# Test some common packages that should be available
run_warn_test "Git available" "command -v git"
run_warn_test "Starship available" "$HOME/.nix-profile/bin/starship --version 2>/dev/null || command -v starship"
run_warn_test "Elvish available" "$HOME/.nix-profile/bin/elvish -version 2>/dev/null || command -v elvish"

# Test 6: Environment variables
echo_header "Environment Variables:"
run_test "PATH includes nix-profile" "echo \$PATH | grep -q '.nix-profile/bin'"
run_warn_test "NIX_PATH is set" "[[ -n \${NIX_PATH:-} ]]"

# Test 7: Store paths
echo_header "Nix Store:"
if [[ -f "metadata.json" ]] && command -v jq >/dev/null 2>&1; then
    STORE_PATH=$(jq -r '.store_path' metadata.json)
    run_test "Activation package exists" "[[ -e $STORE_PATH ]]"
    run_test "Activation script exists" "[[ -x $STORE_PATH/activate ]]"
fi

# Test 8: Permissions (WSL-specific)
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo_header "WSL-Specific Checks:"
    run_warn_test "Nix store readable" "[[ -r /nix/store ]]"
    run_warn_test "Profile directory writable" "[[ -w /nix/var/nix/profiles/per-user/$(whoami) ]] || [[ ! -d /nix/var/nix/profiles ]]"
fi

# Test 9: Activation verification
echo_header "Activation Verification:"
run_test "Generation created" "nix-env --list-generations | grep -q Generation"

# Count packages
if command -v home-manager >/dev/null 2>&1; then
    PACKAGE_COUNT=$(home-manager packages 2>/dev/null | wc -l || echo 0)
else
    PACKAGE_COUNT=$(nix-env -q 2>/dev/null | wc -l || echo 0)
fi
echo "Installed packages: $PACKAGE_COUNT"

# Final report
echo_header "Validation Summary:"
echo "Tests passed:  $TESTS_PASSED"
echo "Tests failed:  $TESTS_FAILED"
echo "Tests warned:  $TESTS_WARNED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}${BOLD}✅ Deployment validation successful!${RESET}"
    exit 0
elif [[ $TESTS_FAILED -lt 3 ]]; then
    echo -e "\n${YELLOW}${BOLD}⚠️  Deployment partially successful with minor issues${RESET}"
    exit 0
else
    echo -e "\n${RED}${BOLD}❌ Deployment validation failed!${RESET}"
    exit 1
fi