extends GdUnitTestSuite

# Test reproducer for TileMapLayer transform affecting polygon->tile overlap
# This test constructs a square polygon in world space and computes tile offsets
# using CollisionGeometryUtils.compute_polygon_tile_offsets(). The TileMapLayer
# is placed at a non-zero position to simulate maps not centered on (0,0).

const TILE_SIZE := Vector2(16, 16)


func before_test() -> void:
	# nothing special to create globally for now
	pass


func test_tilemap_offset_affects_tile_overlap() -> void:
	# Create a properly configured TileMapLayer and offset it
	var tile_map: TileMapLayer = TileMapLayer.new()
	tile_map.name = "TestTileMap"
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_map.tile_set = tile_set
	auto_free(tile_map)
	add_child(tile_map)
	# Position the tilemap at a non-zero global offset to reproduce coordinate mismatch
	tile_map.position = Vector2(24, 10)

	# Build a rectangle polygon in world coordinates centered near tile (0,0)
	# Rectangle size: 48 x 64 (same as failing integration test)
	var rect_size := Vector2(48, 64)
	var rect_half := rect_size * 0.5

	# Place the rect so its center is at world origin (0,0)
	var world_center := Vector2.ZERO
	var world_points := [
		world_center + Vector2(-rect_half.x, -rect_half.y),
		world_center + Vector2(rect_half.x, -rect_half.y),
		world_center + Vector2(rect_half.x, rect_half.y),
		world_center + Vector2(-rect_half.x, rect_half.y),
	]

	# Compute center_tile as the tile that contains the positioner (here at world_center)
	# Use TileMap methods to convert: local_to_map expects coordinates in tile_map local space
	var center_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(world_center))

	# Call the existing helper to compute tile offsets. We pass the tile_map so
	# that implementations which accept it can consider its transform. The current
	# implementation may ignore it and produce an incorrect result when tile_map
	# is offset — this test will catch that.
	var offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		world_points, TILE_SIZE, center_tile, tile_map.tile_set.tile_shape, tile_map
	)

	# Offsets expected for a 48x64 rectangle centered at tile (0,0):
	# The integration test expected tiles: [(-1, -1), (0, -1), (1, -1), (-1, 0), (0,0), (1,0), (-1,1), (0,1), (1,1), (-1,2), (0,2), (1,2)]
	# We'll assert that at least the central 3x3 block exists (covers the main area).
	var expected_core: Array[Vector2i] = [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(-1, 0),
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
		Vector2i(1, 1)
	]

	# Convert returned offsets to a set for easy membership checking
	var offsets_set: Dictionary[Vector2i, bool] = {}
	for i in offsets:
		var off: Vector2i = i
		offsets_set[off] = true

	# Use helper to produce diagnostic message and assert missing tiles in one check
	var missing := _get_missing_expected_tiles(expected_core, offsets_set)
	var diag := _format_diagnostic(
		expected_core, offsets, missing, tile_map, world_center, center_tile
	)
	assert_bool(missing.size() == 0).append_failure_message(diag).is_true()

	# Clean up
	tile_map.queue_free()


## Helper - returns an Array[Vector2i] of expected tiles not present in the offsets_set
func _get_missing_expected_tiles(
	expected: Array[Vector2i], offsets_set: Dictionary
) -> Array[Vector2i]:
	var missing: Array[Vector2i] = []
	for ex in expected:
		var e: Vector2i = ex
		if not offsets_set.has(e):
			missing.append(e)
	return missing


## Helper - format a verbose diagnostic message for failures
func _format_diagnostic(
	expected: Array[Vector2i],
	offsets: Array[Vector2i],
	missing: Array[Vector2i],
	map_layer: TileMapLayer,
	world_center: Vector2,
	center_tile: Vector2i
) -> String:
	var s := (
		"Expected tiles: %s\nActual offsets (%d): %s\nMissing tiles (%d): %s\nTileMap position: %s\nWorld center: %s\nComputed center_tile: %s"
		% [
			str(expected),
			offsets.size(),
			str(offsets),
			missing.size(),
			str(missing),
			str(map_layer.position),
			str(world_center),
			str(center_tile)
		]
	)
	return s
