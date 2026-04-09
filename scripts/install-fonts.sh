#!/usr/bin/env bash
# scripts/install-fonts.sh
# Download and install Nerd Fonts for terminal use
# Called by bootstrap.sh in online mode

set -euo pipefail

FONT_DIR="${HOME}/.local/share/fonts"
NERD_FONTS_VERSION="v3.3.0"
NERD_FONTS_BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}"

# Fonts to install — these cover most terminal emulators
FONTS=(
  "JetBrainsMono"
  "FiraCode"
  "Hack"
)

log_info() { echo "[INFO]  $*"; }
log_warn() { echo "[WARN]  $*" >&2; }

mkdir -p "${FONT_DIR}"

for font in "${FONTS[@]}"; do
  FONT_ZIP="${font}.zip"
  FONT_URL="${NERD_FONTS_BASE_URL}/${FONT_ZIP}"
  FONT_DEST="${FONT_DIR}/${font}"

  if [[ -d "${FONT_DEST}" ]]; then
    log_info "Font already installed: ${font}"
    continue
  fi

  log_info "Downloading ${font} Nerd Font..."
  TMPDIR="$(mktemp -d)"

  if curl -fsSL "${FONT_URL}" -o "${TMPDIR}/${FONT_ZIP}"; then
    mkdir -p "${FONT_DEST}"
    unzip -q "${TMPDIR}/${FONT_ZIP}" -d "${FONT_DEST}" 2>/dev/null \
      && log_info "Installed: ${font}" \
      || log_warn "Failed to extract ${FONT_ZIP}"
  else
    log_warn "Failed to download ${font} from ${FONT_URL}"
  fi

  rm -rf "${TMPDIR}"
done

# Rebuild font cache
if command -v fc-cache &>/dev/null; then
  log_info "Rebuilding font cache..."
  fc-cache -f "${FONT_DIR}"
  log_info "Font cache updated"
fi

log_info "Fonts installed to: ${FONT_DIR}"
log_info "Restart your terminal and set font to 'JetBrainsMono Nerd Font'"
