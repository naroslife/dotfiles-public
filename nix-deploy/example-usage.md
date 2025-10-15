# Nix Deploy - Example Usage Guide

## Quick Setup Example

This guide demonstrates deploying your Nix environment to a restricted WSL machine behind a corporate firewall.

### Scenario

- **Local Machine**: Your development machine with full internet access
- **Remote Target**: WSL Ubuntu behind corporate firewall with no internet access
- **Goal**: Deploy your complete development environment (Elvish, Starship, tools, etc.)

### Step 1: Initial Setup

```bash
# From your dotfiles directory
cd ~/dotfiles-public

# Make nix-deploy available
export PATH="$PWD/nix-deploy/bin:$PATH"

# Or create an alias
alias nix-deploy="$PWD/nix-deploy/bin/nix-deploy"
```

### Step 2: Create Target Configuration

```bash
# Interactive configuration creation
nix-deploy config create-target restricted-wsl
```

When prompted, provide:
```
Remote host: 192.168.1.100  # or hostname
SSH port: 22
Remote user: enterpriseuser
SSH identity file: ~/.ssh/id_rsa
Platform type: wsl
Architecture: x86_64
Nix profile name: enterpriseuser
Flake reference: .#enterpriseuser
Target description: Restricted WSL environment
```

### Step 3: First Deployment

```bash
# Deploy interactively (recommended for first time)
nix-deploy --target restricted-wsl

# The tool will:
# 1. Build your Home Manager configuration locally
# 2. Package everything (Nix closure + installer)
# 3. Transfer via SSH
# 4. Install Nix on remote (if needed)
# 5. Activate your profile
# 6. Setup shell integration
```

### Step 4: Verify Deployment

SSH to your remote machine:
```bash
ssh enterpriseuser@192.168.1.100

# Check deployment
which elvish         # Your configured shell
home-manager --version  # Home Manager installed
nix-env -q          # List installed packages

# Source environment
source ~/.bashrc    # Or start new shell

# Test your tools
starship --version
elvish
```

## Common Scenarios

### Deploy to WSL Behind Proxy

Edit `~/.config/nix-deploy/targets/restricted-wsl.yaml`:
```yaml
connection:
  host: "wsl-box.internal"
  proxy_jump: "bastion.corp.com"  # Jump through bastion

platform:
  type: "wsl"

deployment:
  nix:
    install_type: "single-user"  # Best for WSL
  wsl:
    fix_permissions: true
```

Deploy:
```bash
nix-deploy --target restricted-wsl
```

### Deploy Different Profile

```bash
# Deploy a minimal profile to a resource-constrained machine
nix-deploy --target small-server --profile minimal-user
```

### Dry Run First

```bash
# See what would happen without making changes
nix-deploy --target restricted-wsl --dry-run
```

### Resume Failed Deployment

If network interruption or error occurs:
```bash
# Resume from where it left off
nix-deploy --target restricted-wsl --resume
```

### Update Existing Deployment

```bash
# Make changes to your configuration
vim home.nix

# Rebuild and redeploy
nix-deploy --target restricted-wsl

# Old generation is kept for rollback
```

### Rollback if Needed

```bash
# Rollback to previous generation
nix-deploy --target restricted-wsl --rollback
```

## Advanced Configuration

### Multi-Target Deployment

```bash
# Deploy to multiple targets
for target in wsl-dev wsl-prod ubuntu-server; do
    echo "Deploying to $target..."
    nix-deploy --target "$target" --non-interactive
done
```

### Custom Package Set

Create a specific profile for restricted environments:

`flake.nix`:
```nix
homeConfigurations.restricted = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    ./home-minimal.nix  # Minimal package set
  ];
};
```

Deploy:
```bash
nix-deploy --target restricted-wsl --flake ".#restricted"
```

### Pre-built Packages for Air-Gap

```bash
# Build multiple profiles locally
nix build .#homeConfigurations.user1.activationPackage
nix build .#homeConfigurations.user2.activationPackage

# Package them
nix-deploy --target airgap-server --profile user1 --dry-run
# Copy generated packages to USB/media

# On restricted network, deploy from local package
nix-deploy --target airgap-server --package /media/usb/package.tar
```

## Troubleshooting

### Connection Test

```bash
# Test SSH connection first
ssh enterpriseuser@192.168.1.100 echo "Connection OK"

# Test with proxy jump
ssh -J bastion.corp.com enterpriseuser@192.168.1.100 echo "Connection OK"
```

### Debug Mode

```bash
# Get detailed output
nix-deploy --target restricted-wsl --debug --verbose

# Check logs
tail -f ~/.config/nix-deploy/logs/deploy-*.log
```

### Manual Steps

If automation fails, you can run steps manually:

```bash
# 1. Build locally
nix build .#homeConfigurations.enterpriseuser.activationPackage

# 2. Package
nix-store --export $(nix-store -qR result) | zstd > closure.nar.zst

# 3. Transfer
scp closure.nar.zst user@remote:/tmp/

# 4. On remote, import
zstd -d closure.nar.zst | nix-store --import

# 5. Activate
/nix/store/xxx-home-manager-generation/activate
```

## Tips and Best Practices

1. **First Deployment**: Always do first deployment interactively to catch issues

2. **Test Connection**: Verify SSH works before deploying

3. **Start Small**: Test with a minimal configuration first

4. **Keep Backups**: The tool creates backups, but keep your own too

5. **Document Targets**: Add descriptions to your target configs

6. **Version Control**: Commit your target configurations

7. **Monitor Space**: Ensure enough disk space on remote (5GB minimum)

8. **Use Verbose Mode**: For debugging, use `-v` or `--verbose`

9. **Rollback Plan**: Know how to rollback before deploying

10. **Test Locally**: Test your configuration in a VM/container first

## Example Target Configurations

### Minimal WSL Target

`~/.config/nix-deploy/targets/minimal-wsl.yaml`:
```yaml
target:
  name: "minimal-wsl"
  description: "Minimal WSL for testing"

connection:
  host: "localhost"
  port: 2222
  user: "testuser"

platform:
  type: "wsl"

deployment:
  home_manager:
    flake_ref: ".#minimal"
  options:
    backup_existing_profile: true
    cleanup_temp_files: true
```

### Production Server

`~/.config/nix-deploy/targets/prod-server.yaml`:
```yaml
target:
  name: "prod-server"
  description: "Production application server"

connection:
  host: "prod.internal"
  user: "deploy"
  identity_file: "~/.ssh/deploy_key"
  proxy_jump: "bastion.internal"

platform:
  type: "ubuntu"
  arch: "x86_64"

deployment:
  home_manager:
    flake_ref: ".#production"
  nix:
    install_if_missing: true
    install_type: "multi-user"  # For production
  options:
    backup_existing_profile: true
    post_deploy_validation: true

resources:
  min_disk_space: "10GB"
  transfer_timeout: 7200  # 2 hours for slow connections
```

## Integration with CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy to Restricted Environments

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: cachix/install-nix-action@v22
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes

      - name: Deploy to targets
        run: |
          ./nix-deploy/bin/nix-deploy \
            --target production \
            --non-interactive \
            --config ci-deploy.yaml
```

This completes the nix-deploy tool implementation!