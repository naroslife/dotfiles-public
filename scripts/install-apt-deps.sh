#!/usr/bin/env bash
# scripts/install-apt-deps.sh
# Install apt-managed dependencies for Tier 1/3/4 tools and C/C++ libraries
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

# Detect Ubuntu version for package availability differences
# shellcheck source=/dev/null
UBUNTU_VERSION="$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-unknown}" || echo "unknown")"
log_info "Detected Ubuntu version: ${UBUNTU_VERSION}"

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

# ── C/C++ build libraries (Tier 3) ────────────────────────────────────────────
# Derived from modules/dev/languages.nix — headers, .pc files, cmake configs
# Note: libcatch2-dev is Ubuntu 24.04+ only (see version-conditional block below)
APT_CPP_LIBS=(
  # Core system headers
  libc6-dev          # glibc.dev — C standard library headers
  libssl-dev         # openssl — TLS/crypto headers
  libncurses-dev     # ncurses.dev — terminal UI library
  libcap-dev         # libcap.dev — POSIX capabilities
  libsystemd-dev     # systemd.dev — systemd integration

  # Widely-used C++ libraries
  libboost-all-dev   # boost — comprehensive C++ utility library
  libfmt-dev         # fmt — modern C++ formatting library
  libspdlog-dev      # spdlog — fast C++ logging library

  # Testing frameworks
  libgtest-dev       # gtest — Google Test framework
  libgmock-dev       # gtest — Google Mock (bundled with gtest)

  # Math / data science
  libeigen3-dev      # eigen — C++ template library for linear algebra

  # Computer vision / graphics
  libopencv-dev      # opencv — computer vision library
  libgtk-4-dev       # gtk4 — GTK4 UI toolkit
  libglfw3-dev       # glfw — OpenGL/Vulkan window and input
  libglew-dev        # glew — OpenGL Extension Wrangler

  # Vulkan
  libvulkan-dev                # vulkan-headers + vulkan-loader
  vulkan-validationlayers-dev  # Vulkan validation layers
  mesa-vulkan-drivers          # Mesa Vulkan ICD (software + AMD/Intel)
)

# ── Tier 3 language support libraries ─────────────────────────────────────────
APT_LANG_SUPPORT=(
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

# ── Catch2 v3 (Ubuntu 24.04+ only) ───────────────────────────────────────────
# Ubuntu 22.04 ships Catch2 v2 (libcatch2-dev is v2); Ubuntu 24.04+ ships v3.
# For 22.04, use CMake FetchContent or build from source.
# Uses awk numeric comparison (>=24.04) to handle 24.04, 24.10, 25.04, etc.
if awk -v ver="${UBUNTU_VERSION}" 'BEGIN { exit !(ver != "unknown" && ver + 0 >= 24.04) }'; then
  log_info "Installing libcatch2-dev (Catch2 v3, Ubuntu ${UBUNTU_VERSION})..."
  ${SUDO} apt-get install -y --no-install-recommends libcatch2-dev 2>/dev/null \
    || log_warn "libcatch2-dev not available — install Catch2 v3 via CMake FetchContent"
else
  log_warn "Ubuntu ${UBUNTU_VERSION}: libcatch2-dev in apt is Catch2 v2."
  log_warn "  For Catch2 v3, use CMake FetchContent or build from source."
fi

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
