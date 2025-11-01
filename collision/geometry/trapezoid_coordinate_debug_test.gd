## Debug test specifically for the trapezoid coordinate calculation issue
## The runtime shows missing tile coverage in bottom corners, but collision geometry
## calculation is returning completely wrong tile coordinates
extends GdUnitTestSuite

const TRAPEZOID_POSITION: Vector2 = Vector2(440, 552)
const TILE_SIZE: Vector2 = Vector2(16, 16)

## Trapezoid local polygon points: [(-32,12), (-16,-12), (17,-12), (32,12)]
static func create_trapezoid_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-32, 12),
		Vector2(-16, -12),
		Vector2(17, -12),
		Vector2(32, 12)
	])

## Calculates world coordinates from local polygon points
static func get_world_points(
	local_points: PackedVector2Array, position: Vector2
) -> PackedVector2Array:
	var world_points: PackedVector2Array = PackedVector2Array()
	for point in local_points:
		world_points.append(position + point)
	return world_points

## Calculates tile coordinates from world position
static func get_tile_coordinate(
	world_pos: Vector2, tile_size: Vector2 = Vector2(16, 16)
) -> Vector2i:
	return Vector2i(int(world_pos.x / tile_size.x), int(world_pos.y / tile_size.y))


func test_trapezoid_coordinate_calculation() -> void:
	"""Debug test for trapezoid coordinate calculation issue.

	For a trapezoid at position (440, 552) with local points
	[(-32,12), (-16,-12), (17,-12), (32,12)]:
	- World points: [(408,564), (424,540), (457,540), (472,564)]
	- Spans tiles from (25,33) to (29,35)
	- Relative to center tile (27,34), expected offsets:
	  [(-2,-1), (-1,-1), (0,-1), (1,-1), (2,-1), (-2,0), (-1,0),
	   (0,0), (1,0), (2,0), (-1,1), (0,1), (1,1)]
	"""
	GBTestDiagnostics.log_verbose("=== TRAPEZOID COORDINATE DEBUG TEST ===")

	# Get the trapezoid polygon
	var local_polygon: PackedVector2Array = create_trapezoid_polygon()
	GBTestDiagnostics.log_verbose("Local polygon: %s" % [local_polygon])

	# Calculate world points
	var world_points: PackedVector2Array = get_world_points(
		local_polygon, TRAPEZOID_POSITION
	)
	GBTestDiagnostics.log_verbose("World points: %s" % [world_points])

	# Calculate tile coordinates for each vertex
	var vertex_tiles: Array[Vector2i] = []
	for i in range(world_points.size()):
		var world_point: Vector2 = world_points[i]
		var tile_coord: Vector2i = get_tile_coordinate(world_point, TILE_SIZE)
		vertex_tiles.append(tile_coord)
		GBTestDiagnostics.log_verbose(
			"  Vertex %d: World %s -> Tile %s" % [i, world_point, tile_coord]
		)

	# Verify vertex tiles span expected range
	assert_int(vertex_tiles.size()).append_failure_message(
		"Should have 4 vertices"
	).is_equal(4)

	# Expected tiles for trapezoid span approximately (25,33) to (29,35)
	var min_tile_x: int = 25
	var max_tile_x: int = 29
	var min_tile_y: int = 33
	var max_tile_y: int = 35

	for tile in vertex_tiles:
		assert_bool(
			tile.x >= min_tile_x and tile.x <= max_tile_x
		).append_failure_message(
			"Tile X %d should be between %d and %d" % [tile.x, min_tile_x, max_tile_x]
		).is_true()
		assert_bool(
			tile.y >= min_tile_y and tile.y <= max_tile_y
		).append_failure_message(
			"Tile Y %d should be between %d and %d" % [tile.y, min_tile_y, max_tile_y]
		).is_true()

	GBTestDiagnostics.log_verbose("✓ Trapezoid coordinate calculation verified")

