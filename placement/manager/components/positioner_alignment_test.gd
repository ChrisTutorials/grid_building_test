extends GdUnitTestSuite

## Tests that preview objects and indicators are aligned when positioned relative to the positioner

var targeting_state: GridTargetingState
var positioner: Node2D
var tile_map_layer: TileMapLayer


func before_test():
	# Create test setup using GodotTestFactory
	var owner_context = auto_free(GBOwnerContext.new())
	targeting_state = GridTargetingState.new(owner_context)

	tile_map_layer = GodotTestFactory.create_tile_map_layer(self)
	tile_map_layer.tile_set.tile_size = Vector2(16, 16)
	targeting_state.target_map = tile_map_layer

	positioner = GodotTestFactory.create_node2d(self)
	targeting_state.positioner = positioner


## Test that the positioner position affects both preview and indicator positioning consistently
func test_positioner_preview_indicator_alignment():
	# Set positioner to a specific tile position (absolute tile indices)
	var center_tile = Vector2i(2, 2)  # -> world (40, 40) for 16x16 tiles when using tile center
	var expected_world_pos = Vector2(40, 40)  # Tile center

	# Position the positioner at the center tile
	var map = targeting_state.target_map
	positioner.global_position = map.to_global(map.map_to_local(center_tile))

	print("Positioner global_position: %s" % positioner.global_position)
	print("Expected world position for tile %s: %s" % [center_tile, expected_world_pos])

	# Validate positioner location
	(
		assert_that(positioner.global_position.x)
		. append_failure_message("Positioner X should be at tile center")
		. is_equal_approx(expected_world_pos.x, 0.1)
	)
	(
		assert_that(positioner.global_position.y)
		. append_failure_message("Positioner Y should be at tile center")
		. is_equal_approx(expected_world_pos.y, 0.1)
	)

	# Preview object placed as child at local zero -> should align exactly
	var preview_test = auto_free(Node2D.new())
	positioner.add_child(preview_test)
	preview_test.position = Vector2.ZERO
	print("Preview global_position (as child): %s" % preview_test.global_position)
	(
		assert_that(preview_test.global_position.x)
		. append_failure_message("Preview X should match positioner")
		. is_equal_approx(positioner.global_position.x, 0.1)
	)
	(
		assert_that(preview_test.global_position.y)
		. append_failure_message("Preview Y should match positioner")
		. is_equal_approx(positioner.global_position.y, 0.1)
	)

	# IndicatorFactory.position_indicator_as_child expects an OFFSET relative to center tile.
	# Passing absolute tile indices previously caused an unintended +center_tile, producing (72,72).
	# Use Vector2i.ZERO offset to align indicator with positioner center tile.
	var indicator_center = auto_free(RuleCheckIndicator.new())
	# Do not parent here; IndicatorFactory.position_indicator_as_child will handle parenting to the positioner
	indicator_center.shape = GodotTestFactory.create_rectangle_shape(Vector2(16, 16))
	IndicatorFactory.position_indicator_as_child(indicator_center, Vector2i.ZERO, positioner, targeting_state)
	print("Indicator(center offset) global_position: %s" % indicator_center.global_position)
	(
		assert_that(indicator_center.global_position.x)
		. append_failure_message("Indicator (center) X should match preview position")
		. is_equal_approx(preview_test.global_position.x, 0.1)
	)
	(
		assert_that(indicator_center.global_position.y)
		. append_failure_message("Indicator (center) Y should match preview position")
		. is_equal_approx(preview_test.global_position.y, 0.1)
	)

	# Also verify a positive offset of (1,1) lands exactly one tile (16 units) away on each axis
	var indicator_offset = auto_free(RuleCheckIndicator.new())
	# Leave unparented so factory can attach to positioner
	indicator_offset.shape = GodotTestFactory.create_rectangle_shape(Vector2(16, 16))
	var offset = Vector2i(1, 1)
	IndicatorFactory.position_indicator_as_child(indicator_offset, offset, positioner, targeting_state)
	var expected_offset_pos = expected_world_pos + Vector2(16, 16)
	print("Indicator(offset %s) global_position: %s (expected %s)" % [offset, indicator_offset.global_position, expected_offset_pos])
	(
		assert_that(indicator_offset.global_position.x)
		. append_failure_message("Indicator(+1,+1) X should be one tile right of center")
		. is_equal_approx(expected_offset_pos.x, 0.1)
	)
	(
		assert_that(indicator_offset.global_position.y)
		. append_failure_message("Indicator(+1,+1) Y should be one tile down from center")
		. is_equal_approx(expected_offset_pos.y, 0.1)
	)

	# Regression guard: demonstrate the incorrect usage would shift twice
	var incorrect_usage_indicator = auto_free(RuleCheckIndicator.new())
	# Leave unparented intentionally for factory parenting
	incorrect_usage_indicator.shape = GodotTestFactory.create_rectangle_shape(Vector2(16, 16))
	IndicatorFactory.position_indicator_as_child(incorrect_usage_indicator, center_tile, positioner, targeting_state)
	var incorrect_expected = expected_world_pos + Vector2(32, 32) # 2 tiles offset each axis
	print("Indicator(incorrect absolute passed) global_position: %s (expected incorrect %s)" % [incorrect_usage_indicator.global_position, incorrect_expected])
	# Validate both axes separately (must compare floats, not Vector2 to avoid type mismatch)
	(
		assert_that(incorrect_usage_indicator.global_position.x)
		. append_failure_message("Incorrect absolute usage X should be +2 tiles (documentation guard)")
		. is_equal_approx(incorrect_expected.x, 0.1)
	)
	(
		assert_that(incorrect_usage_indicator.global_position.y)
		. append_failure_message("Incorrect absolute usage Y should be +2 tiles (documentation guard)")
		. is_equal_approx(incorrect_expected.y, 0.1)
	)
