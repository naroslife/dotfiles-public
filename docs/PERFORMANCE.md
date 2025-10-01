# Performance Optimizations

This document describes the performance optimizations applied to the dotfiles configuration.

## Shell Startup Optimizations

### Lazy Loading

#### Carapace Completions
- **Bash**: Completions are loaded only on first tab press using `complete -F -D`
- **ZSH**: Direct loading (lazy loading caused issues with completion system)
- **Impact**:
  - Bash: Reduces shell startup time by ~100-200ms
  - ZSH: No lazy loading due to complexity of ZSH completion system

#### Custom Functions
- Functions are only sourced if the directory exists and contains files
- Prevents unnecessary file system operations on every shell start
- **Impact**: Saves ~50ms when functions directory is empty

### Starship Prompt

Optimized settings:
- `command_timeout`: Reduced from 2000ms to 500ms
- `scan_timeout`: Set to 30ms for faster file scanning
- **Impact**: Faster prompt rendering, especially in large git repositories

### Atuin History

Performance settings:
- `auto_sync`: Disabled for faster startup (sync manually or on-demand)
- `sync_frequency`: Reduced from 5m to 1h
- `max_preview_height`: Limited to 4 lines for faster rendering
- **Impact**: Reduces shell startup time by ~50-100ms

### ZSH-Specific Optimizations

#### Completion System
- `skip_global_compinit=1`: Skips system-wide compinit
- Completions managed by Home Manager for better performance

#### History
- History file moved to `~/.cache/zsh/history` for better I/O
- `ignoreDups` and `ignoreSpace` enabled to keep history clean
- History size: 50,000 entries (balanced for performance)
- `share`: Enabled for instant history sharing across shells

#### Autosuggestions
- Strategy: `["history" "completion"]` for faster suggestions
- History-based suggestions are faster than completion-based

## Benchmarking

### Measure Shell Startup Time

**Bash:**
```bash
time bash -ic exit
```

**ZSH:**
```bash
time zsh -ic exit
```

### Expected Times (After Optimizations)

- **First shell of the day**: ~200-300ms (WSL messages + initialization)
- **Subsequent shells**: ~100-150ms
- **Without lazy loading**: ~400-600ms

## Additional Performance Tips

### 1. Disable Unused Features

If you don't use certain features, disable them:

```nix
# In modules/shells/default.nix
programs.atuin.enable = false;  # If you don't use Atuin
programs.mcfly.enable = false;  # Already disabled
```

### 2. Reduce Git Operations

Starship checks git status on every prompt. In large repos:

```bash
# Disable git status for specific repos
cd /path/to/large/repo
git config --local oh-my-zsh.hide-status 1
```

### 3. Use Compilation Cache

For C/C++/Rust development, use `sccache`:

```bash
export RUSTC_WRAPPER=sccache
export CC="sccache gcc"
export CXX="sccache g++"
```

### 4. Optimize Nix Operations

```bash
# Use binary caches
nix.conf settings:
  substituters = [ "https://cache.nixos.org" "https://nix-community.cachix.org" ]
  trusted-public-keys = [ ... ]

# Parallel builds
nix.conf:
  max-jobs = auto
  cores = 0  # Use all cores
```

## Monitoring Performance

### Profile Shell Startup

**Bash:**
```bash
PS4='+ $(date "+%s.%N")\011 ' bash -x -ic exit 2>&1 | tail -20
```

**ZSH:**
```bash
zsh -xv -ic exit 2>&1 | tail -20
```

### Check Individual Tool Times

```bash
time (source <(carapace _carapace))  # Carapace loading time
time (eval "$(atuin init bash)")      # Atuin initialization time
time (eval "$(starship init bash)")   # Starship initialization time
```

## Trade-offs

### Lazy Loading
- **Pro**: Faster startup
- **Con**: First tab completion slightly slower
- **Recommendation**: Enable (current setting)

### Atuin Auto-sync
- **Pro**: Always up-to-date history across machines
- **Con**: Adds 50-100ms to shell startup
- **Recommendation**: Disable and sync manually (current setting)

### Starship Command Timeout
- **Pro**: Faster prompts in slow environments
- **Con**: Some commands may not show complete info
- **Recommendation**: 500ms is a good balance (current setting)

## Future Improvements

1. **Zsh Plugin Manager**: Consider switching to a faster plugin manager like `zinit` for even faster startup
2. **Completion Caching**: Cache completion definitions between sessions
3. **Async Prompts**: Use async rendering for git status (Starship already does this)
4. **Profile-based Loading**: Load different features based on whether it's an interactive/login/subshell

## Reverting Optimizations

If any optimization causes issues, you can revert by editing the respective module:

```bash
# Edit the shell module
vim ~/dotfiles-public/modules/shells/bash.nix    # For bash
vim ~/dotfiles-public/modules/shells/zsh.nix     # For zsh
vim ~/dotfiles-public/modules/shells/default.nix # For shared settings

# Apply changes
./apply.sh
```