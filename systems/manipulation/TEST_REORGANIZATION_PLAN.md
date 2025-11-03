# Test Suite Reorganization Plan — Manipulation System

**Goal**: Restructure test hierarchy to leverage dependency injection pattern for
faster, clearer tests.

---

## Current Test Structure Issues

### Scattered Locations

```
godot/test/grid_building_test/
├── regressions/manipulation/         # 6 regression tests
├── integration/system_interactions/  # 8 integration tests
├── placement/                        # 1 manipulation test
├── manipulation/                     # 1 isometric test
└── utilities/                        # 1 transform calculator test
```

**Problem**: Manipulation tests spread across 5 different directories

### Test Type Confusion

Many "integration" tests could now be **unit tests** with DI pattern:

- `manipulation_orchestrator_unit_test.gd` - ✅ Already deleted (component removed)
- `manipulation_system_environment_test.gd` - Could be split into unit + integration
- `manipulation_state_machine_test.gd` - Pure logic, good candidate for unit test

---

## Proposed New Structure

```gdscript
godot/test/grid_building_test/manipulation/
├── unit/
│   ├── validators/
│   │   ├── manipulation_validator_unit_test.gd
│   │   └── move_setup_validation_test.gd
│   ├── managers/
│   │   ├── move_workflow_manager_unit_test.gd
│   │   ├── placement_manager_unit_test.gd
│   │   ├── demolish_manager_unit_test.gd
│   │   └── transform_handler_unit_test.gd
│   └── utilities/
│       └── manipulation_transform_calculator_test.gd
├── integration/
│   ├── manipulation_system_workflow_test.gd
│   ├── manipulation_move_workflow_test.gd
│   ├── manipulation_placement_workflow_test.gd
│   └── manipulation_source_deletion_test.gd
├── regressions/
│   ├── manipulation_rotation_transfer_test.gd
│   ├── manipulation_cancel_method_regression_test.gd
│   ├── manipulation_data_reassignment_regression_test.gd
│   ├── manipulation_move_collision_exclusion_regression_test.gd
│   ├── manipulation_move_positioner_outside_bounds_test.gd
│   └── manipulation_validation_gating_regression_test.gd
└── e2e/
    └── manipulation_full_workflow_test.gd
```

---

## Test Migration Guide

### Unit Tests (NEW with DI Pattern)

**Create these new unit tests** to verify component logic in isolation:

#### ManipulationValidator Unit Tests

```gdscript
## Unit test: ManipulationValidator.validate_move_setup()
extends GdUnitTestSuite

var _validator: ManipulationValidator
var _mock_settings: ManipulationSettings
var _mock_states: GBStates
var _mock_indicator_context: IndicatorContext


func before_test() -> void:
    _mock_settings = auto_free(ManipulationSettings.new())
    _mock_settings.failed_object_not_manipulatable = \
        "Object %s not manipulatable"

    _mock_states = auto_free(GBStates.new())
    _mock_indicator_context = auto_free(IndicatorContext.new())

    _validator = auto_free(ManipulationValidator.new(
        _mock_settings,
        _mock_states,
        _mock_indicator_context
    ))


func test_validate_move_setup_rejects_null_root() -> void:
    var result = _validator.validate_move_setup(null)

    assert_string(result).append_failure_message(
        "Should reject null root with error message"
    ).is_equal("Cannot move null root")


func test_validate_move_setup_accepts_valid_manipulatable() -> void:
    # Setup mock manipulatable
    var mock_manipulatable = Manipulatable.new()
    mock_manipulatable.settings = ManipulatableSettings.new()
    mock_manipulatable.settings.can_move = true

    var result = _validator.validate_move_setup(mock_manipulatable)

    assert_object(result).append_failure_message(
        "Should accept valid manipulatable (return null error)"
    ).is_null()
```

**Benefits**:

- Fast (<50ms per test)
- No scene_runner overhead
- Tests single component in isolation
- Easy to mock edge cases

#### MoveWorkflowManager Unit Tests

```gdscript
## Unit test: MoveWorkflowManager.start_move()
extends GdUnitTestSuite

var _manager: MoveWorkflowManager
# ... mock dependencies ...


func test_start_move_requires_valid_data() -> void:
    var invalid_data = ManipulationData.new(
        null, null, null, GBEnums.Action.MOVE
    )

    var success = _manager.start_move(invalid_data, Callable())

    assert_bool(success).append_failure_message(
        "Should fail with invalid data"
    ).is_false()
```

