# AI Agent Mode Documentation

## 📋 Quick Reference

**Enable AI Agent Mode:**
```bash
# Method 1: Environment Variable
DOTFILES_AGENT_MODE=1 claude-code

# Method 2: Wrapper Script
./scripts/claude-code-wrapper.sh

# Method 3: Profile Mode
export DOTFILES_PROFILE=agent

# Method 4: Per-Project (.envrc)
echo "export DOTFILES_AGENT_MODE=1" >> .envrc
```

**Test Detection:**
```bash
./scripts/dotfiles-test-context.sh
```

---

## 🎯 Overview

AI Agent Mode is an intelligent context detection system that ensures compatibility between modern CLI tools and AI coding assistants. It automatically switches between human-friendly modern tools and POSIX-compliant commands based on the execution context.

### What is AI Agent Mode?

AI Agent Mode is a runtime feature that:
- ✅ Detects when AI agents are executing commands
- ✅ Automatically switches aliases to POSIX-compliant versions
- ✅ Prevents modern tool syntax from breaking AI workflows
- ✅ Maintains full functionality for human users

### Why It's Needed

Modern developer environments use enhanced CLI tools that provide better user experiences:
- `bat` instead of `cat` (syntax highlighting, line numbers)
- `eza` instead of `ls` (better formatting, Git integration)
- `ripgrep` instead of `grep` (faster, smarter patterns)
- `fd` instead of `find` (intuitive syntax, faster)

However, AI agents expect standard POSIX commands and their output formats. When modern tools are aliased to replace standard commands, AI agents fail due to:
- Different command-line syntax
- Altered output formats
- Additional decorations (colors, icons)
- Missing standard options

### How It Works

The system employs:
1. **Automatic Detection**: Multiple heuristics identify AI agent contexts
2. **Smart Aliases**: Commands adapt based on detected context
3. **Runtime Switching**: No restart required, works immediately
4. **Shell Integration**: Consistent behavior across Bash, Zsh, and Elvish

---

## ⚠️ Problem Statement

### The Compatibility Challenge

AI coding assistants like Claude Code, GitHub Copilot, and VSCode Agent Mode execute shell commands expecting POSIX-standard behavior. When modern CLI replacements are aliased, failures occur:

#### Example: `cat` vs `bat`
```bash
# Human expects (with bat):
$ cat file.py
───────┬────────────────────────────────
       │ File: file.py
───────┼────────────────────────────────
   1   │ def hello():
   2   │     print("Hello World")
───────┴────────────────────────────────

# AI agent expects (standard cat):
$ cat file.py
def hello():
    print("Hello World")
```

#### Example: `ls` vs `eza`
```bash
# Human expects (with eza):
$ ls
drwxr-xr-x  - user 2024-01-15 10:30  docs
.rw-r--r-- 1.2k user 2024-01-15 10:25  README.md
.rw-r--r-- 543 user 2024-01-15 09:15  config.yaml

# AI agent expects (standard ls):
$ ls
docs  README.md  config.yaml
```

#### Example: `grep` vs `ripgrep`
```bash
# Human command (ripgrep):
$ grep "pattern" --type py

# AI agent command (standard grep):
$ grep -r "pattern" --include="*.py" .
```

### Common Failure Scenarios

1. **File Reading**: AI tries `cat -n file.txt`, bat doesn't support `-n`
2. **Directory Listing**: AI parses `ls -la` output, eza format differs
3. **Pattern Searching**: AI uses `grep -E`, ripgrep syntax incompatible
4. **File Finding**: AI uses `find -type f -name`, fd syntax completely different

---

## 🔧 Solution Design

### Architecture Overview

```
┌─────────────────────────────────────┐
│         Shell Startup               │
│              ↓                      │
│    Load Agent Detection Library     │
│    (lib/agent-detection.sh)         │
│              ↓                      │
│     Check Multiple Triggers         │
│              ↓                      │
│   ┌────────────────────┐           │
│   │  AI Agent Mode?    │           │
│   └──────┬─────────────┘           │
│          ↓                          │
│    Yes ──┴── No                    │
│     ↓         ↓                    │
│  POSIX     Modern                  │
│  Commands  Tools                   │
└─────────────────────────────────────┘
```

