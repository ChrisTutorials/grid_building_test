extends GdUnitTestSuite

## Simple test to verify collision mapper positioning logic

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var collision_mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var positioner: Node2D


func before_test():
	# Configure the TEST_CONTAINER's targeting state directly
	tile_map_layer = GodotTestFactory.create_tile_map_layer(self)
	positioner = GodotTestFactory.create_node2d(self)
	var container_targeting_state = TEST_CONTAINER.get_states().targeting
	container_targeting_state.target_map = tile_map_layer
	container_targeting_state.positioner = positioner

	collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)


## Test that collision detection updates when positioner moves
func test_positioner_movement_updates_collision():
	# Test case 1: Positioner at (0, 0)
	positioner.global_position = Vector2(0, 0)

	var collision_polygon: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(
		self, PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	)
	collision_polygon.global_position = Vector2(1000, 1000)  # Far from positioner

	var test_indicator: RuleCheckIndicator = GodotTestFactory.create_rule_check_indicator(self)
	collision_mapper.setup(test_indicator, {})

	var result1 = collision_mapper._get_tile_offsets_for_collision_polygon(
		collision_polygon, tile_map_layer
	)
	print("Positioner at (0,0): ", result1.keys())

	# Test case 2: Move positioner to (32, 32)
	positioner.global_position = Vector2(32, 32)

	var result2 = collision_mapper._get_tile_offsets_for_collision_polygon(
		collision_polygon, tile_map_layer
	)
	print("Positioner at (32,32): ", result2.keys())

	# The results should be different since the positioner moved
	(
		assert_that(result1.keys())
		. append_failure_message("Results should be different when positioner moves")
		. is_not_equal(result2.keys())
	)
