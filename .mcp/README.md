# MCP Server Configuration

This directory contains configuration and data files for Model Context Protocol (MCP) servers used with Claude Code.

## memory.json

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

### Configuration

The MCP memory server is configured in `.mcp.json` to use this file via the `MEMORY_FILE_PATH` environment variable:

```json
{
  "memory": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"],
    "env": {
      "MEMORY_FILE_PATH": "${HOME}/dotfiles-public/.mcp/memory.json"
    }
  }
}
```

### Maintenance

- The memory file is automatically updated by Claude Code during conversations
- Changes are committed to version control along with code changes
- The file persists user preferences, learned patterns, and best practices across sessions
