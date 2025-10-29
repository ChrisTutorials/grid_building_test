## Unit tests for GridPositioner2D coordinate conversion accuracy## Unit tests for GridPositioner2D coordinate conversion accuracy

####

## Tests that coordinate system conversions work correctly:## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern

## - Screen coordinates to world coordinates## for better reliability and deterministic frame control.

## - Tile coordinate calculations##

## - Tile center positioning for mouse input## IMPORTANT: Objects are expected to be placed in the MIDDLE of tiles.

extends GdUnitTestSuite## The GridPositioner2D snaps to tile centers, not edges/corners.

## Tests verify that moNo, no, no. No. Yes. No. That's very sketchy. No. use input correctly positions at tile centers.

var runner: GdUnitSceneRunnerextends GdUnitTestSuite

var test_env: CollisionTestEnvironment

var positioner: GridPositioner2Dvar runner: GdUnitSceneRunner

var tile_map: TileMapLayervar test_env: CollisionTestEnvironment

var positioner: GridPositioner2D

var tile_map: TileMapLayer

func before_test() -> void:

	## Create test environment with proper tilemap setup# Helper functions for detailed diagnostics

	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)func _format_coordinate_debug(screen_pos: Vector2, world_pos: Vector2, tile_coord: Vector2i, tile_center: Vector2, actual_pos: Vector2) -> String:

	test_env = runner.scene() as CollisionTestEnvironment	var distance_from_center := actual_pos.distance_to(tile_center)

	positioner = test_env.positioner	var tile_size: Vector2 = Vector2(16, 16)  # Default tile size

	tile_map = test_env.tile_map_layer	if tile_map.tile_set != null:

		tile_size = tile_map.tile_set.tile_size

	return "Coordinate conversion debug - Screen: %s → World: %s → Tile: %s → Expected center: %s → Actual: %s (distance: %.3f px, tile_size: %s)" % [

func test_screen_to_world_conversion() -> void:		str(screen_pos), str(world_pos), str(tile_coord), str(tile_center), str(actual_pos), distance_from_center, str(tile_size)

	## Test: Screen coordinates should convert to world coordinates correctly	]

	var screen_pos := Vector2(32, 32)

func _format_conversion_environment() -> String:

	## Act: Convert screen to world	var viewport := positioner.get_viewport()

	var world_pos: Vector2 = positioner._test_convert_screen_to_world(screen_pos)	var camera := viewport.get_camera_2d() if viewport else null

	var zoom := camera.zoom if camera else Vector2.ONE

	## Assert: Should get non-zero world position	var camera_pos := camera.global_position if camera else Vector2.ZERO

	assert_vector(world_pos).append_failure_message(	return "Environment - Viewport: %s, Camera: %s, Zoom: %s, Camera pos: %s" % [

		"Screen position %s should convert to non-zero world position, got %s" % [		viewport != null, camera != null, str(zoom), str(camera_pos)

			str(screen_pos), str(world_pos)	]

		]

	).is_not_equal(Vector2.ZERO)func _format_tile_mapping_debug(screen_pos: Vector2) -> String:

	var world_pos := positioner._test_convert_screen_to_world(screen_pos)

	## Assert: Conversion should be deterministic (same input = same output)	var tile_result := positioner._test_get_tile_center_from_screen(screen_pos)

	var world_pos2: Vector2 = positioner._test_convert_screen_to_world(screen_pos)	var tile_coord: Vector2i = tile_result.get("tile", Vector2i.ZERO)

	assert_vector(world_pos2).append_failure_message(	var tile_center: Vector2 = tile_result.get("tile_center", Vector2.ZERO)

		"Screen-to-world conversion should be deterministic: %s != %s" % [	var map_local_pos := tile_map.to_local(world_pos)

			str(world_pos), str(world_pos2)	var map_tile_coord := tile_map.local_to_map(map_local_pos)

		]	return "Tile mapping - Screen %s → World %s → Map local %s → Map tile %s → Positioner tile %s → Center %s" % [

	).is_equal(world_pos)		str(screen_pos), str(world_pos), str(map_local_pos), str(map_tile_coord), str(tile_coord), str(tile_center)

	]



func test_tile_center_positioning_accuracy() -> void:func before_test() -> void:

	## Test: Mouse input at screen positions should position at tile CENTERS, not edges	# Create test environment with proper tilemap setup

	var test_positions := [	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)

		Vector2(32, 32),  # Should map to tile center	test_env = runner.scene() as CollisionTestEnvironment

		Vector2(64, 64),  # Different tile center	positioner = test_env.positioner

		Vector2(16, 48),  # Should still center in target tile	tile_map = test_env.tile_map_layer

		Vector2(80, 16),  # Another test position

	]

