# Manipulation System Tests

Tests for the Manipulation System (`godot/addons/grid_building/systems/manipulation/`).

## Structure

- **unit/** - Unit tests for individual components (validators, managers, handlers)
- **integration/** - Integration tests for system workflows and interactions
- **regressions/** - Regression tests for specific bug fixes

## Running Tests

```bash
# Run all manipulation tests
./scripts/testing/run_tests.sh --individual \
  test/grid_building_test/systems/manipulation/

# Run only unit tests
./scripts/testing/run_tests.sh --individual \
  test/grid_building_test/systems/manipulation/unit/

# Run only integration tests
./scripts/testing/run_tests.sh --individual \
  test/grid_building_test/systems/manipulation/integration/

# Run only regression tests
./scripts/testing/run_tests.sh --individual \
  test/grid_building_test/systems/manipulation/regressions/

# Run with failures-only mode
./scripts/testing/run_tests.sh --individual \
  test/grid_building_test/systems/manipulation/ --failures-only
```

## Test Coverage

### Unit Tests

- **validators/** - `ManipulationValidator` error handling and validation logic
- **managers/** - Workflow managers (move, placement, demolish)
- **handlers/** - Transform handler (rotation/flip operations)

### Integration Tests

- System-level workflows (move, placement, cancellation)
- State machine transitions
- Object manipulation and deletion

### Regression Tests

- Collision exclusion during moves
- Rotation transfer between objects
- Validation gating
- Positioner bounds handling
- Data reassignment edge cases

## Related Documentation

- [TEST_REORGANIZATION_PLAN.md](./TEST_REORGANIZATION_PLAN.md) - Reorganization strategy and patterns
- [Main test organization analysis](/docs/TEST_FOLDER_ORGANIZATION_ANALYSIS.md)
