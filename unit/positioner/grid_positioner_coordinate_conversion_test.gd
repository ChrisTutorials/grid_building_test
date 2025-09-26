## Unit tests for GridPositioner2D coordinate conversion accuracy
## Tests the specific issue where mouse input was positioning at tile edges/corners
## instead of tile centers due to incorrect screen-to-world conversion.
extends GdUnitTestSuite

var test_env: Dictionary
var positioner: GridPositioner2D
var tile_map: TileMapLayer

func before_test() -> void:
	# Create test environment with proper tilemap setup
	var collision_env := EnvironmentTestFactory.create_collision_test_environment(self)
	positioner = collision_env.positioner as GridPositioner2D
	tile_map = collision_env.tile_map_layer as TileMapLayer
	
	# Ensure positioner has proper dependencies for coordinate conversion
	assert_object(positioner).is_not_null()
	assert_object(tile_map).is_not_null()
	assert_bool(positioner.is_input_ready()).is_true().append_failure_message(
		"Positioner should be input ready for coordinate conversion tests"
	)

func test_screen_to_world_conversion_accuracy() -> void:
	# Test: screen coordinate conversion should be accurate and deterministic
	# Setup: Known screen position
	var screen_pos := Vector2(100, 150)
	
	# Act: Convert screen to world using positioner method
	var world_pos: Vector2 = positioner._test_convert_screen_to_world(screen_pos)
	
	# Assert: Should get a valid world position (not zero unless screen pos was at origin)
	assert_vector(world_pos).is_not_equal(Vector2.ZERO).append_failure_message(
		"Screen position %s should convert to non-zero world position, got %s" % [str(screen_pos), str(world_pos)]
	)
	
	# Assert: Conversion should be deterministic (same input = same output)
	var world_pos2: Vector2 = positioner._test_convert_screen_to_world(screen_pos)
	assert_vector(world_pos2).is_equal(world_pos).append_failure_message(
		"Screen-to-world conversion should be deterministic: %s != %s" % [str(world_pos), str(world_pos2)]
	)

func test_tile_center_positioning_accuracy() -> void:
	# Test: mouse input at screen positions should position at tile CENTERS, not edges
	# Setup: Test multiple screen positions
	var test_positions := [
		Vector2(32, 32),   # Should map to tile center
		Vector2(64, 64),   # Different tile center
		Vector2(16, 48),   # Should still center in target tile
		Vector2(80, 16)    # Another test position
	]
	
	for screen_pos in test_positions:
		# Act: Get tile center calculation from screen position
		var result: Dictionary = positioner._test_get_tile_center_from_screen(screen_pos)
		
		# Assert: Should get valid results
		assert_object(result.get("tile")).is_not_null().append_failure_message(
			"Should get valid tile coordinate for screen pos %s" % str(screen_pos)
		)
		assert_vector(result.get("world_pos", Vector2.ZERO)).is_not_equal(Vector2.ZERO).append_failure_message(
			"Should get valid world position for screen pos %s" % str(screen_pos)
		)
		assert_vector(result.get("tile_center", Vector2.ZERO)).is_not_equal(Vector2.ZERO).append_failure_message(
			"Should get valid tile center for screen pos %s" % str(screen_pos)
		)
		
		# Critical test: Verify positioner moves to EXACT tile center
		var tile_coord: Vector2i = result.get("tile")
		var tile_center: Vector2 = result.get("tile_center")
		
		# Move positioner using the screen coordinate (like mouse input does)
		var motion_event := InputEventMouseMotion.new()
		motion_event.position = screen_pos
		positioner._handle_mouse_motion_event(motion_event, GBEnums.Mode.MOVE)
		
		# Assert: Positioner should be positioned at tile center, not at edge/corner
		var position_diff := positioner.global_position.distance_to(tile_center)
		assert_float(position_diff).is_less(1.0).append_failure_message(
			"Positioner should be at tile center. Screen: %s, Tile: %s, Expected center: %s, Actual pos: %s, Distance: %.2f" % [
				str(screen_pos), str(tile_coord), str(tile_center), str(positioner.global_position), position_diff
			]
		)

func test_mouse_motion_event_tile_centering() -> void:
	# Test: InputEventMouseMotion should result in precise tile center positioning
	# Setup: Create realistic mouse motion events
	var test_cases := [
		{"screen": Vector2(48, 32), "description": "Top area of tile"},
		{"screen": Vector2(32, 48), "description": "Left area of tile"},
		{"screen": Vector2(48, 48), "description": "Center area of tile"},
		{"screen": Vector2(63, 63), "description": "Bottom-right area of tile"}
	]
	
	for test_case in test_cases:
		var screen_pos: Vector2 = test_case.screen
		var description: String = test_case.description
		
		# Act: Simulate mouse motion event
		var motion_event := InputEventMouseMotion.new()
		motion_event.position = screen_pos
		
		# Get expected tile and center before moving
		var expected_result: Dictionary = positioner._test_get_tile_center_from_screen(screen_pos)
		var expected_tile: Vector2i = expected_result.get("tile")
		var expected_center: Vector2 = expected_result.get("tile_center")
		
		# Trigger mouse motion handling
		positioner._handle_mouse_motion_event(motion_event, GBEnums.Mode.MOVE)
		
		# Assert: Should be positioned at exact tile center regardless of where in tile the mouse was
		var actual_pos := positioner.global_position
		var distance_from_center := actual_pos.distance_to(expected_center)
		
		assert_float(distance_from_center).is_less(0.5).append_failure_message(
			"%s: Mouse at %s should position at tile %s center %s, but positioned at %s (distance: %.2f)" % [
				description, str(screen_pos), str(expected_tile), str(expected_center), str(actual_pos), distance_from_center
			]
		)
		
		# Also verify we're in the correct tile
		var actual_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(actual_pos, tile_map)
		assert_that(actual_tile).is_equal(expected_tile).append_failure_message(
			"%s: Should be in tile %s but positioned in tile %s" % [description, str(expected_tile), str(actual_tile)]
		)

func test_coordinate_conversion_edge_cases() -> void:
	# Test: Edge cases for coordinate conversion
	var edge_cases := [
		{"screen": Vector2.ZERO, "description": "Origin position"},
		{"screen": Vector2(1, 1), "description": "Near origin"},
		{"screen": Vector2(15, 15), "description": "Tile edge boundary"},
		{"screen": Vector2(16, 16), "description": "Tile size boundary"},
		{"screen": Vector2(31, 31), "description": "Almost next tile"}
	]
	
	for case in edge_cases:
		var screen_pos: Vector2 = case.screen
		var description: String = case.description
		
		# Act: Convert coordinates
		var world_pos: Vector2 = positioner._test_convert_screen_to_world(screen_pos)
		var tile_result: Dictionary = positioner._test_get_tile_center_from_screen(screen_pos)
		
		# Assert: Should always get valid, finite results
		assert_bool(is_finite(world_pos.x) and is_finite(world_pos.y)).is_true().append_failure_message(
			"%s: World position should be finite, got %s" % [description, str(world_pos)]
		)
		
		var tile_center: Vector2 = tile_result.get("tile_center", Vector2.ZERO)
		assert_bool(is_finite(tile_center.x) and is_finite(tile_center.y)).is_true().append_failure_message(
			"%s: Tile center should be finite, got %s" % [description, str(tile_center)]
		)

func after_test() -> void:
	# Cleanup
	if test_env.has("cleanup"):
		test_env.cleanup.call()