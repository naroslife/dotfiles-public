#!/usr/bin/env bash

# Configuration Consistency Validator
# Checks for consistency of aliases and functions across Bash, Zsh, and Elvish shells
# Ensures all shells have compatible implementations of common commands

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Track overall status
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
FAILURES=0

# Arrays to store extracted configurations
declare -A BASH_ALIASES
declare -A ZSH_ALIASES
declare -A ELVISH_ALIASES
declare -A WSL_BASH_ALIASES
declare -A WSL_ZSH_ALIASES

declare -A BASH_FUNCTIONS
declare -A ZSH_FUNCTIONS
declare -A ELVISH_FUNCTIONS

# Smart aliases that should use agent detection
SMART_ALIASES=("cat" "ls" "ll" "la" "l" "lt" "ltree" "grep" "find")

# Git aliases that should be consistent
GIT_ALIASES=("gc" "gca" "gp" "gpu" "gst" "glog" "gdiff" "gco" "gb" "gba" "gadd" "ga" "gcoall" "gr" "gre" "gd" "gdt")

# Core functions that should be available in all shells
CORE_FUNCTIONS=("is-agent-context" "npm-clean" "pip-clean" "cargo-clean" "venv")

# Find dotfiles root (parent of lib directory)
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Function to print section headers
print_header() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${RESET}"
}

# Function to print check results
print_check() {
    local status="$1"
    local message="$2"
    local details="${3:-}"

    ((TOTAL_CHECKS++)) || true

    case "$status" in
        "pass")
            echo -e "  ${GREEN}✓${RESET} $message"
            ((PASSED_CHECKS++)) || true
            ;;
        "warn")
            echo -e "  ${YELLOW}⚠${RESET} $message"
            ((WARNINGS++)) || true
            if [[ -n "$details" ]]; then
                echo -e "    ${CYAN}→ $details${RESET}"
            fi
            ;;
        "fail")
            echo -e "  ${RED}✗${RESET} $message"
            ((FAILURES++)) || true
            if [[ -n "$details" ]]; then
                echo -e "    ${CYAN}→ $details${RESET}"
            fi
            ;;
    esac
}

# Extract aliases from aliases.nix (common aliases)
extract_nix_common_aliases() {
    local alias_file="$DOTFILES_ROOT/modules/shells/aliases.nix"

    if [[ ! -f "$alias_file" ]]; then
        echo -e "${YELLOW}Warning: aliases.nix not found at $alias_file${RESET}" >&2
        return
    fi

    # Extract commonAliases block
    local in_block=false
    local alias_name=""
    local alias_value=""

    while IFS= read -r line; do
        # Check if we're entering the commonAliases block
        if [[ "$line" =~ ^[[:space:]]*commonAliases[[:space:]]*=[[:space:]]*\{ ]]; then
            in_block=true
            continue
        fi

        # Check if we're leaving the block (closing brace at the start of line)
        if [[ "$in_block" == true && "$line" =~ ^\}[[:space:]]*\;?[[:space:]]*$ ]]; then
            break
        fi

        # Extract alias definitions within the block
        if [[ "$in_block" == true ]]; then
            # Match pattern: alias_name = "command";
            if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_.-]+)[[:space:]]*=[[:space:]]*\"([^\"]*)\"\;?[[:space:]]*$ ]]; then
                alias_name="${BASH_REMATCH[1]}"
                alias_value="${BASH_REMATCH[2]}"
                # Store for both bash and zsh (they share commonAliases)
                BASH_ALIASES["$alias_name"]="$alias_value"
                ZSH_ALIASES["$alias_name"]="$alias_value"
            fi
        fi
    done < "$alias_file"
}

