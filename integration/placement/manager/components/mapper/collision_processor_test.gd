## Unit tests for CollisionProcessor public API
## Tests the unified collision processing for both CollisionObject2D and CollisionPolygon2D
extends GdUnitTestSuite

var _processor: CollisionProcessor

func before_test():
	# Setup minimal dependencies
	_processor = CollisionProcessor.new()

func after_test():
	# Cleanup handled by auto_free
	pass

## Test CollisionObject2D with RectangleShape2D processing
func test_collision_processor_rectangle_shape_square_tiles():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var positioner = UnifiedTestFactory.create_grid_positioner(self)

	# Create a CollisionObject2D with a rectangle shape using factory
	var collision_obj = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(32, 32))
	collision_obj.position = Vector2(840, 680)  # Should map to tile (52, 42)

	# Create test setup data with proper constructor
	var test_data = IndicatorCollisionTestSetup.new(collision_obj, Vector2(16, 16))

	# Act
	var result = _processor.get_tile_offsets_for_collision(collision_obj, test_data, test_map, positioner)

	# Assert
	assert_that(result.size()).append_failure_message("Expected collision processing to return tile offsets for rectangle shape, got empty result").is_greater(0)

	# Verify the center tile is included
	var center_tile = Vector2i(52, 42)
	assert_that(result.has(center_tile)).append_failure_message("Expected center tile %s to be included in collision results" % center_tile).is_true()

	# For a 32x32 rectangle, we expect multiple tiles to be covered
	assert_that(result.size()).append_failure_message("Expected 4-16 tiles for 32x32 rectangle, got %d tiles" % result.size()).is_between(4, 16)

## Test CollisionObject2D with CircleShape2D processing
func test_collision_processor_circle_shape_square_tiles():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var positioner = UnifiedTestFactory.create_grid_positioner(self)

	# Create a CollisionObject2D with a circle shape using factory
	var collision_obj = CollisionObjectTestFactory.create_static_body_with_circle(self, 16.0)
	collision_obj.position = Vector2(840, 680)  # Should map to tile (52, 42)

	# Create test setup data with proper constructor
	var test_data = IndicatorCollisionTestSetup.new(collision_obj, Vector2(16, 16))

	# Act
	var result = _processor.get_tile_offsets_for_collision(collision_obj, test_data, test_map, positioner)

	# Assert
	assert_that(result.size()).append_failure_message("Expected collision processing to return tile offsets for circle shape, got empty result").is_greater(0)

	# Verify the center tile is included
	var center_tile = Vector2i(52, 42)
	var has_center_tile : bool = result.has(center_tile)
	assert_bool(has_center_tile).append_failure_message("Expected center tile %s to be included in collision results" % center_tile).is_true()

	# For a radius 16 circle, we expect 1-9 tiles to be covered
	assert_that(result.size()).append_failure_message("Expected 1-9 tiles for radius 16 circle, got %d tiles" % result.size()).is_between(1, 9)

## Test CollisionPolygon2D processing
func test_collision_processor_polygon_square_tiles():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var positioner = UnifiedTestFactory.create_grid_positioner(self)

	# Create a CollisionPolygon2D with a simple rectangle polygon
	var polygon_node = CollisionPolygon2D.new()
	var polygon_points = PackedVector2Array([
		Vector2(-16, -16),
		Vector2(16, -16),
		Vector2(16, 16),
		Vector2(-16, 16)
	])
	polygon_node.polygon = polygon_points

	# Position the polygon at a known location
	polygon_node.position = Vector2(840, 680)  # Should map to tile (52, 42)
	add_child(polygon_node)
	auto_free(polygon_node)

	# Act - CollisionPolygon2D doesn't need test_data
	var result = _processor.get_tile_offsets_for_collision(polygon_node, null, test_map, positioner)

	# Assert
	assert_that(result.size()).append_failure_message("Expected collision processing to return tile offsets for polygon, got empty result").is_greater(0)

	# Verify the center tile is included
	var center_tile = Vector2i(52, 42)
	assert_that(result.has(center_tile)).append_failure_message("Expected center tile %s to be included in collision results" % center_tile).is_true()

	# For a 32x32 polygon, we expect 1-4 tiles to be covered
	assert_that(result.size()).append_failure_message("Expected 1-4 tiles for 32x32 polygon, got %d tiles" % result.size()).is_between(1, 4)

