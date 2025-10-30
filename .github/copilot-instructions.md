# Copilot Instructions for Dotfiles-Public Repository

## Architecture Overview

This is a **Nix/Home Manager-based dotfiles system** that provides reproducible development environments across multiple shells and platforms. The architecture uses flakes for reproducible builds and supports both local and remote deployment.

### Core Components

- **`flake.nix`** - Main Nix flake defining inputs, overlays, and multi-user configurations
- **`home.nix`** - Complete Home Manager configuration with packages, programs, and environment setup
- **`apply.sh`** - Interactive deployment script with user prompts and environment detection
- **`deploy-remote.sh`** - Remote deployment script for air-gapped/restricted environments

## Multi-Shell Strategy

The system supports **three shells with consistent configuration**:

- **Elvish** (primary) - Uses `elvish/rc.elv` with EPM package manager and custom modules
- **Zsh** (secondary) - Configured in `home.nix` with completions and modern integrations
- **Bash** (fallback) - Extensive configuration in `home.nix` with function overrides and smart reminders

All shells share identical aliases, functions, and tool integrations defined in `home.nix`.

## Critical Development Workflows

### Deployment Commands

```bash
# Local application (interactive)
./apply.sh [--dry-run] [--help]

# Remote deployment (network-restricted environments)
./deploy-remote.sh user@remote-host

# Manual Home Manager flake application
nix run home-manager/release-25.05 -- switch --flake .#username --impure
```

### User Configuration Pattern

The flake supports multiple users defined in `flake.nix`:

```nix
users = [ "naroslife" "enterpriseuser" ]; # Add usernames here
```

Each user gets automatically configured git credentials and home directory paths.

### Git Submodule Integration

Optional submodules provide shell enhancements:

- **`stdlib.sh/`** - Bash standard library (auto-sourced in shells)
- **`base/`** - Shell framework with utilities
- **`util-linux/`** - Custom util-linux build

Enable with: `git submodule update --init --recursive`

## Environment-Specific Adaptations

### WSL Detection & Optimization

- **`wsl-init.sh`** - Automatic WSL environment detection and clipboard integration
- Windows PATH integration and performance optimizations
- WSL-specific aliases: `pbcopy`, `pbpaste`, `open` (via wslview)

### Runtime Tool Switching

History tools (Atuin/McFly) can be switched at runtime without rebuilds:

```bash
switch_history atuin|mcfly|status  # Available in all shells
use-atuin / use-mcfly             # Shell aliases
```

## Modern CLI Philosophy

The configuration promotes **modern CLI tool adoption** with:

- Smart command reminders (every 5th usage) suggesting modern alternatives
- Comprehensive aliases mapping legacy → modern tools
- Tool-specific configurations optimized for productivity

Example patterns:

- `ls` → `eza` (with icons, git integration)
- `find` → `fd` (faster, user-friendly)
- `cat` → `bat` (syntax highlighting)
- `du` → `dust` (tree view with colors)

## Configuration Management Patterns

### File Organization

- **Program configs**: `programs.*` blocks in `home.nix`
- **External configs**: `home.file.*` for symlinking from dedicated directories
- **Environment variables**: `home.sessionVariables` for shell-agnostic settings

### Package Categories

Packages are organized by purpose in `home.nix`:

- Version Control & Git Tools
- Shell & Terminal Environment
- Modern CLI Replacements
- Development toolchains (Java, C/C++, etc.)

## Security & Environment Considerations

### Nix Environment Preservation

Custom `nsudo`/`sudo-nix` functions preserve Nix PATH when using sudo:

```bash
nsudo systemctl restart service  # Maintains access to Nix-installed tools
```

### Path & Library Configuration

- **PKG_CONFIG_PATH** - Ensures Ubuntu system libraries remain accessible
- **LD_LIBRARY_PATH** - Custom library paths for development projects
- **PATH management** - Careful ordering to prioritize Nix tools while preserving system access

## Anti-Patterns to Avoid

- **Don't hardcode usernames** - Use the flake's user configuration system
- **Don't bypass the apply.sh script** - It handles environment detection and user prompts
- **Don't edit shell configs directly** - All shell configuration goes through `home.nix`
- **Don't ignore WSL detection** - Use the `is_wsl()` function for platform-specific code

## Testing & Validation

After configuration changes:

