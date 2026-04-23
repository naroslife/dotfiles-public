#!/usr/bin/env bash
# deploy-remote.sh — Deploy dotfiles to a remote restricted machine
#
# Builds a self-contained offline bundle locally (or uses a provided one),
# transfers it to the remote via scp, rsyncs the dotfiles repo, then runs
# bootstrap.sh --offline on the remote.
#
# Usage:
#   ./deploy-remote.sh user@host
#   ./deploy-remote.sh user@host --bundle /path/to/bundle.tar.gz
#   ./deploy-remote.sh user@host --user enterpriseuser -y
#
# Transfer alternatives (when scp is unavailable — see docs/OFFLINE_DEPLOYMENT.md):
#   S3:     aws s3 cp bundle.tar.gz s3://bucket/
#           ssh user@host 'aws s3 cp s3://bucket/bundle.tar.gz /tmp/'
#   Docker: docker save image | gzip | ssh user@host docker load

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  COLOR_RED='\033[0;31m'
  COLOR_GREEN='\033[0;32m'
  COLOR_YELLOW='\033[1;33m'
  COLOR_BOLD='\033[1m'
  COLOR_NC='\033[0m'
else
  COLOR_RED='' COLOR_GREEN='' COLOR_YELLOW='' COLOR_BOLD='' COLOR_NC=''
fi

log_info()  { echo -e "${COLOR_GREEN}[INFO]${COLOR_NC}  $*"; }
log_warn()  { echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC}  $*" >&2; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $*" >&2; }
log_step()  { echo -e "\n${COLOR_BOLD}==> $*${COLOR_NC}"; }
die()       { log_error "$1"; exit "${2:-1}"; }

# ── Argument parsing ──────────────────────────────────────────────────────────
REMOTE_HOST=""
BUNDLE_PATH=""
REMOTE_USERNAME=""
ASSUME_YES=false
REMOTE_DOTFILES_DIR="~/dotfiles-public"
BUNDLE_CLEANUP=false

show_help() {
  cat <<EOF
deploy-remote.sh — Deploy dotfiles to a remote restricted machine

USAGE:
    $0 <user@host> [OPTIONS]

OPTIONS:
    --bundle <path>        Use existing bundle (skip local build step)
    --user <username>      User profile for bootstrap (naroslife, enterpriseuser)
    -y, --yes              Non-interactive (auto-confirm all prompts)
    -h, --help             Show this help

EXAMPLES:
    $0 user@192.168.1.100
    $0 user@host --bundle /tmp/bundle.tar.gz
    $0 user@host --user enterpriseuser -y

PRE-REQUISITES (before first run):
    MISE_ALWAYS_KEEP_DOWNLOAD=1 mise install   # ensure mise cache is populated
    scripts/install-zsh-plugins.sh             # ensure zsh plugins are pre-cloned

TRANSFER ALTERNATIVES (when scp is unavailable):
    S3:     aws s3 cp bundle.tar.gz s3://bucket/
            ssh user@host 'aws s3 cp s3://bucket/bundle.tar.gz /tmp/'
    Docker: see docs/OFFLINE_DEPLOYMENT.md

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    --bundle)
      shift
      BUNDLE_PATH="${1:?--bundle requires a path}"
      ;;
    --user|-u)
      shift
      REMOTE_USERNAME="${1:?--user requires a value}"
      ;;
    -y|--yes)
      ASSUME_YES=true
      ;;
    *)
      if [[ -z "$REMOTE_HOST" && "$1" != -* ]]; then
        REMOTE_HOST="$1"
      else
        die "Unknown option: $1. Use --help for usage."
      fi
      ;;
  esac
  shift
done

if [[ -z "$REMOTE_HOST" ]]; then
  log_error "Remote host is required."
  show_help
  exit 1
fi

# ── Step 0: Verify SSH connection ─────────────────────────────────────────────
log_step "Verifying SSH connection to ${REMOTE_HOST}..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${REMOTE_HOST}" "echo OK" &>/dev/null; then
  die "Cannot connect to ${REMOTE_HOST}. Ensure SSH key authentication is set up."
fi
log_info "SSH connection OK"

# ── Step 1: Build or validate offline bundle ──────────────────────────────────
if [[ -n "$BUNDLE_PATH" ]]; then
  log_step "Using existing bundle: ${BUNDLE_PATH}"
  [[ -f "$BUNDLE_PATH" ]] || die "Bundle not found: $BUNDLE_PATH"
  log_info "Bundle size: $(du -sh "${BUNDLE_PATH}" | cut -f1)"