### Smart Alias System

Aliases are dynamically resolved at runtime:
```bash
# Alias definition (simplified)
alias cat='_smart_cat'
alias ls='_smart_ls'

# Smart wrapper functions
_smart_cat() {
    if _is_ai_agent; then
        command cat "$@"
    else
        bat "$@"
    fi
}
```

### Multiple Activation Methods

1. **Automatic Detection**: Heuristics identify AI contexts
2. **Explicit Environment**: Set `DOTFILES_AGENT_MODE=1`
3. **Profile Selection**: Use `DOTFILES_PROFILE=agent`
4. **Wrapper Scripts**: Pre-configured launch scripts

### Supported Shells

- **Bash**: Full support via `lib/agent-detection.sh`
- **Zsh**: Full support with Zsh-specific optimizations
- **Elvish**: Native implementation in `elvish/lib/agent-detection.elv`

---

## 🔍 Detection Triggers

The system uses multiple methods to detect AI agent contexts:

### 1. Environment Variables

| Variable | Trigger Value | Description |
|----------|--------------|-------------|
| `DOTFILES_AGENT_MODE` | `1`, `true`, `yes` | Explicit agent mode |
| `DOTFILES_PROFILE` | `agent` | Agent profile selected |
| `TERM` | `dumb` or unset | Non-interactive terminal |
| `CI` | Any value | CI/CD environment |
| `AUTOMATION` | Any value | Automation context |
| `GITHUB_ACTIONS` | `true` | GitHub Actions runner |
| `GITLAB_CI` | Any value | GitLab CI pipeline |
| `JENKINS_HOME` | Any value | Jenkins build |
| `BUILD_ID` | Any value | Generic build system |
| `BUILDKITE` | `true` | Buildkite CI |
| `CIRCLECI` | `true` | CircleCI build |
| `TRAVIS` | `true` | Travis CI build |
| `CODEBUILD_BUILD_ID` | Any value | AWS CodeBuild |
| `AUTOMATION_CONTEXT` | Any value | Custom automation |

### 2. Parent Process Detection

Checks if parent process name contains:
- `code` (VSCode)
- `claude` (Claude Code)
- `cursor` (Cursor AI)
- `agent` (Generic agents)
- `copilot` (GitHub Copilot)
- `aide` (AI Development Environment)
- `windsurf` (Windsurf IDE)

### 3. Shell State Detection

- **Non-interactive shells**: `[[ ! -t 0 ]]` or `$-` doesn't contain 'i'
- **No TTY**: Terminal not attached
- **Dumb terminal**: `TERM=dumb` or undefined

### 4. SSH Detection

- `SSH_CLIENT` or `SSH_CONNECTION` set (remote sessions)
- Often combined with other heuristics

---

## 📖 Usage Guide

### Method 1: Environment Variable

Set the environment variable before running commands:

```bash
# Single command
DOTFILES_AGENT_MODE=1 git diff

# Session-wide
export DOTFILES_AGENT_MODE=1
claude-code

# In scripts
#!/bin/bash
export DOTFILES_AGENT_MODE=1
# Your automation here
```

### Method 2: Wrapper Scripts

Use pre-configured wrapper scripts:

```bash
# Claude Code wrapper
./scripts/claude-code-wrapper.sh

# VSCode Agent wrapper
./scripts/vscode-agent-wrapper.sh

# Generic agent shell
./scripts/launch-agent-shell.sh
```

Example wrapper script:
```bash
#!/bin/bash
# scripts/claude-code-wrapper.sh
export DOTFILES_AGENT_MODE=1
export DOTFILES_PROFILE=agent
exec claude-code "$@"
```

### Method 3: Explicit Profile

Set the profile to agent mode:

```bash
# Temporarily
export DOTFILES_PROFILE=agent

# Permanently (in .bashrc/.zshrc)
echo 'export DOTFILES_PROFILE=agent' >> ~/.bashrc
```

