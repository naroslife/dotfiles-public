#!/usr/bin/env bash
# Tmux Session Manager
# Enhanced session save/restore management for tmux-resurrect and tmux-continuum

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly RESURRECT_DIR="${HOME}/.tmux/resurrect"
readonly RESURRECT_SAVE_SCRIPT="${HOME}/.tmux/plugins/tmux-resurrect/scripts/save.sh"
readonly RESURRECT_RESTORE_SCRIPT="${HOME}/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
readonly MAX_SAVES_TO_KEEP=5

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    if ! command -v tmux &> /dev/null; then
        log_error "tmux is not installed"
        exit 1
    fi

    if [[ ! -d "${HOME}/.tmux/plugins/tmux-resurrect" ]]; then
        log_error "tmux-resurrect plugin is not installed"
        log_info "Install it by adding 'resurrect' to your tmux plugins"
        exit 1
    fi
}

cmd_save() {
    log_info "Saving current tmux session..."

    if [[ ! -x "${RESURRECT_SAVE_SCRIPT}" ]]; then
        log_error "Save script not found or not executable: ${RESURRECT_SAVE_SCRIPT}"
        exit 1
    fi

    if "${RESURRECT_SAVE_SCRIPT}"; then
        log_success "Session saved successfully"
        log_info "Save location: ${RESURRECT_DIR}/"
    else
        log_error "Failed to save session"
        exit 1
    fi
}

cmd_restore() {
    log_info "Restoring last saved tmux session..."

    if [[ ! -x "${RESURRECT_RESTORE_SCRIPT}" ]]; then
        log_error "Restore script not found or not executable: ${RESURRECT_RESTORE_SCRIPT}"
        exit 1
    fi

    if [[ ! -d "${RESURRECT_DIR}" ]] || [[ -z "$(ls -A "${RESURRECT_DIR}" 2>/dev/null)" ]]; then
        log_error "No saved sessions found in ${RESURRECT_DIR}"
        exit 1
    fi

    if "${RESURRECT_RESTORE_SCRIPT}"; then
        log_success "Session restored successfully"
    else
        log_error "Failed to restore session"
        exit 1
    fi
}

cmd_list() {
    log_info "Available saved sessions:"

    if [[ ! -d "${RESURRECT_DIR}" ]]; then
        log_warning "No resurrect directory found: ${RESURRECT_DIR}"
        exit 0
    fi

    local save_files
    save_files=$(find "${RESURRECT_DIR}" -name "tmux_resurrect_*.txt" -type f 2>/dev/null | sort -r)

    if [[ -z "${save_files}" ]]; then
        log_warning "No saved sessions found"
        exit 0
    fi

    local count=0
    local last_file
    last_file=$(readlink -f "${RESURRECT_DIR}/last" 2>/dev/null || echo "")

    echo ""
    while IFS= read -r file; do
        count=$((count + 1))
        local timestamp
        timestamp=$(basename "${file}" | sed 's/tmux_resurrect_\(.*\)\.txt/\1/')
        local size
        size=$(du -h "${file}" | cut -f1)
        local is_current=""

        if [[ "${file}" == "${last_file}" ]]; then
            is_current=" ${GREEN}(current)${NC}"
        fi

        echo -e "  ${count}. ${timestamp} - ${size}${is_current}"
    done <<< "${save_files}"

    echo ""
    log_info "Total saves: ${count}"

    if [[ -n "${last_file}" ]]; then
        log_info "Current restore point: $(basename "${last_file}")"
    fi
}

cmd_clean() {
    log_info "Cleaning old session saves (keeping last ${MAX_SAVES_TO_KEEP})..."

    if [[ ! -d "${RESURRECT_DIR}" ]]; then
        log_warning "No resurrect directory found: ${RESURRECT_DIR}"
        exit 0
    fi

    local save_files
    save_files=$(find "${RESURRECT_DIR}" -name "tmux_resurrect_*.txt" -type f 2>/dev/null | sort -r)

    if [[ -z "${save_files}" ]]; then
        log_warning "No saved sessions found"
        exit 0
    fi

    local count=0
    local deleted=0

    while IFS= read -r file; do
        count=$((count + 1))
        if [[ ${count} -gt ${MAX_SAVES_TO_KEEP} ]]; then
            log_info "Deleting old save: $(basename "${file}")"
            rm -f "${file}"
            deleted=$((deleted + 1))
        fi
    done <<< "${save_files}"

    if [[ ${deleted} -gt 0 ]]; then
        log_success "Deleted ${deleted} old save(s)"
    else
        log_info "No old saves to delete (${count} total saves)"
    fi
}

show_usage() {
    cat <<EOF
Tmux Session Manager - Enhanced session save/restore management

Usage: $(basename "$0") <command>

Commands:
    save     - Manually save current tmux session
    restore  - Manually restore last saved session
    list     - List all available saved sessions
    clean    - Clean old session saves (keep last ${MAX_SAVES_TO_KEEP})
    help     - Show this help message

Examples:
    $(basename "$0") save         # Save current session
    $(basename "$0") restore      # Restore last session
    $(basename "$0") list         # List all saves
    $(basename "$0") clean        # Clean old saves

Automatic Features:
    - Sessions auto-save every 5 minutes (via tmux-continuum)
    - Sessions auto-restore on tmux start
    - Use Ctrl-b Ctrl-s for quick manual save
    - Use Ctrl-b Ctrl-r for quick manual restore

Configuration:
    Resurrect directory: ${RESURRECT_DIR}
    Max saves to keep: ${MAX_SAVES_TO_KEEP}

EOF
}

main() {
    check_dependencies

    local command="${1:-help}"

    case "${command}" in
        save)
            cmd_save
            ;;
        restore)
            cmd_restore
            ;;
        list)
            cmd_list
            ;;
        clean)
            cmd_clean
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: ${command}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
