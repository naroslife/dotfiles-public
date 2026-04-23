#!/usr/bin/env bash
# scripts/doctor.sh
# Check tool installations managed by mise and report status
#
# Usage:
#   mise run doctor          # via mise task runner
#   ./scripts/doctor.sh      # direct
#   ./scripts/doctor.sh --verbose

set -euo pipefail

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

PASS=0
FAIL=0
WARN=0

log_pass() { echo "  ✓ $*"; ((PASS++)) || true; }
log_fail() { echo "  ✗ $*" >&2; ((FAIL++)) || true; }
log_warn() { echo "  ! $*"; ((WARN++)) || true; }
log_info() { echo "$*"; }

check_binary() {
  local name="$1"
  local binary="${2:-$1}"
  if command -v "${binary}" &>/dev/null; then
    if [[ "${VERBOSE}" == true ]]; then
      local version
      version=$("${binary}" --version 2>&1 | head -1 || echo "unknown")
      log_pass "${name}: ${version}"
    else
      log_pass "${name}"
    fi
    return 0
  else
    log_fail "${name}: not found (run: mise install)"
    return 1
  fi
}

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE "(microsoft.*wsl|wsl2)" /proc/version 2>/dev/null
}

# ── Preflight ──────────────────────────────────────────────────────────────────
log_info "=== dotfiles doctor ==="
log_info ""

log_info "── Prerequisites ──"
if ! command -v mise &>/dev/null; then
  echo "FATAL: mise not found. Run ./bootstrap.sh to install mise first." >&2
  exit 1
fi
log_pass "mise: $(mise --version 2>&1 | head -1)"

if command -v chezmoi &>/dev/null; then
  log_pass "chezmoi: $(chezmoi --version 2>&1 | head -1)"
else
  log_warn "chezmoi: not found (run: ./bootstrap.sh)"
fi

log_info ""
log_info "── Tier 2: Shell environment tools ──"
check_binary "starship"
check_binary "atuin"
check_binary "fzf"
check_binary "carapace"
check_binary "zoxide"
check_binary "direnv"
check_binary "mcfly"
check_binary "helix" "hx"

log_info ""
log_info "── Tier 1: Modern CLI replacements ──"
check_binary "bat"
check_binary "eza"
check_binary "fd"
check_binary "ripgrep" "rg"
check_binary "duf"
check_binary "dust"
check_binary "procs"
check_binary "bottom" "btm"
check_binary "xh"
check_binary "gping"
check_binary "dog"

log_info ""
log_info "── Tier 1: Data & text processing ──"
check_binary "jq"
check_binary "yq"
check_binary "fx"
check_binary "miller" "mlr"
check_binary "choose"
check_binary "sad"
check_binary "sampler"

log_info ""
log_info "── Tier 1: Git tools ──"
check_binary "lazygit"
check_binary "delta"
check_binary "difftastic" "difft"
check_binary "gitui"
check_binary "gh"
check_binary "git-absorb"
check_binary "gitleaks"
check_binary "git-filter-repo"
check_binary "pre-commit"

log_info ""
log_info "── Tier 1: Container & K8s ──"
check_binary "lazydocker"
check_binary "k9s"
check_binary "kubectx"
check_binary "kubectl"
check_binary "helm"

log_info ""
log_info "── Tier 1: Code analysis ──"
check_binary "tokei"
check_binary "scc"
check_binary "sccache"

log_info ""
log_info "── Tier 1: Productivity ──"
check_binary "tealdeer" "tldr"
check_binary "cheat"
check_binary "navi"
check_binary "broot" "br"
check_binary "termscp"
check_binary "rclone"
check_binary "restic"
check_binary "usql"

log_info ""
log_info "── Tier 1: Python-based tools ──"
check_binary "httpie" "http"
check_binary "visidata" "vd"
check_binary "ranger"
check_binary "pgcli"

log_info ""
log_info "── Tier 1: Monitoring ──"
check_binary "bandwhich"
check_binary "rustscan"

log_info ""
log_info "── Tier 3: System toolchains (apt) ──"

