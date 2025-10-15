#!/usr/bin/env bash
# Dotfiles Examples Viewer - Show curated command examples
# Usage: dotfiles-examples.sh <tool> [search_term]

set -euo pipefail

# Script directory and root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLES_DIR="$ROOT_DIR/examples"

# Colors for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Show usage
show_usage() {
    cat << EOF
${BOLD}Dotfiles Examples Viewer${NC}

${BOLD}USAGE:${NC}
    dotfiles examples <tool> [search_term]
    dotfiles examples --list
    dotfiles examples --fzf

${BOLD}COMMANDS:${NC}
    <tool>              Show examples for a tool (e.g., git, docker, nix)
    <tool> <search>     Search examples for specific terms
    --list, -l          List all available tools
    --fzf, -f           Browse examples interactively with fzf
    --help, -h          Show this help message

${BOLD}EXAMPLES:${NC}
    dotfiles examples git           # Show all git examples
    dotfiles examples git commit    # Search git examples for "commit"
    dotfiles examples docker build  # Search docker examples for "build"
    dotfiles examples --list        # List available tools
    dotfiles examples --fzf         # Interactive browser

${BOLD}FALLBACK:${NC}
    If a tool has no curated examples, falls back to:
      1. tldr (if installed)
      2. cheat (if installed)
      3. <tool> --help

${BOLD}LOCATION:${NC}
    Examples: $EXAMPLES_DIR

EOF
}

# List available tools
list_tools() {
    echo -e "${BOLD}Available Example Tools:${NC}"
    echo ""

    if [[ ! -d "$EXAMPLES_DIR" ]]; then
        echo -e "${RED}Error: Examples directory not found: $EXAMPLES_DIR${NC}"
        return 1
    fi

    local tools=()
    while IFS= read -r file; do
        local tool=$(basename "$file" .txt)
        tools+=("$tool")
    done < <(find "$EXAMPLES_DIR" -name "*.txt" -type f | sort)

    if [[ ${#tools[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No example files found${NC}"
        return 0
    fi

    for tool in "${tools[@]}"; do
        local file="$EXAMPLES_DIR/$tool.txt"
        local line_count=$(wc -l < "$file")
        local section_count=$(grep -c "^##" "$file" 2>/dev/null || echo "0")
        echo -e "  ${GREEN}$tool${NC} (${CYAN}$section_count sections${NC}, $line_count lines)"
    done

    echo ""
    echo -e "Use: ${CYAN}dotfiles examples <tool>${NC} to view examples"
}

# Show examples with optional search
show_examples() {
    local tool="$1"
    local search_term="${2:-}"
    local example_file="$EXAMPLES_DIR/$tool.txt"

    # Check if example file exists
    if [[ ! -f "$example_file" ]]; then
        echo -e "${YELLOW}No curated examples found for: $tool${NC}"
        echo ""

        # Try fallback to tldr
        if command -v tldr &>/dev/null; then
            echo -e "${CYAN}Falling back to tldr...${NC}"
            echo ""
            tldr "$tool"
            return 0
        fi

        # Try fallback to cheat
        if command -v cheat &>/dev/null; then
            echo -e "${CYAN}Falling back to cheat...${NC}"
            echo ""
            cheat "$tool"
            return 0
        fi

        # Try tool --help
        echo -e "${CYAN}Available example tools:${NC}"
        list_tools
        return 1
    fi

    # If search term provided, filter results
    if [[ -n "$search_term" ]]; then
        echo -e "${BOLD}Examples for ${GREEN}$tool${NC} ${BOLD}matching ${CYAN}$search_term${NC}"
        echo ""

        # Use grep to find matching sections and context
        if command -v rg &>/dev/null; then
            # Use ripgrep if available (respects gitignore, faster)
            rg -i -A 5 -B 1 "$search_term" "$example_file" --color=always || {
                echo -e "${YELLOW}No matches found for: $search_term${NC}"
                return 1
            }
        else
            # Fallback to grep
            grep -i -A 5 -B 1 "$search_term" "$example_file" --color=always || {
                echo -e "${YELLOW}No matches found for: $search_term${NC}"
                return 1
            }
        fi
    else
        # Show all examples
        echo -e "${BOLD}Examples for ${GREEN}$tool${NC}"
        echo ""

        # Use bat for syntax highlighting if available
        if command -v bat &>/dev/null; then
            bat --style=plain --color=always "$example_file"
        else
            # Fallback to cat with header highlighting
            sed "s/^# \(.*\)/${BOLD}${GREEN}\1${NC}/g; s/^## \(.*\)/${BOLD}${CYAN}\1${NC}/g; s/^### \(.*\)/${YELLOW}\1${NC}/g" "$example_file"
        fi
    fi
}

# Interactive browser with fzf
browse_with_fzf() {
    if ! command -v fzf &>/dev/null; then
        echo -e "${RED}Error: fzf is not installed${NC}"
        echo "Install with: nix-env -iA nixpkgs.fzf"
        return 1
    fi

    if [[ ! -d "$EXAMPLES_DIR" ]]; then
        echo -e "${RED}Error: Examples directory not found: $EXAMPLES_DIR${NC}"
        return 1
    fi

    # Create a temporary file with all examples
    local temp_index=$(mktemp)
    trap "rm -f $temp_index" EXIT

    # Build index of all sections
    for file in "$EXAMPLES_DIR"/*.txt; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local tool=$(basename "$file" .txt)

        # Extract section headers
        while IFS= read -r line; do
            if [[ "$line" =~ ^###[[:space:]](.+) ]]; then
                local section="${BASH_REMATCH[1]}"
                echo "$tool :: $section" >> "$temp_index"
            fi
        done < "$file"
    done

    # Let user select a section
    local selection=$(cat "$temp_index" | fzf \
        --prompt="Examples > " \
        --preview="echo {} | cut -d':' -f1 | xargs -I{} grep -A 10 '\$(echo {} | cut -d':' -f3-)' $EXAMPLES_DIR/{}.txt 2>/dev/null || echo 'No preview available'" \
        --preview-window=right:60%:wrap \
        --height=80% \
        --border \
        --header="Select a topic (Ctrl-C to cancel)")

    if [[ -z "$selection" ]]; then
        return 0
    fi

    # Extract tool and search term
    local tool=$(echo "$selection" | cut -d':' -f1 | xargs)
    local search=$(echo "$selection" | cut -d':' -f3- | xargs)

    echo ""
    show_examples "$tool" "$search"
}

# Main function
main() {
    local command="${1:-help}"

    case "$command" in
        --help|-h|help)
            show_usage
            ;;
        --list|-l|list)
            list_tools
            ;;
        --fzf|-f|fzf|browse)
            browse_with_fzf
            ;;
        -*)
            echo -e "${RED}Unknown option: $command${NC}"
            echo "Run 'dotfiles examples --help' for usage"
            exit 1
            ;;
        *)
            # Show examples for tool
            if [[ -z "$command" ]]; then
                show_usage
                exit 1
            fi

            local search_term="${2:-}"
            show_examples "$command" "$search_term"
            ;;
    esac
}

# Run main
main "$@"
