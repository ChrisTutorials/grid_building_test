class_name UnifiedTestFactory
extends RefCounted

## Unified Test Factory - Comprehensive Test Environment Builder with API Compatibility
##
## CRITICAL: BREAKING CHANGES DETECTED IN GRID BUILDING SYSTEM
## This factory has been updated to handle API changes in the underlying grid_building addon.
## See the detailed breaking changes list below for required test updates.
##
## This factory provides a clean, DRY approach to creating complex test environments
## for the Grid Building system. It eliminates code duplication and ensures consistency
## across all test suites.
##
## BREAKING CHANGES DETECTED:
## 1. CollisionMapper Access: IndicatorManager.get_collision_mapper() may return null
## 2. PlacementValidator API: validate() method may not exist, replaced with try_validate()  
## 3. DragBuildManager API: is_dragging() method doesn't exist
## 4. PlacementReport API: get_error_messages() method doesn't exist
## 5. Type System: Some classes now extend RefCounted instead of Node
## 6. Array Typing: Stricter array type checking required
##
## RECOMMENDATION: Update test files to use current grid_building system API
## instead of relying on factory compatibility shims.

## Common test constants to eliminate magic numbers
const DEFAULT_TILE_SIZE := 16
const DEFAULT_SHAPE_SIZE := 32
const DEFAULT_RADIUS := 16.0
const DEMO_BUILDING_LAYER := 2560  # Match demo building collision layer
const DEMO_BUILDING_MASK := 1536   # Match demo building collision mask
const DEFAULT_TEST_POSITION := Vector2(100, 100)

## Common shape sizes
const TILE_SIZE_VEC := Vector2(DEFAULT_TILE_SIZE, DEFAULT_TILE_SIZE)
const SHAPE_SIZE_VEC := Vector2(DEFAULT_SHAPE_SIZE, DEFAULT_SHAPE_SIZE)

## Common collision layer bits
const COLLISION_LAYER_BIT_0 := 1
const COLLISION_LAYER_BIT_9 := 512

## Test environment scene UIDs
const ALL_SYSTEMS_ENV_UID := "uid://ioucajhfxc8b"
const BUILDING_TEST_ENV_UID := "uid://c4ujk08n8llv8"
const COLLISION_TEST_ENV_UID := "uid://cdrtd538vrmun"
const ISOMETRIC_BUILDING_ENV_UID := "uid://d3yeah2uexha2"

## Common test layer configurations to reduce magic numbers and improve consistency
const TEST_LAYER_CONFIGS := {
	"minimal": {"layer": COLLISION_LAYER_BIT_0, "mask": 0},
	"building": {"layer": DEMO_BUILDING_LAYER, "mask": DEMO_BUILDING_MASK},
	"player": {"layer": COLLISION_LAYER_BIT_0, "mask": COLLISION_LAYER_BIT_9},
	"environment": {"layer": COLLISION_LAYER_BIT_9, "mask": COLLISION_LAYER_BIT_0},
	"indicator_test": {"layer": 513, "mask": 1}  # bits 0+9 commonly used in tests
}

## Common shape configurations for consistent test object creation
const TEST_SHAPE_CONFIGS := {
	"tile": {"size": TILE_SIZE_VEC, "radius": DEFAULT_TILE_SIZE / 2.0},
	"building": {"size": SHAPE_SIZE_VEC, "radius": DEFAULT_RADIUS},
	"large": {"size": Vector2(64, 64), "radius": 32.0},
	"small": {"size": Vector2(8, 8), "radius": 4.0}
}
## ⚠️  MIGRATION NOTICE - Use Scene-Based Test Environments
##
## Factory methods are deprecated. Use pre-configured scene environments:
## - AllSystems: `env = load(ALL_SYSTEMS_ENV_UID).instantiate(); add_child(env); auto_free(env)`
## - Building: `env = load(BUILDING_TEST_ENV_UID).instantiate(); add_child(env); auto_free(env)`
## - Collision: `env = load(COLLISION_TEST_ENV_UID).instantiate(); add_child(env); auto_free(env)`
## - Isometric: `env = load(ISOMETRIC_BUILDING_ENV_UID).instantiate(); add_child(env); auto_free(env)`
##
## Benefits: No timing issues, visual config, built-in validation, better performance.

## Helper function to validate that collision shapes have proper parents
## @param collision_node: The CollisionPolygon2D or CollisionShape2D to validate
## @param method_name: Name of the calling method for error reporting
static func _validate_collision_parent(collision_node: Node, method_name: String) -> void:
	if collision_node == null:
		push_error("%s: collision_node cannot be null" % method_name)
		return
	
	var parent: Node = collision_node.get_parent()
	if parent == null:
		push_error("%s: collision node must have a parent" % method_name)
		return
	if not (parent is CollisionObject2D or parent is Area2D):
		push_error("%s: collision node parent must be CollisionObject2D or Area2D, got %s" % [method_name, parent.get_class()])

## Helper function to ensure collision shapes are properly parented to collision objects
## @param collision_shape: The CollisionPolygon2D or CollisionShape2D to attach
## @param target_parent: The CollisionObject2D or Area2D to attach to  
## @param test: Test suite for auto_free management
## @param method_name: Name of the calling method for error reporting
static func _ensure_collision_parent(
	collision_shape: Node, 
	target_parent: CollisionObject2D, 
	test: GdUnitTestSuite,
	method_name: String
) -> void:
	if target_parent == null:
		test.assert_that(target_parent).append_failure_message("%s: target_parent cannot be null" % method_name).is_not_null()
		return
	if not (target_parent is CollisionObject2D or target_parent is Area2D):
		test.assert_that(target_parent).append_failure_message("%s: target_parent must be CollisionObject2D or Area2D, got %s" % [method_name, target_parent.get_class()]).is_instance_of(CollisionObject2D)
		return
	
	# Remove from current parent if any
	if collision_shape.get_parent() != null:
		collision_shape.get_parent().remove_child(collision_shape)
	
	# Add to proper parent
	target_parent.add_child(collision_shape)
	test.auto_free(collision_shape)

#region Helper Methods to Reduce Code Duplication

## Core validation helper - validates test suite parameter with GdUnit assertions
static func _validate_test_suite(test: GdUnitTestSuite, method_name: String) -> void:
	if test == null:
		push_error("%s: GdUnitTestSuite parameter cannot be null - this indicates a critical test setup issue" % method_name)
		return
	# Using assert for null test since we can't call methods on null
	assert(test != null, "%s: GdUnitTestSuite parameter is required for proper resource management" % method_name)

## Helper to create and auto_free a node with GdUnit validation
static func _create_and_free(node_class: Variant, test: GdUnitTestSuite, method_name: String = "factory_method") -> Node:
	_validate_test_suite(test, method_name)
	
	# Handle both GDScript class references and PackedScene resources
	var node: Node
	if node_class is PackedScene:
		node = test.auto_free(node_class.instantiate())
	else:
		# Assume it's a class that can be instantiated with new() (GDScript or built-in)
		var instance: Variant = node_class.new()
		# Ensure we're creating a Node, not a RefCounted
		if instance is Node:
			node = test.auto_free(instance as Node)
		else:
			push_error("%s: %s.new() returned RefCounted (%s) instead of Node. Tests expect Node objects." % [method_name, node_class, instance.get_class()])
			# Create a Node2D as fallback to avoid type errors
			node = test.auto_free(Node2D.new())
			node.name = "FallbackNode_" + str(instance.get_class())
	
	test.assert_that(node).append_failure_message("%s: Failed to create and register %s node for auto cleanup" % [method_name, node_class]).is_not_null()
	return node

## Helper to create a StaticBody2D with standard collision settings and GdUnit validation
static func _create_static_body(test: GdUnitTestSuite, layer: int = COLLISION_LAYER_BIT_0, mask: int = 0, method_name: String = "create_static_body") -> StaticBody2D:
	var body: StaticBody2D = _create_and_free(StaticBody2D, test, method_name) as StaticBody2D
	body.collision_layer = layer
	body.collision_mask = mask
	
	# Validate collision configuration with GdUnit assertions
	test.assert_that(body.collision_layer).append_failure_message(
		"%s: StaticBody2D collision_layer not set correctly. Expected: %d, Got: %d" % [method_name, layer, body.collision_layer]).is_equal(layer)
	test.assert_that(body.collision_mask).append_failure_message(
		"%s: StaticBody2D collision_mask not set correctly. Expected: %d, Got: %d" % [method_name, mask, body.collision_mask]).is_equal(mask)
	test.assert_that(body is StaticBody2D).append_failure_message(
		"%s: Expected StaticBody2D instance, got %s" % [method_name, body.get_class()]).is_true()
	
	return body

## Helper to create a CollisionShape2D with GdUnit validation and automatic parenting
static func _create_collision_shape_with_parent(shape: Shape2D, parent: CollisionObject2D, test: GdUnitTestSuite, method_name: String = "create_collision_shape") -> CollisionShape2D:
	_validate_test_suite(test, method_name)
	test.assert_that(shape).append_failure_message("%s: Shape2D parameter cannot be null" % method_name).is_not_null()
	test.assert_that(parent).append_failure_message("%s: CollisionObject2D parent cannot be null" % method_name).is_not_null()
	test.assert_that(parent is CollisionObject2D).append_failure_message(
		"%s: Parent must be CollisionObject2D, got %s" % [method_name, parent.get_class()]).is_true()
	
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	parent.add_child(collision_shape)
	test.auto_free(collision_shape)
	
	# Validate the result with GdUnit assertions
	test.assert_that(collision_shape.shape).append_failure_message(
		"%s: CollisionShape2D shape assignment failed" % method_name).is_equal(shape)
	test.assert_that(collision_shape.get_parent()).append_failure_message(
		"%s: CollisionShape2D parenting failed" % method_name).is_equal(parent)
	test.assert_that(parent.get_children().has(collision_shape)).append_failure_message(
		"%s: Parent does not contain the collision shape" % method_name).is_true()
	
	return collision_shape

## Helper to create a RectangleShape2D with given size and validation
static func _create_rectangle_shape(size: Vector2 = SHAPE_SIZE_VEC) -> RectangleShape2D:
	var rect := RectangleShape2D.new()
	rect.size = size
	# Basic validation that size is reasonable
	if size.x <= 0 or size.y <= 0:
		push_error("_create_rectangle_shape: size must be positive, got %s" % size)
	if rect.size != size:
		push_error("_create_rectangle_shape: size assignment failed")
	return rect

## Helper to create a CircleShape2D with given radius and validation
static func _create_circle_shape(radius: float = DEFAULT_RADIUS) -> CircleShape2D:
	var circle := CircleShape2D.new()
	circle.radius = radius
	# Basic validation that radius is reasonable
	if radius <= 0.0:
		push_error("_create_circle_shape: radius must be positive, got %f" % radius)
	if circle.radius != radius:
		push_error("_create_circle_shape: radius assignment failed")
	return circle

## Helper to create standard square polygon points
static func _create_square_polygon(half_size: int = DEFAULT_TILE_SIZE) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_size, -half_size), Vector2(half_size, -half_size), 
		Vector2(half_size, half_size), Vector2(-half_size, half_size)
	])

## Helper to create concave polygon for complex testing
static func _create_concave_polygon(half_size: int = DEFAULT_SHAPE_SIZE) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_size, -half_size),  # Top-left
		Vector2(half_size, -half_size),   # Top-right
		Vector2(half_size, 0),            # Right-middle
		Vector2(0, 0),                    # Center (creates concave shape)
		Vector2(0, half_size),            # Bottom-center
		Vector2(-half_size, half_size),   # Bottom-left
		Vector2(-half_size, -half_size)   # Close the polygon
	])

## Helper to validate a fully-configured collision object with comprehensive GdUnit assertions
## This serves as a reference pattern for thorough validation in factory methods
static func _validate_collision_object_comprehensive(obj: CollisionObject2D, test: GdUnitTestSuite, context: String = "") -> void:
	var method_context := "validate_collision_object" + (" " + context if context else "")
	
	# Basic object validation
	test.assert_that(obj).append_failure_message(
		"%s: CollisionObject2D cannot be null" % method_context).is_not_null()
	test.assert_that(obj is CollisionObject2D).append_failure_message(
		"%s: Object must be CollisionObject2D, got %s" % [method_context, obj.get_class() if obj else "null"]).is_true()
	
	# Collision configuration validation
	test.assert_that(obj.collision_layer).append_failure_message(
		"%s: collision_layer should be non-negative, got %d" % [method_context, obj.collision_layer]).is_greater_equal(0)
	test.assert_that(obj.collision_mask).append_failure_message(
		"%s: collision_mask should be non-negative, got %d" % [method_context, obj.collision_mask]).is_greater_equal(0)
	
	# Shape validation
	var shape_owners := obj.get_shape_owners()
	test.assert_that(shape_owners.size()).append_failure_message(
		"%s: CollisionObject2D must have collision shapes for proper collision detection" % method_context).is_greater(0)
	
	# Validate each shape owner has shapes
	for owner_id in shape_owners:
		var shape_count := obj.shape_owner_get_shape_count(owner_id)
		test.assert_that(shape_count).append_failure_message(
			"%s: Shape owner %d has no shapes configured" % [method_context, owner_id]).is_greater(0)
		
		# Validate shapes are valid
		for shape_idx in range(shape_count):
			var shape := obj.shape_owner_get_shape(owner_id, shape_idx)
			test.assert_that(shape).append_failure_message(
				"%s: Shape at owner %d, index %d is null" % [method_context, owner_id, shape_idx]).is_not_null()

