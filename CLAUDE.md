# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the OpenShift Build Data Multi-Version Toolset, designed for managing build metadata across multiple OpenShift Container Platform versions simultaneously using git worktrees. The repository contains:

- **Version-specific configurations**: Each version (4.12-4.22) defines image builds, RPM packages, and release settings
- **Multi-version management tools**: Command-line utilities for applying changes across versions without branch switching
- **Hermetic build conversion tracking**: Tools for converting images from network mode to hermetic builds

## Core Architecture

### Directory Structure
```
ocp-build-data-multi/
├── config/                 # Configuration files
│   ├── versions.conf       # Active versions and repo settings
│   └── remotes.conf        # Git remote configuration
├── tools/                  # Command-line utilities
│   ├── lib/               # Shared libraries (common.sh, git-utils.sh, yaml-utils.sh)
│   ├── ocp-setup         # Worktree management
│   ├── ocp-migrate       # Multi-version migration and patching
│   ├── ocp-diff          # Cross-version comparisons
│   ├── ocp-view          # Multi-version file viewing
│   └── ocp-hermetic      # Hermetic conversion tracking
└── versions/               # Version-specific directories
    ├── 4.22/              # Current development version
    │   ├── group.yml      # Release-wide defaults
    │   ├── streams.yml    # Base image definitions
    │   ├── images/*.yml   # Individual image build configs
    │   └── rpms/*.yml     # RPM package configs
    └── [4.12-4.21]/       # Older supported versions
```

### Key Configuration Files
- **group.yml**: Defines release-wide settings including `network_mode: hermetic` default
- **streams.yml**: Base image streams and golang version configurations
- **images/*.yml**: Individual image build configurations with potential `konflux: network_mode: open` overrides

## Essential Commands

### Setup and Management
```bash
# Install dependencies and setup
make setup                   # Complete setup process
make check-deps             # Check dependencies
make install-deps           # Install missing dependencies

# Initialize worktrees (run from project root)
./tools/ocp-setup clone      # First-time setup
./tools/ocp-setup init       # Initialize all active versions
./tools/ocp-setup status     # Check worktree status

# Cross-version operations
./tools/ocp-diff golang-versions all                    # Compare golang versions
./tools/ocp-migrate bulk 4.21 4.19,4.20               # Convert to hermetic builds
./tools/ocp-view file group.yml 4.17..4.22             # View files across versions
```

### Version Specifications
- **Specific versions**: `4.20,4.21,4.22`
- **Version ranges**: `4.17..4.22` (inclusive)
- **Version and above**: `4.19+`
- **All active versions**: `all`

## Development Workflow

### Working Directory Requirement
**CRITICAL**: All commands must be run from the `ocp-build-data-multi` project root directory. The tools use relative paths and will fail if run from subdirectories.

### Git Remote Configuration
- **origin**: `openshift-eng/ocp-build-data` (read-only)
- **personal-remote**: Personal fork for development (configured via `config/remotes.conf`)

### Branch Structure
- **Main branch**: `main` (development)
- **Release branches**: `openshift-{MAJOR}.{MINOR}` (e.g., `openshift-4.21`)

## Key Concepts

### Hermetic Build Conversion
The primary ongoing initiative is converting images from `network_mode: open` to hermetic builds:

1. **Default behavior**: `group.yml` sets `network_mode: hermetic` for all images
2. **Override pattern**: Some images have `konflux: network_mode: open` to bypass hermetic mode
3. **Conversion process**: Remove the override to use the default hermetic setting
4. **Dependencies**: Hermetic builds require cachi2 lockfiles for dependency caching

### Multi-Architecture Support
All builds support: x86_64, aarch64, ppc64le, s390x

### Build System Integration
- **Konflux**: New build system with hermetic capabilities
- **Cachi2**: Dependency caching system for hermetic builds
- **Multi-arch**: Architecture-specific build configurations

## Common Operations

### Hermetic Build Conversion Workflow
```bash
# Check current hermetic status
./tools/ocp-hermetic status 4.19+

# Detect images needing migration from current to older versions
./tools/ocp-migrate detect 4.22 4.19,4.20,4.21

# Migrate hermetic configs from source to target versions
./tools/ocp-migrate bulk 4.22 4.19,4.20,4.21

# Verify conversion progress
./tools/ocp-hermetic progress 4.19+

```

### Cross-Version Analysis
```bash
# Compare configurations
./tools/ocp-diff yaml group.yml ".vars.GO_LATEST" all
./tools/ocp-diff network-modes 4.19+

# View summaries
./tools/ocp-view summary all --format table
```

### Migration Operations
```bash
# Show differences between versions for specific image
./tools/ocp-migrate diff image-name 4.22 4.21

# Apply migration for single image
./tools/ocp-migrate apply image-name 4.22 4.21

# Validate working directory changes
./tools/ocp-migrate validate 4.21
```

## Testing and Validation

### Validation Commands
```bash
# Dry run mode for all migration commands
./tools/ocp-migrate bulk 4.22 4.19+ --dry-run

# Check dependencies
make check-deps

# Validate tools are working
make validate
```

## Dependencies

- **git**: Version control operations
- **yq**: YAML processing (v4.0+)
- **jq**: JSON processing  
- **bash**: Shell scripting (v4.0+)
- **gh**: GitHub CLI
- **yamlfmt**: YAML formatting tool

## Important Notes

- Always run commands from the project root directory
- Use `--dry-run` to preview changes before applying
- Validate YAML syntax after modifications
- Push to personal remotes (configured in config/remotes.conf), never to origin
- Test hermetic build conversions in development environments before production