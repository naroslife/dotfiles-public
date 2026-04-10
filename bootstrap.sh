#!/usr/bin/env bash
# bootstrap.sh — Entry point: chezmoi + mise dotfiles on a fresh Ubuntu machine
#
# Takes Ubuntu 22.04 / 24.04 (bare metal or WSL2) from zero to a fully
# configured development environment.
#
# Usage:
#   ./bootstrap.sh                              # Interactive
#   ./bootstrap.sh -y                           # Non-interactive, auto-detect user
#   ./bootstrap.sh -u enterpriseuser            # Specific user profile
#   ./bootstrap.sh --offline                    # Use local cache only (no downloads)
#   ./bootstrap.sh --offline --archive /path/to/bundle.tar.gz
#   ./bootstrap.sh --no-mise                    # Skip mise tool installation
#   ./bootstrap.sh --no-apt                     # Skip apt installs (no root required)
#   ./bootstrap.sh -v                           # Verbose/debug output
#
# This script is idempotent — safe to run multiple times.

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_INSTALL_URL="https://get.chezmoi.io"
MISE_INSTALL_URL="https://mise.run"

# ── Log levels ────────────────────────────────────────────────────────────────
readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4

# ── Colors (only when stdout is a terminal) ───────────────────────────────────
if [[ -t 1 ]]; then
  COLOR_RED='\033[0;31m'
  COLOR_GREEN='\033[0;32m'
  COLOR_YELLOW='\033[1;33m'
  COLOR_BLUE='\033[0;34m'
  COLOR_BOLD='\033[1m'
  COLOR_NC='\033[0m'
else
  COLOR_RED=''
  COLOR_GREEN=''
  COLOR_YELLOW=''
  COLOR_BLUE=''
  COLOR_BOLD=''
  COLOR_NC=''
fi

# ── Defaults ──────────────────────────────────────────────────────────────────
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}
ASSUME_YES=false
OFFLINE=false
SKIP_MISE=false
SKIP_APT=false
USERNAME="${USER:-$(whoami)}"
ARCHIVE_PATH=""
TEMP_FILES=()

# Platform state (populated by step_detect_platform)
IS_WSL=false
IS_LINUX=false
IS_MACOS=false

# ── Logging ───────────────────────────────────────────────────────────────────
log() {
  local level="$1"; shift
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  if [[ "$level" -le "$LOG_LEVEL" ]]; then
    case "$level" in
      "$LOG_LEVEL_ERROR") echo -e "${COLOR_RED}[ERROR]${COLOR_NC} [$timestamp] $message" >&2 ;;
      "$LOG_LEVEL_WARN")  echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC}  [$timestamp] $message" >&2 ;;
      "$LOG_LEVEL_INFO")  echo -e "${COLOR_GREEN}[INFO]${COLOR_NC}  [$timestamp] $message" ;;
      "$LOG_LEVEL_DEBUG") echo -e "${COLOR_BLUE}[DEBUG]${COLOR_NC} [$timestamp] $message" ;;
    esac
  fi
}

log_error() { log "$LOG_LEVEL_ERROR" "$@"; }
log_warn()  { log "$LOG_LEVEL_WARN"  "$@"; }
log_info()  { log "$LOG_LEVEL_INFO"  "$@"; }
log_debug() { log "$LOG_LEVEL_DEBUG" "$@"; }
log_step()  { echo -e "\n${COLOR_BOLD}${COLOR_BLUE}==>${COLOR_NC}${COLOR_BOLD} $*${COLOR_NC}"; }

# ── Error handling ────────────────────────────────────────────────────────────
die() {
  log_error "$1"
  log_error "Bootstrap failed. Check the output above for details."
  exit "${2:-1}"
}

cleanup_on_exit() {
  local exit_code=$?
  if [[ "${#TEMP_FILES[@]}" -gt 0 ]]; then
    log_debug "Cleaning up temporary files"
    rm -rf "${TEMP_FILES[@]}" 2>/dev/null || true
  fi
  tput sgr0 >/dev/null 2>&1 || true
  exit "$exit_code"
}

