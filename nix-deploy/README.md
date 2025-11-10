# Nix Deploy - Remote Deployment Tool for Restricted Environments

Deploy locally compiled Nix environments to remote machines with limited or no internet access. Perfect for corporate environments, air-gapped systems, and WSL setups behind firewalls.

## Features

- 🚀 **Offline Deployment**: Transfer complete Nix closures without internet access
- 🔒 **Security-First**: Works within corporate firewall restrictions
- 🐧 **Multi-Platform**: Supports WSL, Ubuntu, Debian, and other Linux distributions
- 📦 **Complete Packages**: Includes all dependencies in a single transfer
- 🔄 **Resumable Transfers**: Continue interrupted deployments
- ⚙️ **Interactive Configuration**: Guided setup with sensible defaults
- 🔧 **Platform Detection**: Automatically detects and handles platform differences
- 💾 **Backup & Rollback**: Safe deployment with easy rollback options

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
2. Detect remote platform automatically
3. Build your Nix environment locally
4. Package everything for offline transfer
5. Deploy and activate on the remote machine

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

### Phase 2: Package Creation

Creates a compressed archive containing:
- Complete Nix store closure
- Offline Nix installer (if needed)
- Deployment scripts
- Metadata for verification

### Phase 3: Transfer

Securely transfers the package via SSH:
- Uses rsync for resumable transfers
- Verifies checksums
- Supports proxy jumps for bastion hosts

### Phase 4: Remote Installation

On the remote machine:
1. Installs Nix if not present (offline installer)
2. Imports the store closure
3. Activates the Home Manager profile
4. Sets up shell integration

### Phase 5: Validation

Verifies the deployment:
- Checks Nix installation
- Validates profile activation
- Tests key packages
- Ensures shell integration

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

defaults:
  nix_install_type: "single-user"
  backup_existing: true
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
    install_if_missing: true
    install_type: "single-user"  # Recommended for WSL
  options:
    backup_existing_profile: true
    setup_shell_integration: true
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

### Rollback Deployment

```bash
nix-deploy --target prod-server --rollback
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

### Remote Installation Issues

```bash
# Check remote logs
ssh user@host "cat /tmp/nix-deploy/deploy.log"

# Manual validation
ssh user@host "bash /tmp/nix-deploy/validate.sh"
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
/tmp/nix-deploy/          # Temporary deployment directory
├── closure.nar.zst       # Compressed Nix closure
├── metadata.json         # Deployment metadata
├── nix-installer.tar.gz  # Offline Nix installer
├── *.sh                  # Deployment scripts
└── deploy.log           # Deployment log

~/.nix-profile/          # Activated Nix profile
~/.config/nix/           # Nix configuration
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
A: The tool includes an offline Nix installer that works without internet.

**Q: How large are the deployment packages?**
A: Typically 100-500MB compressed, depending on your configuration.

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