extends GdUnitTestSuite


# Test to debug trapezoid polygon tile coverage issue
func test_trapezoid_debug() -> void:
	# The exact trapezoid from the failing test
	var polygon_points: PackedVector2Array = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)

	# Standard 64x64 tiles
	var tile_size: Vector2 = Vector2(64, 64)
	var center_tile: Vector2i = Vector2i(0, 0)  # Positioned at origin

	# Collect detailed diagnostic information for failure messages
	var details: String = "=== TRAPEZOID DEBUG ===\n"
	details += "Polygon points: " + str(polygon_points) + "\n"
	details += "Tile size: " + str(tile_size) + "\n"
	details += "Center tile: " + str(center_tile) + "\n"

	# Expected tiles based on visual inspection of trapezoid:
	# The trapezoid spans from x=-32 to x=32 (64 units) and y=-12 to y=12 (24 units)
	# This should cover tiles: (-1,-1), (0,-1), (1,-1), (-1,0), (0,0), (1,0)
	var expected_tiles: Array[Vector2i] = [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(-1, 0),
		Vector2i(0, 0),
		Vector2i(1, 0)
	]

	details += "Expected tiles: " + str(expected_tiles) + "\n"

	# Test each expected tile individually
	for expected_tile: Vector2i in expected_tiles:
		var tile_rect: Rect2 = Rect2(
			Vector2(expected_tile.x * tile_size.x, expected_tile.y * tile_size.y), tile_size
		)
		details += "Testing tile " + str(expected_tile) + " rect: " + str(tile_rect) + "\n"

		# Calculate actual overlap area
		var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(polygon_points, tile_rect)
		var tile_area: float = tile_size.x * tile_size.y
		var overlap_ratio: float = area / tile_area

		details += (
			"  Overlap area: "
			+ str(area)
			+ " / "
			+ str(tile_area)
			+ " = "
			+ str(overlap_ratio)
			+ " ("
			+ str(overlap_ratio * 100)
			+ "% )\n"
		)

		# Test with different thresholds
		var thresholds: Array[float] = [0.01, 0.05, 0.12]
		for threshold: float in thresholds:
			var passes: bool = overlap_ratio >= threshold
			details += (
				"    Threshold "
				+ str(threshold * 100)
				+ "%: "
				+ ("PASS" if passes else "FAIL")
				+ "\n"
			)

	# Now test the actual CollisionGeometryUtils function
	details += "\n=== ACTUAL FUNCTION TEST ===\n"
	var actual_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		polygon_points, tile_size, center_tile, TileSet.TILE_SHAPE_SQUARE
	)
	details += "Actual offsets from CollisionGeometryUtils: " + str(actual_offsets) + "\n"

	# Check why we're only getting 2 tiles instead of 6
	# Append all collected diagnostic details to the failure message for easy debugging
	(
		assert_int(actual_offsets.size()) \
		. append_failure_message(
			details + "Should get at least 4 tiles, got " + str(actual_offsets.size())
		) \
		. is_greater_equal(4)
	)
