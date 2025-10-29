#!/usr/bin/env bash
# Common utility functions for dotfiles scripts
# This library provides shared functionality to ensure consistency across all scripts

# Guard against multiple sourcing
if [[ -n "${COMMON_SH_LOADED:-}" ]]; then
  return 0
fi
COMMON_SH_LOADED=1

set -euo pipefail

LOG_LEVEL_SUCCESS=1
LOG_LEVEL_ERROR=2
LOG_LEVEL_WARN=3
LOG_LEVEL_INFO=4
LOG_LEVEL_DEBUG=5

# Default log level
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Colors for output
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_NC='\033[0m' # No Color

# Logging functions
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  if [[ $level -le $LOG_LEVEL ]]; then
    case $level in
    "$LOG_LEVEL_SUCCESS")
      echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} [$timestamp] $message"
      ;;
    "$LOG_LEVEL_ERROR")
      echo -e "${COLOR_RED}[ERROR]${COLOR_NC} [$timestamp] $message" >&2
      ;;
    "$LOG_LEVEL_WARN")
      echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} [$timestamp] $message" >&2
      ;;
    "$LOG_LEVEL_INFO")
      echo -e "${COLOR_GREEN}[INFO]${COLOR_NC} [$timestamp] $message"
      ;;
    "$LOG_LEVEL_DEBUG")
      echo -e "${COLOR_BLUE}[DEBUG]${COLOR_NC} [$timestamp] $message"
      ;;
    esac
  fi
}

log_error() { log "$LOG_LEVEL_ERROR" "$1"; }
log_warn() { log "$LOG_LEVEL_WARN" "$1"; }
log_info() { log "$LOG_LEVEL_INFO" "$1"; }
log_debug() { log "$LOG_LEVEL_DEBUG" "$1"; }
log_success() { log "$LOG_LEVEL_SUCCESS" "$1"; }


# Enhanced error handling with recovery suggestions
die() {
  local error_msg="$1"
  local exit_code="${2:-1}"
  local suggestion="${3:-}"

  log_error "$error_msg"

  # Show suggestion if provided
  if [[ -n "$suggestion" ]]; then
    echo -e "${COLOR_CYAN}💡 Suggestion: ${suggestion}${COLOR_NC}" >&2
  fi

  exit "$exit_code"
}

# Suggest common fixes for known error patterns
suggest_fix() {
  local error_context="$1"

  case "$error_context" in
  "nix_not_found")
    echo "Install Nix: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    ;;
  "git_not_found")
    echo "Install git: sudo apt install git (Ubuntu/Debian) or brew install git (macOS)"
    ;;
  "home_manager_fail")
    echo "Try: 1) nix flake update  2) Check ~/.config/nix/nix.conf has 'experimental-features = nix-command flakes'"
    ;;
  "permission_denied")
    echo "Check file permissions or run with appropriate user privileges"
    ;;
  "network_error")
    echo "Check internet connection and proxy settings. Try: curl -I https://cache.nixos.org"
    ;;
  "disk_space")
    echo "Free up disk space: nix-collect-garbage -d or df -h to check available space"
    ;;
  *)
    echo "Check logs above for details, or run with LOG_LEVEL=4 for debug output"
    ;;
  esac
}

# Command existence check with better error messages
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

# Safe URL fetching with checksum verification
fetch_url() {
  local url="$1"
  local output_file="$2"
  local expected_checksum="${3:-}"
  local checksum_algorithm="${4:-sha256}"

  log_info "Downloading $url"

  if ! curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$output_file"; then
    die "Failed to download $url"
  fi

  if [[ -n "$expected_checksum" ]]; then
    log_debug "Verifying checksum using $checksum_algorithm"
    local actual_checksum
    actual_checksum=$("${checksum_algorithm}sum" "$output_file" | cut -d' ' -f1)

    if [[ "$actual_checksum" != "$expected_checksum" ]]; then
      rm -f "$output_file"
      die "Checksum verification failed for $url (expected: $expected_checksum, got: $actual_checksum)"
    fi
    log_debug "Checksum verification passed"
  else
    log_warn "No checksum provided for $url - security risk!"
  fi
}

