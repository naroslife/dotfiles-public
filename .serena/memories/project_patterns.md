# Project Patterns & Best Practices

## Shell Script Patterns

### Module Template
All lib/setup/ modules follow this structure:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Guard against multiple sourcing
if [[ -n "${MODULE_NAME_LOADED:-}" ]]; then
    return 0
fi
readonly MODULE_NAME_LOADED=1

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"  # Adjust path based on depth

# Module functions...
```

### Error Handling Standards
- Use `die "message"` for fatal errors (from common.sh)
- Use `log_error`, `log_warn`, `log_info`, `log_debug` for output
- Check command existence: `command -v tool >/dev/null 2>&1`
- Validate prerequisites before operations
- Use `set -euo pipefail` for strict error handling

### Naming Conventions
- **Functions**: snake_case (e.g., `check_nix_installation`)
- **Constants**: UPPER_CASE (e.g., `NIX_INSTALL_URL`)
- **Variables**: snake_case (e.g., `temp_installer`)
- **Guards**: ${MODULE_NAME}_LOADED (e.g., `NVIDIA_SETUP_LOADED`)

## Nix Configuration Patterns

### Module Structure
```nix
{ config, lib, pkgs, ... }:
{
  imports = [ ./submodule.nix ];
  
  # Use let bindings to reduce duplication
  let
    homeDir = config.home.homeDirectory;
    xdgConfig = "${homeDir}/.config";
  in {
    # Configuration here
  };
}
```

### Helper Patterns
```nix
# Shell integration helper (lib/shell-helpers.nix)
shellHelpers.withShells defaultShells {
  # Program-specific config
};

# Environment variable with let binding
let homeDir = config.home.homeDirectory;
in {
  ENV_VAR = "${homeDir}/path";
}
```

### Validation Pattern
```nix
# Add assertions to modules/validation.nix
config.assertions = [
  {
    assertion = condition;
    message = "Error message explaining the issue...";
  }
];
```

## Architecture Patterns

### Module Organization
```
modules/
├── core.nix           # Essential packages
├── environment.nix    # Environment variables
├── validation.nix     # Build-time assertions
├── shells/            # Shell configurations
│   └── default.nix
├── dev/               # Development tools
│   └── default.nix
└── cli/               # CLI utilities
    └── default.nix
```

### Library Organization
```
lib/
├── common.sh          # Logging, error handling, platform detection
├── user_config.sh     # Interactive configuration
├── sops_bootstrap.sh  # Secrets management
├── shell-helpers.nix  # Nix helper functions
└── setup/             # Modular setup scripts
    ├── nix.sh
    ├── user.sh
    ├── homemanager.sh
    ├── github.sh
    └── platform/
        ├── wsl.sh
        └── nvidia.sh
```

### Orchestration Pattern
1. Main script (apply.sh) sources all modules
2. Validates prerequisites
3. Calls module functions in orchestrated sequence
4. Module functions are autonomous and focused
5. Error handling delegated to common.sh

## Testing & Validation

### Shell Script Validation
```bash
# Syntax check
bash -n script.sh

# All modules
for f in lib/setup/*.sh lib/setup/platform/*.sh; do
  bash -n "$f" || echo "Failed: $f"
done
```

### Nix Validation
```bash
# Full flake check
nix flake check

# Build specific configuration
nix build .#homeConfigurations.username.activationPackage

# Format check
nixpkgs-fmt --check .
```

### Build Validation Pattern
- Always run `nix flake check` after Nix changes
- Validate bash syntax with `bash -n` after shell changes
- Pre-existing format issues are acceptable if unrelated to changes
- Build-all derivation success is required for completion

## Documentation Patterns

### README Structure
- Overview of module/script purpose
- Usage examples with expected output
- Function/export documentation
- Standards and conventions section
- Migration status or progress tracking
- Future enhancements roadmap

### Inline Documentation
```bash
# Function comment explaining purpose
# Args: $1 - description
# Returns: 0 on success, 1 on error
function_name() {
    # Implementation comment for complex logic
}
```

### Memory Documentation
- Create Serena memory for significant work
- Include quantitative metrics (lines changed, modules created)
- Document patterns and decisions for cross-session learning
- Provide continuation points for future sessions

## Common Utilities (lib/common.sh)

### Logging Functions
- `log_debug "message"` - Debug information
- `log_info "message"` - General information
- `log_warn "message"` - Warnings (non-fatal)
- `log_error "message"` - Errors (non-fatal)
- `die "message"` - Fatal error (exits with code 1)

### Platform Detection
- `is_wsl` - Returns 0 if running in WSL
- `is_linux` - Returns 0 if running on Linux
- `detect_platform` - Returns platform string

### Validation Utilities
- `ask_yes_no "prompt" [default]` - Interactive yes/no prompt
- `backup_file "path"` - Create timestamped backup
- `fetch_url "url" "dest" "checksum"` - Download with verification

## Git Workflow

### Branch Strategy
- Work on feature branches (feature/*, fix/*)
- Never commit directly to main
- Keep commits focused and atomic
- Use descriptive commit messages

### Commit Message Format
```
type: brief description

Detailed explanation if needed

- Change 1
- Change 2
- Change 3
```

Types: feat, fix, refactor, docs, test, chore

## Quality Standards

### Code Quality
- Functions < 50 lines preferred
- Modules < 200 lines preferred
- Single responsibility per function/module
- Clear, descriptive names
- Minimal coupling between modules

### Documentation Quality
- Every module has header comment
- Complex functions have inline comments
- README updated with changes
- Memory files for significant work

### Validation Quality
- All syntax checks pass
- Build validation succeeds
- Pre-existing issues don't block if unrelated
- Manual testing recommended for behavior changes
