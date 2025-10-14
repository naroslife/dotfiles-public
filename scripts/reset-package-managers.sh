#!/usr/bin/env bash
# Reset all package manager installations to baseline
# This script backs up and cleans user-level package installations,
# allowing you to return to your reproducible Nix baseline

set -e

echo "════════════════════════════════════════════════════════════"
echo "  Package Manager Reset Script"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "This will reset package manager installations to your Nix baseline."
echo "All existing packages will be backed up before removal."
echo ""

# Backup function
backup_dir() {
    local dir=$1
    if [ -d "$dir" ]; then
        local backup
        backup="${dir}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "  📦 Backing up $dir to $backup"
        mv "$dir" "$backup"
        return 0
    fi
    return 1
}

# Reset npm
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NPM Global Packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "$HOME/.npm-global" ]; then
    echo "Current packages:"
    if [ -d "$HOME/.npm-global/lib/node_modules" ]; then
        find "$HOME/.npm-global/lib/node_modules" -maxdepth 1 -mindepth 1 -type d ! -name 'npm' -exec basename {} \; 2>/dev/null || echo "  (none)"
    else
        echo "  (none)"
    fi
    echo ""
    backup_dir "$HOME/.npm-global"
    mkdir -p "$HOME/.npm-global"
    echo "  ✓ npm global packages reset"
else
    echo "  ℹ️  No npm global packages found"
fi
echo ""

# Reset pip
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Python pip User Packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "$HOME/.local/lib" ]; then
    echo "Current packages:"
    find "$HOME/.local/lib/python"*/site-packages -maxdepth 1 -type d 2>/dev/null | \
        grep -v '__pycache__\|\.dist-info\|\.egg-info\|site-packages$' | \
        xargs -n1 basename 2>/dev/null | head -20 || echo "  (none)"
    echo ""
    backup_dir "$HOME/.local/lib"
    mkdir -p "$HOME/.local/lib"
    # Also backup and recreate bin directory
    if [ -d "$HOME/.local/bin" ]; then
        backup_dir "$HOME/.local/bin"
    fi
    mkdir -p "$HOME/.local/bin"
    echo "  ✓ pip user packages reset"
else
    echo "  ℹ️  No pip user packages found"
fi
echo ""

# Reset cargo (with confirmation)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Rust Cargo Packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "$HOME/.cargo/bin" ] && [ -n "$(ls -A "$HOME/.cargo/bin" 2>/dev/null)" ]; then
    echo "Current packages:"
    ls -1 "$HOME/.cargo/bin" 2>/dev/null | head -20 || echo "  (none)"
    echo ""
    read -p "Reset Cargo packages? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        backup_dir "$HOME/.cargo/bin"
        mkdir -p "$HOME/.cargo/bin"
        echo "  ✓ cargo packages reset"
    else
        echo "  ⊘ cargo packages skipped"
    fi
else
    echo "  ℹ️  No cargo packages found"
fi
echo ""

# Reset ruby gems
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ruby Gems"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "$HOME/.gem" ]; then
    echo "Current gems:"
    find "$HOME/.gem" -name "*.gemspec" -print0 2>/dev/null | \
        xargs -0 -n1 basename 2>/dev/null | \
        sed 's/\.gemspec$//' | head -20 || echo "  (none)"
    echo ""
    backup_dir "$HOME/.gem"
    mkdir -p "$HOME/.gem"
    echo "  ✓ ruby gems reset"
else
    echo "  ℹ️  No ruby gems found"
fi
echo ""

# Summary
echo "════════════════════════════════════════════════════════════"
echo "  Reset Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📋 Next steps:"
echo "  1. Run './apply.sh' to restore your Nix baseline"
echo "  2. Reinstall packages as needed:"
echo "     • npm install -g <package>"
echo "     • pip install <package>"
echo "     • cargo install <package>"
echo "     • gem install <package>"
echo ""
echo "💾 Backups are stored with .backup.* suffix in:"
echo "  • ~/.npm-global.backup.*"
echo "  • ~/.local/lib.backup.*"
echo "  • ~/.cargo/bin.backup.*"
echo "  • ~/.gem.backup.*"
echo ""
echo "🧹 To remove backups: rm -rf ~/.*backup*"
echo ""
