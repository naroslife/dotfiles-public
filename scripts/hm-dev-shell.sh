#!/usr/bin/env bash
# Home Manager Development Shell Launcher
# Convenience script to easily enter the Home Manager dev environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Check if we're already in a nix shell
if [[ -n "${IN_NIX_SHELL:-}" ]]; then
    echo -e "${YELLOW}You are already in a Nix shell!${RESET}"
    echo "Exit the current shell before entering a new one."
    exit 1
fi

# Check if dotfiles directory exists
if [[ ! -d "$DOTFILES_DIR" ]] || [[ ! -f "$DOTFILES_DIR/flake.nix" ]]; then
    echo -e "${RED}Error: dotfiles-public directory not found or invalid${RESET}"
    echo "Expected location: $DOTFILES_DIR"
    echo ""
    echo "Set DOTFILES_DIR environment variable to the correct path:"
    echo "  export DOTFILES_DIR=/path/to/dotfiles-public"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}║   Launching Home Manager Development Shell                ║${RESET}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Detect user
USER_NAME="${1:-$(whoami)}"
echo -e "${GREEN}User: $USER_NAME${RESET}"
echo -e "${GREEN}Dotfiles: $DOTFILES_DIR${RESET}"
echo ""

# Change to dotfiles directory
cd "$DOTFILES_DIR"

# Check if flake is available
if ! nix flake show 2>/dev/null | grep -q "devShells"; then
    echo -e "${YELLOW}Warning: Could not verify devShells in flake${RESET}"
    echo "Attempting to enter shell anyway..."
    echo ""
fi

# Enter dev shell
echo -e "${GREEN}Entering Home Manager development environment...${RESET}"
echo ""

# Try flake-based dev shell first, fall back to shell.nix
if nix develop ".#hm-env" 2>/dev/null; then
    :
elif nix develop 2>/dev/null; then
    :
elif [[ -f "$DOTFILES_DIR/shell.nix" ]]; then
    echo -e "${YELLOW}Falling back to shell.nix...${RESET}"
    nix-shell "$DOTFILES_DIR/shell.nix"
else
    echo -e "${RED}Error: Could not enter dev shell${RESET}"
    echo "Please ensure Nix is installed and flakes are enabled."
    exit 1
fi