# Extract WSL-specific aliases
extract_wsl_aliases() {
    local wsl_file="$DOTFILES_ROOT/modules/wsl.nix"

    if [[ ! -f "$wsl_file" ]]; then
        return  # WSL module may not exist in all setups
    fi

    # Extract bash aliases from WSL module
    local in_bash_block=false
    local in_zsh_block=false

    while IFS= read -r line; do
        # Check for bash alias block
        if [[ "$line" =~ programs\.bash\.shellAliases[[:space:]]*=[[:space:]]*\{ ]]; then
            in_bash_block=true
            in_zsh_block=false
            continue
        fi

        # Check for zsh alias block
        if [[ "$line" =~ programs\.zsh\.shellAliases[[:space:]]*=[[:space:]]*\{ ]]; then
            in_zsh_block=true
            in_bash_block=false
            continue
        fi

        # Check if we're leaving a block
        if [[ ("$in_bash_block" == true || "$in_zsh_block" == true) && "$line" =~ ^[[:space:]]*\}[[:space:]]*\;?[[:space:]]*$ ]]; then
            in_bash_block=false
            in_zsh_block=false
            continue
        fi

        # Extract alias definitions
        if [[ "$in_bash_block" == true || "$in_zsh_block" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_\-]+)[[:space:]]*=[[:space:]]*\"([^\"]*)\"\;?[[:space:]]*$ ]]; then
                alias_name="${BASH_REMATCH[1]}"
                alias_value="${BASH_REMATCH[2]}"

                if [[ "$in_bash_block" == true ]]; then
                    WSL_BASH_ALIASES["$alias_name"]="$alias_value"
                fi
                if [[ "$in_zsh_block" == true ]]; then
                    WSL_ZSH_ALIASES["$alias_name"]="$alias_value"
                fi
            fi
        fi
    done < "$wsl_file"
}

# Extract functions from bash.nix
extract_bash_functions() {
    local bash_file="$DOTFILES_ROOT/modules/shells/bash.nix"

    if [[ ! -f "$bash_file" ]]; then
        return
    fi

    # Look for function definitions in bashrcExtra
    grep -E "^\s*(function |[a-zA-Z_][a-zA-Z0-9_]*\(\))" "$bash_file" 2>/dev/null | while read -r line; do
        if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\) ]]; then
            func_name="${BASH_REMATCH[2]}"
            BASH_FUNCTIONS["$func_name"]=1
        fi
    done
}

# Extract functions from zsh.nix
extract_zsh_functions() {
    local zsh_file="$DOTFILES_ROOT/modules/shells/zsh.nix"

    if [[ ! -f "$zsh_file" ]]; then
        return
    fi

    # Look for function definitions in initExtra
    grep -E "^\s*(function |[a-zA-Z_][a-zA-Z0-9_]*\(\))" "$zsh_file" 2>/dev/null | while read -r line; do
        if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\) ]]; then
            func_name="${BASH_REMATCH[2]}"
            ZSH_FUNCTIONS["$func_name"]=1
        fi
    done
}

# Extract aliases and functions from Elvish rc.elv
extract_elvish_config() {
    local elvish_file="$DOTFILES_ROOT/elvish/rc.elv"

    if [[ ! -f "$elvish_file" ]]; then
        echo -e "${YELLOW}Warning: elvish/rc.elv not found${RESET}" >&2
        return
    fi

    # Extract alias:new definitions
    grep "alias:new" "$elvish_file" 2>/dev/null | while read -r line; do
        # Match pattern: alias:new &save alias_name command
        if [[ "$line" =~ alias:new[[:space:]]+\&save[[:space:]]+([a-zA-Z0-9_.-]+)[[:space:]]+(.*) ]]; then
            alias_name="${BASH_REMATCH[1]}"
            alias_value="${BASH_REMATCH[2]}"
            ELVISH_ALIASES["$alias_name"]="$alias_value"
        fi
    done

    # Extract function definitions (fn name)
    grep -E "^fn[[:space:]]+" "$elvish_file" 2>/dev/null | while read -r line; do
        if [[ "$line" =~ ^fn[[:space:]]+([a-zA-Z_][a-zA-Z0-9_-]*) ]]; then
            func_name="${BASH_REMATCH[1]}"
            ELVISH_FUNCTIONS["$func_name"]=1
        fi
    done
}

