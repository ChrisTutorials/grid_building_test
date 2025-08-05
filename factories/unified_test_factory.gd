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
# Collision Objects
# ================================

static func create_collision_object_test_setups(col_objects: Array) -> Dictionary[CollisionObject2D, IndicatorCollisionTestSetup]:
	var setups: Dictionary[CollisionObject2D, IndicatorCollisionTestSetup] = {}
	for obj in col_objects:
		if obj is CollisionObject2D:
			setups[obj] = IndicatorCollisionTestSetup.new(obj, Vector2.ZERO, create_test_logger())
	return setups

static func create_collision_test_setup(test: GdUnitTestSuite, collision_object: CollisionObject2D = null) -> IndicatorCollisionTestSetup:
	return create_test_indicator_collision_setup(test, collision_object)

static func create_test_collision_polygon(test: GdUnitTestSuite) -> CollisionPolygon2D:
	var poly: CollisionPolygon2D = CollisionPolygon2D.new()
	test.auto_free(poly)
	poly.polygon = PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(8,16)])
	test.add_child(poly)
	return poly

static func create_test_object_with_circle_shape(test: GdUnitTestSuite) -> Node2D:
	var test_object: Node2D = Node2D.new()
	test.auto_free(test_object)
	var body: StaticBody2D = StaticBody2D.new()
	test_object.add_child(body)
	test.auto_free(body)
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	body.add_child(collision_shape)
	test.auto_free(collision_shape)
	body.collision_layer = 1
	return test_object

static func create_test_static_body_with_rect_shape(test: GdUnitTestSuite) -> StaticBody2D:
	var body: StaticBody2D = test.auto_free(StaticBody2D.new())
	var shape: CollisionShape2D = test.auto_free(CollisionShape2D.new())
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.extents = Vector2(8, 8)
	shape.shape = rect
	test.add_child(body)
	body.add_child(shape)
	return body

static func create_test_parent_with_body_and_polygon(test: GdUnitTestSuite) -> Node2D:
	var parent: Node2D = Node2D.new()
	test.auto_free(parent)
	test.add_child(parent)
	var body: StaticBody2D = create_test_static_body_with_rect_shape(test)
	var poly: CollisionPolygon2D = create_test_collision_polygon(test)
	if body.get_parent() != null:
		body.get_parent().remove_child(body)
	if poly.get_parent() != null:
		poly.get_parent().remove_child(poly)
	parent.add_child(body)
	parent.add_child(poly)
	return parent

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
	var parent := create_test_node2d(test)
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
	return indicator

# ================================
# Injection & Logging
# ================================

static func create_test_injector(test: GdUnitTestSuite, container: GBCompositionContainer) -> GBInjectorSystem:
	var injector := GBInjectorSystem.create_with_injection(container)
	test.add_child(injector)
	test.auto_free(injector)
	return injector

static func create_test_logger() -> GBLogger:
	var debug_settings := GBDebugSettings.new()
	debug_settings.level = GBDebugSettings.DebugLevel.VERBOSE
	return GBLogger.new(debug_settings)

# ================================
# Manipulation
# ================================

static func create_test_manipulation_system(test: GdUnitTestSuite) -> ManipulationSystem:
	var system := ManipulationSystem.new()
	test.auto_free(system)
	test.add_child(system)
	return system

static func create_test_manipulatable(test: GdUnitTestSuite) -> Manipulatable:
	var root: Node2D = test.auto_free(Node2D.new())
	test.add_child(root)
	var manipulatable: Manipulatable = test.auto_free(Manipulatable.new())
	manipulatable.root = root
	root.add_child(manipulatable)
	root.name = "FactoryManipulatableRoot"
	manipulatable.name = "FactoryManipulatable"
	return manipulatable

# ================================
# Node Utilities
# ================================

