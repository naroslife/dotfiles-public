# Offline Deployment Guide

Deploy dotfiles to AWS EC2 instances, VPN-restricted machines, or any host with limited internet access.

## Overview

The offline deployment uses a tiered strategy:

| Tier | Tools | Install Method |
|------|-------|----------------|
| **1/2** | bat, eza, fd, starship, atuin, lazygit, etc. | `mise` from pre-built cache |
| **3** | GDB, GCC, CMake, Valgrind, Clang tools, JDK, Go, Node, Rust | `apt` on target (accessible per requirements) |
| **4** | Docker, nmap, wireshark | `apt` on target |

## Quick Start

### On an unrestricted machine (one-time setup)

```bash
# 1. Ensure mise downloads are cached
MISE_ALWAYS_KEEP_DOWNLOAD=1 mise install

# 2. Pre-clone Zsh plugins
scripts/install-zsh-plugins.sh

# 3. Build the offline bundle (~500MB–1GB)
scripts/build-offline-bundle.sh
# → creates: dotfiles-offline-bundle-YYYYMMDD.tar.gz
```

### Deploy to restricted machine (automated)

```bash
./deploy-remote.sh user@host
# With existing bundle:
./deploy-remote.sh user@host --bundle dotfiles-offline-bundle-YYYYMMDD.tar.gz
# With specific user profile:
./deploy-remote.sh user@host --user enterpriseuser -y
```

### Deploy manually (if automated deploy isn't possible)

```bash
# 1. Transfer bundle and dotfiles repo
scp dotfiles-offline-bundle-YYYYMMDD.tar.gz user@host:/tmp/
rsync -av --exclude='.git' ./ user@host:~/dotfiles-public/

# 2. On the restricted machine
cd ~/dotfiles-public
./bootstrap.sh --offline --archive /tmp/dotfiles-offline-bundle-YYYYMMDD.tar.gz
```

## Bundle Contents

The bundle created by `scripts/build-offline-bundle.sh` contains:

```
bundle.tar.gz
├── bin/
│   ├── chezmoi      # dotfile manager binary
│   └── mise         # tool manager binary
├── mise-cache.tar.gz   # ~/.local/share/mise/{downloads,installs}
└── zsh-plugins.tar.gz  # ~/.local/share/zsh/plugins/* + ~/.tmux/plugins/tpm
```

When `bootstrap.sh --offline --archive bundle.tar.gz` runs, it:
1. Installs `chezmoi` and `mise` binaries to `~/.local/bin`
2. Restores the mise tool cache to `~/.local/share/mise/`
3. Restores Zsh plugins to `~/.local/share/zsh/plugins/`
4. Runs `mise install` with `MISE_OFFLINE=1` (uses cached downloads)
5. Applies dotfiles with `chezmoi apply`
6. Installs Tier 3/4 apt packages (requires apt access, no internet needed)

## Expected Bundle Size

| Component | Typical Size |
|-----------|-------------|
| chezmoi binary | ~10 MB |
| mise binary | ~15 MB |
| mise tool cache (Tier 1/2 tools) | ~300–700 MB |
| Zsh plugins + tpm | ~5–15 MB |
| **Total** | **~330–740 MB** |

Full toolset (all Tier 1/2 tools enabled): up to ~1 GB.

## Transfer Methods

### scp (default)

```bash
scp dotfiles-offline-bundle-YYYYMMDD.tar.gz user@host:/tmp/
```

### S3 bucket

```bash
# Upload from unrestricted machine
aws s3 cp dotfiles-offline-bundle-YYYYMMDD.tar.gz s3://your-bucket/dotfiles/

# Download on restricted machine (if S3 endpoint is accessible)
aws s3 cp s3://your-bucket/dotfiles/dotfiles-offline-bundle-YYYYMMDD.tar.gz /tmp/
```

### GUI / file upload

If an SFTP client or web-based file upload is available (e.g. via a jump host), upload the bundle file and then run `bootstrap.sh --offline --archive /path/to/bundle.tar.gz` manually.

### Docker (for C++ toolchain — see below)

```bash
# Save image locally
docker save my-cpp-toolchain | gzip > cpp-toolchain.tar.gz

# Transfer via scp
scp cpp-toolchain.tar.gz user@host:/tmp/

# Load on restricted machine
ssh user@host 'docker load < /tmp/cpp-toolchain.tar.gz'
```

## Tier 3 Tools: Docker Image for C++ Toolchain

For the full C++ development toolchain (GCC, GDB, CMake, Valgrind, Boost, etc.) in restricted environments where Docker is available, you can pre-build and transfer an image instead of relying on `apt`.

### Dockerfile

```dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ cmake ninja-build \
    gdb valgrind lldb strace ltrace \
    clang-format clang-tidy \
    autoconf automake libtool pkg-config \
    libboost-all-dev libfmt-dev libspdlog-dev \
    libgtest-dev libgmock-dev libcatch2-dev \
    libeigen3-dev libopencv-dev \
    libssl-dev libncurses-dev \
    libvulkan-dev vulkan-validationlayers-dev \
    python3-dev python3-pip \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
```

### Build and transfer

```bash
# Build on unrestricted machine
docker build -f Dockerfile.cpp-toolchain -t cpp-toolchain:latest .

# Save and transfer
docker save cpp-toolchain:latest | gzip > cpp-toolchain.tar.gz
scp cpp-toolchain.tar.gz user@host:/tmp/

# Load on restricted machine
ssh user@host 'docker load < /tmp/cpp-toolchain.tar.gz'

# Run C++ development environment
ssh user@host 'docker run --rm -it -v $HOME/projects:/workspace cpp-toolchain:latest bash'
```

## Bootstrap Flags Reference

```bash
bootstrap.sh --offline                          # No downloads (tools pre-installed)
bootstrap.sh --offline --archive bundle.tar.gz  # Extract bundle, then run offline
bootstrap.sh --offline --no-apt                 # Skip apt (no root required)
bootstrap.sh --offline -y                       # Non-interactive
bootstrap.sh --offline -u enterpriseuser        # Specific user profile
```

## Updating a Deployed Machine

Since the restricted machine has no internet, updates are pushed from an unrestricted machine:

```bash
# Option 1: Re-deploy with a new bundle
scripts/build-offline-bundle.sh
./deploy-remote.sh user@host --bundle dotfiles-offline-bundle-YYYYMMDD.tar.gz

# Option 2: Dotfiles-only update (if tools haven't changed)
rsync -av --exclude='.git' ./ user@host:~/dotfiles-public/
ssh user@host 'cd ~/dotfiles-public && chezmoi apply'
```

## Troubleshooting

**`chezmoi not found` after bootstrap** — check that `~/.local/bin` is in PATH:

```bash
export PATH="${HOME}/.local/bin:${PATH}"
# Add to ~/.zshrc or ~/.bashrc to make permanent
```

**mise offline install fails** — the `downloads/` cache may be incomplete. Rebuild the bundle after running `MISE_ALWAYS_KEEP_DOWNLOAD=1 mise install` on an unrestricted machine.

**apt packages fail to install** — verify that the internal apt repository is reachable:

```bash
apt-cache show gdb    # should print package info
sudo apt-get update   # should succeed without internet if internal mirror is configured
```

**Zsh plugins missing** — rebuild the bundle after running `scripts/install-zsh-plugins.sh` on an unrestricted machine.
