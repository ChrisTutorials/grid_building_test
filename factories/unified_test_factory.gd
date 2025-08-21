class_name UnifiedTestFactory
extends RefCounted

## Unified test factory for test doubles, helper objects, and complex test setup
## Use this for test-specific utilities, NOT as wrappers around runtime factory methods

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

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
	var system := ManipulationSystem.create_with_injection(_container)
	test.auto_free(system)
	test.add_child(system)
	return system

## Creates a GridTargetingSystem using the static factory method
static func create_grid_targeting_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> GridTargetingSystem:
	var _container = container if container != null else TEST_CONTAINER
	var system := GridTargetingSystem.create_with_injection(_container)
	test.auto_free(system)
	test.add_child(system)
	return system

## Creates a GBInjectorSystem using the static factory method
static func create_injector_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> GBInjectorSystem:
	var _container = container if container != null else TEST_CONTAINER
	var system := GBInjectorSystem.create_with_injection(_container)
	test.auto_free(system)
	test.add_child(system)
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

static func create_indicator_manager(test: GdUnitTestSuite, targeting_state: GridTargetingState = null) -> IndicatorManager:
	var parent := Node2D.new()
	test.auto_free(parent)
	test.add_child(parent)
	var template := load("uid://nhlp6ks003fp")
	var state := targeting_state if targeting_state != null else create_targeting_state(test)
	var logger := create_test_logger()
	return IndicatorManager.new(parent, state, template, logger)

static func create_test_indicator_collision_setup(test: GdUnitTestSuite, collision_object: CollisionObject2D = null) -> IndicatorCollisionTestSetup:
	var obj := collision_object if collision_object != null else create_test_static_body_with_rect_shape(test)
	var shape_stretch := Vector2(16, 16)
	var logger := create_test_logger()
	return IndicatorCollisionTestSetup.new(obj, shape_stretch, logger)

static func create_test_indicator_manager(test: GdUnitTestSuite, targeting_state: GridTargetingState = null) -> IndicatorManager:
	var parent := GodotTestFactory.create_node2d(test)
	var template := load("uid://nhlp6ks003fp")
	var state := targeting_state if targeting_state != null else create_double_targeting_state(test)
	var logger := create_test_logger()
	var manager := IndicatorManager.new(parent, state, template, logger)
	return manager

static func create_test_indicator_rect(test: GdUnitTestSuite, tile_size: int = 16) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	test.auto_free(indicator)
	var rect_shape := RectangleShape2D.new()
	rect_shape.extents = Vector2(tile_size, tile_size)
	indicator.shape = rect_shape
	test.auto_free(rect_shape)
	# IMPORTANT: ensure indicator participates in the test scene tree so auto_free + orphan detection work
	test.add_child(indicator)
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
	var injector := GBInjectorSystem.create_with_injection(_container)
	test.add_child(injector)
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

static func create_placement_manager(test: GdUnitTestSuite, targeting_state: GridTargetingState = null) -> PlacementManager:
	var manager := PlacementManager.new()
	var placement_context := PlacementContext.new()
	var indicator_template := load("uid://nhlp6ks003fp")
	var state := targeting_state if targeting_state != null else create_targeting_state(test)
	var logger := create_test_logger()
	var rules: Array[PlacementRule] = []
	var messages := GBMessages.new()
	manager.initialize(placement_context, indicator_template, state, logger, rules, messages)
	test.auto_free(manager)
	test.auto_free(placement_context)
	test.add_child(manager)
	return manager

static func create_test_placement_manager(test: GdUnitTestSuite) -> PlacementManager:
	var context := PlacementContext.new()
	test.auto_free(context)
	var indicator_template := load("uid://nhlp6ks003fp")
	var targeting_state := create_double_targeting_state(test)
	var logger := create_test_logger()
	var rules: Array[PlacementRule] = []
	var messages: GBMessages = GBMessages.new()
	var manager : PlacementManager = PlacementManager.new()
	test.auto_free(manager)
	manager.initialize(context, indicator_template, targeting_state, logger, rules, messages)
	test.add_child(manager)
	return manager

static func create_placement_validator(_test: GdUnitTestSuite, rules: Array[PlacementRule] = []) -> PlacementValidator:
	var messages := GBMessages.new()
	var logger := create_test_logger()
	return PlacementValidator.new(rules, messages, logger)
#endregion
#region Rules
static func create_rule_check_indicator(test: GdUnitTestSuite, parent: Node = null, rules: Array[TileCheckRule] = []) -> RuleCheckIndicator:
	# Creates a RuleCheckIndicator and parents it.
	# Parenting rules:
	# 1. If a parent Node is provided, the indicator is added to it.
	# 2. If no parent is provided, it is added to the test suite (maintains previous auto-parent behavior).
	var logger := create_test_logger()
	var indicator := RuleCheckIndicator.new(rules, logger)
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
	var logger := create_test_logger()
	var indicator := RuleCheckIndicator.new(rules, logger)
	test.auto_free(indicator)
	if parent != null:
		parent.add_child(indicator)
	else:
		test.add_child(indicator)
	return indicator

static func create_test_valid_placement_tile_rule(tile_data: Dictionary = {}) -> ValidPlacementTileRule:
	return ValidPlacementTileRule.new(tile_data)

static func create_test_within_tilemap_bounds_rule() -> WithinTilemapBoundsRule:
	var rule := WithinTilemapBoundsRule.new()
	var logger := create_test_logger()
	rule.initialize(logger)
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
	
	# Create placement manager
	scene.placement_manager = create_test_placement_manager(test)
	scene.placement_context = test.auto_free(PlacementContext.new())
	
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
	var system = test.auto_free(ManipulationSystem.create_with_injection(container))
	test.add_child(system)
	scene.system = system
	
	# Create placement manager
	scene.placement_manager = create_test_placement_manager(test)
	scene.placement_context = test.auto_free(PlacementContext.new())
	
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
	var system = test.auto_free(GridTargetingSystem.create_with_injection(container))
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
	return test.auto_free(instance)

## Create a test manipulation data object
static func create_test_manipulation_data(
	test: GdUnitTestSuite,
	action: GBEnums.Action = GBEnums.Action.BUILD,
	root_manipulatable: Manipulatable = null,
	target_manipulatable: Manipulatable = null
) -> ManipulationData:
	var root = root_manipulatable if root_manipulatable else create_test_manipulatable(test)
	var target = target_manipulatable if target_manipulatable else create_test_manipulatable(test)
	
	var data = ManipulationData.new(
		test.auto_free(Node.new()),
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
	var issues = system.validate_dependencies()
	test.assert_array(issues).is_empty()

## Validate that a system has expected dependency issues
static func assert_system_dependencies_have_issues(test: GdUnitTestSuite, system: Node, expected_issue_count: int = 1) -> void:
	var issues = system.validate_dependencies()
	test.assert_int(issues.size()).is_greater_equal(expected_issue_count)

#endregion
#region TileMaps

static func create_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	return GodotTestFactory.create_tile_map_layer(test)

static func create_test_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	# Backwards compatible wrapper
	return GodotTestFactory.create_tile_map_layer(test)

#endregion
