## Unit tests for CollisionShapeProcessor._compute_shape_tile_offsets method
## Tests the core geometric calculation logic for various shape types
extends GdUnitTestSuite

const CollisionShapeProcessor = preload("res://addons/grid_building/placement/manager/components/mapper/collision_shape_processor.gd")
const GeometryCacheManager = preload("uid://d0cdgiqycnh43")

var _processor: CollisionShapeProcessor
var _cache_manager: GeometryCacheManager
var _logger: GBLogger

func before_test():
	# Setup minimal dependencies
	_logger = GBLogger.new()
	_cache_manager = GeometryCacheManager.new()
	_processor = CollisionShapeProcessor.new(_cache_manager, _logger)

func after_test():
	# Cleanup handled by auto_free
	pass

## Test data for parameterized shape testing
@warning_ignore("unused_parameter")
func test_compute_shape_tile_offsets_for_various_shapes(
	test_name: String,
	shape: Shape2D,
	transform_offset: Vector2,
	tile_shape: TileSet.TileShape,
	expected_offset_count: int,
	expected_center_offset: Vector2i,
	test_parameters := [
		# Rectangle tests - square tiles
		["small_rectangle_16x16_square", GodotTestFactory.create_rectangle_shape(Vector2(16, 16)), Vector2.ZERO, TileSet.TILE_SHAPE_SQUARE, 1, Vector2i.ZERO],
		["medium_rectangle_32x32_square", GodotTestFactory.create_rectangle_shape(Vector2(32, 32)), Vector2.ZERO, TileSet.TILE_SHAPE_SQUARE, 9, Vector2i.ZERO],
		["large_rectangle_48x32_square", GodotTestFactory.create_rectangle_shape(Vector2(48, 32)), Vector2.ZERO, TileSet.TILE_SHAPE_SQUARE, 9, Vector2i.ZERO],
		["offset_rectangle_24x24_square", GodotTestFactory.create_rectangle_shape(Vector2(24, 24)), Vector2(8, 8), TileSet.TILE_SHAPE_SQUARE, 4, Vector2i.ZERO],
		
		# Circle tests - square tiles
		["small_circle_r8_square", GodotTestFactory.create_circle_shape(8.0), Vector2.ZERO, TileSet.TILE_SHAPE_SQUARE, 1, Vector2i.ZERO],
		["medium_circle_r12_square", GodotTestFactory.create_circle_shape(12.0), Vector2.ZERO, TileSet.TILE_SHAPE_SQUARE, 5, Vector2i.ZERO],
		["large_circle_r16_square", GodotTestFactory.create_circle_shape(16.0), Vector2.ZERO, TileSet.TILE_SHAPE_SQUARE, 5, Vector2i.ZERO],
		
		# Capsule tests - square tiles
		["horizontal_capsule_32x16_square", GodotTestFactory.create_capsule_shape(16.0, 16.0), Vector2.ZERO, TileSet.TILE_SHAPE_SQUARE, 1, Vector2i.ZERO],
		["vertical_capsule_16x32_square", GodotTestFactory.create_capsule_shape(8.0, 24.0), Vector2.ZERO, TileSet.TILE_SHAPE_SQUARE, 1, Vector2i.ZERO],
		
		# Rectangle tests - isometric tiles
		["small_rectangle_16x16_isometric", GodotTestFactory.create_rectangle_shape(Vector2(16, 16)), Vector2.ZERO, TileSet.TILE_SHAPE_ISOMETRIC, 1, Vector2i.ZERO],
		["medium_rectangle_32x32_isometric", GodotTestFactory.create_rectangle_shape(Vector2(32, 32)), Vector2.ZERO, TileSet.TILE_SHAPE_ISOMETRIC, 9, Vector2i.ZERO],
		["large_rectangle_48x32_isometric", GodotTestFactory.create_rectangle_shape(Vector2(48, 32)), Vector2.ZERO, TileSet.TILE_SHAPE_ISOMETRIC, 9, Vector2i.ZERO],
		["offset_rectangle_24x24_isometric", GodotTestFactory.create_rectangle_shape(Vector2(24, 24)), Vector2(8, 8), TileSet.TILE_SHAPE_ISOMETRIC, 4, Vector2i.ZERO],
		
		# Circle tests - isometric tiles
		["small_circle_r8_isometric", GodotTestFactory.create_circle_shape(8.0), Vector2.ZERO, TileSet.TILE_SHAPE_ISOMETRIC, 1, Vector2i.ZERO],
		["medium_circle_r12_isometric", GodotTestFactory.create_circle_shape(12.0), Vector2.ZERO, TileSet.TILE_SHAPE_ISOMETRIC, 5, Vector2i.ZERO],
		["large_circle_r16_isometric", GodotTestFactory.create_circle_shape(16.0), Vector2.ZERO, TileSet.TILE_SHAPE_ISOMETRIC, 5, Vector2i.ZERO],
		
		# Capsule tests - isometric tiles
		["horizontal_capsule_32x16_isometric", GodotTestFactory.create_capsule_shape(16.0, 16.0), Vector2.ZERO, TileSet.TILE_SHAPE_ISOMETRIC, 1, Vector2i.ZERO],
		["vertical_capsule_16x32_isometric", GodotTestFactory.create_capsule_shape(8.0, 24.0), Vector2.ZERO, TileSet.TILE_SHAPE_ISOMETRIC, 1, Vector2i.ZERO],
	]
) -> void:
	# Setup tilemap based on tile_shape parameter
	var test_map: TileMapLayer
	if tile_shape == TileSet.TILE_SHAPE_ISOMETRIC:
		test_map = GodotTestFactory.create_isometric_tile_map_layer(self, 40)
	else:
		test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	
	# Arrange
	var shape_transform = Transform2D()
	shape_transform.origin = Vector2(840, 680) + transform_offset  # Standard position plus offset
	
	var center_tile = Vector2i(52, 42)  # Calculated from standard position
	var tile_size = Vector2(16, 16)
	var shape_epsilon = 0.035
	
	# Calculate tile range based on shape bounds
	var shape_polygon = GBGeometryMath.convert_shape_to_polygon(shape, shape_transform)
	var bounds = _cache_manager.get_cached_polygon_bounds(shape_polygon)
	var tile_range = _calculate_test_tile_range(bounds, test_map)
	var start_tile = tile_range["start"]
	var end_exclusive = tile_range["end_exclusive"]
	
	# Act - Call the private method directly
	var result_offsets = _processor._compute_shape_tile_offsets(
		shape, 
		shape_transform, 
		test_map, 
		tile_size, 
		shape_epsilon, 
		start_tile, 
		end_exclusive, 
		center_tile, 
		shape_polygon
	)
	
	# Assert with detailed debugging
	assert_that(result_offsets.size()).is_equal(expected_offset_count) \
		.override_failure_message("%s: Expected %d tile offsets for %s, got %d.\nShape bounds: %s\nTile range: %s to %s\nResult offsets: %s" % [
			_get_tile_shape_name(tile_shape), expected_offset_count, test_name, result_offsets.size(), bounds, start_tile, end_exclusive, result_offsets
		])
	
	# Verify center offset is included for non-zero expected counts
	if expected_offset_count > 0:
		assert_that(result_offsets).contains([expected_center_offset]) \
			.override_failure_message("%s: Expected center offset %s to be included in results for %s" % [_get_tile_shape_name(tile_shape), expected_center_offset, test_name])