1. **Local validation**: `./apply.sh --dry-run`
2. **Build test**: `nix build .#homeConfigurations.username.activationPackage`
3. **Shell reload**: Test aliases and functions in all supported shells
4. **WSL testing**: Verify WSL-specific integrations if applicable

## Remote Deployment Architecture

### Air-Gapped/Limited Internet Deployment Strategy

The `deploy-remote.sh` script enables deploying complete Nix/Home Manager environments to machines with **no or limited internet access** through a sophisticated closure-based approach.

#### Deployment Workflow Overview

```bash
# From internet-connected machine
./deploy-remote.sh user@restricted-host

# Process:
# 1. Build locally (with internet) → 2. Copy closure → 3. Remote activation
```

#### Step-by-Step Process

**Phase 1: Local Build & Closure Computation**

```bash
# Build configuration locally with full internet access
nix build --no-link --print-out-paths .#homeConfigurations.username.activationPackage

# Compute complete dependency closure (all required store paths)
nix-store -qR /nix/store/xxx-home-manager-generation
```

**Phase 2: Nix Installation on Remote (if needed)**

- Downloads Nix installer locally first (handles restricted environments)
- Copies installer to remote via SCP
- Runs installation without internet dependency
- Uses Determinate Systems installer for reliability

**Phase 3: Store Path Transfer**
Two transfer methods (automatic fallback):

```bash
# Method 1: Direct SSH store (preferred)
nix copy --to "ssh://user@host" /nix/store/path --no-check-sigs

# Method 2: NAR archive fallback
nix-store --export $(nix-store -qR /nix/store/path) > closure.nar
scp closure.nar remote:/tmp/ && ssh remote "nix-store --import < /tmp/closure.nar"
```

**Phase 4: Repository Sync & Activation**

```bash
# Sync dotfiles-public repository (excluding .git)
rsync -av --exclude='.git' ./ user@host:~/dotfiles-public/

# Remote activation without internet
ssh user@host "nix-env --profile ~/.nix-profile --set /nix/store/activation-path"
ssh user@host "/nix/store/activation-path/activate"
```

#### Key Architectural Principles

**Complete Offline Operation**

- All dependencies pre-computed and transferred
- No network requests during remote activation
- Nix store provides hermetic environment

**Bandwidth Optimization**

- Only transfers store paths not already present
- Efficient NAR format for large closures
- Rsync for incremental repository updates

**Error Recovery**

- Automatic fallback between transfer methods
- Validates SSH connectivity before operations
- Creates update helper scripts for future deployments

#### Environment-Specific Considerations

**Corporate/Restricted Networks**

```bash
# Pre-download all dependencies locally
nix-store -qR $(nix build --no-link --print-out-paths .#homeConfigurations.username.activationPackage)

# Check closure size before transfer
nix path-info -S /nix/store/path  # Shows total MB
```

**Air-Gapped Systems**

- Complete isolation from internet during activation
- Self-contained Nix environment with all tools
- Update mechanism requires re-running from internet-connected machine

**WSL/Windows Integration**

- Handles Windows path conversions in WSL environments
- Preserves WSL-specific optimizations post-deployment
- `wsl-init.sh` automatically detects and configures WSL integration

#### Update Workflow for Restricted Environments

**Generated Update Helper**
The deployment creates `~/dotfiles-public/update-from-local.sh` on remote:

```bash
# Remote update process (run from internet-connected machine)
./deploy-remote.sh user@restricted-host
```

**Manual Update Process**

```bash
# 1. On internet machine: pull latest changes
git pull && git submodule update --remote

# 2. Build new configuration
nix build .#homeConfigurations.username.activationPackage

# 3. Deploy to restricted machine
./deploy-remote.sh user@restricted-host
```

#### Troubleshooting Common Issues

**Large Closure Sizes**

- C++ development tools can create 500MB+ closures
- Use `nix path-info -S` to identify large dependencies
- Consider selective package removal for bandwidth-constrained environments

**SSH Key Authentication**

- Deployment requires passwordless SSH access
- Use `ssh-copy-id user@host` to set up keys
- Test with `ssh -o BatchMode=yes user@host` before deployment

**Nix Daemon Issues**

- Remote installation may require `sudo` access for daemon setup
- Deployment waits 5 seconds for daemon initialization
- Check `/etc/nix/nix.conf` for flakes support after installation

This architecture enables complete development environments on restricted systems while maintaining the reproducibility guarantees of Nix/Home Manager.
