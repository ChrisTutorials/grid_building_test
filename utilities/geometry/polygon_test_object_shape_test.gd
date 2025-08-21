## Tests replicating the polygon from `polygon_test_object.tscn` to validate tile overlap & indicator heuristics.
extends GdUnitTestSuite

const TILE_SIZE := Vector2(16,16)

## Returns a PackedVector2Array matching the CollisionPolygon2D points inside polygon_test_object.tscn
## Scene file snippet:
## polygon = PackedVector2Array(-31, 31, -31, -31, 31, -31, 31, 31, 17, 31, 17, 15, 3, 15, 18, 0, -1, -18, -18, -18, -17, 31)
func _polygon_test_object_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-31, 31),
		Vector2(-31, -31),
		Vector2(31, -31),
		Vector2(31, 31),
		Vector2(17, 31),
		Vector2(17, 15),
		Vector2(3, 15),
		Vector2(18, 0),
		Vector2(-1, -18),
		Vector2(-18, -18),
		Vector2(-17, 31),
	])

## Helper: compute raw overlapped tile positions using pure calculator (world_points directly)
func _calc_tiles(world_points: PackedVector2Array) -> Array[Vector2i]:
	return CollisionGeometryCalculator.calculate_tile_overlap(world_points, TILE_SIZE, GBEnums.TileType.SQUARE, 0.01, 0.05)

## Helper mirroring mapper's offset computation (center tile at (0,0))
func _calc_offsets(world_points: PackedVector2Array) -> Array[Vector2i]:
	return CollisionGeometryUtils.compute_polygon_tile_offsets(world_points, TILE_SIZE, Vector2i.ZERO, GBEnums.TileType.SQUARE)

func test_polygon_test_object_basic_overlap_less_than_bounding_box():
	var pts := _polygon_test_object_points()
	var tiles := _calc_tiles(pts)
	# Derive bounding box tile coverage size
	var minx = 9999; var maxx = -9999; var miny = 9999; var maxy = -9999
	for t in tiles:
		minx = min(minx, t.x); maxx = max(maxx, t.x); miny = min(miny, t.y); maxy = max(maxy, t.y)
	var bbox_tile_count = (maxx - minx + 1) * (maxy - miny + 1)
	assert_bool(tiles.size() < bbox_tile_count).override_failure_message("Expected concave polygon to occupy fewer tiles than full bounding box. tiles=%s bbox=%d" % [tiles, bbox_tile_count]).is_true()

func test_polygon_test_object_no_trapezoid_expansion():
	var pts := _polygon_test_object_points()
	var offsets := _calc_offsets(pts)
	# The deterministic trapezoid expansion yields exactly 13 tiles (3/5/5). Ensure we did *not* get 13.
	assert_int(offsets.size()).override_failure_message("Offsets unexpectedly equal trapezoid expansion size (13). offsets=%s" % [offsets]).is_not_equal(13)
	# Also ensure offset count <= 12 (sanity upper bound under heuristic guards)
	assert_bool(offsets.size() <= 12).override_failure_message("Expected <=12 offsets for concave polygon but got %d: %s" % [offsets.size(), offsets]).is_true()

func test_polygon_test_object_stable_offsets_under_translation():
	# Translating all points by a whole-tile multiple should shift tile positions but preserve relative offset set shape
	var base := _polygon_test_object_points()
	var offsets_base := _calc_offsets(base)
	var translated: PackedVector2Array = PackedVector2Array()
	var shift := Vector2(32, 16) # 2 tiles right, 1 tile down
	for p in base: translated.append(p + shift)
	var tiles_shifted := _calc_tiles(translated)
	# Compute shape of offset set (normalize by subtracting min) for both and compare sizes
	var shape_base: Dictionary = {}
	for o in offsets_base: shape_base[str(o)] = true
	# Shift expected offsets by tile delta
	var tile_delta := Vector2i(int(shift.x / TILE_SIZE.x), int(shift.y / TILE_SIZE.y))
	var expected_shifted: Dictionary = {}
	for o in offsets_base: expected_shifted[str(o + tile_delta)] = true
	var actual_shifted: Dictionary = {}
	for t in tiles_shifted: actual_shifted[str(t)] = true
	assert_int(actual_shifted.size()).override_failure_message("Shifted tile set size mismatch expected=%d got=%d" % [expected_shifted.size(), actual_shifted.size()]).is_equal(expected_shifted.size())