# Check alias consistency across shells
check_alias_consistency() {
    print_header "Alias Consistency Check"

    # Get all unique aliases
    declare -A all_aliases
    for alias in "${!BASH_ALIASES[@]}"; do
        all_aliases["$alias"]=1
    done
    for alias in "${!ZSH_ALIASES[@]}"; do
        all_aliases["$alias"]=1
    done
    for alias in "${!ELVISH_ALIASES[@]}"; do
        all_aliases["$alias"]=1
    done

    # Check each alias - use while loop to handle special characters properly
    while IFS= read -r alias; do
        local bash_val="${BASH_ALIASES["$alias"]:-missing}"
        local zsh_val="${ZSH_ALIASES["$alias"]:-missing}"
        local elvish_val="${ELVISH_ALIASES["$alias"]:-missing}"

        # Check if it's a smart alias (should be a function in all shells)
        local is_smart=false
        for smart in "${SMART_ALIASES[@]}"; do
            if [[ "$alias" == "$smart" ]]; then
                is_smart=true
                break
            fi
        done

        if [[ "$is_smart" == true ]]; then
            # Smart aliases should be implemented as functions
            if [[ -n "${BASH_FUNCTIONS["$alias"]:-}" || -n "${ELVISH_FUNCTIONS["$alias"]:-}" ]]; then
                print_check "pass" "'$alias' - implemented as smart function"
            else
                print_check "warn" "'$alias' - should be implemented as smart function with agent detection"
            fi
        else
            # Regular aliases should be consistent
            if [[ "$bash_val" == "$zsh_val" ]]; then
                if [[ "$elvish_val" == "missing" ]]; then
                    print_check "warn" "'$alias' - missing in Elvish" "Add to elvish/rc.elv"
                elif [[ "$bash_val" == "missing" ]]; then
                    print_check "warn" "'$alias' - only in Elvish" "Consider adding to aliases.nix"
                else
                    # Check if Elvish value is similar (may have different syntax)
                    print_check "pass" "'$alias' - implemented in all shells"
                fi
            else
                if [[ "$bash_val" == "missing" || "$zsh_val" == "missing" ]]; then
                    print_check "warn" "'$alias' - inconsistent across shells"
                else
                    print_check "fail" "'$alias' - different implementations" "Bash: $bash_val | Zsh: $zsh_val"
                fi
            fi
        fi
    done < <(echo "${!all_aliases[@]}" | tr ' ' '\n' | sort)
}

# Check function consistency
check_function_consistency() {
    print_header "Function Consistency Check"

    for func in "${CORE_FUNCTIONS[@]}"; do
        local in_bash="${BASH_FUNCTIONS["$func"]:-0}"
        local in_zsh="${ZSH_FUNCTIONS["$func"]:-0}"
        local in_elvish="${ELVISH_FUNCTIONS["$func"]:-0}"

        if [[ "$in_bash" == "1" && "$in_zsh" == "1" && "$in_elvish" == "1" ]]; then
            print_check "pass" "'$func' - available in all shells"
        elif [[ "$in_elvish" == "1" && ("$in_bash" == "0" || "$in_zsh" == "0") ]]; then
            print_check "warn" "'$func' - missing in bash/zsh" "Port from Elvish implementation"
        elif [[ "$in_elvish" == "0" ]]; then
            print_check "warn" "'$func' - missing in Elvish" "Consider implementing in Elvish"
        else
            print_check "pass" "'$func' - available in bash/zsh"
        fi
    done
}

# Check smart alias coverage
check_smart_aliases() {
    print_header "Smart Alias Coverage"

    for alias in "${SMART_ALIASES[@]}"; do
        # Check if implemented as function with agent detection
        local has_smart_impl=false

        # Check in bash functions
        if grep -q "^\s*$alias()" "$DOTFILES_ROOT/modules/shells/bash.nix" 2>/dev/null; then
            if grep -A5 "^\s*$alias()" "$DOTFILES_ROOT/modules/shells/bash.nix" | grep -q "is_agent_context\|DOTFILES_AGENT_MODE" 2>/dev/null; then
                has_smart_impl=true
            fi
        fi

        # Check in Elvish
        if grep -q "^fn $alias" "$DOTFILES_ROOT/elvish/rc.elv" 2>/dev/null; then
            if grep -A5 "^fn $alias" "$DOTFILES_ROOT/elvish/rc.elv" | grep -q "is-agent-context" 2>/dev/null; then
                has_smart_impl=true
            fi
        fi

        if [[ "$has_smart_impl" == true ]]; then
            print_check "pass" "'$alias' - has smart implementation with agent detection"
        else
            print_check "warn" "'$alias' - missing smart implementation" "Should detect AI agent context"
        fi
    done
}

