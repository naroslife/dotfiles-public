# Mutable Package Manager Setup

This document explains how to use traditional package managers (npm, pip, cargo, etc.) alongside your immutable Nix/Home Manager baseline.

## Overview

Your Nix configuration provides an immutable, reproducible baseline environment. However, you can now install packages ad-hoc using traditional package managers without rebuilding your Nix configuration.

### Strategy

- **Immutable Base**: Package managers (npm, pip, cargo, ruby, go) are installed via Nix
- **Mutable Layer**: User-level package installations in `~/.local`, `~/.npm-global`, `~/.cargo`, `~/.gem`
- **Easy Reset**: Delete user directories and re-run `./apply.sh` to return to baseline

## Configuration Files

### NPM Configuration
- **Location**: `~/.npmrc`
- **Settings**: 
  - Prefix set to `~/.npm-global`
  - Auto-updates disabled

### Python pip Configuration
- **Location**: `~/.config/pip/pip.conf`
- **Settings**:
  - User-level installation enabled
  - Column format for package listing

### Environment Variables
All configured in `modules/environment.nix`:
- `NPM_CONFIG_PREFIX=~/.npm-global`
- `PIP_USER=1`
- `PYTHONUSERBASE=~/.local`
- `CARGO_HOME=~/.cargo`
- `GEM_HOME=~/.gem`
- `GEM_PATH=~/.gem`

## Usage Examples

### NPM (Node.js)
```bash
# Install packages globally (goes to ~/.npm-global)
npm install -g typescript
npm install -g @angular/cli
npm install -g prettier

# List global packages
npm list -g --depth=0

# Clean npm packages (helper function)
npm-clean
```

### Python pip
```bash
# Install packages (goes to ~/.local)
pip install requests
pip install pandas numpy
pip install jupyter

# List installed packages
pip list --user

# Create virtual environment
venv  # Helper function: creates .venv and activates

# Clean pip packages (helper function)
pip-clean
```

### Rust Cargo
```bash
# Install packages (goes to ~/.cargo/bin)
cargo install ripgrep
cargo install bat
cargo install fd-find

# Clean cargo packages (helper function)
cargo-clean
```

### Ruby Gems
```bash
# Install gems (goes to ~/.gem)
gem install bundler
gem install rails

# List installed gems
gem list
```

### Go
```bash
# Install packages (goes to ~/go/bin)
go install github.com/junegunn/fzf@latest

# Already in PATH via modules/environment.nix
```

## Mutable Bash Configuration

You can now create `~/.bashrc.local` for ad-hoc bash customizations:

```bash
# ~/.bashrc.local - Your mutable shell config
# This file is sourced automatically and won't be overwritten by Nix

# Custom aliases
alias myproject='cd ~/projects/myproject'

# Custom functions
myfunc() {
    echo "Hello from mutable config!"
}

# Environment variables for experiments
export MY_TEMP_VAR="testing"
```

This file is automatically sourced by bash and won't be managed by Home Manager.

## Helper Functions

Available in both Bash and Elvish:

### `npm-clean`
Removes all npm global packages and resets `~/.npm-global`.

### `pip-clean`
Removes all pip user packages and resets `~/.local/lib/python*/site-packages`.

### `cargo-clean`
Removes all cargo binaries and resets `~/.cargo/bin`.

### `venv`
Creates and activates a Python virtual environment in `.venv`.

## Reset Script

Use the reset script to return to your Nix baseline:

```bash
# Reset all package managers
./scripts/reset-package-managers.sh

# Follow the prompts
# Backups will be created with .backup.TIMESTAMP suffix

# Restore Nix baseline
./apply.sh
```

The script will:
1. Show current installed packages
2. Create timestamped backups
3. Clean installation directories
4. Prompt for confirmation on Cargo (since it may contain important tools)

### Backup Locations
- `~/.npm-global.backup.TIMESTAMP`
- `~/.local/lib.backup.TIMESTAMP`
- `~/.cargo/bin.backup.TIMESTAMP`
- `~/.gem.backup.TIMESTAMP`

## Best Practices

### 1. **Use Nix for Base Tools**
Install stable, long-term tools via Nix in `modules/dev/languages.nix`:
```nix
home.packages = with pkgs; [
  nodejs
  python3
  rustup
  # ... etc
];
```

### 2. **Use Package Managers for Experiments**
Use npm/pip/cargo for:
- Testing new packages
- Project-specific tools
- Frequently updated tools
- Tools not available in nixpkgs

### 3. **Use Virtual Environments for Projects**
For Python projects:
```bash
cd myproject
venv  # Creates and activates .venv
pip install -r requirements.txt
```

### 4. **Regular Cleanup**
Periodically run `./scripts/reset-package-managers.sh` to:
- Remove unused packages
- Free up disk space
- Return to a clean baseline

### 5. **Document Important Packages**
If you find yourself repeatedly installing the same packages, consider:
- Adding them to your Nix configuration
- Creating a project-specific `shell.nix`
- Using `direnv` with `.envrc`

## Integration with direnv

For project-specific environments, use `direnv`:

```bash
# .envrc
use nix
# or for Python:
layout python3
```

Then `direnv` will automatically load the environment when you `cd` into the directory.

## Troubleshooting

### PATH Issues
If commands aren't found, verify your PATH includes:
```bash
echo $PATH | tr ':' '\n' | grep -E 'npm-global|local/bin|cargo|gem'
```

Should show:
- `~/.npm-global/bin`
- `~/.local/bin`
- `~/.cargo/bin`
- `~/.gem/bin`

### Permission Issues
All installations are user-level, so you should never need `sudo`.

### Conflicts with Nix Packages
If a package manager installs a binary that conflicts with a Nix package:
- The Nix version takes precedence (comes first in PATH)
- Use `which <command>` to see which version is being used
- Use the full path to override: `~/.npm-global/bin/command`

### Python Virtual Environment Activation
For Elvish, use:
```elvish
use .venv/bin/activate.elv
```

For Bash/Zsh:
```bash
source .venv/bin/activate
```

## Migration from Existing Setup

If you have existing package manager installations:

1. **Backup current installations** (the reset script does this automatically)
2. **Run reset script**: `./scripts/reset-package-managers.sh`
3. **Apply Nix config**: `./apply.sh`
4. **Reinstall needed packages** using the package managers

Your Nix baseline will be restored, and you can selectively reinstall packages as needed.

## Summary

You now have the best of both worlds:
- ✅ Reproducible baseline via Nix/Home Manager
- ✅ Flexibility to install packages ad-hoc
- ✅ Easy reset to baseline
- ✅ No constant rebuilding required
- ✅ Version control for your base environment
- ✅ Freedom to experiment without breaking your system
