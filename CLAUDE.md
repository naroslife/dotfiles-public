# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles-public repository managed with Nix Home Manager, providing a reproducible development environment across multiple machines. The configuration supports both flake-based (recommended) and regular Home Manager installations.

## Build and Setup Commands

### Initial Setup
```bash
# Apply configuration (interactive mode with prompts)
./apply.sh

# Apply configuration with specific username (flake mode)
nix run home-manager/master -- switch --impure --flake ".#enterpriseuser"

# Available usernames configured in flake.nix: naroslife, enterpriseuser
```

### Update Configuration
```bash
# Update flake inputs
nix flake update

# Update git submodules (if using)
git submodule update --init --recursive

# Apply updated configuration
./apply.sh
```

### WSL-Specific Setup
```bash
# The apply.sh script auto-detects WSL and applies optimizations
# WSL utilities are automatically configured via wsl-init.sh
```

## Architecture

### Multi-User Support
The flake configuration (`flake.nix`) supports multiple users through dynamic home configuration generation. Each user gets their own:
- Username and home directory
- Git configuration (user.name, user.email)
- Environment-specific settings

Users are defined in the `users` list in `flake.nix` and configurations are generated dynamically using `mkHomeConfig`.

### Configuration Structure
- **home.nix**: Central Home Manager configuration defining all packages, programs, and dotfile management
- **flake.nix**: Defines inputs (nixpkgs, home-manager, NUR, sops-nix) and generates per-user configurations
- **apply.sh**: Interactive setup script that handles both Nix installation and Home Manager configuration

### Key Components

#### Shell Environment
- Primary shell: **Elvish** with custom modules in `elvish/`
- Secondary shells: Zsh, Bash with shared configurations
- Prompt: Starship with custom configuration
- History: Atuin for cross-shell history synchronization
- Completions: Carapace framework for advanced completions

#### Development Tools
The configuration includes extensive development tooling:
- Modern CLI replacements (bat, eza, fd, ripgrep, zoxide)
- Container tools (Docker, kubectl, k9s, lazydocker)
- Language environments (Python 3.12, Java 11, Ruby 3.3, Go, Rust, Node.js)
- Version management via asdf (configured in `.tool-versions`)

#### Git Submodules (Optional)
- **base**: Shell framework for consistent functions across shells
- **stdlib.sh**: Bash standard library for robust scripting
- **util-linux**: Custom util-linux build

### WSL Integration
When running on WSL, additional features are activated:
- Clipboard integration (pbcopy/pbpaste aliases)
- Windows path integration
- WSL utilities (wslview, wslpath, wslvar)
- Daily APT network configuration checks (Enterprise-specific)
- Performance optimizations and proper umask settings

## Important Notes

### Nix Flake Usage
- The configuration uses `--impure` flag to allow accessing environment variables
- Username must match one defined in the `users` list in `flake.nix`
- Git configuration is embedded in the flake for each user

### Shell Integration
All shells source common configurations:
- Base shell framework (if submodules initialized)
- Stdlib.sh utilities (if submodules initialized)
- Shared aliases and functions from `home.nix`

### Configuration Deployment
The `apply.sh` script provides an interactive experience:
1. Checks for required dependencies (git, nix)
2. Installs Nix if not present
3. Prompts for git submodule usage
4. Asks for Home Manager type (flake vs regular)
5. Prompts for username (in flake mode)
6. Applies configuration and optionally configures GitHub CLI

### File Management
- Dotfiles are managed through Home Manager's `home.file` declarations
- Symlinks are created from Nix store to home directory
- Configuration files maintain their structure from the repository
