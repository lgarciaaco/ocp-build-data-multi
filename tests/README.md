# Test Fixtures and Mock Data

This directory contains test fixtures and mock data for testing the OpenShift Build Data Multi-Version Toolset.

## Structure

```text
tests/
├── README.md                   # This file
├── fixtures/                   # Static test data
│   ├── mock-configs/          # Mock configuration files
│   ├── sample-images/         # Sample image YAML files
│   └── sample-streams/        # Sample streams YAML files
├── scripts/                   # Test helper scripts
│   ├── create-mock-worktrees.sh  # Create mock git worktrees
│   ├── test-version-parsing.sh  # Test version specification parsing
│   └── validate-tools.sh       # Validate all tools work correctly
└── integration/               # Integration test data
    └── mock-versions/         # Mock version directories for testing
```

## Usage

### Running Tests with Mock Data

The mock data allows testing the toolset functionality without requiring actual OpenShift build data:

```bash
# Set environment variable to use mock data
export VERSIONS_DIR="$PWD/tests/mock-worktrees"

# Run tools with mock data
./tools/ocp-view file group.yml 4.19,4.20,4.21
./tools/ocp-diff yaml group.yml ".vars.GO_LATEST" 4.19,4.20,4.21
./tools/ocp-patch hermetic 4.19,4.20,4.21 --dry-run
```

### Creating Mock Test Environment

```bash
# Create mock worktrees for testing
./tests/scripts/create-mock-worktrees.sh

# Validate tools work with mock data
./tests/scripts/validate-tools.sh
```

## Mock Data Characteristics

The mock data is designed to:

- **Simulate real OpenShift structure**: Includes realistic `group.yml`, `streams.yml`, and image configurations
- **Test hermetic conversion scenarios**: Contains images with `network_mode: open` for conversion testing
- **Support version comparison**: Provides data across multiple versions (4.19, 4.20, 4.21)
- **Enable error testing**: Includes malformed data for error handling validation

## Test Scenarios

### Hermetic Build Conversion Testing

Mock images include:

- `ose-etcd.yml`: Has `network_mode: open` (conversion candidate)
- `openshift-enterprise-base.yml`: Already hermetic (no network_mode override)
- `cluster-monitoring-operator.yml`: Complex configuration for testing edge cases

### Version Specification Testing

Mock data supports testing:

- Single versions: `4.19`
- Multiple versions: `4.19,4.20,4.21`
- Version ranges: `4.19..4.21`
- Version-plus: `4.19+`
- All versions: `all`

### YAML Manipulation Testing

Mock files test:

- Key deletion: Removing `.konflux.network_mode`
- Value setting: Updating `.vars.GO_LATEST`
- Complex path navigation: Nested YAML structures
- Error handling: Invalid YAML and missing keys

## Maintenance

When updating the toolset:

1. **Add new test cases** for new functionality
2. **Update mock data** to reflect real-world changes
3. **Maintain version consistency** across mock data
4. **Test error scenarios** with invalid data

## Integration with CI

The mock data is used in GitHub Actions workflows:

- **Integration tests**: Test tools with realistic data without external dependencies
- **Error handling tests**: Validate graceful failure with invalid data
- **Performance tests**: Ensure tools scale with large datasets

## Contributing Test Data

When adding new test data:

1. **Follow real-world patterns** from actual OpenShift configurations
2. **Include edge cases** that stress-test the tools
3. **Document test scenarios** in comments within the mock files
4. **Ensure compatibility** across all supported versions
