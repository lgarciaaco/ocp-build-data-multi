# Contributing to OpenShift Build Data Multi-Version Toolset

Thank you for your interest in contributing to the OpenShift Build Data Multi-Version Toolset! This project
helps manage build metadata across multiple OpenShift Container Platform versions simultaneously.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Code Style](#code-style)
- [Testing](#testing)
- [Reporting Issues](#reporting-issues)

## Getting Started

### Prerequisites

Before contributing, ensure you have all required dependencies installed:

```bash
# Check if you have all dependencies
make check-deps

# Install missing dependencies automatically
make install-deps
```

**Required Tools:**

- bash 4.0+
- git
- yq v4.0+
- jq
- gh (GitHub CLI)

### Fork and Clone

1. **Fork the repository** on GitHub
2. **Clone your fork**:

   ```bash
   git clone https://github.com/your-username/ocp-build-data-multi.git
   cd ocp-build-data-multi
   ```

3. **Set up your personal configuration**:

   ```bash
   cp config/remotes.conf.example config/remotes.conf
   # Edit config/remotes.conf with your GitHub username
   ```

## Development Setup

1. **Complete the setup process**:

   ```bash
   make setup
   ```

2. **Validate the toolset**:

   ```bash
   make validate
   ```

3. **Initialize test worktrees** (optional, for testing):

   ```bash
   ./tools/ocp-setup init 4.20,4.21
   ```

## Contributing Guidelines

### Types of Contributions

We welcome several types of contributions:

- **Bug fixes** - Fix issues in existing tools
- **Feature enhancements** - Improve existing functionality
- **New tools** - Add new utilities to the toolset
- **Documentation** - Improve README, help text, or add examples
- **Tests** - Add or improve test coverage

### Code Organization

The project structure:

```text
ocp-build-data-multi/
├── tools/              # Main toolset
│   ├── lib/           # Shared libraries
│   ├── ocp-setup     # Worktree management
│   ├── ocp-patch     # Multi-version patching
│   ├── ocp-diff      # Cross-version comparisons  
│   ├── ocp-view      # Multi-version file viewing
│   ├── ocp-bulk      # Bulk git operations
│   └── ocp-hermetic  # Hermetic conversion tracking
├── config/            # Configuration templates
└── docs/              # Documentation
```

### Coding Standards

- **Shell Scripts**: Follow bash best practices
  - Use `set -euo pipefail` for error handling
  - Quote variables properly
  - Use meaningful function and variable names
  - Add help text for all commands

- **Functions**: Should be focused and do one thing well
- **Error Handling**: Provide clear error messages with suggested fixes
- **Logging**: Use the common logging functions from `lib/common.sh`

### Documentation Requirements

- **Help Text**: All tools must provide `--help` output
- **Examples**: Include practical examples in help text
- **README Updates**: Update README.md for significant changes
- **Code Comments**: Explain complex logic, not obvious code

## Pull Request Process

### Before Submitting

1. **Test your changes**:

   ```bash
   # Validate the toolset still works
   make validate
   
   # Test with dry-run mode
   ./tools/your-tool --dry-run
   ```

2. **Update documentation** if needed

3. **Follow commit message conventions**:

   ```text
   feat: add support for version ranges in ocp-patch
   
   - Add parsing for version ranges like 4.17..4.21
   - Update help text with examples
   - Add validation for range syntax
   ```

### Submitting a Pull Request

1. **Create a feature branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** with clear, focused commits

3. **Push to your fork**:

   ```bash
   git push origin feature/your-feature-name
   ```

4. **Create a Pull Request** with:
   - **Clear title** describing the change
   - **Description** explaining what and why
   - **Testing notes** showing how you validated the change
   - **Breaking changes** if any

### Pull Request Template

```markdown
## Summary
Brief description of what this PR does.

## Changes
- List of specific changes made
- New features or fixes

## Testing
- [ ] Ran `make validate`
- [ ] Tested with `--dry-run` mode
- [ ] Tested on multiple versions

## Breaking Changes
List any breaking changes or none.
```

## Code Style

### Shell Scripting

- Use 4-space indentation
- Prefer `[[ ]]` over `[ ]` for conditionals
- Use `$()` for command substitution, not backticks
- Quote variables: `"$variable"` not `$variable`
- Use meaningful function names: `validate_version()` not `check()`

### Error Handling

```bash
# Good error handling example
if [[ ! -f "$config_file" ]]; then
    log_error "Configuration file not found: $config_file"
    log_info "Run 'make setup-config' to create it"
    return 1
fi
```

### Logging

Use the common logging functions:

```bash
log_info "Starting operation..."
log_success "Operation completed successfully"
log_warning "This is a warning"
log_error "Something went wrong"
log_debug "Debug information"  # Only shown with --debug
```

## Testing

### Manual Testing

Always test your changes manually:

```bash
# Test the tool works
./tools/your-tool --help

# Test with dry-run
./tools/your-tool your-operation --dry-run

# Test error conditions
./tools/your-tool invalid-input
```

### Integration Testing

Test with actual OpenShift versions:

```bash
# Initialize test worktrees
./tools/ocp-setup init 4.20,4.21

# Test cross-version operations
./tools/ocp-diff golang-versions 4.20,4.21
./tools/ocp-view file group.yml 4.20,4.21
```

## Reporting Issues

### Bug Reports

When reporting bugs, include:

- **Environment**: OS, shell version, tool versions
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **Error messages** (full output)
- **Configuration**: Relevant config files (sanitized)

### Feature Requests

For feature requests, describe:

- **Use case**: What problem does this solve?
- **Proposed solution**: How should it work?
- **Alternatives**: Other approaches considered
- **Impact**: Who would benefit from this?

### Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Documentation**: Check README.md and tool help text first

## Code of Conduct

This project follows the OpenShift community standards:

- Be respectful and inclusive
- Focus on what's best for the community
- Show empathy towards other community members
- Be collaborative and constructive

## License

By contributing to this project, you agree that your contributions will be licensed under the Apache License 2.0.

## Thank You

Your contributions help make OpenShift build data management easier for everyone. Thank you for taking the time
to contribute!
