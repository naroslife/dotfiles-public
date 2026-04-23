#!/usr/bin/env bash
# Install Claude Code CLI via npm
# chezmoi run_once: only runs on first apply or when this file changes hash
# Requires: Node.js / npm in PATH (managed via mise)

set -euo pipefail

if command -v claude &>/dev/null; then
  echo "Claude Code already installed: $(claude --version 2>/dev/null || echo 'version unknown')"
  exit 0
fi

if ! command -v npm &>/dev/null; then
  echo "npm not found. Install Node.js via mise: mise use node@lts"
  exit 1
fi

echo "Installing Claude Code via npm..."
npm install -g @anthropic-ai/claude-code

echo "Claude Code installed: $(claude --version)"
