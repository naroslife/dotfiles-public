#!/usr/bin/env bash
# Install VS Code extensions
# chezmoi run_onchange: re-runs when this file changes
# Requires: code CLI in PATH

set -euo pipefail

if ! command -v code &>/dev/null; then
  echo "VS Code CLI not found, skipping extension installation"
  exit 0
fi

extensions=(
  # Core
  "editorconfig.editorconfig"
  "streetsidesoftware.code-spell-checker"
  "christian-kohler.path-intellisense"
  "gruntfuggly.todo-tree"
  "usernamehw.errorlens"

  # Git
  "eamodio.gitlens"
  "donjayamanne.githistory"
  "mhutchie.git-graph"

  # Themes and icons
  "pkief.material-icon-theme"

  # Language support
  "ms-python.python"
  "ms-python.vscode-pylance"
  "ms-python.black-formatter"
  "rust-lang.rust-analyzer"
  "golang.go"
  "hashicorp.terraform"
  "redhat.vscode-yaml"
  "timonwong.shellcheck"
  "foxundermoon.shell-format"

  # Containers
  "ms-azuretools.vscode-docker"
  "ms-kubernetes-tools.vscode-kubernetes-tools"

  # Remote development
  "ms-vscode-remote.remote-ssh"
  "ms-vscode-remote.remote-containers"
  "ms-vscode.remote-explorer"

  # Formatters
  "esbenp.prettier-vscode"

  # Markdown
  "yzhang.markdown-all-in-one"
  "bierner.markdown-mermaid"

  # AI assistants
  "github.copilot"
  "github.copilot-chat"

  # Productivity
  "vscodevim.vim"
  "formulahendry.auto-rename-tag"
  "naumovs.color-highlight"
)

echo "Installing VS Code extensions..."
for ext in "${extensions[@]}"; do
  code --install-extension "$ext" --force 2>&1 | tail -1
done
echo "VS Code extension installation complete"
