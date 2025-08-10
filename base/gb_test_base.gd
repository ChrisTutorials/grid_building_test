class_name GBTestBase
extends GdUnitTestSuite

## Base test class for Grid Building tests that provides common setup methods
## and utilities to reduce duplication and minimize failure points

# ================================
# Common Test Resources
# ================================

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# ================================
# Common Test State
# ================================

var _container: GBCompositionContainer
var _states: GBStates
var _targeting_state: GridTargetingState
var _manipulation_state: ManipulationState
var _building_state: BuildingState
var _mode_state: ModeState

# ================================
# Base Setup Methods
# ================================

## Initialize common test container and states
func setup_common_container() -> void:
	_container = TEST_CONTAINER
	_states = _container.get_states()
	_targeting_state = _states.targeting
	_manipulation_state = _states.manipulation
	_building_state = _states.building
	_mode_state = _states.mode

## Create a basic test scene with common nodes
func create_basic_test_scene() -> Dictionary:
	var scene = {}
	
	# Create basic nodes
	scene.placer = GodotTestFactory.create_node2d(self)
	scene.placed_parent = GodotTestFactory.create_node2d(self)
	scene.grid_positioner = GodotTestFactory.create_node2d(self)
	scene.map_layer = GodotTestFactory.create_tile_map_layer(self)
	
	# Setup targeting state
	_targeting_state.positioner = scene.grid_positioner
	_targeting_state.target_map = scene.map_layer
	_targeting_state.maps = [scene.map_layer]
	
	# Setup building state
	scene.user_context = create_test_owner_context(scene.placer)
	_building_state.placer_state = scene.user_context
	_building_state.placed_parent = scene.placed_parent
	
	return scene

## Create a test owner context with proper setup
func create_test_owner_context(owner_node: Node) -> GBOwnerContext:
	var context := GBOwnerContext.new()
	var gb_owner := GBOwner.new(owner_node)
	context.set_owner(gb_owner)
	return context

## Create a placement manager with common setup
func create_test_placement_manager(grid_positioner: Node2D) -> PlacementManager:
	var placement_manager = auto_free(PlacementManager.new())
	placement_manager.resolve_gb_dependencies(_container)
	grid_positioner.add_child(placement_manager)
	return placement_manager

## Create a placement context with common setup
func create_test_placement_context() -> PlacementContext:
	return auto_free(PlacementContext.new())

## Setup a complete building system test environment
func setup_building_system_test() -> Dictionary:
	setup_common_container()
	var scene = create_basic_test_scene()
	
	# Create and setup building system
	var system = auto_free(BuildingSystem.create_with_injection(_container))
	add_child(system)
	scene.system = system
	
	# Create placement manager
	scene.placement_manager = create_test_placement_manager(scene.grid_positioner)
	scene.placement_context = create_test_placement_context()
	
	return scene

## Setup a complete manipulation system test environment
func setup_manipulation_system_test() -> Dictionary:
	setup_common_container()
	var scene = create_basic_test_scene()
	
	# Create and setup manipulation system
	var system = auto_free(ManipulationSystem.create_with_injection(_container))
	add_child(system)
	scene.system = system
	
	# Setup manipulation state
	_manipulation_state.targeting_state = _targeting_state
	
	return scene

## Setup a complete grid targeting system test environment
func setup_grid_targeting_system_test() -> Dictionary:
	setup_common_container()
	var scene = create_basic_test_scene()
	
	# Create and setup grid targeting system
	var system = auto_free(GridTargetingSystem.create_with_injection(_container))
	add_child(system)
	scene.system = system
	
	return scene

## Create a test placeable instance with common setup
func create_test_placeable_instance(instance_name: String = "TestInstance", placeable_path: String = "") -> Node:
	var save = {
		PlaceableInstance.Names.INSTANCE_NAME: instance_name,
		PlaceableInstance.Names.PLACEABLE: {Placeable.Names.UID: placeable_path},
		PlaceableInstance.Names.TRANSFORM: var_to_str(Transform2D.IDENTITY)
	}
	
	var instance = PlaceableInstance.instance_from_save(save, self)
	return auto_free(instance)

## Create a test manipulation data object
func create_test_manipulation_data(
	action: GBEnums.Action = GBEnums.Action.BUILD,
	root_manipulatable: Manipulatable = null,
	target_manipulatable: Manipulatable = null
) -> ManipulationData:
	var root = root_manipulatable if root_manipulatable else UnifiedTestFactory.create_test_manipulatable(self)
	var target = target_manipulatable if target_manipulatable else UnifiedTestFactory.create_test_manipulatable(self)
	
	var data = ManipulationData.new(
		auto_free(Node.new()),
		root,
		target,
		action
	)
	
	return auto_free(data)

## Create a test rule validation parameters object
func create_test_rule_validation_params(
	target: Node2D = null,
	targeting_state: GridTargetingState = null
) -> RuleValidationParameters:
	return UnifiedTestFactory.create_rule_validation_params(
		self,
		target,
		targeting_state if targeting_state else _targeting_state
	)

