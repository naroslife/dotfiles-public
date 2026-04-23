#!/usr/bin/env bash
# scripts/build-offline-bundle.sh
# Build a self-contained offline deployment bundle for restricted machines
#
# Creates a tarball containing:
#   bin/chezmoi              - chezmoi binary
#   bin/mise                 - mise binary
#   mise-cache.tar.gz        - mise downloads + installs cache
#   zsh-plugins.tar.gz       - pre-cloned Zsh plugins + tpm
#
# Pre-requisites (run on unrestricted machine before bundling):
#   MISE_ALWAYS_KEEP_DOWNLOAD=1 mise install   # populate download cache
#   scripts/install-zsh-plugins.sh             # pre-clone zsh plugin repos
#
# Usage:
#   ./scripts/build-offline-bundle.sh
#   ./scripts/build-offline-bundle.sh --output /tmp/my-bundle.tar.gz
#   ./scripts/build-offline-bundle.sh --skip-zsh-plugins
#
# On restricted machine:
#   ./bootstrap.sh --offline --archive dotfiles-offline-bundle-YYYYMMDD.tar.gz

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
OUTPUT_FILE="dotfiles-offline-bundle-$(date +%Y%m%d).tar.gz"
SKIP_ZSH_PLUGINS=false
SKIP_MISE_CACHE=false

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
die()       { log_error "$1"; exit "${2:-1}"; }

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      shift
      OUTPUT_FILE="${1:?--output requires a path}"
      ;;
    --skip-zsh-plugins)
      SKIP_ZSH_PLUGINS=true
      ;;
    --skip-mise-cache)
      SKIP_MISE_CACHE=true
      ;;
    -h|--help)
      cat <<EOF
build-offline-bundle.sh — Build a self-contained offline deployment bundle

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -o, --output <path>        Output path (default: dotfiles-offline-bundle-YYYYMMDD.tar.gz)
        --skip-zsh-plugins     Exclude Zsh plugin repos from bundle
        --skip-mise-cache      Exclude mise tool cache from bundle
    -h, --help                 Show this help

EXAMPLES:
    $0
    $0 --output /tmp/bundle.tar.gz
    $0 --skip-zsh-plugins

PRE-REQUISITES (run before bundling):
    MISE_ALWAYS_KEEP_DOWNLOAD=1 mise install   # cache mise downloads
    scripts/install-zsh-plugins.sh             # pre-clone zsh plugins

EXPECTED BUNDLE SIZE: ~500MB–1GB for full toolset
EOF
      exit 0
      ;;
    *)
      if [[ "$1" != -* ]]; then
        OUTPUT_FILE="$1"
      else
        die "Unknown option: $1. Use --help for usage."
      fi
      ;;
  esac
  shift
done

# ── Pre-flight checks ─────────────────────────────────────────────────────────
log_info "=== Building offline deployment bundle ==="

CHEZMOI_BIN=$(command -v chezmoi 2>/dev/null) \
  || die "chezmoi not found. Install: sh -c \"\$(curl -fsSL https://get.chezmoi.io)\""
MISE_BIN=$(command -v mise 2>/dev/null) \
  || die "mise not found. Install: curl -fsSL https://mise.run | sh"

log_info "chezmoi: ${CHEZMOI_BIN} ($(chezmoi --version 2>/dev/null || echo 'unknown'))"
log_info "mise:    ${MISE_BIN} ($(mise --version 2>/dev/null || echo 'unknown'))"
log_info "Output:  ${OUTPUT_FILE}"

# ── Create temp staging directory ─────────────────────────────────────────────
BUNDLE_DIR=$(mktemp -d)
trap 'rm -rf "${BUNDLE_DIR}"' EXIT

log_info "Staging in: ${BUNDLE_DIR}"

# ── Step 1: Copy binaries ─────────────────────────────────────────────────────
log_info ""
log_info "Step 1/3 — Bundling binaries..."
mkdir -p "${BUNDLE_DIR}/bin"
cp "${CHEZMOI_BIN}" "${BUNDLE_DIR}/bin/chezmoi"
cp "${MISE_BIN}"    "${BUNDLE_DIR}/bin/mise"
chmod +x "${BUNDLE_DIR}/bin/chezmoi" "${BUNDLE_DIR}/bin/mise"
log_info "  chezmoi: $(du -sh "${BUNDLE_DIR}/bin/chezmoi" | cut -f1)"
log_info "  mise:    $(du -sh "${BUNDLE_DIR}/bin/mise"    | cut -f1)"