static func create_test_node2d(test: GdUnitTestSuite) -> Node2D:
	var node: Node2D = Node2D.new()
	test.add_child(node)
	test.auto_free(node)
	return node

static func create_test_node_locator(search_method: NodeLocator.SEARCH_METHOD = NodeLocator.SEARCH_METHOD.NODE_NAME, search_string: String = "test") -> NodeLocator:
	return NodeLocator.new(search_method, search_string)

# ================================
# Owner Context
# ================================

static func create_owner_context(test: GdUnitTestSuite) -> GBOwnerContext:
	var context := GBOwnerContext.new()
	var user := Node2D.new()
	test.auto_free(user)
	test.add_child(user)
	context.user = user
	return context

static func create_test_owner_context(test: GdUnitTestSuite) -> GBOwnerContext:
	var context := GBOwnerContext.new()
	var user := create_test_node2d(test)
	context.user = user
	return context

# ================================
# Placement
# ================================

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

# ================================
# Rules
# ================================

static func create_rule_check_indicator(test: GdUnitTestSuite, rules: Array[TileCheckRule] = []) -> RuleCheckIndicator:
	var logger := create_test_logger()
	var indicator := RuleCheckIndicator.new(rules, logger)
	test.auto_free(indicator)
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
	return RuleValidationParameters.new(placer, test_target, state)

static func create_rule_with_logger(rule_class: GDScript) -> PlacementRule:
	var rule: PlacementRule = rule_class.new()
	var logger := create_test_logger()
	rule.initialize(logger)
	return rule

static func create_test_collisions_check_rule() -> CollisionsCheckRule:
	return CollisionsCheckRule.new()

static func create_test_rule_check_indicator(test: GdUnitTestSuite, rules: Array[TileCheckRule] = []) -> RuleCheckIndicator:
	var logger := create_test_logger()
	var indicator := RuleCheckIndicator.new(rules, logger)
	test.auto_free(indicator)
	return indicator

static func create_test_valid_placement_tile_rule(tile_data: Dictionary = {}) -> ValidPlacementTileRule:
	return ValidPlacementTileRule.new(tile_data)

static func create_test_within_tilemap_bounds_rule() -> WithinTilemapBoundsRule:
	var rule := WithinTilemapBoundsRule.new()
	var logger := create_test_logger()
	rule.initialize(logger)
	return rule

# ================================
# Targeting State
# ================================

static func create_double_targeting_state(test : GdUnitTestSuite) -> GridTargetingState:
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())
	test.auto_free(targeting_state)
	var positioner := Node2D.new()
	test.auto_free(positioner)
	targeting_state.positioner = positioner
	var target_map := create_test_tile_map_layer(test)
	targeting_state.target_map = target_map
	var layer1 := TileMapLayer.new()
	var layer2 := TileMapLayer.new()
	test.auto_free(layer1)
	test.auto_free(layer2)
	targeting_state.maps = [layer1, layer2]
	return targeting_state

static func create_targeting_state(test: GdUnitTestSuite, owner_context: GBOwnerContext = null) -> GridTargetingState:
	var context := owner_context if owner_context != null else create_owner_context(test)
	var targeting_state := GridTargetingState.new(context)
	var positioner := Node2D.new()
	test.auto_free(positioner)
	test.add_child(positioner)
	targeting_state.positioner = positioner
	var map_layer := create_tile_map_layer(test)
	targeting_state.set_map_objects(map_layer, [map_layer])
	test.auto_free(targeting_state)
	return targeting_state

# ================================
# Tile Maps
# ================================

static func create_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	return create_test_tile_map_layer(test)

static func create_test_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	var map_layer: TileMapLayer = TileMapLayer.new()
	map_layer.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-100, 100, 1):
		for y in range(-100, 100, 1):
			var cords = Vector2i(x, y)
			map_layer.set_cellv(cords, 0, Vector2i(0,0))
	test.add_child(map_layer)
	test.auto_free(map_layer)
	return map_layer