### Integration Tests (Keep scene_runner)

**Keep these as integration tests** - they validate component interactions:

- `manipulation_system_workflow_test.gd` - Full system coordination
- `manipulation_move_workflow_test.gd` - Move copy + indicators + placement
- `manipulation_source_deletion_test.gd` - Signal handling across systems

**Pattern**:

```gdscript
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: ManipulationTestEnvironment
var _system: ManipulationSystem


func before_test() -> void:
    runner = scene_runner(
        GBTestConstants.MANIPULATION_TEST_ENV.resource_path
    )
    runner.simulate_frames(1)
    env = runner.scene() as ManipulationTestEnvironment
    _system = env.get_manipulation_system()


func test_move_workflow_creates_indicators() -> void:
    var source = env.create_test_placeable(Vector2(100, 100))

    var move_data = _system.try_move(source)

    assert_bool(move_data.is_valid()).is_true()
    assert_object(move_data.move_copy).is_not_null()
```

### Regression Tests (Move to regression/)

**Keep all regression tests** in one place with clear bug reference:

```gdscript
## Regression Test: GH-XXX - Rotation transfer bug
##
## ISSUE: Rotation during move was not persisting to placed object
## ROOT CAUSE: ManipulationParent.reset() cleared transforms before
##   application
## FIX: Capture transforms BEFORE reset, apply to source object
```

---

## Migration Checklist

### Phase 1: Create Unit Test Structure

- [ ] Create `manipulation/unit/validators/` directory
- [ ] Create `manipulation/unit/managers/` directory
- [ ] Create `manipulation_validator_unit_test.gd` (new)
- [ ] Create `move_workflow_manager_unit_test.gd` (new)
- [ ] Create `placement_manager_unit_test.gd` (new)
- [ ] Create `demolish_manager_unit_test.gd` (new)
- [ ] Create `transform_handler_unit_test.gd` (new)

### Phase 2: Move Existing Tests

- [ ] Move `utilities/manipulation_transform_calculator_test.gd` → `unit/utilities/`
- [ ] Move integration tests from `integration/system_interactions/` →
      `manipulation/integration/`
- [ ] Move regression tests from `regressions/manipulation/` →
      `manipulation/regressions/`
- [ ] Move `placement/manipulation_move_positioner_regression_test.gd` →
      `manipulation/regressions/`

### Phase 3: Convert Integration → Unit (Where Appropriate)

**Candidates for unit test conversion:**

- `manipulation_state_machine_test.gd` - Pure logic, no scene needed
- `manipulation_cancellation_unit_test.gd` - Already labeled "unit", verify
  it uses DI

**Keep as integration:**

- `manipulation_system_environment_test.gd` - Tests full system setup
- `manipulation_source_deletion_test.gd` - Tests signal handling
- `manipulation_rotation_workflow_test.gd` - Tests complete rotation workflow

### Phase 4: Run & Verify

- [ ] Run all unit tests:
      `./scripts/testing/run_tests.sh --individual godot/test/grid_building_test/manipulation/unit/`
- [ ] Run all integration tests:
      `./scripts/testing/run_tests.sh --individual godot/test/grid_building_test/manipulation/integration/`
- [ ] Run all regression tests:
      `./scripts/testing/run_tests.sh --individual godot/test/grid_building_test/manipulation/regressions/`
- [ ] Verify no tests skipped or broken

---

## Expected Outcomes

### Test Speed Improvements

| Test Type | Before (avg) | After (target) | Improvement |
|-----------|--------------|----------------|-------------|
| Unit tests | N/A (didn't exist) | <50ms | NEW |
| Integration tests | 500-1000ms | 500-1000ms | Same (appropriate) |
| Regression tests | 500-1000ms | 500-1000ms | Same (appropriate) |

**Total suite**: Expect 20-30% faster with new unit tests replacing some
integration tests

### Test Clarity Improvements

- **Clear hierarchy**: Unit → Integration → Regression → E2E
- **Focused tests**: Each test verifies one component or interaction
- **Easy to find**: All manipulation tests in one `/manipulation/` directory
- **Mocking examples**: Unit tests demonstrate DI pattern usage

---

## Related Documentation

- **Testing Essentials**: `.github/instructions/docs/testing_essentials.md`
- **DI Pattern Guide**: See "Dependency Injection Testing" section
- **Mocking Best Practices**: When to mock vs use scene_runner
- **Test Factories**: `godot/test/factories/` for test object creation

---

**Last Updated**: November 3, 2025
