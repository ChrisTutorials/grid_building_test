# Test Development Patterns - Grid Building Plugin

**Reference:** This document is referenced from [test_execution_guide.md](test_execution_guide.md) and complements [test_factory_guide.md](../project/test_factory_guide.md).

## Overview

This document provides standardized patterns for developing tests in the Grid Building Plugin using GdUnit4 and the project's factory systems.

## Test Structure Patterns

### Standard Test File Structure

```gdscript
# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# Test container for dependency injection
const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# Test subject and dependencies
var subject_under_test: ExampleClass
var dependency_1: RequiredDependency
var dependency_2: RequiredDependency

func before_test():
    # Setup using factory methods
    dependency_1 = ExampleDependency.create_with_injection(TEST_CONTAINER)
    dependency_2 = GodotTestFactory.create_node2d(self)
    
    # Create subject under test
    subject_under_test = ExampleClass.create_with_injection(TEST_CONTAINER)

func after_test():
    # Cleanup - most objects auto_free, just clear references
    subject_under_test = null

# Test functions follow...
```

### Anonymous Test Classes

Test suites should be anonymous (no `class_name` declaration) to avoid cluttering the global class symbol list:

```gdscript
# ✅ CORRECT: Anonymous test suite
extends GdUnitTestSuite

# ❌ INCORRECT: Named test suite
class_name ExampleTestSuite
extends GdUnitTestSuite
```

## Parameterized Testing Patterns

### Basic Parameterized Tests

```gdscript
@warning_ignore("unused_parameter")
func test_validation_cases(input_value: Variant, expected_valid: bool, test_parameters := [
    ["valid_input", true],
    ["invalid_input", false],
    [null, false],
    [42, true]
]):
    var result = subject_under_test.validate(input_value)
    assert_bool(result).is_equal(expected_valid)
```

### Complex Parameterized Tests

```gdscript
@warning_ignore("unused_parameter")
func test_geometry_calculations(
    shape_type: int, 
    size: Vector2, 
    expected_area: float,
    test_parameters := [
        [0, Vector2(10, 20), 200.0],    # Rectangle
        [1, Vector2(15, 0), 706.86],    # Circle (radius 15)
        [2, Vector2(8, 12), 48.0]       # Triangle
    ]
):
    var shape: Shape2D
    match shape_type:
        0: shape = GodotTestFactory.create_rectangle_shape(size)
        1: shape = GodotTestFactory.create_circle_shape(size.x)
        2: shape = create_triangle_shape(size)
    
    var area = GBGeometryMath.calculate_area(shape)
    assert_float(area).is_equal_approx(expected_area, 0.1)
```

### Important Parameterization Rules

- **Parameter Variable Naming**: Use `test_parameters` (not `_test_parameters`)
- **Factory Calls**: Never call factory methods in parameter arrays - use simple values and create objects in test body
- **Type Safety**: Use static typing for all parameter variables

## Node Lifecycle Management

### Automatic Lifecycle (Preferred)

```gdscript
func before_test():
    # GodotTestFactory handles auto_free and add_child automatically
    var node: Node2D = GodotTestFactory.create_node2d(self)
    var body: StaticBody2D = GodotTestFactory.create_static_body_with_rect_shape(self)
    
    # NEVER call add_child on GodotTestFactory results
    # add_child(node)  # ❌ ERROR: Node is already a child
```

### Manual Lifecycle (When Needed)

```gdscript
func before_test():
    # Manual creation when you need control over lifecycle
    var node: Node2D = auto_free(Node2D.new())
    add_child(node)
    
    # Or when using objects that don't extend Node
    var data_object = auto_free(SomeRefCountedClass.new())
```

## Assertion Patterns

### Standard Assertions

```gdscript
# Object assertions
assert_object(result).is_not_null()
assert_object(result).is_instanceof(ExpectedType)
assert_object(actual).is_equal(expected)
assert_object(actual).is_same(expected)  # Reference equality

# Collection assertions
assert_array(result).is_empty()
assert_array(result).has_size(expected_size)
assert_array(result).contains([expected_item])

# Numeric assertions
assert_int(result).is_equal(expected)
assert_float(result).is_equal_approx(expected, tolerance)
assert_bool(result).is_true()

# String assertions  
assert_str(result).is_equal(expected)
assert_str(result).contains("substring")
```

### Assertion Messages

Use `append_failure_message()` for complex logic or non-obvious failures:

```gdscript
assert_bool(validation_result).append_failure_message(
    "Validation failed: %s" % validation_errors
).is_true()

assert_array(collision_results).append_failure_message(
    "Expected collision at tile %s but found %s" % [expected_tile, actual_tiles]
).is_not_empty()
```

## Dependency Injection in Tests

### Production Object Creation

