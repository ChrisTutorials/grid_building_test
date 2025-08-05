# Unified Test Factory Usage Guide

## Overview
The `UnifiedTestFactory` provides test doubles, helper objects, and complex test setup utilities. For GBInjectable objects, **use the actual static factory methods directly** with the test container resource instead of wrapper methods.

## Key Benefits
1. **Realistic Testing**: Use actual runtime factory methods in tests
2. **Single Source of Truth**: Test container resource configured once, used everywhere  
3. **Reduced Maintenance**: No wrapper methods to maintain
4. **Test Clarity**: Direct calls show exactly what's being tested

## GBInjectable Static Factory Methods
Each `GBInjectable` class has its own static factory method for dependency injection:

### Using Static Factory Methods Directly
```gdscript
# Load the test container resource
const TEST_CONTAINER = preload("uid://dy6e5p5d6ax6n")

# Use actual static factory methods directly
var collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)
var validator = PlacementValidator.create_with_injection(TEST_CONTAINER)
var indicator_manager = IndicatorManager.create_with_injection(TEST_CONTAINER, parent)

# For runtime code
var collision_mapper = CollisionMapper.create_with_injection(container)
var validator = PlacementValidator.create_with_injection(container)
```

### Benefits of Static Factory Methods
- **High Cohesion**: Each class owns its creation logic
- **Better Discoverability**: Factory methods are with the class they create
- **Loose Coupling**: No central factory dependency
- **Automatic Validation**: Dependencies are validated during creation
- **Single Source of Truth**: Container provides all dependencies consistently

## Quick Reference

When writing tests, use these factory methods instead of direct constructors:

### System Objects
```gdscript
# ✅ DO: Use unified factory methods
var building_system = UnifiedTestFactory.create_test_building_system(self)
var manipulation_system = UnifiedTestFactory.create_test_manipulation_system(self)
var placement_manager = UnifiedTestFactory.create_test_placement_manager(self)

# ✅ BEST: Use injectable factory methods for runtime-compatible creation
var collision_mapper = UnifiedTestFactory.create_injectable_collision_mapper(container)
var indicator_manager = UnifiedTestFactory.create_injectable_indicator_manager(self, container, parent, template)

# ❌ DON'T: Use direct constructors
var building_system = BuildingSystem.new()  # Missing dependencies!
```

### Validation Objects
```gdscript
# ✅ DO: Use unified factory methods
var placement_validator = UnifiedTestFactory.create_placement_validator(self)
var indicator_manager = UnifiedTestFactory.create_test_indicator_manager(self)

# ✅ BEST: Use injectable factory methods for runtime-compatible creation  
var placement_validator = UnifiedTestFactory.create_injectable_placement_validator(self, container, rules)

# ❌ DON'T: Create with wrong dependencies
var validator = PlacementValidator.new([], GBMessages.new(), GBDebugSettings.new())  # Wrong!
```

### Rule Objects
```gdscript
# ✅ DO: Use factory for proper initialization
var bounds_rule = UnifiedTestFactory.create_test_within_tilemap_bounds_rule()
var collision_rule = UnifiedTestFactory.create_test_collisions_check_rule()

# ❌ DON'T: Create without initialization
var rule = WithinTilemapBoundsRule.new()  # Needs initialize() call!
```

### Test Environment Objects
```gdscript
# ✅ DO: Use existing factory methods
var owner_context = UnifiedTestFactory.create_test_owner_context(self)
var targeting_state = UnifiedTestFactory.create_double_targeting_state(self)
var tile_map = UnifiedTestFactory.create_test_tile_map_layer(self)
```

## Method Categories

### Building Systems
- `create_building_system(test, container = null)`
- `create_test_building_system(test)`
- `create_manipulation_system(test, container = null)`
- `create_test_manipulation_system(test)`

### Collision Objects
- `create_collision_object_test_setups(col_objects)`
- `create_test_collision_polygon(test)`
- `create_test_object_with_circle_shape(test)`
- `create_test_static_body_with_rect_shape(test)`

### Indicators
- `create_indicator_manager(test, targeting_state = null)`
- `create_test_indicator_manager(test, targeting_state = null)`
- `create_test_indicator_rect(test, tile_size = 16)`
- `create_injectable_indicator_manager(test, container, parent, template)` ⭐ RECOMMENDED

### Placement  
- `create_placement_manager(test, targeting_state = null)`
- `create_test_placement_manager(test)`
- `create_placement_validator(test, rules = [])`
- `create_injectable_placement_validator(test, container, rules)` ⭐ RECOMMENDED

### Injectable Objects (Runtime-Compatible)
- `create_injectable_collision_mapper(container)` ⭐ NEW
- `create_injectable_test_setup_factory(container)` ⭐ NEW  
- `create_injectable_logger(container)` ⭐ NEW

### Rules
- `create_rule_check_indicator(test, rules = [])`
- `create_test_collisions_check_rule()`
- `create_test_within_tilemap_bounds_rule()`

### Targeting State
- `create_double_targeting_state(test)`
- `create_targeting_state(test, owner_context = null)`

### Utilities
- `create_test_logger()`
- `create_test_node2d(test)`
- `create_test_tile_map_layer(test)`
- `create_test_owner_context(test)`

## Migration Benefits

1. **No More Factory Confusion**: Single factory for all test objects
2. **Better Organization**: Methods grouped by functionality 
3. **Easier Discovery**: Alphabetical ordering within categories
4. **Reduced Maintenance**: One place to update constructor signatures
5. **Consistent Dependencies**: All objects get proper setup

## Usage Examples

### Basic Test Setup
```gdscript
func before_test():
    logger = UnifiedTestFactory.create_test_logger()
    targeting_state = UnifiedTestFactory.create_targeting_state(self)
    placement_manager = UnifiedTestFactory.create_placement_manager(self, targeting_state)
```

### Injectable Factory Pattern (RECOMMENDED)
```gdscript
# For runtime-compatible object creation with proper dependency injection
const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

func before_test():
    # Use injectable factory methods that match runtime patterns
    collision_mapper = UnifiedTestFactory.create_injectable_collision_mapper(TEST_CONTAINER)
    indicator_manager = UnifiedTestFactory.create_injectable_indicator_manager(self, TEST_CONTAINER, parent, template)
    placement_validator = UnifiedTestFactory.create_injectable_placement_validator(self, TEST_CONTAINER, rules)
```

### Parameterized Tests
```gdscript
func test_collision_objects(collision_object: CollisionObject2D, expected_count: int, test_parameters := [
    [UnifiedTestFactory.create_test_static_body_with_rect_shape(self), 1],
    [UnifiedTestFactory.create_test_collision_polygon(self), 1]
]):
    # Test logic here
```

### Rule Testing
```gdscript
func before_test():
    rule = UnifiedTestFactory.create_test_within_tilemap_bounds_rule()
    validator = UnifiedTestFactory.create_placement_validator(self, [rule])
```

## Migration Complete
All test files have been updated to use `UnifiedTestFactory`. The old `GBDoubleFactory` and `TestObjectFactory` classes have been removed.
