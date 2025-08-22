## Tests verifying minimum overlap (epsilon ratio) filtering for polygon -> tile mapping.
extends GdUnitTestSuite

func test_polygon_below_threshold_excluded():
	# 16x16 tile => area 256. 5% threshold => 12.8. Use a 2x2 square (area=4) entirely inside one tile corner.
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(0,0), Vector2(2,0), Vector2(2,2), Vector2(0,2)
	])
	var tiles = CollisionGeometryCalculator.calculate_tile_overlap(poly, Vector2(16,16), GBEnums.TileType.SQUARE as GBEnums.TileType, 0.01, 0.05)
	assert_int(tiles.size()).override_failure_message("Expected no tiles for area 4 (<5% of 256)").is_equal(0)

func test_polygon_just_above_threshold_included():
	# Need area > 12.8. Use 4x4 square (area=16) so clearly above.
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(0,0), Vector2(4,0), Vector2(4,4), Vector2(0,4)
	])
	var tiles = CollisionGeometryCalculator.calculate_tile_overlap(poly, Vector2(16,16), GBEnums.TileType.SQUARE as GBEnums.TileType, 0.01, 0.05)
	assert_int(tiles.size()).override_failure_message("Expected exactly 1 tile for area 16 (>5%% threshold) tiles=" + str(tiles)).is_equal(1)

func test_concave_polygon_void_not_filled():
	# Simple concave poly shaped like a C around center void
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(0,0), Vector2(12,0), Vector2(12,4), Vector2(4,4), Vector2(4,12), Vector2(12,12), Vector2(12,16), Vector2(0,16)
	])
	# This polygon wraps around a 8x8 void (approx) – ensure we don't mark full 16x16 coverage
	var tiles = CollisionGeometryCalculator.calculate_tile_overlap(poly, Vector2(16,16), GBEnums.TileType.SQUARE as GBEnums.TileType, 0.01, 0.05)
	# Expect at least 1 tile but NOT additional phantom tiles (range still 1 tile). Ensures no expansion heuristic filled void.
	assert_int(tiles.size()).is_less_equal(1)
