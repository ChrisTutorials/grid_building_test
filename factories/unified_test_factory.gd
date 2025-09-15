class_name UnifiedTestFactory
extends RefCounted

## Unified Test Factory - Convenience Facade for Test Creation
##
## MIGRATION IN PROGRESS: Moving toward "Env pattern" for complex objects.
## This factory serves as a convenience layer and maintains backward compatibility.
##
## NEW PATTERN: Use EnvironmentTestFactory for complete test environments
## - AllSystemsTestEnvironment: Full system integration testing
## - BuildingTestEnvironment: Building system focused testing
## - CollisionTestEnvironment: Collision system focused testing
##
## LEGACY METHODS: Individual object factories are being phased out.
## Use environments for complex object graphs, individual factories only for simple objects.
##
## Specialized Factories (use directly for new code):
## - EnvironmentTestFactory: Test environments and validation
## - PlaceableTestFactory: Placeable objects with rules
## - PlacementRuleTestFactory: Collision/tile placement rules
## - GodotTestFactory: Basic Godot objects
## - CollisionObjectTestFactory: Collision shapes/objects

#region ENVIRONMENT DELEGATE METHODS

## Delegate: Create AllSystemsTestEnvironment
static func instance_all_systems_env(test: GdUnitTestSuite, resource_path_or_uid: String) -> AllSystemsTestEnvironment:
	return EnvironmentTestFactory.create_all_systems_env(test, resource_path_or_uid)

## Delegate: Create building test environment (legacy)
static func instance_building_test_env(test: GdUnitTestSuite, resource_path_or_uid: String) -> Node:
	var env: Node = load(resource_path_or_uid).instantiate()
	test.add_child(env)
	test.auto_free(env)
	return env

## Delegate: Create collision test environment (legacy)
static func instance_collision_test_env(test: GdUnitTestSuite, resource_path_or_uid: String) -> Node:
	var env: Node = load(resource_path_or_uid).instantiate()
	test.add_child(env)
	test.auto_free(env)
	return env

## Delegate: Validate environment setup
static func validate_environment_setup(env: AllSystemsTestEnvironment, context: String = "Test environment") -> bool:
	return EnvironmentTestFactory.validate_environment_setup(env, context)

#endregion

#region PLACEABLE DELEGATE METHODS

## Delegate: Create polygon test placeable
static func create_polygon_test_placeable(test: GdUnitTestSuite) -> Placeable:
	return PlaceableTestFactory.create_polygon_test_placeable(test)

## Delegate: Create polygon test setup with rules
static func create_polygon_test_setup(test_instance: Node) -> Dictionary:
	return PlaceableTestFactory.create_polygon_test_setup(test_instance)

## Delegate: Create test placeable with standard rules
static func create_test_placeable_with_rules(base_placeable: Placeable, display_name: String = "Test Placeable With Rules", include_tile_rule: bool = true) -> Placeable:
	return PlaceableTestFactory.create_test_placeable_with_rules(base_placeable, display_name, include_tile_rule)

#endregion

#region RULE DELEGATE METHODS

## Delegate: Create collision rule with settings
static func create_collision_rule_with_settings(apply_mask: int, collision_mask: int, pass_on_collision: bool = true) -> CollisionsCheckRule:
	return PlacementRuleTestFactory.create_collision_rule_with_settings(apply_mask, collision_mask, pass_on_collision)

## Delegate: Create standard placement rules array
static func create_standard_placement_rules(include_tile_rule: bool = true) -> Array[PlacementRule]:
	return PlacementRuleTestFactory.create_standard_placement_rules(include_tile_rule)

## Delegate: Create default collisions check rule
static func create_test_collisions_check_rule() -> CollisionsCheckRule:
	return PlacementRuleTestFactory.create_default_collision_rule()

#endregion

#region BASIC SETUP DELEGATE METHODS

