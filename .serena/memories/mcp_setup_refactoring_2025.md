# MCP Server Setup Refactoring - Session Context

**Date**: 2025-10-21  
**Project**: dotfiles-public  
**Context Type**: Comprehensive  
**Tags**: mcp-servers, cli-syntax, refactoring, context-optimization

## Session Overview

Major refactoring of MCP server installation approach from symlink-based to CLI command-based, with context size optimization.

## Architectural Decisions

### 1. MCP Server Installation Method Change

**Decision**: Replace symlink approach with explicit `claude mcp add` commands

**Rationale**:
- User-scoped configuration is the proper approach per Claude Code documentation
- Symlinks don't integrate with Claude's native MCP management
- CLI commands allow proper lifecycle management (add, remove, update)
- Better aligns with Claude Code's architecture

**Implementation**: 
- Created `setup_mcp_servers()` function in `lib/setup/claude.sh`
- Parses `.mcp/global.json` using `jq`
- Executes `claude mcp add --transport stdio --scope user` for each server

**Files Modified**:
- `lib/setup/claude.sh` (lines 133-219)
- `.mcp/README.md`
- `.mcp/global.json`

### 2. CLI Syntax Verification Process

**Decision**: Always verify CLI syntax with official documentation before implementation

**Rationale**:
- Initial implementation used incorrect syntax (`--global`, wrong argument order)
- Documentation check revealed correct syntax requirements
- Prevents implementation errors and debugging cycles

**Correct Syntax Pattern**:
```bash
claude mcp add --transport stdio --scope user <name> \
  [--env KEY=value]... \
  -- <command> <args>...
```

**Key Requirements**:
- `--transport stdio` for local process servers
- `--scope user` for user-scoped configuration
- Environment variables BEFORE the `--` separator
- Command and arguments AFTER the `--` separator

**Verification Method**: Used WebFetch to check https://docs.claude.com/en/docs/claude-code/mcp

**User Preference Added**: "Always verify CLI tool syntax by checking official documentation using Ref MCP or WebFetch before implementing"

### 3. Context Size Optimization

**Decision**: Remove `filesystem` MCP server from global configuration

**Rationale**:
- MCP tools context was ~37,056 tokens (exceeding 25,000 token threshold)
- `filesystem` server contributed ~14 tool definitions (~10,000-15,000 tokens)
- Serena provides superior semantic file operations
- Claude Code has native Read, Write, Edit tools
- `filesystem-with-morph` retained for AI-powered editing

**Impact**:
- Significant context reduction
- Eliminates redundancy with Serena
- Improves tool selection performance
- Reduces latency

**Remaining MCP Servers** (6):
1. memory - Global knowledge graph
2. sequential-thinking - Advanced reasoning
3. fetch - Web content retrieval
4. Ref - Documentation search
5. filesystem-with-morph - AI-powered file editing
6. markitdown - Document conversion

## Implementation Details

### setup_mcp_servers() Function

**Location**: `lib/setup/claude.sh:133-219

**Algorithm**:
1. Check for `claude` CLI availability
2. Check for `jq` (JSON parsing dependency)
3. Parse `.mcp/global.json` to extract server configurations
4. For each server:
   - Extract command, args, env vars using jq
   - Build command array with proper syntax
   - Execute `claude mcp add` command
   - Log success/failure

**Error Handling**:
- Gracefully skips if `claude` CLI not found
- Errors if `jq` not available
- Per-server error logging without failing entire setup

**Dependencies**:
- `jq` for JSON parsing
- `claude` CLI for MCP server installation

### Command Construction Pattern

```bash
# Base command
cmd_args=("claude" "mcp" "add" "--transport" "stdio" "--scope" "user" "$server_name")

# Add environment variables (before --)
for key in env_keys; do
    cmd_args+=("--env" "$key=$value")
done

# Add separator
cmd_args+=("--")

# Add command and args (after --)
cmd_args+=("$command")
for arg in args; do
    cmd_args+=("$arg")
done

