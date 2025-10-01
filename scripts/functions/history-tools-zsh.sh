#!/usr/bin/env zsh
# shellcheck shell=bash
# History tool switching functions for zsh

# Runtime history tool switcher for zsh
switch_history() {
  case "$1" in
    atuin)
      echo "🔄 Switching to Atuin (runtime)..."
      # Reset any existing history tools
      unset ATUIN_SESSION MCFLY_SESSION
      # Initialize Atuin
      if command -v atuin >/dev/null 2>&1; then
        eval "$(atuin init zsh)"
        echo "✅ Atuin is now active! Try Ctrl+R"
      else
        echo "❌ Atuin not found. Make sure it's installed."
      fi
      ;;
    mcfly)
      echo "🔄 Switching to McFly (runtime)..."
      # Reset any existing history tools
      unset ATUIN_SESSION MCFLY_SESSION
      # Initialize McFly
      if command -v mcfly >/dev/null 2>&1; then
        export MCFLY_KEY_SCHEME=vim
        export MCFLY_FUZZY=2
        eval "$(mcfly init zsh)"
        echo "✅ McFly is now active! Try Ctrl+R"
      else
        echo "❌ McFly not found. Make sure it's installed."
      fi
      ;;
    status)
      echo "📊 Current history tool status:"
      if [ -n "$ATUIN_SESSION" ]; then
        echo "  ✅ Atuin is active (session: ${ATUIN_SESSION:0:8}...)"
      elif command -v mcfly >/dev/null 2>&1 && [ -n "$MCFLY_SESSION" ]; then
        echo "  ✅ McFly is active"
      else
        echo "  ❌ No history tool is currently active"
        echo "  💡 Available tools:"
        command -v atuin >/dev/null 2>&1 && echo "    - atuin"
        command -v mcfly >/dev/null 2>&1 && echo "    - mcfly"
      fi
      ;;
    *)
      echo "Usage: switch_history {atuin|mcfly|status}"
      echo "  atuin  - Switch to Atuin history search"
      echo "  mcfly  - Switch to McFly history search"
      echo "  status - Show current active tool"
      ;;
  esac
}