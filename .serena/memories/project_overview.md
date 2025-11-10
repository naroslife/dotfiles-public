# Project Overview

## Purpose
A personal dotfiles-public repository managed with Nix Home Manager, providing reproducible development environments across multiple machines. Supports both flake-based (recommended) and regular Home Manager installations.

## Tech Stack

### Core Technologies
- **Nix**: Declarative package management and configuration
- **Home Manager**: User environment management
- **Nix Flakes**: Modern dependency management

### Shells
- **Primary**: Elvish - Friendly interactive shell with structured data
- **Secondary**: Zsh (with syntax highlighting), Bash (with smart completions)
- **Prompt**: Starship - Fast, customizable prompt
- **History**: Atuin - Cross-shell history synchronization
- **Completions**: Carapace - Multi-shell completion framework

### Programming Languages & Tools
- **Bash**: Primary scripting language for automation
- **Python**: 3.12.5 (via asdf) - utility scripts
- **Nix**: Configuration language
- **Elvish**: Shell configuration language
- **Java**: OpenJDK 11 (via asdf)
- **Ruby**: 3.3.4 (via asdf)
- **CMake**: 3.27.0 (via asdf)

### Development Tools
- **Version Control**: Git with delta diff viewer, lazygit, gh CLI
- **Containers**: Docker, docker-compose, lazydocker, kubectl, k9s, Helm
- **Editors**: Neovim, Helix, VS Code (with extensions)
- **Modern CLI**: bat, eza, fd, ripgrep, sd, dust, duf, procs, bottom, zoxide
- **Productivity**: fzf, ranger, broot, tmux, jq, yq

## Project Structure

```
dotfiles-public/
├── flake.nix              # Nix flake with user configurations
├── home.nix               # Main Home Manager entry point
├── apply.sh               # Interactive setup script
├── lib/                   # Shared utility libraries
│   └── common.sh          # Logging, platform detection, error handling
├── modules/               # Modular Nix configurations
│   ├── core.nix           # Essential packages
│   ├── environment.nix    # Environment variables, locale
│   ├── wsl.nix            # WSL-specific config
│   ├── shells/            # Shell configs (bash, zsh, elvish, aliases)
│   ├── dev/               # Development tools (git, ssh, vscode, languages, containers)
│   └── cli/               # CLI tools (modern replacements, productivity)
├── scripts/               # Utility scripts
│   ├── dotfiles           # Central CLI interface
│   ├── dotfiles-doctor.sh # Health checks
│   ├── dotfiles-examples.sh # Command examples database
│   └── functions/         # Helper functions
├── tests/                 # Test suite
│   ├── test_common.sh     # Library tests
│   ├── test_apply.sh      # Apply script tests
│   └── run_tests.sh       # Test runner
├── tmux/                  # Tmux configuration
├── elvish/                # Elvish shell config
├── wsl-init.sh            # WSL initialization
└── docs/                  # Documentation

```

## Key Features

- **Modular Architecture**: Clean separation with focused modules (<200 lines each)
- **Multi-User Support**: Dynamic configuration generation per user in flake.nix
- **Modern CLI Tools**: Faster alternatives with AI-aware detection
- **AI Agent Detection**: Auto-switches to POSIX tools for Claude Code/VSCode Agent Mode
- **WSL Optimized**: Auto-detection and optimization for Windows Subsystem for Linux
- **Reproducible**: Nix ensures identical environments across machines
- **Developer Experience**: Comprehensive DX (CLI, diagnostics, examples, pickers)
- **Command Examples Database**: 2,000+ lines of curated examples
- **Health Monitoring**: Built-in diagnostics and performance profiling

## Platform Support
- Linux
- WSL2 (Windows Subsystem for Linux)
- macOS (partial support)

## Multi-User Architecture
Users are defined in the `users` list in `flake.nix`. Each user gets:
- Username and home directory
- Git configuration (user.name, user.email)
- Environment-specific settings

Configurations generated dynamically using `mkHomeConfig`.
