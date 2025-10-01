# Global Claude Instructions

## Core Development Principles
- **Configuration over Code**: Always prefer configuration files over hardcoded values
- **Runtime Detection**: When displaying status, query actual runtime state rather than showing static configuration
- **Proper Parsing**: Use appropriate tools for data formats (yq for YAML, jq for JSON) instead of text manipulation
- **Defensive Coding**: Write scripts and functions that handle errors gracefully, especially with `set -e`

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