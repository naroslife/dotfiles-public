# CUDA Setup CLI - Architecture Design

## Overview
Transform cuda-setup bash scripts into a modern, developer-friendly Python CLI with interactive features, rich terminal output, and comprehensive error handling.

## CLI Commands Structure

```
cuda-setup [COMMAND] [OPTIONS]

Commands:
  doctor          Run comprehensive system diagnostics
  check           Check driver compatibility with CUDA 12.9
  fix             Fix nvidia-smi segfault issue
  install         Install CUDA 12.9 toolkit
  test            Verify CUDA installation
  info            Show GPU and driver information
  compile         Compile and run CUDA test program
  update-driver   Show driver update instructions
```

## Features

### 1. Rich Terminal Output
- Color-coded messages (success, warning, error, info)
- Progress bars for installations
- Tables for system information
- Syntax highlighting for code/commands

### 2. Interactive Mode
- Guided installation wizard
- Confirmation prompts
- Smart defaults
- Skip options for automation

### 3. Comprehensive Diagnostics
- Pre-flight checks before operations
- Detailed error messages with solutions
- System compatibility validation
- Auto-fix common issues

### 4. Developer Experience
- `--verbose` flag for debugging
- `--quiet` flag for CI/CD
- `--dry-run` for preview
- JSON output for scripting (`--json`)
- Configuration file support

## Technical Stack

### Core Libraries
- **typer** - Modern CLI framework with excellent UX
- **rich** - Beautiful terminal output
- **pydantic** - Configuration and data validation
- **subprocess** - System command execution

### Architecture

```
cuda-setup/
├── cuda_cli/
│   ├── __init__.py
│   ├── main.py              # CLI entry point
│   ├── commands/
│   │   ├── __init__.py
│   │   ├── doctor.py        # Diagnostics command
│   │   ├── check.py         # Driver check command
│   │   ├── fix.py           # nvidia-smi fix command
│   │   ├── install.py       # Installation command
│   │   ├── test.py          # Testing command
│   │   └── info.py          # System info command
│   ├── core/
│   │   ├── __init__.py
│   │   ├── driver.py        # Driver detection & validation
│   │   ├── cuda.py          # CUDA operations
│   │   ├── nvidia_smi.py    # nvidia-smi management
│   │   ├── system.py        # System checks (WSL2, Ubuntu)
│   │   └── constants.py     # Version requirements
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── output.py        # Rich console helpers
│   │   ├── subprocess.py    # Command execution
│   │   └── validators.py    # Input validation
│   └── config/
│       ├── __init__.py
│       └── settings.py      # Configuration management
├── tests/
│   └── ...                  # Unit tests
├── pyproject.toml           # Project metadata & dependencies
├── setup.py                 # Installation script
└── README.md                # Updated documentation
```

## Command Details

### `cuda-setup doctor`
**Purpose:** Comprehensive system diagnostics

**Checks:**
- WSL2 detection
- Windows NVIDIA driver presence
- Driver version compatibility
- nvidia-smi health
- CUDA toolkit installation status
- Environment variables
- GPU detection
- Disk space availability

**Output:** Detailed report with ✓/✗ indicators and solutions

### `cuda-setup check`
**Purpose:** Validate driver compatibility with CUDA 12.9

**Features:**
- Auto-fix nvidia-smi if segfaulting
- Version comparison with visual indicators
- Upgrade recommendations
- Links to driver downloads

### `cuda-setup fix`
**Purpose:** Fix nvidia-smi segfault

**Features:**
- Automatic backup of old nvidia-smi
- Symlink to Windows version
- Verification test
- Rollback capability

### `cuda-setup install`
**Purpose:** Install CUDA 12.9 toolkit

**Features:**
- Interactive wizard mode
- Pre-installation validation
- Progress indicators
- Environment configuration
- Post-install verification
- Shell profile updates (bashrc/zshrc detection)

**Flags:**
- `--wizard` - Interactive mode (default)
- `--auto` - Non-interactive mode
- `--skip-checks` - Skip validation (dangerous)
- `--no-env` - Don't modify shell configs

