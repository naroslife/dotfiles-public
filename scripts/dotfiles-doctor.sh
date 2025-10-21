#!/usr/bin/env bash
# Comprehensive health check for dotfiles installation
# Verifies installation status, configurations, and performance

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Constants
readonly CHECK_PASS="${COLOR_GREEN}✓${COLOR_NC}"
readonly CHECK_WARN="${COLOR_YELLOW}⚠${COLOR_NC}"
readonly CHECK_FAIL="${COLOR_RED}✗${COLOR_NC}"

# Tracking variables
declare -i total_checks=0
declare -i passed_checks=0
declare -i warned_checks=0
declare -a recommendations=()

# Check result functions
check_pass() {
    local message="$1"
    echo -e "$CHECK_PASS $message"
    ((total_checks++))
    ((passed_checks++))
}

check_warn() {
    local message="$1"
    local recommendation="${2:-}"
    echo -e "$CHECK_WARN $message"
    ((total_checks++))
    ((warned_checks++))
    [[ -n "$recommendation" ]] && recommendations+=("$recommendation")
}

check_fail() {
    local message="$1"
    local recommendation="${2:-}"
    echo -e "$CHECK_FAIL $message"
    ((total_checks++))
    [[ -n "$recommendation" ]] && recommendations+=("$recommendation")
}

# Individual check functions
check_nix_installation() {
    if command -v nix >/dev/null 2>&1; then
        local nix_version_full
        local nix_version
        nix_version_full=$(nix --version 2>/dev/null || echo "unknown")

        # Handle different nix version formats
        # Format 1: "nix (Nix) 2.18.1"
        # Format 2: "nix (Determinate Nix 3.11.3) 2.31.2"
        if [[ "$nix_version_full" =~ ([0-9]+\.[0-9]+\.[0-9]+)[^0-9]*$ ]]; then
            nix_version="${BASH_REMATCH[1]}"
        else
            nix_version="unknown"
        fi

        # Check for minimum version (2.10.0 or higher recommended)
        if [[ "$nix_version" == "unknown" ]]; then
            check_warn "Nix installed (version detection failed: $nix_version_full)" "Run: nix --version to verify"
        else
            local major_version="${nix_version%%.*}"
            local minor_version="${nix_version#*.}"
            minor_version="${minor_version%%.*}"

            # Ensure we have numeric values
            if [[ "$major_version" =~ ^[0-9]+$ ]] && [[ "$minor_version" =~ ^[0-9]+$ ]]; then
                if [[ "$major_version" -gt 2 ]] || [[ "$major_version" -eq 2 && "$minor_version" -ge 10 ]]; then
                    check_pass "Nix installed (version $nix_version)"
                else
                    check_warn "Nix installed (version $nix_version, 2.10+ recommended)" \
                        "Update Nix: nix upgrade-nix"
                fi
            else
                check_warn "Nix installed (version parsing failed: $nix_version)" "Version format unexpected"
            fi
        fi
    else
        check_fail "Nix not installed" \
            "Install Nix: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    fi
}

check_flakes_enabled() {
    if command -v nix >/dev/null 2>&1; then
        local nix_conf="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"

        if [[ -f "$nix_conf" ]] && grep -q "experimental-features.*flakes" "$nix_conf" 2>/dev/null; then
            check_pass "Flakes enabled"
        else
            check_fail "Flakes not enabled" \
                "Add to $nix_conf: experimental-features = nix-command flakes"
        fi
    else
        check_fail "Cannot check flakes (Nix not installed)"
    fi
}

check_home_manager() {
    if command -v home-manager >/dev/null 2>&1; then
        local hm_version
        hm_version=$(home-manager --version 2>/dev/null | head -1 || echo "unknown")
        check_pass "Home Manager available (version $hm_version)"
    else
        # Check if it's available via nix run
        if command -v nix >/dev/null 2>&1 && nix run home-manager/master -- --version &>/dev/null; then
            check_pass "Home Manager available (via nix run)"
        else
            check_fail "Home Manager not available" \
                "Install: nix run home-manager/master -- init"
        fi
    fi
}

check_git_configuration() {
    local git_user git_email

    if command -v git >/dev/null 2>&1; then
        git_user=$(git config --global user.name 2>/dev/null || echo "")
        git_email=$(git config --global user.email 2>/dev/null || echo "")

        if [[ -n "$git_user" && -n "$git_email" ]]; then
            check_pass "Git configured (user: $git_user)"
        elif [[ -n "$git_user" || -n "$git_email" ]]; then
            check_warn "Git partially configured" \
                "Configure: git config --global user.name 'Your Name' && git config --global user.email 'your@email.com'"
        else
            check_fail "Git not configured" \
                "Configure: git config --global user.name 'Your Name' && git config --global user.email 'your@email.com'"
        fi
    else
        check_fail "Git not installed" \
            "Install git: sudo apt install git (Ubuntu/Debian) or brew install git (macOS)"
    fi
}

