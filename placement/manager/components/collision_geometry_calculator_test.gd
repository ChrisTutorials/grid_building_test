## Test suite for CollisionGeometryCalculator pure logic class.
## Tests pure functions without complex object setup.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

func test_calculate_tile_overlap_empty_polygon() -> void:
	var empty_polygon = PackedVector2Array()
	var tile_size = Vector2(16, 16)
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		empty_polygon, tile_size, GBEnums.TileType.SQUARE
	)
	
	assert_array(overlapped_tiles).is_empty()

func test_calculate_tile_overlap_single_point() -> void:
	var single_point = PackedVector2Array([Vector2(8, 8)])
	var tile_size = Vector2(16, 16)
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		single_point, tile_size, GBEnums.TileType.SQUARE
	)
	
	assert_int(overlapped_tiles.size()).is_equal(1)
	assert_vector(overlapped_tiles[0]).is_equal(Vector2i(0, 0))

func test_calculate_tile_overlap_rectangle() -> void:
	var rectangle = PackedVector2Array([
		Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)
	])
	var tile_size = Vector2(16, 16)
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		rectangle, tile_size, GBEnums.TileType.SQUARE
	)
	
	assert_int(overlapped_tiles.size()).is_equal(4)  # 2x2 tiles
	assert_bool(overlapped_tiles.has(Vector2i(0, 0))).is_true()
	assert_bool(overlapped_tiles.has(Vector2i(1, 0))).is_true()
	assert_bool(overlapped_tiles.has(Vector2i(0, 1))).is_true()
	assert_bool(overlapped_tiles.has(Vector2i(1, 1))).is_true()

func test_detect_collisions_no_collision() -> void:
	var shape1 = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)
	])
	var shape2 = PackedVector2Array([
		Vector2(32, 32), Vector2(48, 32), Vector2(48, 48), Vector2(32, 48)
	])
	
	var collision = CollisionGeometryCalculator.detect_collisions(shape1, shape2)
	
	assert_bool(collision).is_false()

func test_detect_collisions_with_collision() -> void:
	var shape1 = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)
	])
	var shape2 = PackedVector2Array([
		Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)
	])
	
	var collision = CollisionGeometryCalculator.detect_collisions(shape1, shape2)
	
	assert_bool(collision).is_true()

func test_get_polygon_bounds_empty() -> void:
	var empty_polygon = PackedVector2Array()
	
	var bounds : Rect2 = CollisionGeometryCalculator._get_polygon_bounds(empty_polygon)
	assert_vector(bounds.position).is_equal(Vector2.ZERO)
	assert_vector(bounds.size).is_equal(Vector2.ZERO)

func test_get_polygon_bounds_single_point() -> void:
	var single_point = PackedVector2Array([Vector2(5, 5)])
	
	var bounds : Rect2 = CollisionGeometryCalculator._get_polygon_bounds(single_point)
	assert_vector(bounds.position).is_equal(Vector2(5, 5))

func test_get_polygon_bounds_rectangle() -> void:
	var rectangle = PackedVector2Array([
		Vector2(1, 2), Vector2(5, 2), Vector2(5, 6), Vector2(1, 6)
	])
	
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(rectangle)
	assert_vector(bounds.position).is_equal(Vector2(1, 2))
	assert_vector(bounds.size).is_equal(Vector2(4, 4))

func test_polygon_overlaps_rect_no_overlap() -> void:
	var polygon = PackedVector2Array([
		Vector2(32, 32), Vector2(48, 32), Vector2(48, 48), Vector2(32, 48)
	])
	var rect = Rect2(Vector2(0, 0), Vector2(16, 16))
	
	var overlap = CollisionGeometryCalculator._polygon_overlaps_rect(polygon, rect, 0.01)
	
	assert_bool(overlap).is_false()

func test_polygon_overlaps_rect_with_overlap() -> void:
	var polygon = PackedVector2Array([
		Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)
	])
	var rect = Rect2(Vector2(0, 0), Vector2(16, 16))
	
	var overlap = CollisionGeometryCalculator._polygon_overlaps_rect(polygon, rect, 0.01)
	
	assert_bool(overlap).is_true()

func test_point_in_polygon_inside() -> void:
	var polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)
	])
	var point = Vector2(8, 8)
	
	var inside = CollisionGeometryCalculator._point_in_polygon(point, polygon)
	
	assert_bool(inside).is_true()

func test_point_in_polygon_outside() -> void:
	var polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)
	])
	var point = Vector2(32, 32)
	
	var inside = CollisionGeometryCalculator._point_in_polygon(point, polygon)
	
	assert_bool(inside).is_false()

func test_lines_intersect_no_intersection() -> void:
	var line1_start = Vector2(0, 0)
	var line1_end = Vector2(16, 0)
	var line2_start = Vector2(0, 32)
	var line2_end = Vector2(16, 32)
	
	var intersection = CollisionGeometryCalculator._lines_intersect(line1_start, line1_end, line2_start, line2_end)
	
	assert_bool(intersection).is_false()

func test_lines_intersect_with_intersection() -> void:
	var line1_start = Vector2(0, 0)
	var line1_end = Vector2(16, 16)
	var line2_start = Vector2(0, 16)
	var line2_end = Vector2(16, 0)
	
	var intersection = CollisionGeometryCalculator._lines_intersect(line1_start, line1_end, line2_start, line2_end)
	
	assert_bool(intersection).is_true()

func test_polygons_intersect_no_intersection() -> void:
	var poly1 = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)
	])
	var poly2 = PackedVector2Array([
		Vector2(32, 32), Vector2(48, 32), Vector2(48, 48), Vector2(32, 48)
	])
	
	var intersection = CollisionGeometryCalculator._polygons_intersect(poly1, poly2, 0.01)
	
	assert_bool(intersection).is_false()

func test_polygons_intersect_with_intersection() -> void:
	var poly1 = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)
	])
	var poly2 = PackedVector2Array([
		Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)
	])
	
	var intersection = CollisionGeometryCalculator._polygons_intersect(poly1, poly2, 0.01)
	
	assert_bool(intersection).is_true()
