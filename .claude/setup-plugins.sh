#!/usr/bin/env bash
# Claude Code Plugin Setup Script
#
# This script installs the recommended set of Claude Code plugins for this user.
# These plugins are part of the claude-code-workflows marketplace.
#
# Usage:
#   ./setup-plugins.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if claude is available
if ! command -v claude &> /dev/null; then
  echo "Error: 'claude' command not found. Please install Claude Code first."
  echo "Visit: https://docs.claude.com/en/docs/claude-code/installation"
  exit 1
fi

echo "🔌 Setting up Claude Code plugins..."
echo ""

# List of plugins to install
# Format: plugin-name@marketplace
plugins=(
  # Development
  "code-documentation@claude-code-workflows"
  "debugging-toolkit@claude-code-workflows"
  "backend-development@claude-code-workflows"

  # Workflows
  "git-pr-workflows@claude-code-workflows"
  "full-stack-orchestration@claude-code-workflows"
  "tdd-workflows@claude-code-workflows"

  # Testing
  "unit-testing@claude-code-workflows"

  # Quality
  "code-review-ai@claude-code-workflows"
  "comprehensive-review@claude-code-workflows"
  "performance-testing-review@claude-code-workflows"

  # Utilities
  "code-refactoring@claude-code-workflows"
  "dependency-management@claude-code-workflows"
  "error-debugging@claude-code-workflows"
  "error-diagnostics@claude-code-workflows"

  # AI & Context
  "agent-orchestration@claude-code-workflows"
  "context-management@claude-code-workflows"

  # Operations
  "observability-monitoring@claude-code-workflows"
  "application-performance@claude-code-workflows"

  # Modernization
  "framework-migration@claude-code-workflows"
  "codebase-cleanup@claude-code-workflows"

  # Documentation
  "documentation-generation@claude-code-workflows"

  # Multi-platform
  "multi-platform-apps@claude-code-workflows"

  # Languages
  "python-development@claude-code-workflows"
  "systems-programming@claude-code-workflows"
)

# Track installation results
installed=0
skipped=0
failed=0

# Install each plugin
for plugin in "${plugins[@]}"; do
  plugin_name="${plugin%%@*}"
  echo "Installing $plugin_name..."

  if claude plugin install "$plugin" --yes 2>&1 | grep -q "already installed"; then
    echo "  ⏭️  Already installed, skipping"
    ((skipped++))
  elif claude plugin install "$plugin" --yes; then
    echo "  ✅ Installed successfully"
    ((installed++))
  else
    echo "  ❌ Failed to install"
    ((failed++))
  fi
  echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Installation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Installed: $installed"
echo "  ⏭️  Skipped:   $skipped"
echo "  ❌ Failed:    $failed"
echo "  📦 Total:     ${#plugins[@]}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "⚠️  Some plugins failed to install. Check the output above for details."
  exit 1
fi

echo ""
echo "✨ Plugin setup complete! You can now use all installed plugins."
echo ""
echo "📚 To see available plugins: claude plugin list"
echo "💡 To see plugin commands: Use tab completion or check CLAUDE.md"
