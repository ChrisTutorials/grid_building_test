extends GdUnitTestSuite

## Simplified collision mapper movement tests using consolidated factory

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test():
	# Use consolidated factory instead of manual setup
	test_hierarchy = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER)

## Test that collision detection updates when positioner moves
func test_positioner_movement_updates_collision():
	var positioner = test_hierarchy.positioner
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	
	# Create collision object
	var collision_polygon = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	positioner.add_child(collision_polygon)
	
	# Test case 1: Positioner at (0, 0)
	positioner.global_position = Vector2(0, 0)
	var offsets1 = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map)
	
	# Test case 2: Positioner moved to (32, 32)
	positioner.global_position = Vector2(32, 32)
	var offsets2 = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map)
	
	# Movement should produce different offsets
	assert_dict(offsets1).is_not_equal(offsets2)
	assert_dict(offsets1).is_not_empty()
	assert_dict(offsets2).is_not_empty()

func test_collision_mapper_tracks_movement():
	var positioner = test_hierarchy.positioner
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	
	# Create collision object
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(24, 24)
	area.add_child(collision_shape)
	positioner.add_child(area)
	auto_free(area)
	
	# Create test setup for collision mapper
	var test_setup = IndicatorCollisionTestSetup.new(area, Vector2(32, 32), test_hierarchy.logger)
	
	# Test at different positions
	var positions = [Vector2.ZERO, Vector2(32, 0), Vector2(0, 32), Vector2(32, 32)]
	var all_offsets = []
	
	for pos in positions:
		positioner.position = pos
		var offsets = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map)
		all_offsets.append(offsets)
		assert_dict(offsets).is_not_empty()
	
	# Each position should produce different offset patterns
	assert_int(all_offsets.size()).is_equal(4)
	for i in range(all_offsets.size()):
		for j in range(i + 1, all_offsets.size()):
			assert_dict(all_offsets[i]).is_not_equal(all_offsets[j])
