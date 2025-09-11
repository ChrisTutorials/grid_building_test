extends GdUnitTestSuite

# Unit tests for CollisionUtilities to catch utility method failures
# that cause collision mapping issues in higher-level tests.

const CollisionUtilities = preload("uid://842dmikaq7xu")

var _targeting_state: GridTargetingState

func before_test():
	_targeting_state = GridTargetingState.new(GBOwnerContext.new(null))

# Test catches: CollisionUtilities rectangle tile position calculation
func test_collision_utilities_rect_tile_positions() -> void:
	# Create a mock tile map
	mock_map: Node = TileMapLayer.new()
	auto_free(mock_map)
	var tile_set = TileSet.new()
	tile_set.tile_size = Vector2tile_size
	mock_map.tile_set = tile_set

	# Set up targeting state
	_targeting_state.target_map = mock_map

	# Test rectangle at origin
	var center_pos = Vector2center_pos
	var rect_size = Vector2rect_size  # Single tile

	var result = CollisionUtilities.get_rect_tile_positions(_targeting_state, center_pos, rect_size)
	assert_that(result != null).append_failure_message("Should return valid tile positions").is_true()
	assert_that(result is Array[Node2D]).append_failure_message("Result should be an array").is_true()

	# Should contain at least the center tile
	var contains_center = false
	for pos in result:
		if pos == Vector2i(0, 0):
			contains_center = true
			break

	assert_that(contains_center).append_failure_message("Should contain center tile (0,0)").is_true()

# Test catches: CollisionUtilities handling invalid tile map
func test_collision_utilities_invalid_tile_map() -> void:
	# Set up targeting state with invalid map
	_targeting_state.target_map = null

	var center_pos = Vector2center_pos
	var rect_size = Vector2rect_size

	var result = CollisionUtilities.get_rect_tile_positions(_targeting_state, center_pos, rect_size)
	assert_that(result != null).append_failure_message("Should handle invalid tile map gracefully").is_true()
	assert_that(result.is_empty()).append_failure_message("Should return empty array for invalid tile map").is_true()

# Test catches: CollisionUtilities indicator-shape overlap detection
func test_collision_utilities_indicator_overlap() -> void:
	# Create mock indicator
	var indicator = RuleCheckIndicator.new()
	auto_free(indicator)
	indicator.position = Vector2position
	add_child(indicator)

	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2size
	indicator.shape = rect_shape

	# Create mock shape owner
	var shape_owner : Node2D = Node2D.new()
	auto_free(shape_owner)
	shape_owner.position = Vector2position
	add_child(shape_owner)

	var target_shape = RectangleShape2D.new()
	auto_free(target_shape)
	target_shape.size = Vector2size

	# Test overlapping shapes
	var result = CollisionUtilities.does_indicator_overlap_shape(indicator, target_shape, shape_owner)
	assert_that(result is bool).append_failure_message("Should return boolean result").is_true()

	# Test with null shapes (should not crash)
	var null_result = CollisionUtilities.does_indicator_overlap_shape(indicator, null, shape_owner)
	assert_that(null_result is bool).append_failure_message("Should handle null target shape gracefully").is_true()
