class_name UnifiedTestFactory
extends RefCounted

## Unified test factory for test doubles, helper objects, and complex test setup
## Use this for test-specific utilities, NOT as wrappers around runtime factory methods

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# ================================
# LAYERED FACTORY METHODS - Advanced DRY Approach
# ================================

## Creates comprehensive utilities test environment with shared components
static func create_utilities_test_environment(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container = container if container != null else TEST_CONTAINER
	var injector = create_test_injector(test, _container)
	var tile_map = create_test_tile_map_layer(test)
	
	return {
		"injector": injector,
		"logger": _container.get_logger(),
		"tile_map": tile_map,
		"container": _container
	}

## Creates placement system test environment with manager components
static func create_placement_system_test_environment(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var base_env = create_utilities_test_environment(test, container)
	var placement_manager = create_test_indicator_manager(test, base_env.container)
	var collision_setup = create_test_indicator_collision_setup(test)
	var collision_mapper_setup = create_collision_mapper_setup(test, container)
	
	base_env.merge({
		"placement_manager": placement_manager,
		"collision_setup": collision_setup
	})
	base_env.merge(collision_mapper_setup)
	
	return base_env

## Creates rule check indicator test environment extending placement system
static func create_rule_indicator_test_environment(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var placement_env = create_placement_system_test_environment(test, container)
	var rule_indicators = []
	var basic_rules = [
		create_test_within_tilemap_bounds_rule(test),
		create_test_collisions_check_rule()
	]
	
	for rule in basic_rules:
		var indicator = create_test_rule_check_indicator(test)
		indicator.add_rule(rule)
		rule_indicators.append(indicator)
	
	placement_env.merge({
		"rule_indicators": rule_indicators,
		"basic_rules": basic_rules
	})
	
	return placement_env

## Creates systems integration test environment with all major systems
static func create_systems_integration_test_environment(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var rule_env = create_rule_indicator_test_environment(test, container)
	var building_system = create_building_system(test, rule_env.container)
	var manipulation_system = create_manipulation_system(test, rule_env.container)
	var targeting_system = create_grid_targeting_system(test, rule_env.container)
	
	rule_env.merge({
		"building_system": building_system,
		"manipulation_system": manipulation_system,
		"targeting_system": targeting_system
	})
	
	return rule_env

# ================================
# Building Systems
# ================================

## Creates a BuildingSystem using the static factory method
static func create_building_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> BuildingSystem:
	var _container = container if container != null else TEST_CONTAINER
	var system := BuildingSystem.create_with_injection(_container)
	test.auto_free(system)
	test.add_child(system)
	return system

## Creates a ManipulationSystem using the static factory method
static func create_manipulation_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> ManipulationSystem:
	var _container = container if container != null else TEST_CONTAINER
	var system := ManipulationSystem.create_with_injection(test, _container)
	test.auto_free(system)
	test.add_child(system)
	return system

## Creates a GridTargetingSystem using the static factory method
static func create_grid_targeting_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> GridTargetingSystem:
	var _container = container if container != null else TEST_CONTAINER
	var system := GridTargetingSystem.create_with_injection(test, _container)
	test.auto_free(system)
	test.add_child(system)
	return system

## Creates a GBInjectorSystem using the static factory method
static func create_injector_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> GBInjectorSystem:
	var _container = container if container != null else TEST_CONTAINER
	var system := GBInjectorSystem.create_with_injection(test, _container)
	test.auto_free(system)
	return system

static func create_test_building_system(test: GdUnitTestSuite) -> BuildingSystem:
	var system := BuildingSystem.new()
	test.auto_free(system)
	test.add_child(system)
	return system

# ================================
# Collision Objects (delegated to GodotTestFactory)
# ================================

static func create_collision_object_test_setups(col_objects: Array) -> Dictionary[CollisionObject2D, IndicatorCollisionTestSetup]:
	var setups: Dictionary[CollisionObject2D, IndicatorCollisionTestSetup] = {}
	for obj in col_objects:
		if obj is CollisionObject2D:
			setups[obj] = IndicatorCollisionTestSetup.new(obj, Vector2.ZERO, create_test_logger())
	return setups

static func create_collision_test_setup(test: GdUnitTestSuite, collision_object: CollisionObject2D = null) -> IndicatorCollisionTestSetup:
	return create_test_indicator_collision_setup(test, collision_object)

# DEPRECATED basic helpers (use GodotTestFactory.* instead) ------------------
static func create_test_collision_polygon(test: GdUnitTestSuite) -> CollisionPolygon2D:
	return GodotTestFactory.create_collision_polygon(test)

static func create_test_object_with_circle_shape(test: GdUnitTestSuite) -> Node2D:
	return GodotTestFactory.create_object_with_circle_shape(test)

static func create_test_static_body_with_rect_shape(test: GdUnitTestSuite) -> StaticBody2D:
	return GodotTestFactory.create_static_body_with_rect_shape(test)

static func create_test_parent_with_body_and_polygon(test: GdUnitTestSuite) -> Node2D:
	return GodotTestFactory.create_parent_with_body_and_polygon(test)

# ================================
# Indicators
# ================================

static func create_test_indicator_collision_setup(test: GdUnitTestSuite, collision_object: CollisionObject2D = null) -> IndicatorCollisionTestSetup:
	var obj := collision_object if collision_object != null else create_test_static_body_with_rect_shape(test)
	var shape_stretch := Vector2(16, 16)
	var logger := create_test_logger()
	return IndicatorCollisionTestSetup.new(obj, shape_stretch, logger)

static func create_test_indicator_manager(test: GdUnitTestSuite, param = null) -> IndicatorManager:
	var _container: GBCompositionContainer
	
	# Handle different parameter types for backward compatibility
	if param == null:
		_container = TEST_CONTAINER.duplicate(true)
	elif param is GBCompositionContainer:
		_container = param
	elif param is GridTargetingState:
		# Legacy compatibility: create container with targeting state
		_container = TEST_CONTAINER.duplicate(true)
		_container.get_states().targeting = param
	else:
		push_error("Invalid parameter type for create_test_indicator_manager. Expected GBCompositionContainer or GridTargetingState")
		_container = TEST_CONTAINER.duplicate(true)
	
	# Ensure manipulation parent is set for indicator service
	if _container.get_states().manipulation.parent == null:
		var manipulation_parent = Node2D.new()
		manipulation_parent.name = "TestManipulationParent"
		test.auto_free(manipulation_parent)
		test.add_child(manipulation_parent)
		_container.get_states().manipulation.parent = manipulation_parent
	
	# Create indicator manager using injection pattern
	var manager = IndicatorManager.create_with_injection(_container)
	test.auto_free(manager)
	test.add_child(manager)
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
	var owner_shapes : Dictionary[Node2D, Array] = GBGeometryUtils.get_all_collision_shapes_by_owner(test_object)
	# Ensure a testing indicator exists
	var testing_indicator := manager.get_or_create_testing_indicator(p)
	# Build setups
	var setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for owner in owner_shapes.keys():
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
	var collision_mapper = manager.get_collision_mapper()
	if collision_mapper != null:
		collision_mapper.setup(testing_indicator, setups)

static func create_test_indicator_rect(test: GdUnitTestSuite, tile_size: int = 16) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new([])
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
	var container := GBCompositionContainer.new()
	var debug_settings := create_test_debug_settings()
	var config := GBConfig.new()
	container.config = config
	config.settings.debug = debug_settings
	var logger := container.get_logger()
	
	test.auto_free(container)
	test.auto_free(debug_settings)
	test.auto_free(logger)
	test.auto_free(config)
	
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
	var _container = container if container != null else create_test_composition_container(test)
	var injector := GBInjectorSystem.create_with_injection(test, _container)
	test.auto_free(injector)
	return injector

static func create_test_logger() -> GBLogger:
	var debug_settings := create_test_debug_settings()
	return GBLogger.new(debug_settings)
#endregion
#region Manipulation
static func create_test_manipulation_system(test: GdUnitTestSuite) -> ManipulationSystem:
	var system := ManipulationSystem.new()
	test.auto_free(system)
	test.add_child(system)
	return system

static func create_test_manipulatable(test: GdUnitTestSuite) -> Manipulatable:
	# Delegate to GodotTestFactory for base node creation then apply naming
	var manipulatable := GodotTestFactory.create_manipulatable(test, "FactoryManipulatableRoot")
	manipulatable.name = "FactoryManipulatable"
	return manipulatable
#endregion
#region Node Utilities
static func create_test_node2d(test: GdUnitTestSuite) -> Node2D:
	return GodotTestFactory.create_node2d(test)

static func create_test_node_locator(search_method: NodeLocator.SEARCH_METHOD = NodeLocator.SEARCH_METHOD.NODE_NAME, search_string: String = "test") -> NodeLocator:
	return NodeLocator.new(search_method, search_string)
#endregion
#region Owner Context
static func create_owner_context(test: GdUnitTestSuite) -> GBOwnerContext:
	var context := GBOwnerContext.new()
	var user := Node2D.new()
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
	var container = TEST_CONTAINER
	
	# Create indicator manager using injection pattern
	var manager = IndicatorManager.create_with_injection(container)
	test.auto_free(manager)
	test.add_child(manager)
	return manager

static func create_placement_validator(_test: GdUnitTestSuite, rules: Array[PlacementRule] = []) -> PlacementValidator:
	var messages := GBMessages.new()
	var logger := create_test_logger()
	return PlacementValidator.new(rules, messages, logger)
#endregion
#region Rules
static func create_rule_check_indicator(test: GdUnitTestSuite, parent: Node = null, rules: Array[TileCheckRule] = []) -> RuleCheckIndicator:
	# Creates a RuleCheckIndicator and parents it for testing purposes.
	# 
	# ARCHITECTURE NOTE: In production code, indicators should be created via IndicatorManager.setup_indicators()
	# which automatically parents them to the IndicatorManager. This factory method is for unit testing only.
	#
	# Parenting rules:
	# 1. If a parent Node is provided, the indicator is added to it.
	# 2. If no parent is provided, it is added to the test suite (maintains previous auto-parent behavior).
	# 
	# See docs/systems/parent_node_architecture.md for production architecture guidelines.
	var indicator := RuleCheckIndicator.new(rules)
	test.auto_free(indicator)
	if parent != null:
		parent.add_child(indicator)
	else:
		test.add_child(indicator)
	return indicator

static func create_rule_validation_params(test: GdUnitTestSuite, target: Node2D = null, targeting_state: GridTargetingState = null) -> RuleValidationParameters:
	var placer := Node2D.new()
	test.auto_free(placer)
	test.add_child(placer)
	var test_target := target if target != null else Node2D.new()
	if target == null:
		test.auto_free(test_target)
		test.add_child(test_target)
	var state := targeting_state if targeting_state != null else create_targeting_state(test)
	var logger := create_test_logger()
	return RuleValidationParameters.new(placer, test_target, state, logger)

static func create_rule_with_logger(rule_class: GDScript) -> PlacementRule:
	var rule: PlacementRule = rule_class.new()
	var logger := create_test_logger()
	rule.initialize(logger)
	return rule

static func create_test_collisions_check_rule() -> CollisionsCheckRule:
	return CollisionsCheckRule.new()

static func create_test_rule_check_indicator(test: GdUnitTestSuite, parent: Node = null, rules: Array[TileCheckRule] = []) -> RuleCheckIndicator:
	# Alias helper mirroring create_rule_check_indicator with same parenting logic.
	var indicator := RuleCheckIndicator.new(rules)
	
	# Set up a valid shape for the ShapeCast2D component
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	indicator.shape = shape
	
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

static func create_test_within_tilemap_bounds_rule(test: GdUnitTestSuite = null) -> WithinTilemapBoundsRule:
	# Create the rule. If a test instance is provided, run a proper setup
	# so the rule has valid RuleValidationParameters (including logger).
	var rule := WithinTilemapBoundsRule.new()
	if test != null:
		var params := create_rule_validation_params(test)
		# PlacementRule.setup returns an Array of issues; ignore return but
		# allow assert in setup to surface any problems during tests.
		rule.setup(params)
	return rule
#endregion
#region Targeting State
static func create_double_targeting_state(test : GdUnitTestSuite) -> GridTargetingState:
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())
	test.auto_free(targeting_state)
	var positioner := GodotTestFactory.create_node2d(test)
	# positioner already parented
	targeting_state.positioner = positioner
	var target_map := GodotTestFactory.create_tile_map_layer(test)
	targeting_state.target_map = target_map
	var layer1 := GodotTestFactory.create_empty_tile_map_layer(test)
	var layer2 := GodotTestFactory.create_empty_tile_map_layer(test)
	targeting_state.maps = [layer1, layer2]
	return targeting_state

static func create_targeting_state(test: GdUnitTestSuite, owner_context: GBOwnerContext = null) -> GridTargetingState:
	var context := owner_context if owner_context != null else create_owner_context(test)
	var targeting_state := GridTargetingState.new(context)
	var positioner := GodotTestFactory.create_node2d(test)
	targeting_state.positioner = positioner
	var map_layer := GodotTestFactory.create_tile_map_layer(test)
	targeting_state.set_map_objects(map_layer, [map_layer])
	test.auto_free(targeting_state)
	return targeting_state

#endregion
#region Test Utilities

## Setup a complete building system test environment
static func setup_building_system_test(test: GdUnitTestSuite, container: GBCompositionContainer) -> Dictionary:
	var scene = {}
	
	# Create basic nodes
	scene.placer = GodotTestFactory.create_node2d(test)
	scene.placed_parent = GodotTestFactory.create_node2d(test)
	scene.grid_positioner = GodotTestFactory.create_node2d(test)
	scene.map_layer = GodotTestFactory.create_tile_map_layer(test)
	
	# Setup targeting state
	var targeting_state = container.get_states().targeting
	targeting_state.positioner = scene.grid_positioner
	targeting_state.target_map = scene.map_layer
	targeting_state.maps = [scene.map_layer]
	
	# Setup building state
	scene.user_context = create_test_owner_context(test)
	var building_state = container.get_states().building
	building_state.placer_state = scene.user_context
	building_state.placed_parent = scene.placed_parent
	
	# Create and setup building system
	var system = test.auto_free(BuildingSystem.create_with_injection(container))
	test.add_child(system)
	scene.system = system
	
	# Create indicator manager
	scene.indicator_manager = create_test_indicator_manager(test)
	scene.indicator_context = test.auto_free(IndicatorContext.new())
	
	return scene

## Setup a complete manipulation system test environment
static func setup_manipulation_system_test(test: GdUnitTestSuite, container: GBCompositionContainer) -> Dictionary:
	var scene = {}
	
	# Create basic nodes
	scene.placer = GodotTestFactory.create_node2d(test)
	scene.placed_parent = GodotTestFactory.create_node2d(test)
	scene.grid_positioner = GodotTestFactory.create_node2d(test)
	scene.map_layer = GodotTestFactory.create_tile_map_layer(test)
	
	# Setup targeting state
	var targeting_state = container.get_states().targeting
	targeting_state.positioner = scene.grid_positioner
	targeting_state.target_map = scene.map_layer
	targeting_state.maps = [scene.map_layer]
	
	# Setup building state
	scene.user_context = create_test_owner_context(test)
	var building_state = container.get_states().building
	building_state.placer_state = scene.user_context
	building_state.placed_parent = scene.placed_parent
	
	# Create and setup manipulation system
	var manipulation_system := ManipulationSystem.create_with_injection(test, container)
	test.auto_free(manipulation_system)
	test.add_child(manipulation_system)
	scene.system = manipulation_system
	
	# Create indicator manager
	scene.indicator_manager = create_test_indicator_manager(test)
	scene.indicator_context = test.auto_free(IndicatorContext.new())
	
	return scene

## Setup a complete grid targeting system test environment
static func setup_grid_targeting_system_test(test: GdUnitTestSuite, container: GBCompositionContainer) -> Dictionary:
	var scene = {}
	
	# Create basic nodes
	scene.placer = GodotTestFactory.create_node2d(test)
	scene.placed_parent = GodotTestFactory.create_node2d(test)
	scene.grid_positioner = GodotTestFactory.create_node2d(test)
	scene.map_layer = GodotTestFactory.create_tile_map_layer(test)
	
	# Setup targeting state
	var targeting_state = container.get_states().targeting
	targeting_state.positioner = scene.grid_positioner
	targeting_state.target_map = scene.map_layer
	targeting_state.maps = [scene.map_layer]
	
	# Create and setup grid targeting system
	var system = GridTargetingSystem.create_with_injection(test, container)
	test.auto_free(system)
	test.add_child(system)
	scene.system = system
	
	return scene

## Create a test placeable instance with common setup
static func create_test_placeable_instance(test: GdUnitTestSuite, instance_name: String = "TestInstance", placeable_path: String = "") -> Node:
	var save = {
		PlaceableInstance.Names.INSTANCE_NAME: instance_name,
		PlaceableInstance.Names.PLACEABLE: {Placeable.Names.UID: placeable_path},
		PlaceableInstance.Names.TRANSFORM: var_to_str(Transform2D.IDENTITY)
	}
	
	var instance = PlaceableInstance.instance_from_save(save, test)
	# If the instance is a Node, parent it under the test so it's in the scene tree
	test.auto_free(instance)
	if instance is Node:
		test.add_child(instance)
	return instance

## Create a test manipulation data object
static func create_test_manipulation_data(
	test: GdUnitTestSuite,
	action: GBEnums.Action = GBEnums.Action.BUILD,
	root_manipulatable: Manipulatable = null,
	target_manipulatable: Manipulatable = null
) -> ManipulationData:
	var root = root_manipulatable if root_manipulatable else create_test_manipulatable(test)
	var target = target_manipulatable if target_manipulatable else create_test_manipulatable(test)

	# Provide a container node for manipulation data and ensure it is parented to the test
	var container_node := Node.new()
	test.auto_free(container_node)
	test.add_child(container_node)

	var data = ManipulationData.new(
		container_node,
		root,
		target,
		action
	)

	return test.auto_free(data)

## Create a test rule check indicator with common setup
static func create_test_rule_check_indicator_with_shape(
	test: GdUnitTestSuite,
	rules: Array[TileCheckRule] = [],
	tile_size: int = 16
) -> RuleCheckIndicator:
	var indicator = create_test_rule_check_indicator(test, test, rules)
	var rect_shape = GodotTestFactory.create_rectangle_shape(Vector2(tile_size, tile_size))
	indicator.shape = rect_shape
	return indicator

## Validate that a system has no dependency issues
static func assert_system_dependencies_valid(test: GdUnitTestSuite, system: Node) -> void:
	var issues = system.get_dependency_issues()
	test.assert_array(issues).is_empty()

## Validate that a system has expected dependency issues
static func assert_system_dependencies_have_issues(test: GdUnitTestSuite, system: Node, expected_issue_count: int = 1) -> void:
	var issues = system.get_dependency_issues()
	test.assert_int(issues.size()).is_greater_equal(expected_issue_count)

#endregion
#region TileMaps

static func create_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	return GodotTestFactory.create_tile_map_layer(test)

static func create_test_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	# Backwards compatible wrapper
	return GodotTestFactory.create_tile_map_layer(test)

#endregion

#region Demo Resource Factories (Self-Contained)

## Creates a test polygon object similar to res://demos/top_down/objects/polygon_test_object.tscn
## This is a self-contained version that doesn't depend on external demo files
static func create_polygon_test_object(test: GdUnitTestSuite) -> Node2D:
	var obj := Node2D.new()
	obj.name = "PolygonTestObject"
	
	# Create a direct CollisionPolygon2D child for tests that expect it
	var collision_polygon := CollisionPolygon2D.new()
	collision_polygon.name = "CollisionPolygon2D"
	
	# Define a concave polygon that matches the demo's behavior
	var points: PackedVector2Array = [
		Vector2(-32, -32),  # Top-left
		Vector2(32, -32),   # Top-right
		Vector2(32, 0),     # Right-middle
		Vector2(0, 0),      # Center (creates concave shape)
		Vector2(0, 32),     # Bottom-center
		Vector2(-32, 32),   # Bottom-left
		Vector2(-32, -32)   # Close the polygon
	]
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
	
	# Set owner properties AFTER all nodes are added to the tree
	collision_polygon.owner = obj
	static_body.owner = obj
	body_collision_polygon.owner = obj
	
	test.auto_free(obj)
	return obj

## Creates a test smithy object similar to res://demos/top_down/objects/smithy.tscn
## This is a self-contained version that doesn't depend on external demo files
static func create_smithy_test_object(test: GdUnitTestSuite) -> Node2D:
	var smithy := Node2D.new()
	smithy.name = "SmithyTestObject"
	
	# Add a direct CollisionShape2D to the root for tests that expect it
	var direct_collision := CollisionShape2D.new()
	direct_collision.name = "CollisionShape2D"
	var direct_shape := RectangleShape2D.new()
	direct_shape.size = Vector2(112, 80)  # Rectangle 112x80 as mentioned in test
	direct_collision.shape = direct_shape
	smithy.add_child(direct_collision)
	
	# Create Area2D component (layer 2560)
	var area := Area2D.new()
	area.name = "Area2D"
	area.collision_layer = 2560
	area.collision_mask = 2560
	
	var area_collision := CollisionShape2D.new()
	area_collision.name = "AreaCollisionShape2D"
	var area_shape := RectangleShape2D.new()
	area_shape.size = Vector2(112, 80)  # Rectangle 112x80 as mentioned in test
	area_collision.shape = area_shape
	area.add_child(area_collision)
	
	# Create StaticBody2D component (layer 513)
	var static_body := StaticBody2D.new()
	static_body.name = "StaticBody2D"
	static_body.collision_layer = 513
	static_body.collision_mask = 513
	
	var static_collision := CollisionShape2D.new()
	static_collision.name = "StaticCollisionShape2D"
	var static_shape := RectangleShape2D.new()
	static_shape.size = Vector2(112, 80)
	static_collision.shape = static_shape
	static_body.add_child(static_collision)
	
	smithy.add_child(area)
	smithy.add_child(static_body)
	
	# Add Manipulatable component for manipulation system integration
	var manipulatable := Manipulatable.new()
	manipulatable.root = smithy
	var settings := ManipulatableSettings.new()
	settings.movable = true
	settings.demolishable = true
	manipulatable.settings = settings
	smithy.add_child(manipulatable)
	
	# Set owner properties AFTER all nodes are added to the tree
	area.owner = smithy
	area_collision.owner = smithy
	static_body.owner = smithy
	static_collision.owner = smithy
	manipulatable.owner = smithy
	
	test.auto_free(smithy)
	return smithy

## Creates a test placeable configuration similar to demo placeables
## This is a self-contained version that doesn't depend on external demo files
static func create_polygon_test_placeable(test: GdUnitTestSuite) -> Placeable:
	var placeable := Placeable.new()
	placeable.resource_name = "TestPolygonPlaceable"
	
	# Create a basic packed scene reference (we'll create the scene dynamically)
	var scene := PackedScene.new()
	var polygon_obj := create_polygon_test_object(test)
	scene.pack(polygon_obj)
	placeable.packed_scene = scene
	
	test.auto_free(placeable)
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
	shape.size = Vector2(15.9, 15.9)
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
	var segments = 16
	var radius_x = 48.0
	var radius_y = 32.0
	for i in range(segments + 1):
		var angle = (i * 2.0 * PI) / segments
		var x = radius_x * cos(angle)
		var y = radius_y * sin(angle)
		points.append(Vector2(x, y))
	
	collision_polygon.polygon = points
	static_body.add_child(collision_polygon)
	eclipse.add_child(static_body)
	
	# Add Manipulatable component for manipulation system integration
	var manipulatable := Manipulatable.new()
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
static func create_test_placeable_2d(test: GdUnitTestSuite) -> Placeable:
	var placeable := Placeable.new()
	placeable.display_name = "TestPlaceable2D"
	
	# Create a simple PackedScene for the placeable
	var packed_scene := PackedScene.new()
	var test_obj := Node2D.new()
	test_obj.name = "TestObject"
	
	# Add a collision shape
	var static_body := StaticBody2D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	collision_shape.shape = rect_shape
	static_body.add_child(collision_shape)
	test_obj.add_child(static_body)
	
	# Add Manipulatable component for manipulation system integration
	var manipulatable := Manipulatable.new()
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
	
	test.auto_free(placeable)
	return placeable

## Creates a test smithy placeable
static func create_test_smithy_placeable(test: GdUnitTestSuite) -> Placeable:
	var placeable := Placeable.new()
	placeable.display_name = "TestSmithyPlaceable"
	
	# Create a PackedScene containing the smithy object
	var packed_scene := PackedScene.new()
	var smithy_obj := create_smithy_test_object(test)
	
	packed_scene.pack(smithy_obj)
	placeable.packed_scene = packed_scene
	
	# Add basic placement rules
	var collision_rule := CollisionsCheckRule.new()
	collision_rule.apply_to_objects_mask = 1
	collision_rule.collision_mask = 1
	placeable.placement_rules = [collision_rule]
	
	test.auto_free(placeable)
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
	
	test.auto_free(placeable)
	return placeable

## Creates a test eclipse PackedScene for direct scene testing
static func create_test_eclipse_packed_scene(test: GdUnitTestSuite) -> PackedScene:
	var packed_scene := PackedScene.new()
	var eclipse_obj := create_eclipse_test_object(test)
	packed_scene.pack(eclipse_obj)
	test.auto_free(packed_scene)
	return packed_scene

#endregion

#region Complete Building Test Setup

## Complete building test setup with all necessary components for indicator/placement testing
## Returns a dictionary with all configured components
static func create_complete_building_test_setup(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container = container if container != null else TEST_CONTAINER
	var injector = create_test_injector(test, _container)
	
	# Create core scene nodes
	var obj_parent = GodotTestFactory.create_node2d(test)
	var placer = GodotTestFactory.create_node2d(test)
	var positioner = GodotTestFactory.create_node2d(test)
	
	# Set up tilemap with proper tileset
	var map_layer = TileMapLayer.new()
	test.auto_free(map_layer)
	
	var tileset = load("res://demos/top_down/art/0x72_demo_tileset.tres")
	if tileset:
		map_layer.tile_set = tileset
	else:
		# Fallback tileset if demo tileset not available
		var fallback_tileset = TileSet.new()
		fallback_tileset.tile_size = Vector2i(16, 16)
		map_layer.tile_set = fallback_tileset
	
	# Set up targeting system - configure state BEFORE creating system
	var targeting_state = _container.get_states().targeting
	targeting_state.positioner = positioner
	targeting_state.target_map = map_layer
	targeting_state.set_map_objects(map_layer, [map_layer])
	
	var targeting_system = create_grid_targeting_system(test, _container)
	
	# Set up building system
	var building_system = create_building_system(test, _container)
	var building_state = _container.get_states().building
	var owner_context = _container.get_contexts().owner
	var gb_owner = GBOwner.new(placer)
	placer.add_child(gb_owner)
	gb_owner.owner_root = placer
	owner_context.set_owner(gb_owner)
	building_state.placed_parent = obj_parent
	
	# Set up manipulation parent under positioner
	_container.get_states().manipulation.parent = positioner
	
	# Create and setup IndicatorManager under positioner
	var indicator_manager = IndicatorManager.create_with_injection(_container)
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
	var _container = container if container != null else TEST_CONTAINER.duplicate(true)
	
	# Start with the indicator hierarchy as base
	var scene_dict = create_indicator_test_hierarchy(test, _container)
	
	# Add the additional systems needed for full integration
	scene_dict.building_system = create_building_system(test, _container)
	scene_dict.manipulation_system = create_manipulation_system(test, _container)
	scene_dict.targeting_system = create_grid_targeting_system(test, _container)
	
	# Add additional managers for full integration testing
	scene_dict.object_manager = Node2D.new()
	scene_dict.object_manager.name = "TestObjectManager"
	test.auto_free(scene_dict.object_manager)
	test.add_child(scene_dict.object_manager)
	
	# Create placement manager if available
	if ClassDB.class_exists("PlacementManager"):
		scene_dict.placement_manager = ClassDB.instantiate("PlacementManager")
		test.auto_free(scene_dict.placement_manager)
		test.add_child(scene_dict.placement_manager)
	
	# Create grid - basic Node2D for testing
	scene_dict.grid = Node2D.new()
	scene_dict.grid.name = "TestGrid"
	test.auto_free(scene_dict.grid)
	test.add_child(scene_dict.grid)
	
	# Note: container and logger are already included from indicator hierarchy
	
	return scene_dict

## Creates a systems test hierarchy for testing individual systems
## Builds upon indicator hierarchy but adds only specific systems as needed
static func create_systems_test_hierarchy(test: GdUnitTestSuite, systems_needed: Array[String] = [], container: GBCompositionContainer = null) -> Dictionary:
	var _container = container if container != null else TEST_CONTAINER.duplicate(true)
	
	# Start with the indicator hierarchy as base
	var systems_dict = create_indicator_test_hierarchy(test, _container)
	
	# Add only the requested systems
	for system_name in systems_needed:
		match system_name:
			"building":
				systems_dict.building_system = create_building_system(test, _container)
			"manipulation":
				systems_dict.manipulation_system = create_manipulation_system(test, _container)
			"targeting":
				systems_dict.targeting_system = create_grid_targeting_system(test, _container)
			"object_manager":
				systems_dict.object_manager = Node2D.new()
				systems_dict.object_manager.name = "TestObjectManager"
				test.auto_free(systems_dict.object_manager)
				test.add_child(systems_dict.object_manager)
			"placement":
				if ClassDB.class_exists("PlacementManager"):
					systems_dict.placement_manager = ClassDB.instantiate("PlacementManager")
					test.auto_free(systems_dict.placement_manager)
					test.add_child(systems_dict.placement_manager)
			"grid":
				systems_dict.grid = Node2D.new()
				systems_dict.grid.name = "TestGrid"
				test.auto_free(systems_dict.grid)
				test.add_child(systems_dict.grid)
	
	return systems_dict

## Creates a simplified hierarchy for indicator/collision tests
## positioner -> manipulation_parent -> indicator_manager with collision mapping
static func create_indicator_test_hierarchy(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container = container if container != null else TEST_CONTAINER.duplicate(true)
	var hierarchy = {}
	
	# Create injector system first
	hierarchy.injector = create_test_injector(test, _container)
	
	# Create hierarchy
	hierarchy.positioner = GodotTestFactory.create_node2d(test)
	hierarchy.positioner.name = "TestPositioner"
	
	hierarchy.manipulation_parent = Node2D.new()
	hierarchy.manipulation_parent.name = "TestManipulationParent"
	test.auto_free(hierarchy.manipulation_parent)
	hierarchy.positioner.add_child(hierarchy.manipulation_parent)
	
	# Create and configure tile map
	hierarchy.tile_map = GodotTestFactory.create_tile_map_layer(test, 32)
	hierarchy.tile_map.tile_set.tile_size = Vector2i(16, 16)
	
	# Configure states
	var targeting_state = _container.get_states().targeting
	targeting_state.positioner = hierarchy.positioner
	var map_objects: Array[TileMapLayer] = [hierarchy.tile_map]
	targeting_state.set_map_objects(hierarchy.tile_map, map_objects)
	
	var manipulation_state = _container.get_states().manipulation
	manipulation_state.parent = hierarchy.manipulation_parent
	
	# Create indicator manager with collision mapping
	hierarchy.indicator_manager = IndicatorManager.create_with_injection(_container, hierarchy.manipulation_parent)
	test.auto_free(hierarchy.indicator_manager)
	
	# Create collision mapper
	hierarchy.collision_mapper = CollisionMapper.new(targeting_state, _container.get_logger())
	test.auto_free(hierarchy.collision_mapper)
	
	hierarchy.container = _container
	hierarchy.logger = _container.get_logger()
	hierarchy.targeting_state = targeting_state
	hierarchy.manipulation_state = manipulation_state
	
	return hierarchy

## Creates rule validation parameters for rule tests
static func create_rule_validation_parameters(_test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container = container if container != null else TEST_CONTAINER.duplicate(true)
	
	return {
		"container": _container,
		"logger": _container.get_logger(),
		"tile_size": Vector2(16, 16),
		"collision_layer": 1,
		"rule_check_indicators": [],
		"validation_context": {
			"max_distance": 100.0,
			"min_distance": 0.0,
			"allowed_layers": [1, 2, 3]
		}
	}

## Creates collision mapper setup for collision tests
static func create_collision_mapper_setup(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container = container if container != null else TEST_CONTAINER.duplicate(true)
	var tile_map = create_test_tile_map_layer(test)
	var targeting_state = create_targeting_state(test)
	
	return {
		"container": _container,
		"logger": _container.get_logger(),
		"tile_map": tile_map,
		"targeting_state": targeting_state,
		"collision_mapper": CollisionMapper.new(targeting_state, _container.get_logger()),
		"tile_size": Vector2(16, 16)
	}

## Creates a basic test setup with injector and common objects
static func create_basic_test_setup(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var _container = container if container != null else TEST_CONTAINER.duplicate(true)
	var setup = {}
	
	# Create injector system first
	setup.injector = create_test_injector(test, _container)
	
	# Basic objects most tests need
	setup.container = _container
	setup.logger = _container.get_logger()
	setup.object_manager = Node.new()
	setup.object_manager.name = "TestObjectManager"
	setup.grid = Node2D.new()
	setup.grid.name = "TestGrid"
	
	test.auto_free(setup.object_manager)
	test.auto_free(setup.grid)
	test.add_child(setup.object_manager)
	test.add_child(setup.grid)
	
	return setup

# ================================
# COMMON TEST ASSERTION HELPERS - DRY Test Patterns
# ================================

## Creates standardized polygon test object setup for indicator tests
static func create_polygon_test_setup(test: GdUnitTestSuite, parent: Node, position: Vector2 = Vector2.ZERO) -> Dictionary:
	var polygon_obj = create_polygon_test_object(test)
	parent.add_child(polygon_obj)
	polygon_obj.position = position
	
	return {
		"polygon_obj": polygon_obj,
		"rule": _create_standard_collision_rule(),
		"rules": [_create_standard_collision_rule()]
	}

## Creates standardized collision rule for testing
static func _create_standard_collision_rule() -> CollisionsCheckRule:
	var rule = CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1
	rule.collision_mask = 1
	return rule

## Creates standardized indicator setup for testing
static func create_indicator_test_setup(test: GdUnitTestSuite, container: GBCompositionContainer, polygon_obj: Node2D, rules: Array) -> Dictionary:
	var indicator_manager = create_test_indicator_manager(test, container)
	var report = indicator_manager.setup_indicators(polygon_obj, rules)
	
	return {
		"indicator_manager": indicator_manager,
		"report": report,
		"indicators": report.indicators
	}

## Standardized assertion for indicator count validation
static func assert_indicator_count(report: IndicatorSetupReport, expected_count: int, context: String = "") -> void:
	var message = "Expected %d indicators, got %d" % [expected_count, report.indicators.size()]
	if context: message += " (%s)" % context
	assert(report.indicators.size() == expected_count, message)

## Standardized assertion for origin tile exclusion
static func assert_no_origin_indicator(indicators: Array, map: TileMapLayer, context: String = "") -> void:
	var origin_indicators = []
	for indicator in indicators:
		var tile_pos = map.local_to_map(map.to_local(indicator.global_position))
		if tile_pos == Vector2i.ZERO:
			origin_indicators.append(indicator)
	
	var message = "Found %d indicators at origin (0,0) - should be excluded" % origin_indicators.size()
	if context: message += " (%s)" % context
	assert(origin_indicators.is_empty(), message)

## Standardized assertion for parent architecture validation
static func assert_parent_architecture(indicator_manager: IndicatorManager, manipulation_parent: Node2D, indicators: Array, context: String = "") -> void:
	# IndicatorManager should be child of manipulation parent
	var message = "IndicatorManager should be child of ManipulationParent"
	if context: message += " (%s)" % context
	assert(indicator_manager.get_parent() == manipulation_parent, message)
	
	# All indicators should be children of indicator manager
	for indicator in indicators:
		message = "Indicator should be child of IndicatorManager"
		if context: message += " (%s)" % context
		assert(indicator.get_parent() == indicator_manager, message)

## Creates comprehensive test environment for collision-based indicator tests
static func create_collision_indicator_test_environment(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> Dictionary:
	var base_env = create_utilities_test_environment(test, container)
	var collision_setup = create_test_indicator_collision_setup(test)
	var collision_mapper_setup = create_collision_mapper_setup(test, container)
	
	base_env.merge({
		"collision_setup": collision_setup
	})
	base_env.merge(collision_mapper_setup)
	
	return base_env

## Standardized assertion for collision layer validation
static func assert_collision_layer_setup(indicator: Node2D, expected_layer: int, context: String = "") -> void:
	var collision_layer = 0
	if indicator is Area2D:
		collision_layer = indicator.collision_layer
	elif indicator is StaticBody2D:
		collision_layer = indicator.collision_layer
	
	var message = "Expected collision layer %d, got %d" % [expected_layer, collision_layer]
	if context: message += " (%s)" % context
	assert(collision_layer == expected_layer, message)

## Standardized assertion for rule validation results
static func assert_rule_validation_result(result: Dictionary, expected_valid: bool, context: String = "") -> void:
	var message = "Expected validation result %s, got %s" % [expected_valid, result.get("valid", "missing")]
	if context: message += " (%s)" % context
	assert(result.get("valid", false) == expected_valid, message)

#endregion
