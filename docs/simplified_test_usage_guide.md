# Test Factory Usage Guide (Simplified)

## Overview

Use **actual static factory methods directly** with the test container resource. UnifiedTestFactory should only be used for test-specific utilities, not as wrappers around runtime methods.

## Test Container Resource

```gdscript
const TEST_CONTAINER = preload("uid://dy6e5p5d6ax6n")
```

This pre-configured resource contains all necessary dependencies for testing.

## GBInjectable Objects - Use Direct Static Methods

### Recommended Pattern

```gdscript
# ✅ CORRECT: Use actual static factory methods
var collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)
var validator = PlacementValidator.create_with_injection(TEST_CONTAINER)
var indicator_manager = IndicatorManager.create_with_injection(TEST_CONTAINER, parent)
var logger = GBLogger.create_with_injection(TEST_CONTAINER)
```

## GBSystem Objects - Use Direct Static Methods (NEW)

All GBSystems now have static factory methods following the same pattern:

```gdscript
# ✅ CORRECT: Use actual static factory methods for systems
var building_system = BuildingSystem.create_with_injection(TEST_CONTAINER)
var manipulation_system = ManipulationSystem.create_with_injection(TEST_CONTAINER)
var targeting_system = GridTargetingSystem.create_with_injection(TEST_CONTAINER)
var injector_system = GBInjectorSystem.create_with_injection(TEST_CONTAINER)
```

### ❌ Avoid Wrapper Methods

```gdscript
# ❌ OLD WAY: Don't use wrapper methods anymore
var collision_mapper = UnifiedTestFactory.create_injectable_collision_mapper(container)
var validator = UnifiedTestFactory.create_test_placement_validator_with_injection(self, container)
```

## UnifiedTestFactory - Test Utilities Only

**ELIMINATED**: Wrapper methods for systems and injectables have been removed.

**RETAINED**: Use UnifiedTestFactory for genuine test utilities:

- **Test doubles**: `create_double_targeting_state(test)`
- **Test helpers**: `create_test_logger()`, `create_test_node2d(test)`
- **Complex setup**: Node creation, scene configuration

## Node Creation Guidelines

### Use GodotTestFactory for Basic Godot Nodes

**Always use GodotTestFactory methods when creating basic Godot nodes** as they automatically handle:
- `auto_free()` call for proper cleanup  
- Adding as child to the test suite
- Type safety with explicit type declarations

```gdscript
# ✅ CORRECT: Use GodotTestFactory for basic nodes
var node: Node2D = GodotTestFactory.create_node2d(self)
var body: StaticBody2D = GodotTestFactory.create_static_body_with_rect_shape(self)
var tile_map: TileMapLayer = GodotTestFactory.create_tile_map_layer(self)
var positioner: Node2D = GodotTestFactory.create_node2d(self)

# ❌ INCORRECT: Manual node creation
var node = auto_free(Node2D.new())  # Missing type, manual management
add_child(node)  # Manual child addition

# ❌ CRITICAL ERROR: Double add_child with GodotTestFactory
var node = GodotTestFactory.create_node2d(self)  # Already adds as child!
add_child(node)  # ERROR: Node is already a child
```

**IMPORTANT:** Never call `add_child()` on nodes created with `GodotTestFactory.create_*` methods as they automatically add the node as a child to the test suite.

### Node Creation in Test Parameters

```gdscript
# ❌ INCORRECT: Cannot call factory methods in parameters
func test_example(node: Node2D, test_parameters := [
	[GodotTestFactory.create_node2d(self)]  # This won't work
]):

# ✅ CORRECT: Create nodes in test body
func test_example(node_type: int, test_parameters := [
	[0], [1], [2]  # Use simple values in parameters
]):
	var node: Node2D
	match node_type:
		0: node = GodotTestFactory.create_node2d(self)
		1: node = GodotTestFactory.create_static_body_with_rect_shape(self)
		2: node = GodotTestFactory.create_collision_polygon(self)
```
- **Convenience methods**: System creation with test auto_free and add_child

```gdscript
# ✅ CORRECT: Use for test-specific utilities
var targeting_state = UnifiedTestFactory.create_double_targeting_state(self)
var test_logger = UnifiedTestFactory.create_test_logger()
var test_node = UnifiedTestFactory.create_test_node2d(self)

# ✅ CONVENIENCE: System factory methods that handle test lifecycle
var building_system = UnifiedTestFactory.create_building_system(self)
var manipulation_system = UnifiedTestFactory.create_manipulation_system(self)
```

## Example Test Setup

```gdscript
extends GdUnitTestSuite

const TEST_CONTAINER = preload("uid://dy6e5p5d6ax6n")

var collision_mapper: CollisionMapper
var validator: PlacementValidator
var targeting_state: GridTargetingState
var building_system: BuildingSystem

func before_test():
	# Use UnifiedTestFactory for test doubles/utilities
	targeting_state = UnifiedTestFactory.create_double_targeting_state(self)
	
	# Use actual static factory methods for GBInjectable objects
	collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)
	validator = PlacementValidator.create_with_injection(TEST_CONTAINER)
	
	# Parent node required for IndicatorManager
	var parent = UnifiedTestFactory.create_test_node2d(self)
	var indicator_manager = IndicatorManager.create_with_injection(TEST_CONTAINER, parent)
	
	# GBSystems can use static factory or convenience method
	building_system = BuildingSystem.create_with_injection(TEST_CONTAINER)
	# OR use convenience method that handles test lifecycle
	# building_system = UnifiedTestFactory.create_building_system(self)
```

## Migration Complete - Status

✅ **GBInjectable factory methods**: Simplified to container-only parameters  
✅ **GBSystem factory methods**: Added static factory methods to all systems  
✅ **Abstract validation pattern**: All systems implement `get_dependency_issues()` from base GBSystem class  
✅ **Merged validation logic**: Existing `validate()` methods merged into `get_dependency_issues()` for consistency  
✅ **UnifiedTestFactory cleanup**: Removed wrapper methods, kept test utilities  
✅ **Test container usage**: All tests use consistent TEST_CONTAINER pattern  
✅ **Test method updates**: Updated all test calls from `validate()` to `get_dependency_issues()`  
✅ **Documentation**: Updated with complete patterns  

The dependency injection and validation pattern is now fully consistent across the entire codebase, with:

- GBCompositionContainer serving as the single source of truth for all dependencies
- All GBSystems implementing abstract `get_dependency_issues()` method from base class  
- Consistent validation patterns merged from legacy `validate()` methods
- Complete elimination of duplicate validation logic

## Benefits

1. **Realistic Testing**: Tests use actual runtime code paths
2. **Single Source**: Test container configured once, used everywhere  
3. **Consistent Pattern**: All factory methods follow same signature
4. **Less Maintenance**: No wrapper methods to maintain
5. **Clear Intent**: Direct calls show exactly what's being tested
6. **Type Safety**: Full static typing and validation
7. **Complete Coverage**: Both GBInjectables and GBSystems use same pattern
8. **Abstract Validation**: Base class enforces consistent validation across all systems