# ── Step 2: Bundle mise tool cache ────────────────────────────────────────────
if [[ "${SKIP_MISE_CACHE}" == false ]]; then
  log_info ""
  log_info "Step 2/3 — Bundling mise tool cache..."
  MISE_DATA_DIR="${MISE_DATA_DIR:-${HOME}/.local/share/mise}"

  MISE_ARCHIVE_PARTS=()
  for subdir in downloads installs; do
    if [[ -d "${MISE_DATA_DIR}/${subdir}" ]]; then
      MISE_ARCHIVE_PARTS+=(".local/share/mise/${subdir}")
    else
      log_warn "mise ${subdir} dir not found: ${MISE_DATA_DIR}/${subdir}"
      log_warn "  Run: MISE_ALWAYS_KEEP_DOWNLOAD=1 mise install"
    fi
  done

  if [[ "${#MISE_ARCHIVE_PARTS[@]}" -gt 0 ]]; then
    tar czf "${BUNDLE_DIR}/mise-cache.tar.gz" \
      -C "${HOME}" \
      "${MISE_ARCHIVE_PARTS[@]}"
    log_info "  mise cache: $(du -sh "${BUNDLE_DIR}/mise-cache.tar.gz" | cut -f1)"
  else
    log_warn "No mise cache found — target machine will require network to install tools"
  fi
else
  log_info "Step 2/3 — Skipping mise cache (--skip-mise-cache)"
fi

# ── Step 3: Bundle Zsh plugins + tpm ─────────────────────────────────────────
if [[ "${SKIP_ZSH_PLUGINS}" == false ]]; then
  log_info ""
  log_info "Step 3/3 — Bundling Zsh plugins..."
  ZSH_PLUGIN_DIR="${HOME}/.local/share/zsh/plugins"
  TPM_DIR="${HOME}/.tmux/plugins/tpm"

  ZSH_ARCHIVE_PARTS=()
  if [[ -d "${ZSH_PLUGIN_DIR}" ]]; then
    ZSH_ARCHIVE_PARTS+=(".local/share/zsh/plugins")
  else
    log_warn "Zsh plugin dir not found: ${ZSH_PLUGIN_DIR}"
    log_warn "  Run: scripts/install-zsh-plugins.sh"
  fi

  if [[ -d "${TPM_DIR}" ]]; then
    ZSH_ARCHIVE_PARTS+=(".tmux/plugins/tpm")
  else
    log_warn "tpm dir not found: ${TPM_DIR}"
    log_warn "  Run: scripts/install-zsh-plugins.sh"
  fi

  if [[ "${#ZSH_ARCHIVE_PARTS[@]}" -gt 0 ]]; then
    tar czf "${BUNDLE_DIR}/zsh-plugins.tar.gz" \
      -C "${HOME}" \
      "${ZSH_ARCHIVE_PARTS[@]}"
    log_info "  zsh plugins: $(du -sh "${BUNDLE_DIR}/zsh-plugins.tar.gz" | cut -f1)"
  else
    log_warn "No Zsh plugins found — target machine will require network to clone plugins"
  fi
else
  log_info "Step 3/3 — Skipping Zsh plugins (--skip-zsh-plugins)"
fi

# ── Create final bundle ────────────────────────────────────────────────────────
log_info ""
log_info "Creating final bundle: ${OUTPUT_FILE}"
tar czf "${OUTPUT_FILE}" -C "${BUNDLE_DIR}" .

BUNDLE_SIZE=$(du -sh "${OUTPUT_FILE}" | cut -f1)
log_info ""
log_info "=== Bundle ready ==="
log_info "  File: ${OUTPUT_FILE}"
log_info "  Size: ${BUNDLE_SIZE}"
log_info ""
log_info "Transfer to restricted machine:"
log_info "  scp ${OUTPUT_FILE} user@host:/tmp/"
log_info ""
log_info "Install on restricted machine:"
log_info "  cd ~/dotfiles-public"
log_info "  ./bootstrap.sh --offline --archive /tmp/$(basename "${OUTPUT_FILE}")"
log_info ""
log_info "Or use deploy-remote.sh for automated transfer + install:"
log_info "  ./deploy-remote.sh user@host --bundle ${OUTPUT_FILE}"