## Test error handling for null inputs
func test_collision_processor_null_inputs():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var positioner = UnifiedTestFactory.create_grid_positioner(self)

	# Test null collision object
	var result = _processor.get_tile_offsets_for_collision(null, null, test_map, positioner)
	assert_that(result.size()).append_failure_message("Expected empty result for null collision object").is_equal(0)

	# Test null map
	var collision_obj = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(16, 16))
	add_child(collision_obj)
	result = _processor.get_tile_offsets_for_collision(collision_obj, null, null, positioner)
	assert_that(result.size()).append_failure_message("Expected empty result for null map").is_equal(0)

## Test CollisionObject2D without required test_data
func test_collision_processor_missing_test_data():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var positioner = UnifiedTestFactory.create_grid_positioner(self)

	var collision_obj = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(16, 16))
	add_child(collision_obj)

	# Act - Pass null test_data for CollisionObject2D
	var result = _processor.get_tile_offsets_for_collision(collision_obj, null, test_map, positioner)

	# Assert - Should return empty result
	assert_that(result.size()).append_failure_message("Expected empty result when test_data is null for CollisionObject2D").is_equal(0)

## Test isometric tile processing
func test_collision_processor_isometric_tiles():
	var test_map = GodotTestFactory.create_isometric_tile_map_layer(self, 40)
	var positioner = UnifiedTestFactory.create_grid_positioner(self)

	# Create a CollisionObject2D with a rectangle shape using factory
	var collision_obj = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(32, 32))
	collision_obj.position = Vector2(840, 680)
	add_child(collision_obj)

	# Create test setup data with proper constructor
	var test_data = IndicatorCollisionTestSetup.new(collision_obj, Vector2(16, 16))

	# Act
	var result = _processor.get_tile_offsets_for_collision(collision_obj, test_data, test_map, positioner)

	# Assert
	assert_that(result.size()).append_failure_message("Expected collision processing to work with isometric tiles, got empty result").is_greater(0)

	# Verify reasonable tile coverage for isometric
	assert_that(result.size()).append_failure_message("Expected 1-25 tiles for 32x32 rectangle on isometric tiles, got %d tiles" % result.size()).is_between(1, 25)

## Test cache invalidation functionality
func test_collision_processor_cache_invalidation():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var positioner = UnifiedTestFactory.create_grid_positioner(self)

	# Create a collision object using factory
	var collision_obj = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(16, 16))
	collision_obj.position = Vector2(840, 680)
	add_child(collision_obj)

	# Create test setup data with proper constructor
	var test_data = IndicatorCollisionTestSetup.new(collision_obj, Vector2(16, 16))

	# First call to populate cache
	var result1 = _processor.get_tile_offsets_for_collision(collision_obj, test_data, test_map, positioner)
	assert_that(result1.size()).is_greater_than(0)

	# Invalidate cache
	_processor.invalidate_cache()

	# Second call should still work (cache cleared but functionality intact)
	var result2 = _processor.get_tile_offsets_for_collision(collision_obj, test_data, test_map, positioner)
	assert_that(result2.size()).is_greater_than(0)

	# Results should be identical
	assert_that(result1).append_failure_message("Expected identical results after cache invalidation").is_equal(result2)

## Test multiple shapes in single CollisionObject2D
func test_collision_processor_multiple_shapes():
	var test_map = GodotTestFactory.create_top_down_tile_map_layer(self, 40)
	var positioner = UnifiedTestFactory.create_grid_positioner(self)

	# Create a CollisionObject2D with multiple shapes using factory
	var collision_obj = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(16, 16))

	# Add circle shape at offset position using factory
	var circle_body = CollisionObjectTestFactory.create_static_body_with_circle(self, 8.0)
	circle_body.position = Vector2(20, 0)  # Offset from center

	# Move shapes to the main collision object
	var rect_shape_node = collision_obj.get_child(0) as CollisionShape2D
	var circle_shape_node = circle_body.get_child(0) as CollisionShape2D

	collision_obj.remove_child(rect_shape_node)
	circle_body.remove_child(circle_shape_node)

	collision_obj.add_child(rect_shape_node)
	collision_obj.add_child(circle_shape_node)

	# Clean up the extra body
	add_child(collision_obj)
	auto_free(circle_body)

	collision_obj.position = Vector2(840, 680)

	# Create test setup data with proper constructor
	var test_data = IndicatorCollisionTestSetup.new(collision_obj, Vector2(16, 16))

	# Act
	var result = _processor.get_tile_offsets_for_collision(collision_obj, test_data, test_map, positioner)

	# Assert
	assert_that(result.size()).append_failure_message("Expected collision processing to handle multiple shapes").is_greater_than(0)

	# Should cover more tiles than single shape
	assert_that(result.size()).append_failure_message("Expected at least 2 tiles for multiple shapes, got %d tiles" % result.size()).is_greater_equal(2)
