---
model: claude-opus-4-1
---

Implement multiple features concurrently using git worktrees and parallel agents.

## Workflow Steps:

### 1. Setup Phase
- Parse feature descriptions from $ARGUMENTS (format: "feature1 description | feature2 description | feature3 description")
- Ensure main repository is on main/master branch
- Create feature branches for each feature
- Create git worktrees for each feature branch

### 2. Parallel Development Phase
- Launch specialized agents in parallel, one per worktree
- Each agent should:
  - Work in their designated worktree directory
  - Implement their assigned feature completely
  - Commit their changes with proper commit messages
  - Not depend on other agents' work

### 3. Integration Phase
- Switch back to main repository
- Review each feature branch implementation
- Merge features sequentially or together based on dependencies
- Run integration tests after all merges
- Verify no conflicts in shared resources (aliases, environment variables, ports)

### 4. Cleanup Phase
- Remove all temporary worktrees
- Delete merged feature branches
- Push integrated changes to remote

## Example Usage:
```
/workflows:concurrent-features "Add shell aliases for vscode tools | Implement hardware acceleration preference | Add post-config options for WSL"
```

## Agent Selection Guidelines:
- **general-purpose**: For feature implementation when no specialized agent fits
- **frontend-developer**: For UI/configuration features
- **backend-developer**: For API or service features
- **test-automator**: If test coverage is primary concern

## Important Notes:
- Features must be independent (no shared file modifications)
- Each worktree gets isolated agent execution
- Merge conflicts should be minimal if features are truly independent
- Always test integrated result after merging all features
