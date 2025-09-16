class_name UnifiedTestFactory
extends RefCounted

## Unified Test Factory - Convenience Facade for Test Creation
##
## ⚠️ DEPRECATED: This factory is being phased out in favor of specific factory classes.
## Use EnvironmentTestFactory, PlaceableTestFactory, PlacementRuleTestFactory, etc. directly.
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

## Delegate: Create building test environment (legacy)
## @deprecated: Use EnvironmentTestFactory.create_building_test_env() directly
static func instance_building_test_env(test: GdUnitTestSuite, resource_path_or_uid: String) -> Node:
	var env: Node = load(resource_path_or_uid).instantiate()
	test.add_child(env)
	test.auto_free(env)
	return env

## Delegate: Create collision test environment (legacy)
## @deprecated: Use EnvironmentTestFactory.create_collision_test_env() directly
static func instance_collision_test_env(test: GdUnitTestSuite, resource_path_or_uid: String) -> CollisionTestEnvironment:
	var env: CollisionTestEnvironment = load(resource_path_or_uid).instantiate()
	test.add_child(env)
	test.auto_free(env)
	return env

## Delegate: Validate environment setup
## @deprecated: Use EnvironmentTestFactory.validate_environment_setup() directly
static func validate_environment_setup(env: AllSystemsTestEnvironment, context: String = "Test environment") -> bool:
	return EnvironmentTestFactory.validate_environment_setup(env, context)

#endregion

#region RULE DELEGATE METHODS

## Delegate: Create collision rule with settings
## @deprecated: Use PlacementRuleTestFactory.create_collision_rule_with_settings() directly
static func create_collision_rule_with_settings(apply_mask: int, collision_mask: int, pass_on_collision: bool = true) -> CollisionsCheckRule:
	return PlacementRuleTestFactory.create_collision_rule_with_settings(apply_mask, collision_mask, pass_on_collision)

## Delegate: Create standard placement rules array
## @deprecated: Use PlacementRuleTestFactory.create_standard_placement_rules() directly
static func create_standard_placement_rules(include_tile_rule: bool = true) -> Array[PlacementRule]:
	return PlacementRuleTestFactory.create_standard_placement_rules(include_tile_rule)

## Delegate: Create default collisions check rule
## @deprecated: Use PlacementRuleTestFactory.create_default_collision_rule() directly
static func create_test_collisions_check_rule() -> CollisionsCheckRule:
	return PlacementRuleTestFactory.create_default_collision_rule()

## Delegate: Prepare targeting state ready
## @deprecated: Use specific factory methods for targeting state setup
static func prepare_targeting_state_ready(test: GdUnitTestSuite, container: GBCompositionContainer) -> Dictionary:
	var setup: Dictionary = {}
	var targeting_state: GridTargetingState = container.get_targeting_state()
	var positioner: GridPositioner2D = UnifiedTestFactory.create_grid_positioner(test)
	setup.targeting_state = targeting_state
	setup.positioner = positioner
	return setup

#endregion

#region BASIC SETUP DELEGATE METHODS

## Delegate: Create test composition container
## @deprecated: Use GBCompositionContainer.new() directly or specific factory methods
static func create_test_composition_container(_test: GdUnitTestSuite) -> GBCompositionContainer:
	var container: GBCompositionContainer = GBCompositionContainer.new()
	return container

## Delegate: Create owner context
## @deprecated: Use GBOwnerContext.new() directly or specific factory methods
static func create_owner_context(_test: GdUnitTestSuite) -> GBOwnerContext:
	var context: GBOwnerContext = GBOwnerContext.new()
	# TODO: Fix owner context setup - requires GBOwner object, not string
	# context.owner_id = "test_owner"
	# context.game_time = 0.0
	return context

## Delegate: Create indicator manager
## @deprecated: Use IndicatorManager.new() directly or specific factory methods
static func create_indicator_manager(test: GdUnitTestSuite) -> IndicatorManager:
	var manager: IndicatorManager = IndicatorManager.new()
	test.add_child(manager)
	test.auto_free(manager)
	return manager

## Delegate: Create test injector with container
## @deprecated: Use GBInjectorSystem.new() directly or specific factory methods
static func create_test_injector(test: GdUnitTestSuite, container: GBCompositionContainer) -> GBInjectorSystem:
	var injector: GBInjectorSystem = GBInjectorSystem.new()
	container.injector = injector
	test.add_child(injector)
	test.auto_free(injector)
	return injector

## Delegate: Create eclipse test object
## @deprecated: Use Node2D.new() directly or specific factory methods
static func create_eclipse_test_object(test: GdUnitTestSuite) -> Node2D:
	var obj: Node2D = Node2D.new()
	test.add_child(obj)
	test.auto_free(obj)
	return obj

#endregion

## Delegate: Create test Node2D
## @deprecated: Use GodotTestFactory.create_node2d() directly
static func create_test_node2d(test: GdUnitTestSuite) -> Node2D:
	return GodotTestFactory.create_node2d(test)