### Method 4: Per-Project Configuration

Using `direnv` for project-specific settings:

```bash
# Install direnv (if not already)
nix-env -iA nixpkgs.direnv

# In project root
echo 'export DOTFILES_AGENT_MODE=1' >> .envrc
direnv allow

# Now the project always uses agent mode
cd /path/to/project  # Automatically activates
```

---

## 🧪 Testing

### Testing Detection

Run the test script to verify detection:

```bash
# Test current context
./scripts/dotfiles-test-context.sh

# Example output (human mode):
===================================
Dotfiles Context Detection Test
===================================
DOTFILES_PROFILE: full
DOTFILES_AGENT_MODE: (not set)
Interactive shell: yes
Terminal attached: yes
TERM: xterm-256color
Parent process: bash
CI environment: no

RESULT: HUMAN MODE (Modern Tools)
===================================

# Example output (agent mode):
===================================
Dotfiles Context Detection Test
===================================
DOTFILES_PROFILE: agent
DOTFILES_AGENT_MODE: 1
Interactive shell: no
Terminal attached: no
TERM: dumb
Parent process: claude-code
CI environment: no

RESULT: AGENT MODE (POSIX Tools)
===================================
```

### Verifying Aliases

Test individual command resolution:

```bash
# Check which command is used
type cat
type ls
type grep

# Test actual execution
cat --version 2>/dev/null || echo "Using POSIX cat"
ls --version 2>/dev/null || echo "Using POSIX ls"
```

### Integration Testing

```bash
# Create test script
cat > test-agent.sh << 'EOF'
#!/bin/bash
export DOTFILES_AGENT_MODE=1
source ~/.bashrc

echo "Testing cat:"
echo "Hello" | cat

echo "Testing ls:"
ls /tmp

echo "Testing grep:"
echo "test line" | grep "test"
EOF

chmod +x test-agent.sh
./test-agent.sh
```

---

## 🎛️ Profile Modes

The system supports five profile modes, each optimized for different use cases:

### 1. **auto** (Default)
- **Description**: Intelligent automatic detection
- **Behavior**: Switches based on context detection
- **Use Case**: General purpose, works everywhere
- **Commands**: Adapts dynamically

```bash
export DOTFILES_PROFILE=auto  # Or just unset
```

### 2. **fast**
- **Description**: Minimal startup time
- **Behavior**: Skip heavy initializations
- **Use Case**: Quick scripts, automation
- **Commands**: Basic set only

```bash
export DOTFILES_PROFILE=fast
```

### 3. **balanced**
- **Description**: Optimized performance/features
- **Behavior**: Modern tools with lighter config
- **Use Case**: Daily development
- **Commands**: Modern tools, selective features

```bash
export DOTFILES_PROFILE=balanced
```

### 4. **full**
- **Description**: All features enabled
- **Behavior**: Complete modern environment
- **Use Case**: Interactive development
- **Commands**: All modern tools, all features
- **AI-Aware**: Switches to POSIX when AI detected

```bash
export DOTFILES_PROFILE=full
```

### 5. **agent**
- **Description**: POSIX-only commands
- **Behavior**: Force standard tools
- **Use Case**: AI agents, automation
- **Commands**: Only POSIX-compliant

```bash
export DOTFILES_PROFILE=agent
```

---

## 🔄 Affected Commands

### Smart Aliases (Context-Aware)

These commands switch between modern and POSIX versions:

| Alias | Human Mode (Modern) | Agent Mode (POSIX) | Notes |
|-------|-------------------|-------------------|-------|
| `cat` | `bat` | `/usr/bin/cat` | Syntax highlighting vs plain |
| `ls` | `eza` | `/usr/bin/ls` | Enhanced listing vs standard |
| `ll` | `eza -l` | `ls -l` | Long format |
| `la` | `eza -la` | `ls -la` | All files, long |
| `l` | `eza -lah` | `ls -lah` | Human-readable |
| `tree` | `eza --tree` | `/usr/bin/tree` | Tree view |
| `grep` | `rg` (ripgrep) | `/usr/bin/grep` | Pattern search |
| `find` | `fd` | `/usr/bin/find` | File finding |
| `sed` | `sd` (if enabled) | `/usr/bin/sed` | Stream editing |
| `ps` | `procs` (if enabled) | `/usr/bin/ps` | Process list |
| `top` | `btop` (if enabled) | `/usr/bin/top` | Process monitor |
| `df` | `duf` (if enabled) | `/usr/bin/df` | Disk usage |
| `du` | `dust` (if enabled) | `/usr/bin/du` | Directory usage |