```gdscript
# ✅ PREFERRED: Use actual static factory methods
var collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)
var validator = PlacementValidator.create_with_injection(TEST_CONTAINER)
var system = BuildingSystem.create_with_injection(TEST_CONTAINER)

# ❌ AVOID: Manual construction with separate dependency setup
var mapper = CollisionMapper.new()
mapper._logger = GBLogger.new()  # Accessing private members
mapper._targeting_state = create_targeting_state()  # Manual setup
```

### Test Double Usage

Only use test doubles when necessary for isolation:

```gdscript
# ✅ CORRECT: Test doubles for external dependencies
var mock_targeting_state = UnifiedTestFactory.create_double_targeting_state(self)

# ✅ CORRECT: Real objects for internal testing
var collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)
```

## Validation Testing Patterns

### Standard Validation Tests

```gdscript
func test_get_runtime_issues():
    # Test with valid setup
    var issues = subject_under_test.get_runtime_issues()
    assert_array(issues).is_empty()
    
    # Test with missing dependencies
    subject_under_test._required_dependency = null
    issues = subject_under_test.get_runtime_issues()
    assert_array(issues).is_not_empty()
    assert_array(issues).contains(["Required dependency not set"])
```

### Rule Validation Tests

```gdscript
func test_placement_rule_validation():
    var rule = TestPlacementRule.new()
    var params = create_valid_validation_params()
    
    var result = rule.check_valid(params)
    assert_object(result).is_instanceof(RuleCheckResult)
    assert_bool(result.is_successful).is_true()
    
    # Test failure case
    params.target_tile = Vector2i(-1, -1)  # Invalid position
    result = rule.check_valid(params)
    assert_bool(result.is_successful).is_false()
    assert_str(result.reason).contains("invalid position")
```

## Error Testing Patterns

### Exception Testing

```gdscript
func test_error_conditions():
    # Test that invalid input throws appropriate errors
    assert_error(func(): subject_under_test.process_invalid_data(null))
    
    # Test specific error messages
    var error_caught = false
    try:
        subject_under_test.risky_operation()
    except:
        error_caught = true
    
    assert_bool(error_caught).is_true()
```

### Logging Verification

```gdscript
func test_error_logging():
    var logger = TEST_CONTAINER.get_logger()
    var initial_error_count = logger.error_count
    
    subject_under_test.operation_that_should_log_error()
    
    assert_int(logger.error_count).is_greater(initial_error_count)
```

## Performance Testing Patterns

### Benchmark Tests

```gdscript
func test_geometry_calculation_performance():
    var start_time = Time.get_time_dict_from_system()
    var iterations = 1000
    
    for i in iterations:
        var result = GBGeometryMath.complex_calculation(test_data)
    
    var end_time = Time.get_time_dict_from_system()
    var duration_ms = (end_time.msec - start_time.msec)
    
    # Ensure operation completes within reasonable time
    assert_int(duration_ms).is_less(100)  # 100ms for 1000 iterations
```

## Integration Testing Patterns

### System Integration

```gdscript
func test_building_to_manipulation_flow():
    # Setup complete system stack
    var building_system = BuildingSystem.create_with_injection(TEST_CONTAINER)
    var manipulation_system = ManipulationSystem.create_with_injection(TEST_CONTAINER)
    
    # Test complete workflow
    var placeable = TestSceneLibrary.simple_building
    building_system.selected_placeable = placeable
    
    var built_object = building_system.try_build()
    assert_object(built_object).is_not_null()
    
    # Test manipulation of built object
    manipulation_system.set_target(built_object)
    var manipulation_data = manipulation_system.try_move()
    assert_object(manipulation_data).is_instanceof(ManipulationData)
```

## Debug Test Patterns

### Temporary Debug Tests

```gdscript
func test_debug_specific_issue():
    # Mark as debug test with clear purpose
    # TODO: Remove after fixing issue #123
    
    var test_case = create_problematic_scenario()
    var result = subject_under_test.process(test_case)
    
    # Add detailed logging for debugging
    print("Debug: Input = %s" % test_case)
    print("Debug: Result = %s" % result)
    
    assert_object(result).is_not_null()
```

### Analysis Tests

```gdscript
func test_analyze_collision_behavior():
    # Analysis test - not a pass/fail test, just data collection
    var collision_scenarios = create_collision_test_cases()
    
    for scenario in collision_scenarios:
        var result = analyze_collision_scenario(scenario)
        print("Scenario: %s -> Result: %s" % [scenario.name, result])
    
    # No assertions - just data analysis
```

---

**Related Documents:**

- [test_execution_guide.md](test_execution_guide.md) - Test execution instructions
- [test_factory_guide.md](../project/test_factory_guide.md) - Factory usage patterns
- [copilot-gdscript-conventions.md](../copilot-gdscript-conventions.md) - GDScript coding standards
- [copilot-instructions.md](../copilot-instructions.md) - Master project instructions
