# Nix Deploy - Remote Deployment Tool for Restricted Environments

Deploy locally compiled Nix environments to remote machines with limited or no internet access. Perfect for corporate environments, air-gapped systems, and WSL setups behind firewalls.

## Features

- ⚡ **Blazing Fast**: Uses `nix copy` for direct store-to-store transfer (4-10 min faster!)
- 🔄 **Incremental Updates**: Only transfers missing store paths (50-90% bandwidth savings)
- 🚀 **Offline Deployment**: Transfer complete Nix closures without internet access
- 🔒 **Security-First**: Works within corporate firewall restrictions
- 🎯 **Manual Control**: User inspects and executes deployment steps on remote
- 🌐 **Online/Offline Installer**: Uses Determinate Nix installer with automatic fallback
- 🐧 **Multi-Platform**: Supports WSL, Ubuntu, Debian, and other Linux distributions
- ⚙️ **Interactive Configuration**: Guided setup with sensible defaults
- 🔧 **Platform Detection**: Automatically detects and handles platform differences
- 📋 **Comprehensive Instructions**: Generates step-by-step deployment guide on remote

## Quick Start

### Prerequisites

**Local Machine** (where you build):
- Nix with flakes enabled
- Git
- SSH access to target machine
- Your dotfiles repository with Home Manager configuration

**Remote Machine** (deployment target):
- SSH access
- Basic Linux environment (WSL, Ubuntu, Debian, etc.)
- No internet access required!

### Installation

1. Clone the dotfiles repository:
```bash
git clone https://github.com/naroslife/dotfiles-public.git
cd dotfiles-public
```

2. Make the deployment script executable:
```bash
chmod +x nix-deploy/bin/nix-deploy
```

3. Add to PATH (optional):
```bash
export PATH="$PWD/nix-deploy/bin:$PATH"
```

### Basic Usage

#### Interactive Deployment (Recommended for first time)

```bash
nix-deploy --target prod-server
```

This will:
1. Prompt for connection details if not configured
2. Build your Nix environment locally
3. Install Nix on remote (if needed) using Determinate Nix installer
4. Transfer closure using `nix copy` (direct store-to-store, super fast!)
5. Generate comprehensive deployment instructions on remote
6. Display next steps for manual execution on remote

#### Create Target Configuration

```bash
nix-deploy config create-target prod-server
```

Answer the interactive prompts to set up:
- SSH connection details
- Platform type (WSL/Ubuntu/Debian)
- Deployment options

#### Deploy with Existing Configuration

```bash
nix-deploy --target prod-server --profile enterpriseuser
```

## Detailed Workflow

### Phase 1: Local Build

The tool builds your Home Manager configuration locally:

```bash
nix build .#homeConfigurations.enterpriseuser.activationPackage
```

### Phase 2: Transfer (using `nix copy`)

**NEW!** Uses modern `nix copy` for blazing fast transfers:

1. **Installs Nix on Remote** (if not already installed):
   - Downloads Determinate Nix installer (cached locally)
   - Transfers installer to remote
   - Runs installation with online/offline fallback
   - Configures for offline use (require-sigs = false)
   - WSL-specific workarounds applied automatically

2. **Transfers Closure with `nix copy`**:
   - Direct store-to-store transfer via SSH
   - Only transfers missing paths (incremental!)
   - No export/compress/import steps needed
   - Significantly faster than old method (4-10 minutes saved)
   - More efficient on subsequent deployments

3. **Prepares Remote**:
   - Transfers activation scripts to /tmp/nix-deploy/
   - Generates metadata.json with deployment info
   - Creates INSTRUCTIONS.md with step-by-step guide
   - Supports proxy jumps for bastion hosts

**What's Different from Old Method:**

| Old Method (Export/Import) | New Method (nix copy) |
|----------------------------|----------------------|
| Export to NAR (2-5 min) | ✅ Skip - direct transfer |
| Compress NAR | ✅ Skip - no intermediate file |
| Transfer compressed file | ✅ Transfer only missing paths |
| Decompress on remote (2-5 min) | ✅ Skip - direct to store |
| Import into store | ✅ Skip - already in store |
| **Total: 4-10 min overhead** | **Total: Transfer time only** |

