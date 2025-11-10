# Claude Code Configuration

This directory contains configuration files for Claude Code that are version-controlled and portable across machines.

## Directory Structure

```
.claude/
├── CLAUDE.md              # Global instructions for Claude Code
├── settings.json          # Main settings (permissions, statusline, env)
├── settings.local.json    # Machine-specific overrides (MCP servers, local permissions)
├── setup-plugins.sh       # Script to install Claude Code plugins
├── .gitignore            # Excludes ephemeral files and credentials
└── ccline/               # CCline statusline configuration
    ├── config.toml       # CCline segments and styling
    ├── models.toml       # Model display names and context limits
    └── themes/           # CCline theme files
        └── *.toml
```

## Files Included

### CLAUDE.md
Global instructions that define Claude Code's behavior, plugin marketplace architecture, orchestration workflows, and coding philosophy. This file is read by Claude Code in all projects unless overridden by a project-specific CLAUDE.md.

### settings.json
Main configuration file containing:
- **Permissions**: Allowed MCP tools and additional directories
- **Status Line**: CCline configuration
- **Environment Variables**: MCP timeouts, Ripgrep settings
- **Features**: Always Thinking mode

### settings.local.json
Machine-specific settings that override settings.json. This file can contain:
- Machine-specific tool permissions (e.g., project-specific git commands)
- Enabled MCP servers for this machine
- Any other local overrides

**Note**: This file is in `.gitignore` to prevent syncing machine-specific settings.

### setup-plugins.sh
Automated script to install the recommended Claude Code plugins. The script installs 24 plugins covering development, testing, quality, AI/ML, operations, and language-specific workflows.

**Usage**:
```bash
cd ~/.claude
./setup-plugins.sh
```

### ccline/
Configuration for the CCline statusline tool that displays context in Claude Code's status bar.

- **config.toml**: Defines segments (model, directory, git, context window, etc.)
- **models.toml**: Custom model display names and context limits
- **themes/**: Color themes (Tokyo Night, Nord, Gruvbox, Rose Pine, etc.)

## Files Excluded

The following files are excluded from version control via `.gitignore`:

- `.credentials.json` - API credentials (sensitive)
- `plugins/` - Installed plugins (handled by setup-plugins.sh)
- `history.jsonl` - Chat history (ephemeral)
- `todos/` - Todo state (ephemeral)
- `file-history/` - File edit history (ephemeral)
- `debug/` - Debug logs (ephemeral)
- `projects/` - Project-specific state (ephemeral)
- `shell-snapshots/` - Shell state snapshots (ephemeral)
- `statsig/` - Analytics data (ephemeral)
- `ide/` - IDE integration lock files (ephemeral)
- `ccline/ccline` - Binary executable (installed separately)
- `ccline/.api_usage_cache.json` - API usage cache (ephemeral)

## Setup Instructions

### Initial Setup on a New Machine

1. **Apply dotfiles** (this will symlink the .claude directory):
   ```bash
   cd ~/dotfiles-public
   ./apply.sh
   ```

2. **Install Claude Code plugins**:
   ```bash
   ~/.claude/setup-plugins.sh
   ```

3. **Install CCline** (for statusline):
   ```bash
   # Download from https://github.com/cometix-ai/ccline
   # Or use package manager if available
   ```

4. **Configure credentials** (if needed):
   ```bash
   # Create .credentials.json in ~/.claude/ with your API keys
   # This file is NOT version-controlled
   ```

### Updating Configuration

After making changes to settings.json or CLAUDE.md:

```bash
cd ~/dotfiles-public
git add .claude/
git commit -m "chore: Update Claude Code configuration"
git push
```

On other machines, pull the changes:

```bash
cd ~/dotfiles-public
git pull
./apply.sh  # Re-symlink if needed
```

## Portability

This configuration is designed to be portable across machines:

- **Username-agnostic**: Uses `${HOME}` variables where possible
- **Generic identities**: MCP Memory uses "User Preferences" not usernames
- **Modular**: Machine-specific settings go in settings.local.json
- **Automated**: Plugin installation via script, not manual config

## Maintenance

### Adding New Plugins

To add plugins to the setup:

1. Edit `setup-plugins.sh`
2. Add the plugin to the `plugins=()` array
3. Commit and push
4. Run `./setup-plugins.sh` on all machines

### Updating CCline Theme

1. Edit `ccline/config.toml` to change theme or segments
2. Commit and push
3. Restart Claude Code to see changes

### Checking Plugin Status

```bash
claude plugin list
```

## Documentation Links

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [CCline Repository](https://github.com/cometix-ai/ccline)
- [Plugin Marketplace](https://github.com/anthropics/claude-code-workflows)
