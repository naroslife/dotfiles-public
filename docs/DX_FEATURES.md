# Developer Experience (DX) Features

Comprehensive guide to all developer experience improvements in the dotfiles.

## Table of Contents

- [Overview](#overview)
- [Central CLI Interface](#central-cli-interface)
- [AI Agent Detection](#ai-agent-detection)
- [Diagnostic Tools](#diagnostic-tools)
- [Interactive Tool Pickers](#interactive-tool-pickers)
- [Command Examples Database](#command-examples-database)
- [Configuration Management](#configuration-management)
- [Enhanced Error Handling](#enhanced-error-handling)
- [Session Management](#session-management)

---

## Overview

The dotfiles include 10 major DX improvements designed to enhance productivity, discoverability, and user experience:

1. **Central CLI Interface** - Unified command system
2. **AI Agent Detection** - Prevents modern tool incompatibilities
3. **Health Checks** - Environment validation
4. **Performance Profiling** - Startup time analysis
5. **Update Checker** - Smart update notifications
6. **Configuration Validator** - Consistency checking
7. **Interactive Pickers** - FZF-based command discovery
8. **Examples Database** - Curated command references
9. **Enhanced Errors** - Context-aware suggestions
10. **Session Restoration** - Tmux auto-save/restore

---

## Central CLI Interface

### Purpose
Single entry point for all dotfiles operations, replacing scattered scripts and commands.

### Command: `dotfiles`

Located: `scripts/dotfiles`

### Available Commands

#### Information & Help
```bash
dotfiles help              # Show usage information
dotfiles version           # Version and location
dotfiles aliases           # List all aliases with descriptions
dotfiles functions         # List available functions
dotfiles keybindings       # Show shell keybindings
dotfiles tools             # List installed tools
```

#### Diagnostics
```bash
dotfiles doctor            # Comprehensive health check
dotfiles update            # Check for updates
dotfiles test-context      # Test AI agent detection
```

#### Configuration
```bash
dotfiles apply             # Apply configuration changes
dotfiles profile           # Show/set profile
dotfiles profile full      # Enable all features
```

#### Interactive Menus
```bash
dotfiles git               # Git workflow picker
dotfiles docker            # Docker operations picker
dotfiles nix               # Nix operations picker
dotfiles examples git      # Show git examples
```

### Usage Examples

```bash
# Quick health check
dotfiles doctor

# Find git commands
dotfiles examples git commit

# Interactive git menu
dotfiles git

# Check installed tools
dotfiles tools

# Set profile
dotfiles profile agent
```

### Integration

The CLI integrates with:
- `lib/common.sh` - Shared utilities
- `lib/agent-detection.sh` - Context detection
- All diagnostic scripts
- Interactive tool pickers
- Examples database

---

## AI Agent Detection

### Purpose
Automatically detect when commands are executed by AI agents (Claude Code, VSCode) and use POSIX-compliant tools instead of modern alternatives.

### Problem Solved
Modern tools like `bat`, `eza`, `rg`, `fd` have different syntax than traditional `cat`, `ls`, `grep`, `find`. AI agents expect POSIX tools and fail when encountering modern alternatives.

### Detection Methods (7 triggers)

1. **Explicit Mode**: `DOTFILES_AGENT_MODE=1`
2. **Non-Interactive Shell**: Shell lacks interactive flag
3. **Dumb Terminal**: `TERM=dumb` or unset
4. **Parent Process**: Detects code, claude, cursor, copilot
5. **CI Environment**: `CI`, `GITHUB_ACTIONS`, `JENKINS_HOME`
6. **SSH Non-TTY**: SSH sessions without terminal
7. **Script Context**: Running inside scripts

### Smart Aliases

| Alias | Human Mode | Agent Mode |
|-------|------------|------------|
| `cat` | `bat --paging=never --style=plain` | `cat` |
| `ls` | `eza` | `ls` |
| `ll` | `eza -l` | `ls -l` |
| `la` | `eza -la` | `ls -la` |
| `grep` | `rg` | `grep` |
| `find` | `fd` | `find` |

### How to Use

**Automatic (Recommended):**
System auto-detects context - no action needed!

**Explicit Mode:**
```bash
# For Claude Code
DOTFILES_AGENT_MODE=1 claude-code

# Or use wrapper
./scripts/claude-code-wrapper.sh
```

**Per-Project:**
```bash
# Create .envrc
echo "export DOTFILES_AGENT_MODE=1" > .envrc
direnv allow
```

**Testing:**
```bash
# Check current context
dotfiles test-context

# Test agent mode
DOTFILES_AGENT_MODE=1 dotfiles test-context
```

### Supported Shells
- ✅ Bash (via bash.nix)
- ✅ Zsh (via zsh.nix)
- ✅ Elvish (via rc.elv)

### Documentation
See [AI_AGENT_MODE.md](AI_AGENT_MODE.md) for complete details.

---

## Diagnostic Tools

### 1. Health Check (`dotfiles doctor`)

**Script:** `scripts/dotfiles-doctor.sh`
**Size:** 358 lines
**Runtime:** ~2-5 seconds

#### Checks Performed (11 total)

1. **Nix Installation** - Version and path
2. **Flakes Support** - Experimental features enabled
3. **Home Manager** - Availability and version
4. **Required Tools** - 20+ essential tools
5. **Git Configuration** - user.name and user.email
6. **WSL Optimizations** - WSL-specific settings (if applicable)
7. **Shell Performance** - Startup time < 300ms
8. **Disk Space** - Available space > 5GB
9. **Network Connectivity** - Can reach cache.nixos.org
10. **Environment Variables** - Critical paths set
11. **Permissions** - File permissions correct

#### Output Format

```
=== Dotfiles Health Check ===

✓ Nix installed (version 2.18.1)
✓ Flakes enabled
✓ Home Manager available (version 23.11)
✓ Git configured (user@example.com)
⚠ Shell startup slow (450ms, recommended <300ms)
✗ Low disk space (2.3GB free, recommended >5GB)

Overall Status: MOSTLY HEALTHY
Passed: 9/11 checks

Recommendations:
  1. Run: nix-collect-garbage -d
  2. Optimize shell startup (see PERFORMANCE.md)
```

#### Exit Codes
- `0` - All checks passed or warnings only
- `1` - One or more checks failed

#### Usage

```bash
# Run health check
dotfiles doctor

# Silent mode (exit code only)
dotfiles doctor > /dev/null 2>&1 && echo "Healthy"
```

---

### 2. Performance Profiler (`dotfiles-profiler.sh`)

**Script:** `scripts/dotfiles-profiler.sh`
**Size:** 499 lines
**Runtime:** ~3-10 seconds (measures multiple iterations)

#### Features

- Measures shell startup time
- Component breakdown analysis
- Performance status indicators
- Optimization recommendations
- Support for bash and zsh

#### Output Format

```
=== Shell Startup Profile (bash) ===

Component                 Time       % of Total
────────────────────────────────────────────────
Nix profile               45ms        30%
Home Manager vars         20ms        13%
Agent detection           5ms          3%
Carapace (lazy)           2ms          1%
Starship init             15ms        10%
Atuin init                20ms        13%
Custom functions          8ms          5%
Other                     35ms        23%
────────────────────────────────────────────────
TOTAL                     150ms       100%

Status: ✓ Excellent (under 200ms)

Recommendations:
  • Your shell startup is excellent! No optimization needed.
```

#### Performance Tiers

| Status | Time | Action |
|--------|------|--------|
| ✓ Excellent | < 200ms | Perfect! |
| ✓ Good | 200-300ms | Great for most uses |
| ⚠ Acceptable | 300-500ms | Consider optimizing |
| ⚠ Slow | 500-1000ms | Optimization recommended |
| ✗ Very Slow | > 1000ms | Needs attention |

#### Usage

```bash
# Profile current shell
./scripts/dotfiles-profiler.sh

# Profile specific shell
./scripts/dotfiles-profiler.sh --shell bash

# More iterations for accuracy
./scripts/dotfiles-profiler.sh --iterations 10
```

---

### 3. Update Checker (`dotfiles-update-checker.sh`)

**Script:** `scripts/dotfiles-update-checker.sh`
**Size:** 435 lines
**Features:** Smart caching, auto-pull, verbose mode

#### Features

- **Smart Caching**: Results cached for 24 hours
- **Commit Analysis**: Shows commit count and messages
- **Conventional Commits**: Color-coded by type (feat, fix, docs)
- **Auto-Pull**: Optional automatic updates
- **Ahead/Behind**: Detects unpushed commits
- **Network-Aware**: Handles offline scenarios gracefully

#### Output Format

```
📦 Dotfiles Update Available
   3 new commits since last update
   Last checked: 2 hours ago

Recent changes:
  • feat: Add AI agent detection
  • fix: Shell startup performance
  • docs: Update README

Run: dotfiles update --pull
```

#### Options

```bash
# Check for updates (uses cache)
dotfiles update

# Force fresh check
dotfiles update --force

# Auto-pull if available
dotfiles update --pull

# Show detailed commit messages
dotfiles update --verbose

# Silent mode (exit code only)
dotfiles update --quiet
```

#### Exit Codes
- `0` - Up to date or successfully pulled
- `1` - Updates available (not pulled)

---

## Interactive Tool Pickers

### Purpose
Discover and execute commands using fuzzy finding (fzf), reducing the need to memorize syntax.

### Available Pickers

#### 1. Git Helper (`dotfiles git`)

**Script:** `scripts/dotfiles-git-helper.sh`
**Size:** 244 lines
**Operations:** 20+

**Features:**
- Status and diff views
- Commit workflows
- Branch management
- Push/pull operations
- Stash management
- Reset operations
- Git blame
- Interactive branch selection

**Usage:**
```bash
dotfiles git
# Select operation from menu
# Execute with guided prompts
```

#### 2. Docker Helper (`dotfiles docker`)

**Script:** `scripts/dotfiles-docker-helper.sh`
**Size:** 264 lines
**Operations:** 15+

**Features:**
- Container operations (start, stop, restart, remove)
- Image management
- Volume management
- Docker Compose integration
- Log viewing
- System cleanup
- Stats monitoring

**Usage:**
```bash
dotfiles docker
# Select operation
# Choose container/image interactively
```

#### 3. Nix Helper (`dotfiles nix`)

**Script:** `scripts/dotfiles-nix-helper.sh`
**Size:** 301 lines
**Operations:** 12+

**Features:**
- Configuration management
- Package search
- Garbage collection
- Generation management (list, rollback, diff)
- Development shells
- Build operations
- Store optimization

**Usage:**
```bash
dotfiles nix
# Select operation
# Execute with appropriate context
```

### Common Features

All pickers include:
- **FZF Integration** - Fuzzy finding with preview
- **Error Handling** - Graceful failures with suggestions
- **Safe Operations** - Confirmations for destructive actions
- **Context Awareness** - Validates prerequisites (git repo, docker daemon)
- **Consistent UX** - Same patterns across all pickers

---

## Command Examples Database

### Purpose
Curated, searchable examples for common development tools.

### Available Tools (5)

| Tool | Sections | Lines | Topics |
|------|----------|-------|--------|
| **git** | 80 | 242 | Version control workflows |
| **docker** | 119 | 361 | Container management |
| **nix** | 128 | 423 | Package manager, flakes |
| **bash** | 144 | 564 | Scripting patterns |
| **tmux** | 142 | 497 | Terminal multiplexer |

**Total:** 613 sections, 2,087 lines of curated examples

### Features

1. **Display Examples**: Show all examples for a tool
2. **Search & Filter**: Find specific topics
3. **Syntax Highlighting**: Colored output via bat
4. **Fallback System**: Auto-fallback to tldr/cheat
5. **FZF Browsing**: Optional interactive mode

### Usage

```bash
# List available tools
dotfiles examples --list

# Show all examples
dotfiles examples git
dotfiles examples docker
dotfiles examples nix

# Search within examples
dotfiles examples git commit      # Find commit-related
dotfiles examples docker build    # Find build examples
dotfiles examples bash loop       # Find loop patterns

# Interactive browsing (requires fzf)
dotfiles examples --fzf

# Get help
dotfiles examples --help
```

### Example Content Structure

Each file organized by:
- Common Workflows
- Basic Operations
- Advanced Techniques
- Best Practices
- Troubleshooting

### Adding Custom Examples

```bash
# Create your own
echo "# My Tool Examples" > examples/mytool.txt
echo "## Section" >> examples/mytool.txt
echo "command --flag value" >> examples/mytool.txt

# Use it
dotfiles examples mytool
```

See [EXAMPLES_GUIDE.md](EXAMPLES_GUIDE.md) for detailed documentation.

---

## Configuration Management

### Configuration Validator

**Script:** `lib/config-validator.sh`
**Size:** 537 lines
**Purpose:** Ensure consistency across shells

#### Features

1. **Alias Consistency** - Same aliases across bash/zsh/elvish
2. **Function Availability** - Core functions in all shells
3. **Smart Alias Coverage** - AI detection properly implemented
4. **Git Alias Coverage** - All shortcuts present
5. **WSL Validation** - WSL-specific aliases consistent

#### Usage

```bash
# Run validation
./lib/config-validator.sh

# Output shows:
# - Passed checks (green ✓)
# - Warnings (yellow ⚠)
# - Failures (red ✗)
# - Specific recommendations
```

#### Output Format

```
=== Configuration Consistency Check ===

Alias Consistency:
  ✓ cat     - implemented in all shells (smart)
  ✓ ll      - implemented in all shells (smart)
  ⚠ tree    - missing in elvish
  ✗ custom  - different implementation in zsh

Recommendations:
  1. Add 'tree' alias to elvish/rc.elv
  2. Standardize 'custom' across shells

Overall: 42/45 checks passed (93%)
```

### Profile Management

Switch between feature profiles:

```bash
# Show current profile
dotfiles profile

# Available profiles
auto     # Automatic detection (recommended)
fast     # Minimal features for speed
balanced # Optimized features
full     # All features, AI-aware
agent    # POSIX-only for AI agents

# Set profile
dotfiles profile full
export DOTFILES_PROFILE=full
```

---

## Enhanced Error Handling

### Purpose
Context-aware error messages with recovery suggestions.

### Implementation
Located: `lib/common.sh`

### Features

#### 1. Enhanced die() Function

```bash
# Before
die "Command failed"

# After (with suggestion)
die "Nix not found" 1 "Install Nix: curl ... | sh"
```

#### 2. suggest_fix() Function

Provides contextual suggestions for common errors:

```bash
suggest_fix "nix_not_found"
# Output: Install Nix: curl --proto '=https' ... | sh

suggest_fix "home_manager_fail"
# Output: Try: 1) nix flake update  2) Check nix.conf

suggest_fix "network_error"
# Output: Check connection: curl -I https://cache.nixos.org
```

#### 3. Common Error Patterns

- `nix_not_found` - Nix installation
- `git_not_found` - Git installation
- `home_manager_fail` - Home Manager issues
- `permission_denied` - Permission problems
- `network_error` - Connectivity issues
- `disk_space` - Insufficient space
- Default - Generic troubleshooting

### Usage

```bash
# In scripts
require_command nix "Install with: curl ... | sh" ||  die "Nix required" 1 "$(suggest_fix nix_not_found)"

# User sees helpful message automatically
```

---

## Session Management

### Tmux Enhancements

**Files:** `modules/dev/default.nix`, `scripts/tmux-session-manager.sh`
**Purpose:** Never lose work due to crashes

#### Features

1. **Auto-Save** - Every 5 minutes
2. **Auto-Restore** - On tmux start
3. **Vim/Neovim Sessions** - Preserved
4. **Pane Contents** - Captured
5. **Process Restoration** - ssh, psql, mysql, npm, yarn
6. **Manual Controls** - Keybindings for save/restore
7. **Status Indicator** - Shows save status
8. **CLI Management** - Session management script

#### Keybindings

| Binding | Action |
|---------|--------|
| `Ctrl-B Ctrl-S` | Manual save |
| `Ctrl-B Ctrl-R` | Manual restore |

#### CLI Commands

```bash
# Session manager
./scripts/tmux-session-manager.sh help
./scripts/tmux-session-manager.sh list    # List saves
./scripts/tmux-session-manager.sh save    # Manual save
./scripts/tmux-session-manager.sh restore # Manual restore
./scripts/tmux-session-manager.sh clean   # Clean old saves
```

#### Status Line

Shows continuum status and timestamp:
```
[Session] | [Last save: 2m ago] | [14:30]
```

---

## Integration Points

### How Features Work Together

```
User Command
    ↓
dotfiles CLI (central interface)
    ├→ Doctor (health check)
    │   ├→ lib/common.sh (logging)
    │   └→ Checks all tools
    ├→ Examples (database)
    │   ├→ examples/*.txt
    │   └→ Syntax highlighting via bat
    ├→ Git/Docker/Nix (pickers)
    │   ├→ FZF integration
    │   └→ lib/common.sh (utilities)
    ├→ Test-Context (AI detection)
    │   └→ lib/agent-detection.sh
    └→ Update (smart checker)
        └→ Caching + git operations
```

### Shell Integration

```
Shell Startup
    ├→ Nix profile
    ├→ Home Manager variables
    ├→ lib/agent-detection.sh (load)
    ├→ Smart aliases (define)
    ├→ Starship init
    ├→ Atuin init
    └→ Custom functions
```

---

## Performance Impact

### Measurements

| Feature | Startup Cost | Runtime Cost |
|---------|--------------|--------------|
| Agent Detection | ~5ms | < 1ms per command |
| Smart Aliases | ~2ms | < 1ms per alias |
| CLI Wrapper | 0ms | ~50ms to launch |
| Examples | 0ms | ~100ms to display |
| Doctor | 0ms | ~2-5s when run |
| Profiler | 0ms | ~3-10s when run |
| Update Checker | 0ms | ~1-3s when run |

**Total Startup Impact:** ~7ms (negligible)

---

## Best Practices

### 1. Regular Health Checks

```bash
# Weekly
dotfiles doctor

# After major changes
./apply.sh && dotfiles doctor
```

### 2. Monitor Performance

```bash
# Monthly
./scripts/dotfiles-profiler.sh

# If slow (>300ms), investigate
```

### 3. Stay Updated

```bash
# Check for updates
dotfiles update

# Apply updates
dotfiles update --pull
./apply.sh
```

### 4. Use Examples

```bash
# Before googling, check examples
dotfiles examples <tool>

# Add your own examples
echo "..." >> examples/custom.txt
```

### 5. Leverage Interactive Menus

```bash
# Instead of memorizing git commands
dotfiles git

# Instead of docker command syntax
dotfiles docker
```

---

## Troubleshooting

### Feature Not Working

```bash
# 1. Check health
dotfiles doctor

# 2. Check tool installation
dotfiles tools

# 3. Verify configuration
./lib/config-validator.sh

# 4. Check logs
LOG_LEVEL=4 dotfiles <command>
```

### Performance Issues

```bash
# Profile startup
./scripts/dotfiles-profiler.sh

# Follow recommendations
# Common fixes:
# - Disable unused features
# - Clear caches: nix-collect-garbage
# - Update: dotfiles update --pull
```

### AI Detection Issues

```bash
# Test detection
dotfiles test-context

# Force agent mode
DOTFILES_AGENT_MODE=1 <command>

# Check parent process
ps -p $PPID -o comm=
```

---

## Future Enhancements

Potential improvements:

1. **Web Dashboard** - Visual interface for all features
2. **More Examples** - kubectl, terraform, ansible
3. **Custom Themes** - Personalized color schemes
4. **Plugin System** - Extensible architecture
5. **AI Integration** - Natural language commands
6. **Sync Across Machines** - Configuration synchronization
7. **Performance Monitoring** - Long-term trending
8. **Auto-Optimization** - Automatic performance tuning

---

## Contributing

To add new features:

1. Create feature branch
2. Implement following existing patterns
3. Add documentation
4. Test thoroughly
5. Submit PR

See [ARCHITECTURE.md](ARCHITECTURE.md) for system design.

---

## Summary

The DX improvements transform the dotfiles from a collection of configurations into a comprehensive development platform with:

- **Discoverability** - Easy to find commands and features
- **Reliability** - Health checks and validation
- **Performance** - Monitoring and optimization
- **Compatibility** - AI agent support
- **Usability** - Interactive menus and examples
- **Maintainability** - Consistent configurations

All features work together to create a seamless, productive development environment.