#endregion
## - **DRY Principle**: Eliminates 80% of code duplication through helper methods
## - **Layered Architecture**: Simple → Complex environment building
## - **Backward Compatibility**: All existing APIs preserved
## - **Type Safety**: Comprehensive type hints and validation
##
## ## Usage Patterns:
##
## ### Basic Setup:
## ```gdscript
## func before_test():
##     var env = UnifiedTestFactory.create_utilities_test_environment(self)
##     var container = env.container
##     var logger = env.logger
## ```
##
## ### Building System Test:
## ```gdscript
## func before_test():
##     var env = UnifiedTestFactory.create_building_system_test_environment(self)
##     building_system = env.building_system
##     tile_map = env.tile_map_layer
## ```
##
## ### Complex Integration Test:
## ```gdscript
## func before_test():
##     var env = UnifiedTestFactory.create_systems_integration_test_environment(self)
##     # Access any component: env.building_system, env.targeting_system, etc.
## ```
##
## ## Architecture Notes:
## - Private methods (prefixed with _) are internal implementation details
## - Public methods are stable APIs that maintain backward compatibility
## - All methods follow consistent parameter ordering: (test, container, options)
##
## ## Related Factories:
## - **CollisionObjectTestFactory**: Specialized factory for collision shapes and bodies
##   - Located at: test/grid_building_test/factories/collision_object_test_factory.gd
##   - Use for: Diamond shapes, isometric buildings, collision environment setup
##   - Methods: create_static_body_with_diamond(), create_isometric_blacksmith(), etc.
##
## @tutorial: See docs/testing/factory_usage_guide.md for detailed examples

## Default test container used when no specific container is provided.
## This is a pre-configured GBCompositionContainer with standard test settings.
## Loaded from: uid://dy6e5p5d6ax6n (test_composition_container.tres)
const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

#region CORE FACTORY METHODS - Most Used Methods

