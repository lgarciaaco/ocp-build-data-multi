# OpenShift Build Data Multi-Version Toolset

A powerful toolset for managing multiple OpenShift Container Platform versions simultaneously using git worktrees. This
eliminates the need for tedious branch switching when working across different OpenShift releases.

## Overview

This toolset provides unified commands to:

- **Apply changes quickly across multiple versions** without branch switching
- **Spot differences between versions** with comprehensive comparison tools
- **List files and content across versions** with flexible viewing options
- **Track hermetic build conversion progress** across all OpenShift releases
- **Perform bulk git operations** across multiple version workspaces

## Architecture

The toolset uses git worktrees to maintain separate working directories for each OpenShift version:

```text
ocp-build-data-multi/
├── config/                 # Configuration files
├── tools/                  # Command-line tools
│   ├── lib/               # Shared utility libraries
│   ├── ocp-setup         # Worktree management
│   ├── ocp-patch         # Multi-version patching
│   ├── ocp-diff          # Cross-version comparisons
│   ├── ocp-view          # Multi-version file viewing
│   ├── ocp-bulk          # Bulk git operations
│   └── ocp-hermetic      # Hermetic conversion tracking
└── worktrees/             # Git worktrees for each version
    ├── v4.17/
    ├── v4.18/
    ├── v4.19/
    ├── v4.20/
    └── v4.21/
```

## Quick Start

**Important**: All commands must be run from the `ocp-build-data-multi` project root directory.

### 1. Prerequisites

First, check if you have all required dependencies:

```bash
# Check dependencies
make check-deps

# Install missing dependencies (auto-detects OS)
make install-deps

# Or install manually for your OS:
make install-deps-macos    # macOS with Homebrew
make install-deps-ubuntu   # Ubuntu/Debian
make install-deps-rhel     # RHEL/CentOS/Fedora
```

**Required Tools:**

- bash 4.0+
- git
- yq v4.0+
- jq
- gh (GitHub CLI)

### 2. Personal Fork Setup

1. **Fork the upstream repository**: Go to <https://github.com/openshift-eng/ocp-build-data> and create a fork

2. **Configure your personal remote**:

   ```bash
   # Copy the template and edit with your GitHub username
   cp config/remotes.conf.example config/remotes.conf
   # Edit config/remotes.conf with your GitHub account details
   ```

3. **Complete setup**:

   ```bash
   # Run the complete setup process
   make setup
   ```

### 3. Initialize Worktrees

```bash
# Navigate to the project root
cd ocp-build-data-multi

# Initialize the toolset
./tools/ocp-setup clone

# Initialize worktrees for all active versions
./tools/ocp-setup init

# Check status
./tools/ocp-setup status
```

### 2. Basic Operations

```bash
# View differences across versions
./tools/ocp-diff golang-versions all
./tools/ocp-diff network-modes 4.19+

# Apply changes across multiple versions
./tools/ocp-patch hermetic 4.19,4.20,4.21

# View files across versions
./tools/ocp-view file group.yml 4.17..4.21
./tools/ocp-view yaml group.yml ".vars.GO_LATEST" all

# Bulk git operations
./tools/ocp-bulk status all
./tools/ocp-bulk commit "Remove network_mode for hermetic builds" 4.19+
```

**Note**: All examples assume you're in the `ocp-build-data-multi` directory.

## Tools Reference

### ocp-setup - Worktree Management

Initialize and manage git worktrees for multiple OpenShift versions.

```bash
# Clone the repository
ocp-setup clone

# Initialize worktrees for all versions
ocp-setup init [versions]

# Update worktrees with latest changes
ocp-setup update [versions]

# Show worktree status
ocp-setup status [versions]

# Clean up worktrees
ocp-setup clean [versions]
```

### ocp-patch - Multi-Version Patching

Apply changes across multiple OpenShift versions simultaneously.

```bash
# Convert images to hermetic builds
ocp-patch hermetic 4.19,4.20,4.21

# Set YAML values across versions
ocp-patch yaml-set ".golang_version" "1.23" "images/*.yml" 4.17..4.21

# Delete YAML keys
ocp-patch yaml-delete ".konflux.network_mode" "images/component.yml" 4.19+

# Apply custom yq scripts
ocp-patch yaml-script '.konflux.cachi2.enabled = true' "images/*.yml" all

# Apply unified diff patches
ocp-patch file-patch fix.patch 4.20,4.21

# Text replacement with sed
ocp-patch sed-replace "old-text" "new-text" 4.19+
```