### `cuda-setup test`
**Purpose:** Verify CUDA installation

**Features:**
- Quick smoke tests
- Environment variable checks
- Compiler verification
- Runtime tests
- Detailed error diagnostics

### `cuda-setup info`
**Purpose:** Display system information

**Output:**
- GPU model and capabilities
- Driver version
- CUDA version supported
- Toolkit version (if installed)
- Environment variables
- System details (OS, kernel, WSL version)

**Flags:**
- `--json` - JSON output for scripting
- `--full` - Include detailed specs

### `cuda-setup compile`
**Purpose:** Compile and run test program

**Features:**
- Automatic nvcc detection
- Compilation with progress
- Runtime execution
- Result validation
- Performance metrics

## Error Handling

### Error Categories
1. **System Errors** - WSL2 not detected, wrong OS
2. **Driver Errors** - Missing/old driver, compatibility issues
3. **Installation Errors** - Disk space, permissions, network
4. **Runtime Errors** - GPU not detected, CUDA errors

### Error Output Format
```
✗ Error: Driver version too old

  Current: 520.10
  Required: 528.33+

Solution:
  Update your Windows NVIDIA driver:

  Option 1: GeForce Experience
    1. Open GeForce Experience
    2. Go to Drivers tab
    3. Download latest driver

  Option 2: Manual download
    https://www.nvidia.com/Download/index.aspx

  After updating:
    1. Restart Windows
    2. Run: wsl --shutdown
    3. Run: cuda-setup check
```

## Configuration File

**Location:** `~/.config/cuda-setup/config.toml`

```toml
[general]
auto_fix_nvidia_smi = true
verbose = false
interactive = true

[installation]
skip_checks = false
update_shell_profile = true
backup_configs = true

[output]
color = true
unicode = true
```

## Installation & Distribution

### PyPI Package
```bash
# Install from PyPI
pip install cuda-setup-wsl2

# Or using pipx (recommended)
pipx install cuda-setup-wsl2

# Development install
pip install -e .
```

### Entry Point
```bash
cuda-setup --version
cuda-setup --help
cuda-setup doctor
```

## Backward Compatibility

Keep existing bash scripts for users who prefer them:
- `install-cuda.sh` → wraps `cuda-setup install --auto`
- `check-driver.sh` → wraps `cuda-setup check`
- `fix-nvidia-smi.sh` → wraps `cuda-setup fix`
- `test-cuda.sh` → wraps `cuda-setup test`

## Benefits Over Bash Scripts

1. **Better Error Handling** - Structured exceptions, detailed messages
2. **Rich Output** - Colors, tables, progress bars, spinners
3. **Type Safety** - Input validation, configuration schemas
4. **Testing** - Unit tests, integration tests
5. **Extensibility** - Plugin architecture, custom commands
6. **Cross-Platform** - Easier to extend beyond WSL2
7. **Documentation** - Auto-generated help, docstrings
8. **Distribution** - PyPI package, versioning
9. **Maintenance** - Cleaner code, better structure
10. **Interactive Features** - Prompts, wizards, menus

## Implementation Priority

**Phase 1: Core CLI** (MVP)
- [ ] Project setup (pyproject.toml, structure)
- [ ] Core utilities (driver check, nvidia-smi fix)
- [ ] Basic commands (check, fix, info)
- [ ] Rich output integration

**Phase 2: Installation**
- [ ] Install command with progress
- [ ] Environment configuration
- [ ] Pre/post install checks

**Phase 3: Advanced Features**
- [ ] Doctor command with full diagnostics
- [ ] Interactive wizard mode
- [ ] Configuration file support
- [ ] JSON output for automation

**Phase 4: Testing & Distribution**
- [ ] Unit tests
- [ ] Integration tests
- [ ] PyPI packaging
- [ ] Documentation

## Success Metrics

- ✓ Single command for all operations
- ✓ Clear, actionable error messages
- ✓ Auto-fix common issues
- ✓ Beautiful, informative output
- ✓ Works in both interactive and automated modes
- ✓ Easy to install and update
- ✓ Comprehensive documentation
