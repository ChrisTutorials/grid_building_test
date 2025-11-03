# Grid Targeting System Tests

3-hybrid test structure for the GridPositionerSystem and targeting component hierarchy.

## Structure

```
grid_targeting/
├── unit/                                         # Component tests with mocked DI
│   ├── handlers/                                 # Handler component tests
│   │   ├── grid_positioner_unit_test.gd
│   │   └── targeting_shape_cast_2d_unit_test.gd
│   └── validators/                               # Validator component tests
│       ├── gb_positioning_2d_utils_test.gd
│       └── gb_positioning_2d_utils_coordinate_conversion_test.gd
├── integration/                                  # System-level workflow tests
│   ├── grid_positioner_coordinate_conversion_test.gd
│   ├── grid_positioner_input_visibility_test.gd
│   ├── grid_positioner_logic_tests.gd
│   ├── grid_positioner_visibility_and_logic_test.gd
│   ├── grid_positioner_visibility_and_recentering_test.gd
│   ├── test_positioning_policies_comparison.gd
│   ├── targeting_integration_test.gd
│   └── grid_targeting_state_resolution_test.gd
└── regressions/                                  # Bug reproduction tests
    ├── grid_positioner_end_of_frame_logging_test.gd
    ├── grid_positioner_mouse_gate_test.gd
    ├── grid_positioner_reconcile_and_recenter_test.gd
    ├── grid_positioner_visibility_logic_test.gd
    ├── test_positioning_after_resolve.gd
    ├── test_positioning_policy_off_mode.gd
    └── test_visibility_off_mode.gd
```

## Mirror Structure

Tests mirror the runtime addon component hierarchy:

**Runtime Components** (`godot/addons/grid_building/systems/grid_targeting/`):

- `grid_positioner_2d.gd` → unit/handlers/ + integration tests
- `grid_targeting_state_machine.gd` → integration tests

## Test Distribution

- **Unit Tests**: 4 tests - Fast, isolated component validation
- **Integration Tests**: 8 tests - Workflow and system interaction
- **Regression Tests**: 7 tests - Edge cases and specific fixes

## Running Tests

```bash
# Run all grid_targeting tests
./scripts/testing/run_tests.sh --individual test/grid_building_test/systems/grid_targeting/

# Run by category
./scripts/testing/run_all_unit_tests.sh         # Includes grid_targeting unit tests
./scripts/testing/run_all_integration_tests.sh  # Includes grid_targeting integration tests
./scripts/testing/run_all_regressions.sh        # Includes grid_targeting regressions
```

## Test Validation

Verify structure compliance:

```bash
python3 scripts/code_quality/test_suite_validator.py --system grid_targeting
```
