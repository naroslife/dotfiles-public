# Command Examples Database

This directory contains curated command examples for common development tools. These examples are designed to provide quick, practical reference for everyday tasks.

## Available Tools

- **git.txt** - Git version control operations
- **docker.txt** - Docker container management
- **nix.txt** - Nix package manager and Home Manager
- **bash.txt** - Bash scripting patterns and commands
- **tmux.txt** - Tmux terminal multiplexer

## Usage

### View examples directly
```bash
cat examples/git.txt
less examples/docker.txt
```

### Use the examples viewer (recommended)
```bash
# Show all examples for a tool
dotfiles examples git

# Search for specific examples
dotfiles examples git commit
dotfiles examples docker build

# List all available tools
dotfiles examples --list

# Browse interactively with fzf
dotfiles examples --fzf
```

## Integration

The examples viewer integrates with existing tools:

1. **Primary source**: Shows curated examples from this directory
2. **Fallback**: If available, falls back to `tldr` or `cheat` commands
3. **Search**: Supports searching within examples
4. **FZF**: Interactive browsing with fuzzy finding

## Example Format

Examples are organized in plain text files with clear sections:

```
# Tool Name

## Section Name

### Task description
command example
more commands

### Another task
another example
```

## Adding New Examples

To add examples for a new tool:

1. Create a new `.txt` file in this directory
2. Follow the existing format (markdown-style headers)
3. Group related commands under sections
4. Include common workflows and advanced usage
5. Add comments where helpful

## Philosophy

- **Practical over comprehensive**: Focus on commonly-used commands
- **Examples over explanations**: Show actual usage, not just syntax
- **Workflows over isolated commands**: Demonstrate common patterns
- **Searchable**: Use clear section headers for easy grepping
- **Copy-paste ready**: Commands should work with minimal modification

## Maintenance

These examples are version-controlled as part of the dotfiles repository:

- Update examples as tools evolve
- Add new sections for emerging workflows
- Keep examples relevant to the development environment
- Test examples periodically to ensure accuracy

## Credits

Examples are curated from:
- Official documentation
- Community best practices
- Personal experience
- Common patterns in the wild

Inspired by and complementing tools like `tldr` and `cheat`.
