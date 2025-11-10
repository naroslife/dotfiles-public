# Quick Start Guide

Welcome to your new dotfiles! This guide will get you up and running in minutes.

## 🚀 Initial Setup

```bash
# 1. Clone the repository (if not already done)
git clone <your-repo-url> ~/dotfiles-public
cd ~/dotfiles-public

# 2. Run the setup script
./apply.sh

# The script will:
# - Install Nix (if needed)
# - Apply Home Manager configuration
# - Set up all shells (bash, zsh, elvish)
# - Configure modern CLI tools
# - Enable AI agent detection
```

## 📋 Essential Commands

### Central CLI Interface

The `dotfiles` command is your main interface:

```bash
dotfiles help              # Show all available commands
dotfiles version           # Show version and location
dotfiles doctor            # Run comprehensive health check
dotfiles aliases           # List all available aliases
dotfiles examples git      # Show git command examples
```

### Quick Health Check

```bash
# Check if everything is working
dotfiles doctor

# Expected output:
# ✓ Nix installed
# ✓ Flakes enabled
# ✓ Home Manager available
# ✓ All tools present
# ✓ Git configured
```

### Performance Check

```bash
# Measure shell startup time
./scripts/dotfiles-profiler.sh

# Goal: < 300ms for responsive shell
# Excellent: < 200ms
```

## 🎯 Key Features

### 1. Modern CLI Tools (AI-Aware)

Your dotfiles include modern replacements that automatically adapt:

| Old Tool | New Tool | When |
|----------|----------|------|
| `cat` | `bat` | Interactive shell |
| `cat` | `cat` | AI agents (Claude Code, VSCode) |
| `ls` | `eza` | Interactive shell |
| `ls` | `ls` | AI agents |
| `grep` | `rg` (ripgrep) | Interactive |
| `grep` | `grep` | AI agents |
| `find` | `fd` | Interactive |
| `find` | `find` | AI agents |

**The system automatically detects context** - no manual switching needed!

### 2. Command Examples Database

Curated examples for common tools:

```bash
dotfiles examples git          # Git workflows
dotfiles examples docker       # Docker operations
dotfiles examples nix          # Nix commands
dotfiles examples bash         # Bash scripting
dotfiles examples tmux         # Tmux usage

# Search within examples
dotfiles examples git commit   # Find commit examples
dotfiles examples docker build # Find build examples
```

### 3. Interactive Tool Pickers

Use `fzf` to discover commands:

```bash
dotfiles git               # Interactive git menu
dotfiles docker            # Interactive docker menu
dotfiles nix               # Interactive nix menu
```

### 4. Shell Aliases

Common shortcuts already configured:

**Navigation:**
```bash
ll      # ls -l with icons
la      # ls -la
..      # cd ..
...     # cd ../..
```

**Git:**
```bash
gst     # git status
gc      # git commit -m
gp      # git push origin HEAD
glog    # pretty git log
```

**Docker:**
```bash
dco     # docker compose
dps     # docker ps
dx      # docker exec -it
```

View all: `dotfiles aliases`

## 🤖 Using with AI Agents

If you use Claude Code or VSCode Agent Mode:

```bash
# Method 1: Environment variable (recommended)
DOTFILES_AGENT_MODE=1 claude-code

# Method 2: Wrapper script
./scripts/claude-code-wrapper.sh

# Method 3: Set permanently
export DOTFILES_PROFILE=agent
```

The system will automatically use POSIX tools (cat, ls, grep, find) instead of modern alternatives.

**Test it:**
```bash
dotfiles test-context           # Check current context
DOTFILES_AGENT_MODE=1 dotfiles test-context  # Test agent mode
```

See full documentation: [AI_AGENT_MODE.md](AI_AGENT_MODE.md)

## 🔧 Configuration Management

### Check for Updates

```bash
dotfiles update                # Check for updates (cached)
dotfiles update --force        # Force check
dotfiles update --pull         # Auto-pull updates
```

### Apply Configuration Changes

```bash
# After pulling updates or making changes
./apply.sh                     # Apply configuration
source ~/.bashrc               # Reload shell
```

### Profile Management

Switch between feature profiles:

```bash
dotfiles profile               # Show current profile
dotfiles profile full          # Enable all features
dotfiles profile agent         # POSIX-only mode
dotfiles profile auto          # Auto-detect (default)
```

Available profiles:
- `auto` - Automatic detection (recommended)
- `fast` - Minimal features for speed
- `balanced` - Optimized features
- `full` - All features, AI-aware
- `agent` - POSIX-only for AI agents

## 📊 Monitoring & Diagnostics

### Health Check

```bash
dotfiles doctor

# Checks:
# - Nix installation
# - Flakes support
# - Home Manager
# - Required tools
# - Git configuration
# - Shell performance
# - Disk space
# - Network connectivity
```

### Performance Profiling

```bash
./scripts/dotfiles-profiler.sh

# Shows startup time breakdown:
# - Nix profile loading
# - Home Manager variables
# - Starship init
# - Atuin history
# - Component percentages
```

### Configuration Validation

```bash
./lib/config-validator.sh

# Validates:
# - Alias consistency across shells
# - Function availability
# - Smart alias coverage
# - Git alias implementation
```

## 🎨 Customization

### Add Your Own Aliases

Create `~/.bashrc.local`:

```bash
# Custom aliases
alias mycommand="echo Hello"

# Custom functions
myfunction() {
    echo "My custom function"
}
```

This file is sourced automatically and won't be overwritten.

### Add Custom Examples

```bash
# Create your own examples file
echo "# My Custom Commands" > examples/my-tool.txt
echo "## Example" >> examples/my-tool.txt
echo "my-command --flag value" >> examples/my-tool.txt

# Use it
dotfiles examples my-tool
```

### Per-Project Settings

Use `.envrc` with direnv (already installed):

```bash
# In your project directory
echo "export DOTFILES_AGENT_MODE=1" > .envrc
direnv allow

# Now this directory always uses POSIX tools
```

## 🐛 Troubleshooting

### Shell Not Loading Properly

```bash
# Check for errors
bash -x ~/.bashrc 2>&1 | less

# Verify configuration
dotfiles doctor
```

### Modern Tools Not Working

```bash
# Check if tools are installed
dotfiles tools

# Check context detection
dotfiles test-context
```

### Slow Shell Startup

```bash
# Profile startup time
./scripts/dotfiles-profiler.sh

# Check what's slow
# Optimize based on recommendations
```

### AI Agent Mode Not Working

```bash
# Verify detection
DOTFILES_AGENT_MODE=1 dotfiles test-context

# Should show: "Context: AGENT"
```

## 📚 Learn More

- [AI Agent Mode](AI_AGENT_MODE.md) - Comprehensive AI detection guide
- [DX Features](DX_FEATURES.md) - All developer experience features
- [Architecture](ARCHITECTURE.md) - System design and structure
- [Performance](PERFORMANCE.md) - Optimization guide
- [Tool Pickers](TOOL_PICKERS.md) - Interactive menu guide
- [Examples Guide](EXAMPLES_GUIDE.md) - Using the examples system

## 🎓 Next Steps

1. **Explore the CLI:**
   ```bash
   dotfiles help
   ```

2. **Check system health:**
   ```bash
   dotfiles doctor
   ```

3. **Try examples:**
   ```bash
   dotfiles examples git
   ```

4. **Use interactive menus:**
   ```bash
   dotfiles git
   ```

5. **Test AI detection:**
   ```bash
   dotfiles test-context
   ```

6. **Read full documentation:**
   ```bash
   ls docs/
   ```

Welcome to your enhanced development environment! 🎉