## Create a test rule check indicator with common setup
func create_test_rule_check_indicator(
	rules: Array[TileCheckRule] = [],
	tile_size: int = 16
) -> RuleCheckIndicator:
	var indicator = UnifiedTestFactory.create_test_rule_check_indicator(self, rules)
	var rect_shape = GodotTestFactory.create_rectangle_shape(Vector2(tile_size, tile_size))
	indicator.shape = rect_shape
	return indicator

## Create a test collisions check rule with logger
func create_test_collisions_check_rule() -> CollisionsCheckRule:
	var rule = CollisionsCheckRule.new()
	var logger = UnifiedTestFactory.create_test_logger()
	rule.initialize(logger)
	return rule

## Create a test within tilemap bounds rule with logger
func create_test_within_tilemap_bounds_rule() -> WithinTilemapBoundsRule:
	return UnifiedTestFactory.create_test_within_tilemap_bounds_rule()

## Create a test valid placement tile rule
func create_test_valid_placement_tile_rule(tile_data: Dictionary = {}) -> ValidPlacementTileRule:
	return UnifiedTestFactory.create_test_valid_placement_tile_rule(tile_data)

## Create a test placement validator with rules
func create_test_placement_validator(rules: Array[PlacementRule] = []) -> PlacementValidator:
	return UnifiedTestFactory.create_placement_validator(self, rules)

## Create a test indicator manager
func create_test_indicator_manager(
	targeting_state: GridTargetingState = null
) -> IndicatorManager:
	return UnifiedTestFactory.create_test_indicator_manager(
		self,
		targeting_state if targeting_state else _targeting_state
	)

## Create a test injector system
func create_test_injector_system() -> GBInjectorSystem:
	return UnifiedTestFactory.create_test_injector(self, _container)

## Create a test logger with verbose settings
func create_test_logger() -> GBLogger:
	return UnifiedTestFactory.create_test_logger()

## Validate that a system has no dependency issues
func assert_system_dependencies_valid(system: Node) -> void:
	var issues = system.validate_dependencies()
	assert_array(issues).is_empty()

## Validate that a system has expected dependency issues
func assert_system_dependencies_have_issues(system: Node, expected_issue_count: int = 1) -> void:
	var issues = system.validate_dependencies()
	assert_int(issues.size()).is_greater_equal(expected_issue_count)

## Create a test tile map layer with specified size
func create_test_tile_map_layer(grid_size: int = 40) -> TileMapLayer:
	return GodotTestFactory.create_tile_map_layer(self, grid_size)

## Create an empty test tile map layer
func create_empty_test_tile_map_layer() -> TileMapLayer:
	return GodotTestFactory.create_empty_tile_map_layer(self)

## Create a test static body with rectangular collision shape
func create_test_static_body_with_rect_shape(extents: Vector2 = Vector2(8, 8)) -> StaticBody2D:
	return GodotTestFactory.create_static_body_with_rect_shape(self, extents)

## Create a test collision polygon
func create_test_collision_polygon(polygon: PackedVector2Array = PackedVector2Array()) -> CollisionPolygon2D:
	return GodotTestFactory.create_collision_polygon(self, polygon)

## Create a test manipulatable
func create_test_manipulatable(root_name: String = "TestManipulatableRoot") -> Manipulatable:
	return GodotTestFactory.create_manipulatable(self, root_name)

## Create a test node2d
func create_test_node2d() -> Node2D:
	return GodotTestFactory.create_node2d(self)

## Create a test node
func create_test_node() -> Node:
	return GodotTestFactory.create_node(self)

## Create a test canvas item
func create_test_canvas_item() -> CanvasItem:
	return GodotTestFactory.create_canvas_item(self)

## Create a test area2d with circle shape
func create_test_area2d_with_circle_shape(radius: float = 16.0) -> Area2D:
	return GodotTestFactory.create_area2d_with_circle_shape(self, radius)

## Create a test object with circle shape
func create_test_object_with_circle_shape() -> Node2D:
	return GodotTestFactory.create_object_with_circle_shape(self)

## Create a test parent with body and polygon
func create_test_parent_with_body_and_polygon() -> Node2D:
	return GodotTestFactory.create_parent_with_body_and_polygon(self)

## Create a test rectangle shape
func create_test_rectangle_shape(size: Vector2 = Vector2(16, 16)) -> RectangleShape2D:
	return GodotTestFactory.create_rectangle_shape(size)

## Create a test circle shape
func create_test_circle_shape(radius: float = 8.0) -> CircleShape2D:
	return GodotTestFactory.create_circle_shape(radius)

## Create a test capsule shape
func create_test_capsule_shape(radius: float = 48.0, height: float = 128.0) -> CapsuleShape2D:
	return GodotTestFactory.create_capsule_shape(radius, height)

## Create a test transform2d
func create_test_transform2d(origin: Vector2 = Vector2.ZERO) -> Transform2D:
	return GodotTestFactory.create_transform2d(origin)

## Create a test tile size
func create_test_tile_size(size: int = 16) -> Vector2:
	return GodotTestFactory.create_tile_size(size)

## Create a test rule check indicator
func create_test_rule_check_indicator_basic(tile_size: int = 16) -> RuleCheckIndicator:
	return GodotTestFactory.create_rule_check_indicator(self, tile_size)