### Safe Aliases (Unchanged)

These remain consistent regardless of mode:

| Category | Commands | Reason |
|----------|----------|---------|
| **Git** | `g`, `ga`, `gc`, `gp`, `gst` | Consistent Git workflow |
| **Docker** | `d`, `dc`, `dps`, `dex` | Container operations |
| **Kubernetes** | `k`, `kgp`, `kga`, `kdp` | K8s management |
| **Navigation** | `cd`, `pwd`, `pushd`, `popd` | POSIX standard |
| **Editors** | `vim`, `nano`, `code` | Direct executables |
| **Nix** | `nix`, `nixos-rebuild`, `home-manager` | Package management |
| **System** | `sudo`, `chmod`, `chown`, `mkdir` | Core utilities |

### Custom Functions

Smart functions that adapt behavior:

```bash
# mkcd - Make directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# extract - Universal archive extractor
extract() {
    # Works the same in both modes
    case "$1" in
        *.tar.gz) tar xzf "$1" ;;
        *.tar.bz2) tar xjf "$1" ;;
        *.zip) unzip "$1" ;;
        *) echo "Unknown format" ;;
    esac
}
```

---

## ⚙️ Configuration

### File Structure

```
dotfiles-public/
├── lib/
│   └── agent-detection.sh      # Core detection logic
├── modules/
│   ├── shells/
│   │   ├── bash.nix           # Bash configuration
│   │   ├── zsh.nix            # Zsh configuration
│   │   └── elvish.nix         # Elvish configuration
│   └── user-config.nix        # User preferences
├── elvish/
│   └── lib/
│       └── agent-detection.elv # Elvish detection
├── scripts/
│   ├── claude-code-wrapper.sh  # Claude wrapper
│   ├── vscode-agent-wrapper.sh # VSCode wrapper
│   ├── launch-agent-shell.sh   # Generic wrapper
│   └── dotfiles-test-context.sh # Testing utility
└── home.nix                    # Main configuration
```

### Core Detection Logic

Location: `lib/agent-detection.sh`

```bash
# Simplified detection function
_is_ai_agent() {
    # Check explicit mode
    [[ "$DOTFILES_AGENT_MODE" == "1" ]] && return 0

    # Check profile
    [[ "$DOTFILES_PROFILE" == "agent" ]] && return 0

    # Check if non-interactive
    [[ ! -t 0 ]] && return 0

    # Check TERM
    [[ "$TERM" == "dumb" ]] && return 0

    # Check parent process
    local parent_name=$(ps -o comm= -p $PPID 2>/dev/null)
    case "$parent_name" in
        *code*|*claude*|*cursor*|*agent*|*copilot*)
            return 0 ;;
    esac

    # Check CI environment
    [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]] && return 0

    return 1
}
```

### Shell-Specific Configuration

#### Bash (`modules/shells/bash.nix`)
```nix
{
  programs.bash = {
    enable = true;
    initExtra = ''
      source ${./lib/agent-detection.sh}

      # Smart aliases
      alias cat='_smart_cat'
      alias ls='_smart_ls'
    '';
  };
}
```

#### Zsh (`modules/shells/zsh.nix`)
```nix
{
  programs.zsh = {
    enable = true;
    initExtra = ''
      source ${./lib/agent-detection.sh}

      # Zsh-specific optimizations
      setopt no_global_rcs  # Faster startup
    '';
  };
}
```

