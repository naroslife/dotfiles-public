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

### Step 3: Transfer Package

```bash
# Transfer package to remote (nix-deploy handles this)
nix-deploy --target restricted-wsl

# The tool will:
# 1. Build your Home Manager configuration locally
# 2. Package everything (Nix closure + Determinate Nix installer)
# 3. Transfer via SSH to /tmp/nix-deploy/
# 4. Generate INSTRUCTIONS.md on remote
# 5. Display next steps
```

### Step 4: Manual Deployment on Remote

SSH to your remote machine and execute the scripts:

```bash
ssh enterpriseuser@192.168.1.100
cd /tmp/nix-deploy

# Read the instructions first
cat INSTRUCTIONS.md

# Step 1: Install Nix (if needed)
bash ./install-nix.sh
# - Tries online installation first
# - Falls back to offline if no internet

# Step 2: Import the closure
bash ./import-closure.sh

# Step 3: Activate your profile
bash ./activate-profile.sh

# Step 4: Setup shell integration (optional)
bash ./setup-shell.sh

# Step 5: Validate (optional)
bash ./validate.sh
```

### Step 5: Verify and Use

After successful manual deployment:

```bash
# Start a new shell or source profile
source ~/.bashrc

# Check deployment
which elvish         # Your configured shell
home-manager --version  # Home Manager installed
nix-env -q          # List installed packages

# Test your tools
starship --version
elvish

# Cleanup deployment files (optional)
rm -rf /tmp/nix-deploy
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
    install_if_missing: true  # Download Determinate Nix installer
  wsl:
    fix_permissions: true  # WSL-specific /nix handling
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

Rollback is now manual for full control:

```bash
# SSH to the remote
ssh enterpriseuser@192.168.1.100

# List generations
home-manager generations

# Rollback to previous generation
home-manager switch --rollback

# Or switch to specific generation
nix-env --list-generations
nix-env --switch-generation <number>
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

### Manual Workflow (All Deployments)

All deployments now follow the manual workflow for security and control:

```bash
# 1. Local: Transfer package (nix-deploy does this)
nix-deploy --target restricted-wsl

# 2. Remote: SSH and navigate
ssh user@remote
cd /tmp/nix-deploy

# 3. Remote: Read instructions
cat INSTRUCTIONS.md

# 4. Remote: Execute scripts step-by-step
bash ./install-nix.sh      # Install Nix (online/offline fallback)
bash ./import-closure.sh   # Import store paths
bash ./activate-profile.sh # Activate configuration
bash ./setup-shell.sh      # Setup shell (optional)
bash ./validate.sh         # Validate (optional)

# 5. Remote: Verify and use
source ~/.bashrc
which elvish
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
  nix:
    install_if_missing: true
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