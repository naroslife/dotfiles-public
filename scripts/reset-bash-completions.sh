#!/usr/bin/env bash
#
# reset-bash-completions.sh - Reset bash completion system
#
# This script clears all bash completion state and reloads from scratch.
# Useful when completions are causing errors or behaving unexpectedly.

set -euo pipefail

echo "=== Bash Completion Reset ==="
echo ""

# 1. Clear all completion specifications
echo "Clearing all completion specifications..."
complete -r
echo "✓ Completions cleared"

# 2. Unset completion-related variables
echo "Unsetting completion variables..."
unset BASH_COMPLETION_COMPAT_DIR 2>/dev/null || true
unset BASH_COMPLETION_USER_DIR 2>/dev/null || true
unset BASH_COMPLETION_USER_FILE 2>/dev/null || true
unset COMP_WORDBREAKS 2>/dev/null || true
echo "✓ Variables unset"

# 3. Remove old lazy-load function if it exists
echo "Removing old completion functions..."
if declare -f _lazy_load_carapace >/dev/null 2>&1; then
  unset -f _lazy_load_carapace
  echo "✓ Removed _lazy_load_carapace"
else
  echo "  (no _lazy_load_carapace function found)"
fi

# 4. Check for cached completion files
echo "Checking for cached completion files..."
if [ -d ~/.bash_completion.d ]; then
  echo "  Found ~/.bash_completion.d/"
  rm -rf ~/.bash_completion.d
  echo "✓ Removed completion cache"
else
  echo "  (no cache directory found)"
fi

# 5. Reload bashrc
echo "Reloading bashrc..."
source ~/.bashrc
echo "✓ Bashrc reloaded"

echo ""
echo "=== Completion Status ==="

# Show what's now loaded
if complete -p | grep -q carapace; then
  echo "✓ Carapace completions loaded"
  complete -p | grep carapace | head -3
else
  echo "⚠ Carapace completions NOT loaded"
fi

# Check for the old function
if declare -f _lazy_load_carapace >/dev/null 2>&1; then
  echo "⚠ Old _lazy_load_carapace still present"
else
  echo "✓ No old lazy-load function"
fi

echo ""
echo "=== Reset Complete ==="
echo "Try testing completion: git <TAB>"