check_required_tools() {
    local tools=("bat" "eza" "rg" "fd" "fzf" "zoxide" "atuin" "starship" "carapace")
    local missing_tools=()
    local installed_count=0

    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            ((installed_count++))
        else
            missing_tools+=("$tool")
        fi
    done

    if [[ $installed_count -eq ${#tools[@]} ]]; then
        check_pass "All required tools in PATH (${#tools[@]}/${#tools[@]})"
    elif [[ $installed_count -gt $((${#tools[@]} / 2)) ]]; then
        check_warn "Most tools in PATH ($installed_count/${#tools[@]}, missing: ${missing_tools[*]})" \
            "Run: ./apply.sh to install missing tools"
    else
        check_fail "Many tools missing ($installed_count/${#tools[@]}, missing: ${missing_tools[*]})" \
            "Run: ./apply.sh to install dotfiles"
    fi
}

check_wsl_optimizations() {
    if is_wsl; then
        # Check if WSL-specific optimizations are applied
        local wsl_conf="/etc/wsl.conf"
        local has_systemd=false
        local has_interop=false
        local has_append_path=false
        local has_automount=false
        local has_metadata=false
        local missing_settings=()

        if [[ -f "$wsl_conf" ]]; then
            # Use section-aware parsing to avoid false positives
            grep -A5 "^\[boot\]" "$wsl_conf" 2>/dev/null | grep -q "systemd.*true" && has_systemd=true
            grep -A5 "^\[interop\]" "$wsl_conf" 2>/dev/null | grep -q "enabled.*true" && has_interop=true
            grep -A5 "^\[interop\]" "$wsl_conf" 2>/dev/null | grep -q "appendWindowsPath.*true" && has_append_path=true
            grep -A5 "^\[automount\]" "$wsl_conf" 2>/dev/null | grep -q "enabled.*true" && has_automount=true
            grep -A5 "^\[automount\]" "$wsl_conf" 2>/dev/null | grep -q "metadata" && has_metadata=true

            # Track missing settings
            $has_systemd || missing_settings+=("systemd")
            $has_interop || missing_settings+=("interop enabled")
            $has_append_path || missing_settings+=("appendWindowsPath")
            $has_automount || missing_settings+=("automount section")
            $has_metadata || missing_settings+=("metadata option")
        else
            missing_settings=("wsl.conf file not found")
        fi

        # Check clipboard aliases
        local has_clipboard=false
        if command -v pbcopy >/dev/null 2>&1 || alias pbcopy &>/dev/null; then
            has_clipboard=true
        fi

        # Check Windows PATH integration
        local has_windows_path=false
        if command -v clip.exe >/dev/null 2>&1; then
            has_windows_path=true
        fi

        # Determine overall status
        if $has_systemd && $has_interop && $has_append_path && $has_automount && $has_metadata && $has_clipboard && $has_windows_path; then
            check_pass "WSL fully optimized (interop, automount, clipboard, Windows PATH)"
        elif [[ ${#missing_settings[@]} -gt 0 ]]; then
            local missing_str="${missing_settings[*]}"
            check_warn "WSL configuration incomplete (missing: ${missing_str})" \
                "See docs/WSL_SETUP.md for proper /etc/wsl.conf configuration"
        elif $has_clipboard; then
            check_warn "WSL partially optimized (clipboard configured)" \
                "See docs/WSL_SETUP.md for complete setup"
        else
            check_warn "WSL optimizations not fully applied" \
                "See docs/WSL_SETUP.md for setup instructions"
        fi
    fi
}

check_shell_startup_performance() {
    local shell="${SHELL##*/}"
    local startup_time_ms=0

    # Measure shell startup time
    if [[ "$shell" == "bash" ]] || [[ "$shell" == "zsh" ]]; then
        local start_ns end_ns
        start_ns=$(date +%s%N)
        $SHELL -i -c 'exit' 2>/dev/null
        end_ns=$(date +%s%N)
        startup_time_ms=$(( (end_ns - start_ns) / 1000000 ))
    else
        # For other shells, skip the check
        check_warn "Shell startup performance (cannot measure for $shell)"
        return
    fi

    if [[ $startup_time_ms -lt 300 ]]; then
        check_pass "Shell startup performance (${startup_time_ms}ms, excellent)"
    elif [[ $startup_time_ms -lt 500 ]]; then
        check_warn "Shell startup slow (${startup_time_ms}ms, recommended <300ms)" \
            "Run: ./scripts/dotfiles-profiler.sh to identify bottlenecks"
    else
        check_fail "Shell startup very slow (${startup_time_ms}ms, recommended <300ms)" \
            "Run: ./scripts/dotfiles-profiler.sh to identify bottlenecks"
    fi
}

check_disk_space() {
    local home_free_gb nix_free_gb

    # Check home directory space
    if command -v df >/dev/null 2>&1; then
        home_free_gb=$(df -BG "$HOME" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')

        if [[ -d /nix ]]; then
            nix_free_gb=$(df -BG /nix 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
        else
            nix_free_gb=$home_free_gb  # Assume same filesystem
        fi

        if [[ ${home_free_gb:-0} -gt 10 ]] && [[ ${nix_free_gb:-0} -gt 10 ]]; then
            check_pass "Disk space adequate (Home: ${home_free_gb}GB, Nix: ${nix_free_gb}GB free)"
        elif [[ ${home_free_gb:-0} -gt 5 ]] && [[ ${nix_free_gb:-0} -gt 5 ]]; then
            check_warn "Disk space low (Home: ${home_free_gb}GB, Nix: ${nix_free_gb}GB free, >10GB recommended)" \
                "Run: nix-collect-garbage -d to free space"
        else
            check_fail "Disk space critical (Home: ${home_free_gb}GB, Nix: ${nix_free_gb}GB free, >5GB required)" \
                "Run: nix-collect-garbage -d && nix store optimise"
        fi
    else
        check_warn "Cannot check disk space (df command not available)"
    fi
}

check_network_connectivity() {
    local cache_url="https://cache.nixos.org"
    local github_url="https://github.com"
    local can_reach_cache=false
    local can_reach_github=false

    # Check cache.nixos.org
    if curl -fsS --connect-timeout 5 --max-time 10 -o /dev/null "$cache_url" 2>/dev/null; then
        can_reach_cache=true
    fi

    # Check github.com
    if curl -fsS --connect-timeout 5 --max-time 10 -o /dev/null "$github_url" 2>/dev/null; then
        can_reach_github=true
    fi

    if $can_reach_cache && $can_reach_github; then
        check_pass "Network connectivity OK (cache.nixos.org, github.com)"
    elif $can_reach_cache || $can_reach_github; then
        check_warn "Partial network connectivity" \
            "Check firewall/proxy settings"
    else
        check_fail "No network connectivity to required services" \
            "Check internet connection and proxy settings"
    fi
}

check_nix_channels() {
    if command -v nix >/dev/null 2>&1; then
        local channel_count
        channel_count=$(nix-channel --list 2>/dev/null | wc -l)

        if [[ $channel_count -gt 0 ]]; then
            check_pass "Nix channels configured ($channel_count channels)"
        else
            # In flake-based setups, channels might not be needed
            if [[ -f "${ROOT_DIR}/flake.nix" ]]; then
                check_pass "Nix channels not needed (flake-based setup)"
            else
                check_warn "No Nix channels configured" \
                    "Add channel: nix-channel --add https://nixos.org/channels/nixpkgs-unstable"
            fi
        fi
    fi
}

check_home_manager_generation() {
    if command -v home-manager >/dev/null 2>&1; then
        local generations
        generations=$(home-manager generations 2>/dev/null | head -1 || echo "")

        if [[ -n "$generations" ]]; then
            check_pass "Home Manager generation active"
        else
            check_warn "No Home Manager generations found" \
                "Run: ./apply.sh to create initial generation"
        fi
    fi
}

# Main function
main() {
    echo -e "${COLOR_CYAN}=== Dotfiles Health Check ===${COLOR_NC}"
    echo

    # Run all checks
    check_nix_installation
    check_flakes_enabled
    check_home_manager
    check_required_tools
    check_git_configuration

    # WSL-specific check
    if is_wsl; then
        check_wsl_optimizations
    fi

    check_shell_startup_performance
    check_disk_space
    check_network_connectivity
    check_nix_channels
    check_home_manager_generation

    # Summary
    echo
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"

    local failed_checks=$((total_checks - passed_checks - warned_checks))
    local status_color="$COLOR_GREEN"
    local status_text="HEALTHY"

    if [[ $failed_checks -gt 0 ]]; then
        status_color="$COLOR_RED"
        status_text="NEEDS ATTENTION"
    elif [[ $warned_checks -gt 0 ]]; then
        status_color="$COLOR_YELLOW"
        status_text="MOSTLY HEALTHY"
    fi

    echo -e "${status_color}Overall Status: $status_text${COLOR_NC}"
    echo -e "Checks: ${COLOR_GREEN}$passed_checks passed${COLOR_NC}, ${COLOR_YELLOW}$warned_checks warnings${COLOR_NC}, ${COLOR_RED}$failed_checks failed${COLOR_NC} (Total: $total_checks)"

    # Show recommendations if any
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        echo
        echo -e "${COLOR_CYAN}Recommendations:${COLOR_NC}"
        for rec in "${recommendations[@]}"; do
            echo "  • $rec"
        done
    fi

    # Exit code based on health
    if [[ $failed_checks -gt 0 ]]; then
        exit 1
    elif [[ $warned_checks -gt 0 ]]; then
        exit 0  # Warnings don't fail the check
    else
        exit 0
    fi
}

# Run main function
main "$@"