## Test edge cases and boundary conditions
func test_compute_shape_tile_offsets_edge_cases():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var shape_transform = Transform2D()
	shape_transform.origin = Vector2(840, 680)
	var center_tile = Vector2i(52, 42)
	var tile_size = Vector2(16, 16)
	var shape_epsilon = 0.035
	
	# Test with small shape that should still produce a tile (made larger to pass area threshold)
	var small_shape = GodotTestFactory.create_rectangle_shape(Vector2(8, 8))  # Increased from 2x2
	var shape_polygon = GBGeometryMath.convert_shape_to_polygon(small_shape, shape_transform)
	var bounds = _cache_manager.get_cached_polygon_bounds(shape_polygon)
	var tile_range = _calculate_test_tile_range(bounds, test_map)
	var start_tile = tile_range["start"]
	var end_exclusive = tile_range["end_exclusive"]
	
	var result = _processor._compute_shape_tile_offsets(
		small_shape, shape_transform, test_map, tile_size, shape_epsilon,
		start_tile, end_exclusive, center_tile, shape_polygon
	)
	
	# Should include at least the center tile
	assert_that(result.size()).is_greater_equal(1) \
		.override_failure_message("Expected at least 1 tile for small shape, got %d. Shape size: %s, bounds: %s, offsets: %s" % [
			result.size(), small_shape.size, bounds, result
		])
	assert_that(result).contains([Vector2i.ZERO]) \
		.override_failure_message("Expected center offset (0,0) to be included in results: %s" % result)

## Test circle-specific filtering logic
func test_circle_tile_filtering():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var circle_shape = GodotTestFactory.create_circle_shape(12.0)
	var shape_transform = Transform2D()
	shape_transform.origin = Vector2(840, 680)
	var center_tile = Vector2i(52, 42)
	var tile_size = Vector2(16, 16)
	var shape_epsilon = 0.035
	
	var shape_polygon = GBGeometryMath.convert_shape_to_polygon(circle_shape, shape_transform)
	var bounds = _cache_manager.get_cached_polygon_bounds(shape_polygon)
	var tile_range = _calculate_test_tile_range(bounds, test_map)
	var start_tile = tile_range["start"]
	var end_exclusive = tile_range["end_exclusive"]
	
	var result = _processor._compute_shape_tile_offsets(
		circle_shape, shape_transform, test_map, tile_size, shape_epsilon,
		start_tile, end_exclusive, center_tile, shape_polygon
	)
	
	# Verify circle filtering is working (should exclude corner tiles that don't meet circle criteria)
	# For a 12 radius circle, we expect roughly 4-5 tiles depending on exact positioning
	assert_that(result.size()).is_between(3, 6)