# GDB: verify Python scripting support and data-directory
if command -v gdb &>/dev/null; then
  _gdb_out=$(gdb -batch -ex "python print('gdb-python-ok')" 2>&1)
  if echo "${_gdb_out}" | grep -q "gdb-python-ok"; then
    log_pass "gdb (Python scripting)"
  else
    log_fail "gdb: Python scripting not working — install: sudo apt install gdb python3-dev"
  fi
  _gdb_datadir=$(gdb -batch -ex "show data-directory" 2>&1 | grep -oP '(?<=").*?(?=")' | head -1)
  if [[ -d "${_gdb_datadir:-/nonexistent}" ]]; then
    log_pass "gdb data-directory: ${_gdb_datadir}"
  else
    log_warn "gdb: data-directory not found (${_gdb_datadir:-unset})"
  fi
else
  log_fail "gdb: not found — run: sudo apt install gdb"
fi

# CMake: verify module resolution (FindThreads must be resolvable)
if command -v cmake &>/dev/null; then
  if cmake --help-module FindThreads &>/dev/null; then
    log_pass "cmake (FindThreads module)"
  else
    log_fail "cmake: module directory missing — run: sudo apt install cmake"
  fi
else
  log_fail "cmake: not found — run: sudo apt install cmake"
fi

# GCC: verify compilation works end-to-end
if command -v gcc &>/dev/null; then
  if echo 'int main(){}' | gcc -x c - -o /dev/null 2>/dev/null; then
    log_pass "gcc (compilation test)"
  else
    log_fail "gcc: compilation test failed"
  fi
  check_binary "g++"
else
  log_fail "gcc: not found — run: sudo apt install gcc g++ build-essential"
fi

# clang-tools: verify resource directory is accessible
if command -v clang-format &>/dev/null; then
  if echo '{}' | clang-format 2>/dev/null | grep -q '{}'; then
    log_pass "clang-format"
  else
    log_warn "clang-format: resource directory may be missing"
  fi
else
  log_fail "clang-format: not found — run: sudo apt install clang-format clang-tidy"
fi
check_binary "clang-tidy"

# Valgrind: binary + functional test if gcc available
if command -v valgrind &>/dev/null; then
  _vg_tmp=$(mktemp /tmp/doctor-valgrind-XXXXXX)
  if echo 'int main(){}' | gcc -x c - -g -o "${_vg_tmp}" 2>/dev/null; then
    if valgrind --error-exitcode=1 --quiet "${_vg_tmp}" 2>/dev/null; then
      log_pass "valgrind (functional)"
    else
      log_fail "valgrind: error running test binary"
    fi
  else
    log_pass "valgrind (binary only — gcc not available for functional test)"
  fi
  rm -f "${_vg_tmp}"
else
  log_fail "valgrind: not found — run: sudo apt install valgrind"
fi

# LLDB
check_binary "lldb"

# strace/ltrace
if command -v strace &>/dev/null; then
  if strace -e trace=read echo hello &>/dev/null; then
    log_pass "strace"
  else
    log_warn "strace: running but functional test failed (may need ptrace permissions)"
  fi
else
  log_fail "strace: not found — run: sudo apt install strace"
fi
check_binary "ltrace"

# autoconf / build system tools
if command -v autoconf &>/dev/null; then
  log_pass "autoconf: $(autoconf --version 2>&1 | head -1)"
else
  log_fail "autoconf: not found — run: sudo apt install autoconf automake libtool"
fi
check_binary "automake"
check_binary "libtool" "libtool"

# Build system helpers (ninja, pkg-config) — also moved to tier3_apt
check_binary "ninja" "ninja"
check_binary "pkg-config"

# perf tools (kernel-version-specific, unavailable on WSL2)
if is_wsl; then
  log_warn "perf: not supported on WSL2 (kernel perf events unavailable) — native Linux only"
elif command -v perf &>/dev/null; then
  log_pass "perf (linux-tools)"
else
  log_warn "perf: not found — install: sudo apt install linux-tools-\$(uname -r)"
fi

# rr — record & replay debugger (requires perf_event, unavailable on WSL2)
if is_wsl; then
  log_warn "rr: not supported on WSL2 (no perf_event support) — native Linux only"
elif command -v rr &>/dev/null; then
  log_pass "rr: $(rr --version 2>&1 | head -1)"
else
  log_warn "rr: not installed — optional; install if available: sudo apt install rr"
fi

log_info ""
log_info "── Tier 3: Language toolchains (mise) ──"

