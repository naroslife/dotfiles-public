#!/usr/bin/env bash
# Quick Reference: Mutable Package Managers
# Source: docs/MUTABLE_PACKAGE_MANAGERS.md

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════╗
║              MUTABLE PACKAGE MANAGERS - QUICK REFERENCE                  ║
╚══════════════════════════════════════════════════════════════════════════╝

📦 INSTALL PACKAGES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  npm install -g <package>      # Node.js packages → ~/.npm-global
  pip install <package>          # Python packages → ~/.local
  cargo install <package>        # Rust packages → ~/.cargo/bin
  gem install <package>          # Ruby gems → ~/.gem
  go install <package>@latest    # Go packages → ~/go/bin

🔍 LIST PACKAGES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  npm list -g --depth=0          # List global npm packages
  pip list --user                # List user pip packages
  cargo install --list           # List cargo packages
  gem list                       # List ruby gems

🧹 CLEAN INDIVIDUAL PACKAGE MANAGERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  npm-clean                      # Clean npm global packages
  pip-clean                      # Clean pip user packages
  cargo-clean                    # Clean cargo packages

🔄 RESET ALL PACKAGE MANAGERS TO BASELINE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ./scripts/reset-package-managers.sh
  ./apply.sh                     # Restore Nix baseline

🐍 PYTHON VIRTUAL ENVIRONMENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  venv                           # Create & activate .venv
  source .venv/bin/activate      # Activate existing venv
  deactivate                     # Deactivate venv

⚙️  MUTABLE CONFIGURATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ~/.bashrc.local                # Add custom bash config here
                                 # (automatically sourced, not managed by Nix)

📂 INSTALLATION DIRECTORIES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ~/.npm-global/                 # NPM global packages
  ~/.local/lib/python*/          # Python pip packages
  ~/.cargo/bin/                  # Rust cargo binaries
  ~/.gem/                        # Ruby gems
  ~/go/bin/                      # Go packages

📋 BACKUP LOCATIONS (after reset)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ~/.npm-global.backup.TIMESTAMP
  ~/.local/lib.backup.TIMESTAMP
  ~/.cargo/bin.backup.TIMESTAMP
  ~/.gem.backup.TIMESTAMP

💡 PHILOSOPHY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • Nix = Immutable baseline (version controlled, reproducible)
  • Package managers = Mutable layer (experiments, ad-hoc installs)
  • Reset script = Easy return to baseline
  • No sudo required (all user-level installations)

📚 DOCUMENTATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  docs/MUTABLE_PACKAGE_MANAGERS.md

EOF