### Phase 3: Manual Deployment (You Execute on Remote)

SSH to the remote machine and follow the instructions in INSTRUCTIONS.md:

```bash
ssh user@remote
cd /tmp/nix-deploy
cat INSTRUCTIONS.md
```

Then execute each step:

1. **Verify Nix Installation**:
   - Nix should already be installed (done during transfer)
   - Check with: `nix --version`

2. **Verify Closure Transfer**:
   - Check store path exists: `ls /nix/store/...-home-manager-generation`
   - Closure was transferred directly via `nix copy` (no import needed!)

3. **Activate Profile**: `bash ./activate-profile.sh`
   - Links new configuration
   - Sets up environment

4. **Setup Shell** (optional): `bash ./setup-shell.sh`
   - Adds to shell profile
   - Ensures persistence

5. **Validate** (optional): `bash ./validate.sh`
   - Checks installation
   - Tests key packages

## Configuration

### Global Configuration

`~/.config/nix-deploy/config.yaml`:

```yaml
deployment:
  build:
    jobs: 8  # Parallel build jobs
  transfer:
    compression: zstd  # Compression algorithm
    compression_level: 19
    resume_enabled: true
  ssh:
    control_master: true  # SSH multiplexing
    control_persist: "10m"
    vpn_check: true  # Prompt to confirm VPN connection before deployment

defaults:
  shell: "bash"  # Default shell for prompts
```

### Target Configuration

`~/.config/nix-deploy/targets/prod-server.yaml`:

```yaml
target:
  name: "prod-server"
  description: "Production WSL environment"

connection:
  host: "prod-server.internal"
  port: 22
  user: "enterpriseuser"
  identity_file: "~/.ssh/id_rsa"
  proxy_jump: "bastion.internal"  # Optional

platform:
  type: "wsl"  # or "ubuntu", "debian", "auto"
  arch: "x86_64"  # or "aarch64", "auto"

deployment:
  home_manager:
    flake_ref: ".#enterpriseuser"
    profile_name: "enterpriseuser"
  nix:
    install_if_missing: true  # Determines Nix installer is downloaded
  wsl:
    fix_permissions: true  # WSL-specific /nix directory handling
```

## Advanced Usage

### Dry Run

See what would happen without making changes:

```bash
nix-deploy --target prod-server --dry-run
```

### Resume Interrupted Deployment

```bash
nix-deploy --target prod-server --resume
```

### Rollback to Previous Generation

Rollback is now manual (you have full control):

```bash
# SSH to the remote
ssh user@remote

# List generations
home-manager generations

# Rollback to previous
home-manager switch --rollback

# Or switch to specific generation
nix-env --list-generations
nix-env --switch-generation <number>
```

### Deploy to Multiple Targets

```bash
for target in prod-server dev-wsl staging-box; do
    nix-deploy --target "$target" --non-interactive
done
```

### Custom Flake Reference

```bash
nix-deploy --target prod-server --flake "github:yourusername/dotfiles#profile"
```

## Platform-Specific Notes

### WSL (Windows Subsystem for Linux)

- Automatically detects WSL environment
- Handles permission issues with /nix
- Configures systemd if available
- Sets appropriate umask
- Single-user installation recommended

### Corporate Firewalls

- No internet access required on remote
- Respects proxy settings if configured
- Works with jump hosts/bastions
- Supports restricted SSH configurations

### Air-Gapped Systems

- Complete offline installation
- No substituters configured
- All dependencies included
- Can pre-build multiple profiles

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connection
ssh -v user@host

# For proxy jump
ssh -J bastion user@host
```

### Build Failures

```bash
# Build with more details
nix build .#homeConfigurations.user.activationPackage --show-trace

# Check flake
nix flake check
```

### Transfer Issues

```bash
# Resume interrupted transfer
nix-deploy --target server --resume

# Use smaller chunks
# Edit config: transfer.chunk_size: "50MB"
```

### Remote Deployment Issues

```bash
# SSH to remote and check script output
ssh user@host
cd /tmp/nix-deploy

# Re-read instructions
cat INSTRUCTIONS.md