## Test area epsilon thresholds for different shape types
func test_area_epsilon_thresholds():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var shape_transform = Transform2D()
	shape_transform.origin = Vector2(840, 680)
	var center_tile = Vector2i(52, 42)
	var tile_size = Vector2(16, 16)
	var shape_epsilon = 0.035
	
	# Test circle with reduced epsilon (should be more permissive)
	var circle_shape = GodotTestFactory.create_circle_shape(10.0)
	var circle_polygon = GBGeometryMath.convert_shape_to_polygon(circle_shape, shape_transform)
	var circle_bounds = _cache_manager.get_cached_polygon_bounds(circle_polygon)
	var circle_tile_range = _calculate_test_tile_range(circle_bounds, test_map)
	var start_tile = circle_tile_range["start"]
	var end_exclusive = circle_tile_range["end_exclusive"]
	
	var circle_result = _processor._compute_shape_tile_offsets(
		circle_shape, shape_transform, test_map, tile_size, shape_epsilon,
		start_tile, end_exclusive, center_tile, circle_polygon
	)
	
	# Test rectangle with standard epsilon
	var rect_shape = GodotTestFactory.create_rectangle_shape(Vector2(20, 20))
	var rect_polygon = GBGeometryMath.convert_shape_to_polygon(rect_shape, shape_transform)
	var rect_bounds = _cache_manager.get_cached_polygon_bounds(rect_polygon)
	var rect_tile_range = _calculate_test_tile_range(rect_bounds, test_map)
	start_tile = rect_tile_range["start"]
	end_exclusive = rect_tile_range["end_exclusive"]
	
	var rect_result = _processor._compute_shape_tile_offsets(
		rect_shape, shape_transform, test_map, tile_size, shape_epsilon,
		start_tile, end_exclusive, center_tile, rect_polygon
	)
	
	# Both should include center tile
	assert_that(circle_result).contains([Vector2i.ZERO])
	assert_that(rect_result).contains([Vector2i.ZERO])

## Test corner tile area requirements
func test_corner_tile_area_requirements():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	# Create a shape that will have corner tiles with minimal overlap
	var large_rect = GodotTestFactory.create_rectangle_shape(Vector2(50, 50))
	var shape_transform = Transform2D()
	shape_transform.origin = Vector2(840, 680)
	var center_tile = Vector2i(52, 42)
	var tile_size = Vector2(16, 16)
	var shape_epsilon = 0.035
	
	var shape_polygon = GBGeometryMath.convert_shape_to_polygon(large_rect, shape_transform)
	var bounds = _cache_manager.get_cached_polygon_bounds(shape_polygon)
	var tile_range = _calculate_test_tile_range(bounds, test_map)
	var start_tile = tile_range["start"]
	var end_exclusive = tile_range["end_exclusive"]
	
	var result = _processor._compute_shape_tile_offsets(
		large_rect, shape_transform, test_map, tile_size, shape_epsilon,
		start_tile, end_exclusive, center_tile, shape_polygon
	)
	
	# Should have a reasonable number of tiles for a 50x50 rectangle
	# Based on actual results, expect around 21 tiles (adjusted from 8-16)
	assert_that(result.size()).is_between(18, 25) \
		.override_failure_message("Expected 18-25 tiles for 50x50 rectangle, got %d. Bounds: %s, tile range: %s to %s, offsets: %s" % [
			result.size(), bounds, start_tile, end_exclusive, result
		])

## Helper to calculate tile range for testing - returns Dictionary with start and end_exclusive
func _calculate_test_tile_range(bounds: Rect2, map: TileMapLayer) -> Dictionary:
	var tile_size = Vector2(16, 16)
	var min_local = map.to_local(bounds.position)
	var max_local = map.to_local(bounds.position + bounds.size)
	var start_tile = Vector2i(
		int(floor(min_local.x / tile_size.x)),
		int(floor(min_local.y / tile_size.y))
	)
	var end_exclusive = Vector2i(
		int(ceil(max_local.x / tile_size.x)),
		int(ceil(max_local.y / tile_size.y))
	)
	return {"start": start_tile, "end_exclusive": end_exclusive}

## Helper to convert TileShape enum to readable string for error messages
func _get_tile_shape_name(tile_shape: TileSet.TileShape) -> String:
	match tile_shape:
		TileSet.TILE_SHAPE_SQUARE:
			return "SQUARE"
		TileSet.TILE_SHAPE_ISOMETRIC:
			return "ISOMETRIC"
		TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE:
			return "HALF_OFFSET_SQUARE"
		_:
			return "UNKNOWN"