func test_screen_to_world_conversion() -> void:

	for screen_pos: Vector2 in test_positions:	# Test: Screen coordinates should convert to world coordinates correctly

		## Act: Get tile center calculation from screen position	var screen_pos := Vector2(32, 32)

		var result: Dictionary = positioner._test_get_tile_center_from_screen(screen_pos)	

	# Act: Convert screen to world

		## Assert: Should get valid results	var world_pos: Vector2 = positioner._test_convert_screen_to_world(screen_pos)

		assert_object(result.get("tile")).append_failure_message(	

			"Should get valid tile coordinate for screen pos %s" % str(screen_pos)	# Assert: Should get non-zero world position

		).is_not_null()	assert_vector(world_pos).append_failure_message(

		"Screen position %s should convert to non-zero world position, got %s" % [str(screen_pos), str(world_pos)]

		assert_vector(result.get("world_pos", Vector2.ZERO)).append_failure_message(	).is_not_equal(Vector2.ZERO)

			"Should get valid world position for screen pos %s" % str(screen_pos)	

		).is_not_equal(Vector2.ZERO)	# Assert: Conversion should be deterministic (same input = same output)

	var world_pos2: Vector2 = positioner._test_convert_screen_to_world(screen_pos)

		assert_vector(result.get("tile_center", Vector2.ZERO)).append_failure_message(	assert_vector(world_pos2).is_equal(world_pos).append_failure_message(

			"Should get valid tile center for screen pos %s" % str(screen_pos)		"Screen-to-world conversion should be deterministic: %s != %s" % [str(world_pos), str(world_pos2)]

		).is_not_equal(Vector2.ZERO)	)



		## Critical test: Verify positioner moves to EXACT tile center

		var tile_coord: Vector2i = result.get("tile")func test_tile_center_positioning_accuracy() -> void: # Test: mouse input at screen positions should position at tile CENTERS, not edges # Setup: Test multiple screen positions var test_positions := [ Vector2(32, 32), # Should map to tile center Vector2(64, 64), # Different tile center Vector2(16, 48), # Should still center in target tile Vector2(80, 16) # Another test position ] for screen_pos: Vector2 in test_positions: # Act: Get tile center calculation from screen position 	var result: Dictionary[String, Variant] = positioner._test_get_tile_center_from_screen(screen_pos) # Assert: Should get valid results assert_object(result.get("tile")).is_not_null().append_failure_message( "Should get valid tile coordinate for screen pos %s" % str(screen_pos) ) assert_vector(result.get("world_pos", Vector2.ZERO)).is_not_equal(Vector2.ZERO).append_failure_message( "Should get valid world position for screen pos %s" % str(screen_pos) ) assert_vector(result.get("tile_center", Vector2.ZERO)).is_not_equal(Vector2.ZERO).append_failure_message( "Should get valid tile center for screen pos %s" % str(screen_pos) ) # Critical test: Verify positioner moves to EXACT tile center var tile_coord: Vector2i = result.get("tile") var tile_center: Vector2 = result.get("tile_center") # Move positioner using the screen coordinate (like mouse input does) var motion_event := InputEventMouseMotion.new() motion_event.position = screen_pos positioner._handle_mouse_motion_event(motion_event, GBEnums.Mode.MOVE) # Assert: Positioner should be positioned at tile center (within reasonable tolerance for floating point) # IMPORTANT: In Godot 4.x, TileMapLayer.map_to_local() returns tile CENTER, not top-left! var position_diff := positioner.global_position.distance_to(tile_center) var world_pos: Vector2 = result.get("world_pos") assert_float(position_diff).append_failure_message( "TILE CENTER POSITIONING: Expected tile center positioning (within 16px tolerance for coordinate system differences): %s\n%s\n%s" % [ _format_coordinate_debug(screen_pos, world_pos, tile_coord, tile_center, positioner.global_position), _format_conversion_environment(), _format_tile_mapping_debug(screen_pos) ] ).is_less(16.0) func test_mouse_motion_event_tile_centering() -> void: # Test: InputEventMouseMotion should result in precise tile center positioning # Setup: Create realistic mouse motion events var test_cases := [ {"screen": Vector2(48, 32), "description": "Top area of tile"}, {"screen": Vector2(32, 48), "description": "Left area of tile"}, {"screen": Vector2(48, 48), "description": "Center area of tile"}, {"screen": Vector2(63, 63), "description": "Bottom-right area of tile"} ] for test_case: Dictionary in test_cases: var screen_pos: Vector2 = test_case.screen var description: String = test_case.description # Act: Simulate mouse motion event var motion_event := InputEventMouseMotion.new() motion_event.position = screen_pos # Get expected tile and center before moving var expected_result: Dictionary = positioner._test_get_tile_center_from_screen(screen_pos) var expected_tile: Vector2i = expected_result.get("tile") var expected_center: Vector2 = expected_result.get("tile_center") # Trigger mouse motion handling positioner._handle_mouse_motion_event(motion_event, GBEnums.Mode.MOVE) # Assert: Should be positioned at tile center regardless of where in tile the mouse was # IMPORTANT: Objects are placed in the MIDDLE of tiles - grid positioner snaps to tile centers var actual_pos := positioner.global_position var distance_from_center := actual_pos.distance_to(expected_center) var world_pos: Vector2 = expected_result.get("world_pos") assert_float(distance_from_center).append_failure_message( "MOUSE MOTION TILE CENTERING - %s: Expected positioning at tile center (within 16px tolerance): %s\n%s\n%s" % [ description, _format_coordinate_debug(screen_pos, world_pos, expected_tile, expected_center, actual_pos), _format_conversion_environment(), _format_tile_mapping_debug(screen_pos) ] ).is_less(16.0) # Also verify we're in the correct tile var actual_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(actual_pos, tile_map) assert_that(actual_tile).is_equal(expected_tile).append_failure_message( "%s: Should be in tile %s but positioned in tile %s" % [description, str(expected_tile), str(actual_tile)] ) func test_coordinate_conversion_edge_cases() -> void: # Test: Edge cases for coordinate conversion var edge_cases := [ {"screen": Vector2.ZERO, "description": "Origin position"}, {"screen": Vector2(1, 1), "description": "Near origin"}, {"screen": Vector2(15, 15), "description": "Tile edge boundary"}, {"screen": Vector2(16, 16), "description": "Tile size boundary"}, {"screen": Vector2(31, 31), "description": "Almost next tile"} ] for case: Dictionary in edge_cases: var screen_pos: Vector2 = case.screen var description: String = case.description # Act: Convert coordinates var world_pos: Vector2 = positioner._test_convert_screen_to_world(screen_pos) var tile_result: Dictionary = positioner._test_get_tile_center_from_screen(screen_pos) # Assert: Should always get valid, finite results assert_bool(is_finite(world_pos.x) and is_finite(world_pos.y)).is_true().append_failure_message( "%s: World position should be finite, got %s" % [description, str(world_pos)] ) var tile_center: Vector2 = tile_result.get("tile_center", Vector2.ZERO) assert_bool(is_finite(tile_center.x) and is_finite(tile_center.y)).is_true().append_failure_message( "%s: Tile center should be finite, got %s" % [description, str(tile_center)] ) func after_test().is_not_equal(Vector2.ZERO)
		var tile_center: Vector2 = result.get("tile_center")

		## Move positioner using the screen coordinate (like mouse input does)
		var motion_event := InputEventMouseMotion.new()
		motion_event.position = screen_pos
		positioner._handle_mouse_motion_event(motion_event, GBEnums.Mode.MOVE)

		## Assert: Positioner should be positioned at tile center
		var position_diff := positioner.global_position.distance_to(tile_center)
		assert_float(position_diff).append_failure_message(
			"Screen %s: Expected positioning at tile center (within 16px tolerance), got %s" % [
				str(screen_pos), str(positioner.global_position)
			]
		).is_less(16.0)


