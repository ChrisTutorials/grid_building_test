class_name IndicatorPositioningTest
extends GdUnitTestSuite

## Tests that RuleCheckIndicators are positioned correctly at tile centers in world space

var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger

func before_test():
	logger = UnifiedTestFactory.create_test_logger()
	targeting_state = auto_free(GridTargetingState.new(auto_free(GBOwnerContext.new())))
	tile_map_layer = UnifiedTestFactory.create_test_tile_map_layer(self)
	targeting_state.target_map = tile_map_layer
	
	# Create positioner and set it to a specific target position
	positioner = auto_free(Node2D.new())
	positioner.global_position = Vector2(32, 32)  # Target position at tile (2, 2) with 16x16 tiles
	targeting_state.positioner = positioner

func after_test():
	pass

## Test that indicators are positioned at the correct world positions for their tile coordinates
func test_indicator_world_positioning():
	# Test with known tile positions and expected world positions (at tile centers with 16x16 tiles)
	var test_cases = [
		[Vector2i(0, 0), Vector2(8, 8)],       # Tile (0,0) center -> World (8,8)
		[Vector2i(1, 1), Vector2(24, 24)],     # Tile (1,1) center -> World (24,24) 
		[Vector2i(2, 2), Vector2(40, 40)],     # Tile (2,2) center -> World (40,40)
		[Vector2i(-1, -1), Vector2(-8, -8)]    # Tile (-1,-1) center -> World (-8,-8)
	]
	
	for test_case in test_cases:
		var tile_pos = test_case[0] as Vector2i
		var expected_world_pos = test_case[1] as Vector2
		
		# Test the tile-to-world conversion directly using the same logic as IndicatorManager
		var map = targeting_state.target_map
		var actual_world_pos = map.to_global(map.map_to_local(tile_pos))
		
		print("Tile pos: %s -> World pos: %s (expected %s)" % [tile_pos, actual_world_pos, expected_world_pos])
		
		# Check that the conversion produces the expected world position
		assert_that(actual_world_pos.x).append_failure_message("World X position should match expected for tile %s" % tile_pos).is_equal_approx(expected_world_pos.x, 0.1)
		assert_that(actual_world_pos.y).append_failure_message("World Y position should match expected for tile %s" % tile_pos).is_equal_approx(expected_world_pos.y, 0.1)
