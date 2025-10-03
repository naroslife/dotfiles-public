# Test Variable Sets for Electron Slowness Investigation

This document contains the exact variable sets used in testing to help identify the root cause.

## SET 1: FAST OPENING (8 base variables)

These variables result in **2-3 second startup**:

```bash
HOME=/home/enterpriseuser
USER=enterpriseuser
DISPLAY=:0
XDG_RUNTIME_DIR=/run/user/1000
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
PATH=/usr/local/bin:/usr/bin:/bin
LIBVA_DRIVER_NAME=none
SHELL=/home/enterpriseuser/.nix-profile/bin/zsh
```

**Test command:**
```bash
cd ~/.config/Next-Client && env -i \
    HOME=/home/enterpriseuser \
    USER=enterpriseuser \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR=/run/user/1000 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
    PATH=/usr/local/bin:/usr/bin:/bin \
    LIBVA_DRIVER_NAME=none \
    SHELL=/home/enterpriseuser/.nix-profile/bin/zsh \
    ~/dev/Next-Client-1.10.0/squashfs-root/next-client
```

## SET 2: SLOW OPENING - First 20 real variables

Adding these 20 variables to the base set causes **30+ second timeout**:

```bash
ATUIN_HISTORY_ID=01999a3dd92b78819efe2e1a3ecc0160
ATUIN_SESSION=01999a3825277043bdb74f1b6fc61740
BAT_STYLE=numbers,changes,header
BAT_THEME=Monokai Extended
BROWSER=wslview
BUILDKIT_PROGRESS=plain
BUNDLE_USER_HOME=/home/enterpriseuser/.bundle
CARGO_HOME=/home/enterpriseuser/.cargo
CLAUDE=true
CLAUDECODE=1
CLAUDE_CODE_ENTRYPOINT=cli
CLAUDE_CODE_SSE_PORT=12744
COLORTERM=truecolor
COMPOSE_DOCKER_CLI_BUILD=1
COREPACK_ENABLE_AUTO_PIN=0
CUDA_HOME=/usr/local/cuda
CUDA_PATH=/usr/local/cuda
DELTA_FEATURES=+side-by-side
DOCKER_BUILDKIT=1
DOTFILES=/home/enterpriseuser/dotfiles
```

**Notable variables:**
- `CUDA_HOME`, `CUDA_PATH` - Yet these are FAST when tested alone
- `CLAUDECODE=1` - Claude Code environment
- `COLORTERM=truecolor` - Terminal colors
- Various tool configurations (Atuin, Bat, Cargo, Docker, etc.)

## SET 3: SLOW OPENING - Next 20 real variables (20-39)

These next 20 also cause slowness when combined with base:

```bash
DOTFILES_MANAGED=home-manager
DOTFILES_VERSION=2.0
EDITOR=code
ENABLE_IDE_INTEGRATION=true
EZA_COLORS=uu=33:gu=33:sn=32:sb=32:da=34:ur=33:uw=31:ux=32:ue=32:gr=33:gw=31:gx=32:tr=33:tw=31:tx=32
FZF_ALT_C_OPTS=--preview 'tree -C {} | head -200'
FZF_CTRL_R_OPTS=--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'
FZF_CTRL_T_OPTS=--preview '(bat --color=always {} || tree -C {}) 2> /dev/null | head -200'
FZF_DEFAULT_COMMAND=fd --type f --hidden --follow
FZF_DEFAULT_OPTS=--height 40% --layout=reverse --border --info=inline
GEM_HOME=/home/enterpriseuser/.gem
GIT_ASKPASS=/home/enterpriseuser/.vscode-server/bin/e3a5acfb517a443235981655413d566533107e92/extensions/git/dist/askpass.sh
GIT_EDITOR=true
GNUPGHOME=/home/enterpriseuser/.gnupg
GO111MODULE=on
GOBIN=/home/enterpriseuser/go/bin
GOPATH=/home/enterpriseuser/go
GPG_TTY=not a tty
HISTCONTROL=ignoreboth:erasedups
HISTFILESIZE=100000
```

**Notable variables:**
- `GIT_ASKPASS` - Long VSCode path
- `GIT_EDITOR=true` - Might interact with Git operations
- `FZF_*` - Multiple FZF configuration variables
- Various language environment vars (Go, Ruby/Gem, Python)

## Key Findings

### What Makes Variables "Slow"

Through testing we found:
1. **Individual variables from these sets**: ALL fast when tested alone (2-3s)
2. **All "suspect" variables combined**: Still fast (5s)
3. **These 20 variables added to base**: SLOW (30s+ timeout)

### Hypothesis

The slowness appears when Electron/Chromium encounters:
- **Many real environment variables** (>10-15)
- **Specific combinations** that trigger parsing/validation
- Possibly variables that cause **path/library resolution attempts**:
  - `CUDA_HOME` + `CUDA_PATH` together
  - `GIT_EDITOR` + `GIT_ASKPASS` together
  - Various `*_HOME` variables (`CARGO_HOME`, `GEM_HOME`, `GOPATH`, etc.)
  - Color/terminal variables (`COLORTERM`, `EZA_COLORS`, etc.)

### Why Dummy Variables Don't Cause This

150 dummy variables with format `DUMMY_N=/nix/store/path` were FAST because:
- Electron may not recognize them as "real" configuration
- No special parsing/handling triggered
- Not attempting path resolution for unknown variable names

## Statistics

- Total real environment variables: 144
- Base essential variables: 8
- Total in full environment: 152
- Fast threshold: ≤10 real variables
- Slow threshold: ≥20 real variables

## Testing Notes

All tests performed on:
- WSL2 Ubuntu 22.04
- Windows 11
- CUDA 12.6 installed
- Nix Home Manager (flake-based)
- App: Next-Client 1.10.0 (Electron-based)
- Date: 2025-09-30
