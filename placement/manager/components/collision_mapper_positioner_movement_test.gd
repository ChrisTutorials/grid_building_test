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
	positioner.name = "TestPositioner"
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

	var test_indicator: RuleCheckIndicator = GodotTestFactory.create_rule_check_indicator(self, self)
	collision_mapper.setup(test_indicator, {})

	var offsets1 = collision_mapper._get_tile_offsets_for_collision_polygon(
		collision_polygon, tile_map_layer
	)
	# TODO: Debug prints removed per no-prints rule

	# Test case 2: Move positioner to (32, 32)
	positioner.global_position = Vector2(32, 32)


	var offsets2 = collision_mapper._get_tile_offsets_for_collision_polygon(
		collision_polygon, tile_map_layer
	)

	(
		assert_that(offsets1.keys())
		. append_failure_message("Tile offsets should be different when positioner moves")
		. is_not_equal(offsets2.keys())
	)

## New test: When polygon is parented to positioner, offsets remain stable as both move.
func test_parented_polygon_offsets_stable():
	positioner.global_position = Vector2(0,0)

	var collision_polygon: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(
		self, PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	)
	# Reparent polygon under positioner so it tracks movement
	if collision_polygon.get_parent() != positioner:
		var prev_parent = collision_polygon.get_parent()
		if prev_parent:
			prev_parent.remove_child(collision_polygon)
		positioner.add_child(collision_polygon)
	# Large local offset so its world position differs from positioner yet follows it
	collision_polygon.position = Vector2(1000, 1000)

	var test_indicator: RuleCheckIndicator = GodotTestFactory.create_rule_check_indicator(self, self)
	collision_mapper.setup(test_indicator, {})

	var offsets1 = collision_mapper._get_tile_offsets_for_collision_polygon(
		collision_polygon, tile_map_layer
	)
	positioner.global_position = Vector2(64,64)
	var offsets2 = collision_mapper._get_tile_offsets_for_collision_polygon(
		collision_polygon, tile_map_layer
	)
	assert_that(offsets1.keys()).append_failure_message("Parented polygon offsets should remain stable when moving positioner").is_equal(offsets2.keys())