### ocp-diff - Cross-Version Comparisons

Compare files and configurations across OpenShift versions.

```bash
# Compare specific files
ocp-diff file group.yml 4.17,4.20,4.21

# Compare YAML values
ocp-diff yaml group.yml ".vars.GO_LATEST" 4.17..4.21

# Compare golang versions
ocp-diff golang-versions all

# Check hermetic conversion status
ocp-diff network-modes 4.19+
ocp-diff hermetic-status all

# Compare directory contents
ocp-diff directory images/ 4.20,4.21
```

### ocp-view - Multi-Version File Viewing

View files and configurations across multiple versions with flexible output formats.

```bash
# View files across versions
ocp-view file group.yml 4.17,4.20,4.21

# View YAML values in table format
ocp-view yaml group.yml ".vars.GO_LATEST" 4.17..4.21

# View specific line ranges
ocp-view lines group.yml 10-20 all

# Search for patterns
ocp-view grep "network_mode.*open" "images/*.yml" 4.19+

# Find files matching patterns
ocp-view find "*etcd*" all

# Show comprehensive summary
ocp-view summary 4.17..4.21
```

**Output Formats:**

- `--format table` - Tabular output (default)
- `--format columns` - Column-based output
- `--format json` - JSON format for scripting

### ocp-bulk - Bulk Git Operations

Perform git operations across multiple version worktrees.

```bash
# Commit changes across versions
ocp-bulk commit "Remove network_mode for hermetic builds" 4.19,4.20,4.21

# Push changes to personal remote
ocp-bulk push 4.19+

# Create branches across versions
ocp-bulk branch hermetic-conversion 4.19,4.20,4.21

# Checkout branches
ocp-bulk checkout hermetic-conversion 4.19+

# Check git status
ocp-bulk status all

# Pull latest changes
ocp-bulk pull 4.20,4.21

# Reset changes (with confirmation)
ocp-bulk reset --hard 4.19,4.20

# Validate YAML syntax
ocp-bulk validate all
```

### ocp-hermetic - Hermetic Conversion Tracking

Track and manage the hermetic build conversion initiative across OpenShift versions.

```bash
# Show conversion status
ocp-hermetic status all

# List conversion candidates
ocp-hermetic candidates 4.19,4.20,4.21

# Show converted images
ocp-hermetic converted 4.19+

# Find images missing lockfiles
ocp-hermetic missing-lockfiles 4.19+

# Convert specific images
ocp-hermetic convert openshift-enterprise-base 4.19,4.20

# Generate comprehensive report
ocp-hermetic report 4.17..4.21

# Show conversion progress with visualization
ocp-hermetic progress all
```

**Output Formats:**

- `--format table` - Tabular output (default)
- `--format json` - JSON format
- `--format csv` - CSV format

## Version Specifications

All tools support flexible version specifications:

- **Specific versions:** `4.19,4.20,4.21`
- **Version ranges:** `4.17..4.21` (inclusive)
- **Version and above:** `4.19+` (4.19 and all newer versions)
- **All active versions:** `all`

## Configuration

### versions.conf

Defines active OpenShift versions and repository settings:

```bash
ACTIVE_VERSIONS="4.17 4.18 4.19 4.20 4.21"
REPO_URL="git@github.com:openshift-eng/ocp-build-data.git"
BASE_DIR="worktrees"
```

### Git Remotes

The toolset is configured to work with personal remotes for safe development:

- **origin:** `openshift-eng/ocp-build-data` (read-only)
- **your-username:** Personal fork for pushes and PRs (configured in `config/remotes.conf`)

## Common Workflows

### Hermetic Build Conversion

Convert images from `network_mode: open` to hermetic builds:

```bash
# 1. Check current status
ocp-hermetic status 4.19+

# 2. List conversion candidates
ocp-hermetic candidates 4.19+

# 3. Convert images to hermetic
ocp-patch hermetic 4.19,4.20,4.21

# 4. Verify conversion
ocp-hermetic progress 4.19+

# 5. Commit changes
ocp-bulk commit "Convert to hermetic builds" 4.19+

# 6. Generate report
ocp-hermetic report all
```

### Cross-Version Feature Implementation

Implement a feature across multiple OpenShift versions:

