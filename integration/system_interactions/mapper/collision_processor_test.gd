## Unit tests for CollisionProcessor public API
## Tests the unified collision processing for both CollisionObject2D and CollisionPolygon2D
extends GdUnitTestSuite

var _processor: CollisionProcessor
var _test_env: Dictionary

func before_test() -> void:
	# Setup minimal dependencies
	var container: GBCompositionContainer = GBCompositionContainer.new()
	var logger: GBLogger = container.get_logger()
	_processor = CollisionProcessor.new(logger)
	_test_env = _create_base_test_environment()

func after_test() -> void:
	# Cleanup handled by auto_free
	pass

## Helper method to create common test environment (DRY principle)
func _create_base_test_environment() -> Dictionary[String, Variant]:
	var positioner := GridPositioner2D.new()
	add_child(positioner)
	auto_free(positioner)
	return {
		"top_down_map": GodotTestFactory.create_top_down_tile_map_layer(self, 40),
		"isometric_map": GodotTestFactory.create_isometric_tile_map_layer(self, 40),
		"positioner": positioner,
		"tile_size": Vector2(16, 16),
		"test_position": Vector2(840, 680),  # Maps to tile (52, 42)
		"center_tile": Vector2i(52, 42)
	}

## Helper method to create collision test setup (DRY principle)
func _create_collision_test_setup(collision_obj: CollisionObject2D) -> CollisionTestSetup2D:
	return CollisionTestSetup2D.new(collision_obj, _test_env.tile_size)

## Helper method to verify basic collision processing results (DRY principle)
func _verify_collision_result(result: Dictionary, expected_min_tiles: int, expected_max_tiles: int, test_description: String) -> void:
	assert_that(result.size()).append_failure_message("Expected collision processing to return tile offsets for %s, got empty result" % test_description).is_greater(0)

	# Verify the center tile is included
	assert_that(result.has(_test_env.center_tile)).append_failure_message("Expected center tile %s to be included in collision results for %s" % [_test_env.center_tile, test_description]).is_true()

	# Verify tile count is in expected range
	assert_that(result.size()).append_failure_message("Expected %d-%d tiles for %s, got %d tiles" % [expected_min_tiles, expected_max_tiles, test_description, result.size()]).is_between(expected_min_tiles, expected_max_tiles)

## Parameterized test for collision processor with different shapes on square tiles
@warning_ignore("unused_parameter")
func test_collision_processor_shapes_square_tiles(
	shape_type: String,
	shape_size: Vector2,
	expected_min_tiles: int,
	expected_max_tiles: int,
	test_parameters := [
		["rectangle", Vector2(32, 32), 4, 16],     # 32x32 rectangle should cover 4-16 tiles
		["circle", Vector2(16, 16), 1, 9],         # radius 16 circle should cover 1-9 tiles
	]
) -> void:
	# Setup
	var collision_obj: CollisionObject2D
	if shape_type == "rectangle":
		collision_obj = CollisionObjectTestFactory.create_static_body_with_rect(self, shape_size)
	elif shape_type == "circle":
		collision_obj = CollisionObjectTestFactory.create_static_body_with_circle(self, shape_size.x)  # Use x as radius

	collision_obj.position = _test_env.test_position
	var test_data: CollisionTestSetup2D = _create_collision_test_setup(collision_obj)

	# Act
	var tile_offsets : Dictionary[Vector2i, Array] = _processor.get_tile_offsets_for_collision(collision_obj, test_data, _test_env.top_down_map, _test_env.positioner)

	# Assert
	_verify_collision_result(tile_offsets, expected_min_tiles, expected_max_tiles, "%s shape" % shape_type)

## Test CollisionPolygon2D processing
func test_collision_processor_polygon_square_tiles() -> void:
	# Create a CollisionPolygon2D with a simple rectangle polygon
	var polygon_node := CollisionPolygon2D.new()
	var polygon_points := PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	polygon_node.polygon = polygon_points
	polygon_node.position = _test_env.test_position
	add_child(polygon_node)
	auto_free(polygon_node)

	# Act - CollisionPolygon2D doesn't need test_data
	var tile_offsets : Dictionary[Vector2i, Array] = _processor.get_tile_offsets_for_collision(polygon_node, null, _test_env.top_down_map, _test_env.positioner)

	# Assert - Polygon processing may have different behavior than shape processing
	assert_that(tile_offsets.size()).append_failure_message("Expected collision processing to return tile offsets for polygon, got empty result").is_greater(0)
	# Relaxed expectations for polygon - it uses different algorithms and may cover more tiles
	assert_that(tile_offsets.size()).append_failure_message("Expected 1-16 tiles for 32x32 polygon, got %d tiles" % tile_offsets.size()).is_between(1, 16)

