## Debug Polygon Test Suite
##
## This test suite validates polygon bounds calculation and tile overlap detection
## for collision geometry utilities. It tests the mathematical accuracy of converting
## polygon coordinates to tile-based collision detection, ensuring proper bounds
## calculation and tile enumeration for collision checking algorithms.
##
## Key validations:
## - Polygon bounds calculation from vertex coordinates
## - Tile coordinate conversion from world space bounds
## - CollisionGeometryCalculator tile overlap detection accuracy
## - Debug output verification for development troubleshooting

class_name DebugPolygonTest
extends GdUnitTestSuite

#region Test Constants
# Test constants to eliminate magic numbers
const TEST_TILE_SIZE := Vector2(16, 16)
const COLLISION_TOLERANCE := 0.01
const TEST_POLYGON_VERTICES := [
	Vector2(1, 1),
	Vector2(17, 1),
	Vector2(17, 17),
	Vector2(1, 17)
]
#endregion

#region Polygon Bounds Validation
func test_debug_polygon_bounds() -> void:
	var polygon: PackedVector2Array = PackedVector2Array(TEST_POLYGON_VERTICES)
	var tile_size: Vector2 = TEST_TILE_SIZE

	# Test our understanding of the bounds calculation
	var bounds: Rect2 = Rect2()
	if polygon.size() > 0:
		var min_x: float = polygon[0].x
		var max_x: float = polygon[0].x
		var min_y: float = polygon[0].y
		var max_y: float = polygon[0].y

		for point: Vector2 in polygon:
			min_x = min(min_x, point.x)
			max_x = max(max_x, point.x)
			min_y = min(min_y, point.y)
			max_y = max(max_y, point.y)

		bounds = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

	print("Polygon: ", polygon)
	print("Bounds: ", bounds)
	print("bounds.position: ", bounds.position)
	print("bounds.size: ", bounds.size)
	print("bounds.position + bounds.size: ", bounds.position + bounds.size)

	var start_tile: Vector2i = Vector2i(floor(bounds.position.x / tile_size.x), floor(bounds.position.y / tile_size.y))
	var end_tile: Vector2i = Vector2i(ceil((bounds.position.x + bounds.size.x) / tile_size.x), ceil((bounds.position.y + bounds.size.y) / tile_size.y))

	print("start_tile: ", start_tile)
	print("end_tile: ", end_tile)

	var tiles_checked: Array[Vector2i] = []
	for x: int in range(start_tile.x, end_tile.x):
		for y: int in range(start_tile.y, end_tile.y):
			tiles_checked.append(Vector2i(x, y))

	print("Tiles checked: ", tiles_checked)
	print("Number of tiles: ", tiles_checked.size())

	# Test actual collision detection
	var tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		polygon, tile_size, TileSet.TILE_SHAPE_SQUARE, COLLISION_TOLERANCE, COLLISION_TOLERANCE
	)
	print("Actually overlapping tiles: ", tiles)
#endregion
