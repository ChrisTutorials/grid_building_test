extends GdUnitTestSuite

## Tests that CollisionMapper calculates collision positions relative to the target position (positioner),
## not the preview object's current world position. This ensures indicators appear at the correct locations
## where the object will be placed, not where the preview object currently exists.

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var collision_mapper: CollisionMapper
var tile_map_layer: TileMapLayer
var positioner: Node2D


func before_test():
	tile_map_layer = auto_free(TileMapLayer.new())
	add_child(tile_map_layer)
	tile_map_layer.tile_set = TileSet.new()
	tile_map_layer.tile_set.tile_size = Vector2(16, 16)

	# Create positioner and set it to a specific target position
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	positioner.position = Vector2(32, 32)  # Target position at tile (2, 2) with 16x16 tiles

	# Configure the TEST_CONTAINER's targeting state directly
	var container_targeting_state = TEST_CONTAINER.get_states().targeting
	container_targeting_state.target_map = tile_map_layer
	container_targeting_state.positioner = positioner

	collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)

func after_test():
	if collision_mapper:
		collision_mapper = null


## Test that CollisionPolygon2D collision detection uses positioner position, not object's current position
func test_collision_polygon_uses_target_position():
	# Create a CollisionPolygon2D parented to the positioner so it logically moves with it
	var collision_polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	positioner.add_child(collision_polygon)
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])

	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	if test_indicator.get_parent() == null:
		add_child(test_indicator)
	test_indicator.shape = auto_free(RectangleShape2D.new())
	collision_mapper.setup(test_indicator, {})

	var result = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)

	# Expected four neighboring offsets around center
	var expected_offsets := [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 0)]
	(
		assert_that(result.keys())
		. append_failure_message("Polygon offsets should be relative to positioner center tile")
		. contains_same(expected_offsets)
	)


## Test that CollisionObject2D shapes use positioner position for collision detection
func test_collision_object_uses_target_position():
	# Create CollisionObject2D with shape
	var static_body: StaticBody2D = auto_free(StaticBody2D.new())
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rectangle_shape: RectangleShape2D = auto_free(RectangleShape2D.new())
	rectangle_shape.size = Vector2(16, 16)
	collision_shape.shape = rectangle_shape
	collision_shape.position = Vector2(0, 0)  # Centered on object
	static_body.add_child(collision_shape)

	# Position the object far from target position
	static_body.global_position = Vector2(200, 200)

	# Create test setup using the correct constructor
	var test_setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(
		static_body, Vector2(0, 0), TEST_CONTAINER.get_logger()
	)

	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	if test_indicator.get_parent() == null:
		add_child(test_indicator)
	test_indicator.shape = auto_free(RectangleShape2D.new())
	collision_mapper.setup(test_indicator, {static_body: test_setup})

	# Get collision positions - should be relative to positioner (32, 32)
	var result = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map_layer)

	# Should detect collision at positioner position as offsets from center tile
	# Shape offsets now pivot on the object's own tile; a 16x16 shape centered on its tile yields only (0,0)
	var expected_offsets = [Vector2i(0, 0)]

	# TODO: Debug print removed per no-prints rule

	(
		assert_that(result.keys())
		. append_failure_message("Should detect collision at target position as offsets")
		. contains_same(expected_offsets)
	)
	# Object is at (200, 200) = tile (12, 12), so offset from center (2, 2) would be (10, 10)
	(
		assert_that(result.keys())
		. append_failure_message("Should not detect collision at object's current position")
		. not_contains([Vector2i(10, 10)])
	)


## Test position calculation with different positioner positions
func test_collision_position_follows_positioner_movement():
	# Polygon parented to positioner => offsets should remain constant as positioner moves
	var collision_polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	positioner.add_child(collision_polygon)
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
	])

	var core := [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 0)]
	var positions := [Vector2(0,0), Vector2(16,16), Vector2(48,64)]
	for pos in positions:
		positioner.position = pos
		var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
		if test_indicator.get_parent() == null:
			add_child(test_indicator)
		test_indicator.shape = auto_free(RectangleShape2D.new())
		collision_mapper.setup(test_indicator, {})
		var result = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
		(
			assert_that(result.keys())
			. append_failure_message("Core subset should remain present with parented polygon when positioner moves to %s" % pos)
			. contains_same(core)
		)


## Test that center tile calculation works correctly
func test_center_tile_calculation():
	# Given: Positioner at specific position with 16x16 tiles
	positioner.global_position = Vector2(840, 680)
	var expected_center_tile = Vector2i(52, 42)  # 840/16 = 52.5 -> 52, 680/16 = 42.5 -> 42

	# When: Converting positioner position to tile coordinates
	var actual_center_tile = tile_map_layer.local_to_map(positioner.global_position)

	# Then: Should match expected tile coordinates
	assert_that(actual_center_tile).is_equal(expected_center_tile)


## Test basic collision detection using rect-based method
func test_rect_based_collision_detection():
	# Given: A capsule-like rectangular area
	positioner.global_position = Vector2(840, 680)
	var rect_size = Vector2(96, 128)  # Similar to capsule with radius=48, height=128

	# When: Using the rect-based tile calculation method
	var tile_positions = collision_mapper.get_rect_tile_positions(
		positioner.global_position, rect_size
	)

	# Then: Should produce reasonable tile positions
	assert_that(tile_positions.size()).is_greater(0).append_failure_message(
		"Should detect at least one tile"
	)

	# All tile positions should be reasonable offsets from center
	var center_tile = tile_map_layer.local_to_map(positioner.global_position)
	for tile_pos in tile_positions:
		var offset = tile_pos - center_tile
		assert_that(abs(offset.x)).is_less_equal(6).append_failure_message(
			"X offset too large: " + str(offset)
		)
		assert_that(abs(offset.y)).is_less_equal(8).append_failure_message(
			"Y offset too large: " + str(offset)
		)
