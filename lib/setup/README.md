# Setup Module Library

This directory contains modularized setup scripts extracted from the monolithic `apply.sh`.

## Architecture

The setup system follows a modular architecture where:
- **apply.sh** acts as the orchestrator
- **lib/common.sh** provides shared utilities
- **lib/setup/** modules provide domain-specific functionality

## Modules

### Core Modules

#### `nix.sh`
Nix package manager installation and validation.

**Functions:**
- `install_nix()` - Download and install Nix with checksum verification
- `check_nix_installation()` - Validate Nix is installed and working

**Dependencies:** lib/common.sh

---

### Planned Modules (Future Enhancement)

The following modules are planned for future implementation to complete the modularization:

#### `user.sh`
User configuration and git submodule management.

**Functions:**
- `select_user()` - Interactive user selection for flake configurations
- `run_user_configuration()` - Run interactive user config wizard
- `setup_git_submodules()` - Initialize git submodules

#### `homemanager.sh`
Home Manager configuration application.

**Functions:**
- `apply_home_manager()` - Apply Home Manager configuration with backups

#### `github.sh`
GitHub CLI setup and authentication.

**Functions:**
- `setup_github_cli()` - GitHub CLI installation and auth

#### `platform/wsl.sh`
WSL-specific optimizations and configurations.

**Functions:**
- `apply_wsl_optimizations()` - Apply WSL performance and integration optimizations

#### `platform/nvidia.sh`
NVIDIA GPU detection and CUDA setup.

**Functions:**
- `has_nvidia_gpu()` - Detect NVIDIA GPU presence
- `offer_cuda_setup()` - Interactive CUDA installation guide

---

## Usage Pattern

### Module Template

All modules follow this structure:

```bash
#!/usr/bin/env bash
# Module Description

set -euo pipefail

# Guard against multiple sourcing
if [[ -n "${MODULE_NAME_LOADED:-}" ]]; then
    return 0
fi
readonly MODULE_NAME_LOADED=1

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../common.sh"

# Module functions here...
```

### Sourcing in apply.sh

```bash
# Source setup modules
source "$SCRIPT_DIR/lib/setup/nix.sh"
source "$SCRIPT_DIR/lib/setup/user.sh"
source "$SCRIPT_DIR/lib/setup/homemanager.sh"
source "$SCRIPT_DIR/lib/setup/github.sh"
source "$SCRIPT_DIR/lib/setup/platform/wsl.sh"
source "$SCRIPT_DIR/lib/setup/platform/nvidia.sh"

# Use module functions
check_nix_installation
select_user
apply_home_manager
setup_github_cli
apply_wsl_optimizations
offer_wsl_config
setup_cuda_wsl
setup_nvidia_drivers
```

## Benefits

### Maintainability
- **Single Responsibility**: Each module handles one domain (Nix, user config, platform)
- **Testability**: Modules can be tested independently
- **Readability**: ~70 lines per module vs 536-line monolith

### Extensibility
- **Easy Addition**: New platform support (macOS, NixOS) = new platform/ module
- **Optional Features**: Source only needed modules for minimal setups
- **Version Control**: Changes isolated to relevant modules

### Safety
- **Validation**: Each module can be validated independently
- **Rollback**: Easier to revert specific functionality
- **Debugging**: Clear error sources and stack traces

## Standards

### Naming Conventions
- Files: `snake_case.sh`
- Functions: `snake_case()`
- Constants: `UPPER_CASE`
- Module guards: `${MODULE_NAME}_LOADED`

### Error Handling
- Always use `set -euo pipefail`
- Use `die()` from common.sh for fatal errors
- Use `log_*` functions for output
- Validate inputs and prerequisites

### Documentation
- Header comment explaining module purpose
- Function-level comments for complex logic
- Usage examples in README

## Migration Status

- [x] lib/setup/nix.sh - **Complete** (install_nix, check_nix_installation)
- [x] lib/setup/user.sh - **Complete** (setup_git_submodules, select_user, run_user_configuration)
- [x] lib/setup/homemanager.sh - **Complete** (apply_home_manager)
- [x] lib/setup/github.sh - **Complete** (setup_github_cli)
- [x] lib/setup/platform/wsl.sh - **Complete** (apply_wsl_optimizations)
- [x] lib/setup/platform/nvidia.sh - **Complete** (has_nvidia_gpu, setup_nvidia_drivers, setup_cuda_wsl, offer_wsl_config)
- [x] apply.sh - **Refactored** (536 lines → 196 lines, 63% reduction)

---

## Future Enhancements

### Phase 1: Core Modules ✅ Complete
- [x] Extract Nix installation logic
- [x] Extract user/submodule management
- [x] Extract Home Manager application
- [x] Extract GitHub CLI setup

### Phase 2: Platform Support ✅ Complete
- [x] WSL optimization module
- [x] NVIDIA/CUDA detection and setup
- [ ] macOS-specific configurations (future)

### Phase 3: Advanced Features
- [ ] Parallel module execution
- [ ] Module dependency resolution
- [ ] Configuration profiles (minimal, desktop, server)
- [ ] Module-level testing framework
- [ ] Integration tests for modular architecture

---

## Contributing

When adding new modules:

1. Follow the module template structure
2. Add to this README with description and function list
3. Update apply.sh to source the module
4. Include unit tests in tests/setup/
5. Document any new dependencies

## References

- Main setup script: `../../apply.sh`
- Common utilities: `../common.sh`
- Test suite: `../../tests/`
