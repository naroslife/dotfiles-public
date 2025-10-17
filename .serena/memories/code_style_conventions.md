# Code Style and Conventions

## General Principles

1. **Modularity**: Keep modules focused and under 200 lines
2. **Reliability**: Comprehensive error handling
3. **Security**: Defense-in-depth approach
4. **Usability**: Clear messages and progress indication
5. **Testability**: Everything should be tested and benchmarked
6. **Maintainability**: Clean, documented, structured code

## File Organization

### EditorConfig Standards
- **Charset**: UTF-8
- **Line Endings**: LF (Unix-style)
- **Final Newline**: Required
- **Trailing Whitespace**: Trimmed (except Markdown)

### Indentation by File Type
- **Nix** (*.nix): 2 spaces
- **Shell** (*.sh): 2 spaces
- **Elvish** (*.elv): 2 spaces
- **YAML/JSON**: 2 spaces
- **Python** (*.py): 4 spaces
- **Go** (*.go): Tabs (4 width)
- **Markdown** (*.md): 2 spaces, trailing whitespace allowed
- **Makefiles**: Tabs

## Bash Scripting Conventions

### Shell Script Headers
```bash
#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

### Code Quality Standards
- **Function Length**: Maximum 20 lines
- **Cyclomatic Complexity**: Below 10
- **Error Handling**: Always use common library functions
- **Logging**: Use structured logging functions from lib/common.sh

### Using the Common Library
```bash
# Source the library
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# Logging functions
log_info "Starting process"
log_warn "This is a warning"
log_error "Something went wrong"
log_debug "Debugging information"

# Platform detection
if is_wsl; then
    log_info "Running on WSL"
fi

if is_linux; then
    log_info "Running on Linux"
fi

# Secure downloads with checksum verification
fetch_url "$URL" "$output_file" "$checksum"

# Input validation
require_command git "Please install git first"
```

### Error Handling Pattern
```bash
# Always handle errors explicitly
if ! some_command; then
    log_error "Command failed"
    return 1
fi

# Use safe file operations with backups
backup_file "/path/to/file"
```

## Nix Configuration Conventions

### Module Structure
```nix
{ config, pkgs, lib, ... }:
{
  # Imports at top
  imports = [ ./submodule.nix ];
  
  # Options definition
  options = { };
  
  # Configuration
  config = {
    # Grouped by functionality
    home.packages = with pkgs; [
      # package list
    ];
    
    programs.git = {
      enable = true;
      # config here
    };
  };
}
```

### Naming Conventions
- **Module files**: lowercase-with-hyphens.nix
- **Variables**: camelCase
- **Functions**: camelCase or snake_case (consistency within file)

### Organization
- Keep modules focused (one concern per module)
- Extract complex logic to separate modules
- Use `modules/default.nix` as the aggregator

## Python Script Conventions

### Style
- **PEP 8** compliant
- **Type hints** where applicable
- **Docstrings** for all public functions and classes
- **4-space indentation** (per EditorConfig)

### Example
```python
#!/usr/bin/env python3
"""Module docstring describing purpose."""

def function_name(param: str) -> bool:
    """Function docstring.
    
    Args:
        param: Description of parameter
        
    Returns:
        Description of return value
    """
    # Implementation
    return True
```

## Testing Conventions

### Test File Naming
- `test_<module_name>.sh` for unit tests
- `test_<feature>.sh` for integration tests

### Test Structure
```bash
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# Test setup
setup_test() {
    # Prepare test environment
}

# Individual test cases
test_function_name() {
    local result
    result=$(function_under_test "arg")
    
    if [[ "$result" == "expected" ]]; then
        log_info "✓ Test passed"
        return 0
    else
        log_error "✗ Test failed: expected 'expected', got '$result'"
        return 1
    fi
}

# Run tests
main() {
    setup_test
    test_function_name
}

main "$@"
```

### Test Coverage Requirements
- Maintain >80% test coverage
- Test all critical paths
- Include edge cases and error conditions

## Documentation Standards

### Code Comments
- **Shell**: `# Comment above the code it describes`
- **Nix**: `# Comment above the expression`
- **Inline**: Only for non-obvious logic

### README Files
- Each major directory should have a README.md explaining its purpose
- Include usage examples
- Document any scripts or tools

### Commit Messages
Follow conventional commits format:
```
feat: add new feature
fix: resolve bug
docs: update documentation
style: formatting changes
refactor: code restructuring
test: add or update tests
chore: maintenance tasks
```

## Security Practices

1. **Checksum Verification**: All downloads must be verified
2. **Input Validation**: Validate all user inputs
3. **Safe File Operations**: Always backup before modifications
4. **Error Recovery**: Implement rollback mechanisms
5. **Secure Defaults**: Conservative security settings

## Performance Guidelines

### Typical Execution Times
- Platform detection: ~12ms
- File operations: ~45ms
- Configuration validation: ~30ms
- Full setup: 2-5 minutes (network dependent)

### Optimization Tips
- Use built-in shell operations over external commands when possible
- Avoid unnecessary subshells
- Batch operations where applicable
- Profile with `./scripts/dotfiles-profiler.sh`

## Common Patterns

### Shared Library Usage
Always use functions from `lib/common.sh` for:
- Logging
- Platform detection
- Error handling
- File operations
- Input validation

### Module Extraction
Extract complex scripts to `scripts/` directory rather than embedding in Nix modules.

### WSL Detection
```bash
if is_wsl; then
    # WSL-specific logic
fi
```

### Configuration Validation
```bash
# Validate before using
validate_json_file "$file"
validate_yaml_file "$file"
```