#### Elvish (`modules/shells/elvish.nix`)
```elvish
# elvish/lib/agent-detection.elv
fn is-ai-agent {
    if (has-env DOTFILES_AGENT_MODE) {
        put $true
    } elif (eq $E:TERM dumb) {
        put $true
    } else {
        put $false
    }
}
```

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Aliases Still Using Modern Tools

**Problem**: Commands still use `bat`, `eza`, etc. in agent mode

**Solutions**:
```bash
# Verify detection
echo $DOTFILES_AGENT_MODE
./scripts/dotfiles-test-context.sh

# Force reload shell config
exec $SHELL

# Check alias resolution
type cat
which cat

# Debug function
alias cat
```

#### 2. Detection Not Working

**Problem**: Agent mode not automatically detected

**Solutions**:
```bash
# Check parent process
ps -o comm= -p $PPID

# Verify environment
env | grep -E "DOTFILES|TERM|CI"

# Test interactivity
[[ -t 0 ]] && echo "Interactive" || echo "Non-interactive"

# Force explicit mode
export DOTFILES_AGENT_MODE=1
```

#### 3. How to Force Agent Mode

```bash
# Method 1: Environment variable
export DOTFILES_AGENT_MODE=1

# Method 2: Profile
export DOTFILES_PROFILE=agent

# Method 3: In script shebang
#!/usr/bin/env bash
export DOTFILES_AGENT_MODE=1

# Method 4: Wrapper function
run_as_agent() {
    DOTFILES_AGENT_MODE=1 "$@"
}
run_as_agent my-script.sh
```

#### 4. How to Force Human Mode

```bash
# Explicitly disable agent mode
export DOTFILES_AGENT_MODE=0
export DOTFILES_PROFILE=full

# Or unset the variables
unset DOTFILES_AGENT_MODE
unset DOTFILES_PROFILE
```

#### 5. Debugging Commands

```bash
# Enable debug output
export DEBUG_AGENT_DETECTION=1

# Trace alias resolution
set -x
cat /etc/passwd
set +x

# Check specific command
command -v cat
type -a cat
alias | grep cat

# Test in isolated environment
env -i HOME=$HOME TERM=$TERM bash --norc
source ~/.bashrc
type cat
```

### Error Messages and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `bat: unrecognized option '--n'` | AI using cat flags with bat | Enable agent mode |
| `eza: option '--d' not found` | AI using ls flags with eza | Set `DOTFILES_AGENT_MODE=1` |
| `rg: unrecognized flag '-E'` | grep regex flag incompatible | Use POSIX grep |
| `fd: invalid option '-type'` | find syntax with fd | Switch to standard find |

---

## 🚀 Advanced Usage

### Custom Detection Logic

Add custom detection in `~/.bashrc.local`:

```bash
# Custom detection for specific tools
_custom_ai_detection() {
    # Check for custom AI tool
    if pgrep -f "my-ai-tool" > /dev/null; then
        export DOTFILES_AGENT_MODE=1
    fi

    # Check for specific project
    if [[ "$PWD" == */ai-project/* ]]; then
        export DOTFILES_AGENT_MODE=1
    fi
}

# Run on shell startup
_custom_ai_detection
```

### Adding New Smart Aliases

Create smart wrappers for additional commands:

```bash
# In ~/.bashrc.local
_smart_diff() {
    if _is_ai_agent; then
        command diff "$@"
    else
        delta "$@"  # or diff-so-fancy
    fi
}
alias diff='_smart_diff'

_smart_hexdump() {
    if _is_ai_agent; then
        command hexdump "$@"
    else
        hexyl "$@"  # Modern hex viewer
    fi
}
alias hexdump='_smart_hexdump'
```

### Excluding Specific Commands

Prevent certain commands from switching:

```bash
# Always use modern tool
alias bat='command bat'  # Override smart alias

# Always use POSIX tool
alias grep='command grep'  # Force standard grep
```

### Integration with CI/CD

#### GitHub Actions
```yaml
# .github/workflows/test.yml
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      DOTFILES_AGENT_MODE: 1  # Ensure POSIX tools
    steps:
      - uses: actions/checkout@v2
      - run: ./test.sh
```

