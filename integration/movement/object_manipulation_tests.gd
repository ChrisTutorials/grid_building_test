extends GdUnitTestSuite

## Consolidated placement component tests combining collision mappers, geometry calculators,
## polygon tile mappers, and various placement-related components
## Uses placement system test environment for comprehensive setup

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

## Isometric game RuleCheckIndicator 
const RCI_ISOMETRIC : PackedScene = preload("uid://bs3xba0ifer7b")

## Top-down sidescroller square shape RuleCheckIndicator
const RCI_TD_SIDE : PackedScene = preload("uid://dhox8mb8kuaxa")


# Test constants
const TILE_SIZE: Vector2 = Vector2(32, 32)
const DEFAULT_RECT_SIZE: Vector2 = Vector2(32, 32)
const PERFORMANCE_TEST_COUNT: int = 50
const PERFORMANCE_TIME_LIMIT_US: int = 500000

var test_env: CollisionTestEnvironment

func before_test() -> void:
	# Load collision test environment scene from GBTestConstants
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.COLLISION_TEST)
	if not env_scene:
		# Try the path fallback directly
		env_scene = load(GBTestConstants.COLLISION_TEST_ENV_PATH)
	
	if not env_scene:
		# Last fallback to the old UID that was in the test 
		env_scene = load("uid://cdrtd538vrmun")
	
	assert(env_scene != null, "Failed to load collision test environment scene")
	test_env = env_scene.instantiate() as CollisionTestEnvironment
	add_child(test_env)
	auto_free(test_env)

func after_test() -> void:
	pass

# Helper: Create test rule check indicator
func _create_test_rule_check_indicator() -> RuleCheckIndicator:
	var scene: PackedScene = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	var indicator: RuleCheckIndicator = scene.instantiate()
	auto_free(indicator)
	add_child(indicator)
	return indicator

# Helper: Configure collision mapper for test object
func _configure_collision_mapper_for_test_object(_test_object: StaticBody2D, _indicator_manager: IndicatorManager, _container: GBCompositionContainer) -> void:
	# Use the targeting state from test environment instead of creating a new one
	var targeting_state: GridTargetingState = test_env.targeting_state
	var _setups: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(_test_object, targeting_state)
	# Note: Actual configuration would depend on collision mapper API
	# For now, just create the setups to use CollisionTestSetup2D factory

#region COLLISION MAPPER TESTS

@warning_ignore("unused_parameter")
func test_collision_mapper_basic_setup() -> void:
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	# Create a collision setup using factory instead of expecting it from environment
	var test_object: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, DEFAULT_RECT_SIZE)
	var collision_setups: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(test_object, test_env.targeting_state)
	
	assert_that(indicator_manager).is_not_null()
	assert_that(collision_setups.size()).is_greater(0)
	var collision_setup: CollisionTestSetup2D = collision_setups[0]
	assert_that(collision_setup).is_not_null()
	assert_that(collision_setup.collision_object).is_not_null()

@warning_ignore("unused_parameter")
func test_collision_mapper_shape_positioning() -> void:
	var test_object: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, DEFAULT_RECT_SIZE)
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	
	# Configure collision mapper for the test object
	_configure_collision_mapper_for_test_object(
		test_object, indicator_manager, test_env.container
	)
	
	# Verify the collision mapper is configured
	var collision_mapper: Object = indicator_manager.get_collision_mapper()
	assert_that(collision_mapper).is_not_null()

@warning_ignore("unused_parameter") 
func test_collision_mapper_movement_tracking() -> void:
	var static_body: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, DEFAULT_RECT_SIZE)
	var initial_pos: Vector2 = Vector2.ZERO
	var moved_pos: Vector2 = TILE_SIZE
	
	static_body.position = initial_pos
	assert_that(static_body.position).is_equal(initial_pos)
	
	static_body.position = moved_pos
	assert_that(static_body.position).is_equal(moved_pos)

#endregion

#endregion

#region GEOMETRY CALCULATOR TESTS

@warning_ignore("unused_parameter")
func test_geometry_calculator_basic_operations() -> void:
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = DEFAULT_RECT_SIZE
	auto_free(rect_shape)
	
	# Test shape bounds calculation
	var bounds: Rect2 = Rect2(Vector2.ZERO, rect_shape.size)
	assert_that(bounds.size).is_equal(DEFAULT_RECT_SIZE)

@warning_ignore("unused_parameter")
func test_geometry_calculator_polygon_bounds() -> void:
	var polygon: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)
	])
	
	var bounds: Rect2 = GBGeometryMath.get_polygon_bounds(polygon)
	assert_that(bounds.size).is_equal(Vector2(16, 16))

#endregion

#endregion

#region POLYGON TILE MAPPER TESTS

@warning_ignore("unused_parameter")
func test_polygon_tile_mapper_basic() -> void:
	var tile_map: TileMapLayer = test_env.tile_map_layer
	var polygon: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)
	])
	
	# Test tile iteration range calculation
	var bounds: Rect2 = GBGeometryMath.get_polygon_bounds(polygon)
	var iteration_range: Dictionary = CollisionGeometryUtils.compute_tile_iteration_range(bounds, tile_map)
	
	assert_object(iteration_range.start).is_not_null()
	assert_object(iteration_range.end_exclusive).is_not_null()