is_wsl2() {
  local is_wsl2=false
  local detection_method=""

  # Method 1: Check WSL_DISTRO_NAME environment variable (most reliable)
  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    is_wsl2=true
    detection_method="WSL_DISTRO_NAME environment variable"
  # Method 2: Check for WSLInterop (standard WSL2)
  elif [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    is_wsl2=true
    detection_method="WSLInterop file"
  # Method 3: Check for WSLInterop-late (systemd-enabled WSL2)
  elif [[ -f /proc/sys/fs/binfmt_misc/WSLInterop-late ]]; then
    is_wsl2=true
    detection_method="WSLInterop-late file (systemd enabled)"
  # Method 4: Check kernel version for WSL2 signature
  elif command grep -qEi "(microsoft.*wsl2|wsl2)" /proc/version 2>/dev/null; then
    is_wsl2=true
    detection_method="kernel version"
  # Method 5: Check WSL_INTEROP environment variable
  elif [[ -n "${WSL_INTEROP:-}" ]]; then
    is_wsl2=true
    detection_method="WSL_INTEROP environment variable"
  fi

  if [[ "$is_wsl2" == true ]]; then
    log_debug "Running on WSL2 (detected via $detection_method)"
    return 0
  fi

  log_debug "Not running on WSL2"
  return 1
}

is_linux() {
  [[ "$(uname -s)" == "Linux" ]] && ! is_wsl2
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

# Platform detection (echoes platform string)
# Uses return codes from is_*() functions to avoid output contamination
detect_platform() {
  # Redirect all output from is_* functions to /dev/null to ensure clean string return
  if is_wsl2 >/dev/null 2>&1; then
    echo "wsl2"
  elif is_linux >/dev/null 2>&1; then
    echo "linux"
  elif is_macos >/dev/null 2>&1; then
    echo "macos"
  else
    echo "unknown"
  fi
}

# OS detection
detect_os() {
  local platform="unknown"

  # Check for Linux variants
  if [[ -f /etc/os-release ]]; then
    # Regular Linux
    . /etc/os-release
    platform="${ID:-unknown}"
  fi

  echo "$platform"
}

# Architecture detection
detect_arch() {
  case "$(uname -m)" in
  x86_64 | amd64)
    echo "x86_64"
    ;;
  aarch64 | arm64)
    echo "aarch64"
    ;;
  armv7l)
    echo "armv7l"
    ;;
  *)
    echo "$(uname -m)"
    ;;
  esac
}

# OS version detection
detect_os_version() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "${VERSION_ID:-unknown}"
  else
    echo "unknown"
  fi
}

# Check for Nix
check_nix() {
  if command -v nix >/dev/null 2>&1; then
    echo "installed"
    nix --version | head -1
  else
    echo "not_installed"
  fi
}

# Check disk space
check_disk_space() {
  local path="${1:-/}"
  df -h "$path" | tail -1 | awk '{print $4}'
}

# Check memory
check_memory() {
  free -h | grep "^Mem:" | awk '{print $2}'
}

# Check for systemd
check_systemd() {
  if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
    echo "available"
  else
    echo "not_available"
  fi
}

# Check for existing Home Manager
check_home_manager() {
  if command -v home-manager >/dev/null 2>&1; then
    echo "installed"
    home-manager --version 2>/dev/null || echo "version_unknown"
  else
    echo "not_installed"
  fi
}

# Check for corporate proxy
check_proxy() {
  if [[ -n "${HTTP_PROXY:-}" ]] || [[ -n "${HTTPS_PROXY:-}" ]]; then
    echo "configured"
    echo "HTTP_PROXY: ${HTTP_PROXY:-not_set}"
    echo "HTTPS_PROXY: ${HTTPS_PROXY:-not_set}"
  else
    echo "not_configured"
  fi
}

# WSL-specific checks
wsl_info() {

  # Check Windows interop
  if [[ -n "${WSLENV:-}" ]]; then
    echo "WINDOWS_INTEROP: enabled"
  else
    echo "WINDOWS_INTEROP: disabled"
  fi

  # Check systemd in WSL
  if [[ -f /etc/wsl.conf ]]; then
    if grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
      echo "SYSTEMD_WSL: enabled"
    else
      echo "SYSTEMD_WSL: disabled"
    fi
  fi

}