# Execute
"${cmd_args[@]}"
```

## Testing & Validation

**JSON Parsing Tests**:
- Verified extraction of server names, commands, args, env vars
- Tested both servers with and without environment variables
- Validated command construction for `memory` and `sequential-thinking` servers

**Example Generated Commands**:

```bash
# With environment variables
claude mcp add --transport stdio --scope user memory \
  --env MEMORY_FILE_PATH=${HOME}/.claude/.mcp/memory.json \
  -- npx -y @modelcontextprotocol/server-memory

# Without environment variables  
claude mcp add --transport stdio --scope user sequential-thinking \
  -- npx -y @modelcontextprotocol/server-sequential-thinking
```

## File Changes Summary

### lib/setup/claude.sh
- **Removed**: Symlink logic for `.mcp/global.json` → `~/.claude/.mcp.json` (lines 102-132, old)
- **Added**: `setup_mcp_servers()` function (lines 133-219)
- **Modified**: `setup_claude()` to call `setup_mcp_servers()`

### .mcp/global.json
- **Removed**: `filesystem` server configuration
- **Remaining**: 6 servers (memory, sequential-thinking, fetch, Ref, filesystem-with-morph, markitdown)

### .mcp/README.md
- **Updated**: File structure diagram (removed symlink reference)
- **Updated**: Server list (removed filesystem entry)
- **Updated**: "How It Works" section (changed to `claude mcp add` approach)
- **Updated**: Terminology (global → user-scoped)

## Knowledge Transfer

### Key Learnings

1. **CLI Documentation is Critical**: Always check official docs before implementing CLI commands
2. **Context Optimization Matters**: Large MCP tool contexts impact performance significantly
3. **Semantic vs Basic Tools**: Prefer semantic tools (Serena) over basic file operations
4. **Proper Separation of Concerns**: User-scoped vs project-scoped MCP configuration

### Best Practices Established

1. Use Ref MCP (`mcp__Ref__ref_search_documentation`) or WebFetch for CLI syntax verification
2. Parse JSON configurations with `jq` for robust shell scripting
3. Implement per-item error handling in batch operations
4. Document rationale for architectural decisions
5. Test command construction before execution

### MCP Configuration Architecture

**User-Scoped** (`~/.config/Claude/claude_desktop_config.json`):
- Global tools used across all projects
- Installed via `claude mcp add --scope user`
- Source: `.mcp/global.json` in dotfiles

**Project-Scoped** (`.mcp.json` in project root):
- Project-specific tools (e.g., Serena with `--project "."`)
- Automatically loaded when working in project directory
- Not managed by dotfiles setup script

**Memory Files**:
- Global: `~/.claude/.mcp/memory.json` (symlinked from dotfiles)
- Project: `.serena/memories/` (Serena-specific)

## Future Considerations

### Potential Improvements

1. **Idempotency**: Add detection for already-installed servers to avoid duplicates
2. **Server Removal**: Add logic to remove servers no longer in `.mcp/global.json`
3. **Version Management**: Track server versions for update notifications
4. **Dependency Checking**: Verify `npx`, `uvx` availability before installation
5. **Rollback Capability**: Backup existing MCP config before modifications

### Monitoring

- Watch MCP tools context size with `/doctor` command
- Monitor for context size warnings (>25,000 tokens)
- Consider removing additional servers if context grows

### Documentation Needs

- Add troubleshooting section for MCP server failures
- Document manual server management commands
- Create migration guide for users with existing setups

## Session Metadata

**Duration**: ~1 hour  
**Tools Used**: Read, Edit, Bash, WebFetch, TodoWrite, MCP Memory  
**Commands Executed**: JSON validation, command construction testing  
**Verification Method**: Manual testing of generated commands  

**Related Memories**:
- `project_overview` - Overall dotfiles architecture
- `suggested_commands` - Command reference
- `code_style_conventions` - Bash scripting standards

**Git Status**: Changes ready for commit but not yet committed

## Recommended Next Steps

1. Test the setup by running `./apply.sh` in a clean environment
2. Verify MCP servers are properly installed in `~/.config/Claude/claude_desktop_config.json`
3. Check context size improvement with `/doctor` command
4. Commit changes with conventional commit format
5. Consider adding integration tests for `setup_mcp_servers()` function