trap cleanup_on_exit EXIT INT TERM

# ── Ported utilities from lib/common.sh ──────────────────────────────────────

# Verify a command exists, exit with helpful message if not
require_command() {
  local cmd="$1"
  local install_hint="${2:-}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    local error_msg="Required command '$cmd' not found"
    if [[ -n "$install_hint" ]]; then
      error_msg="$error_msg. $install_hint"
    fi
    die "$error_msg"
  fi
}

# Download a URL to a file with optional checksum verification
fetch_url() {
  local url="$1"
  local output_file="$2"
  local expected_checksum="${3:-}"
  local checksum_algorithm="${4:-sha256}"

  log_info "Downloading: $url"

  if ! curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$output_file"; then
    die "Failed to download $url"
  fi

  if [[ -n "$expected_checksum" ]]; then
    log_debug "Verifying checksum ($checksum_algorithm)"
    local actual_checksum
    actual_checksum=$("${checksum_algorithm}sum" "$output_file" | cut -d' ' -f1)
    if [[ "$actual_checksum" != "$expected_checksum" ]]; then
      rm -f "$output_file"
      die "Checksum verification failed for $url (expected: $expected_checksum, got: $actual_checksum)"
    fi
    log_debug "Checksum verification passed"
  else
    log_warn "No checksum provided for $url — skipping verification"
  fi
}

# Back up a file with a timestamped suffix; prints backup path
backup_file() {
  local file="$1"
  local backup_suffix="${2:-.backup}"
  local timestamp
  timestamp=$(date '+%Y%m%d_%H%M%S')

  if [[ -f "$file" ]]; then
    local backup_path="${file}${backup_suffix}_${timestamp}"
    cp "$file" "$backup_path"
    log_info "Backed up: $file → $backup_path"
    echo "$backup_path"
  fi
}

# Prompt user with yes/no question; returns 0 for yes, 1 for no
# Always returns yes when ASSUME_YES=true
ask_yes_no() {
  local question="$1"
  local default="${2:-n}"
  local response

  if [[ "$ASSUME_YES" == true ]]; then
    log_debug "Auto-answering yes to: $question"
    return 0
  fi

  while true; do
    if [[ "$default" == "y" ]]; then
      read -rp "$question [Y/n]: " response
      response=${response:-y}
    else
      read -rp "$question [y/N]: " response
      response=${response:-n}
    fi

    case "${response,,}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     log_warn "Please answer yes or no." ;;
    esac
  done
}

# Display a progress bar
show_progress() {
  local current="$1"
  local total="$2"
  local task="$3"
  local width=50
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))

  printf "\r${COLOR_BLUE}[%s%s] %d%% - %s${COLOR_NC}" \
    "$(printf '%*s' "$filled" "" | tr ' ' '=')" \
    "$(printf '%*s' "$empty" "")" \
    "$percentage" \
    "$task"

  if [[ "$current" -eq "$total" ]]; then
    echo
  fi
}

# Validate a config file by type (json, yaml, nix)
validate_config_file() {
  local config_file="$1"
  local config_type="${2:-json}"

  if [[ ! -f "$config_file" ]]; then
    log_error "Configuration file not found: $config_file"
    return 1
  fi

  case "$config_type" in
    json)
      if ! jq empty "$config_file" 2>/dev/null; then
        log_error "Invalid JSON in: $config_file"
        return 1
      fi
      ;;
    yaml|yml)
      if command -v yq >/dev/null 2>&1; then
        if ! yq eval . "$config_file" >/dev/null 2>&1; then
          log_error "Invalid YAML in: $config_file"
          return 1
        fi
      else
        log_warn "yq not available — skipping YAML validation for $config_file"
      fi
      ;;
    *)
      log_warn "Unknown config type: $config_type — skipping validation"
      ;;
  esac

  log_debug "Config file validated: $config_file"
  return 0
}

