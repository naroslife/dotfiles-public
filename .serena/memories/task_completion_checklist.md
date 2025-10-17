# Task Completion Checklist

## Before Committing Code

### 1. Code Quality Checks

```bash
# Validate Nix configuration syntax
nix flake check

# If the check fails, fix syntax errors before proceeding
```

### 2. Run Tests

```bash
# Run the full test suite
./tests/run_tests.sh

# For comprehensive validation with coverage
./tests/run_tests.sh --coverage --benchmark

# Ensure all tests pass before committing
```

### 3. Format and Style

```bash
# Bash scripts should follow conventions:
# - set -euo pipefail at the top
# - 2-space indentation
# - Functions under 20 lines
# - Use lib/common.sh logging functions

# For Python scripts, ensure PEP 8 compliance
# (Can use: black, flake8, pylint if installed)

# Nix files should have 2-space indentation
# Check with: nix fmt (if configured)
```

### 4. Manual Testing

```bash
# Test the configuration applies successfully
./apply.sh

# Or manually
home-manager switch --flake .#$USER

# Verify the changes work as expected in a new shell
```

### 5. Documentation

- Update README.md if you added new features or changed usage
- Update ARCHITECTURE.md if you changed the structure
- Update CLAUDE.md if you changed commands or workflows
- Add comments to complex code sections
- Update module-specific README if applicable

### 6. Run Health Check

```bash
# Verify system health after changes
dotfiles doctor

# Check for any warnings or errors
```

## Commit Process

### 1. Stage Changes

```bash
# Review what changed
git status
git diff

# Stage relevant files
git add <files>
```

### 2. Write Commit Message

Follow conventional commits format:

```bash
git commit -m "type: description"

# Types:
# feat:     New feature
# fix:      Bug fix
# docs:     Documentation changes
# style:    Code style/formatting (no logic change)
# refactor: Code restructuring
# test:     Add or update tests
# chore:    Maintenance tasks
# perf:     Performance improvements

# Examples:
git commit -m "feat: add tmux session manager script"
git commit -m "fix: resolve WSL clipboard integration issue"
git commit -m "docs: update installation instructions"
git commit -m "refactor: extract common shell functions to lib"
git commit -m "test: add coverage for apply.sh user selection"
```

### 3. Verify Commit

```bash
# Review the commit
git show

# Ensure it includes what you intended
```

## After Committing

### 1. Push Changes

```bash
# Push to your branch
git push origin <branch-name>

# Or to main (if working directly on main)
git push origin main
```

### 2. Verify on Other Machines (if applicable)

```bash
# On another machine, pull and apply
git pull
./apply.sh

# Verify everything works across different environments
```

### 3. Update Changelog (for significant changes)

```bash
# Add entry to CHANGELOG.md for version tracking
# Follow the existing format in the file
```

## Maintenance Tasks

### Periodic Checks

```bash
# Check for updates (weekly/monthly)
./scripts/dotfiles-update-checker.sh

# Update flake inputs
nix flake update

# Clean old generations (monthly)
home-manager expire-generations "-30 days"
nix-collect-garbage -d
```

### Performance Monitoring

```bash
# Profile shell startup time
./scripts/dotfiles-profiler.sh

# Compare against previous results
# Typical startup should be <100ms for Bash/Zsh
```

## Special Considerations

### WSL-Specific Changes

If you modified WSL-related code:

```bash
# Test on actual WSL environment
# Verify clipboard integration: pbcopy/pbpaste
# Check WSL utilities: wslview, wslpath, wslvar
# Test network switching: ./scripts/apt-network-switch.sh
```

### Shell Configuration Changes

If you modified shell configs (Bash, Zsh, Elvish):

```bash
# Test in each affected shell
bash
zsh
elvish

# Verify:
# - Aliases work correctly
# - Completions function
# - Prompt displays properly
# - History syncs with Atuin
```

### Module Changes

If you added or modified Nix modules:

```bash
# Ensure module is imported in modules/default.nix
# Verify no duplicate package installations
# Check for conflicts with existing modules
# Test with: nix flake check
```

### Script Changes

If you added or modified scripts in `scripts/`:

```bash
# Ensure script is executable
chmod +x scripts/new-script.sh

# Test script standalone
./scripts/new-script.sh --help

# Add tests to tests/ directory
# Update scripts/README.md if needed
```

## Quality Gates

Before considering a task "done":

- [ ] Code passes `nix flake check`
- [ ] All tests pass (`./tests/run_tests.sh`)
- [ ] Code follows style conventions (EditorConfig, Bash standards)
- [ ] Changes are documented (README, ARCHITECTURE, or code comments)
- [ ] Manual testing completed successfully
- [ ] `dotfiles doctor` shows no new warnings
- [ ] Commit message follows conventional commits format
- [ ] Changes pushed to repository
- [ ] (If applicable) Tested on different environments (WSL, Linux)

## Rollback Procedure

If something goes wrong after applying changes:

```bash
# List home-manager generations
home-manager generations

# Rollback to previous generation
/nix/store/<previous-generation-path>/activate

# Or restore from backup if you used lib/common.sh
# Backups are stored in ~/.dotfiles-backups/

# Fix the issue, then re-apply
./apply.sh
```
