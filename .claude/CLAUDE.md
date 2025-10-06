# Global Claude Instructions

## Concurrent Development with Git Worktrees
- **When to Use Git Worktrees**:
  - Multiple independent features being developed simultaneously
  - Different agents working on separate features to avoid file conflicts
  - Testing different approaches in parallel without branch switching
  - Long-running feature branches that need occasional main branch work
- **Worktree Workflow**:
  1. Create feature branches: `git branch feature/name-1 feature/name-2`
  2. Create worktrees: `git worktree add /path/to/worktree-1 feature/name-1`
  3. Launch agents in separate worktrees (each agent works in isolation)
  4. Review and merge features sequentially or together
  5. Clean up: `git worktree remove /path/to/worktree-1 && git branch -d feature/name-1`
- **Best Practices**:
  - Keep main repository on main/master branch when creating worktrees
  - Name worktrees descriptively: `dotfiles-public-feature-name`
  - One worktree per feature for clean isolation
  - Merge features after all are complete to catch integration issues
  - Remove worktrees immediately after merging to avoid stale checkouts

## Core Development Principles
- **Configuration over Code**: Always prefer configuration files over hardcoded values
- **Runtime Detection**: When displaying status, query actual runtime state rather than showing static configuration
- **Proper Parsing**: Use appropriate tools for data formats (yq for YAML, jq for JSON) instead of text manipulation
- **Defensive Coding**: Write scripts and functions that handle errors gracefully, especially with `set -e`
- **Platform Compatibility for Dotfiles**: Before categorizing tools as WSL or macOS-specific:
  - CUDA tools work on any Linux system with NVIDIA GPU (not just WSL)
  - Docker, Kubernetes, Node.js, Python work everywhere
  - Place in `modules/shells/aliases.nix` for cross-platform
  - Place in `modules/wsl.nix` only for: WSL utilities (wslu, clip.exe, explorer.exe), WSL-specific launchers
  - Place in `modules/darwin.nix` only for: macOS-specific frameworks and utilities

## Version Control
- Always keep a clean commit history. Commit meaningful states. Always commit working stages
- Use descriptive commit messages that explain the "why" not just the "what"
- Never commit broken code - ensure tests pass before committing

## Development Practices
- When debugging, always check logs first before modifying code
- Read existing code and configuration before making changes
- Follow existing code style and conventions in each project
- For repetitive and complex changes consider using the devx-optimizer agent to automate the process or create developer friendly tooling

## Bash Script Best Practices
When writing or modifying bash scripts:
- Be aware that `set -e` causes scripts to exit on any command that returns non-zero status
- In functions that may be called from scripts with `set -e`, use defensive coding:
  - For conditionals that might return false, use `if` statements instead of `&&` or `||` chains
  - Example: Instead of `[ "$VAR" = "value" ] && echo "match"`, use `if [ "$VAR" = "value" ]; then echo "match"; fi`
- When parsing commands might fail, add `|| true` to prevent script exit
- Always test scripts with `set -e` enabled to catch potential issues early

## Configuration Management
- NEVER hardcode values that could be configurable or command line parameters (ports, paths, timeouts, etc.)
- Always check for configuration files or environment variables first
- Use proper parsers for structured data:
  - YAML: Use `yq` or Python's yaml library
  - JSON: Use `jq` or Python's json library
  - XML: Use `xmlstarlet` or appropriate XML parsers
  - NEVER use grep/sed/awk to parse structured data formats

## Service Status and Monitoring
When implementing status or monitoring commands:
- Query actual system state, don't just display configured values
- For ports: Use `ss`, `netstat`, or `/proc/<pid>/net/tcp` to find actual listening ports
- For processes: Use `ps`, `/proc/<pid>/status` for real process information
- Show both configured and actual values when they might differ
- Example: "Config Port: 8080, Actual Port: 8081" if a service is running on a different port

## Testing
- Ask the user if they want to run tests themselves after implementing features or fixing bugs. If not, then you test the solution.
- Create tests for new functionality when possible
- Verify E2E flows work before marking tasks as complete
- **Post-Merge Integration Testing for Dotfiles**:
  - After merging multiple Nix configuration features, suggest running: `nix run home-manager/master -- switch --flake . --impure`
  - Verify merged shell aliases don't conflict
  - Check that environment variables from different modules work together
  - Test that platform-specific and cross-platform features coexist properly

## Documentation
- Update documentation when changing functionality with the docs-writer agent.
- Keep README files current with actual implementation
- Document configuration changes and their purpose

## Problem Solving
- When encountering errors, check:
  1. Logs
  2. Configuration files
  3. File permissions
  4. Dependencies

## Architecture
- Understand component responsibilities before making changes
- Maintain separation of concerns between components
- Prefer configuration over code changes when possible