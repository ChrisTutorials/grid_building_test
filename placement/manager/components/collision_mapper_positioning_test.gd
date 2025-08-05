extends GdUnitTestSuite

## Tests for collision mapper positioning and RCI generation to ensure correct tile offsets and positioning

var collision_mapper: CollisionMapper
var targeting_state: GridTargetingState
var logger: GBLogger
var tile_map: TileMapLayer
var positioner: ShapeCast2D
var test_indicator: RuleCheckIndicator

func before_test():
	# Create test dependencies using factory methods
	logger = UnifiedTestFactory.create_test_logger()
	var owner_context = UnifiedTestFactory.create_test_owner_context(self)
	targeting_state = GridTargetingState.new(owner_context)

	# Create tile map with known tile size (16x16)
	tile_map = auto_free(TileMapLayer.new())
	var tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_map.tile_set = tile_set

	# Create positioner at a known position
	positioner = auto_free(ShapeCast2D.new())
	positioner.global_position = Vector2(840, 680)  # Same as runtime analysis

	# Set up targeting state
	targeting_state.positioner = positioner
	targeting_state.target_map = tile_map

	# Create collision mapper
	collision_mapper = CollisionMapper.new(targeting_state, logger)

	# Create test indicator
	test_indicator = auto_free(RuleCheckIndicator.new([], logger))
	var indicator_shape = RectangleShape2D.new()
	indicator_shape.size = Vector2(16, 16)
	test_indicator.shape = indicator_shape

func test_center_tile_calculation():
	## Test that center tile calculation matches expected coordinates for positioner at (840, 680)
	# Given: Positioner at (840, 680) with 16x16 tiles
	var expected_center_tile = Vector2i(52, 42)  # 840/16 = 52.5 -> 52, 680/16 = 42.5 -> 42

	# When: Converting positioner position to tile coordinates
	var actual_center_tile = tile_map.local_to_map(positioner.global_position)

	# Then: Should match expected tile coordinates
	assert_that(actual_center_tile).is_equal(expected_center_tile)

func test_basic_collision_detection():
	## Test basic collision detection using the rect-based method
	# Given: A capsule-like rectangular area
	var rect_size = Vector2(96, 128)  # Similar to capsule with radius=48, height=128

	# When: Using the rect-based tile calculation method
	var tile_positions = collision_mapper.get_rect_tile_positions(positioner.global_position, rect_size)

	# Then: Should produce reasonable tile positions
	assert_that(tile_positions.size()).is_greater(0).append_failure_message("Should detect at least one tile")

	# All tile positions should be reasonable offsets from center
	var center_tile = tile_map.local_to_map(positioner.global_position)
	for tile_pos in tile_positions:
		var offset = tile_pos - center_tile
		assert_that(abs(offset.x)).is_less_equal(6).append_failure_message("X offset too large: " + str(offset))
		assert_that(abs(offset.y)).is_less_equal(8).append_failure_message("Y offset too large: " + str(offset))