# ── Platform detection ────────────────────────────────────────────────────────

is_wsl2() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    return 0
  elif [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    return 0
  elif [[ -f /proc/sys/fs/binfmt_misc/WSLInterop-late ]]; then
    return 0
  elif grep -qEi "(microsoft.*wsl2|wsl2)" /proc/version 2>/dev/null; then
    return 0
  elif [[ -n "${WSL_INTEROP:-}" ]]; then
    return 0
  fi
  return 1
}

detect_platform() {
  if is_wsl2 2>/dev/null; then
    echo "wsl2"
  elif [[ "$(uname -s)" == "Linux" ]]; then
    echo "linux"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

detect_os_version() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${VERSION_ID:-unknown}"
  else
    echo "unknown"
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    armv7l)        echo "armv7l" ;;
    *)             uname -m ;;
  esac
}

# ── Argument parsing ──────────────────────────────────────────────────────────
show_help() {
  cat <<EOF
bootstrap.sh — Dotfiles setup via chezmoi + mise

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -y, --yes                    Answer yes to all prompts (non-interactive)
    -u, --user <username>        Specify user profile (default: current user)
        --offline                Use local cache only (skip all downloads)
        --archive <path>         Extract tools from pre-built archive (implies --offline)
        --no-mise                Skip mise tool installation
        --no-apt                 Skip apt package installation (no root required)
    -v, --verbose                Enable verbose/debug logging
    -h, --help                   Show this help message

EXAMPLES:
    $0                                # Interactive setup
    $0 -y                             # Non-interactive, auto-detect user
    $0 -u enterpriseuser              # Use enterprise user profile
    $0 --offline                      # Offline mode (tools pre-installed)
    $0 --offline --archive /tmp/bundle.tar.gz

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        ASSUME_YES=true
        ;;
      --offline)
        OFFLINE=true
        ;;
      --no-mise)
        SKIP_MISE=true
        ;;
      --no-apt)
        SKIP_APT=true
        ;;
      --archive)
        shift
        ARCHIVE_PATH="${1:?--archive requires a path}"
        OFFLINE=true
        ;;
      -u|--user)
        shift
        USERNAME="${1:?--user requires a value}"
        if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
          die "--user value contains invalid characters (allowed: a-z A-Z 0-9 _ -)"
        fi
        ;;
      -v|--verbose)
        LOG_LEVEL=$LOG_LEVEL_DEBUG
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        die "Unknown option: $1. Use --help for usage information."
        ;;
    esac
    shift
  done
}

# ── Bootstrap steps ───────────────────────────────────────────────────────────

# Step 1: Detect platform, OS, arch — warn on unsupported versions
step_detect_platform() {
  log_step "Step 1/7 — Detecting platform"

  local platform os os_version arch
  platform=$(detect_platform)
  os=$(detect_os)
  os_version=$(detect_os_version)
  arch=$(detect_arch)

  case "$platform" in
    wsl2)   IS_WSL=true;  IS_LINUX=true ;;
    linux)  IS_LINUX=true ;;
    macos)  IS_MACOS=true ;;
  esac

  log_info "Platform:  $platform"
  log_info "OS:        ${os} ${os_version}"
  log_info "Arch:      $arch"
  log_info "Username:  $USERNAME"

  if [[ "$IS_WSL" == true ]]; then
    log_info "WSL2 detected — will apply WSL-specific configuration"
  fi

  # Warn on untested Ubuntu versions
  if [[ "$os" == "ubuntu" ]] && [[ "$os_version" != "22.04" && "$os_version" != "24.04" ]]; then
    log_warn "Ubuntu ${os_version} is not officially supported (tested: 22.04, 24.04)."
    if ! ask_yes_no "Continue anyway?" "n"; then
      die "Aborted — unsupported Ubuntu version: $os_version"
    fi
  fi
}