## Delegate: Create test static body with rect shape
## @deprecated: Use GodotTestFactory.create_static_body_with_rect_shape() directly
static func create_test_static_body_with_rect_shape(test: GdUnitTestSuite) -> StaticBody2D:
	return GodotTestFactory.create_static_body_with_rect_shape(test, Vector2(32, 32))  # TODO: Use GBTestConstants.DEFAULT_TILE_SIZE

## Delegate: Create polygon test object
## @deprecated: Use CollisionObjectTestFactory.create_polygon_test_object() directly
static func create_polygon_test_object(test_instance: Node) -> Node2D:
	return CollisionObjectTestFactory.create_polygon_test_object(test_instance)

## Delegate: Create polygon test placeable
## @deprecated: Use PlaceableTestFactory.create_polygon_test_placeable() directly
static func create_polygon_test_placeable(test_instance: Node) -> Placeable:
	return PlaceableTestFactory.create_polygon_test_placeable(test_instance)

## Delegate: Create test placeable with rules
## @deprecated: Use PlaceableTestFactory.create_test_placeable_with_rules() directly
static func create_test_placeable_with_rules(base_placeable: Placeable, display_name: String = "Test Placeable With Rules", include_tile_rule: bool = true) -> Placeable:
	return PlaceableTestFactory.create_test_placeable_with_rules(base_placeable, display_name, include_tile_rule)

## Delegate: Create polygon test setup
## @deprecated: Use PlaceableTestFactory.create_polygon_test_setup() directly
static func create_polygon_test_setup(test_instance: Node) -> Dictionary:
	return PlaceableTestFactory.create_polygon_test_setup(test_instance)

## Delegate: Create test rule check indicator
## @deprecated: Use RuleCheckIndicator.new() directly or specific factory methods
static func create_test_rule_check_indicator(test_instance: Node) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	test_instance.add_child(indicator)
	if test_instance.has_method("auto_free"):
		test_instance.auto_free(indicator)
	return indicator

## Delegate: Create test rule check indicator with shape
## @deprecated: Use RuleCheckIndicator.new() directly or specific factory methods
static func create_test_rule_check_indicator_with_shape(test_instance: Node, shape: Shape2D) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = create_test_rule_check_indicator(test_instance)
	indicator.shape = shape
	return indicator

## Delegate: Ensure indicator template configured
## @deprecated: Indicator template configuration is handled by specific factory methods
static func ensure_indicator_template_configured(_indicator_manager: IndicatorManager) -> void:
	# TODO: Implement indicator template configuration
	# For now, this is a no-op
	pass

## Delegate: Create complete building test setup
## @deprecated: Use EnvironmentTestFactory for complete test environments
static func create_complete_building_test_setup(_test_instance: Node) -> Dictionary:
	# TODO: Implement complete building test setup
	# For now, return a basic setup dictionary
	return {
		"building_system": null,
		"indicator_manager": null,
		"collision_mapper": null
	}

## Delegate: Create manipulation system
## @deprecated: Use specific factory methods for manipulation system creation
static func create_manipulation_system(test_instance: Node) -> Object:
	# TODO: Implement manipulation system creation
	# For now, return a basic object
	var manipulation_system: Object = Object.new()
	test_instance.add_child(manipulation_system)
	if test_instance.has_method("auto_free"):
		test_instance.auto_free(manipulation_system)
	return manipulation_system

#region UTILITY DELEGATE METHODS

## Delegate: Create grid positioner
## @deprecated: Use GridPositioner2D.new() directly
static func create_grid_positioner(_test: GdUnitTestSuite) -> GridPositioner2D:
	var positioner: GridPositioner2D = GridPositioner2D.new()
	return positioner

## Delegate: Create tile map layer parented to p_parent
## @deprecated: Use TileMapLayer.new() directly or specific factory methods
static func create_tile_map_layer(test: GdUnitTestSuite, _p_parent : Node = null) -> TileMapLayer:
	var tile_map: TileMapLayer = TileMapLayer.new()
	test.add_child(tile_map)
	test.auto_free(tile_map)
	return tile_map

#endregion

#region ESSENTIAL LEGACY METHODS

#endregion

## Delegate: Assert placement report success
## @deprecated: Use direct assertion methods instead of factory assertions
static func assert_placement_report_success(_test: GdUnitTestSuite, report: PlacementReport) -> void:
	assert(report.is_success(), "Placement report should be successful")

## Delegate: Create test collision rule
## @deprecated: Use PlacementRuleTestFactory.create_collision_rule_with_settings() directly
static func create_test_collision_rule() -> CollisionsCheckRule:
	return create_collision_rule_with_settings(1, 1, true)

## Delegate: Create test tile rule
static func create_test_tile_rule() -> TileCheckRule:
	return TileCheckRule.new()

## Delegate: Assert system dependencies valid
static func assert_system_dependencies_valid(_test: GdUnitTestSuite, system: Object) -> void:
	assert(system != null, "System should not be null")

#endregion
