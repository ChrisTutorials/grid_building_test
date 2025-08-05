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
✅ **Abstract validation pattern**: All systems implement `validate_dependencies()` from base GBSystem class  
✅ **Merged validation logic**: Existing `validate()` methods merged into `validate_dependencies()` for consistency  
✅ **UnifiedTestFactory cleanup**: Removed wrapper methods, kept test utilities  
✅ **Test container usage**: All tests use consistent TEST_CONTAINER pattern  
✅ **Test method updates**: Updated all test calls from `validate()` to `validate_dependencies()`  
✅ **Documentation**: Updated with complete patterns  

The dependency injection and validation pattern is now fully consistent across the entire codebase, with:

- GBCompositionContainer serving as the single source of truth for all dependencies
- All GBSystems implementing abstract `validate_dependencies()` method from base class  
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
