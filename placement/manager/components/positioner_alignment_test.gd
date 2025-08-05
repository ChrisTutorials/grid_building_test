class_name PositionerAlignmentTest
extends GdUnitTestSuite

## Tests that preview objects and indicators are aligned when positioned relative to the positioner

var targeting_state: GridTargetingState
var positioner: Node2D
var tile_map_layer: TileMapLayer

func before_test():
	# Create test setup
	var owner_context = auto_free(GBOwnerContext.new())
	targeting_state = GridTargetingState.new(owner_context)
	
	tile_map_layer = auto_free(TileMapLayer.new())
	add_child(tile_map_layer)
	tile_map_layer.tile_set = TileSet.new()
	tile_map_layer.tile_set.tile_size = Vector2(16, 16)
	targeting_state.target_map = tile_map_layer
	
	positioner = auto_free(Node2D.new())
	targeting_state.positioner = positioner

## Test that the positioner position affects both preview and indicator positioning consistently
func test_positioner_preview_indicator_alignment():
	# Set positioner to a specific tile position
	var target_tile = Vector2i(2, 2)  # Should be at world (40, 40) with 16x16 tiles at centers
	var expected_world_pos = Vector2(40, 40)  # Tile center
	
	# Position the positioner at the target tile center
	var map = targeting_state.target_map
	positioner.global_position = map.to_global(map.map_to_local(target_tile))
	
	print("Positioner global_position: %s" % positioner.global_position)
	print("Expected world position for tile %s: %s" % [target_tile, expected_world_pos])
	
	# Test that positioner is at expected location
	assert_that(positioner.global_position.x).append_failure_message("Positioner X should be at tile center").is_equal_approx(expected_world_pos.x, 0.1)
	assert_that(positioner.global_position.y).append_failure_message("Positioner Y should be at tile center").is_equal_approx(expected_world_pos.y, 0.1)
	
	# Test that preview object (if created as child of positioner) would be at positioner position
	var preview_test = auto_free(Node2D.new())
	positioner.add_child(preview_test)
	preview_test.position = Vector2.ZERO  # Local position relative to positioner
	
	print("Preview global_position (as child): %s" % preview_test.global_position)
	
	# Preview should be at same global position as positioner when local position is zero
	assert_that(preview_test.global_position.x).append_failure_message("Preview X should match positioner").is_equal_approx(positioner.global_position.x, 0.1)
	assert_that(preview_test.global_position.y).append_failure_message("Preview Y should match positioner").is_equal_approx(positioner.global_position.y, 0.1)
	
	# Test indicator positioning using current logic
	var indicator = auto_free(RuleCheckIndicator.new())
	var indicator_template = load("res://test/grid_building_test/scenes/indicators/test_indicator.tscn")
	var logger = GBLogger.new(GBDebugSettings.new())
	var indicator_manager = IndicatorManager.new(positioner, targeting_state, indicator_template, logger)
	
	# Position indicator using the same logic as the real system
	indicator_manager.setup_indicator_as_child(indicator, target_tile, positioner)
	
	print("Indicator global_position: %s" % indicator.global_position)
	
	# Indicator should be at same position as preview (both should align)
	assert_that(indicator.global_position.x).append_failure_message("Indicator X should match preview position").is_equal_approx(preview_test.global_position.x, 0.1)
	assert_that(indicator.global_position.y).append_failure_message("Indicator Y should match preview position").is_equal_approx(preview_test.global_position.y, 0.1)
