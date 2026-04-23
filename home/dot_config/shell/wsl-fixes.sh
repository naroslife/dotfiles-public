#!/usr/bin/env bash
# ~/.config/shell/wsl-fixes.sh — WSL session startup fixes
# Managed by chezmoi — edit source at home/dot_config/shell/wsl-fixes.sh
# Sourced by .zshrc and .bashrc when is_wsl is true

# umask for Windows filesystem compatibility
umask 022

# Windows PATH integration
[[ -d "/mnt/c/Windows/System32" ]] && export PATH="${PATH}:/mnt/c/Windows/System32"

# ── DBus session setup ────────────────────────────────────────────────────────
# Source the fix-dbus-wsl script to ensure a valid DBus session
if [[ -x "${HOME}/.local/bin/fix-dbus-wsl" ]]; then
  source "${HOME}/.local/bin/fix-dbus-wsl" 2>/dev/null || true
fi

# ── WSLg systemd conflict fix (once per session) ──────────────────────────────
_WSLG_FIX_MARKER="${HOME}/.cache/.wslg-systemd-fixed"
if [[ ! -f "${_WSLG_FIX_MARKER}" ]] && [[ -x "${HOME}/.local/bin/fix-wslg-systemd" ]]; then
  mkdir -p "${HOME}/.cache"
  "${HOME}/.local/bin/fix-wslg-systemd" 2>/dev/null || true
  touch "${_WSLG_FIX_MARKER}"
fi
unset _WSLG_FIX_MARKER

# ── Daily WSL reminders (once per day) ───────────────────────────────────────
_WSL_MESSAGES_FILE="${HOME}/.cache/wsl-messages-last-shown"
_TODAY="$(date +%Y-%m-%d)"
mkdir -p "${HOME}/.cache"

if [[ ! -f "${_WSL_MESSAGES_FILE}" ]] || [[ "$(cat "${_WSL_MESSAGES_FILE}" 2>/dev/null)" != "${_TODAY}" ]]; then
  echo "${_TODAY}" > "${_WSL_MESSAGES_FILE}"

  # Daily APT network configuration check (background, non-blocking)
  if command -v apt-network-switch &>/dev/null; then
    ( apt-network-switch --quiet &>/dev/null ) &
  fi

  # WSL utilities reminder
  echo "WSL Tool Reminders:"
  echo "  wslview <file>     - Open file in Windows default app"
  echo "  wslpath <path>     - Convert between Windows and WSL paths"
  echo "  wslvar <var>       - Access Windows environment variables"
  echo "  pbcopy / pbpaste   - Windows clipboard integration"
fi
unset _WSL_MESSAGES_FILE _TODAY
