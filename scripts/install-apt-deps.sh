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

# Returns true if $1 >= $2 (version comparison, e.g. ver_ge "24.10" "24.04")
# Returns false for non-version strings like "unknown" or empty
ver_ge() {
  [[ "${1}" =~ ^[0-9] ]] && \
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

if [[ "${EUID}" -ne 0 ]] && ! command -v sudo &>/dev/null; then
  log_warn "Not root and no sudo. Skipping apt installation."
  exit 0
fi

SUDO=""
[[ "${EUID}" -ne 0 ]] && SUDO="sudo"

# ── Detect Ubuntu version for package availability differences ─────────────────
UBUNTU_VERSION="unknown"
if [[ -f /etc/os-release ]]; then
  UBUNTU_VERSION=$(. /etc/os-release 2>/dev/null && printf '%s' "${VERSION_ID:-unknown}" || printf 'unknown')
fi

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
  cppcheck
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
  libssl-dev   # openssl (also needed for C/C++ builds)
  libffi-dev
  python3-dev
  python3-pip
  python3-venv
)

# ── C/C++ library headers (mapped from modules/dev/languages.nix) ──────────────
APT_CPP_LIBS=(
  libc6-dev              # glibc.dev
  libncurses-dev         # ncurses.dev
  libcap-dev             # libcap.dev
  libsystemd-dev         # systemd.dev
  libboost-all-dev       # boost
  libfmt-dev             # fmt
  libspdlog-dev          # spdlog
  libgtest-dev           # gtest
  libgmock-dev           # gtest (mock framework)
  libeigen3-dev          # eigen
  libopencv-dev          # opencv
  libgtk-4-dev           # gtk4
  libglfw3-dev           # glfw
  libglew-dev            # glew
  libvulkan-dev          # vulkan-headers + vulkan-loader
  vulkan-validationlayers-dev  # Vulkan validation layers
  mesa-vulkan-drivers    # Vulkan ICD implementations
  libcurl4-openssl-dev   # commonly needed for C/C++ projects
  zlib1g-dev             # commonly needed for C/C++ projects
  libprotobuf-dev        # commonly needed for C/C++ projects
  protobuf-compiler      # commonly needed for C/C++ projects
)

# Ubuntu 24.04+ has Catch2 v3 in apt; earlier versions only have v2
if ver_ge "${UBUNTU_VERSION}" "24.04"; then
  APT_CPP_LIBS+=(libcatch2-dev)  # catch2 — Catch2 v3
else
  log_warn "libcatch2-dev (Catch2 v3) not in apt for Ubuntu ${UBUNTU_VERSION} — use CMake FetchContent instead"
fi

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
  "${APT_CPP_LIBS[@]}"
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
