#!/usr/bin/env bash
# scripts/kill-switch.sh
# Revert all modern CLI aliases to system defaults
#
# Usage:
#   source ./scripts/kill-switch.sh        # current shell session
#   echo 'export DOTFILES_NO_ALIASES=1' >> ~/.zshrc.local  # persistent
#
# The alias overrides in dot_zshrc.tmpl check for DOTFILES_NO_ALIASES:
#   if [[ -z "${DOTFILES_NO_ALIASES:-}" ]]; then ... aliases ... fi
#
# To re-enable: unset DOTFILES_NO_ALIASES && source ~/.zshrc

export DOTFILES_NO_ALIASES=1

# Explicitly unalias all modern replacements in current session
_aliases=(
  cat find grep ls df du ps top htop ping dig http
  bat fd ripgrep eza duf dust procs bottom gping dog xh
)

for _alias in "${_aliases[@]}"; do
  unalias "${_alias}" 2>/dev/null || true
done
unset _alias _aliases

echo "Kill switch activated: all dotfiles aliases removed for this session."
echo "Standard system tools are now active."
echo ""
echo "To make permanent: echo 'export DOTFILES_NO_ALIASES=1' >> ~/.zshrc.local"
echo "To re-enable:      unset DOTFILES_NO_ALIASES && source ~/.zshrc"