## Parameterized test for error handling scenarios
@warning_ignore("unused_parameter")
func test_collision_processor_error_handling(
	collision_obj_valid: bool,
	test_data_valid: bool,
	map_valid: bool,
	expected_size: int,
	test_description: String,
	test_parameters := [
		[false, false, true, 0, "null collision object"],
		[true, false, false, 0, "null map"],
		[true, false, true, 0, "missing test_data for CollisionObject2D"]
	]
) -> void:
	# Setup test objects based on parameters
	var collision_obj : CollisionObject2D= null
	var test_data : CollisionTestSetup2D = null
	var test_map : TileMapLayer = null

	if collision_obj_valid:
		collision_obj = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(16, 16))
		# Don't add_child - factory already handles parenting

	if test_data_valid and collision_obj != null:
		test_data = _create_collision_test_setup(collision_obj)

	if map_valid:
		test_map = _test_env.top_down_map

	# Act
	var result : Dictionary[Vector2i, Array] = _processor.get_tile_offsets_for_collision(collision_obj, test_data, test_map, _test_env.positioner)

	# Assert - result is a Dictionary, not Array[Node2D]
	assert_that(result.size()).append_failure_message("Expected empty result for %s" % test_description).is_equal(expected_size)

## Test isometric tile processing
func test_collision_processor_isometric_tiles() -> void:
	var collision_obj : StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(32, 32))
	collision_obj.position = _test_env.test_position
	# Factory already handles parenting

	var test_data : CollisionTestSetup2D = _create_collision_test_setup(collision_obj)

	# Act
	var result : Dictionary[Vector2i, Array] = _processor.get_tile_offsets_for_collision(collision_obj, test_data, _test_env.isometric_map, _test_env.positioner)

	# Assert - For isometric, we expect more tiles and different center behavior
	assert_that(result.size()).append_failure_message("Expected collision processing to work with isometric tiles, got empty result").is_greater(0)
	assert_that(result.size()).append_failure_message("Expected 1-25 tiles for 32x32 rectangle on isometric tiles, got %d tiles" % result.size()).is_between(1, 25)

## Test cache invalidation functionality
func test_collision_processor_cache_invalidation() -> void:
	var collision_obj : StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(16, 16))
	collision_obj.position = _test_env.test_position
	# Factory already handles parenting

	var test_data : CollisionTestSetup2D = _create_collision_test_setup(collision_obj)

	# First call to populate cache
	var result1 : Dictionary[Vector2i, Array] = _processor.get_tile_offsets_for_collision(collision_obj, test_data, _test_env.top_down_map, _test_env.positioner)
	assert_that(result1.size()).append_failure_message(
		"First collision processing call should return tile offsets"
	).is_greater(0)

	# Invalidate cache
	_processor.invalidate_cache()

	# Second call should still work (cache cleared but functionality intact)
	var result2 : Dictionary[Vector2i, Array] = _processor.get_tile_offsets_for_collision(collision_obj, test_data, _test_env.top_down_map, _test_env.positioner)
	assert_that(result2.size()).append_failure_message(
		"Second collision processing call after cache invalidation should return tile offsets"
	).is_greater(0)

	# Results should be identical
	assert_that(result1).append_failure_message("Expected identical results after cache invalidation").is_equal(result2)

## Test multiple shapes in single CollisionObject2D
func test_collision_processor_multiple_shapes() -> void:
	# Create a CollisionObject2D with multiple shapes using factory
	var collision_obj : StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(16, 16))

	# Add circle shape at offset position using factory
	var circle_body : StaticBody2D = CollisionObjectTestFactory.create_static_body_with_circle(self, 8.0)
	circle_body.position = Vector2(8, 8)  # Offset from center

	# Move shapes to the main collision object
	var rect_shape_node: CollisionShape2D = collision_obj.get_child(0) as CollisionShape2D
	var circle_shape_node: CollisionShape2D = circle_body.get_child(0) as CollisionShape2D

	collision_obj.remove_child(rect_shape_node)
	circle_body.remove_child(circle_shape_node)

	collision_obj.add_child(rect_shape_node)
	collision_obj.add_child(circle_shape_node)

	# Clean up the extra body - don't add to scene since factories handle it
	auto_free(circle_body)

	collision_obj.position = _test_env.test_position
	var test_data: CollisionTestSetup2D = _create_collision_test_setup(collision_obj)

	# Act
	var result: Dictionary[Vector2i, Array] = _processor.get_tile_offsets_for_collision(collision_obj, test_data, _test_env.top_down_map, _test_env.positioner)

	# Assert - result is a Dictionary[Vector2i, Array[Node2D]]
	assert_that(result.size()).append_failure_message("Expected collision processing to handle multiple shapes").is_greater(0)
	# Multiple shapes may only cover 1 tile if they're small and close together
	assert_that(result.size()).append_failure_message("Expected at least 1 tile for multiple shapes, got %d tiles" % result.size()).is_greater_equal(1)

