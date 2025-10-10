#!/usr/bin/env bash
# Validate all tools work correctly with mock data

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
MOCK_WORKTREES="$TESTS_DIR/mock-worktrees"

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

# Ensure we're in the project root
cd "$PROJECT_ROOT"

log_info "Validating OpenShift Build Data Multi-Version Toolset with mock data"
log_info "Project root: $PROJECT_ROOT"
log_info "Mock worktrees: $MOCK_WORKTREES"

# Check if mock data exists, create if needed
if [[ ! -d "$MOCK_WORKTREES" ]]; then
    log_info "Mock data not found, creating..."
    "$TESTS_DIR/scripts/create-mock-worktrees.sh"
fi

# Set environment to use mock data
export VERSIONS_DIR="$MOCK_WORKTREES"
export ACTIVE_VERSIONS="4.19 4.20 4.21"

log_info "Using mock data from: $VERSIONS_DIR"

# Test versions to use
TEST_VERSIONS="4.19,4.20,4.21"
TEST_VERSION_RANGE="4.19..4.21"
TEST_VERSION_PLUS="4.19+"

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Testing: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name: PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name: FAILED"
        log_error "Command: $test_command"
        ((TESTS_FAILED++))
        return 1
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Testing: $test_name"
    echo "Command: $test_command"
    
    if eval "$test_command"; then
        log_success "$test_name: PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name: FAILED"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo ""
log_info "=== Testing Help Output ==="

# Test help output for all tools
for tool in tools/ocp-*; do
    tool_name=$(basename "$tool")
    run_test "$tool_name --help" "$tool --help"
done

echo ""
log_info "=== Testing ocp-view ==="

# Test file viewing
run_test_with_output "ocp-view file group.yml" \
    "./tools/ocp-view file group.yml $TEST_VERSIONS --format table"

run_test_with_output "ocp-view yaml GO_LATEST" \
    "./tools/ocp-view yaml group.yml '.vars.GO_LATEST' $TEST_VERSIONS --format table"

run_test "ocp-view file with version range" \
    "./tools/ocp-view file group.yml $TEST_VERSION_RANGE --format table"

run_test "ocp-view with all versions" \
    "./tools/ocp-view file group.yml all --format table"

echo ""
log_info "=== Testing ocp-diff ==="

# Test file comparison
run_test_with_output "ocp-diff file group.yml" \
    "./tools/ocp-diff file group.yml $TEST_VERSIONS"

run_test_with_output "ocp-diff yaml GO_LATEST" \
    "./tools/ocp-diff yaml group.yml '.vars.GO_LATEST' $TEST_VERSIONS"

run_test "ocp-diff with version plus" \
    "./tools/ocp-diff file group.yml $TEST_VERSION_PLUS"

echo ""
log_info "=== Testing ocp-hermetic ==="

# Test hermetic analysis
run_test_with_output "ocp-hermetic status" \
    "./tools/ocp-hermetic status $TEST_VERSIONS --format table"

run_test_with_output "ocp-hermetic candidates" \
    "./tools/ocp-hermetic candidates $TEST_VERSIONS --format table"

run_test "ocp-hermetic progress" \
    "./tools/ocp-hermetic progress $TEST_VERSIONS --format table"

echo ""
log_info "=== Testing ocp-patch (dry-run) ==="

# Test YAML operations in dry-run mode
run_test "ocp-patch yaml-delete (dry-run)" \
    "./tools/ocp-patch yaml-delete '.konflux.network_mode' 'images/ose-etcd.yml' $TEST_VERSIONS --dry-run"

run_test "ocp-patch yaml-set (dry-run)" \
    "./tools/ocp-patch yaml-set '.vars.GO_LATEST' '1.25' 'group.yml' $TEST_VERSIONS --dry-run"

run_test "ocp-patch hermetic (dry-run)" \
    "./tools/ocp-patch hermetic $TEST_VERSIONS --dry-run"

echo ""
log_info "=== Testing Version Specifications ==="

# Test different version specification formats
run_test "Single version specification" \
    "./tools/ocp-view file group.yml 4.19 --format table"

run_test "Multiple versions specification" \
    "./tools/ocp-view file group.yml 4.19,4.21 --format table"

run_test "Version range specification" \
    "./tools/ocp-view file group.yml 4.19..4.21 --format table"

run_test "Version plus specification" \
    "./tools/ocp-view file group.yml 4.19+ --format table"

run_test "All versions specification" \
    "./tools/ocp-view file group.yml all --format table"

echo ""
log_info "=== Testing Error Handling ==="

# Test error conditions
run_test "Invalid version format" \
    "! ./tools/ocp-view file group.yml 'invalid-version' 2>/dev/null"

run_test "Non-existent file" \
    "! ./tools/ocp-view file 'non-existent.yml' 4.19 2>/dev/null"

run_test "Invalid YAML path" \
    "! ./tools/ocp-view yaml group.yml '.invalid.path' 4.19 2>/dev/null"

echo ""
log_info "=== Testing Output Formats ==="

# Test different output formats
run_test "Table format output" \
    "./tools/ocp-view yaml group.yml '.vars.MAJOR' $TEST_VERSIONS --format table"

run_test "JSON format output" \
    "./tools/ocp-hermetic status $TEST_VERSIONS --format json"

echo ""
log_info "=== Testing ocp-setup (configuration only) ==="

# Test setup operations that don't require actual worktrees
run_test "ocp-setup help" \
    "./tools/ocp-setup --help"

echo ""
log_info "=== Testing Mock Data Integrity ==="

# Verify mock data structure
run_test "Mock worktrees exist" \
    "test -d '$MOCK_WORKTREES'"

for version in 4.19 4.20 4.21; do
    run_test "Version $version directory exists" \
        "test -d '$MOCK_WORKTREES/$version'"
    
    run_test "Version $version has group.yml" \
        "test -f '$MOCK_WORKTREES/$version/group.yml'"
    
    run_test "Version $version has images directory" \
        "test -d '$MOCK_WORKTREES/$version/images'"
        
    run_test "Version $version has git repository" \
        "test -d '$MOCK_WORKTREES/$version/.git'"
done

echo ""
log_info "=== Test Results Summary ==="

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "Total tests:  $TOTAL_TESTS"

if [[ $TESTS_FAILED -eq 0 ]]; then
    log_success "✅ All tests passed!"
    echo ""
    log_info "The OpenShift Build Data Multi-Version Toolset is working correctly with mock data."
    echo ""
    log_info "To use mock data in your own testing:"
    echo "export VERSIONS_DIR=\"$MOCK_WORKTREES\""
    echo ""
    exit 0
else
    log_error "❌ $TESTS_FAILED test(s) failed!"
    echo ""
    log_error "Please review the failed tests above and fix any issues."
    echo ""
    exit 1
fi