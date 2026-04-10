#!/usr/bin/env bash
# bootstrap.sh — Entry point for chezmoi + mise dotfiles
#
# Usage:
#   ./bootstrap.sh                  # Interactive, auto-detects environment
#   ./bootstrap.sh --offline        # Offline mode (uses cached/bundled tools)
#   ./bootstrap.sh --no-mise        # Skip mise tool installation
#   ./bootstrap.sh --no-apt         # Skip apt package installation (no root needed)
#   ./bootstrap.sh --user <name>    # Specify user profile (default: whoami)
#
# This script is idempotent — safe to run multiple times.

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_VERSION="latest"
MISE_VERSION="latest"
CHEZMOI_INSTALL_URL="https://get.chezmoi.io"
MISE_INSTALL_URL="https://mise.run"

# ── Colors ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BOLD}${BLUE}==>${NC}${BOLD} $*${NC}"; }

# ── Defaults ─────────────────────────────────────────────────────────────────
OFFLINE=false
SKIP_MISE=false
SKIP_APT=false
USERNAME="${USER:-$(whoami)}"

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline)    OFFLINE=true ;;
    --no-mise)    SKIP_MISE=true ;;
    --no-apt)     SKIP_APT=true ;;
    --user)       shift; USERNAME="${1:?--user requires a value}" ;;
    --help|-h)
      echo "Usage: $0 [--offline] [--no-mise] [--no-apt] [--user <username>]"
      exit 0 ;;
    *) log_error "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# ── Platform detection ────────────────────────────────────────────────────────
IS_WSL=false
if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
fi

IS_LINUX=false
IS_MACOS=false
case "$(uname -s)" in
  Linux)  IS_LINUX=true ;;
  Darwin) IS_MACOS=true ;;
esac

# ── Dependency check ─────────────────────────────────────────────────────────
require_cmd() {
  command -v "$1" &>/dev/null || {
    log_error "Required command not found: $1"
    log_error "Please install $1 and retry."
    exit 1
  }
}

require_cmd curl
require_cmd git

# ── Step 1: Install chezmoi ───────────────────────────────────────────────────
log_step "Installing chezmoi"

if command -v chezmoi &>/dev/null; then
  log_info "chezmoi already installed: $(chezmoi --version)"
elif [[ "${OFFLINE}" == true ]]; then
  log_error "chezmoi not found and --offline mode is active."
  log_error "Pre-install chezmoi or bundle it with deploy-remote.sh."
  exit 1
else
  log_info "Downloading and installing chezmoi..."
  sh -c "$(curl -fsSL "${CHEZMOI_INSTALL_URL}")" -- -b "${HOME}/.local/bin"
  export PATH="${HOME}/.local/bin:${PATH}"
fi

# ── Step 2: Apply chezmoi dotfiles ────────────────────────────────────────────
log_step "Applying dotfiles with chezmoi"

CHEZMOI_SOURCE="${SCRIPT_DIR}"

# Pass selected user profile to chezmoi templates
export DOTFILES_USER="${USERNAME}"
log_info "Using profile: ${USERNAME}"

if chezmoi data &>/dev/null; then
  log_info "chezmoi already initialized — running apply"
  chezmoi apply --source="${CHEZMOI_SOURCE}"
else
  log_info "Initializing chezmoi from source directory: ${CHEZMOI_SOURCE}"
  chezmoi init --source="${CHEZMOI_SOURCE}" --apply
fi

log_info "Dotfiles applied successfully"

# ── Step 3: Install mise ──────────────────────────────────────────────────────
if [[ "${SKIP_MISE}" == false ]]; then
  log_step "Installing mise-en-place"

  if command -v mise &>/dev/null; then
    log_info "mise already installed: $(mise --version)"
  elif [[ "${OFFLINE}" == true ]]; then
    log_error "mise not found and --offline mode is active."
    log_error "Pre-install mise or use deploy-remote.sh to bundle it."
    exit 1
  else
    log_info "Downloading and installing mise..."
    curl -fsSL "${MISE_INSTALL_URL}" | sh
    export PATH="${HOME}/.local/bin:${PATH}"
  fi

  # ── Step 4: Install system apt dependencies ──────────────────────────────
  log_step "Installing apt dependencies (Tier 1/3/4 from apt)"

  if [[ "${IS_LINUX}" == true ]] && command -v apt-get &>/dev/null; then
    if [[ "${SKIP_APT}" == true ]]; then
      log_warn "Skipping apt installation (--no-apt specified)"
    else
      if [[ "${OFFLINE}" == false ]]; then
        sudo apt-get update -qq
      fi
      install_apt_deps_args=()
      if [[ "${OFFLINE}" == true ]]; then
        install_apt_deps_args+=(--offline)
      fi
      "${SCRIPT_DIR}/scripts/install-apt-deps.sh" "${install_apt_deps_args[@]}"
    fi
  else
    log_warn "apt-get not available — skipping apt dependencies"
  fi

  # ── Step 5: Install mise tools ───────────────────────────────────────────
  log_step "Installing mise tools (Tier 1/2)"

  if [[ "${OFFLINE}" == true ]]; then
    log_info "Offline mode: using cached downloads"
    MISE_OFFLINE=1 mise install
  else
    mise install
  fi
  log_info "mise tools installed"

  # ── Step 6: Install Zsh plugins ─────────────────────────────────────────
  log_step "Installing Zsh plugins"
  "${SCRIPT_DIR}/scripts/install-zsh-plugins.sh"

  # ── Step 7: Install fonts ───────────────────────────────────────────────
  log_step "Installing Nerd Fonts"
  if [[ "${OFFLINE}" == false ]]; then
    "${SCRIPT_DIR}/scripts/install-fonts.sh"
  else
    log_warn "Skipping font installation in offline mode"
  fi

  # ── Step 8: WSL-specific setup ──────────────────────────────────────────
  if [[ "${IS_WSL}" == true ]]; then
    log_step "Applying WSL-specific configuration"
    if [[ -f "${SCRIPT_DIR}/wsl-fixes/wsl-setup.sh" ]]; then
      "${SCRIPT_DIR}/wsl-fixes/wsl-setup.sh"
    fi
  fi
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
log_info "Bootstrap complete!"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo "  1. Restart your shell or run: source ~/.zshrc"
echo "  2. Verify: mise list"
echo "  3. Verify: chezmoi status"
echo ""
echo -e "  ${BOLD}Update dotfiles later:${NC}"
echo "  chezmoi apply           # re-apply after editing source"
echo "  mise upgrade            # update all tools"
echo "  mise run update         # same as above"
echo ""
