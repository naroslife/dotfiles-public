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
log_info "── Tier 3: Language toolchains ──"
check_binary "node"
check_binary "python" "python3"
check_binary "go"
check_binary "rust" "rustc"
check_binary "java"
check_binary "maven" "mvn"
check_binary "gradle"
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
