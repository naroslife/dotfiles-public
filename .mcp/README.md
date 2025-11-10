# MCP Server Configuration

This directory contains configuration and data files for Model Context Protocol (MCP) servers used with Claude Code.

## File Structure

```text
.mcp/
├── global.json    # Global MCP servers (used by apply.sh to run `claude mcp add`)
├── memory.json    # Global knowledge graph (symlinked to ~/.claude/.mcp/)
└── README.md      # This file
```

**Project root also contains:**

```text
.mcp.json          # Project-level MCP config (Serena only, NOT symlinked)
```

## global.json - Global MCP Server Configuration

This file contains MCP servers that apply across ALL projects:

- **memory**: Global knowledge graph for user preferences and patterns
- **sequential-thinking**: Advanced reasoning capabilities
- **fetch**: Web content retrieval
- **Ref**: Documentation search (requires `REF_API_KEY` env var)
- **filesystem-with-morph**: AI-powered file editing (requires `MORPH_API_KEY` env var)
- **markitdown**: Document conversion

**Important:** The `apply.sh` script reads this file and uses `claude mcp add --scope user` commands to install each server into Claude Code's user-scoped configuration (`~/.config/Claude/claude_desktop_config.json`).

**Serena is NOT in this file** - it's configured per-project in each project's `.mcp.json`.

### Required Environment Variables

Some MCP servers require API keys to be set as environment variables:

1. **REF_API_KEY** - Required for the Ref documentation search server
   ```bash
   export REF_API_KEY="your-ref-api-key-here"
   ```

2. **MORPH_API_KEY** - Required for the filesystem-with-morph AI editing server
   ```bash
   export MORPH_API_KEY="your-morph-api-key-here"
   ```

**Setup Instructions:**

Add these environment variables to your shell configuration file:

- **Zsh**: Add to `~/.zshrc` or `~/.zshenv`
- **Bash**: Add to `~/.bashrc` or `~/.bash_profile`
- **Elvish**: Add to `~/.config/elvish/rc.elv`

Example for Zsh:
```bash
# ~/.zshrc or ~/.zshenv
export REF_API_KEY="ref-xxxxxxxxxxxxx"
export MORPH_API_KEY="sk-xxxxxxxxxxxxx"
```

After adding the variables:
1. Reload your shell: `source ~/.zshrc` (or restart your terminal)
2. Verify: `echo $REF_API_KEY` and `echo $MORPH_API_KEY`
3. Run `./apply.sh` to install the MCP servers with the environment variables

## memory.json - Global Knowledge Graph

This file stores the global MCP Memory knowledge graph, containing:

- **User Preferences**: Personal preferences and patterns that apply across all machines and usernames
- **Code Quality Standards**: Development practices and quality requirements
- **Workflow Patterns**: Reusable patterns like parallel agent orchestration
- **Best Practices**: Documentation and guidelines for memory management

### Portability

The memory file is designed to be portable across machines:

- Entity names use generic identifiers (e.g., "User Preferences") not system-specific usernames
- Personal preferences are tagged to work across multiple system usernames (uif58593, naroslife, enterpriseuser)
- The file is version-controlled so preferences travel with the dotfiles

### How It Works

The path in `global.json` points to `${HOME}/.claude/.mcp/memory.json`, which is symlinked to this directory by the `apply.sh` script, allowing the memory to be version-controlled while being accessible globally across all projects.

### Maintenance

- The memory file is automatically updated by Claude Code during conversations
- Changes are committed to version control along with code changes
- The file persists user preferences, learned patterns, and best practices across sessions

## Project-Level .mcp.json - Serena Configuration

Each project should have its own `.mcp.json` file in the project root containing ONLY the Serena MCP server configuration:

```json
{
  "serena": {
    "command": "uvx",
    "args": [
      "--from", "git+https://github.com/oraios/serena",
      "serena", "start-mcp-server",
      "--context", "ide-assistant",
      "--project", "."
    ]
  }
}
```

**Key Features:**

- **Automatic activation**: `--project "."` activates the current working directory
- **Per-project MCP config**: Each project can have its own `.mcp.json` configuration
- **SessionStart hook**: Provides feedback about which project is active
- **Automatic initialization**: Claude Code v1.0.52+ automatically loads Serena's initial instructions

**Auto-Generation:**

If a project doesn't have `.mcp.json`, the SessionStart hook will automatically create it with the correct Serena configuration. After creation, restart Claude Code to activate Serena for that project.

**How It Works:**

1. **User-scoped servers installed**: The `apply.sh` script uses `claude mcp add --scope user` to install servers from `.mcp/global.json` into `~/.config/Claude/claude_desktop_config.json`
2. **Project config overlay**: Claude Code then reads `.mcp.json` from the project root
3. **Combined servers**: Both sets of MCP servers are active
4. **Auto-activation**: The `--project "."` flag tells Serena to activate the current working directory
5. **SessionStart hook**: Provides feedback and auto-creates missing project configs

**Key Benefits:**

- ✅ **Global servers** (memory, fetch, etc.) work across ALL projects
- ✅ **Serena** is project-specific and automatically activates the correct project
- ✅ **Auto-generation** ensures every project gets Serena support
- ✅ **Version-controlled** project configs can be committed to each repo

**Project Configuration:**

Each project maintains its own `.serena/project.yml` file with:

- Language configuration (bash, python, typescript, etc.)
- Ignored paths and gitignore settings
- Read-only mode and excluded tools
- Project-specific memories via Serena's `write_memory` tool

All activated projects are registered in `~/.serena/serena_config.yml`.

## Serena Global Configuration

The `.serena/serena_config.yml` file in this repository contains a minimal template with only customized settings:

```yaml
web_dashboard_open_on_launch: false
# Set to false to prevent auto-opening browser when Serena starts
```

**How it works:**

1. **If config exists:** Updates the `web_dashboard_open_on_launch` setting
2. **If config doesn't exist:** Runs `serena --help` to trigger config creation, then sets the preference
3. **Preserves:** The `projects:` list and all other Serena-managed settings
4. **Version-controls:** Only the minimal template with your preference

**Why this approach?**

- ✅ Automatic initialization - no manual config creation needed
- ✅ Preserves Serena's managed `projects:` list
- ✅ Version-controls only your preference, not system-specific data
- ✅ Safe to run repeatedly - idempotent operation
- ✅ Works on fresh installs and existing setups

### SessionStart Hook

A Claude Code hook automatically runs when sessions start or resume to provide context about the active Serena project:

```json
{
  "SessionStart": [{
    "matcher": "startup|resume",
    "hooks": [{
      "type": "command",
      "command": "bash -c '...displays project info...'"
    }]
  }]
}
```

This hook:

- Shows the current working directory
- Detects if a Serena project configuration exists
- Displays the project name
- Confirms the project has been activated

**Example output:**

```text
📂 Working directory: /home/uif58593/dotfiles-public
✅ Serena project detected: dotfiles-public
The Serena project "dotfiles-public" has been automatically activated for this session.
```
