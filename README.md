# Dotfiles

Modular dotfiles managed with [Home Manager](https://github.com/nix-community/home-manager) and [Nix Flakes](https://nixos.wiki/wiki/Flakes) for reproducible development environments.

## Features

- 🚀 **Modular Architecture** - Clean separation of concerns with focused modules
- 🔧 **Modern CLI Tools** - Replaces traditional tools with faster, more intuitive alternatives (AI-aware!)
- 🤖 **AI Agent Detection** - Automatically uses POSIX tools for Claude Code/VSCode Agent Mode
- 🐚 **Multi-Shell Support** - Elvish (primary), Zsh, and Bash with shared configurations
- 💻 **Development Ready** - Complete toolchains for multiple languages and frameworks
- 🪟 **WSL Optimized** - Automatic detection and optimization for Windows Subsystem for Linux
- 📦 **Reproducible** - Nix ensures identical environments across machines
- 🎯 **Developer Experience** - Comprehensive DX improvements (CLI, diagnostics, examples, pickers)
- 📚 **Command Examples** - 2,000+ lines of curated examples for git, docker, nix, bash, tmux
- 🔍 **Health Monitoring** - Built-in diagnostics and performance profiling
- 🤖 **Claude Code Integration** - Version-controlled configuration, automated plugin setup

## Quick Start

### Prerequisites

- Linux or WSL2
- Git
- Internet connection

### Installation

```bash
# Clone the repository
git clone https://github.com/naroslife/dotfiles-public.git ~/dotfiles-public
cd ~/dotfiles-public

# Run the setup script (installs Nix if needed)
./apply.sh
```

The setup script will:
1. Install Nix with flakes support (if not already installed)
2. Detect your username and apply the appropriate configuration
3. Set up all shells, tools, and configurations
4. Configure locale (using C.UTF-8 for WSL compatibility)
5. Enable AI agent detection for Claude Code/VSCode compatibility
6. Install diagnostic tools and command examples database

### Manual Installation

If you prefer manual control:

```bash
# Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Enable flakes
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Apply configuration
nix run home-manager/master -- switch --impure --flake .#$USER
```

## Project Structure

```
dotfiles-public/
├── flake.nix           # Nix flake definition with user configurations
├── home.nix           # Main home-manager entry point (minimal)
├── apply.sh           # Interactive setup script
│
├── modules/           # Modular Nix configurations
│   ├── default.nix   # Module aggregator
│   ├── core.nix      # Essential packages and utilities
│   ├── environment.nix # Environment variables and locale
│   ├── wsl.nix       # WSL-specific configuration
│   ├── shells/       # Shell configurations (bash, zsh, aliases)
│   │   ├── default.nix  # Starship, Atuin, shared tools
│   │   ├── bash.nix
│   │   ├── zsh.nix
│   │   └── aliases.nix
│   ├── dev/          # Development tools
│   │   ├── default.nix    # Tmux, Neovim, editors
│   │   ├── git.nix        # Git with delta and hooks
│   │   ├── ssh.nix        # SSH with security hardening
│   │   ├── vscode.nix     # VS Code with extensions
│   │   ├── languages.nix  # Programming languages
│   │   └── containers.nix # Docker, Kubernetes
│   └── cli/          # CLI tools
│       ├── default.nix
│       ├── modern.nix      # Modern replacements (eza, bat, fd, rg)
│       └── productivity.nix # Productivity tools (fzf, ranger, jq)
│
├── scripts/          # Shell scripts
│   └── apt-network-switch.sh  # WSL network detection
│
├── wsl-init.sh      # WSL initialization (sources once per shell)
│
├── tmux/            # Tmux configuration
│   └── scripts/     # Tmux helper scripts
│
└── elvish/          # Elvish shell configuration
    ├── rc.elv
    ├── lib/
    └── aliases/

```

## Included Tools

### Shell Environment

- **Primary Shell**: [Elvish](https://elv.sh/) - Friendly interactive shell with structured data
- **Secondary Shells**: Zsh with syntax highlighting, Bash with smart completions
- **Prompt**: [Starship](https://starship.rs/) - Fast, customizable, minimal prompt
- **History**: [Atuin](https://github.com/ellie/atuin) - Sync, search, and backup shell history
- **Completions**: [Carapace](https://github.com/rsteube/carapace) - Multi-shell completion framework

### Modern CLI Replacements

| Traditional | Modern Alternative | Description |
|------------|-------------------|-------------|
| `ls` | [eza](https://github.com/eza-community/eza) | Better listing with git integration |
| `cat` | [bat](https://github.com/sharkdp/bat) | Syntax highlighting and git integration |
| `find` | [fd](https://github.com/sharkdp/fd) | User-friendly and fast file finder |
| `grep` | [ripgrep](https://github.com/BurntSushi/ripgrep) | Blazingly fast recursive search |
| `sed` | [sd](https://github.com/chmln/sd) | Intuitive find and replace |
| `du` | [dust](https://github.com/bootandy/dust) | Intuitive disk usage visualizer |
| `df` | [duf](https://github.com/muesli/duf) | Better disk usage display |
| `ps` | [procs](https://github.com/dalance/procs) | Modern process viewer |
| `top` | [bottom](https://github.com/ClementTsang/bottom) | Graphical process monitor |
| `cd` | [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter cd that learns your habits |

### Development Tools

#### Version Control
- Git with [delta](https://github.com/dandavison/delta) diff viewer
- [lazygit](https://github.com/jesseduffield/lazygit) - Terminal UI for git
- [gh](https://cli.github.com/) - GitHub CLI

#### Languages & Frameworks
- **Java**: JDK 17, Maven, Gradle
- **C/C++**: GCC, CMake, Ninja, Meson
- **Python**: Python 3.12 with pip
- **Ruby**: Ruby 3.3 with bundler
- **Go**: Latest Go compiler
- **Rust**: Cargo and rustc
- **Node.js**: Node 20 with npm, yarn, pnpm

#### Container & Cloud
- Docker & docker-compose
- [lazydocker](https://github.com/jesseduffield/lazydocker) - Docker terminal UI
- kubectl & [k9s](https://k9scli.io/) - Kubernetes management
- Helm - Kubernetes package manager

### Text Editors
- [Neovim](https://neovim.io/) - Hyperextensible Vim-based editor
- [Helix](https://helix-editor.com/) - Post-modern modal editor

### Productivity Tools
- [fzf](https://github.com/junegunn/fzf) - Fuzzy finder
- [ranger](https://github.com/ranger/ranger) - Terminal file manager
- [broot](https://dystroy.org/broot/) - Interactive tree explorer
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [jq](https://stedolan.github.io/jq/) - JSON processor
- [yq](https://github.com/mikefarah/yq) - YAML processor

## Configuration

### Claude Code Setup

Claude Code configuration is version-controlled in `.claude/`:

```bash
# Automatic setup (recommended)
./apply.sh  # Symlinks config and prompts for plugin installation

# Manual plugin installation
~/.claude/setup-plugins.sh  # Installs 24 recommended plugins
```

**Included**:
- **CLAUDE.md**: Global instructions (plugin marketplace, orchestration)
- **settings.json**: Permissions, statusline (ccline), environment
- **ccline/**: Statusline configuration with 9 themes
- **setup-plugins.sh**: Automated plugin installer

See [.claude/README.md](.claude/README.md) for complete documentation.

### User Management

Users are defined in `flake.nix`:

```nix
users = {
  username = {
    email = "user@example.com";
    fullName = "Full Name";
  };
};
```

### Adding New Modules

Create a new module in `modules/` and import it in `modules/default.nix`:

```nix
# modules/my-module.nix
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # your packages
  ];
}
```

### WSL Integration

The configuration automatically detects WSL and:
- Configures clipboard integration (pbcopy/pbpaste)
- Sets up APT repository switching for corporate networks
- Optimizes performance settings
- Provides Windows interop commands
- Shows helpful reminders once per day (not on every shell)

**Important:** WSL requires proper `/etc/wsl.conf` configuration for full functionality. See [WSL Setup Guide](docs/WSL_SETUP.md) for complete instructions.

**Quick Setup:**

Create or edit `/etc/wsl.conf`:

```ini
[boot]
systemd = true

[interop]
enabled = true
appendWindowsPath = true

[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = false
```

Then restart WSL: `wsl --shutdown` (from Windows PowerShell)

For troubleshooting and advanced configuration, see [docs/WSL_SETUP.md](docs/WSL_SETUP.md).

## Maintenance

### Update Dependencies

```bash
# Update all flake inputs
nix flake update

# Update specific input
nix flake update nixpkgs
```

### Apply Changes

After modifying configuration files:

```bash
./apply.sh
# or
home-manager switch --flake .#$USER
```

### Clean Old Generations

```bash
# List generations
home-manager generations

# Remove old generations
home-manager expire-generations "-30 days"
```

## Troubleshooting

### Common Issues

1. **Nix command not found**
   - Restart your shell or source the Nix profile:
   ```bash
   . ~/.nix-profile/etc/profile.d/nix.sh
   ```

2. **Flake evaluation errors**
   - Check syntax: `nix flake check`
   - Ensure all imports exist and are valid

3. **Locale warnings**
   - The config uses `C.UTF-8` which is available on all systems
   - If you need `en_US.UTF-8`, install locale package and update `modules/environment.nix`

4. **WSL-specific issues**
   - Ensure `/etc/wsl.conf` is properly configured (see [WSL Setup Guide](docs/WSL_SETUP.md))
   - Run `dotfiles doctor` to check WSL configuration
   - Run `./scripts/apt-network-switch.sh` to fix APT repositories
   - Ensure WSL2 is being used (not WSL1)
   - Restart WSL after config changes: `wsl --shutdown` (from Windows)

5. **Permission denied**
   - Home Manager doesn't require sudo
   - Ensure you own your home directory

## Contributing

Feel free to fork and customize for your own use! Key principles:
- Keep modules focused and under 200 lines
- Extract complex scripts to `scripts/` directory
- Document any new modules or significant changes
- Test changes with `nix flake check` before committing

## License

MIT - See [LICENSE](LICENSE) file for details

## Acknowledgments

- [Nix](https://nixos.org/) and [Home Manager](https://github.com/nix-community/home-manager) communities
- Authors of all the amazing CLI tools included
- [NUR](https://github.com/nix-community/NUR) - Nix User Repository
## 🎯 Developer Experience Features

This dotfiles includes comprehensive DX improvements to enhance productivity:

### Central CLI Interface

```bash
dotfiles help              # Show all commands
dotfiles doctor            # Run health checks
dotfiles aliases           # List all aliases
dotfiles examples git      # Show git examples
dotfiles git               # Interactive git menu
```

### AI Agent Detection

Automatically detects when running in AI agent contexts (Claude Code, VSCode Agent Mode) and uses POSIX-compliant tools to prevent syntax errors:

```bash
# Automatically handled - no action needed!
# Modern tools (bat, eza, rg, fd) for humans
# POSIX tools (cat, ls, grep, find) for AI agents
```

See [AI_AGENT_MODE.md](docs/AI_AGENT_MODE.md) for details.

### Command Examples Database

2,000+ lines of curated examples:

```bash
dotfiles examples git      # Git workflows
dotfiles examples docker   # Docker operations
dotfiles examples nix      # Nix commands
dotfiles examples bash     # Bash scripting
dotfiles examples tmux     # Tmux usage
```

### Interactive Tool Pickers

Discover commands with fzf:

```bash
dotfiles git               # Git operations menu
dotfiles docker            # Docker commands menu
dotfiles nix               # Nix operations menu
```

### Diagnostic Tools

Monitor environment health and performance:

```bash
dotfiles doctor            # Comprehensive health check
./scripts/dotfiles-profiler.sh      # Shell startup profiling
./scripts/dotfiles-update-checker.sh # Check for updates
```

### Documentation

- [Quick Start](docs/QUICKSTART.md) - Get started in minutes
- [DX Features](docs/DX_FEATURES.md) - All developer experience features
- [AI Agent Mode](docs/AI_AGENT_MODE.md) - AI detection system
- [Architecture](ARCHITECTURE.md) - System design
- [Performance](docs/PERFORMANCE.md) - Optimization guide