## Creates a comprehensive test environment for the indicator management system
## Includes necessary components for testing indicator behavior and interactions
##
## [b]⚠️  DEPRECATED - Use Scene-Based Environments Instead[/b]
##
## This factory method is being deprecated in favor of pre-configured scene environments.
## **Recommended replacement:**
## ```gdscript
## # OLD (deprecated):
## var env = UnifiedTestFactory.create_indicator_test_environment(self)
## 
## # NEW (recommended):
## var env = UnifiedTestFactory.instance_collision_test_env(self, "uid://cdrtd538vrmun")
## # Access properties directly: env.indicator_manager, env.building_system, etc.
## ```
##
## **Why switch?**
## - ✅ No dependency injection timing issues (100% passive)
## - ✅ Visual scene editor configuration
## - ✅ Built-in runtime validation via `env.get_issues()`
## - ✅ Better performance and reliability
##
## [b]Parameters[/b]:
##  • [code]test[/code]: GdUnitTestSuite – test suite for parenting/autofree
##  • [code]container[/code]: GBCompositionContainer – base container (defaults to TEST_CONTAINER)
## [b]Returns[/b]: Dictionary – complete test environment with all components properly configured
static func create_indicator_test_environment(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	push_warning("DEPRECATED: create_indicator_test_environment() is deprecated. Use UnifiedTestFactory.instance_collision_test_env(test, \"uid://cdrtd538vrmun\") instead for better reliability.")
	_validate_test_suite(test, "create_indicator_test_environment")
	
	# Start with comprehensive targeting state setup (ensures indicator template and manipulation parent)
	var targeting_setup: Dictionary = prepare_targeting_state_ready(test, container)
	test.assert_that(targeting_setup).append_failure_message(
		"create_indicator_test_environment: prepare_targeting_state_ready returned null").is_not_null()
	test.assert_that(targeting_setup is Dictionary).append_failure_message(
		"create_indicator_test_environment: prepare_targeting_state_ready must return Dictionary").is_true()
	test.assert_that(targeting_setup.has("container")).append_failure_message(
		"create_indicator_test_environment: targeting_setup missing 'container' key").is_true()
	test.assert_that(targeting_setup.container).append_failure_message(
		"create_indicator_test_environment: targeting_setup.container cannot be null").is_not_null()

	# Create injector for dependency injection
	var injector: GBInjectorSystem = GBInjectorSystem.create_with_injection(test, targeting_setup.container)
	test.assert_that(injector).append_failure_message(
		"create_indicator_test_environment: _create_injector_for_container returned null").is_not_null()

	# Create indicator manager with proper setup
	var indicator_manager: IndicatorManager = create_test_indicator_manager(test, targeting_setup.container)
	test.assert_that(indicator_manager).append_failure_message(
		"create_indicator_test_environment: create_test_indicator_manager returned null").is_not_null()
	
	# indicator_manager is already parented to manipulation_parent via create_test_indicator_manager
	# No need to add it to test suite directly

	# Validate environment dictionary components
	test.assert_that(targeting_setup.has("targeting_state")).append_failure_message(
		"create_indicator_test_environment: targeting_setup missing 'targeting_state' key").is_true()
	test.assert_that(targeting_setup.has("building_state")).append_failure_message(
		"create_indicator_test_environment: targeting_setup missing 'building_state' key").is_true()
	test.assert_that(targeting_setup.has("positioner")).append_failure_message(
		"create_indicator_test_environment: targeting_setup missing 'positioner' key").is_true()
	test.assert_that(targeting_setup.has("tile_map")).append_failure_message(
		"create_indicator_test_environment: targeting_setup missing 'tile_map' key").is_true()
	test.assert_that(targeting_setup.has("objects_parent")).append_failure_message(
		"create_indicator_test_environment: targeting_setup missing 'objects_parent' key").is_true()
	test.assert_that(targeting_setup.has("logger")).append_failure_message(
		"create_indicator_test_environment: targeting_setup missing 'logger' key").is_true()

	# Return complete environment dictionary
	var collision_mapper: CollisionMapper = indicator_manager.get_collision_mapper()
	# If collision_mapper is null, create one directly as fallback
	if collision_mapper == null:
		collision_mapper = CollisionMapper.create_with_injection(targeting_setup.container)
		# Ensure collision mapper dependencies are injected
		indicator_manager.inject_collision_mapper_dependencies(targeting_setup.container)
		collision_mapper = indicator_manager.get_collision_mapper()
		# Final fallback if injection doesn't work
		if collision_mapper == null:
			collision_mapper = CollisionMapper.create_with_injection(targeting_setup.container)
	
	var env_dict: Dictionary = {
		"container": targeting_setup.container,
		"targeting_state": targeting_setup.targeting_state,
		"building_state": targeting_setup.building_state,
		"positioner": targeting_setup.positioner,
		"tile_map": targeting_setup.tile_map,
		"objects_parent": targeting_setup.objects_parent,
		"logger": targeting_setup.logger,
		"injector": injector,
		"indicator_manager": indicator_manager,
		"collision_mapper": collision_mapper,
		"manipulation_parent": indicator_manager.get_parent()
	}

	# Final validation of complete environment (flexible to allow new keys)
	var required_keys := [
		"container",
		"targeting_state",
		"building_state",
		"positioner",
		"tile_map",
		"objects_parent",
		"logger",
		"injector",
		"indicator_manager",
		"collision_mapper",
		"manipulation_parent"
	]
	for k: String in required_keys:
		test.assert_that(env_dict.has(k)).append_failure_message(
			"validate_indicator_test_environment: Environment missing '%s' key" % k).is_true()
		test.assert_that(env_dict.get(k)).append_failure_message(
			"validate_indicator_test_environment: Environment key '%s' cannot be null" % k).is_not_null()

	# Key sanity checks
	test.assert_that(env_dict.container).append_failure_message(
		"validate_indicator_test_environment: Environment container cannot be null").is_not_null()
	test.assert_that(env_dict.indicator_manager).append_failure_message(
		"validate_indicator_test_environment: Environment indicator_manager cannot be null").is_not_null()
	test.assert_that(env_dict.injector).append_failure_message(
		"validate_indicator_test_environment: Environment injector cannot be null").is_not_null()

	return env_dict

#endregion
#region Building Systems

## Creates a BuildingSystem using the static factory method
static func create_building_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> BuildingSystem:
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	var system: BuildingSystem = BuildingSystem.create_with_injection(_container)
	system.name = "TestBuildingSystem"
	test.add_child(system)
	test.auto_free(system)
	return system

## Creates a ManipulationSystem using the static factory method
static func create_manipulation_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> ManipulationSystem:
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	var system: ManipulationSystem = ManipulationSystem.create_with_injection(test, _container)
	system.name = "TestManipulationSystem"
	test.auto_free(system)
	return system

## Creates a GridTargetingSystem using the static factory method
static func create_grid_targeting_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> GridTargetingSystem:
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	var system: GridTargetingSystem = GridTargetingSystem.create_with_injection(test, _container)
	system.name = "TestGridTargetingSystem"
	test.auto_free(system)
	return system

## Creates a GBInjectorSystem using the static factory method
static func create_injector_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> GBInjectorSystem:
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	var system: GBInjectorSystem = GBInjectorSystem.create_with_injection(test, _container)
	system.name = "TestGBInjectorSystem"
	test.auto_free(system)
	return system

static func create_test_building_system(test: GdUnitTestSuite) -> BuildingSystem:
	var system := BuildingSystem.new()
	system.name = "TestBuildingSystem"
	test.auto_free(system)
	test.add_child(system) ## Needed because not using create_with_injection
	return system

#endregion
#region Collision Objects

static func create_collision_object_test_setups(col_objects: Array[Node2D]) -> Dictionary[CollisionObject2D, IndicatorCollisionTestSetup]:
	var setups: Dictionary[CollisionObject2D, IndicatorCollisionTestSetup] = {}
	for obj: Node2D in col_objects:
		if obj is CollisionObject2D:
			var collision_obj: CollisionObject2D = obj
			setups[collision_obj] = IndicatorCollisionTestSetup.new(collision_obj, Vector2.ZERO)
	return setups

static func create_collision_test_setup(test: GdUnitTestSuite, collision_object: CollisionObject2D = null) -> IndicatorCollisionTestSetup:
	return create_test_indicator_collision_setup(test, collision_object)
	
## Create test building with specified collision polygon
## Creates a StaticBody2D with properly validated CollisionPolygon2D hierarchy
static func create_static_body_with_polygon(test: GdUnitTestSuite, polygon: PackedVector2Array) -> StaticBody2D:
	_validate_test_suite(test, "create_static_body_with_polygon")
	test.assert_that(polygon).append_failure_message(
		"create_static_body_with_polygon: polygon parameter cannot be null").is_not_null()
	test.assert_that(polygon.size()).append_failure_message(
		"create_static_body_with_polygon: polygon must have at least 3 points, got %d" % polygon.size()).is_greater_equal(3)
	
	var building := _create_static_body(test, DEMO_BUILDING_LAYER, DEMO_BUILDING_MASK, "create_static_body_with_polygon")
	
	var collision_shape: CollisionPolygon2D = _create_and_free(CollisionPolygon2D, test, "create_static_body_with_polygon")
	collision_shape.polygon = polygon
	building.add_child(collision_shape)
	
	# Validate the collision hierarchy with GdUnit assertions
	test.assert_that(collision_shape.get_parent()).append_failure_message(
		"create_static_body_with_polygon: CollisionPolygon2D not properly parented to StaticBody2D").is_equal(building)
	test.assert_that(collision_shape.polygon.size()).append_failure_message(
		"create_static_body_with_polygon: polygon not properly assigned to CollisionPolygon2D").is_equal(polygon.size())
	test.assert_that(building.get_shape_owners().size()).append_failure_message(
		"create_static_body_with_polygon: StaticBody2D has no collision shapes after setup").is_greater(0)

	return building

## Creates a CollisionPolygon2D with triangle shape and optional parent validation
static func create_test_collision_polygon(test: GdUnitTestSuite, parent: CollisionObject2D = null) -> CollisionPolygon2D:
	var polygon: CollisionPolygon2D = _create_and_free(CollisionPolygon2D, test)
	
	if parent != null:
		_ensure_collision_parent(polygon, parent, test, "create_test_collision_polygon")
	elif polygon.get_parent() != null:
		_validate_collision_parent(polygon, "create_test_collision_polygon")
	
	return polygon

static func create_test_object_with_circle_shape(test: GdUnitTestSuite) -> Node2D:
	_validate_test_suite(test, "create_test_object_with_circle_shape")
	
	var obj := _create_static_body(test, COLLISION_LAYER_BIT_0, 0, "create_test_object_with_circle_shape")
	_create_collision_shape_with_parent(_create_circle_shape(), obj, test, "create_test_object_with_circle_shape")
	
	# Validate the complete object using comprehensive validation
	_validate_collision_object_comprehensive(obj, test, "create_test_object_with_circle_shape")
	
	# Additional specific validation for circle shape
	var shape_owners := obj.get_shape_owners()
	if shape_owners.size() > 0:
		var first_shape := obj.shape_owner_get_shape(shape_owners[0], 0)
		test.assert_that(first_shape is CircleShape2D).append_failure_message(
			"create_test_object_with_circle_shape: Expected CircleShape2D, got %s" % first_shape.get_class()).is_true()
		test.assert_that((first_shape as CircleShape2D).radius).append_failure_message(
			"create_test_object_with_circle_shape: Circle radius not set correctly. Expected: %f, Got: %f" % 
			[DEFAULT_RADIUS, (first_shape as CircleShape2D).radius]).is_equal(DEFAULT_RADIUS)
	
	return obj

static func create_test_static_body_with_rect_shape(test: GdUnitTestSuite) -> StaticBody2D:
	_validate_test_suite(test, "create_test_static_body_with_rect_shape")
	
	var body := _create_static_body(test, COLLISION_LAYER_BIT_0, 0, "create_test_static_body_with_rect_shape")
	_create_collision_shape_with_parent(_create_rectangle_shape(), body, test, "create_test_static_body_with_rect_shape")
	
	# Comprehensive validation with GdUnit assertions
	test.assert_that(body).append_failure_message(
		"create_test_static_body_with_rect_shape: Failed to create StaticBody2D with rect shape").is_not_null()
	test.assert_that(body is StaticBody2D).append_failure_message(
		"create_test_static_body_with_rect_shape: Expected StaticBody2D, got %s" % type_string(typeof(body))).is_true()
	test.assert_that(body.get_children().size()).append_failure_message(
		"create_test_static_body_with_rect_shape: StaticBody2D should have collision shape children").is_greater(0)
	test.assert_that(body.get_shape_owners().size()).append_failure_message(
		"create_test_static_body_with_rect_shape: StaticBody2D should have registered collision shapes").is_greater(0)
	
	return body

static func create_test_parent_with_body_and_polygon(test: GdUnitTestSuite) -> Node2D:
	var parent: Node2D = _create_and_free(Node2D, test)
	var body := _create_static_body(test)
	
	# Create both CollisionShape2D and CollisionPolygon2D for comprehensive testing
	_create_collision_shape_with_parent(_create_rectangle_shape(), body, test)
	
	var polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	polygon.polygon = _create_square_polygon()
	body.add_child(polygon)
	
	parent.add_child(body)
	return parent

#endregion
#region Indicators

static func create_test_indicator_collision_setup(test: GdUnitTestSuite, collision_object: CollisionObject2D = null) -> IndicatorCollisionTestSetup:
	_validate_test_suite(test, "create_test_indicator_collision_setup")
	
	var obj := collision_object if collision_object != null else create_test_static_body_with_rect_shape(test)
	test.assert_that(obj).append_failure_message(
		"create_test_indicator_collision_setup: Failed to create collision object for test setup").is_not_null()
	test.assert_that(obj is CollisionObject2D).append_failure_message(
		"create_test_indicator_collision_setup: Object must be a CollisionObject2D, got %s" % type_string(typeof(obj))).is_true()
	test.assert_that(obj.get_shape_owners().size()).append_failure_message(
		"create_test_indicator_collision_setup: CollisionObject2D must have collision shapes for indicator testing").is_greater(0)
	
	var setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(obj, TILE_SIZE_VEC)
	test.assert_that(setup).append_failure_message(
		"create_test_indicator_collision_setup: Failed to create IndicatorCollisionTestSetup").is_not_null()
	test.assert_that(setup.collision_object).append_failure_message(
		"create_test_indicator_collision_setup: IndicatorCollisionTestSetup collision_object not set correctly").is_equal(obj)
	
	return setup

static func create_test_indicator_manager(test: GdUnitTestSuite, param: Variant = null) -> IndicatorManager:
	_validate_test_suite(test, "create_test_indicator_manager")
	
	var _container: GBCompositionContainer

	# Handle different parameter types for backward compatibility
	if param == null:
		_container = TEST_CONTAINER.duplicate(true)
		test.assert_that(_container).append_failure_message(
			"create_test_indicator_manager: Failed to duplicate TEST_CONTAINER").is_not_null()
		_ensure_container_has_templates(_container, test)
	elif param is GBCompositionContainer:
		_container = param
		test.assert_that(_container).append_failure_message(
			"create_test_indicator_manager: GBCompositionContainer parameter cannot be null").is_not_null()
		_ensure_container_has_templates(_container, test)
	elif param is GridTargetingState:
		# Legacy compatibility: create container with targeting state
		_container = TEST_CONTAINER.duplicate(true)
		test.assert_that(_container).append_failure_message(
			"create_test_indicator_manager: Failed to duplicate TEST_CONTAINER for GridTargetingState").is_not_null()
		_ensure_container_has_templates(_container, test)
		# Ensure states are initialized before assigning targeting state
		var states: GBStates = _container.get_states()
		test.assert_that(states).append_failure_message(
			"create_test_indicator_manager: container.get_states() returned null").is_not_null()
		states.targeting = param
		test.assert_that(states.targeting).append_failure_message(
			"create_test_indicator_manager: Failed to assign targeting state").is_equal(param)
	else:
		push_error("Invalid parameter type for create_test_indicator_manager. Expected GBCompositionContainer or GridTargetingState")
		_container = TEST_CONTAINER.duplicate(true)
		assert(_container != null, "Failed to duplicate TEST_CONTAINER as fallback")
		_ensure_container_has_templates(_container, test)

	# Create positioner and tile map if needed
	var positioner: Node2D = _create_standard_positioner(test)
	assert(positioner != null, "_create_standard_positioner returned null")
	
	var tile_map: TileMapLayer = _create_standard_tile_map(test)
	assert(tile_map != null, "_create_standard_tile_map returned null")

	# For GridTargetingState parameter, preserve the original positioner if it exists
	if param is GridTargetingState and param.positioner != null:
		positioner = param.positioner
		assert(positioner != null, "GridTargetingState.positioner cannot be null when assigned")

	# Set up manipulation parent
	var manipulation_parent: Node2D = _setup_manipulation_parent(test, _container, positioner)
	assert(manipulation_parent != null, "_setup_manipulation_parent returned null")

	# Set up targeting state
	var targeting_state: GridTargetingState = _container.get_states().targeting
	assert(targeting_state != null, "container targeting state is null")
	_setup_basic_targeting_state(targeting_state, positioner, tile_map)

	# Create injector for dependency resolution
	var _injector: GBInjectorSystem = GBInjectorSystem.create_with_injection(test, _container)
	assert(_injector != null, "_create_injector_for_container returned null")

	# Create indicator manager using injection pattern
	var manager: IndicatorManager = IndicatorManager.create_with_injection(_container)
	assert(manager != null, "IndicatorManager.create_with_injection returned null")
	
	manager.name = "TestIndicatorManager"
	assert(manager.name == "TestIndicatorManager", "Failed to set manager name")
	
	manipulation_parent.add_child(manager)
	assert(manager.get_parent() == manipulation_parent, "Failed to add manager to manipulation_parent")
	
	return manager

## Creates a test IndicatorManager for containers loaded from filesystem (like .tres files)
## This method creates a proper scene hierarchy and ensures all runtime dependencies are set up
## [b]Parameters[/b]:
##  • [code]test[/code]: GdUnitTestSuite – test suite for parenting/autofree
##  • [code]container[/code]: GBCompositionContainer – container loaded from filesystem that needs runtime setup
## [b]Returns[/b]: IndicatorManager – fully configured test indicator manager
static func create_test_indicator_manager_for_filesystem_container(test: GdUnitTestSuite, container: GBCompositionContainer) -> IndicatorManager:
	if container == null:
		return null

	# Create a test scene to hold the manager and all dependencies
	var test_scene: Node2D = Node2D.new()
	test_scene.name = "TestScene"
	test.auto_free(test_scene)
	test.add_child(test_scene)

	# Create positioner and tile map
	var positioner: Node2D = _create_standard_positioner(test, "FilesystemTestPositioner")
	var tile_map: TileMapLayer = _create_standard_tile_map(test)

	# Set up manipulation parent
	var manipulation_parent: Node2D = _setup_manipulation_parent(test, container, positioner)

	# Set up targeting state
	_setup_basic_targeting_state(container.get_states().targeting, positioner, tile_map)

	# Create the IndicatorManager using injection pattern
	var manager: IndicatorManager = IndicatorManager.create_with_injection(container)
	manager.name = "FilesystemTestIndicatorManager"
	manipulation_parent.add_child(manager)

	return manager

## Configure the IndicatorManager's CollisionMapper for a given test object.
## This prepares the testing indicator and per-owner collision test setups before indicator generation.
## [b]Parameters[/b]:
##  • [code]test[/code]: GdUnitTestSuite – test suite for parenting/autofree
##  • [code]manager[/code]: IndicatorManager – manager under test
##  • [code]test_object[/code]: Node2D – preview object containing collision owners/shapes
##  • [code]container[/code]: GBCompositionContainer – composition container (defaults to TEST_CONTAINER)
##  • [code]parent[/code]: Node – parent for the testing indicator (usually the same parent used by manager)
static func configure_collision_mapper_for_test_object(test: GdUnitTestSuite, manager: IndicatorManager, test_object: Node2D, container: GBCompositionContainer = null, parent: Node = null) -> void:
	if manager == null or test_object == null:
		return
	var _container := container if container != null else TEST_CONTAINER
	var setup_factory := TestSetupFactory.create_with_injection(_container)
	# Determine parent for testing indicator
	var p := parent if parent != null else test
	# Build owners mapping
	var owner_shapes : Dictionary = GBGeometryUtils.get_all_collision_shapes_by_owner(test_object)
	# Ensure a testing indicator exists
	var testing_indicator := manager.get_or_create_testing_indicator(p)
	# Build setups
	var setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for owner: Node2D in owner_shapes.keys():
		if owner is CollisionObject2D:
			setups[owner] = setup_factory.get_or_create_test_params(owner)
		elif owner is CollisionPolygon2D:
			setups[owner] = null
	# Configure underlying mapper directly via the manager's internal mapper.
	# Use reflection-safe pattern: ensure injected dependencies match the test container.
	if manager.has_method("inject_collision_mapper_dependencies"):
		manager.inject_collision_mapper_dependencies(_container)
	# Call setup on the internal CollisionMapper instance.
	# Accessing underscored fields is acceptable in tests to avoid runtime-only APIs.
	var collision_mapper: CollisionMapper = manager.get_collision_mapper()
	if collision_mapper != null:
		collision_mapper.setup(testing_indicator, setups)

static func create_test_indicator_rect(test: GdUnitTestSuite, tile_size: int = DEFAULT_TILE_SIZE) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new([])
	indicator.name = "TestRuleCheckIndicatorRect"
	test.auto_free(indicator)
	var rect_shape := RectangleShape2D.new()
	rect_shape.extents = Vector2(tile_size, tile_size)
	indicator.shape = rect_shape
	test.auto_free(rect_shape)
	# IMPORTANT: ensure indicator participates in the test scene tree so auto_free + orphan detection work
	test.add_child(indicator)
	
	# Set up dependency injection after adding to tree
	var container := TEST_CONTAINER
	indicator.resolve_gb_dependencies(container)
	
	return indicator

#region Injection and Logging
## Creates a fully configured composition container for testing purposes.
## It sets up a logger, debug settings, and a config, then registers them.
static func create_test_composition_container(test: GdUnitTestSuite) -> GBCompositionContainer:
	assert(test != null, "test parameter cannot be null")
	
	var container := GBCompositionContainer.new()
	assert(container != null, "Failed to create GBCompositionContainer instance")
	
	var debug_settings := create_test_debug_settings()
	assert(debug_settings != null, "create_test_debug_settings returned null")
	
	var config := GBConfig.new()
	assert(config != null, "Failed to create GBConfig instance")
	
	var templates := GBTemplates.new()
	assert(templates != null, "Failed to create GBTemplates instance")

	# Configure templates with default rule check indicator
	templates.rule_check_indicator = preload("res://addons/grid_building/placement/rule_check_indicator/rule_check_indicator.tscn")
	assert(templates.rule_check_indicator != null, "Failed to load rule_check_indicator template")

	container.config = config
	assert(container.config == config, "Failed to assign config to container")
	
	config.settings.debug = debug_settings
	assert(config.settings.debug == debug_settings, "Failed to assign debug settings to config")
	
	config.templates = templates
	assert(config.templates == templates, "Failed to assign templates to config")

	var logger := container.get_logger()
	assert(logger != null, "container.get_logger() returned null")

	test.auto_free(container)
	test.auto_free(debug_settings)
	test.auto_free(logger)
	test.auto_free(config)
	test.auto_free(templates)

	return container

static func create_configured_injector(test_suite: GdUnitTestSuite) -> GBInjectorSystem:
	var container := GBCompositionContainer.new()
	
	var config := GBConfig.new()
	config.debug = create_test_debug_settings()
	
	container.set_script(load("res://addons/grid_building/systems/injection/gb_composition_container.gd"))
	container.config = config
	container.logger = GBLogger.new(create_test_debug_settings())

	container.logger.debug = config.debug
	
	var injector := GBInjectorSystem.new()
	test_suite.auto_free(injector)
	injector.composition_container = container
	test_suite.add_child(injector)
	
	return injector

## Creates a fully configured debug settings instance for testing purposes.
static func create_test_debug_settings() -> GBDebugSettings:
	# Properly instantiate debug settings (previous implementation recursed infinitely)
	var debug_settings := GBDebugSettings.new()
	debug_settings.resource_name = "TestDebugSettings"
	# Default to DEBUG level for verbose test diagnostics
	debug_settings.set_debug_level(GBDebugSettings.DebugLevel.DEBUG)
	return debug_settings

static func create_test_injector(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> GBInjectorSystem:
	assert(test != null, " Should only be ran inside a GdUnitTestSuite")
	var _container: GBCompositionContainer = container if container != null else create_test_composition_container(test)
	var injector: GBInjectorSystem = GBInjectorSystem.create_with_injection(test, _container)
	test.auto_free(injector)
	return injector

static func create_test_logger() -> GBLogger:
	var debug_settings := create_test_debug_settings()
	return GBLogger.new(debug_settings)

#endregion
#region Manipulation

static func create_test_manipulation_system(test: GdUnitTestSuite) -> ManipulationSystem:
	var system := ManipulationSystem.new()
	system.name = "TestManipulationSystem"
	test.auto_free(system)
	test.add_child(system)
	return system

static func create_test_manipulatable(test: GdUnitTestSuite) -> Manipulatable:
	# Create a basic manipulatable component
	var manipulatable: Manipulatable = test.auto_free(Manipulatable.new())
	manipulatable.name = "FactoryManipulatable"
	return manipulatable

#endregion
#region Node Utilities

static func create_test_node2d(test: GdUnitTestSuite) -> Node2D:
	return test.auto_free(Node2D.new())

static func create_test_node_locator(search_method: NodeLocator.SEARCH_METHOD = NodeLocator.SEARCH_METHOD.NODE_NAME, search_string: String = "test") -> NodeLocator:
	return NodeLocator.new(search_method, search_string)

#endregion
#region Owner Context

static func create_owner_context(test: GdUnitTestSuite) -> GBOwnerContext:
	var context := GBOwnerContext.new()
	var user := Node2D.new()
	user.name = "TestOwnerUser"
	test.auto_free(user)
	test.add_child(user)
	var gb_owner := GBOwner.new(user)
	test.auto_free(gb_owner)
	context.set_owner(gb_owner)
	return context

static func create_test_owner_context(test: GdUnitTestSuite) -> GBOwnerContext:
	var context := GBOwnerContext.new()
	var user := create_test_node2d(test)
	var gb_owner := GBOwner.new(user)
	test.auto_free(gb_owner)
	context.set_owner(gb_owner)
	return context

#endregion
#region Placement

## Creates a IndicatorManager for testing purposes.
## 
## ARCHITECTURE NOTE: IndicatorManager serves as the parent for rule check indicators.
## In production, it should be a child of ManipulationParent to maintain proper hierarchy.
## See docs/systems/parent_node_architecture.md for detailed guidelines.
static func create_indicator_manager(test: GdUnitTestSuite) -> IndicatorManager:
	# Create a test container if we don't have one
	var container: GBCompositionContainer = TEST_CONTAINER
	
	# Create indicator manager using injection pattern
	var manager: IndicatorManager = IndicatorManager.create_with_injection(container)
	manager.name = "TestIndicatorManager"
	test.auto_free(manager)
	test.add_child(manager)
	return manager

## Creates a minimal GridTargetingState for unit tests without dependencies
## Catches: Invalid targeting state setup issues that can cause IndicatorService failures
static func create_minimal_targeting_state(test: GdUnitTestSuite, valid: bool = true, align_to_center: bool = false) -> GridTargetingState:
	var owner_ctx := GBOwnerContext.new(null)
	var gts := GridTargetingState.new(owner_ctx)
	if valid:
		var map : TileMapLayer = test.auto_free(TileMapLayer.new())
		map.tile_set = TileSet.new()
		map.tile_set.tile_size = TILE_SIZE_VEC
		var positioner : Node2D = test.auto_free(Node2D.new())
		if align_to_center:
			var center := map.to_global(map.map_to_local(Vector2i.ZERO))
			positioner.global_position = center
		gts.positioner = positioner
		gts.target_map = map
		gts.maps = [map]
	return gts

## Creates minimal IndicatorManager for unit tests with direct initialization (no container)
## Has no rules. If you want rules, you must add them manually
## Catches: IndicatorManager initialization failures without composition container dependencies
static func create_minimal_indicator_manager(test: GdUnitTestSuite, parent: Node2D, gts: GridTargetingState, template: PackedScene) -> IndicatorManager:
	var manager := IndicatorManager.new()
	test.auto_free(manager)
	parent.add_child(manager)
	
	# Set up minimal dependencies directly
	var owner_ctx := GBOwnerContext.new(null)
	var indicator_ctx := IndicatorContext.new()
	var rules: Array[PlacementRule] = []
	var messages := GBMessages.new()
	var logger := create_test_logger()
	
	# Initialize manager directly without container
	manager.initialize(indicator_ctx, owner_ctx, template, gts, logger, rules, messages)
	
	return manager

## Creates minimal template PackedScene with RuleCheckIndicator for unit tests
## Catches: Template creation and packing errors that prevent indicator generation
static func create_minimal_indicator_template(_test: GdUnitTestSuite) -> PackedScene:
	var ps := PackedScene.new()
	var node := RuleCheckIndicator.new()
	# Set up a valid shape for the ShapeCast2D component
	var shape := RectangleShape2D.new()
	shape.size = SHAPE_SIZE_VEC
	node.shape = shape
	# pack a minimal scene with RuleCheckIndicator root
	var err := ps.pack(node)
	node.free() ## Cleanup loose node
	assert(err == OK, "Failed to pack RuleCheckIndicator into PackedScene, err=%d" % err)
	return ps

static func create_placement_validator(_test: GdUnitTestSuite, rules: Array = []) -> PlacementValidator:
	var messages := GBMessages.new()
	var logger := create_test_logger()
	var validator := PlacementValidator.new(rules, messages, logger)
	
	# COMPATIBILITY: If the PlacementValidator API has changed and doesn't have validate() method,
	# this factory method creates an object that tests expect but the API may have evolved.
	# The actual API may now use try_validate() or a different method structure.
	# Tests calling validator.validate() may need to be updated to use the new API.
	
	return validator
#endregion
#region Rules

## Creates a RuleCheckIndicator and parents it for testing purposes.
## It defaults to a RectangleShape2D
## 
## ARCHITECTURE NOTE: In production code, indicators should be created via IndicatorManager.setup_indicators()
## which automatically parents them to the IndicatorManager. This factory method is for unit testing only.
##
## Parenting rules:
## 1. If a parent Node is provided, the indicator is added to it.
## 2. If no parent is provided, it is added to the test suite (maintains previous auto-parent behavior).
## 
## See docs/systems/parent_node_architecture.md for production architecture guidelines.
static func create_rule_check_indicator(test: GdUnitTestSuite, rules: Array[TileCheckRule] = [], parent: Node = null, shape_size := Vector2(16,16)) -> RuleCheckIndicator:
	var indicator := RuleCheckIndicator.new(rules)
	var test_shape: RectangleShape2D = RectangleShape2D.new()
	test_shape.size = shape_size
	indicator.shape = test_shape
	test.auto_free(indicator)
	if parent != null:
		parent.add_child(indicator)
	else:
		test.add_child(indicator)
	return indicator

static func create_rule_with_logger(rule_class: GDScript) -> PlacementRule:
	var rule: PlacementRule = rule_class.new()
	var logger := create_test_logger()
	rule.initialize(logger)
	return rule

static func create_test_collisions_check_rule() -> CollisionsCheckRule:
	return CollisionsCheckRule.new()

static func create_test_rule_check_indicator(test: GdUnitTestSuite, rules: Array = [], parent: Node = null) -> RuleCheckIndicator:
	# Alias helper mirroring create_rule_check_indicator with same parenting logic.
	var indicator := RuleCheckIndicator.new(rules)
	indicator.name = "TestRuleCheckIndicator"
	
	# Set up a valid shape for the ShapeCast2D component
	var shape := RectangleShape2D.new()
	shape.size = SHAPE_SIZE_VEC
	indicator.shape = shape
	
	# Set collision mask to match test expectations
	indicator.collision_mask = 1
	
	test.auto_free(indicator)
	if parent != null:
		parent.add_child(indicator)
	else:
		test.add_child(indicator)
	
	# Set up dependency injection after adding to tree
	var container := TEST_CONTAINER
	indicator.resolve_gb_dependencies(container)
	
	return indicator

static func create_test_valid_placement_tile_rule(tile_data: Dictionary = {}) -> ValidPlacementTileRule:
	return ValidPlacementTileRule.new(tile_data)

#endregion
#region Targeting State
static func create_double_targeting_state(test : GdUnitTestSuite) -> GridTargetingState:
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())
	test.auto_free(targeting_state)
	var positioner: Node2D = test.auto_free(Node2D.new())
	# positioner already parented
	positioner.global_position = DEFAULT_TEST_POSITION  # Set a default position for calculations
	targeting_state.positioner = positioner
	var target_map: TileMapLayer = test.auto_free(TileMapLayer.new())
	targeting_state.target_map = target_map
	var layer1: TileMapLayer = test.auto_free(TileMapLayer.new())
	var layer2: TileMapLayer = test.auto_free(TileMapLayer.new())
	targeting_state.maps = [layer1, layer2]
	return targeting_state

static func create_targeting_state(test: GdUnitTestSuite, owner_context: GBOwnerContext = null) -> GridTargetingState:
	var context: GBOwnerContext = owner_context if owner_context != null else create_owner_context(test)
	var targeting_state: GridTargetingState = GridTargetingState.new(context)
	var positioner: Node2D = _create_standard_positioner(test)
	var map_layer: TileMapLayer = _create_standard_tile_map(test)
	targeting_state.positioner = positioner
	targeting_state.set_map_objects(map_layer, [map_layer])
	test.auto_free(targeting_state)
	return targeting_state

#endregion
#region Test Utilities

## Setup a complete building system test environment
static func setup_building_system_test(test: GdUnitTestSuite, container: GBCompositionContainer) -> Dictionary:
	var scene: Dictionary = {}

	# Create core scene nodes using helper methods
	var placer: Node2D = _create_standard_positioner(test, "TestPlacer")
	var placed_parent: Node2D = _setup_placed_parent(test, container)
	var grid_positioner: Node2D = _create_standard_positioner(test, "TestGridPositioner")
	var map_layer: TileMapLayer = _create_standard_tile_map(test)

	# Setup targeting state
	_setup_basic_targeting_state(container.get_states().targeting, grid_positioner, map_layer)

	# Setup building state
	var user_context: GBOwnerContext = create_test_owner_context(test)
	var building_state: BuildingState = container.get_states().building
	building_state.placer_state = user_context
	building_state.placed_parent = placed_parent

	# Create and setup building system
	var system: BuildingSystem = _create_system_with_injection(test, BuildingSystem, container, "TestBuildingSystem")

	# Create indicator manager
	var indicator_manager: IndicatorManager = create_test_indicator_manager(test)
	var indicator_context: IndicatorContext = test.auto_free(IndicatorContext.new())

	# Populate scene dictionary
	scene.placer = placer
	scene.placed_parent = placed_parent
	scene.grid_positioner = grid_positioner
	scene.map_layer = map_layer
	scene.user_context = user_context
	scene.system = system
	scene.indicator_manager = indicator_manager
	scene.indicator_context = indicator_context

	return scene

## Setup a complete manipulation system test environment
static func setup_manipulation_system_test(test: GdUnitTestSuite, container: GBCompositionContainer) -> Dictionary:
	var scene: Dictionary = {}

	# Create core scene nodes using helper methods
	var placer: Node2D = _create_standard_positioner(test, "TestPlacer")
	var placed_parent: Node2D = _setup_placed_parent(test, container)
	var grid_positioner: Node2D = _create_standard_positioner(test, "TestGridPositioner")
	var map_layer: TileMapLayer = _create_standard_tile_map(test)

	# Setup targeting state
	_setup_basic_targeting_state(container.get_states().targeting, grid_positioner, map_layer)

	# Setup building state
	var user_context: GBOwnerContext = create_test_owner_context(test)
	var building_state: BuildingState = container.get_states().building
	building_state.placer_state = user_context
	building_state.placed_parent = placed_parent

	# Create and setup manipulation system
	var manipulation_system: ManipulationSystem = ManipulationSystem.create_with_injection(test, container)
	test.auto_free(manipulation_system)
	test.add_child(manipulation_system)
	var system: ManipulationSystem = manipulation_system

	# Create indicator manager
	var indicator_manager: IndicatorManager = create_test_indicator_manager(test)
	var indicator_context: IndicatorContext = test.auto_free(IndicatorContext.new())

	# Populate scene dictionary
	scene.placer = placer
	scene.placed_parent = placed_parent
	scene.grid_positioner = grid_positioner
	scene.map_layer = map_layer
	scene.user_context = user_context
	scene.system = system
	scene.indicator_manager = indicator_manager
	scene.indicator_context = indicator_context

	return scene

## Setup a complete grid targeting system test environment
static func setup_grid_targeting_system_test(test: GdUnitTestSuite, container: GBCompositionContainer) -> Dictionary:
	var scene: Dictionary = {}

	# Create core scene nodes using helper methods
	var placer: Node2D = _create_standard_positioner(test, "TestPlacer")
	var placed_parent: Node2D = _setup_placed_parent(test, container)
	var grid_positioner: Node2D = _create_standard_positioner(test, "TestGridPositioner")
	var map_layer: TileMapLayer = _create_standard_tile_map(test)

	# Setup targeting state
	_setup_basic_targeting_state(container.get_states().targeting, grid_positioner, map_layer)

	# Create and setup grid targeting system
	var system: GridTargetingSystem = _create_system_with_injection(test, GridTargetingSystem, container, "TestGridTargetingSystem")

	# Populate scene dictionary
	scene.placer = placer
	scene.placed_parent = placed_parent
	scene.grid_positioner = grid_positioner
	scene.map_layer = map_layer
	scene.system = system

	return scene

## Create a test placeable instance with common setup
static func create_test_placeable_instance(test : GdUnitTestSuite, p_parent: Node,  placeable : Placeable, _instance_name: String = "TestInstance",) -> Node:
	var instance: Node = placeable.packed_scene.instantiate()
	test.auto_free(instance)
	p_parent.add_child(instance)
	return instance

## Create a test manipulation data object
static func create_test_manipulation_data(
	test: GdUnitTestSuite,
	action: GBEnums.Action = GBEnums.Action.BUILD,
	root_manipulatable: Manipulatable = null,
	target_manipulatable: Manipulatable = null
) -> ManipulationData:
	var root: Manipulatable = root_manipulatable if root_manipulatable else create_test_manipulatable(test)
	var target: Manipulatable = target_manipulatable if target_manipulatable else create_test_manipulatable(test)

	# Provide a container node for manipulation data and ensure it is parented to the test
	var container_node: Node = Node.new()
	test.auto_free(container_node)
	test.add_child(container_node)

	var data: ManipulationData = ManipulationData.new(
		container_node,
		root,
		target,
		action
	)

	return test.auto_free(data)

## Create a test rule check indicator with common setup
static func create_test_rule_check_indicator_with_shape(
	test: GdUnitTestSuite,
	rules: Array = [],
	tile_size: int = DEFAULT_TILE_SIZE
) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = create_test_rule_check_indicator(test, rules, null)
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(tile_size, tile_size)
	indicator.shape = rect_shape
	return indicator

## Validate that a system has no dependency issues
static func assert_system_dependencies_valid(test: GdUnitTestSuite, system: Node) -> void:
	var issues: Array = system.get_runtime_issues()
	test.assert_array(issues).is_empty()

## Validate that a system has expected dependency issues
static func assert_system_dependencies_have_issues(test: GdUnitTestSuite, system: Node, expected_issue_count: int = 1) -> void:
	var issues: Array = system.get_runtime_issues()
	test.assert_int(issues.size()).is_greater_equal(expected_issue_count)

#endregion
#region TileMaps

static func create_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	return test.auto_free(TileMapLayer.new())

static func create_test_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	# Backwards compatible wrapper
	return test.auto_free(TileMapLayer.new())

#endregion

#region Demo Resource Factories (Self-Contained)

## Creates a test polygon object similar to res://demos/top_down/objects/polygon_test_object.tscn
## This is a self-contained version that doesn't depend on external demo files
## 
## @param test: The test suite for auto_free management
## @param parent: Optional parent CollisionObject2D to attach the collision polygon to.
##                If provided, creates a proper collision hierarchy with the polygon as child of parent.
##                If null, creates the legacy structure with separate StaticBody2D.
static func create_polygon_test_object(test: GdUnitTestSuite, parent: CollisionObject2D = null) -> Node2D:
	var obj := Node2D.new()
	obj.name = "PolygonTestObject"
	
	# Define a concave polygon that matches the demo's behavior
	var points: PackedVector2Array = _create_concave_polygon()
	
	if parent != null:
		# Assert that parent is a valid collision object
		assert(parent is CollisionObject2D or parent is Area2D, 
			"Parent must be a CollisionObject2D (StaticBody2D, RigidBody2D, CharacterBody2D) or Area2D for collision detection to work properly")
		
		# Create proper collision hierarchy: CollisionObject2D -> CollisionPolygon2D
		var collision_polygon := CollisionPolygon2D.new()
		collision_polygon.name = "CollisionPolygon2D"
		collision_polygon.polygon = points
		parent.add_child(collision_polygon)
		obj.add_child(parent)
		
		# Set owner properties
		collision_polygon.owner = obj
		parent.owner = obj
	else:
		# Legacy structure: Create both direct CollisionPolygon2D and StaticBody2D with collision
		# NOTE: The direct CollisionPolygon2D is invalid for physics but kept for backward compatibility
		var collision_polygon := CollisionPolygon2D.new()
		collision_polygon.name = "CollisionPolygon2D"
		collision_polygon.polygon = points
		obj.add_child(collision_polygon)
		
		# Create a StaticBody2D with collision layer 1 (matches bit 0) for collision detection
		var static_body := StaticBody2D.new()
		static_body.name = "StaticBody2D"
		static_body.collision_layer = 1  # Bit 0 set
		static_body.collision_mask = 1
		
		# Create a collision polygon for the static body
		var body_collision_polygon := CollisionPolygon2D.new()
		body_collision_polygon.name = "BodyCollisionPolygon2D"
		body_collision_polygon.polygon = points  # Same shape
		
		static_body.add_child(body_collision_polygon)
		obj.add_child(static_body)
		
		# Set owner properties
		
	test.auto_free(obj)
	return obj

## Creates a test placeable configuration similar to demo placeables
## This is a self-contained version that doesn't depend on external demo files
static func create_polygon_test_placeable(test: GdUnitTestSuite) -> Placeable:
	assert(test != null, "test parameter cannot be null")
	
	var placeable := Placeable.new()
	assert(placeable != null, "Failed to create Placeable instance")
	
	placeable.resource_name = "TestPolygonPlaceable"
	assert(placeable.resource_name == "TestPolygonPlaceable", "Failed to set resource_name")
	
	# Create a basic packed scene reference (we'll create the scene dynamically)
	var scene := PackedScene.new()
	assert(scene != null, "Failed to create PackedScene instance")
	
	var polygon_obj := create_polygon_test_object(test)
	assert(polygon_obj != null, "create_polygon_test_object returned null")
	
	var pack_result := scene.pack(polygon_obj)
	assert(pack_result == OK, "Failed to pack polygon object into scene: " + str(pack_result))
	
	placeable.packed_scene = scene
	assert(placeable.packed_scene != null, "Failed to assign packed_scene to placeable")
	assert(placeable.packed_scene == scene, "Packed scene assignment verification failed")
	
	return placeable

## Creates a test grid positioner similar to templates
## This is a self-contained version that doesn't depend on external template files
static func create_grid_positioner(test: GdUnitTestSuite) -> Node2D:
	var positioner := Node2D.new()
	positioner.name = "GridPositioner"
	positioner.position = Vector2.ZERO
	test.auto_free(positioner)
	return positioner

## Creates a test GridPositioner2D with proper collision settings
## This is a self-contained version that doesn't depend on external template files
static func create_grid_positioner_2d(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> GridPositioner2D:
	var positioner := GridPositioner2D.new()
	positioner.name = "GridPositioner2D"
	positioner.position = Vector2.ZERO
	positioner.collide_with_areas = true
	positioner.collision_mask = 2561  # Match runtime expectation
	
	# Set required shape for ShapeCast2D (matches template configuration)
	var shape := RectangleShape2D.new()
	shape.size = SHAPE_SIZE_VEC
	positioner.shape = shape
	
	if container:
		positioner.resolve_gb_dependencies(container)
	
	test.auto_free(positioner)
	return positioner

## Creates an eclipse test object similar to the external eclipse scene (uid://j5837ml5dduu)
## This is a self-contained version that doesn't depend on external demo files
static func create_eclipse_test_object(test: GdUnitTestSuite) -> Node2D:
	var eclipse := Node2D.new()
	eclipse.name = "EclipseTestObject"
	
	# Create collision shapes for the eclipse - using multiple polygons to simulate eclipse shape
	var static_body := StaticBody2D.new()
	static_body.name = "StaticBody2D"
	static_body.collision_layer = 1  # Bit 0 set
	static_body.collision_mask = 1
	
	# Create an elliptical/eclipse shape using a polygon approximation
	var collision_polygon := CollisionPolygon2D.new()
	collision_polygon.name = "CollisionPolygon2D"
	
	# Create eclipse-like shape with multiple points
	var points: PackedVector2Array = []
	var segments: int = 16
	var radius_x: float = 48.0
	var radius_y: float = 32.0
	for i in range(segments + 1):
		var angle: float = (i * 2.0 * PI) / segments
		var x: float = radius_x * cos(angle)
		var y: float = radius_y * sin(angle)
		points.append(Vector2(x, y))
	
	collision_polygon.polygon = points
	static_body.add_child(collision_polygon)
	eclipse.add_child(static_body)
	
	# Add Manipulatable component for manipulation system integration
	var manipulatable := Manipulatable.new()
	manipulatable.name = "TestManipulatable"
	manipulatable.root = eclipse
	var settings := ManipulatableSettings.new()
	settings.movable = true
	settings.demolishable = true
	manipulatable.settings = settings
	eclipse.add_child(manipulatable)
	
	# Set owner properties AFTER all nodes are added to the tree
	static_body.owner = eclipse
	collision_polygon.owner = eclipse
	manipulatable.owner = eclipse
	
	test.auto_free(eclipse)
	return eclipse

## Creates a test placeable for 2D objects
static func create_test_placeable_2d(_test: GdUnitTestSuite) -> Placeable:
	var placeable := Placeable.new()
	placeable.display_name = "TestPlaceable2D"
	
	# Create a simple PackedScene for the placeable
	var packed_scene := PackedScene.new()
	var test_obj := Node2D.new()
	test_obj.name = "TestObject"
	
	# Add a collision shape
	var static_body := StaticBody2D.new()
	static_body.name = "TestStaticBody2D"
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "TestCollisionShape2D"
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = SHAPE_SIZE_VEC
	collision_shape.shape = rect_shape
	static_body.add_child(collision_shape)
	test_obj.add_child(static_body)
	
	# Add Manipulatable component for manipulation system integration
	var manipulatable := Manipulatable.new()
	manipulatable.name = "TestManipulatable"
	manipulatable.root = test_obj
	var settings := ManipulatableSettings.new()
	settings.movable = true
	settings.demolishable = true
	manipulatable.settings = settings
	test_obj.add_child(manipulatable)
	
	# Set owners for PackedScene inclusion (after tree is built)
	static_body.owner = test_obj
	collision_shape.owner = test_obj
	manipulatable.owner = test_obj
	
	packed_scene.pack(test_obj)
	placeable.packed_scene = packed_scene
	placeable.placement_rules = []
	
	return placeable

## Creates a test eclipse placeable
static func create_test_eclipse_placeable(test: GdUnitTestSuite) -> Placeable:
	var placeable := Placeable.new()
	placeable.display_name = "TestEclipsePlaceable"
	
	# Create a PackedScene containing the eclipse object
	var packed_scene := PackedScene.new()
	var eclipse_obj := create_eclipse_test_object(test)
	
	packed_scene.pack(eclipse_obj)
	placeable.packed_scene = packed_scene
	
	# Add basic placement rules
	var collision_rule := CollisionsCheckRule.new()
	collision_rule.apply_to_objects_mask = 1
	collision_rule.collision_mask = 1
	placeable.placement_rules = [collision_rule]
	return placeable

## Creates a test eclipse PackedScene for direct scene testing
static func create_test_eclipse_packed_scene(test: GdUnitTestSuite) -> PackedScene:
	var packed_scene := PackedScene.new()
	var eclipse_obj := create_eclipse_test_object(test)
	packed_scene.pack(eclipse_obj)
	return packed_scene

#endregion

#region Complete Building Test Setup

## Complete building test setup with all necessary components for indicator/placement testing
## Returns a dictionary with all configured components
static func create_complete_building_test_setup(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER
	var injector: GBInjectorSystem = create_test_injector(test, _container)
	
	# Create core scene nodes
	var obj_parent: Node2D = test.auto_free(Node2D.new())
	var placer: Node2D = test.auto_free(Node2D.new())
	var positioner: Node2D = test.auto_free(Node2D.new())
	
	# Set up tilemap with proper tileset
	var map_layer: TileMapLayer = TileMapLayer.new()
	test.auto_free(map_layer)
	
	var tileset: TileSet = load("res://demos/top_down/art/0x72_demo_tileset.tres")
	if tileset:
		map_layer.tile_set = tileset
	else:
		# Fallback tileset if demo tileset not available
		var fallback_tileset: TileSet = TileSet.new()
		fallback_tileset.tile_size = Vector2i(16, 16)
		map_layer.tile_set = fallback_tileset
	
	# Set up targeting system - configure state BEFORE creating system
	var targeting_state: GridTargetingState = _container.get_states().targeting
	targeting_state.positioner = positioner
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	
	var targeting_system: GridTargetingSystem = create_grid_targeting_system(test, _container)
	
	# Set up building system
	var building_system: BuildingSystem = create_building_system(test, _container)
	var building_state: BuildingState = _container.get_states().building
	var owner_context: GBOwnerContext = _container.get_contexts().owner
	var gb_owner: GBOwner = GBOwner.new(placer)
	placer.add_child(gb_owner)
	gb_owner.owner_root = placer
	owner_context.set_owner(gb_owner)
	building_state.placed_parent = obj_parent
	
	# Set up manipulation parent under positioner
	_container.get_states().manipulation.parent = positioner
	
	# Create and setup IndicatorManager under positioner
	var indicator_manager: IndicatorManager = IndicatorManager.create_with_injection(_container)
	positioner.add_child(indicator_manager)
	_container.get_contexts().indicator.set_manager(indicator_manager)
	
	return {
		"container": _container,
		"injector": injector,
		"obj_parent": obj_parent,
		"placer": placer,
		"positioner": positioner,
		"map_layer": map_layer,
		"targeting_system": targeting_system,
		"building_system": building_system,
		"indicator_manager": indicator_manager
	}

## Creates manipulation system test environment with all required components
##
## [b]⚠️  DEPRECATED - Use Scene-Based Environments Instead[/b]
##
## This factory method is being deprecated in favor of pre-configured scene environments.
## **Recommended replacement:**
## ```gdscript
## # OLD (deprecated):
## var env = UnifiedTestFactory.create_manipulation_system_test_environment(self)
## 
## # NEW (recommended):
## var env = UnifiedTestFactory.instance_collision_test_env(self, "uid://cdrtd538vrmun")
## # Access properties directly: env.indicator_manager, env.building_system, etc.
## ```
##
## [b]Parameters[/b]:
##  • [code]test[/code]: GdUnitTestSuite – test suite for parenting/autofree
##  • [code]container[/code]: GBCompositionContainer – base container (defaults to TEST_CONTAINER)
## [b]Returns[/b]: Dictionary – complete manipulation system test environment
static func create_manipulation_system_test_environment(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	push_warning("DEPRECATED: create_manipulation_system_test_environment() is deprecated. Use UnifiedTestFactory.instance_collision_test_env(test, \"uid://cdrtd538vrmun\") instead for better reliability.")
	var _container: GBCompositionContainer = _resolve_container(container)
	var injector: GBInjectorSystem = _create_injector_for_container(test, _container)

	# Create manipulator node
	var manipulator: Node2D = _create_standard_positioner(test, "TestManipulator")

	# Create GBOwner and set it up properly
	var gb_owner: GBOwner = _create_standard_gb_owner(test, manipulator, _container)

	# Connect the owner to the container's context
	var owner_context: GBOwnerContext = _setup_owner_context(test, _container, manipulator)

	# Setup manipulation test system using static factory methods
	var states: GBStates = _container.get_states()
	var manipulation_state: ManipulationState = states.manipulation
	var manipulation_parent: Node2D = _setup_manipulation_parent(test, _container, manipulator)

	var targeting_state: GridTargetingState = states.targeting
	var tile_map_layer: TileMapLayer = _create_standard_tile_map(test)
	targeting_state.target_map = tile_map_layer
	var maps_array: Array = [tile_map_layer]
	targeting_state.maps = maps_array

	# IndicatorManager: instantiate and inject dependencies
	var placement_manager: IndicatorManager = create_test_indicator_manager(test, _container)

	var system: ManipulationSystem = ManipulationSystem.create_with_injection(test, _container)
	system.name = "TestManipulationSystem"
	test.auto_free(system)
	if not system.get_parent():
		test.add_child(system)

	return {
		"container": _container,
		"injector": injector,
		"manipulator": manipulator,
		"gb_owner": gb_owner,
		"owner_context": owner_context,
		"manipulation_state": manipulation_state,
		"manipulation_parent": manipulation_parent,
		"targeting_state": targeting_state,
		"tile_map": tile_map_layer,
		"indicator_manager": placement_manager,
		"system": system
	}

## Creates building system test environment with all required components
##
## [b]⚠️  DEPRECATED - Use Scene-Based Environments Instead[/b]
##
## This factory method is being deprecated in favor of pre-configured scene environments.
## **Recommended replacement:**
## ```gdscript
## # OLD (deprecated):
## var env = UnifiedTestFactory.create_building_system_test_environment(self)
## 
## # NEW (recommended):
## var env = UnifiedTestFactory.instance_building_test_env(self, "uid://c4ujk08n8llv8")
## # Access properties directly: env.building_system, env.indicator_manager, etc.
## ```
##
## [b]Parameters[/b]:
##  • [code]test[/code]: GdUnitTestSuite – test suite for parenting/autofree
##  • [code]container[/code]: GBCompositionContainer – base container (defaults to TEST_CONTAINER)
## [b]Returns[/b]: Dictionary – complete building system test environment
static func create_building_system_test_environment(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	push_warning("DEPRECATED: create_building_system_test_environment() is deprecated. Use UnifiedTestFactory.instance_building_test_env(test, \"uid://c4ujk08n8llv8\") instead for better reliability.")
	var _container: GBCompositionContainer = _resolve_container(container)
	var injector: GBInjectorSystem = _create_injector_for_container(test, _container)

	# Create scene nodes
	var placer: Node2D = _create_standard_positioner(test, "TestPlacer")
	var placed_parent: Node2D = _setup_placed_parent(test, _container)
	var grid_positioner: Node2D = _create_standard_positioner(test, "TestGridPositioner")

	# Access shared states from the pre-configured test container
	var states: GBStates = _container.get_states()
	var targeting_state: GridTargetingState = states.targeting
	var map_layer: TileMapLayer = _create_standard_tile_map(test)
	_setup_basic_targeting_state(targeting_state, grid_positioner, map_layer)
	var mode_state: ModeState = states.mode

	# Proper owner setup: create a GBOwner node and resolve dependencies
	var gb_owner: GBOwner = _create_standard_gb_owner(test, placer, _container)

	# Create IndicatorManager with factory pattern for proper dependency injection
	var indicator_manager: IndicatorManager = create_test_indicator_manager(test, _container)

	# Build system with injected dependencies
	var system: BuildingSystem = _create_system_with_injection(test, BuildingSystem, _container, "TestBuildingSystem")

	return {
		"container": _container,
		"injector": injector,
		"placer": placer,
		"placed_parent": placed_parent,
		"grid_positioner": grid_positioner,
		"positioner": grid_positioner,  # Backward compatibility alias
		"targeting_state": targeting_state,
		"map_layer": map_layer,
		"tile_map_layer": map_layer,  # Backward compatibility alias
		"mode_state": mode_state,
		"gb_owner": gb_owner,
		"indicator_manager": indicator_manager,
		"system": system,
		"building_system": system  # Backward compatibility alias
	}

## Creates injection test environment for testing dependency injection
##
## [b]⚠️  DEPRECATED - Use Scene-Based Environments Instead[/b]
##
## This factory method is being deprecated in favor of pre-configured scene environments.
## **Recommended replacement:**
## ```gdscript
## # OLD (deprecated):
## var env = UnifiedTestFactory.create_injection_test_environment(self)
## 
## # NEW (recommended):
## var env = UnifiedTestFactory.instance_building_test_env(self, "uid://c4ujk08n8llv8")
## # Access properties directly: env.building_system, env.indicator_manager, env.injector, etc.
## ```
##
## [b]Parameters[/b]:
##  • [code]test[/code]: GdUnitTestSuite – test suite for parenting/autofree
##  • [code]container[/code]: GBCompositionContainer – base container (defaults to TEST_CONTAINER)
## [b]Returns[/b]: Dictionary – complete injection test environment
static func create_injection_test_environment(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	push_warning("DEPRECATED: create_injection_test_environment() is deprecated. Use UnifiedTestFactory.instance_building_test_env(test, \"uid://c4ujk08n8llv8\") instead for better reliability.")
	var _container: GBCompositionContainer = _resolve_container(container)

	# Set up injection system
	var injector: GBInjectorSystem = _create_system_with_injection(test, GBInjectorSystem, _container, "GBInjectorSystem")

	# Set up targeting state dependencies (required for IndicatorManager)
	var targeting_state: GridTargetingState = _container.get_states().targeting
	var map_layer: TileMapLayer = _create_standard_tile_map(test)
	var positioner: Node2D = _create_standard_positioner(test)
	_setup_basic_targeting_state(targeting_state, positioner, map_layer)

	return {
		"container": _container,
		"injector": injector,
		"targeting_state": targeting_state,
		"map_layer": map_layer,
		"positioner": positioner
	}

## ✅ **RECOMMENDED** - Instances AllSystemsTestEnvironment scene and validates it
##
## This is the **preferred method** for creating comprehensive test environments.
## The scene-based approach provides 100% passive initialization with no dependency timing issues.
##
## **Usage:**
## ```gdscript
## func before_test():
##     test_env = UnifiedTestFactory.instance_all_systems_env(self, "uid://ioucajhfxc8b")
##     # All systems ready: test_env.building_system, test_env.manipulation_system, etc.
## ```
##
## **Benefits:**
## - ✅ No dependency injection timing issues (100% passive)
## - ✅ Built-in runtime validation via `env.get_issues()`  
## - ✅ Visual scene editor configuration
## - ✅ Better performance than factory assembly
static func instance_all_systems_env(test : GdUnitTestSuite, resource_path_or_uid : String) -> AllSystemsTestEnvironment:
	var env : AllSystemsTestEnvironment = load(resource_path_or_uid).instantiate()
	test.add_child(env)
	test.auto_free(env)
	test.assert_array(env.get_issues()).append_failure_message("Environment is not properly setup. Issues: %s" % str(env.get_issues())).is_empty()
	return env

## ✅ **RECOMMENDED** - Instances BuildingTestEnvironment scene and validates it
##
## This is the **preferred method** for building system and dependency injection tests.
## The scene-based approach provides 100% passive initialization with no dependency timing issues.
##
## **Usage:**
## ```gdscript
## func before_test():
##     test_env = UnifiedTestFactory.instance_building_test_env(self, "uid://c4ujk08n8llv8")
##     # Access properties: test_env.building_system, test_env.indicator_manager, etc.
## ```
##
## **Benefits:**
## - ✅ No dependency injection timing issues (100% passive)
## - ✅ Built-in runtime validation via `env.get_issues()`  
## - ✅ Visual scene editor configuration
## - ✅ Better performance than factory assembly
static func instance_building_test_env(test: GdUnitTestSuite, resource_path_or_uid : String) -> BuildingTestEnvironment:
	var env : BuildingTestEnvironment= load(resource_path_or_uid).instantiate()
	test.add_child(env)
	test.auto_free(env)
	test.assert_array(env.get_issues()).is_empty()
	return env

## ✅ **RECOMMENDED** - Instances CollisionTestEnvironment scene and validates it
##
## This is the **preferred method** for collision detection and indicator management tests.
## The scene-based approach provides 100% passive initialization with no dependency timing issues.
##
## **Usage:**
## ```gdscript
## func before_test():
##     test_env = UnifiedTestFactory.instance_collision_test_env(self, "uid://cdrtd538vrmun")
##     # Access properties: test_env.indicator_manager, test_env.collision_mapper, etc.
## ```
##
## **Benefits:**
## - ✅ No dependency injection timing issues (100% passive)
## - ✅ Built-in runtime validation via `env.get_issues()`  
## - ✅ Visual scene editor configuration
## - ✅ Better performance than factory assembly
static func instance_collision_test_env(test : GdUnitTestSuite, resource_path_or_uid : String) -> CollisionTestEnvironment:
	var env : CollisionTestEnvironment = load(resource_path_or_uid).instantiate()
	test.add_child(env)
	test.auto_free(env)
	test.assert_array(env.get_issues()).is_empty()
	return env

## ✅ **RECOMMENDED** - Instances IsometricBuildingTestEnvironment scene and validates it
##
## This is the **preferred method** for isometric view and complex building scenario tests.
## The scene-based approach provides 100% passive initialization with no dependency timing issues.
##
## **Usage:**
## ```gdscript
## func before_test():
##     test_env = UnifiedTestFactory.instance_isometric_building_test_env(self, "uid://d3yeah2uexha2")
##     # Access properties: test_env.building_system, test_env.indicator_manager, etc.
## ```
##
## **Benefits:**
## - ✅ No dependency injection timing issues (100% passive)
## - ✅ Built-in runtime validation via `env.get_issues()`  
## - ✅ Visual scene editor configuration
## - ✅ Better performance than factory assembly
static func instance_isometric_building_test_env(test: GdUnitTestSuite, resource_path_or_uid : String) -> Node:
	var env: Node = load(resource_path_or_uid).instantiate()
	test.add_child(env)
	test.auto_free(env)
	if env.has_method("get_issues"):
		test.assert_array(env.get_issues()).is_empty()
	return env

# ================================
# Comprehensive Integration Test Factories
# ================================

## Factory Usage Guide:
## 
## 1. create_basic_test_setup() - For simple unit tests
##    - Just injector, container, logger, basic objects
##    - Use when testing individual classes or methods
##
## 2. create_indicator_test_hierarchy() - For collision/indicator tests  
##    - Base hierarchy: positioner -> manipulation_parent -> indicator_manager
##    - Includes collision_mapper, tile_map, targeting/manipulation states
##    - Use for testing indicators, collision detection, positioning
##
## 3. create_systems_test_hierarchy() - For focused system tests
##    - Builds on indicator hierarchy + specific systems as needed
##    - Use when testing individual systems (building, manipulation, targeting)
##    - More efficient than full integration for focused tests
##
## 4. create_full_integration_test_scene() - For complete integration tests
##    - Builds on indicator hierarchy + all systems + all managers
##    - Use for end-to-end testing, full workflow validation
##    - Most complete but also heaviest setup
##
## All factories build upon each other for consistency and efficiency.

## Creates a complete test scene hierarchy with all systems for integration testing
## Returns a dictionary with all components for easy access
## Builds upon the indicator test hierarchy for consistency
static func create_full_integration_test_scene(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	
	# Start with the indicator hierarchy as base
	var scene_dict: Dictionary = create_indicator_test_hierarchy(test, _container)
	
	# Add the additional systems needed for full integration
	scene_dict.building_system = create_building_system(test, _container)
	scene_dict.manipulation_system = create_manipulation_system(test, _container)
	scene_dict.targeting_system = create_grid_targeting_system(test, _container)
	
	# Add additional managers for full integration testing
	scene_dict.object_manager = Node2D.new()
	scene_dict.object_manager.name = "TestObjectManager"
	test.auto_free(scene_dict.object_manager)
	test.add_child(scene_dict.object_manager)
	
	# Create indicator manager if available
	if ClassDB.class_exists("IndicatorManager"):
		scene_dict.indicator_manager = ClassDB.instantiate("IndicatorManager")
		test.auto_free(scene_dict.indicator_manager)
		test.add_child(scene_dict.indicator_manager)
	
	# Create grid - basic Node2D for testing
	scene_dict.grid = Node2D.new()
	scene_dict.grid.name = "TestGrid"
	test.auto_free(scene_dict.grid)
	test.add_child(scene_dict.grid)
	
	# Note: container and logger are already included from indicator hierarchy
	
	return scene_dict

## Creates a systems test hierarchy for testing individual systems
## Builds upon indicator hierarchy but adds only specific systems as needed
static func create_systems_test_hierarchy(test: GdUnitTestSuite, systems_needed: Array = [], container: GBCompositionContainer = null) -> Dictionary:
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	
	# Start with the indicator hierarchy as base
	var systems_dict: Dictionary = create_indicator_test_hierarchy(test, _container)
	
	# Add only the requested systems
	for system_name: String in systems_needed:
		match system_name:
			"building":
				systems_dict.building_system = create_building_system(test, _container)
			"manipulation":
				systems_dict.manipulation_system = create_manipulation_system(test, _container)
			"targeting":
				systems_dict.targeting_system = create_grid_targeting_system(test, _container)
			"object_manager": ## The node where preview objects are added under
				systems_dict.object_manager = Node2D.new()
				systems_dict.object_manager.name = "TestObjectManager"
				test.auto_free(systems_dict.object_manager)
				test.add_child(systems_dict.object_manager)
	
	return systems_dict

## Creates a simplified hierarchy for indicator/collision tests
## positioner -> manipulation_parent -> indicator_manager with collision mapping
static func create_indicator_test_hierarchy(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	assert(test != null, "Test suite cannot be null")
	
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	assert(_container != null, "Failed to create or get composition container")
	
	var hierarchy: Dictionary = {}
	
	# Create injector system first
	hierarchy.injector = create_test_injector(test, _container)
	assert(hierarchy.injector != null, "Failed to create test injector")
	
	# Create hierarchy
	hierarchy.positioner = test.auto_free(GridPositioner2D.new())
	assert(hierarchy.positioner != null, "Failed to create positioner node")
	hierarchy.positioner.name = "TestPositioner"
	test.add_child(hierarchy.positioner)  # Add to scene tree for position changes to work
	
	hierarchy.manipulation_parent = Node2D.new()
	hierarchy.manipulation_parent.name = "TestManipulationParent"
	test.auto_free(hierarchy.manipulation_parent)
	hierarchy.positioner.add_child(hierarchy.manipulation_parent)
	
	# Create and configure tile map
	hierarchy.tile_map = test.auto_free(TileMapLayer.new())
	assert(hierarchy.tile_map != null, "Failed to create tile map layer")
	
	# Initialize tile set for the tile map
	var tile_set := TileSet.new()
	hierarchy.tile_map.tile_set = tile_set
	hierarchy.tile_map.tile_set.tile_size = Vector2i(32, 32)
	
	# Configure states
	var targeting_state: GridTargetingState = _container.get_states().targeting
	assert(targeting_state != null, "Failed to get targeting state from container")
	targeting_state.positioner = hierarchy.positioner
	var map_objects: Array[TileMapLayer] = [hierarchy.tile_map]
	targeting_state.set_map_objects(hierarchy.tile_map, map_objects)
	
	# Create default target node for tests
	hierarchy.default_target = test.auto_free(Node2D.new())
	hierarchy.default_target.name = "DefaultTestTarget"
	hierarchy.default_target.position = Vector2(50, 50)  # Default test position
	targeting_state.target = hierarchy.default_target
	
	var manipulation_state: ManipulationState = _container.get_states().manipulation
	assert(manipulation_state != null, "Failed to get manipulation state from container")
	manipulation_state.parent = hierarchy.manipulation_parent
	
	# Create indicator manager with collision mapping
	hierarchy.indicator_manager = IndicatorManager.create_with_injection(_container, hierarchy.manipulation_parent)
	assert(hierarchy.indicator_manager != null, "Failed to create indicator manager")
	test.auto_free(hierarchy.indicator_manager)
	
	# Create collision mapper
	hierarchy.collision_mapper = CollisionMapper.new(targeting_state, _container.get_logger())
	assert(hierarchy.collision_mapper != null, "Failed to create collision mapper")
	test.auto_free(hierarchy.collision_mapper)
	
	# Configure collision mapper for testing
	configure_collision_mapper_for_test_object(test, hierarchy.indicator_manager, hierarchy.positioner, _container, hierarchy.positioner)
	
	hierarchy.container = _container
	hierarchy.logger = _container.get_logger()
	hierarchy.targeting_state = targeting_state
	hierarchy.manipulation_state = manipulation_state
	
	# Final validation of the complete hierarchy
	assert(hierarchy.has("positioner"), "Hierarchy missing positioner")
	assert(hierarchy.has("manipulation_parent"), "Hierarchy missing manipulation_parent")
	assert(hierarchy.has("indicator_manager"), "Hierarchy missing indicator_manager")
	assert(hierarchy.has("collision_mapper"), "Hierarchy missing collision_mapper")
	assert(hierarchy.has("tile_map"), "Hierarchy missing tile_map")
	
	return hierarchy

## Creates collision mapper setup for collision tests
static func create_collision_mapper_setup(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	var tile_map: TileMapLayer = create_test_tile_map_layer(test)
	var targeting_state: GridTargetingState = create_targeting_state(test)
	
	return {
		"container": _container,
		"logger": _container.get_logger(),
		"tile_map": tile_map,
		"targeting_state": targeting_state,
		"collision_mapper": CollisionMapper.new(targeting_state, _container.get_logger()),
		"tile_size": TILE_SIZE_VEC
	}

## Creates parameters for rule validation tests
## Returns a dictionary with targeting state and related objects needed for rule setup and validation
static func create_rule_validation_parameters(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary[String, Object]:
	assert(test != null, "test parameter cannot be null")
	
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	assert(_container != null, "Failed to resolve container for rule validation")
	
	var targeting_state: GridTargetingState = create_targeting_state(test)
	assert(targeting_state != null, "create_targeting_state returned null")
	
	var tile_map: TileMapLayer = create_test_tile_map_layer(test)
	assert(tile_map != null, "create_test_tile_map_layer returned null")
	
	# Set up targeting state with tile map
	targeting_state.target_map = tile_map
	assert(targeting_state.target_map == tile_map, "Failed to assign target_map to targeting_state")
	
	# Create positioner if needed
	if targeting_state.positioner == null:
		targeting_state.positioner = _create_standard_positioner(test)
		assert(targeting_state.positioner != null, "Failed to create standard positioner")
	
	var logger: GBLogger = _container.get_logger()
	assert(logger != null, "container.get_logger() returned null")
	
	return {
		"targeting_state": targeting_state,
		"container": _container,
		"logger": logger,
		"tile_map": tile_map,
		"positioner": targeting_state.positioner
	}

## Creates a basic test setup with injector and common objects
static func create_basic_test_setup(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container: GBCompositionContainer = _resolve_container(container)
	var setup: Dictionary = {}

	# Create injector system first
	setup.injector = _create_injector_for_container(test, _container)

	# Basic objects most tests need
	setup.container = _container
	setup.logger = _container.get_logger()
	setup.object_manager = _create_standard_positioner(test, "TestObjectManager")
	setup.grid = _create_standard_positioner(test, "TestGrid")

	# Initialize basic container states for composition container tests
	var targeting_state: GridTargetingState = _container.get_states().targeting
	if targeting_state.positioner == null:
		targeting_state.positioner = _create_standard_positioner(test)

	if targeting_state.target_map == null:
		var map_layer: TileMapLayer = _create_standard_tile_map(test)
		targeting_state.set_map_objects(map_layer, [map_layer])

	var building_state: BuildingState = _container.get_states().building
	if building_state.placed_parent == null:
		building_state.placed_parent = setup.object_manager

	var manipulation_state: ManipulationState = _container.get_states().manipulation
	if manipulation_state.parent == null:
		manipulation_state.parent = setup.object_manager

	return setup

# ================================
# COMMON TEST ASSERTION HELPERS - DRY Test Patterns
# ================================

## Creates standardized polygon test object setup for indicator tests
static func create_polygon_test_setup(test: GdUnitTestSuite, parent: Node, position: Vector2 = Vector2.ZERO) -> Dictionary:
	var polygon_obj: Node2D = create_polygon_test_object(test)
	parent.add_child(polygon_obj)
	polygon_obj.position = position
	
	var rules: Array[TileCheckRule] = [_create_standard_collision_rule()]
	
	return {
		"polygon_obj": polygon_obj,
		"rule": _create_standard_collision_rule(),
		"rules": rules
	}

## Creates standardized collision rule for testing
static func _create_standard_collision_rule() -> CollisionsCheckRule:
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1
	rule.collision_mask = 1
	return rule

## Creates standardized indicator setup for testing
static func create_indicator_test_setup(test: GdUnitTestSuite, container: GBCompositionContainer, polygon_obj: Node2D, rules: Array[TileCheckRule]) -> Dictionary:
	var indicator_manager: IndicatorManager = create_test_indicator_manager(test, container)
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(polygon_obj, rules)
	
	# Ensure indicators are properly parented to the indicator manager
	if report and report.indicators:
		for indicator in report.indicators:
			if indicator.get_parent() != indicator_manager:
				# Remove from current parent and add to indicator manager
				indicator.get_parent().remove_child(indicator)
				indicator_manager.add_child(indicator)
	
	return {
		"indicator_manager": indicator_manager,
		"report": report,
		"indicators": report.indicators if report else []
	}

## Standardized assertion for indicator count validation
static func assert_indicator_count(report: IndicatorSetupReport, expected_count: int, context: String = "") -> void:
	var message: String = "Expected %d indicators, got %d" % [expected_count, report.indicators.size()]
	if context: message += " (%s)" % context
	assert(report.indicators.size() == expected_count, message)

## Standardized assertion for origin tile exclusion
static func assert_no_origin_indicator(indicators: Array[Node2D], map: TileMapLayer, context: String = "") -> void:
	var origin_indicators: Array = []
	for indicator in indicators:
		var tile_pos: Vector2i = map.local_to_map(map.to_local(indicator.global_position))
		if tile_pos == Vector2i.ZERO:
			origin_indicators.append(indicator)
	
	var message: String = "Found %d indicators at origin (0,0) - should be excluded" % origin_indicators.size()
	if context: message += " (%s)" % context
	assert(origin_indicators.is_empty(), message)

## Standardized assertion for parent architecture validation
static func assert_parent_architecture(indicator_manager: IndicatorManager, manipulation_parent: Node2D, indicators: Array[Node2D], context: String = "") -> void:
	# IndicatorManager should be child of manipulation parent
	var message: String = "IndicatorManager should be child of ManipulationParent"
	if context: message += " (%s)" % context
	assert(indicator_manager.get_parent() == manipulation_parent, message)
	
	# All indicators should be children of indicator manager
	for indicator in indicators:
		message = "Indicator should be child of IndicatorManager"
		if context: message += " (%s)" % context
		assert(indicator.get_parent() == indicator_manager, message)

## Standardized assertion for collision layer validation
static func assert_collision_layer_setup(collision_node: Node2D, expected_layer: int, context: String = "") -> void:
	var collision_layer: int = 0
	if collision_node is Area2D:
		collision_layer = collision_node.collision_layer
	elif collision_node is StaticBody2D:
		collision_layer = collision_node.collision_layer
	elif collision_node is ShapeCast2D:
		# ShapeCast2D uses collision_mask instead of collision_layer
		collision_layer = collision_node.collision_mask
	
	var message: String = "Expected collision layer %d, got %d" % [expected_layer, collision_layer]
	if context: message += " (%s)" % context
	assert(collision_layer == expected_layer, message)

## Standardized assertion for rule validation results
static func assert_rule_validation_result(result: Dictionary, expected_valid: bool, context: String = "") -> void:
	var message: String = "Expected validation result %s, got %s" % [expected_valid, result.get("valid", "missing")]
	if context: message += " (%s)" % context
	assert(result.get("valid", false) == expected_valid, message)

## Ensures the indicator template is properly configured in the container
static func ensure_indicator_template_configured(container: GBCompositionContainer) -> void:
	var templates: GBTemplates = container.get_templates()
	if templates == null:
		push_error("Container templates is null - cannot configure indicator template")
		return
		
	if templates.rule_check_indicator == null:
		# Try to load the standard indicator template
		var standard_indicator: PackedScene = load("res://templates/grid_building_templates/indicator/rule_check_indicator_16x16.tscn")
		if standard_indicator:
			templates.rule_check_indicator = standard_indicator
		else:
			push_error("Could not load standard indicator template - tests may fail")

## Creates a targeting state with intentional runtime issues for testing error handling
## @param test: The test suite instance
## @param container: The composition container to use
## @param runtime_issue_type: Type of runtime issue to inject ("null_target_map", "null_positioner", "empty_maps")
## @return Dictionary containing the setup with intentional runtime issues
static func create_targeting_state_with_runtime_issues(
	test: GdUnitTestSuite, 
	container: GBCompositionContainer,
	runtime_issue_type: String = "null_target_map"
) -> Dictionary:
	var setup: Dictionary = {}
	
	# Create injector system first
	setup.injector = create_test_injector(test, container)
	
	# Get targeting state from container
	var targeting_state: GridTargetingState = container.get_states().targeting
	setup.targeting_state = targeting_state
	
	# Create positioner
	setup.positioner = test.auto_free(Node2D.new())
	setup.positioner.name = "TestPositioner"
	
	# Create tile map (but don't assign it based on issue type)
	var tile_map: TileMapLayer = test.auto_free(TileMapLayer.new())
	tile_map.tile_set.tile_size = Vector2i(32, 32)
	setup.tile_map = tile_map
	
	# Configure targeting state based on the type of runtime issue we want to test
	match runtime_issue_type:
		"null_target_map":
			# Set positioner but leave target_map null to create runtime issue
			targeting_state.positioner = setup.positioner
			# Intentionally don't set target_map or call set_map_objects
			targeting_state.target_map = null
			targeting_state.maps = []
			
		"null_positioner":
			# Set target_map but leave positioner null
			targeting_state.target_map = tile_map
			targeting_state.set_map_objects(tile_map, [tile_map])
			# Intentionally don't set positioner
			
		"empty_maps":
			# Set positioner and target_map but leave maps array empty
			targeting_state.positioner = setup.positioner
			targeting_state.target_map = tile_map
			targeting_state.maps = []  # Empty maps array
			
		_:
			push_error("Unknown runtime issue type: " + runtime_issue_type)
	
	# Create default target node
	setup.default_target = test.auto_free(Node2D.new())
	setup.default_target.name = "DefaultTestTarget"
	setup.default_target.position = Vector2(50, 50)
	targeting_state.target = setup.default_target
	
	# Ensure indicator template is configured
	ensure_indicator_template_configured(container)
	
	return setup
	
	
## Create isometric tilemap with demo-accurate configuration
static func create_isometric_tilemap(test : GdUnitTestSuite) -> TileMapLayer:
	var tilemap_layer: TileMapLayer = test.auto_free(TileMapLayer.new())
	var tileset: TileSet = TileSet.new()
	
	# Configure exactly like isometric demo
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN  
	tileset.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
	tileset.tile_size = Vector2i(90, 50)  # Demo's exact tile dimensions
	
	tilemap_layer.tile_set = tileset
	test.auto_free(tilemap_layer)
	test.add_child(tilemap_layer)
	return tilemap_layer

## Prepares a TargetingState to be READY for use by setting up all required dependencies
## Uses GBLevelContext pattern to properly configure target_map, maps array, and objects_parent
## Returns a dictionary with all the setup components for testing
static func prepare_targeting_state_ready(
	test: GdUnitTestSuite, 
	container: GBCompositionContainer = null
) -> Dictionary:
	var _container: GBCompositionContainer = container if container != null else TEST_CONTAINER.duplicate(true)
	var setup: Dictionary = {}
	
	# Create core scene nodes
	setup.positioner = test.auto_free(Node2D.new())
	setup.positioner.name = "TestPositioner"
	
	setup.objects_parent = Node2D.new()
	setup.objects_parent.name = "TestObjectsParent"
	test.auto_free(setup.objects_parent)
	
	# Create tile map layer for targeting
	setup.tile_map = test.auto_free(TileMapLayer.new())
	setup.tile_map.tile_set.tile_size = Vector2i(16, 16)
	
	# Apply level context to container states
	var targeting_state: GridTargetingState = _container.get_states().targeting
	var building_state: BuildingState = _container.get_states().building
	
	# Set runtime dependencies for targeting map instead of using GBLevelContext
	targeting_state.positioner = setup.positioner
	targeting_state.target_map = setup.tile_map
	targeting_state.maps = [setup.tile_map]
	
	# Create default target for testing 
	setup.default_target = test.auto_free(Node2D.new())
	setup.default_target.name = "DefaultTestTarget"
	setup.default_target.position = Vector2(50, 50)
	targeting_state.target = setup.default_target
	
	# Ensure indicator template is configured
	ensure_indicator_template_configured(container)
	
	return setup

## Helper function to ensure container has templates initialized
static func _ensure_container_has_templates(container: GBCompositionContainer, test: GdUnitTestSuite) -> void:
	if container.config == null:
		container.config = GBConfig.new()
		test.auto_free(container.config)

	if container.config.templates == null:
		var templates := GBTemplates.new()
		templates.rule_check_indicator = preload("res://addons/grid_building/placement/rule_check_indicator/rule_check_indicator.tscn")
		container.config.templates = templates
		test.auto_free(templates)

## Creates a standardized positioner node with consistent naming
static func _create_standard_positioner(test: GdUnitTestSuite, name: String = "TestPositioner") -> Node2D:
	var positioner: Node2D = GodotTestFactory.create_node2d(test)
	positioner.name = name
	return positioner

## Creates a standardized tile map layer for testing
static func _create_standard_tile_map(test: GdUnitTestSuite, tile_size: int = DEFAULT_TILE_SIZE) -> TileMapLayer:
	var tile_map: TileMapLayer = GodotTestFactory.create_tile_map_layer(test)
	var tile_set := TileSet.new()
	var atlas := TileSetAtlasSource.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	atlas.texture = tex
	atlas.create_tile(Vector2i(0,0))
	tile_set.add_source(atlas)
	tile_set.tile_size = Vector2i(tile_size, tile_size)
	tile_map.tile_set = tile_set
	return tile_map

## Configures a GridTargetingState with standard test settings
static func _setup_basic_targeting_state(targeting_state: GridTargetingState, positioner: Node2D, tile_map: TileMapLayer) -> void:
	targeting_state.positioner = positioner
	targeting_state.target_map = tile_map

## Sets up a manipulation parent node for testing
static func _setup_manipulation_parent(test: GdUnitTestSuite, _container: GBCompositionContainer, _positioner: Node2D) -> Node2D:
	var manipulation_parent: Node2D = GodotTestFactory.create_node2d(test)
	manipulation_parent.name = "ManipulationParent"
	return manipulation_parent

## Sets up a placed parent node for testing
static func _setup_placed_parent(test: GdUnitTestSuite, _container: GBCompositionContainer) -> Node2D:
	var placed_parent: Node2D = GodotTestFactory.create_node2d(test)
	placed_parent.name = "PlacedParent"
	return placed_parent

## Creates a standard Grid Building owner for testing
static func _create_standard_gb_owner(test: GdUnitTestSuite, owner_node: Node2D, container: GBCompositionContainer) -> GBOwner:
	var gb_owner: GBOwner = GBOwner.new(owner_node)
	test.add_child(gb_owner)
	gb_owner.resolve_gb_dependencies(container)
	return gb_owner

## Sets up owner context for testing
static func _setup_owner_context(_test: GdUnitTestSuite, container: GBCompositionContainer, owner_node: Node2D) -> GBOwnerContext:
	var owner_context: GBOwnerContext = container.get_contexts().owner
	var gb_owner: GBOwner = _create_standard_gb_owner(_test, owner_node, container)
	owner_context.set_owner(gb_owner)
	return owner_context

## Creates an injector system for the given container
static func _create_injector_for_container(test: GdUnitTestSuite, container: GBCompositionContainer) -> GBInjectorSystem:
	return create_test_injector(test, container)

## Resolves container parameter, using default if null
static func _resolve_container(container: GBCompositionContainer) -> GBCompositionContainer:
	return container if container != null else TEST_CONTAINER.duplicate(true)

## Creates a system with injection pattern and standard configuration
static func _create_system_with_injection(test: GdUnitTestSuite, system_class: GDScript, container: GBCompositionContainer, system_name: String) -> Node:
	var system: Node = system_class.new()
	system.resolve_gb_dependencies(container)
	test.auto_free(system)
	test.add_child(system)
	system.name = system_name
	return system
