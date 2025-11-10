# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles-public repository managed with Nix Home Manager, providing a reproducible development environment across multiple machines. The configuration supports both flake-based (recommended) and regular Home Manager installations.

**Tech Stack**: Nix + Home Manager + Flakes | Primary Shell: Elvish | Multi-user support via dynamic configuration

## Quick Reference

### Essential Commands

```bash
# Apply configuration (interactive mode)
./apply.sh

# Apply with specific username (flake mode)
nix run home-manager/release-25.05 -- switch --impure --flake ".#enterpriseuser"
# Available usernames: naroslife, enterpriseuser

# Update and apply
nix flake update
./apply.sh

# Run tests
./tests/run_tests.sh

# Validate configuration
nix flake check
```

### Key Files

- **flake.nix**: User configurations, input dependencies
- **home.nix**: Main Home Manager entry point (delegates to modules/)
- **modules/**: Modular Nix configs (core, environment, shells, dev, cli, wsl)
- **apply.sh**: Interactive setup script
- **lib/common.sh**: Shared utilities (logging, platform detection, error handling)
- **tests/**: Test suite for shell scripts

## Architecture

**Structure**: Modular Nix configuration with domain separation (shells/, dev/, cli/)
**Multi-User**: Dynamic configuration generation per user in flake.nix
**Platform-Aware**: Auto-detects WSL and applies optimizations
**Reproducible**: Nix ensures identical environments across machines

## Memory Navigation

For detailed information, Claude should read Serena memories on-demand:

- **project_overview**: Comprehensive tech stack, structure, features
- **suggested_commands**: Full command reference (setup, update, maintenance, DX CLI)
- **code_style_conventions**: EditorConfig, Bash/Nix/Python conventions, patterns
- **task_completion_checklist**: Pre-commit checks, commit process, quality gates
- **testing_guide**: Test suite, coverage, writing tests
- **architecture_analysis**: Deep technical analysis, refactoring recommendations
- **project_patterns**: Shell/Nix patterns, naming conventions, best practices

**Reading Order**:
1. Start here (Project CLAUDE.md) for quick context
2. Check MCP Memory for user-specific preferences
3. Read relevant Serena memories based on task (don't load all upfront)

## MCP Memory Configuration

This repository includes a portable MCP Memory configuration:

- **.mcp/memory.json**: Global knowledge graph with user preferences, workflow patterns, and best practices
- **.mcp.json**: MCP server configuration (configures Memory server to use `.mcp/memory.json`)

**Key Features**:

- **Portable**: Uses `${HOME}` variable to work across different usernames (uif58593, naroslife, enterpriseuser)
- **Version-Controlled**: Memory travels with dotfiles across machines
- **Generic Identities**: Uses "User Preferences" entity instead of username-specific entities

**After Setup**: Restart Claude Code to apply the new memory configuration. The memory server will then use the version-controlled memory file instead of the default location.

See `.mcp/README.md` for detailed documentation.

## Important Notes

### Nix Flake Usage

- Requires `--impure` flag to access environment variables
- Username must match one in `flake.nix` users list
- Configuration is purely functional and reproducible

### WSL Integration

- Auto-detected by apply.sh
- Clipboard integration (pbcopy/pbpaste)
- WSL utilities (wslview, wslpath, wslvar)
- Network configuration helpers

### Development Workflow

1. Make changes to Nix modules or shell scripts
2. Validate: `nix flake check`
3. Test: `./tests/run_tests.sh` (if modified shell scripts)
4. Apply: `./apply.sh`
5. Commit with conventional commits format
6. See `task_completion_checklist` memory for full checklist

## Claude Code Integration

This repository includes version-controlled Claude Code configuration in `.claude/`:

- **CLAUDE.md**: Global instructions for Claude (plugin marketplace, orchestration rules)
- **settings.json**: Permissions, statusline (ccline), environment variables
- **ccline/**: Statusline configuration and themes
- **setup-plugins.sh**: Automated plugin installation script

**Setup**: Run `./apply.sh` to symlink Claude Code configuration to `~/.claude/`. The script will prompt to install plugins.

**Manual Plugin Setup**: Run `~/.claude/setup-plugins.sh` after applying dotfiles.

See `.claude/README.md` for complete documentation.
