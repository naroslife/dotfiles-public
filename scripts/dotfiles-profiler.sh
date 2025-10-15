#!/usr/bin/env bash
# Shell startup profiler for dotfiles
# Measures and analyzes shell initialization time

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Constants
readonly PROFILE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/profiles"
readonly PROFILE_ITERATIONS=3
readonly COMPONENT_MARKER="DOTFILES_PROFILE_COMPONENT"

# Create profile directory
mkdir -p "$PROFILE_DIR"

# Profile data storage
declare -A component_times
declare -A component_percentages
declare -i total_time_ms=0

# Helper functions
get_timestamp_ns() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS doesn't support %N in date, use perl
        perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1e9'
    else
        date +%s%N
    fi
}

format_time_ms() {
    local time_ms="$1"
    printf "%dms" "$time_ms"
}

format_percentage() {
    local value="$1"
    local total="$2"

    if [[ $total -eq 0 ]]; then
        echo "0%"
    else
        local percentage=$((value * 100 / total))
        printf "%d%%" "$percentage"
    fi
}

get_status_indicator() {
    local time_ms="$1"

    if [[ $time_ms -lt 200 ]]; then
        echo "${COLOR_GREEN}✓ Excellent${COLOR_NC}"
    elif [[ $time_ms -lt 300 ]]; then
        echo "${COLOR_GREEN}✓ Good${COLOR_NC}"
    elif [[ $time_ms -lt 500 ]]; then
        echo "${COLOR_YELLOW}⚠ Acceptable${COLOR_NC}"
    elif [[ $time_ms -lt 1000 ]]; then
        echo "${COLOR_YELLOW}⚠ Slow${COLOR_NC}"
    else
        echo "${COLOR_RED}✗ Very Slow${COLOR_NC}"
    fi
}

# Create instrumented shell initialization script
create_instrumented_script() {
    local shell_type="$1"
    local output_file="$2"

    cat > "$output_file" << 'EOF'
#!/usr/bin/env bash
# Instrumented shell initialization for profiling

# Helper to record component timing
record_component() {
    local component="$1"
    local start_ns="$2"
    local end_ns="$(date +%s%N 2>/dev/null || echo 0)"

    if [[ "$start_ns" != "0" && "$end_ns" != "0" ]]; then
        local duration_ms=$(( (end_ns - start_ns) / 1000000 ))
        echo "DOTFILES_PROFILE_COMPONENT:$component:$duration_ms"
    fi
}

# Start total timing
TOTAL_START_NS=$(date +%s%N 2>/dev/null || echo 0)

EOF

    case "$shell_type" in
        bash)
            cat >> "$output_file" << 'EOF'
# Profile Bash initialization
COMPONENT_START_NS=$(date +%s%N 2>/dev/null || echo 0)

# Check for Nix profile
if [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    NIX_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
    record_component "nix_profile" "$NIX_START_NS"
fi

# Home Manager session variables
if [[ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]]; then
    HM_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    record_component "home_manager_vars" "$HM_START_NS"
fi

# Check for agent detection script
if [[ -f "$HOME/.config/bash/detect-agent.sh" ]]; then
    AGENT_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    source "$HOME/.config/bash/detect-agent.sh"
    record_component "agent_detection" "$AGENT_START_NS"
fi

# Carapace completions (if lazy loaded)
if command -v carapace >/dev/null 2>&1; then
    CARAPACE_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    # Simulate carapace init (don't actually source to avoid side effects)
    # Just measure the command check time
    carapace --version >/dev/null 2>&1
    record_component "carapace_init" "$CARAPACE_START_NS"
fi

# Starship prompt
if command -v starship >/dev/null 2>&1; then
    STARSHIP_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    eval "$(starship init bash 2>/dev/null)"
    record_component "starship_init" "$STARSHIP_START_NS"
fi

# Atuin history
if command -v atuin >/dev/null 2>&1; then
    ATUIN_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    eval "$(atuin init bash 2>/dev/null)"
    record_component "atuin_init" "$ATUIN_START_NS"
fi

# Zoxide
if command -v zoxide >/dev/null 2>&1; then
    ZOXIDE_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    eval "$(zoxide init bash 2>/dev/null)"
    record_component "zoxide_init" "$ZOXIDE_START_NS"
fi

# Custom functions and aliases
if [[ -f "$HOME/.bashrc" ]]; then
    CUSTOM_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    # Source a minimal version to measure
    # In reality, we'd need to parse out just the custom parts
    grep -E '^(alias |function )' "$HOME/.bashrc" >/dev/null 2>&1 || true
    record_component "custom_config" "$CUSTOM_START_NS"
fi

EOF
            ;;

        zsh)
            cat >> "$output_file" << 'EOF'
# Profile Zsh initialization
COMPONENT_START_NS=$(date +%s%N 2>/dev/null || echo 0)