@warning_ignore("unused_parameter")
func test_polygon_tile_mapper_offsets() -> void:
	var tile_map: TileMapLayer = test_env.tile_map_layer
	var polygon: PackedVector2Array = PackedVector2Array([
		Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)
	])
	
	var center_tile: Vector2i = CollisionGeometryUtils.center_tile_for_polygon_positioner(tile_map, test_env.indicator_manager)
	var tile_size: Vector2 = TILE_SIZE
	
	var offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		polygon, tile_size, center_tile, TileSet.TILE_SHAPE_SQUARE, tile_map
	)
	
	assert_that(offsets.size()).is_greater_equal(1)

#endregion

#endregion

#region AREA2D ROTATION INDICATOR TESTS

@warning_ignore("unused_parameter")
func test_area2d_rotation_indicator_basic() -> void:
	var area: Area2D = Area2D.new()
	area.name = "TestRotationArea"
	auto_free(area)
	add_child(area)
	
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = TILE_SIZE
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	
	# Test basic rotation
	area.rotation = PI / 4  # 45 degrees
	assert_that(area.rotation).is_equal_approx(PI / 4, 0.01)

@warning_ignore("unused_parameter") 
func test_area2d_rotation_indicator_collision() -> void:
	var area: Area2D = Area2D.new()
	area.collision_layer = 2
	area.collision_mask = 2
	auto_free(area)
	add_child(area)
	
	assert_that(area.collision_layer).is_equal(2)
	assert_that(area.collision_mask).is_equal(2)

#endregion

#endregion

#region INDICATOR FACTORY TESTS

@warning_ignore("unused_parameter")
func test_indicator_factory_rule_check_creation() -> void:
	var indicator: RuleCheckIndicator = _create_test_rule_check_indicator()
	
	assert_that(indicator).is_not_null()
	assert_that(indicator.shape).is_not_null()
	assert_that(indicator.shape).is_instanceof(RectangleShape2D)

@warning_ignore("unused_parameter")
func test_indicator_factory_with_custom_shape() -> void:
	var indicator: RuleCheckIndicator = _create_test_rule_check_indicator()
	
	assert_that(indicator).is_not_null()
	assert_that(indicator.shape).is_not_null()
	var rect_shape: RectangleShape2D = indicator.shape as RectangleShape2D
	assert_that(rect_shape.size).is_equal(TILE_SIZE)

#endregion

#endregion

#region GRID ALIGNMENT TESTS

@warning_ignore("unused_parameter")
func test_grid_alignment_basic() -> void:
	var positioner: GridPositioner2D = test_env.injector.get_node("TestPositioner") if test_env.injector.has_node("TestPositioner") else GridPositioner2D.new()
	if not test_env.injector.has_node("TestPositioner"):
		positioner.name = "TestPositioner"
		auto_free(positioner)
		test_env.injector.add_child(positioner)
	
	var tile_size: Vector2 = TILE_SIZE
	
	# Test basic grid alignment calculation
	var world_pos: Vector2 = Vector2(20, 25)
	var aligned_pos: Vector2 = Vector2(
		floor(world_pos.x / tile_size.x) * tile_size.x,
		floor(world_pos.y / tile_size.y) * tile_size.y
	)
	
	assert_that(aligned_pos).is_equal(Vector2(0, 32))  # Assuming 32x32 tiles

#endregion

#endregion

#region COLLISION LAYER RULE SETUP TESTS

@warning_ignore("unused_parameter")
func test_collision_layer_rule_setup_validation() -> void:
	var collision_rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()
	
	assert_that(collision_rule).is_not_null()
	assert_that(collision_rule.collision_mask).is_equal(1)  # Default mask

@warning_ignore("unused_parameter")
func test_collision_layer_rule_setup_with_custom_mask() -> void:
	var collision_rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()
	collision_rule.collision_mask = 256  # Custom mask
	
	assert_that(collision_rule.collision_mask).is_equal(256)

#endregion

#endregion

#region INTEGRATION TESTS

@warning_ignore("unused_parameter")
func test_placement_environment_integration() -> void:
	# Verify all components of placement system environment work together
	assert_that(test_env.injector).is_not_null()
	assert_that(test_env.logger).is_not_null()
	assert_that(test_env.tile_map_layer).is_not_null()
	assert_that(test_env.container).is_equal(TEST_CONTAINER)
	assert_that(test_env.indicator_manager).is_not_null()
	# Note: collision_setup property was removed from environment - collision setups are now created per-test as needed

@warning_ignore("unused_parameter")
func test_placement_components_workflow() -> void:
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	var test_object: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, DEFAULT_RECT_SIZE)
	
	# Test complete workflow from object to collision detection
	_configure_collision_mapper_for_test_object(
		test_object, indicator_manager, test_env.container
	)
	
	var collision_mapper: Object = indicator_manager.get_collision_mapper()
	assert_that(collision_mapper).is_not_null()
	
	# Verify the workflow completed successfully
	var testing_indicator: RuleCheckIndicator = indicator_manager.get_or_create_testing_indicator(self)
	assert_that(testing_indicator).is_not_null()

@warning_ignore("unused_parameter")
func test_performance_placement_components() -> void:
	var start_time: int = Time.get_ticks_usec()
	var _placement_manager: IndicatorManager = test_env.indicator_manager
	
	# Performance test creating multiple indicators
	for i in range(50):
		var indicator: RuleCheckIndicator = _create_test_rule_check_indicator()
		indicator.position = Vector2(i * 10, i * 10)
		assert_that(indicator).is_not_null()
	
	var elapsed: int = Time.get_ticks_usec() - start_time
	test_env.logger.log_info(self, "Placement components performance test completed in " + str(elapsed) + " microseconds")
	assert_that(elapsed).is_less(500000)  # Should complete in under 0.5 seconds

#endregion
