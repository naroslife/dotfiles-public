#!/usr/bin/env bash
# scripts/install-apt-deps.sh
# Install apt-managed dependencies for Tier 1/3/4 tools
# Called by bootstrap.sh — safe to run multiple times
#
# Usage:
#   ./scripts/install-apt-deps.sh          # online mode
#   ./scripts/install-apt-deps.sh --offline # skip apt update

set -euo pipefail

OFFLINE=false
[[ "${1:-}" == "--offline" ]] && OFFLINE=true

log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*" >&2; }

if [[ "${EUID}" -ne 0 ]] && ! command -v sudo &>/dev/null; then
  log_warn "Not root and no sudo. Skipping apt installation."
  exit 0
fi

SUDO=""
[[ "${EUID}" -ne 0 ]] && SUDO="sudo"

if [[ "${OFFLINE}" == false ]]; then
  log_info "Updating apt package list..."
  ${SUDO} apt-get update -qq
fi

# ── Tier 1 tools available via apt ────────────────────────────────────────────
APT_TIER1=(
  pv
  most
  stow
  git-crypt
  cloc
  mosh
  autossh
  sshfs
  openssh-client   # ssh-copy-id
  bsdmainutils     # hexdump
  xxd
)

# ── Tier 3 system toolchains ──────────────────────────────────────────────────
APT_TIER3=(
  gdb
  gcc
  g++
  build-essential
  clang-format
  clang-tidy
  valgrind
  lldb
  autoconf
  automake
  libtool
  strace
  ltrace
  cmake
  ninja-build
  pkg-config
)

# ── Tier 3 language support libraries ─────────────────────────────────────────
APT_LANG_SUPPORT=(
  libssl-dev
  libffi-dev
  python3-dev
  python3-pip
  python3-venv
)

# ── Tier 4 prerequisites ──────────────────────────────────────────────────────
APT_TIER4=(
  git
  git-lfs
  curl
  wget
  unzip
  tar
  zsh
  vim
  nano
  tmux
  nmap
)

ALL_PKGS=(
  "${APT_TIER1[@]}"
  "${APT_TIER3[@]}"
  "${APT_TIER4[@]}"
  "${APT_LANG_SUPPORT[@]}"
)

log_info "Installing ${#ALL_PKGS[@]} apt packages..."
${SUDO} apt-get install -y --no-install-recommends "${ALL_PKGS[@]}" 2>/dev/null || {
  log_warn "Some packages failed to install — continuing with best effort"
  for pkg in "${ALL_PKGS[@]}"; do
    ${SUDO} apt-get install -y --no-install-recommends "${pkg}" 2>/dev/null \
      || log_warn "  Skipped: ${pkg}"
  done
}

# ── git-lfs post-install hook ─────────────────────────────────────────────────
if command -v git-lfs &>/dev/null; then
  git lfs install --skip-smudge 2>/dev/null || true
fi

# ── perf tools (kernel-version-specific) ─────────────────────────────────────
KERNEL_VER="$(uname -r)"
PERF_PKG="linux-tools-${KERNEL_VER}"
if apt-cache show "${PERF_PKG}" &>/dev/null; then
  log_info "Installing kernel perf tools: ${PERF_PKG}"
  ${SUDO} apt-get install -y "${PERF_PKG}" 2>/dev/null \
    || log_warn "perf tools not available for kernel ${KERNEL_VER} — install linux-tools-generic manually"
else
  log_warn "Kernel-specific perf package ${PERF_PKG} not found in apt."
  log_warn "Install manually: sudo apt install linux-tools-\$(uname -r)"
fi

# ── rr — record & replay debugger ─────────────────────────────────────────────
if ! command -v rr &>/dev/null; then
  if apt-cache show rr &>/dev/null; then
    log_info "Installing rr..."
    ${SUDO} apt-get install -y rr 2>/dev/null || log_warn "rr not available via apt"
  else
    log_warn "rr not in apt — see: https://github.com/rr-debugger/rr for build instructions"
  fi
fi

log_info "apt dependency installation complete"
