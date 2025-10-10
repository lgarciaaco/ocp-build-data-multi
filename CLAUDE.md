# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the OpenShift Build Data Multi-Version Toolset, designed for managing build metadata across multiple OpenShift Container Platform versions simultaneously using git worktrees. The repository contains:

- **Version-specific configurations**: Each version (4.12-4.21) defines image builds, RPM packages, and release settings
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
│   ├── ocp-patch         # Multi-version patching
│   ├── ocp-diff          # Cross-version comparisons
│   ├── ocp-view          # Multi-version file viewing
│   ├── ocp-bulk          # Bulk git operations
│   └── ocp-hermetic      # Hermetic conversion tracking
└── versions/               # Version-specific directories
    ├── 4.21/              # Current development version
    │   ├── group.yml      # Release-wide defaults
    │   ├── streams.yml    # Base image definitions
    │   ├── images/*.yml   # Individual image build configs
    │   └── rpms/*.yml     # RPM package configs
    └── [4.12-4.20]/       # Older supported versions
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
./tools/ocp-patch hermetic 4.19,4.20,4.21             # Convert to hermetic builds
./tools/ocp-view file group.yml 4.17..4.21             # View files across versions
./tools/ocp-bulk commit "Message" 4.19+                # Bulk git operations
```

### Version Specifications
- **Specific versions**: `4.19,4.20,4.21`
- **Version ranges**: `4.17..4.21` (inclusive)
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

# Convert images to hermetic
./tools/ocp-patch hermetic 4.19,4.20,4.21

# Verify conversion
./tools/ocp-hermetic progress 4.19+

# Commit changes
./tools/ocp-bulk commit "Convert to hermetic builds" 4.19+
```

### Cross-Version Analysis
```bash
# Compare configurations
./tools/ocp-diff yaml group.yml ".vars.GO_LATEST" all
./tools/ocp-diff network-modes 4.19+

# View summaries
./tools/ocp-view summary all --format table
```

### YAML Modification
```bash
# Set values across versions
./tools/ocp-patch yaml-set ".golang_version" "1.24" "images/*.yml" 4.19+

# Delete keys
./tools/ocp-patch yaml-delete ".konflux.network_mode" "images/component.yml" 4.19+
```

## Testing and Validation

### Validation Commands
```bash
# Validate YAML syntax
./tools/ocp-bulk validate all

# Dry run mode for all modification commands
./tools/ocp-patch hermetic 4.19+ --dry-run
./tools/ocp-bulk commit "Test" all --dry-run
```

## Dependencies

- **git**: Version control operations
- **yq**: YAML processing (v4.0+)
- **jq**: JSON processing  
- **bash**: Shell scripting (v4.0+)

## Important Notes

- Always run commands from the project root directory
- Use `--dry-run` to preview changes before applying
- Validate YAML syntax after modifications
- Push to personal remotes (configured in config/remotes.conf), never to origin
- Test hermetic build conversions in development environments before production