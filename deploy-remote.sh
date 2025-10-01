#!/usr/bin/env bash
# filepath: /home/naroslife/dotfiles-public/deploy-remote.sh

set -euo pipefail

# Colors and emojis for output (matching apply.sh style)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo "✅ $1"; }
print_warn() { echo "⚠️  $1"; }
print_error() { echo "❌ $1"; }

# Check if remote host is provided
if [[ $# -ne 1 ]]; then
    print_error "Usage: $0 <user@host>"
    echo "   Example: $0 user@192.168.1.100"
    exit 1
fi

REMOTE_HOST="$1"
REMOTE_USER="${REMOTE_HOST%%@*}"

echo "🚀 Deploying Home Manager configuration to ${REMOTE_HOST}..."

# Verify SSH connection
echo "🔌 Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${REMOTE_HOST}" "echo 'SSH connection successful'" &>/dev/null; then
    print_error "Cannot connect to ${REMOTE_HOST}. Please check SSH access."
    echo "   Ensure you have SSH key authentication set up"
    exit 1
fi

# Check if Nix is installed locally
if ! command -v nix &> /dev/null; then
    print_error "Nix is not installed locally. Please install Nix first:"
    echo "   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    exit 1
fi

# Check if flakes are enabled locally
if ! nix --version | grep -q "flakes" 2>/dev/null; then
    echo "📝 Enabling flakes and nix-command locally..."
    mkdir -p ~/.config/nix
    if ! grep -q "experimental-features = nix-command flakes" ~/.config/nix/nix.conf 2>/dev/null; then
        echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    fi
fi

# Initialize submodules if they exist
if [[ -f ".gitmodules" ]]; then
    echo "📦 Initializing git submodules..."
    git submodule update --init --recursive
fi

# Build the Home Manager configuration locally
echo "🔨 Building Home Manager configuration locally..."
BUILD_OUTPUT=$(mktemp)
if ! nix build --no-link --print-out-paths .#homeConfigurations.naroslife.activationPackage 2>&1 | tee "${BUILD_OUTPUT}"; then
    print_error "Failed to build configuration"
    rm -f "${BUILD_OUTPUT}"
    exit 1
fi

# Extract the store path from build result
STORE_PATH=$(tail -n1 "${BUILD_OUTPUT}")
rm -f "${BUILD_OUTPUT}"
print_info "Built configuration at: ${STORE_PATH}"

# Compute closure to get all dependencies
echo "📊 Computing closure (all dependencies)..."
CLOSURE=$(nix-store -qR "${STORE_PATH}")
CLOSURE_SIZE=$(nix path-info -S "${STORE_PATH}" | awk '{print $2}')
CLOSURE_SIZE_MB=$((CLOSURE_SIZE / 1024 / 1024))
echo "📦 Total closure size: ${CLOSURE_SIZE_MB} MB"

# Check if Determinate Nix is installed on remote
echo "🔍 Checking Nix installation on remote..."
REMOTE_HAS_NIX=$(ssh "${REMOTE_HOST}" "command -v nix >/dev/null 2>&1 && echo 'yes' || echo 'no'")

if [[ "${REMOTE_HAS_NIX}" == "no" ]]; then
    print_warn "Nix is not installed on remote."
    echo "📥 Installing Determinate Systems' Nix on remote..."
    
    # Download installer locally and copy to remote (for restricted environments)
    echo "   Downloading installer locally first..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix -o /tmp/nix-installer.sh
    
    echo "   Copying installer to remote..."
    scp /tmp/nix-installer.sh "${REMOTE_HOST}:/tmp/"
    rm -f /tmp/nix-installer.sh
    
    echo "   Running installer on remote..."
    ssh -t "${REMOTE_HOST}" "bash /tmp/nix-installer.sh install --no-confirm && rm -f /tmp/nix-installer.sh" || {
        print_error "Failed to install Nix on remote"
        print_warn "You may need to install Nix manually on the remote machine:"
        echo "   1. Copy the installer from https://install.determinate.systems/nix"
        echo "   2. Run: sh nix-installer.sh install"
        echo "   3. Re-run this deployment script"
        exit 1
    }
    
    # Wait for daemon to start
    echo "⏳ Waiting for Nix daemon to start..."
    sleep 5
fi

# Enable flakes on remote if needed
echo "📝 Ensuring flakes are enabled on remote..."
ssh "${REMOTE_HOST}" "mkdir -p ~/.config/nix && grep -q 'experimental-features = nix-command flakes' ~/.config/nix/nix.conf 2>/dev/null || echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf"

# Copy the closure to remote machine
echo "📤 Copying Nix store paths to remote..."
echo "   This may take a while (${CLOSURE_SIZE_MB} MB)..."

# Use nix copy with SSH store - Determinate Nix supports this well
if ! nix copy --to "ssh://${REMOTE_HOST}" "${STORE_PATH}" --no-check-sigs; then
    print_error "Failed to copy store paths to remote"
    echo "   Trying alternative method..."
    
    # Alternative: use nix-store export/import
    echo "📦 Creating NAR archive..."
    NAR_FILE=$(mktemp -d)/closure.nar
    nix-store --export $(nix-store -qR "${STORE_PATH}") > "${NAR_FILE}"
    
    echo "📤 Copying NAR archive to remote..."
    scp "${NAR_FILE}" "${REMOTE_HOST}:/tmp/closure.nar"
    
    echo "📥 Importing on remote..."
    ssh "${REMOTE_HOST}" "nix-store --import < /tmp/closure.nar && rm -f /tmp/closure.nar"
    
    rm -rf "$(dirname "${NAR_FILE}")"
fi

print_info "Store paths copied successfully"

# Copy the dotfiles-public repository to remote
echo "📁 Syncing dotfiles-public repository to remote..."
ssh "${REMOTE_HOST}" "mkdir -p ~/dotfiles-public"

# Use rsync to efficiently copy files
if command -v rsync &> /dev/null; then
    rsync -av \
        --exclude='.git' \
        --exclude='result' \
        --exclude='result-*' \
        --exclude='*.swp' \
        --exclude='.direnv' \
        ./ "${REMOTE_HOST}:~/dotfiles-public/"
else
    # Fallback to tar over SSH
    tar czf - \
        --exclude='.git' \
        --exclude='result' \
        --exclude='result-*' \
        . | ssh "${REMOTE_HOST}" "cd ~/dotfiles-public && tar xzf -"
fi

# Create and run activation script on remote
echo "🎯 Activating configuration on remote..."
ssh "${REMOTE_HOST}" bash <<REMOTE_SCRIPT
set -euo pipefail

echo "🏠 Activating Home Manager configuration..."

# Ensure user's nix profile exists
mkdir -p /nix/var/nix/profiles/per-user/${REMOTE_USER}

# Create a profile link
nix-env --profile /nix/var/nix/profiles/per-user/${REMOTE_USER}/home-manager --set "${STORE_PATH}"

# Run the activation
"${STORE_PATH}/activate"

echo "✅ Home Manager configuration activated!"
REMOTE_SCRIPT

# Create update helper script on remote
echo "📝 Creating update helper script on remote..."
ssh "${REMOTE_HOST}" "cat > ~/dotfiles-public/update-from-local.sh" <<'UPDATE_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

echo "🔄 This script should be run from a machine with internet access:"
echo "   cd ~/dotfiles-public"
echo "   ./deploy-remote.sh $(whoami)@$(hostname)"
echo ""
echo "Current activation package:"
readlink -f ~/.nix-profile
UPDATE_SCRIPT

ssh "${REMOTE_HOST}" "chmod +x ~/dotfiles-public/update-from-local.sh"

print_info "Deployment complete! 🎉"
echo "📍 The Home Manager environment is now active on ${REMOTE_HOST}"
echo ""
echo "📚 Notes:"
echo "   • The remote machine won't be able to update without network access"
echo "   • To update, run this script again from an unrestricted machine"
echo "   • Configuration is available at ~/dotfiles-public on the remote"

if [[ -d "base" ]] && [[ -f "base/base.sh" ]]; then
    echo "   • Base shell framework will be automatically sourced"
fi

if [[ -d "stdlib.sh" ]] && [[ -f "stdlib.sh/stdlib.sh" ]]; then
    echo "   • Stdlib.sh will be automatically sourced"
fi

echo ""
echo "🎉 Please reload your shell or restart your terminal on the remote machine."