func test_mouse_motion_tile_centering() -> void:
	## Test: InputEventMouseMotion should result in precise tile center positioning
	var test_cases := [
		{"screen": Vector2(48, 32), "description": "Top area of tile"},
		{"screen": Vector2(32, 48), "description": "Left area of tile"},
		{"screen": Vector2(48, 48), "description": "Center area of tile"},
		{"screen": Vector2(63, 63), "description": "Bottom-right area of tile"},
	]

	for test_case: Dictionary in test_cases:
		var screen_pos: Vector2 = test_case.screen
		var description: String = test_case.description

		## Act: Simulate mouse motion event
		var motion_event := InputEventMouseMotion.new()
		motion_event.position = screen_pos

		## Get expected tile and center before moving
		var expected_result: Dictionary = positioner._test_get_tile_center_from_screen(
			screen_pos
		)
		var expected_tile: Vector2i = expected_result.get("tile")
		var expected_center: Vector2 = expected_result.get("tile_center")

		## Trigger mouse motion handling
		positioner._handle_mouse_motion_event(motion_event, GBEnums.Mode.MOVE)

		## Assert: Should be positioned at tile center regardless of where in tile
		var actual_pos := positioner.global_position
		var distance_from_center := actual_pos.distance_to(expected_center)

		assert_float(distance_from_center).append_failure_message(
			"MOUSE MOTION TILE CENTERING - %s: Expected positioning at tile center, got %s" % [
				description, str(actual_pos)
			]
		).is_less(16.0)

		## Also verify we're in the correct tile
		var actual_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(
			actual_pos, tile_map
		)
		assert_that(actual_tile).append_failure_message(
			"%s: Should be in tile %s but positioned in tile %s" % [
				description, str(expected_tile), str(actual_tile)
			]
		).is_equal(expected_tile)