# Step 2: Install system prerequisites via apt
step_install_prerequisites() {
  log_step "Step 2/7 — Installing system prerequisites"

  local prereqs=(git curl build-essential zsh ca-certificates)

  if [[ "$IS_LINUX" == true ]] && command -v apt-get >/dev/null 2>&1; then
    if [[ "$SKIP_APT" == true ]]; then
      log_warn "Skipping apt prerequisites (--no-apt specified) — verifying commands exist"
      require_command git  "Install with: sudo apt-get install git"
      require_command curl "Install with: sudo apt-get install curl"
      return 0
    fi

    # Determine which prerequisites are missing
    local missing=()
    for pkg in "${prereqs[@]}"; do
      if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        missing+=("$pkg")
      fi
    done

    if [[ "${#missing[@]}" -gt 0 ]]; then
      log_info "Installing missing prerequisites: ${missing[*]}"
      if [[ "$OFFLINE" == false ]]; then
        sudo apt-get update -qq
      fi
      sudo apt-get install -y "${missing[@]}"
    else
      log_info "All prerequisites already installed"
    fi
  elif [[ "$IS_MACOS" == true ]]; then
    require_command git  "Install Xcode Command Line Tools: xcode-select --install"
    require_command curl "Install Xcode Command Line Tools: xcode-select --install"
  else
    log_warn "Non-apt system — verifying required commands exist"
    require_command git
    require_command curl
  fi
}

# Step 3: Install chezmoi (skip if already present)
step_install_chezmoi() {
  log_step "Step 3/7 — Installing chezmoi"

  mkdir -p "${HOME}/.local/bin"
  if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi

  if command -v chezmoi >/dev/null 2>&1; then
    log_info "chezmoi already installed: $(chezmoi --version)"
    return 0
  fi

  if [[ "$OFFLINE" == true ]]; then
    die "chezmoi not found and --offline mode is active. Pre-install chezmoi or use --archive."
  fi

  log_info "Downloading and installing chezmoi..."
  # Note: This uses the official chezmoi installer over HTTPS. For maximum
  # security in sensitive environments, use --archive with a pre-verified bundle
  # or pin to a specific version and verify the release checksum manually at
  # https://github.com/twpayne/chezmoi/releases
  sh -c "$(curl -fsSL "${CHEZMOI_INSTALL_URL}")" -- -b "${HOME}/.local/bin"
  log_info "chezmoi installed: $(chezmoi --version)"
}

# Step 4: Install mise (skip if already present or --no-mise)
step_install_mise() {
  if [[ "$SKIP_MISE" == true ]]; then
    log_warn "Skipping mise installation (--no-mise specified)"
    return 0
  fi

  log_step "Step 4/7 — Installing mise-en-place"

  if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi

  if command -v mise >/dev/null 2>&1; then
    log_info "mise already installed: $(mise --version)"
    return 0
  fi

  if [[ "$OFFLINE" == true ]]; then
    die "mise not found and --offline mode is active. Pre-install mise or use --archive."
  fi

  log_info "Downloading and installing mise..."
  # Note: This uses the official mise installer over HTTPS. For maximum
  # security in sensitive environments, use --archive with a pre-verified bundle
  # or pin to a specific version and verify the release checksum manually at
  # https://github.com/jdx/mise/releases
  curl -fsSL "${MISE_INSTALL_URL}" | sh
  export PATH="${HOME}/.local/bin:${PATH}"
  log_info "mise installed: $(mise --version)"
}