else
  log_step "Building offline bundle locally..."

  if [[ ! -x "${SCRIPT_DIR}/scripts/build-offline-bundle.sh" ]]; then
    die "scripts/build-offline-bundle.sh not found. Cannot build bundle."
  fi

  BUNDLE_PATH="${SCRIPT_DIR}/dotfiles-offline-bundle-$(date +%Y%m%d-%H%M%S).tar.gz"
  BUNDLE_CLEANUP=true
  trap 'rm -f "${BUNDLE_PATH}" 2>/dev/null || true' EXIT

  "${SCRIPT_DIR}/scripts/build-offline-bundle.sh" --output "${BUNDLE_PATH}"
  log_info "Bundle built: ${BUNDLE_PATH} ($(du -sh "${BUNDLE_PATH}" | cut -f1))"
fi

# ── Step 2: Transfer bundle to remote ─────────────────────────────────────────
REMOTE_BUNDLE_PATH="/tmp/$(basename "${BUNDLE_PATH}")"
log_step "Transferring bundle to ${REMOTE_HOST}:${REMOTE_BUNDLE_PATH}..."
log_info "Size: $(du -sh "${BUNDLE_PATH}" | cut -f1) — this may take a few minutes..."

scp "${BUNDLE_PATH}" "${REMOTE_HOST}:${REMOTE_BUNDLE_PATH}"
log_info "Bundle transferred"

# ── Step 3: Sync dotfiles repo to remote ──────────────────────────────────────
log_step "Syncing dotfiles to ${REMOTE_HOST}:${REMOTE_DOTFILES_DIR}..."
ssh "${REMOTE_HOST}" "mkdir -p ${REMOTE_DOTFILES_DIR}"

RSYNC_EXCLUDES=(
  --exclude='.git'
  --exclude='result' --exclude='result-*'
  --exclude='*.swp' --exclude='.direnv'
  --exclude='dotfiles-offline-bundle-*.tar.gz'
)

if command -v rsync &>/dev/null; then
  rsync -av "${RSYNC_EXCLUDES[@]}" \
    "${SCRIPT_DIR}/" "${REMOTE_HOST}:${REMOTE_DOTFILES_DIR}/"
else
  log_warn "rsync not found — falling back to tar over SSH"
  tar czf - \
    --exclude='.git' \
    --exclude='result' \
    --exclude='result-*' \
    --exclude='dotfiles-offline-bundle-*.tar.gz' \
    -C "${SCRIPT_DIR}" . \
    | ssh "${REMOTE_HOST}" "cd ${REMOTE_DOTFILES_DIR} && tar xzf -"
fi
log_info "Dotfiles synced"

# ── Step 4: Run bootstrap on remote ──────────────────────────────────────────
log_step "Running bootstrap on ${REMOTE_HOST}..."

BOOTSTRAP_ARGS=(--offline --archive "${REMOTE_BUNDLE_PATH}")
[[ "$ASSUME_YES" == true ]]  && BOOTSTRAP_ARGS+=(-y)
[[ -n "$REMOTE_USERNAME" ]]  && BOOTSTRAP_ARGS+=(--user "${REMOTE_USERNAME}")

# Build a properly quoted command string for the remote shell
BOOTSTRAP_CMD="cd ${REMOTE_DOTFILES_DIR} && bash bootstrap.sh"
for arg in "${BOOTSTRAP_ARGS[@]}"; do
  BOOTSTRAP_CMD+=" $(printf '%q' "$arg")"
done

# Allocate a TTY for interactive prompts unless -y was given
if [[ "$ASSUME_YES" == true ]]; then
  ssh "${REMOTE_HOST}" "${BOOTSTRAP_CMD}"
else
  ssh -t "${REMOTE_HOST}" "${BOOTSTRAP_CMD}"
fi

# ── Step 5: Clean up remote bundle ────────────────────────────────────────────
log_info "Cleaning up remote bundle..."
ssh "${REMOTE_HOST}" "rm -f ${REMOTE_BUNDLE_PATH}" || true

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${COLOR_BOLD}${COLOR_GREEN}✓ Deployment complete!${COLOR_NC}"
echo ""
echo -e "${COLOR_BOLD}Remote machine:${COLOR_NC}  ${REMOTE_HOST}"
echo -e "${COLOR_BOLD}Dotfiles at:${COLOR_NC}     ${REMOTE_DOTFILES_DIR}"
echo ""
echo -e "${COLOR_BOLD}To update later:${COLOR_NC}"
echo "  Run this script again from an unrestricted machine, or:"
echo "  - If apt is accessible: bootstrap.sh handles Tier 3 tools via apt"
echo "  - Rebuild bundle:  scripts/build-offline-bundle.sh"
echo "  - See:             docs/OFFLINE_DEPLOYMENT.md"