# Check Git alias coverage
check_git_aliases() {
    print_header "Git Alias Coverage"

    local git_count=0
    local git_found=0

    for alias in "${GIT_ALIASES[@]}"; do
        ((git_count++)) || true

        local in_common="${BASH_ALIASES["$alias"]:-}"
        local in_elvish="${ELVISH_ALIASES["$alias"]:-}"

        if [[ -n "$in_common" || -n "$in_elvish" ]]; then
            ((git_found++)) || true
        else
            print_check "warn" "'$alias' - missing git alias"
        fi
    done

    print_check "pass" "Git aliases: $git_found/$git_count implemented"
}

# Check WSL-specific aliases
check_wsl_aliases() {
    print_header "WSL-Specific Aliases (if applicable)"

    if [[ ${#WSL_BASH_ALIASES[@]} -eq 0 && ${#WSL_ZSH_ALIASES[@]} -eq 0 ]]; then
        print_check "pass" "No WSL module found (non-WSL environment)"
        return
    fi

    # Check consistency between WSL bash and zsh
    declare -A wsl_all
    for alias in "${!WSL_BASH_ALIASES[@]}"; do
        wsl_all["$alias"]=1
    done
    for alias in "${!WSL_ZSH_ALIASES[@]}"; do
        wsl_all["$alias"]=1
    done

    for alias in "${!wsl_all[@]}"; do
        local bash_val="${WSL_BASH_ALIASES["$alias"]:-missing}"
        local zsh_val="${WSL_ZSH_ALIASES["$alias"]:-missing}"

        if [[ "$bash_val" == "$zsh_val" ]]; then
            print_check "pass" "'$alias' - WSL alias consistent"
        elif [[ "$bash_val" == "missing" ]]; then
            print_check "warn" "'$alias' - WSL alias missing in bash"
        elif [[ "$zsh_val" == "missing" ]]; then
            print_check "warn" "'$alias' - WSL alias missing in zsh"
        else
            print_check "fail" "'$alias' - WSL alias differs" "Bash: $bash_val | Zsh: $zsh_val"
        fi
    done
}

# Generate recommendations
generate_recommendations() {
    print_header "Recommendations"

    local rec_num=1

    if [[ $WARNINGS -gt 0 || $FAILURES -gt 0 ]]; then
        echo -e "\n${BOLD}Suggested fixes:${RESET}"

        # Check for missing Elvish aliases
        for alias in "${!BASH_ALIASES[@]}"; do
            if [[ -z "${ELVISH_ALIASES["$alias"]:-}" ]]; then
                echo -e "  ${rec_num}. Add '$alias' alias to elvish/rc.elv:"
                echo -e "     ${CYAN}alias:new &save $alias ${BASH_ALIASES["$alias"]}${RESET}"
                ((rec_num++)) || true
            fi
        done

        # Check for inconsistent implementations
        if [[ $FAILURES -gt 0 ]]; then
            echo -e "  ${rec_num}. Review and standardize aliases with different implementations"
            ((rec_num++))
        fi

        # Check for missing smart implementations
        local missing_smart=false
        for alias in "${SMART_ALIASES[@]}"; do
            if [[ -z "${BASH_FUNCTIONS["$alias"]:-}" && -z "${ELVISH_FUNCTIONS["$alias"]:-}" ]]; then
                missing_smart=true
                break
            fi
        done

        if [[ "$missing_smart" == true ]]; then
            echo -e "  ${rec_num}. Implement smart aliases with agent detection for POSIX compatibility"
            echo -e "     ${CYAN}These should detect AI/automation context and use appropriate tools${RESET}"
            ((rec_num++))
        fi
    else
        echo -e "  ${GREEN}No issues found - configuration is consistent!${RESET}"
    fi
}

# Main execution
main() {
    echo -e "${BOLD}${CYAN}=== Dotfiles Configuration Consistency Validator ===${RESET}"
    echo -e "Checking configuration files in: $DOTFILES_ROOT\n"

    # Extract configurations
    echo -e "${BLUE}Extracting configurations...${RESET}"
    extract_nix_common_aliases
    extract_wsl_aliases
    extract_bash_functions
    extract_zsh_functions
    extract_elvish_config

    # Note: Arrays in bash don't persist across subshells from command substitution
    # So we need to re-extract in the main process

    # Re-extract Elvish config in main process
    if [[ -f "$DOTFILES_ROOT/elvish/rc.elv" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ alias:new[[:space:]]+\&save[[:space:]]+([a-zA-Z0-9_.-]+)[[:space:]]+(.*) ]]; then
                alias_name="${BASH_REMATCH[1]}"
                alias_value="${BASH_REMATCH[2]}"
                ELVISH_ALIASES["$alias_name"]="$alias_value"
            fi
        done < <(grep "alias:new" "$DOTFILES_ROOT/elvish/rc.elv" 2>/dev/null)

        while IFS= read -r line; do
            if [[ "$line" =~ ^fn[[:space:]]+([a-zA-Z_][a-zA-Z0-9_-]*) ]]; then
                func_name="${BASH_REMATCH[1]}"
                ELVISH_FUNCTIONS["$func_name"]=1
            fi
        done < <(grep -E "^fn[[:space:]]+" "$DOTFILES_ROOT/elvish/rc.elv" 2>/dev/null)
    fi

    # Re-extract bash functions in main process
    if [[ -f "$DOTFILES_ROOT/modules/shells/bash.nix" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\) ]]; then
                func_name="${BASH_REMATCH[2]}"
                BASH_FUNCTIONS["$func_name"]=1
            fi
        done < <(grep -E "^\s*(function |[a-zA-Z_][a-zA-Z0-9_]*\(\))" "$DOTFILES_ROOT/modules/shells/bash.nix" 2>/dev/null)
    fi

    # Re-extract zsh functions in main process
    if [[ -f "$DOTFILES_ROOT/modules/shells/zsh.nix" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\) ]]; then
                func_name="${BASH_REMATCH[2]}"
                ZSH_FUNCTIONS["$func_name"]=1
            fi
        done < <(grep -E "^\s*(function |[a-zA-Z_][a-zA-Z0-9_]*\(\))" "$DOTFILES_ROOT/modules/shells/zsh.nix" 2>/dev/null)
    fi

    echo -e "${GREEN}Configuration extraction complete${RESET}"
    echo "Found: ${#BASH_ALIASES[@]} bash/zsh aliases, ${#ELVISH_ALIASES[@]} elvish aliases"

    # Run checks
    check_alias_consistency
    check_function_consistency
    check_smart_aliases
    check_git_aliases
    check_wsl_aliases

    # Generate summary
    print_header "Summary"

    local percentage=0
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        percentage=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    fi

    echo -e "\nOverall: ${BOLD}$PASSED_CHECKS/$TOTAL_CHECKS${RESET} checks passed (${percentage}%)"
    echo -e "  ${GREEN}✓ Passed:${RESET} $PASSED_CHECKS"
    echo -e "  ${YELLOW}⚠ Warnings:${RESET} $WARNINGS"
    echo -e "  ${RED}✗ Failed:${RESET} $FAILURES"

    # Generate recommendations
    generate_recommendations

    # Exit with appropriate code
    if [[ $FAILURES -gt 0 ]]; then
        exit 1
    elif [[ $WARNINGS -gt 0 ]]; then
        exit 0
    else
        exit 0
    fi
}

# Run main function
main "$@"