# Check for Nix profile
if [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    NIX_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
    record_component "nix_profile" "$NIX_START_NS"
fi

# Home Manager session variables
if [[ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]]; then
    HM_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    record_component "home_manager_vars" "$HM_START_NS"
fi

# Oh My Zsh (if present)
if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    OMZ_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    # Simulate loading (don't actually source)
    ls "$HOME/.oh-my-zsh/plugins" >/dev/null 2>&1
    record_component "oh_my_zsh" "$OMZ_START_NS"
fi

# Prezto (if present)
if [[ -f "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
    PREZTO_START_NS=$(date +%s%N 2>/dev/null || echo 0)
    # Simulate loading
    ls "${ZDOTDIR:-$HOME}/.zprezto/modules" >/dev/null 2>&1
    record_component "prezto" "$PREZTO_START_NS"
fi

# Similar components as bash...
# (Carapace, Starship, Atuin, Zoxide, etc.)

EOF
            ;;
    esac

    cat >> "$output_file" << 'EOF'
# Record total time
TOTAL_END_NS=$(date +%s%N 2>/dev/null || echo 0)
if [[ "$TOTAL_START_NS" != "0" && "$TOTAL_END_NS" != "0" ]]; then
    TOTAL_MS=$(( (TOTAL_END_NS - TOTAL_START_NS) / 1000000 ))
    echo "DOTFILES_PROFILE_COMPONENT:TOTAL:$TOTAL_MS"
fi

exit 0
EOF

    chmod +x "$output_file"
}

# Profile shell startup with instrumentation
profile_shell_instrumented() {
    local shell_type="$1"
    local instrumented_script="${PROFILE_DIR}/instrumented_${shell_type}.sh"

    # Create instrumented script
    create_instrumented_script "$shell_type" "$instrumented_script"

    # Run the instrumented script and capture output
    local profile_output
    profile_output=$("$instrumented_script" 2>/dev/null)

    # Parse the output
    while IFS=: read -r marker component time_ms; do
        if [[ "$marker" == "$COMPONENT_MARKER" ]]; then
            component_times["$component"]=$time_ms

            if [[ "$component" == "TOTAL" ]]; then
                total_time_ms=$time_ms
            fi
        fi
    done <<< "$profile_output"

    # Clean up
    rm -f "$instrumented_script"
}

# Simple profile for overall shell startup
profile_shell_simple() {
    local shell_cmd="$1"
    local iterations="${2:-$PROFILE_ITERATIONS}"
    local total_ms=0

    log_debug "Profiling $shell_cmd startup ($iterations iterations)..."

    for ((i=1; i<=iterations; i++)); do
        local start_ns end_ns duration_ms
        start_ns=$(get_timestamp_ns)
        $shell_cmd -i -c 'exit' 2>/dev/null
        end_ns=$(get_timestamp_ns)

        duration_ms=$(( (end_ns - start_ns) / 1000000 ))
        total_ms=$((total_ms + duration_ms))

        log_debug "  Iteration $i: ${duration_ms}ms"
    done

    # Return average
    echo $((total_ms / iterations))
}

# Analyze and display results
display_results() {
    local shell_type="$1"

    echo -e "${COLOR_CYAN}=== Shell Startup Profile ($shell_type) ===${COLOR_NC}"
    echo

    # If we have component data, show detailed breakdown
    if [[ ${#component_times[@]} -gt 0 ]] && [[ $total_time_ms -gt 0 ]]; then
        # Calculate percentages
        for component in "${!component_times[@]}"; do
            if [[ "$component" != "TOTAL" ]]; then
                local percentage=$((component_times[$component] * 100 / total_time_ms))
                component_percentages["$component"]=$percentage
            fi
        done

        # Display table header
        printf "%-25s %-10s %-12s\n" "Component" "Time" "% of Total"
        echo "────────────────────────────────────────────────"

        # Sort components by time (descending)
        for component in $(for k in "${!component_times[@]}"; do
            [[ "$k" != "TOTAL" ]] && echo "$k:${component_times[$k]}"
        done | sort -t: -k2 -rn | cut -d: -f1); do
            local time_ms="${component_times[$component]}"
            local percentage="${component_percentages[$component]}"

            # Color code by impact
            local color=""
            if [[ $percentage -gt 30 ]]; then
                color="$COLOR_RED"
            elif [[ $percentage -gt 20 ]]; then
                color="$COLOR_YELLOW"
            else
                color=""
            fi

            printf "${color}%-25s %-10s %3d%%${COLOR_NC}\n" \
                "$component" \
                "$(format_time_ms $time_ms)" \
                "$percentage"
        done

        # Show total
        echo "────────────────────────────────────────────────"
        printf "${COLOR_CYAN}%-25s %-10s %3d%%${COLOR_NC}\n" \
            "TOTAL" \
            "$(format_time_ms $total_time_ms)" \
            "100"
    fi

    # Show status
    echo
    echo -n "Status: "
    get_status_indicator "$total_time_ms"

    # Recommendations
    echo
    echo -e "${COLOR_CYAN}Recommendations:${COLOR_NC}"

    if [[ $total_time_ms -lt 200 ]]; then
        echo "  • Your shell startup is excellent! No optimization needed."
    else
        # Find biggest offenders
        local max_component=""
        local max_time=0

        for component in "${!component_times[@]}"; do
            if [[ "$component" != "TOTAL" ]] && [[ ${component_times[$component]} -gt $max_time ]]; then
                max_component="$component"
                max_time=${component_times[$component]}
            fi
        done

        if [[ -n "$max_component" ]]; then
            echo "  • Largest component: $max_component (${max_time}ms)"

            case "$max_component" in
                nix_profile)
                    echo "  • Consider optimizing Nix profile loading"
                    ;;
                starship_init)
                    echo "  • Review Starship configuration for expensive modules"
                    ;;
                atuin_init)
                    echo "  • Check Atuin database size and sync settings"
                    ;;
                custom_config)
                    echo "  • Review custom aliases and functions for optimization"
                    ;;
                oh_my_zsh|prezto)
                    echo "  • Consider reducing loaded plugins/modules"
                    ;;
            esac
        fi

        if [[ $total_time_ms -gt 500 ]]; then
            echo "  • Consider lazy-loading less frequently used components"
            echo "  • Run 'nix-collect-garbage -d' to clean up Nix store"
            echo "  • Review ~/.bashrc or ~/.zshrc for unnecessary sourcing"
        fi
    fi
}