# Step 5: Back up existing configs, then apply chezmoi dotfiles
step_apply_chezmoi() {
  log_step "Step 5/7 — Applying dotfiles with chezmoi"

  # Pass selected user profile to chezmoi templates
  export DOTFILES_USER="${USERNAME}"
  log_info "Using profile: ${USERNAME}"

  local chezmoi_source="${SCRIPT_DIR}"
  local chezmoi_config="${HOME}/.config/chezmoi/chezmoi.toml"

  # Back up existing configs before the first-time apply
  # (chezmoi will overwrite them; we preserve originals)
  if [[ ! -f "$chezmoi_config" ]]; then
    log_info "First run — backing up existing config files before chezmoi apply"
    local configs_to_backup=(
      "${HOME}/.zshrc"
      "${HOME}/.bashrc"
      "${HOME}/.gitconfig"
      "${HOME}/.profile"
      "${HOME}/.bash_profile"
    )

    local backed_up=0
    for config in "${configs_to_backup[@]}"; do
      if [[ -f "$config" ]]; then
        backup_file "$config" ".pre-chezmoi"
        backed_up=$((backed_up + 1))
      fi
    done

    if [[ "$backed_up" -eq 0 ]]; then
      log_info "No existing configs to back up"
    else
      log_info "Backed up $backed_up existing config file(s)"
    fi

    log_info "Initializing chezmoi from source: ${chezmoi_source}"
    chezmoi init --source="${chezmoi_source}" --apply
  else
    log_info "chezmoi already initialized — running apply"
    chezmoi apply --source="${chezmoi_source}"
  fi

  log_info "Dotfiles applied successfully"
}

# Install apt Tier 1/3/4 dependencies via install-apt-deps.sh
step_install_apt_deps() {
  log_step "Installing apt dependencies (Tier 1/3/4)"

  if [[ "$IS_LINUX" != true ]] || ! command -v apt-get >/dev/null 2>&1; then
    log_warn "apt-get not available — skipping apt dependencies"
    return 0
  fi

  if [[ "$SKIP_APT" == true ]]; then
    log_warn "Skipping apt installation (--no-apt specified)"
    return 0
  fi

  local install_args=()
  if [[ "$OFFLINE" == true ]]; then
    install_args+=(--offline)
  fi

  if [[ -x "${SCRIPT_DIR}/scripts/install-apt-deps.sh" ]]; then
    "${SCRIPT_DIR}/scripts/install-apt-deps.sh" "${install_args[@]}"
  else
    log_warn "scripts/install-apt-deps.sh not found — skipping Tier 3/4 apt dependencies"
  fi
}

# Install mise Tier 1/2 tools
step_install_mise_tools() {
  if [[ "$SKIP_MISE" == true ]]; then
    return 0
  fi

  log_step "Installing mise tools (Tier 1/2)"

  if [[ "$OFFLINE" == true ]]; then
    log_info "Offline mode: using cached downloads"
    MISE_OFFLINE=1 mise install
  else
    mise install
  fi

  log_info "mise tools installed"
}

# Install Zsh plugins via install-zsh-plugins.sh
step_install_zsh_plugins() {
  if [[ "$SKIP_MISE" == true ]]; then
    log_debug "Skipping Zsh plugins (--no-mise specified; plugins may depend on mise tools)"
    return 0
  fi

  log_step "Installing Zsh plugins"

  if [[ -x "${SCRIPT_DIR}/scripts/install-zsh-plugins.sh" ]]; then
    "${SCRIPT_DIR}/scripts/install-zsh-plugins.sh"
  else
    log_warn "scripts/install-zsh-plugins.sh not found — skipping"
  fi
}

# Install Nerd Fonts (skipped in offline mode)
step_install_fonts() {
  if [[ "$SKIP_MISE" == true ]]; then
    log_debug "Skipping font installation (--no-mise specified)"
    return 0
  fi

  log_step "Installing Nerd Fonts"

  if [[ "$OFFLINE" == true ]]; then
    log_warn "Skipping font installation in offline mode"
    return 0
  fi

  if [[ -x "${SCRIPT_DIR}/scripts/install-fonts.sh" ]]; then
    "${SCRIPT_DIR}/scripts/install-fonts.sh"
  else
    log_warn "scripts/install-fonts.sh not found — skipping"
  fi
}

# WSL-specific post-configuration
step_wsl_setup() {
  if [[ "$IS_WSL" != true ]]; then
    return 0
  fi

  log_step "Applying WSL-specific configuration"

  if [[ -f "${SCRIPT_DIR}/wsl-fixes/wsl-setup.sh" ]]; then
    bash "${SCRIPT_DIR}/wsl-fixes/wsl-setup.sh"
  else
    log_debug "wsl-fixes/wsl-setup.sh not found — skipping WSL setup"
  fi
}

