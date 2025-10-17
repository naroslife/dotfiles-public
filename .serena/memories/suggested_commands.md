# Suggested Commands

## Initial Setup

```bash
# Clone the repository
git clone https://github.com/naroslife/dotfiles-public.git ~/dotfiles-public
cd ~/dotfiles-public

# Run interactive setup (installs Nix if needed)
./apply.sh

# Apply with specific username (flake mode)
nix run home-manager/master -- switch --impure --flake ".#enterpriseuser"
# Available usernames: naroslife, enterpriseuser
```

## Updating Configuration

```bash
# Update flake inputs
nix flake update

# Update specific input
nix flake update nixpkgs

# Update git submodules (if using)
git submodule update --init --recursive

# Apply updated configuration
./apply.sh

# Or manually
home-manager switch --flake .#$USER
```

## Testing

```bash
# Run all tests
./tests/run_tests.sh

# Run with coverage and benchmarks
./tests/run_tests.sh --coverage --benchmark

# Run with verbose output
./tests/run_tests.sh --verbose

# Check Nix syntax
nix flake check
```

## Developer Experience CLI

```bash
# Show all commands
dotfiles help

# Run health checks
dotfiles doctor

# List all aliases
dotfiles aliases

# Show command examples
dotfiles examples git       # Git workflows
dotfiles examples docker    # Docker operations
dotfiles examples nix       # Nix commands
dotfiles examples bash      # Bash scripting
dotfiles examples tmux      # Tmux usage

# Interactive tool pickers (with fzf)
dotfiles git                # Git operations menu
dotfiles docker             # Docker commands menu
dotfiles nix                # Nix operations menu
```

## Maintenance

```bash
# List home-manager generations
home-manager generations

# Remove old generations (older than 30 days)
home-manager expire-generations "-30 days"

# Garbage collect Nix store
nix-collect-garbage -d

# Check for updates
./scripts/dotfiles-update-checker.sh

# Profile shell startup time
./scripts/dotfiles-profiler.sh
```

## Troubleshooting

```bash
# Source Nix profile if command not found
. ~/.nix-profile/etc/profile.d/nix.sh

# Check flake syntax
nix flake check

# WSL: Fix APT repositories
./scripts/apt-network-switch.sh

# Verbose apply (for debugging)
./apply.sh --verbose

# Show apply script help
./apply.sh --help
```

## Utility Commands (Linux/WSL)

Standard Linux utilities are available:
- `git` - Version control
- `ls` / `eza` - List files (eza is modern alternative)
- `cd` / `z` - Change directory (zoxide learns habits)
- `grep` / `rg` - Search text (ripgrep is faster)
- `find` / `fd` - Find files (fd is user-friendly)
- `cat` / `bat` - Display files (bat has syntax highlighting)
- `ps` / `procs` - Process viewer (procs is modern)
- `top` / `btm` - System monitor (bottom is graphical)

**Note**: AI Agent Detection automatically uses POSIX tools (cat, ls, grep, find) when running in Claude Code or VSCode Agent Mode to prevent syntax errors.

## Development Workflow

```bash
# 1. Make changes to configuration files
vim modules/shells/bash.nix

# 2. Test configuration
nix flake check

# 3. Apply changes
./apply.sh

# 4. Run tests if you modified scripts
./tests/run_tests.sh

# 5. Commit changes
git add .
git commit -m "feat: describe your changes"

# 6. Push to repository
git push
```

## WSL-Specific Commands

```bash
# WSL utilities (auto-configured)
wslview <url>              # Open URL in Windows browser
wslpath -w /path           # Convert Linux path to Windows
wslvar USERNAME            # Get Windows environment variable

# Clipboard integration (aliases)
pbcopy                     # Copy to clipboard
pbpaste                    # Paste from clipboard
```
