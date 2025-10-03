# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `.gitignore` file to exclude backups, history, and build artifacts
- `.editorconfig` for consistent code formatting
- Flake checks for automated validation
- CHANGELOG.md to track project changes
- `docs/PERFORMANCE.md` documenting all performance optimizations
- Lazy-loading for Carapace completions (bash only, zsh uses direct loading)
- ZSH history substring search and optimized autosuggestions

### Performance
- Lazy-load Carapace completions in bash (saves ~100-200ms on shell startup)
- Reduced Starship command timeout from 2000ms to 500ms
- Disabled Atuin auto-sync for faster startup (manual sync available)
- Reduced Atuin sync frequency from 5m to 1h
- Added scan_timeout to Starship (30ms)
- Optimized function sourcing with conditional checks
- ZSH: Skip global compinit for faster startup
- ZSH: Move history to ~/.cache for better I/O performance
- ZSH: Optimized autosuggestion strategy (history-first)

### Changed
- Locale configuration changed from `en_US.UTF-8` to `C.UTF-8` for better WSL compatibility
- WSL environment detection messages now shown only once per day (instead of every shell)
- SSH configuration updated to use `matchBlocks` (fixing deprecation warnings)
- VS Code configuration updated to use profile-based settings (fixing deprecation warnings)
- ZSH configuration updated to use `initContent` (fixing deprecation warnings)
- README.md updated to reflect current project structure and removed git submodule references

### Removed
- `stdlib.sh` git submodule (was causing grep errors in shell initialization)
- Duplicate packages: `tldr` (kept `tealdeer`), `htop` (kept `htop-vim`)
- `.history/` and backup files from git tracking

## [1.0.0] - 2025-09-29

### Added
- Complete modular architecture with focused Nix modules
- Native Nix configurations for SSH, Git, VS Code, shells
- Git with delta integration and pre-commit hooks
- SSH with connection multiplexing and security hardening
- Comprehensive environment variable management
- WSL-specific optimizations and clipboard integration

### Changed
- Reduced `home.nix` from 1,292 lines to 64 lines (95% reduction)
- Migrated from static config files to native Nix modules where possible
- Consolidated duplicate configurations (Starship, Atuin, Tmux)
- Repository size reduced from ~28MB to <2MB (93% reduction)

### Fixed
- Infinite recursion errors from circular dependencies
- Shell aliases structure for bash and zsh
- Package conflicts between duplicate tools
- Git and SSH configuration syntax issues

## [0.1.0] - Initial State

### Features
- Nix Flakes-based configuration
- Home Manager integration
- Multi-user support
- WSL detection and optimization
- Modern CLI tools (eza, bat, fd, ripgrep, etc.)
- Development toolchains for multiple languages
- Elvish as primary shell with Zsh and Bash support
### Interactive Features
- Added fzf-tab plugin for ZSH with interactive, visual completion menu
- Completion menu shows previews (e.g., directory contents with `eza`)
- Colorized completion entries matching file colors
- Group switching with `,` and `.` keys
- Tmux popup support when running in tmux