# Extract an offline bundle archive and add its bin/ to PATH
step_extract_archive() {
  if [[ -z "$ARCHIVE_PATH" ]]; then
    return 0
  fi

  log_step "Extracting offline archive"

  if [[ ! -f "$ARCHIVE_PATH" ]]; then
    die "Archive not found: $ARCHIVE_PATH"
  fi

  log_info "Extracting: $ARCHIVE_PATH"
  local extract_dir
  extract_dir=$(mktemp -d)
  TEMP_FILES+=("$extract_dir")

  tar -xzf "$ARCHIVE_PATH" -C "$extract_dir"

  if [[ -d "${extract_dir}/bin" ]]; then
    export PATH="${extract_dir}/bin:${PATH}"
    log_info "Added ${extract_dir}/bin to PATH"
  fi

  log_debug "Archive extraction complete"
}

# Step 6: Set Zsh as default shell (with user confirmation, idempotent)
step_set_default_shell() {
  log_step "Step 6/7 — Setting default shell"

  local zsh_path
  zsh_path=$(command -v zsh 2>/dev/null || true)

  if [[ -z "$zsh_path" ]]; then
    log_warn "zsh not found in PATH — skipping default shell configuration"
    return 0
  fi

  local current_shell
  current_shell=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || echo "${SHELL:-unknown}")

  if [[ "$current_shell" == "$zsh_path" ]]; then
    log_info "Default shell is already zsh ($zsh_path)"
    return 0
  fi

  log_info "Current shell: ${current_shell}"
  log_info "zsh path:      $zsh_path"

  if ask_yes_no "Set zsh as your default shell?" "y"; then
    # Ensure zsh is listed in /etc/shells
    if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
      log_info "Adding $zsh_path to /etc/shells"
      echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$zsh_path"
    log_info "Default shell set to zsh — takes effect on next login"
  else
    log_info "Skipping default shell change"
  fi
}

# Step 7: Print summary and next steps
step_print_summary() {
  log_step "Step 7/7 — Done"
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_GREEN}✓ Bootstrap complete!${COLOR_NC}"
  echo ""
  echo -e "${COLOR_BOLD}Next steps:${COLOR_NC}"
  echo "  1. Restart your shell or run:  source ~/.zshrc"
  echo "  2. Verify mise tools:          mise list"
  echo "  3. Verify chezmoi status:      chezmoi status"
  echo ""
  echo -e "${COLOR_BOLD}Update dotfiles later:${COLOR_NC}"
  echo "  chezmoi apply     # re-apply after editing source"
  echo "  mise upgrade      # update all tools"
  echo ""
  if [[ "$IS_WSL" == true ]]; then
    echo -e "${COLOR_BOLD}WSL note:${COLOR_NC}"
    echo "  GUI applications require WSL2 with WSLg support."
    echo "  Restart your terminal for all changes to take effect."
    echo ""
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  parse_arguments "$@"

  log_info "Bootstrap starting"
  log_debug "  ASSUME_YES: $ASSUME_YES"
  log_debug "  OFFLINE:    $OFFLINE"
  log_debug "  USERNAME:   $USERNAME"
  log_debug "  SKIP_MISE:  $SKIP_MISE"
  log_debug "  SKIP_APT:   $SKIP_APT"
  log_debug "  ARCHIVE:    ${ARCHIVE_PATH:-none}"

  # Extract offline archive first (if provided) so tools are available in PATH
  step_extract_archive

  step_detect_platform
  step_install_prerequisites
  step_install_chezmoi
  step_install_mise
  step_apply_chezmoi
  step_install_apt_deps
  step_install_mise_tools
  step_install_zsh_plugins
  step_install_fonts
  step_wsl_setup
  step_set_default_shell
  step_print_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
