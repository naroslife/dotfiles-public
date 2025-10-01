# Completion System

This document explains how the completion system works in ZSH with both Carapace and fzf-tab.

## Architecture

The completion system has two main components that work together:

### 1. Carapace (Backend)
- **What it does**: Generates completion candidates and descriptions
- **Provides**: Intelligent command-specific completions for 1000+ commands
- **Examples**: Docker commands, Git operations, kubectl, etc.

### 2. fzf-tab (Frontend/UI)
- **What it does**: Displays completions in an interactive, searchable menu
- **Provides**: Visual interface with fuzzy search, previews, and navigation
- **Examples**: Shows directory contents, colorizes options, groups by type

## How They Work Together

```
You press TAB
     ↓
ZSH completion system activates
     ↓
Carapace generates completion options
     ↓
fzf-tab intercepts and displays them in interactive menu
     ↓
You select an option
     ↓
ZSH completes the command
```

## Do They Conflict?

**No!** They are complementary:
- Carapace = Smart completion generation
- fzf-tab = Beautiful presentation

Think of it as:
- **Carapace**: The brain (knows what completions are available)
- **fzf-tab**: The UI (shows them nicely)

## Configuration

### Carapace Settings
```bash
# Loaded in modules/shells/zsh.nix
source <(carapace _carapace zsh)
```

### fzf-tab Settings
```bash
# Verbose completions show carapace's descriptions
zstyle ':completion:*' verbose yes

# Group completions by type
zstyle ':completion:*' group-name ''

# Colorize based on file type
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
```

## Usage Examples

### Basic TAB Completion
```bash
docker <TAB>
# Shows: run, ps, exec, etc. with descriptions from carapace
# Displayed: in fzf-tab interactive menu

git checkout <TAB>
# Shows: all branches with carapace knowledge
# Displayed: in searchable fzf menu
```

### With Preview
```bash
cd ~/proj<TAB>
# Shows: directories matching ~/proj*
# Preview: eza shows contents of each directory
```

### Fuzzy Search
```bash
docker ps <TAB>
# Type to filter: "cont" → filters to container-related options
```

## Benefits of This Setup

### From Carapace:
✅ Smart completions for 1000+ commands
✅ Accurate flag descriptions
✅ Context-aware suggestions
✅ Regular updates for new commands

### From fzf-tab:
✅ Visual, searchable interface
✅ Preview panes (files, directories, etc.)
✅ Color coding
✅ Group navigation
✅ Fuzzy search filtering

### Combined:
✅ Best of both worlds
✅ Carapace's intelligence + fzf-tab's UX
✅ No conflicts - they complement each other

## Disabling One or Both

### Disable fzf-tab (keep carapace)
```nix
# In modules/shells/zsh.nix, comment out:
plugins = [
  # {
  #   name = "fzf-tab";
  #   ...
  # }
];
```
Result: Standard ZSH menu completion with carapace smarts

### Disable carapace (keep fzf-tab)
```nix
# In modules/shells/zsh.nix, comment out:
# if command -v carapace >/dev/null 2>&1; then
#   source <(carapace _carapace zsh)
# fi
```
Result: fzf-tab UI with standard ZSH completions

### Disable both
Comment out both sections above.
Result: Basic ZSH completion only

## Troubleshooting

### Completions not showing descriptions
- Check: `zstyle ':completion:*' verbose yes` is set
- Verify carapace is loaded: `which carapace`

### fzf-tab not working
- Check fzf is installed: `which fzf`
- Verify plugin loaded: restart shell after config change

### Slow completions
- Carapace generates completions on-demand (usually fast)
- For very large directories, preview may be slow (disable preview)

### Conflicts with other completion plugins
- fzf-tab should be loaded last (after carapace)
- Check plugin load order in zsh.nix

## Performance

- **Carapace**: Negligible overhead (~5-10ms per completion)
- **fzf-tab**: Adds ~20-30ms for UI rendering
- **Total**: Still faster than typing the full command!

## Further Reading

- [Carapace Documentation](https://carapace-sh.github.io/carapace/)
- [fzf-tab GitHub](https://github.com/Aloxaf/fzf-tab)
- [ZSH Completion System](http://zsh.sourceforge.net/Doc/Release/Completion-System.html)