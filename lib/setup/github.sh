#!/usr/bin/env bash
# GitHub CLI Setup and Authentication
# Functions for GitHub CLI installation and authentication

set -euo pipefail

# Guard against multiple sourcing
if [[ -n "${GITHUB_SETUP_LOADED:-}" ]]; then
    return 0
fi
readonly GITHUB_SETUP_LOADED=1

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../common.sh"

# GitHub CLI setup
setup_github_cli() {
    if ! $SETUP_GITHUB_CLI; then
        return 0
    fi

    log_info "Setting up GitHub CLI"

    if ! command -v gh >/dev/null 2>&1; then
        log_warn "GitHub CLI not found. Install it through your package manager."
        return 0
    fi

    if ! gh auth status >/dev/null 2>&1; then
        log_info "GitHub CLI not authenticated"
        if $ASSUME_YES || ask_yes_no "Would you like to authenticate GitHub CLI now?"; then
            if ! gh auth login; then
                log_warn "GitHub CLI authentication failed"
            else
                log_info "GitHub CLI authenticated successfully"
            fi
        fi
    else
        log_info "GitHub CLI already authenticated"
    fi
}
