#!/usr/bin/env bash
# Common utilities for OpenShift Build Data multi-version tools

# Script directory detection
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(dirname "$LIB_DIR")"
MULTI_DIR="$(dirname "$TOOLS_DIR")"
VERSIONS_DIR="$MULTI_DIR/versions"
CONFIG_DIR="$MULTI_DIR/config"

# Load configuration
source "$CONFIG_DIR/versions.conf"
source "$CONFIG_DIR/remotes.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $*"
    fi
}

# Check if a version is active
is_active_version() {
    local version="$1"
    [[ " $ACTIVE_VERSIONS " =~ \ $version\  ]]
}

# Check if a version exists
version_exists() {
    local version="$1"
    [[ " $ALL_VERSIONS " =~ \ $version\  ]]
}

# Get version directory path
get_version_dir() {
    local version="$1"
    echo "$VERSIONS_DIR/$version"
}

# Check if worktree exists for version
worktree_exists() {
    local version="$1"
    [[ -d "$(get_version_dir "$version")" ]]
}

# Parse version range (e.g., "4.17..4.20" or "4.19+")
parse_version_range() {
    local range="$1"
    local versions=()
    
    if [[ "$range" == *".."* ]]; then
        # Range format: 4.17..4.20
        local start_version="${range%%..*}"
        local end_version="${range##*..}"
        
        for version in $ACTIVE_VERSIONS; do
            if version_ge "$version" "$start_version" && version_le "$version" "$end_version"; then
                versions+=("$version")
            fi
        done
    elif [[ "$range" == *"+" ]]; then
        # Plus format: 4.19+ (all versions >= 4.19)
        local min_version="${range%+}"
        
        for version in $ACTIVE_VERSIONS; do
            if version_ge "$version" "$min_version"; then
                versions+=("$version")
            fi
        done
    elif [[ "$range" == *","* ]]; then
        # Comma-separated: 4.17,4.19,4.21
        IFS=',' read -ra version_list <<< "$range"
        for version in "${version_list[@]}"; do
            version=$(echo "$version" | xargs) # trim whitespace
            if is_active_version "$version"; then
                versions+=("$version")
            fi
        done
    else
        # Single version
        if is_active_version "$range"; then
            versions+=("$range")
        fi
    fi
    
    printf '%s\n' "${versions[@]}"
}

# Version comparison functions
version_gt() {
    local version1="$1"
    local version2="$2"
    [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" != "$version1" ]]
}

version_ge() {
    local version1="$1"
    local version2="$2"
    [[ "$version1" == "$version2" ]] || version_gt "$version1" "$version2"
}

version_lt() {
    local version1="$1"
    local version2="$2"
    [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" == "$version1" ]] && [[ "$version1" != "$version2" ]]
}

version_le() {
    local version1="$1"
    local version2="$2"
    [[ "$version1" == "$version2" ]] || version_lt "$version1" "$version2"
}

# Validate version format
validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: $version (expected: X.Y)"
        return 1
    fi
    return 0
}

# Get git branch name for version
get_branch_name() {
    local version="$1"
    if [[ "$version" == "main" ]]; then
        echo "main"
    else
        echo "${BRANCH_PREFIX}${version}"
    fi
}

# Check if tool dependencies are installed
check_dependencies() {
    local missing_deps=()
    
    for cmd in git yq jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install the missing tools and try again"
        return 1
    fi
    
    return 0
}

# Show help for common options
show_common_help() {
    cat << EOF
Common Options:
  -h, --help     Show this help message
  -v, --verbose  Enable verbose output
  -d, --debug    Enable debug output
  --dry-run      Show what would be done without making changes

Version Specification:
  Single version:    4.19
  Multiple versions: 4.17,4.19,4.21
  Version range:     4.17..4.20
  From version up:   4.19+
  All active:        all

Examples:
  4.19           - Apply to version 4.19 only
  4.17,4.20      - Apply to versions 4.17 and 4.20
  4.17..4.20     - Apply to all versions from 4.17 to 4.20
  4.19+          - Apply to version 4.19 and all newer versions
  all            - Apply to all active versions
EOF
}