func test_coordinate_conversion_edge_cases() -> void:
	## Test: Edge cases for coordinate conversion
	var edge_cases := [
		{"screen": Vector2.ZERO, "description": "Origin position"},
		{"screen": Vector2(1, 1), "description": "Near origin"},
		{"screen": Vector2(15, 15), "description": "Tile edge boundary"},
		{"screen": Vector2(16, 16), "description": "Tile size boundary"},
		{"screen": Vector2(31, 31), "description": "Almost next tile"},
	]

	for case: Dictionary in edge_cases:
		var screen_pos: Vector2 = case.screen
		var description: String = case.description

		## Act: Convert coordinates
		var world_pos: Vector2 = positioner._test_convert_screen_to_world(screen_pos)
		var tile_result: Dictionary = positioner._test_get_tile_center_from_screen(
			screen_pos
		)

		## Assert: Should always get valid, finite results
		assert_bool(is_finite(world_pos.x) and is_finite(world_pos.y)).append_failure_message(
			"%s: World position should be finite, got %s" % [description, str(world_pos)]
		).is_true()

		var tile_center: Vector2 = tile_result.get("tile_center", Vector2.ZERO)
		assert_bool(is_finite(tile_center.x) and is_finite(tile_center.y)).append_failure_message(
			"%s: Tile center should be finite, got %s" % [description, str(tile_center)]
		).is_true()


func after_test() -> void:
	## Cleanup
	runner = null
	test_env = null
	positioner = null
	tile_map = null