```bash
# 1. Create feature branches
ocp-bulk branch new-feature 4.19,4.20,4.21

# 2. Apply YAML changes
ocp-patch yaml-set ".feature.enabled" "true" "images/*.yml" 4.19+

# 3. Check differences
ocp-diff yaml images/component.yml ".feature.enabled" 4.19+

# 4. Validate changes
ocp-bulk validate 4.19+

# 5. Commit and push
ocp-bulk commit "Enable new feature" 4.19+
ocp-bulk push 4.19+
```

### Version Analysis and Reporting

Analyze differences and generate reports across versions:

```bash
# 1. Show comprehensive summary
ocp-view summary all

# 2. Compare golang versions
ocp-diff golang-versions all

# 3. Find version-specific files
ocp-view find "*4.21*" all

# 4. Search for patterns
ocp-view grep "specific-pattern" "**/*.yml" all

# 5. Generate hermetic conversion report
ocp-hermetic report all --format json > hermetic-report.json
```

## Advanced Features

### Dry Run Mode

All modification commands support `--dry-run` to preview changes:

```bash
ocp-patch hermetic 4.19+ --dry-run
ocp-bulk commit "Test message" all --dry-run
```

### Debug and Verbose Output

Enable detailed logging for troubleshooting:

```bash
ocp-setup init --verbose --debug
ocp-patch hermetic 4.19+ --verbose
```

### Output Formatting

Most tools support multiple output formats:

```bash
ocp-view summary all --format json
ocp-hermetic status all --format csv
ocp-diff golang-versions all --format table
```

## Dependencies

- **git** - Version control operations
- **yq** - YAML processing (v4.0+)
- **jq** - JSON processing
- **bash** - Shell scripting (v4.0+)

## Troubleshooting

### Common Issues

1. **Missing dependencies:**

   ```bash
   # Check what's missing
   make check-deps
   
   # Install missing dependencies
   make install-deps
   ```

2. **"No such file or directory" errors:**

   ```bash
   # Make sure you're in the project root directory
   cd ocp-build-data-multi
   pwd  # Should show .../ocp-build-data-multi
   ./tools/ocp-setup --help
   ```

3. **Configuration issues:**

   ```bash
   # Check overall status
   make status
   
   # Recreate personal config
   make setup-config
   ```

4. **Worktree conflicts:**

   ```bash
   ocp-setup clean all
   ocp-setup init
   ```

5. **YAML syntax errors:**

   ```bash
   ocp-bulk validate all
   ```

6. **Git remote issues:**

   ```bash
   # Check remote configuration
   ocp-setup status
   
   # Reconfigure remotes if needed
   ocp-setup update
   ```

### Getting Help

Each tool provides comprehensive help:

```bash
ocp-setup --help
ocp-patch --help
ocp-diff --help
ocp-view --help
ocp-bulk --help
ocp-hermetic --help
```

## Local Testing

### 🚀 Run All Tests (Recommended)

**Always run this before pushing:**

```bash
./test-local.sh
```

This comprehensive test runner executes all the same tests that CI runs:

- ✅ Dependency validation
- ✅ Tool functionality verification  
- ✅ Help text validation
- ✅ Configuration tests
- ✅ Linting (if tools available)

### Individual Test Categories

Before submitting PRs, you can also run individual test categories:

#### Code Quality Checks

```bash
# Run all linting checks (ShellCheck + markdownlint)
make lint

# Run only shell script linting
./scripts/lint.sh --shell-only

# Run only markdown linting
./scripts/lint.sh --markdown-only

# Auto-fix markdown issues where possible
./scripts/lint.sh --fix
```

### Dependency Validation

```bash
# Validate all dependencies are installed
make check-deps

# Check tool functionality 
make validate
```

### Pre-commit Validation

```bash
# Run all local checks before committing
make pre-commit

# This runs: lint + dependency validation
```

### Local Testing Dependencies

Install local testing tools:

```bash
# macOS
brew install shellcheck
npm install -g markdownlint-cli

# Ubuntu/Debian
sudo apt-get install shellcheck
npm install -g markdownlint-cli

# RHEL/Fedora
sudo dnf install ShellCheck
npm install -g markdownlint-cli
```

## Contributing

This toolset is designed for the OpenShift build data repository workflow. When contributing:

1. **Run local tests first**: `make pre-commit`
2. Test changes with `--dry-run` first
3. Validate YAML syntax with `ocp-bulk validate`
4. Use descriptive commit messages
5. Push to personal remotes, not origin

## License

This toolset follows the same license as the OpenShift build data repository.
