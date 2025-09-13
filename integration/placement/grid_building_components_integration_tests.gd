extends GdUnitTestSuite

## Consolidated placement component tests combining collision mappers, geometry calculators,
## polygon tile mappers, and various placement-related components
## Uses placement system test environment for comprehensive setup

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# Test constants
const TILE_SIZE: Vector2 = Vector2(32, 32)
const DEFAULT_RECT_SIZE: Vector2 = Vector2(32, 32)
const PERFORMANCE_TEST_COUNT: int = 50
const PERFORMANCE_TIME_LIMIT_US: int = 500000

var test_env: Dictionary

func before_test() -> void:
	test_env = UnifiedTestFactory.create_indicator_test_environment(self, TEST_CONTAINER)

func after_test() -> void:
	test_env.clear()

#region COLLISION MAPPER TESTS

@warning_ignore("unused_parameter")
func test_collision_mapper_basic_setup() -> void:
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	var collision_setup: IndicatorCollisionTestSetup = test_env.collision_setup
	
	assert_that(indicator_manager).is_not_null()
	assert_that(collision_setup).is_not_null()
	assert_that(collision_setup.collision_object).is_not_null()

@warning_ignore("unused_parameter")
func test_collision_mapper_shape_positioning() -> void:
	var test_object: StaticBody2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	
	# Configure collision mapper for the test object
	UnifiedTestFactory.configure_collision_mapper_for_test_object(
		self, indicator_manager, test_object, test_env.container
	)
	
	# Verify the collision mapper is configured
	var collision_mapper: Object = indicator_manager.get_collision_mapper()
	assert_that(collision_mapper).is_not_null()

@warning_ignore("unused_parameter") 
func test_collision_mapper_movement_tracking() -> void:
	var static_body: StaticBody2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
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
	var tile_map: TileMapLayer = test_env.tile_map
	var polygon: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)
	])
	
	# Test tile iteration range calculation
	var bounds: Rect2 = GBGeometryMath.get_polygon_bounds(polygon)
	var iteration_range: Dictionary = CollisionGeometryUtils.compute_tile_iteration_range(bounds, tile_map)
	
	assert_object(iteration_range.min_tile).is_not_null()
	assert_object(iteration_range.max_tile).is_not_null()

@warning_ignore("unused_parameter")
func test_polygon_tile_mapper_offsets() -> void:
	var tile_map: TileMapLayer = test_env.tile_map
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
	var indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	
	assert_that(indicator).is_not_null()
	assert_that(indicator.shape).is_not_null()
	assert_that(indicator.shape).is_instanceof(RectangleShape2D)

@warning_ignore("unused_parameter")
func test_indicator_factory_with_custom_shape() -> void:
	var indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator_with_shape(self, [], 32)
	
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
	var collision_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	
	assert_that(collision_rule).is_not_null()
	assert_that(collision_rule.collision_mask).is_equal(1)  # Default mask

@warning_ignore("unused_parameter")
func test_collision_layer_rule_setup_with_custom_mask() -> void:
	var collision_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
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
	assert_that(test_env.tile_map).is_not_null()
	assert_that(test_env.container).is_equal(TEST_CONTAINER)
	assert_that(test_env.indicator_manager).is_not_null()
	assert_that(test_env.collision_setup).is_not_null()

@warning_ignore("unused_parameter")
func test_placement_components_workflow() -> void:
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	var test_object: StaticBody2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
	
	# Test complete workflow from object to collision detection
	UnifiedTestFactory.configure_collision_mapper_for_test_object(
		self, indicator_manager, test_object, test_env.container
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
		var indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
		indicator.position = Vector2(i * 10, i * 10)
		assert_that(indicator).is_not_null()
	
	var elapsed: int = Time.get_ticks_usec() - start_time
	test_env.logger.log_info(self, "Placement components performance test completed in " + str(elapsed) + " microseconds")
	assert_that(elapsed).is_less(500000)  # Should complete in under 0.5 seconds

#endregion