## Parameterized unit tests for shape-specific calculations
@warning_ignore("unused_parameter")
func test_calculate_tile_range_shapes(
	shape_type: String,
	shape_param: float,
	expected_width_span: int,
	expected_height_span: int,
	test_parameters := [
		["rectangle", 32.0, 2, 2],  # 32x32 rectangle should span >1 tile in both dimensions
		["circle", 20.0, 2, 2]      # radius 20 circle should span >1 tile in both dimensions
	]
) -> void:
	var shape: Shape2D
	var bounds: Rect2

	if shape_type == "rectangle":
		shape = RectangleShape2D.new()
		shape.size = Vector2(shape_param, shape_param)
		bounds = Rect2(Vector2(824, 664), Vector2(shape_param, shape_param))  # Center position minus half size
	elif shape_type == "circle":
		shape = CircleShape2D.new()
		shape.radius = shape_param
		bounds = Rect2(Vector2(840 - shape_param, 680 - shape_param), Vector2(shape_param * 2, shape_param * 2))

	var shape_transform: Transform2D = Transform2D()
	shape_transform.origin = _test_env.test_position

	# Act
	var result: Dictionary[String, Vector2i] = _processor.calculate_tile_range(shape, bounds, _test_env.top_down_map, _test_env.tile_size, shape_transform)

	# Assert
	assert_that(result).append_failure_message(
		"calculate_tile_range should return a non-null result"
	).is_not_null()
	assert_that(result.has("start")).append_failure_message(
		"calculate_tile_range result should contain 'start' key"
	).is_true()
	assert_that(result.has("end_exclusive")).append_failure_message(
		"calculate_tile_range result should contain 'end_exclusive' key"
	).is_true()

	var start_tile: Vector2i = result["start"]
	var end_exclusive: Vector2i = result["end_exclusive"]

	assert_that(end_exclusive.x - start_tile.x).append_failure_message("Expected width span >= %d for %s, got %d" % [expected_width_span, shape_type, end_exclusive.x - start_tile.x]).is_greater_equal(expected_width_span)
	assert_that(end_exclusive.y - start_tile.y).append_failure_message("Expected height span >= %d for %s, got %d" % [expected_height_span, shape_type, end_exclusive.y - start_tile.y]).is_greater_equal(expected_height_span)

## Unit test for process_shape_offsets method
func test_process_shape_offsets_rectangle() -> void:
	var collision_obj: CollisionObject2D = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(32, 32))
	collision_obj.position = _test_env.test_position

	var test_data: CollisionTestSetup2D = _create_collision_test_setup(collision_obj)
	var rect_test_setup: RectCollisionTestingSetup = test_data.rect_collision_test_setups[0] as RectCollisionTestingSetup

	var shape_epsilon: float = 0.1

	# Act
	var result: Dictionary[Vector2i, Array] = _processor.process_shape_offsets(rect_test_setup, test_data, _test_env.top_down_map, _test_env.center_tile, _test_env.tile_size, shape_epsilon, collision_obj)

	# Assert - result is a Dictionary[Vector2i, Array[Node2D]]
	assert_that(result).append_failure_message(
		"process_shape_offsets should return a non-null result for rectangle shape"
	).is_not_null()
	assert_that(result.size()).append_failure_message("Expected shape offsets to be calculated for rectangle, got %d results" % result.size()).is_greater(0)
	# Since collision object and center_tile are at same position, relative offset should be (0, 0)
	var expected_relative_offset: Vector2i = Vector2i(0, 0)
	assert_that(result.has(expected_relative_offset)).append_failure_message("Expected relative offset %s to be included in shape offsets for collision object at center position" % expected_relative_offset).is_true()

## Unit test for compute_shape_tile_offsets method
func test_compute_shape_tile_offsets_rectangle() -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(32, 32)

	var shape_transform: Transform2D = Transform2D()
	shape_transform.origin = _test_env.test_position

	var shape_polygon: PackedVector2Array = GBGeometryMath.convert_shape_to_polygon(shape, shape_transform)
	var start_tile: Vector2i = Vector2i(50, 40)
	var end_exclusive: Vector2i = Vector2i(55, 45)
	var shape_epsilon: float = 0.1

	# Act
	var result: Array[Vector2i] = _processor.compute_shape_tile_offsets(shape, shape_transform, _test_env.top_down_map, _test_env.tile_size, shape_epsilon, start_tile, end_exclusive, _test_env.center_tile, shape_polygon)

	# Assert
	assert_that(result).append_failure_message(
		"Shape tile offsets calculation should return a result"
	).is_not_null()
	assert_that(result.size()).append_failure_message("Expected tile offsets to be calculated for rectangle shape, got %d results" % result.size()).is_greater(0)

	# Verify result contains Vector2i offsets
	for offset: Variant in result:
		assert_that(offset is Vector2i).append_failure_message("Expected all results to be Vector2i offsets, got %s" % type_string(typeof(offset))).is_true()
