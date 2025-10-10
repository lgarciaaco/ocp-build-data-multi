#!/usr/bin/env bash
# Local linting script for OpenShift Build Data Multi-Version Toolset

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Change to project root
cd "$PROJECT_ROOT"

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v shellcheck &> /dev/null; then
        missing_deps+=("shellcheck")
    fi
    
    if ! command -v markdownlint &> /dev/null; then
        missing_deps+=("markdownlint")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                shellcheck)
                    log_info "  macOS: brew install shellcheck"
                    log_info "  Ubuntu: apt-get install shellcheck"
                    log_info "  RHEL/Fedora: dnf install ShellCheck"
                    ;;
                markdownlint)
                    log_info "  npm: npm install -g markdownlint-cli"
                    ;;
            esac
        done
        return 1
    fi
    
    return 0
}

# Run ShellCheck on shell scripts
lint_shell() {
    log_info "Running ShellCheck on shell scripts..."
    
    local shell_files=()
    
    # Find shell scripts
    while IFS= read -r -d '' file; do
        shell_files+=("$file")
    done < <(find tools/ -type f \( -name "*.sh" -o -executable \) -print0)
    
    if [[ ${#shell_files[@]} -eq 0 ]]; then
        log_warning "No shell scripts found"
        return 0
    fi
    
    local failed=0
    for file in "${shell_files[@]}"; do
        log_info "Checking $file"
        if ! shellcheck "$file"; then
            log_error "ShellCheck failed for $file"
            failed=1
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        log_success "ShellCheck passed for all files"
        return 0
    else
        log_error "ShellCheck failed for some files"
        return 1
    fi
}

# Run markdownlint
lint_markdown() {
    log_info "Running markdownlint on markdown files..."
    
    local md_files=()
    while IFS= read -r -d '' file; do
        md_files+=("$file")
    done < <(find . -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*" -print0)
    
    if [[ ${#md_files[@]} -eq 0 ]]; then
        log_warning "No markdown files found"
        return 0
    fi
    
    if markdownlint -c .markdownlint.json "${md_files[@]}"; then
        log_success "Markdown linting passed"
        return 0
    else
        log_error "Markdown linting failed"
        log_info "Fix markdown issues or update .markdownlint.json configuration"
        return 1
    fi
}

# Main function
main() {
    local run_shell=true
    local run_markdown=true
    local fix_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --shell-only)
                run_markdown=false
                shift
                ;;
            --markdown-only)
                run_shell=false
                shift
                ;;
            --fix)
                fix_mode=true
                shift
                ;;
            --help|-h)
                cat << EOF
Local linting script for OpenShift Build Data Multi-Version Toolset

Usage: $0 [OPTIONS]

Options:
  --shell-only      Run only ShellCheck
  --markdown-only   Run only markdown linting
  --fix             Attempt to fix issues automatically (markdownlint only)
  --help, -h        Show this help message

Examples:
  $0                    # Run all linting
  $0 --shell-only       # Run only ShellCheck
  $0 --markdown-only    # Run only markdown linting
  $0 --fix              # Run linting and attempt fixes

Dependencies:
  - shellcheck: Shell script linting
  - markdownlint: Markdown linting (npm install -g markdownlint-cli)
EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "Starting local linting checks..."
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    local exit_code=0
    
    # Run shell linting
    if [[ "$run_shell" == true ]]; then
        if ! lint_shell; then
            exit_code=1
        fi
    fi
    
    # Run markdown linting
    if [[ "$run_markdown" == true ]]; then
        if [[ "$fix_mode" == true ]]; then
            log_info "Running markdownlint in fix mode..."
            markdownlint -c .markdownlint.json --fix *.md **/*.md 2>/dev/null || true
        fi
        
        if ! lint_markdown; then
            exit_code=1
        fi
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "All linting checks passed!"
    else
        log_error "Some linting checks failed"
    fi
    
    exit $exit_code
}

# Run main function with all arguments
main "$@"