#### GitLab CI
```yaml
# .gitlab-ci.yml
test:
  script:
    - export DOTFILES_AGENT_MODE=1
    - ./test.sh
  variables:
    DOTFILES_PROFILE: agent
```

#### Docker
```dockerfile
# Dockerfile
FROM ubuntu:latest
ENV DOTFILES_AGENT_MODE=1
ENV DOTFILES_PROFILE=agent
COPY . /app
RUN /app/test.sh
```

### Performance Optimization

```bash
# Skip detection for known contexts
if [[ -n "$GITHUB_ACTIONS" ]]; then
    export DOTFILES_AGENT_MODE=1
    # Skip further detection
fi

# Cache detection result
if [[ -z "$_AGENT_MODE_CACHED" ]]; then
    if _is_ai_agent; then
        export _AGENT_MODE_CACHED=1
    else
        export _AGENT_MODE_CACHED=0
    fi
fi
```

---

## 🏗️ Architecture

### Detection Flow

```
Shell Startup
     │
     ├─→ Source shell config (bashrc/zshrc)
     │
     ├─→ Load agent-detection.sh
     │
     ├─→ Run detection checks (in order):
     │   ├─→ 1. Check DOTFILES_AGENT_MODE
     │   ├─→ 2. Check DOTFILES_PROFILE
     │   ├─→ 3. Check interactivity
     │   ├─→ 4. Check TERM variable
     │   ├─→ 5. Check parent process
     │   └─→ 6. Check CI variables
     │
     ├─→ Set internal flags
     │
     └─→ Configure aliases based on mode
```

### Runtime vs Load-time

- **Load-time**: Initial detection happens once at shell startup
- **Runtime**: Each command checks current state
- **Caching**: Results cached for session performance
- **Dynamic**: Can switch modes without restart

### Performance Impact

Minimal overhead:
- **Detection**: ~1-2ms at startup
- **Alias resolution**: <0.1ms per command
- **Memory**: ~50KB for detection functions
- **CPU**: Negligible after initial detection

### Implementation Details

#### Bash/Zsh Implementation
```bash
# Function wrapping for dynamic behavior
_smart_wrapper() {
    local cmd=$1
    local modern=$2
    shift 2

    if _is_ai_agent; then
        command "$cmd" "$@"
    else
        "$modern" "$@"
    fi
}

# Alias to wrapper
alias cat='_smart_wrapper cat bat'
```

#### Elvish Implementation
```elvish
# Elvish uses different syntax
fn smart-cat [@args]{
    if (is-ai-agent) {
        e:cat $@args
    } else {
        bat $@args
    }
}
edit:add-var cat~ $smart-cat~
```

---

## 📚 See Also

- [Home Manager Documentation](https://nix-community.github.io/home-manager/)
- [Modern Unix Tools](https://github.com/ibraheemdev/modern-unix)
- [POSIX Shell Standard](https://pubs.opengroup.org/onlinepubs/9699919799/)
- [Direnv Documentation](https://direnv.net/)

### Related Configuration Files
- `home.nix` - Main Home Manager configuration
- `flake.nix` - Nix flake definition
- `lib/agent-detection.sh` - Core detection library
- `modules/shells/*.nix` - Shell configurations

### Related Scripts
- `apply.sh` - Setup and configuration script
- `scripts/dotfiles-test-context.sh` - Detection testing
- `scripts/*-wrapper.sh` - AI agent wrappers

---

## 📝 Summary

AI Agent Mode provides seamless compatibility between modern CLI tools and AI coding assistants through:

- **Automatic detection** of AI agent contexts
- **Smart aliases** that adapt to execution environment
- **Multiple activation methods** for flexibility
- **Cross-shell support** (Bash, Zsh, Elvish)
- **Zero configuration** for most use cases
- **Full control** when explicit behavior needed

The system ensures AI agents get POSIX-compliant commands while preserving modern tools for human users, creating a best-of-both-worlds development environment.

For questions or issues, check the troubleshooting section or test detection with:
```bash
./scripts/dotfiles-test-context.sh
```