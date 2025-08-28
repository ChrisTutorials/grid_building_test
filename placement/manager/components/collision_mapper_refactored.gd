extends GdUnitTestSuite

## Refactored collision mapper tests using consolidated factory

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test():
	test_hierarchy = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER)

func test_collision_mapper_basic():
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	var positioner = test_hierarchy.positioner
	
	# Create simple collision object
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(32, 32)
	area.add_child(collision_shape)
	positioner.add_child(area)
	auto_free(area)
	
	# Test basic collision mapping
	var offsets = collision_mapper._get_tile_offsets_for_collision_object(area, tile_map)
	assert_dict(offsets).is_not_empty()

func test_collision_mapper_polygon():
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	var positioner = test_hierarchy.positioner
	
	# Create polygon collision
	var polygon = CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	positioner.add_child(polygon)
	
	var offsets = collision_mapper._get_tile_offsets_for_collision_polygon(polygon, tile_map)
	assert_dict(offsets).is_not_empty()

func test_collision_mapper_multiple_shapes():
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	var positioner = test_hierarchy.positioner
	
	# Create area with multiple shapes
	var area = Area2D.new()
	
	var shape1 = CollisionShape2D.new()
	shape1.shape = RectangleShape2D.new()
	shape1.shape.size = Vector2(16, 16)
	shape1.position = Vector2(-20, 0)
	area.add_child(shape1)
	
	var shape2 = CollisionShape2D.new()
	shape2.shape = RectangleShape2D.new()
	shape2.shape.size = Vector2(16, 16)
	shape2.position = Vector2(20, 0)
	area.add_child(shape2)
	
	positioner.add_child(area)
	auto_free(area)
	
	var offsets = collision_mapper._get_tile_offsets_for_collision_object(area, tile_map)
	assert_dict(offsets).size().is_greater(1)

func test_collision_mapper_position_updates():
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	var positioner = test_hierarchy.positioner
	
	# Create collision object
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(24, 24)
	area.add_child(collision_shape)
	positioner.add_child(area)
	auto_free(area)
	
	# Test at different positions
	var positions = [Vector2.ZERO, Vector2(32, 0), Vector2(64, 32)]
	var all_offsets = []
	
	for pos in positions:
		positioner.position = pos
		var offsets = collision_mapper._get_tile_offsets_for_collision_object(area, tile_map)
		all_offsets.append(offsets)
		assert_dict(offsets).is_not_empty()
	
	# Each position should produce different results
	for i in range(all_offsets.size() - 1):
		assert_dict(all_offsets[i]).is_not_equal(all_offsets[i + 1])