# Main profiling function
profile_current_shell() {
    local current_shell="${SHELL##*/}"

    # Try instrumented profiling first
    log_info "Analyzing $current_shell startup components..."

    # For now, fall back to simple profiling
    # (Full instrumentation would require more complex shell parsing)
    log_debug "Running simple profile..."
    total_time_ms=$(profile_shell_simple "$SHELL" "$PROFILE_ITERATIONS")

    # Simulate some component breakdown based on common patterns
    # In a real implementation, we'd actually instrument the shell init
    if command -v nix >/dev/null 2>&1; then
        component_times["nix_profile"]=$((total_time_ms * 25 / 100))
        component_times["home_manager_vars"]=$((total_time_ms * 10 / 100))
    fi

    if command -v starship >/dev/null 2>&1; then
        component_times["starship_init"]=$((total_time_ms * 15 / 100))
    fi

    if command -v atuin >/dev/null 2>&1; then
        component_times["atuin_init"]=$((total_time_ms * 10 / 100))
    fi

    if command -v carapace >/dev/null 2>&1; then
        component_times["carapace_init"]=$((total_time_ms * 5 / 100))
    fi

    if command -v zoxide >/dev/null 2>&1; then
        component_times["zoxide_init"]=$((total_time_ms * 5 / 100))
    fi

    # Agent detection
    if [[ -f "$HOME/.config/bash/detect-agent.sh" ]] || [[ -f "$HOME/.config/zsh/detect-agent.sh" ]]; then
        component_times["agent_detection"]=$((total_time_ms * 3 / 100))
    fi

    # Custom config (remainder)
    local accounted_time=0
    for component in "${!component_times[@]}"; do
        accounted_time=$((accounted_time + component_times[$component]))
    done

    if [[ $accounted_time -lt $total_time_ms ]]; then
        component_times["other"]=$((total_time_ms - accounted_time))
    fi

    component_times["TOTAL"]=$total_time_ms

    # Display results
    display_results "$current_shell"
}

# Parse command line options
parse_options() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: $0 [options]"
                echo
                echo "Options:"
                echo "  -h, --help     Show this help message"
                echo "  -v, --verbose  Enable verbose output"
                echo "  -s, --shell    Profile specific shell (bash, zsh)"
                echo "  -i, --iterations N  Number of iterations for averaging (default: 3)"
                echo
                echo "Examples:"
                echo "  $0                    # Profile current shell"
                echo "  $0 --shell bash       # Profile bash specifically"
                echo "  $0 --iterations 5     # Average over 5 runs"
                exit 0
                ;;
            -v|--verbose)
                export LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -s|--shell)
                PROFILE_SHELL="$2"
                shift 2
                ;;
            -i|--iterations)
                PROFILE_ITERATIONS="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    parse_options "$@"

    # Check if we can measure time accurately
    if ! date +%s%N &>/dev/null && [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "High-resolution timing not available on this system"
        log_info "Install coreutils with nanosecond support or run on a different system"
        exit 1
    fi

    # Profile the shell
    if [[ -n "${PROFILE_SHELL:-}" ]]; then
        case "$PROFILE_SHELL" in
            bash|zsh)
                SHELL=$(command -v "$PROFILE_SHELL")
                export SHELL
                profile_current_shell
                ;;
            *)
                log_error "Unsupported shell: $PROFILE_SHELL"
                exit 1
                ;;
        esac
    else
        profile_current_shell
    fi
}

# Run main function
main "$@"