platform_info() {
  cat <<EOF
{
  "platform": "$(detect_platform)",
  "os": "$(detect_os)",
  "arch": "$(detect_arch)",
  "os_version": "$(detect_os_version)",
  "kernel": "$(uname -r)",
  "nix": "$(check_nix)",
  "home_manager": "$(check_home_manager)",
  "disk_space": "$(check_disk_space /)",
  "memory": "$(check_memory)",
  "systemd": "$(check_systemd)",
  "proxy": "$(check_proxy)",
  "user": "$(whoami)",
  "home": "$HOME",
  "shell": "$SHELL",
  "path_separator": ":",
  "temp_dir": "${TMPDIR:-/tmp}"
}
EOF

  # Add WSL-specific information if applicable
  if [[ "$(detect_platform)" == "wsl2" ]]; then
    echo "WSL_INFO:"
    wsl_info
  fi
}

# User interaction functions
ask_yes_no() {
  local question="$1"
  local default="${2:-n}"
  local response

  while true; do
    if [[ "$default" == "y" ]]; then
      read -p "$question [Y/n]: " -r response
      response=${response:-y}
    else
      read -p "$question [y/N]: " -r response
      response=${response:-n}
    fi

    case "${response,,}" in
    y | yes) return 0 ;;
    n | no) return 1 ;;
    *) log_warn "Please answer yes or no." ;;
    esac
  done
}

# File operations with safety checks
backup_file() {
  local file="$1"
  local backup_suffix="${2:-.backup}"
  local timestamp
  timestamp=$(date '+%Y%m%d_%H%M%S')

  if [[ -f "$file" ]]; then
    local backup_file="${file}${backup_suffix}_${timestamp}"
    cp "$file" "$backup_file"
    log_info "Backed up $file to $backup_file" >&2
    echo "$backup_file"
  fi
}

# Configuration validation
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
      log_error "Invalid JSON in configuration file: $config_file"
      return 1
    fi
    ;;
  yaml | yml)
    if command -v yq >/dev/null 2>&1; then
      if ! yq eval . "$config_file" >/dev/null 2>&1; then
        log_error "Invalid YAML in configuration file: $config_file"
        return 1
      fi
    else
      log_warn "yq not available - skipping YAML validation for $config_file"
    fi
    ;;
  nix)
    if command -v nix >/dev/null 2>&1; then
      if ! nix-instantiate --parse "$config_file" >/dev/null 2>&1; then
        log_error "Invalid Nix syntax in configuration file: $config_file"
        return 1
      fi
    else
      log_warn "nix not available - skipping Nix validation for $config_file"
    fi
    ;;
  *)
    log_warn "Unknown configuration type: $config_type - skipping validation"
    ;;
  esac

  log_debug "Configuration file validation passed: $config_file"
  return 0
}

# Progress indication
show_progress() {
  local current="$1"
  local total="$2"
  local task="$3"
  local width=50
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))

  printf "\r${COLOR_BLUE}[%s%s] %d%% - %s${COLOR_NC}" \
    "$(printf "%*s" $filled | tr ' ' '=')" \
    "$(printf "%*s" $empty)" \
    "$percentage" \
    "$task"

  if [[ $current -eq $total ]]; then
    echo
  fi
}

# Cleanup trap
cleanup_on_exit() {
  local exit_code=$?

  # Remove any temporary files
  if [[ -n "${TEMP_FILES:-}" ]]; then
    log_debug "Cleaning up temporary files: $TEMP_FILES"
    # shellcheck disable=SC2086
    rm -f $TEMP_FILES 2>/dev/null || true
  fi

  # Reset terminal state if needed
  if [[ -n "${RESET_TERMINAL:-}" ]]; then
    tput sgr0 2>/dev/null || true
  fi

  exit $exit_code
}

# Set up cleanup trap
trap cleanup_on_exit EXIT INT TERM

# Export functions that should be available to sourcing scripts
export -f log log_success log_error log_warn log_info log_debug
export -f die suggest_fix require_command fetch_url
export -f detect_platform is_wsl2 is_linux is_macos
export -f ask_yes_no backup_file validate_config_file
export -f show_progress
