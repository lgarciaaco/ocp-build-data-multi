#!/usr/bin/env bash
# Create mock worktree structure for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
MOCK_WORKTREES="$TESTS_DIR/mock-worktrees"

echo "Creating mock worktree structure..."

# Clean up existing mock worktrees
rm -rf "$MOCK_WORKTREES"

# Create mock version directories
VERSIONS=(4.19 4.20 4.21)
for version in "${VERSIONS[@]}"; do
    version_dir="$MOCK_WORKTREES/$version"
    echo "Creating mock version $version at $version_dir"
    
    mkdir -p "$version_dir"
    cd "$version_dir"
    
    # Initialize git repository
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create directory structure
    mkdir -p images rpms
    
    # Create version-specific group.yml
    cat > group.yml << EOF
# Mock group.yml for version $version
freeze_automation: false

vars:
  MAJOR: 4
  MINOR: ${version#*.}
  IMPACT: Low
  CVES: None
  RHCOS_EL_MAJOR: 9
  RHCOS_EL_MINOR: 6
  GO_LATEST: "1.24"
  GO_EXTRA: "1.24"

konflux:
  network_mode: hermetic
  arches:
  - x86_64
  - aarch64
  - s390x  
  - ppc64le
  cachi2:
    enabled: true
    gomod_version_patch: true
    lockfile:
      force: true

multi_arch:
  enabled: true
EOF

    # Copy base streams.yml
    cp "$TESTS_DIR/fixtures/mock-configs/streams.yml" streams.yml
    
    # Create version-specific image files
    cp "$TESTS_DIR/fixtures/sample-images/ose-etcd.yml" images/
    cp "$TESTS_DIR/fixtures/sample-images/openshift-enterprise-base.yml" images/
    cp "$TESTS_DIR/fixtures/sample-images/cluster-monitoring-operator.yml" images/
    
    # Update branch targets in image files for this version
    sed -i.bak "s/release-4.21/release-$version/g" images/*.yml
    sed -i.bak "s/rhaos-4.21-rhel-9/rhaos-$version-rhel-9/g" images/*.yml
    rm -f images/*.yml.bak
    
    # Create additional test images for this version
    cat > "images/test-image-$version.yml" << EOF
# Test image specific to version $version
name: test-image-$version
content:
  source:
    git:
      url: git@github.com:openshift-priv/test-$version.git
      branch:
        target: release-$version
from:
  stream: rhel-9-golang
konflux:
  network_mode: open
  cachi2:
    enabled: true
EOF

    # Create some RPM files
    cat > rpms/test-rpm.yml << EOF
# Test RPM for version $version
name: test-rpm
version: "$version.0"
release: "1.el9"
summary: "Test RPM for OpenShift $version"
source:
  git:
    url: git@github.com:openshift-priv/test-rpm.git
    branch:
      target: release-$version
EOF

    # Create files to test different scenarios
    
    # Image that's already hermetic (no network_mode)
    cat > images/already-hermetic.yml << EOF
name: already-hermetic
content:
  source:
    git:
      url: git@github.com:openshift-priv/hermetic.git
from:
  stream: rhel-9-base
konflux:
  cachi2:
    enabled: true
EOF

    # Image with complex nested configuration
    cat > images/complex-nested.yml << EOF
name: complex-nested
content:
  source:
    git:
      url: git@github.com:openshift-priv/complex.git
from:
  builder:
  - stream: rhel-9-golang
  member: openshift-enterprise-base
konflux:
  network_mode: open
  cachi2:
    enabled: true
    lockfile:
      rpms:
      - golang
      - make
  multiarch:
    enabled: true
    exclude_arches:
    - s390x
  sast:
    enabled: true
    config:
      rules:
        - security
        - performance
EOF

    # Commit all files
    git add .
    git commit -m "Initial mock data for version $version"
    
    # Create a test branch
    git checkout -b "feature/test-branch"
    echo "# Test branch content" > test-branch-file.txt
    git add test-branch-file.txt
    git commit -m "Test branch commit"
    git checkout main
    
    echo "✅ Created mock version $version"
done

echo ""
echo "✅ Mock worktree structure created successfully!"
echo "Mock worktrees location: $MOCK_WORKTREES"
echo ""
echo "To use mock data in tests, set:"
echo "export VERSIONS_DIR=\"$MOCK_WORKTREES\""
echo ""
echo "Available versions: ${VERSIONS[*]}"
echo "Each version includes:"
echo "  - group.yml (version-specific configuration)"
echo "  - streams.yml (base image definitions)"
echo "  - images/ directory with test images"
echo "  - rpms/ directory with test RPMs"
echo "  - Git repository with commits and branches"