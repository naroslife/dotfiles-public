#!/usr/bin/env bash
# scripts/install-zsh-plugins.sh
# Clone or update Zsh plugins (no framework required)
# Also installs tpm (tmux plugin manager)
# Called by bootstrap.sh and chezmoi run_onchange_ hooks

set -euo pipefail

PLUGIN_DIR="${HOME}/.local/share/zsh/plugins"
TPM_DIR="${HOME}/.tmux/plugins/tpm"

log_info() { echo "[INFO]  $*"; }

clone_or_update() {
  local name="$1"
  local repo="$2"
  local dest="$3"

  if [[ -d "${dest}/.git" ]]; then
    log_info "Updating ${name}..."
    git -C "${dest}" pull --quiet --ff-only 2>/dev/null \
      || log_info "  ${name}: already up to date"
  else
    log_info "Cloning ${name}..."
    mkdir -p "$(dirname "${dest}")"
    git clone --quiet --depth 1 "${repo}" "${dest}"
  fi
}

# ── Zsh plugins ────────────────────────────────────────────────────────────────
clone_or_update \
  "zsh-autosuggestions" \
  "https://github.com/zsh-users/zsh-autosuggestions.git" \
  "${PLUGIN_DIR}/zsh-autosuggestions"

clone_or_update \
  "zsh-syntax-highlighting" \
  "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
  "${PLUGIN_DIR}/zsh-syntax-highlighting"

clone_or_update \
  "fzf-tab" \
  "https://github.com/Aloxaf/fzf-tab.git" \
  "${PLUGIN_DIR}/fzf-tab"

# ── tmux plugin manager ────────────────────────────────────────────────────────
clone_or_update \
  "tpm" \
  "https://github.com/tmux-plugins/tpm.git" \
  "${TPM_DIR}"

log_info "Plugins ready:"
log_info "  Zsh plugins: ${PLUGIN_DIR}"
log_info "  tpm:         ${TPM_DIR}"
log_info ""
log_info "Source plugins in ~/.zshrc:"
log_info "  source ${PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"
log_info "  source ${PLUGIN_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
log_info "  source ${PLUGIN_DIR}/fzf-tab/fzf-tab.plugin.zsh"
