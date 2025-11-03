# Building System Tests

3-hybrid test structure for the BuildingSystem component hierarchy.

## Structure

```
building/
├── unit/                                    # Component tests with mocked DI
│   ├── managers/                            # Manager component tests
│   │   └── drag_manager_unit_test.gd
│   ├── handlers/                            # Handler component tests
│   │   └── indicator_generation_unit_test.gd
│   └── validators/                          # Validator component tests
│       ├── placement_report_unit_test.gd
│       └── rect4x2_bounds_validation_unit_test.gd
├── integration/                             # System-level workflow tests
│   ├── building_and_placement_tests.gd
│   ├── collision_object_resolver_test.gd
│   ├── grid_building_system_integration_test.gd
│   ├── indicator_positioning_isolation_test.gd
│   └── preview_self_collision_exclusion_test.gd
└── regressions/                             # Bug reproduction tests
    ├── drag_building_race_condition_test.gd
    ├── drag_manager_throttling_test.gd
    ├── placeable_switch_reset_test.gd
    ├── preview_name_consistency_test.gd
    └── valid_placement_tile_rule_test.gd
```

## Mirror Structure

Tests mirror the runtime addon component hierarchy:

**Runtime Components** (`godot/addons/grid_building/systems/building/components/`):

- `drag_manager.gd` → unit/managers/
- `preview_builder.gd` → (covered in integration tests)
- `building_instantiator.gd` → (covered in integration tests)

## Test Distribution

- **Unit Tests**: 4 tests - Fast, isolated component validation
- **Integration Tests**: 5 tests - Workflow and system interaction
- **Regression Tests**: 5 tests - Specific bug fixes and race conditions

## Running Tests

```bash
# Run all building tests
./scripts/testing/run_tests.sh --individual test/grid_building_test/systems/building/

# Run by category
./scripts/testing/run_all_unit_tests.sh         # Includes building unit tests
./scripts/testing/run_all_integration_tests.sh  # Includes building integration tests
./scripts/testing/run_all_regressions.sh        # Includes building regressions
```

## Test Validation

Verify structure compliance:

```bash
python3 scripts/code_quality/test_suite_validator.py --system building
```
