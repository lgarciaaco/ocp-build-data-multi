#!/usr/bin/env bash
# Local Test Runner for OpenShift Build Data Multi-Version Toolset
# Run all tests that the CI runs, locally before pushing

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)); }
log_error() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)); }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Test execution function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Running: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Test execution with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Running: $test_name"
    
    if eval "$test_command"; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

echo ""
echo "🧪 Running Local Tests for OpenShift Build Data Multi-Version Toolset"
echo "===================================================================="
echo ""

# 1. Dependency Checks
log_info "=== Checking Dependencies ==="
run_test "Dependencies available" "make check-deps"
echo ""

# 2. Tool Validation
log_info "=== Validating Tools ==="
run_test "All tools working" "make validate"
run_test "All tools show help" "make validate-tools"
echo ""

# 3. Makefile Targets
log_info "=== Testing Makefile Targets ==="
run_test "Makefile help" "make help"
run_test "Makefile status" "make status"
run_test "Makefile clean" "make clean"
echo ""

# 4. Linting (if tools available)
log_info "=== Linting ==="
if command -v shellcheck >/dev/null 2>&1; then
    run_test "ShellCheck" "make lint-shell"
else
    log_warning "ShellCheck not available, skipping shell linting"
fi

if command -v markdownlint >/dev/null 2>&1; then
    run_test "Markdown lint" "make lint-markdown"
else
    log_warning "markdownlint not available, skipping markdown linting"
fi
echo ""

# 5. Configuration Tests
log_info "=== Configuration Tests ==="
run_test "Configuration setup" "make setup-config"
run_test "Config file exists" "test -f config/remotes.conf"
run_test "Config file has required keys" "grep -q 'PERSONAL_REMOTE\\|GITHUB_ACCOUNT\\|UPSTREAM_REMOTE' config/remotes.conf"
echo ""

# 6. Help Text Validation
log_info "=== Help Text Validation ==="
for tool in tools/ocp-*; do
    tool_name=$(basename "$tool")
    run_test "$tool_name --help" "$tool --help"
done
echo ""

# 7. Version Specification Documentation
log_info "=== Version Specification Documentation ==="
run_test "ocp-view documents version specs" "./tools/ocp-view --help | grep -q '4.17\\|all\\|version'"
run_test "ocp-diff documents version specs" "./tools/ocp-diff --help | grep -q '4.17\\|all\\|version'"
run_test "ocp-hermetic documents version specs" "./tools/ocp-hermetic --help | grep -q '4.17\\|all\\|version'"
echo ""

# 8. Dry-run Support
log_info "=== Dry-run Support ==="
run_test "ocp-bulk supports dry-run" "./tools/ocp-bulk --help | grep -q 'dry-run'"
run_test "ocp-hermetic supports dry-run" "./tools/ocp-hermetic --help | grep -q 'dry-run'"
echo ""

# Summary
echo ""
echo "🏁 Test Results Summary"
echo "======================"
echo -e "✅ Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "❌ Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 All tests passed! Ready to push.${NC}"
    exit 0
else
    echo -e "${RED}💥 Some tests failed. Fix issues before pushing.${NC}"
    exit 1
fi