#!/usr/bin/env bash
# Nix Helper - Interactive nix operations with fzf
# Usage: dotfiles-nix-helper.sh or dotfiles nix

set -euo pipefail

# Script directory and root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common utilities
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/common.sh"
elif [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/../lib/common.sh"
else
  echo "Error: Could not find common.sh" >&2
  exit 1
fi

# Check for required tools
require_command nix "Install Nix: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
require_command fzf "fzf should be installed via home-manager. Try: dotfiles apply"

# Nix operations menu
show_nix_menu() {
  local choice

  # Create menu with preview
  choice=$(
    cat <<'EOF' | fzf \
      --height=80% \
      --border=rounded \
      --header='Nix Helper - Select an operation' \
      --preview='echo {}' \
      --preview-window=up:3:wrap \
      --prompt='Nix > ' \
      --pointer='▶' \
      --marker='✓'
apply           Apply dotfiles configuration (home-manager switch)
apply-flake     Apply flake-based configuration with username
update          Update flake inputs
update-all      Update flake and apply configuration
search          Search for Nix packages
search-options  Search home-manager options
show-package    Show package information
eval            Evaluate Nix expression
repl            Start Nix REPL
build           Build a derivation
shell           Enter development shell
gc              Run garbage collection
gc-delete-old   Delete old generations and collect garbage
list-generations List home-manager generations
rollback        Rollback to previous generation
switch-generation Switch to specific generation
diff-generations Diff current and previous generation
show-config     Show current configuration
validate-config Validate Nix syntax in configuration
rebuild-cache   Rebuild nix evaluation cache
show-store      Show nix store statistics
optimize-store  Optimize nix store (deduplicate)
verify-store    Verify nix store integrity
repair-store    Repair corrupted nix store paths
list-profiles   List all nix profiles
why-depends     Show why a package depends on another
tree            Show package dependency tree
EOF
  )

  # Handle the selected operation
  if [[ -z "$choice" ]]; then
    log_info "No operation selected"
    return 0
  fi

  local operation
  operation=$(echo "$choice" | awk '{print $1}')

  log_info "Executing: $operation"
  echo ""

  case "$operation" in
  apply)
    if [[ -f "$ROOT_DIR/apply.sh" ]]; then
      log_info "Running apply.sh script..."
      "$ROOT_DIR/apply.sh"
    else
      log_info "Running home-manager switch..."
      home-manager switch --flake "$ROOT_DIR" --impure
    fi
    ;;
  apply-flake)
    read -p "Username [$(whoami)]: " -r username
    username=${username:-$(whoami)}
    log_info "Applying flake configuration for user: $username"
    cd "$ROOT_DIR"
    nix run home-manager/release-25.05 -- switch --impure --flake ".#$username"
    ;;
  update)
    log_info "Updating flake inputs..."
    cd "$ROOT_DIR"
    nix flake update
    log_info "Flake inputs updated. Run 'dotfiles apply' to apply changes"
    ;;
  update-all)
    log_info "Updating flake inputs..."
    cd "$ROOT_DIR"
    nix flake update
    log_info "Applying updated configuration..."
    nix run home-manager/release-25.05 -- switch --impure --flake "$ROOT_DIR"
    ;;
  search)
    read -p "Search query: " -r query
    if [[ -n "$query" ]]; then
      log_info "Searching for: $query"
      nix search nixpkgs "$query"
    fi
    ;;
  search-options)
    read -p "Search query: " -r query
    if [[ -n "$query" ]]; then
      log_info "Searching home-manager options: $query"
      home-manager option "$query" 2>/dev/null || nix search nixpkgs home-manager
    fi
    ;;
  show-package)
    read -p "Package name: " -r pkg
    if [[ -n "$pkg" ]]; then
      nix eval nixpkgs#"$pkg".meta --json | jq .
    fi
    ;;
  eval)
    read -p "Nix expression: " -r expr
    if [[ -n "$expr" ]]; then
      nix eval --expr "$expr"
    fi
    ;;
  repl)
    log_info "Starting Nix REPL (type :q to quit)"
    nix repl --file '<nixpkgs>'
    ;;
  build)
    read -p "Flake reference or file path: " -r target
    if [[ -n "$target" ]]; then
      nix build "$target"
      log_info "Build completed. Result in ./result"
    fi
    ;;
  shell)
    read -p "Flake reference or package (e.g., nixpkgs#python3): " -r target
    if [[ -n "$target" ]]; then
      log_info "Entering development shell..."
      nix shell "$target"
    else
      log_info "Entering default development shell..."
      nix develop
    fi
    ;;
  gc)
    log_warn "This will remove unused packages from the Nix store"
    if ask_yes_no "Continue?"; then
      nix-collect-garbage
      log_info "Garbage collection completed"
    fi
    ;;
  gc-delete-old)
    log_warn "This will delete old generations and run garbage collection"
    if ask_yes_no "Continue?"; then
      nix-collect-garbage -d
      log_info "Old generations deleted and garbage collected"
    fi
    ;;
  list-generations)
    home-manager generations
    ;;
  rollback)
    log_warn "This will rollback to the previous generation"
    if ask_yes_no "Continue?"; then
      home-manager generations | head -2 | tail -1 | awk '{print $NF}' | xargs -I{} {}/activate
      log_info "Rolled back to previous generation"
    fi
    ;;
  switch-generation)
    local generation
    home-manager generations
    echo ""
    read -p "Enter generation ID or path: " -r generation
    if [[ -n "$generation" ]]; then
      if [[ -d "$generation" ]]; then
        "$generation/activate"
        log_info "Switched to generation: $generation"
      else
        log_error "Invalid generation path: $generation"
      fi
    fi
    ;;
  diff-generations)
    log_info "Comparing current and previous generation..."
    local current
    local previous
    current=$(home-manager generations | head -1 | awk '{print $NF}')
    previous=$(home-manager generations | head -2 | tail -1 | awk '{print $NF}')
    if [[ -n "$current" ]] && [[ -n "$previous" ]]; then
      nix store diff-closures "$previous" "$current"
    else
      log_error "Could not find generations to compare"
    fi
    ;;
  show-config)
    log_info "Current configuration files:"
    echo ""
    echo "Flake: $ROOT_DIR/flake.nix"
    echo "Home: $ROOT_DIR/home.nix"
    echo ""
    echo "Module structure:"
    find "$ROOT_DIR/modules" -name "*.nix" 2>/dev/null | sort || echo "No modules directory found"
    ;;
  validate-config)
    log_info "Validating Nix configuration files..."
    local errors=0

    for file in "$ROOT_DIR/flake.nix" "$ROOT_DIR/home.nix"; do
      if [[ -f "$file" ]]; then
        if nix-instantiate --parse "$file" >/dev/null 2>&1; then
          echo "✓ $file"
        else
          echo "✗ $file - syntax error"
          ((errors++))
        fi
      fi
    done

    if [[ $errors -eq 0 ]]; then
      log_info "All configuration files are valid"
    else
      log_error "$errors configuration file(s) have syntax errors"
      return 1
    fi
    ;;
  rebuild-cache)
    log_info "Rebuilding Nix evaluation cache..."
    nix flake check "$ROOT_DIR" --no-build
    log_info "Cache rebuilt"
    ;;
  show-store)
    nix path-info --all --human-readable --closure-size | sort -k2 -h | tail -20
    ;;
  optimize-store)
    log_warn "This will deduplicate files in the Nix store to save space"
    if ask_yes_no "Continue?"; then
      nix store optimise
      log_info "Store optimized"
    fi
    ;;
  verify-store)
    log_info "Verifying Nix store integrity..."
    nix store verify --all
    log_info "Verification completed"
    ;;
  repair-store)
    log_warn "This will attempt to repair corrupted store paths"
    if ask_yes_no "Continue?"; then
      nix store repair --all
      log_info "Repair completed"
    fi
    ;;
  list-profiles)
    log_info "Nix profiles:"
    nix profile list 2>/dev/null || echo "No profiles found (using flakes)"
    ;;
  why-depends)
    read -p "Package 1 (e.g., nixpkgs#hello): " -r pkg1
    read -p "Package 2 (depends on): " -r pkg2
    if [[ -n "$pkg1" ]] && [[ -n "$pkg2" ]]; then
      nix why-depends "$pkg1" "$pkg2"
    fi
    ;;
  tree)
    read -p "Package (e.g., nixpkgs#hello): " -r pkg
    if [[ -n "$pkg" ]]; then
      nix-store --query --tree $(nix-build '<nixpkgs>' -A "$pkg" --no-out-link) | less
    fi
    ;;
  *)
    log_error "Unknown operation: $operation"
    return 1
    ;;
  esac

  echo ""
  log_info "Operation completed"
}

# Main entry point
main() {
  # Check if we're in the dotfiles directory for operations that need it
  local needs_dotfiles_dir=("apply" "apply-flake" "update" "update-all" "show-config" "validate-config" "rebuild-cache")

  # Show the menu
  show_nix_menu
}

# Run main
main "$@"