## Delegate: Create basic test setup dictionary
## @deprecated Use AllSystemsTestEnvironment or specific test environments instead
static func create_basic_test_setup(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	if container == null:
		container = create_test_composition_container(test)
	return {
		"test_suite": test,
		"container": container,
		"setup_complete": true
	}

## Delegate: Create rule validation parameters
## @deprecated Use AllSystemsTestEnvironment or specific test environments instead
static func create_rule_validation_parameters(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	if container == null:
		container = create_test_composition_container(test)
	return {
		"validation_container": container,
		"rule_context": create_owner_context(test),
		"rules": create_standard_placement_rules()
	}

## Delegate: Create collision mapper setup
## @deprecated Use CollisionTestEnvironment or AllSystemsTestEnvironment instead
static func create_collision_mapper_setup(test: GdUnitTestSuite) -> Dictionary:
	# Delegate to proper factory method instead of creating directly
	var targeting_state: GridTargetingState = create_minimal_targeting_state(test)
	var logger: GBLogger = create_test_logger()
	return {
		"collision_mapper": CollisionMapper.new(targeting_state, logger),
		"positioner": create_grid_positioner(test),
		"test_suite": test
	}

## Delegate: Create test composition container
static func create_test_composition_container(test: GdUnitTestSuite) -> GBCompositionContainer:
	var container: GBCompositionContainer = GBCompositionContainer.new()
	test.auto_free(container)
	return container

## Delegate: Create owner context
static func create_owner_context(test: GdUnitTestSuite) -> GBOwnerContext:
	var context: GBOwnerContext = GBOwnerContext.new()
	# TODO: Fix owner context setup - requires GBOwner object, not string
	# context.owner_id = "test_owner"
	# context.game_time = 0.0
	test.auto_free(context)
	return context

#endregion

#region GODOT OBJECT DELEGATE METHODS

## Delegate: Create test Node2D
static func create_test_node2d(test: GdUnitTestSuite) -> Node2D:
	return GodotTestFactory.create_node2d(test)

## Delegate: Create double targeting state
static func create_double_targeting_state(test: GdUnitTestSuite) -> GridTargetingState:
	var state: GridTargetingState = GridTargetingState.new(GBOwnerContext.new())
	test.auto_free(state)
	
	# Set up maps and positioner automatically
	var test_map := GodotTestFactory.create_tile_map_layer(test)
	test.auto_free(test_map)
	state.target_map = test_map
	state.maps = [test_map]
	
	var test_positioner := create_test_node2d(test)
	test.auto_free(test_positioner)
	state.positioner = test_positioner
	
	return state

## Delegate: Create minimal targeting state
static func create_minimal_targeting_state(test: GdUnitTestSuite, _is_active: bool = true, _is_ready: bool = true) -> GridTargetingState:
	var state: GridTargetingState = create_double_targeting_state(test)
	state.ready = _is_ready
	return state


## Delegate: Create test static body with rect shape
static func create_test_static_body_with_rect_shape(test: GdUnitTestSuite) -> StaticBody2D:
	return GodotTestFactory.create_static_body_with_rect_shape(test, Vector2(32, 32))  # TODO: Use GBTestConstants.DEFAULT_TILE_SIZE

## Delegate: Create eclipse test object
static func create_eclipse_test_object(test: GdUnitTestSuite) -> Node2D:
	return CollisionObjectTestFactory.create_polygon_test_object(test)

#endregion

#region UTILITY DELEGATE METHODS

## Delegate: Create grid positioner
static func create_grid_positioner(test: GdUnitTestSuite) -> GridPositioner2D:
	var positioner: GridPositioner2D = GridPositioner2D.new()
	test.auto_free(positioner)
	return positioner

## Delegate: Create test logger  
static func create_test_logger() -> GBLogger:
	return GBLogger.new()

## Delegate: Create tile map layer
static func create_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	var tile_map: TileMapLayer = TileMapLayer.new()
	test.auto_free(tile_map)
	return tile_map

#endregion

#region ESSENTIAL LEGACY METHODS

## Legacy constants for backward compatibility - DEPRECATED: Use GBTestConstants instead
## @deprecated Use GBTestConstants.DEFAULT_TILE_SIZE
const DEFAULT_TILE_SIZE := Vector2(32, 32)  # From GBTestConstants.DEFAULT_TILE_SIZE
## @deprecated Use GBTestConstants.TEST_COLLISION_LAYER  
const COLLISION_LAYER_BIT_0 := 1  # From GBTestConstants.TEST_COLLISION_LAYER
## @deprecated Use GBTestConstants.ALL_SYSTEMS_ENV_UID
const ALL_SYSTEMS_ENV_UID := "uid://ioucajhfxc8b"  # From GBTestConstants.ALL_SYSTEMS_ENV_UID
# TEST_CONTAINER removed - resource file does not exist

## Essential method still used by PlaceableTestFactory - delegate to CollisionObjectTestFactory
static func create_polygon_test_object(test: Node) -> Node2D:
	return CollisionObjectTestFactory.create_polygon_test_object(test)

#endregion

## Delegate: Create test manipulatable
static func create_test_manipulatable(test: GdUnitTestSuite) -> Manipulatable:
	var manipulatable: Manipulatable = Manipulatable.new()
	test.add_child(manipulatable)
	test.auto_free(manipulatable)
	return manipulatable

## Delegate: Assert placement report success
static func assert_placement_report_success(_test: GdUnitTestSuite, report: PlacementReport) -> void:
	assert(report.is_success(), "Placement report should be successful")

## Delegate: Create test collision rule
static func create_test_collision_rule() -> CollisionsCheckRule:
	return create_collision_rule_with_settings(1, 1, true)

## Delegate: Create test tile rule
static func create_test_tile_rule() -> TileCheckRule:
	return TileCheckRule.new()

## Delegate: Assert system dependencies valid
static func assert_system_dependencies_valid(_test: GdUnitTestSuite, system: Object) -> void:
	assert(system != null, "System should not be null")