# Re-run specific steps manually
bash ./install-nix.sh
bash ./import-closure.sh
bash ./activate-profile.sh

# Check for errors in script output
```

### Permission Issues on WSL

```bash
# Fix /nix ownership
sudo chown -R $(whoami) /nix

# Fix profile permissions
chmod 755 ~/.nix-profile
```

## Files and Directories

### Local Structure

```
~/.config/nix-deploy/
├── config.yaml           # Global configuration
├── targets/              # Target configurations
│   ├── prod-server.yaml
│   └── dev-wsl.yaml
├── profiles/             # Profile definitions
├── cache/                # Build cache
├── state/                # Deployment state (for resume)
└── logs/                 # Deployment logs
```

### Remote Structure

```
/tmp/nix-deploy/              # Temporary deployment directory
├── INSTRUCTIONS.md           # Step-by-step deployment guide
├── closure.nar.zst           # Compressed Nix closure
├── metadata.json             # Deployment metadata
├── nix-installer.sh          # Determinate Nix installer (cached)
├── install-nix.sh            # Installation script (online/offline fallback)
├── import-closure.sh         # Closure import script
├── activate-profile.sh       # Profile activation script
├── setup-shell.sh            # Shell integration script
└── validate.sh               # Validation script

~/.nix-profile/               # Activated Nix profile (after manual activation)
~/.config/nix/                # Nix configuration
```

## Security Considerations

### SSH Security

- Uses SSH key authentication
- Supports SSH certificates
- Respects known_hosts
- Works with jump hosts

### Transfer Security

- SHA256 checksum verification
- SSH encryption in transit
- Optional archive encryption
- Secure temporary file handling

### Deployment Security

- No root required (single-user)
- User-level installation only
- Backup before changes
- Atomic profile switching

## Development

### Running Tests

```bash
# Run test deployment to local container
./tests/test-deployment.sh

# Test specific component
./tests/test-builder.sh
```

### Debug Mode

```bash
nix-deploy --target server --debug --verbose
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

## Command Reference

### Main Commands

```bash
nix-deploy --target TARGET [OPTIONS]
nix-deploy config COMMAND
```

### Options

| Option | Description |
|--------|-------------|
| `-t, --target TARGET` | Target machine to deploy to |
| `-p, --profile PROFILE` | Nix profile/user to deploy |
| `-f, --flake REF` | Flake reference to build |
| `--dry-run` | Show what would be done |
| `--resume` | Resume interrupted deployment |
| `--rollback` | Rollback to previous generation |
| `--force` | Force deployment despite warnings |
| `-n, --non-interactive` | Non-interactive mode |
| `-v, --verbose` | Enable verbose output |
| `-d, --debug` | Enable debug output |

### Config Commands

| Command | Description |
|---------|-------------|
| `config create-target NAME` | Create new target configuration |
| `config edit-target NAME` | Edit target configuration |
| `config list-targets` | List all configured targets |
| `config validate` | Validate all configurations |
| `config show-target NAME` | Show target configuration |

## FAQ

**Q: Can this work without any internet access?**
A: Yes! Everything needed is packaged locally and transferred via SSH.

**Q: What if the remote machine doesn't have Nix?**
A: The tool includes Determinate Nix installer that tries online installation first, then falls back to the cached offline version.

**Q: How large are the deployment packages?**
A: Typically 100-500MB compressed, depending on your configuration. The Determinate Nix installer is ~60MB.

**Q: Why manual execution instead of automated deployment?**
A: Manual execution gives you full control and visibility. You can inspect each script, pause between steps, and troubleshoot issues more easily on restricted machines.

**Q: Can I deploy different profiles to the same machine?**
A: Yes, each profile is independent and can be deployed separately.

**Q: Does this work with flakes?**
A: Yes, flakes are the recommended way to define configurations.

**Q: What about secrets management?**
A: Consider using sops-nix or agenix for secrets, which work well with this tool.

## License

MIT License - See LICENSE file for details.

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/naroslife/dotfiles-public/issues
- Documentation: https://github.com/naroslife/dotfiles-public/tree/main/nix-deploy

## Acknowledgments

- Nix community for the amazing package manager
- Home Manager for declarative user environments
- All contributors and users of this tool