# Java: binary + JAVA_HOME via mise activate
if command -v java &>/dev/null; then
  log_pass "java: $(java -version 2>&1 | head -1)"
  if command -v javac &>/dev/null; then
    log_pass "javac: $(javac -version 2>&1)"
  else
    log_fail "javac: not found (JAVA_HOME may not include bin/javac)"
  fi
  if [[ -n "${JAVA_HOME:-}" ]] && [[ -x "${JAVA_HOME}/bin/java" ]]; then
    log_pass "JAVA_HOME=${JAVA_HOME}"
  else
    log_warn "JAVA_HOME: not set or invalid — ensure 'eval \"\$(mise activate bash)\"' runs before checks"
  fi
else
  log_fail "java: not found — run: mise install java"
fi
if command -v mvn &>/dev/null; then
  log_pass "mvn: $(mvn --version 2>&1 | head -1)"
else
  log_fail "mvn (maven): not found — run: mise install maven"
fi
if command -v gradle &>/dev/null; then
  log_pass "gradle: $(gradle --version 2>&1 | grep '^Gradle' | head -1)"
else
  log_fail "gradle: not found — run: mise install gradle"
fi

# Go: binary + GOROOT src/ present
if command -v go &>/dev/null; then
  log_pass "go: $(go version)"
  _goroot=$(go env GOROOT 2>/dev/null)
  if [[ -d "${_goroot}/src" ]]; then
    log_pass "GOROOT=${_goroot} (src/ present)"
  else
    log_fail "GOROOT=${_goroot:-unset}: src/ missing"
  fi
  log_pass "GOPATH=${GOPATH:-$(go env GOPATH)}"
else
  log_fail "go: not found — run: mise install go"
fi

# Node.js
if command -v node &>/dev/null; then
  log_pass "node: $(node --version)"
  if command -v npm &>/dev/null; then
    log_pass "npm: $(npm --version)"
  else
    log_fail "npm: not found"
  fi
  if command -v npx &>/dev/null; then
    log_pass "npx"
  else
    log_warn "npx: not found"
  fi
else
  log_fail "node: not found — run: mise install node"
fi

# Rust
if command -v rustc &>/dev/null; then
  log_pass "rustc: $(rustc --version)"
  if command -v cargo &>/dev/null; then
    log_pass "cargo: $(cargo --version)"
  else
    log_fail "cargo: not found"
  fi
  if command -v rustup &>/dev/null; then
    log_pass "rustup: $(rustup --version 2>&1 | head -1)"
  else
    log_warn "rustup: not found"
  fi
  if [[ -n "${CARGO_HOME:-}" ]]; then
    log_pass "CARGO_HOME=${CARGO_HOME}"
  else
    log_warn "CARGO_HOME: not set (defaulting to ~/.cargo)"
  fi
  if [[ -n "${RUSTUP_HOME:-}" ]]; then
    log_pass "RUSTUP_HOME=${RUSTUP_HOME}"
  else
    log_warn "RUSTUP_HOME: not set (defaulting to ~/.rustup)"
  fi
else
  log_fail "rustc: not found — run: mise install rust"
fi

# Python: binary + venv support
if command -v python3 &>/dev/null; then
  log_pass "python3: $(python3 --version)"
  if python3 -m venv --help &>/dev/null; then
    log_pass "python3-venv (venv module)"
  else
    log_fail "python3-venv: missing — run: sudo apt install python3-venv"
  fi
else
  log_fail "python3: not found — run: mise install python"
fi

check_binary "bazel"
check_binary "meson"

log_info ""
log_info "── Tier 3: Editors ──"
check_binary "neovim" "nvim"

log_info ""
log_info "── Apt-managed tools (Tier 4) ──"
for tool in git tmux ssh curl wget unzip; do
  check_binary "${tool}"
done

# ── Summary ────────────────────────────────────────────────────────────────────
log_info ""
log_info "=== Summary ==="
log_info "  Passed:   ${PASS}"
log_info "  Warnings: ${WARN}"
log_info "  Failed:   ${FAIL}"
log_info ""

if [[ "${FAIL}" -gt 0 ]]; then
  log_info "To install missing tools: mise install"
  log_info "To install apt tools:     ./scripts/install-apt-deps.sh"
  exit 1
fi

if [[ "${WARN}" -gt 0 ]]; then
  exit 2
fi

log_info "All tools healthy!"
exit 0
