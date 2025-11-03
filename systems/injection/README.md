# Injection System Tests

3-hybrid test structure for the GBInjectorSystem dependency injection component.

## Structure

```
injection/
├── unit/                                    # Component tests with mocked DI
│   └── managers/                            # Manager component tests
│       ├── gb_test_injector_system_test.gd
│       └── test_container_cache_reset.gd
├── integration/                             # System-level workflow tests
│   └── test_injector_duplication.gd
└── regressions/                             # Bug reproduction tests
    └── (none currently)
```

## Mirror Structure

Tests mirror the runtime addon component hierarchy:

**Runtime Components** (`godot/addons/grid_building/systems/injection/`):

- `gb_injector_system.gd` → unit/managers/

## Test Distribution

- **Unit Tests**: 2 tests - Fast, isolated component validation
- **Integration Tests**: 1 test - System-level behavior
- **Regression Tests**: 0 tests - (add as bugs are found)

## Running Tests

```bash
# Run all injection tests
./scripts/testing/run_tests.sh --individual test/grid_building_test/systems/injection/

# Run by category
./scripts/testing/run_all_unit_tests.sh         # Includes injection unit tests
./scripts/testing/run_all_integration_tests.sh  # Includes injection integration tests
./scripts/testing/run_all_regressions.sh        # Includes injection regressions
```

## Test Validation

Verify structure compliance:

```bash
python3 scripts/code_quality/test_suite_validator.py --system injection
```

## Helper Files

- `utilities/injection/gb_test_injector_system.gd` - Test utility (not a test itself)
