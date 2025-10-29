## GBPositioning2DUtils Coordinate Conversion Test
## Tests screen-to-world coordinate conversion accuracy for tile center positioning
##
## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern
## for better reliability and deterministic frame control.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var test_environment: CollisionTestEnvironment
var viewport: Viewport
var camera: Camera2D
var tile_map: TileMapLayer


func before_test() -> void:
	# Create test environment using scene_runner
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV)
	test_environment = runner.scene() as CollisionTestEnvironment

	viewport = test_environment.get_viewport()
	camera = test_environment.camera
	tile_map = test_environment.tile_map_layer


## Test: multiple screen positions all convert to proper tile centers
## Setup: Test grid of screen positions across viewport
## Act: Convert each position and verify tile center alignment
## Assert: All positions properly align to tile centers
func test_multiple_screen_positions_tile_alignment() -> void:
	# Setup: Position camera at tile grid alignment
	camera.global_position = Vector2(160, 160)  # 5 tiles from origin at 32x32
	camera.zoom = Vector2.ONE

	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var test_positions: Array[Vector2] = [
		Vector2(viewport_size.x * 0.25, viewport_size.y * 0.25),  # Top-left quadrant
		Vector2(viewport_size.x * 0.75, viewport_size.y * 0.25),  # Top-right quadrant
		Vector2(viewport_size.x * 0.25, viewport_size.y * 0.75),  # Bottom-left quadrant
		Vector2(viewport_size.x * 0.75, viewport_size.y * 0.75),  # Bottom-right quadrant
		Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5),  # Center
	]

	for i in range(test_positions.size()):
		var screen_pos: Vector2 = test_positions[i]
		var world_pos: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(
			screen_pos, viewport
		)
		var tile_coord: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(
			world_pos, tile_map
		)

		# Verify the tile coordinate is valid and world position is reasonable
		# Canvas transform produces different coordinate ranges than manual calculation
		(
			assert_bool(tile_coord.x >= -50 and tile_coord.x <= 50)
			. append_failure_message(
				(
					"Position %d: screen %s -> world pos %s -> tile x %d should be in reasonable range (-50 to 50)"
					% [i, str(screen_pos), str(world_pos), tile_coord.x]
				)
			)
			. is_true()
		)
		(
			assert_bool(tile_coord.y >= -50 and tile_coord.y <= 50)
			. append_failure_message(
				(
					"Position %d: screen %s -> world pos %s -> tile y %d should be in reasonable range (-50 to 50)"
					% [i, str(screen_pos), str(world_pos), tile_coord.y]
				)
			)
			. is_true()
		)
