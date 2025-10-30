extends GdUnitTestSuite

## Consolidated Collision and Rules Test Suite
## Consolidates: collision_geometry_calculator_test.gd, collision_geometry_calculator_debug_test.gd,
## collisions_check_rule_test.gd, tile_check_rule_test.gd, collision_mapper_test.gd components

## MARK FOR REMOVAL - collision_geometry_calculator_test.gd, collision_geometry_calculator_debug_test.gd,
## test_collisions_check_rule.gd, tile_check_rule_test.gd

# Test Constants
const STANDARD_TILE_SIZE: Vector2 = Vector2(16, 16)
const SINGLE_POINT_POS: Vector2 = Vector2(8, 8)
const LARGE_RECTANGLE_SIZE: Vector2 = Vector2(32, 32)
const TEST_ORIGIN: Vector2 = Vector2(0, 0)
const TEST_ORIGIN_TILE: Vector2i = Vector2i(0, 0)
const TILE_1_0: Vector2i = Vector2i(1, 0)
const TILE_0_1: Vector2i = Vector2i(0, 1)
const TILE_1_1: Vector2i = Vector2i(1, 1)
const EXPECTED_2X2_TILE_COUNT: int = 4
const EDGE_CASE_SIZE: float = 0.1
const EDGE_CASE_TOLERANCE: float = 0.01
const LINE_SEGMENT_LENGTH: float = 10.0
const BOUNDARY_POINT_POS: Vector2 = Vector2(15.9, 15.9)
const BOUNDARY_TOLERANCE: Vector2 = Vector2(0.01, 0.01)

# 16x16 tile shape coordinates - defined as static helper functions
static func get_tile_shape_16x16() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])


static func get_separated_shape_16x16() -> PackedVector2Array:
	return PackedVector2Array([Vector2(32, 32), Vector2(48, 32), Vector2(48, 48), Vector2(32, 48)])


static func get_overlapping_shape_16x16() -> PackedVector2Array:
	return PackedVector2Array([Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)])


# ===== COLLISION GEOMETRY CALCULATOR TESTS =====


func test_collision_calculator_tile_overlap_empty() -> void:
	var empty_polygon: PackedVector2Array = PackedVector2Array()
	var tile_size: Vector2 = STANDARD_TILE_SIZE
	var map := EnvironmentTestFactory.create_buildable_tilemap(self)

	# Use shared test tile map layer to ensure consistent map-aware calculations
	var test_tile_map_layer: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	var overlapped_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		empty_polygon, tile_size, TileSet.TILE_SHAPE_SQUARE, map
	)

	(
		assert_array(overlapped_tiles) \
		. append_failure_message("Empty polygon should produce no overlapped tiles") \
		. is_empty()
	)


func test_collision_calculator_single_point() -> void:
	var single_point: PackedVector2Array = PackedVector2Array([SINGLE_POINT_POS])
	var tile_size: Vector2 = STANDARD_TILE_SIZE
	var map := EnvironmentTestFactory.create_buildable_tilemap(self)

	var test_tile_map_layer: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	var overlapped_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		single_point, tile_size, TileSet.TILE_SHAPE_SQUARE, map
	)

	(
		assert_int(overlapped_tiles.size()) \
		. append_failure_message("Single point cannot form valid polygon (need 3+ vertices)") \
		. is_equal(0)
	)


func test_collision_calculator_rectangle_overlap() -> void:
	var rectangle: PackedVector2Array = PackedVector2Array(
		[
			TEST_ORIGIN,
			Vector2(LARGE_RECTANGLE_SIZE.x, 0),
			LARGE_RECTANGLE_SIZE,
			Vector2(0, LARGE_RECTANGLE_SIZE.y)
		]
	)
	var tile_size: Vector2 = STANDARD_TILE_SIZE

	var map := EnvironmentTestFactory.create_buildable_tilemap(self)
	var overlapped_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		rectangle, tile_size, TileSet.TILE_SHAPE_SQUARE, map
	)

	(
		assert_int(overlapped_tiles.size()) \
		. append_failure_message(
			"32x32 rectangle should overlap 4 tiles (2x2), got %d" % overlapped_tiles.size()
		) \
		. is_equal(4)
	)

	# Verify specific tile positions
	assert_bool(overlapped_tiles.has(TEST_ORIGIN_TILE)).is_true()
	assert_bool(overlapped_tiles.has(TILE_1_0)).is_true()
	assert_bool(overlapped_tiles.has(TILE_0_1)).is_true()
	assert_bool(overlapped_tiles.has(TILE_1_1)).is_true()


func test_collision_detection_no_collision() -> void:
	var shape1: PackedVector2Array = get_tile_shape_16x16()
	var shape2: PackedVector2Array = get_separated_shape_16x16()

	var collision: bool = CollisionGeometryCalculator.detect_collisions(shape1, shape2)

	(
		assert_bool(collision) \
		. append_failure_message("Separated rectangles should not collide") \
		. is_false()
	)


func test_collision_detection_with_collision() -> void:
	var shape1: PackedVector2Array = get_tile_shape_16x16()
	var shape2: PackedVector2Array = get_overlapping_shape_16x16()

	var collision: bool = CollisionGeometryCalculator.detect_collisions(shape1, shape2)

	assert_bool(collision).append_failure_message("Overlapping rectangles should collide").is_true()


# ===== POLYGON BOUNDS TESTS =====


func test_get_polygon_bounds_empty() -> void:
	var empty_polygon: PackedVector2Array = PackedVector2Array()
	var bounds: Rect2 = CollisionGeometryCalculator._get_polygon_bounds(empty_polygon)

	assert_vector(bounds.position).is_equal(Vector2.ZERO)
	assert_vector(bounds.size).is_equal(Vector2.ZERO)


func test_get_polygon_bounds_single_point() -> void:
	var single_point: PackedVector2Array = PackedVector2Array([Vector2(5, 5)])
	var bounds: Rect2 = CollisionGeometryCalculator._get_polygon_bounds(single_point)

	(
		assert_vector(bounds.position) \
		. append_failure_message("Single point bounds position should be the point itself") \
		. is_equal(Vector2(5, 5))
	)


func test_get_polygon_bounds_rectangle() -> void:
	var rectangle: PackedVector2Array = PackedVector2Array(
		[Vector2(1, 2), Vector2(5, 2), Vector2(5, 6), Vector2(1, 6)]
	)
	var bounds: Rect2 = CollisionGeometryCalculator._get_polygon_bounds(rectangle)

	(
		assert_vector(bounds.position) \
		. append_failure_message("Rectangle bounds position should be top-left corner") \
		. is_equal(Vector2(1, 2))
	)
	(
		assert_vector(bounds.size) \
		. append_failure_message("Rectangle bounds size should be width x height") \
		. is_equal(Vector2(4, 4))
	)


# ===== POLYGON OVERLAP TESTS =====


func test_polygon_overlaps_rect_no_overlap() -> void:
	var polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(32, 32), Vector2(48, 32), Vector2(48, 48), Vector2(32, 48)]
	)
	var rect: Rect2 = Rect2(0, 0, 16, 16)

	var overlap: bool = CollisionGeometryCalculator.polygon_overlaps_rect(polygon, rect, 0.01, 0.05)

	(
		assert_bool(overlap) \
		. append_failure_message("Separated polygon and rect should not overlap") \
		. is_false()
	)


func test_polygon_overlaps_rect_with_overlap() -> void:
	var polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)]
	)
	var rect: Rect2 = Rect2(0, 0, 16, 16)

	var overlap: bool = CollisionGeometryCalculator.polygon_overlaps_rect(polygon, rect, 0.01, 0.05)

	(
		assert_bool(overlap) \
		. append_failure_message("Overlapping polygon and rect should overlap") \
		. is_true()
	)


# ===== POINT IN POLYGON TESTS =====


func test_point_in_polygon_inside() -> void:
	var polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]
	)
	var point: Vector2 = Vector2(5, 5)

	var inside: bool = CollisionGeometryCalculator.point_in_polygon(point, polygon)

	(
		assert_bool(inside) \
		. append_failure_message("Point (5,5) should be inside rectangle (0,0)-(10,10)") \
		. is_true()
	)


func test_point_in_polygon_outside() -> void:
	var polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]
	)
	var point: Vector2 = Vector2(15, 15)

	var inside: bool = CollisionGeometryCalculator.point_in_polygon(point, polygon)

	(
		assert_bool(inside) \
		. append_failure_message("Point (15,15) should be outside rectangle (0,0)-(10,10)") \
		. is_false()
	)


# ===== LINE INTERSECTION TESTS =====


func test_lines_intersect_crossing() -> void:
	var line1_start: Vector2 = Vector2(0, 0)
	var line1_end: Vector2 = Vector2(10, 10)
	var line2_start: Vector2 = Vector2(0, 10)
	var line2_end: Vector2 = Vector2(10, 0)

	var intersection: bool = CollisionGeometryCalculator._lines_intersect(
		line1_start, line1_end, line2_start, line2_end
	)

	(
		assert_bool(intersection) \
		. append_failure_message("Perpendicular crossing lines should intersect") \
		. is_true()
	)


func test_lines_intersect_parallel() -> void:
	var line1_start: Vector2 = Vector2(0, 0)
	var line1_end: Vector2 = Vector2(10, 0)
	var line2_start: Vector2 = Vector2(0, 5)
	var line2_end: Vector2 = Vector2(10, 5)

	var intersection: bool = CollisionGeometryCalculator._lines_intersect(
		line1_start, line1_end, line2_start, line2_end
	)

	(
		assert_bool(intersection) \
		. append_failure_message("Parallel lines should not intersect") \
		. is_false()
	)


# ===== POLYGON INTERSECTION TESTS =====


func test_polygons_intersect_overlapping() -> void:
	var poly1: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]
	)
	var poly2: PackedVector2Array = PackedVector2Array(
		[Vector2(5, 5), Vector2(15, 5), Vector2(15, 15), Vector2(5, 15)]
	)

	var intersection: bool = CollisionGeometryCalculator._polygons_intersect(poly1, poly2, 0.01)

	(
		assert_bool(intersection) \
		. append_failure_message("Overlapping rectangles should intersect") \
		. is_true()
	)


func test_polygons_intersect_separate() -> void:
	var poly1: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]
	)
	var poly2: PackedVector2Array = PackedVector2Array(
		[Vector2(20, 20), Vector2(30, 20), Vector2(30, 30), Vector2(20, 30)]
	)

	var intersection: bool = CollisionGeometryCalculator._polygons_intersect(poly1, poly2, 0.01)

	(
		assert_bool(intersection) \
		. append_failure_message("Separated rectangles should not intersect") \
		. is_false()
	)


# ===== DEBUG EDGE CASE TESTS =====


func test_debug_edge_case_tiny_polygon() -> void:
	var tiny_polygon: PackedVector2Array = PackedVector2Array(
		[
			TEST_ORIGIN,
			Vector2(EDGE_CASE_SIZE, 0),
			Vector2(EDGE_CASE_SIZE, EDGE_CASE_SIZE),
			Vector2(0, EDGE_CASE_SIZE)
		]
	)
	var bounds: Rect2 = CollisionGeometryCalculator._get_polygon_bounds(tiny_polygon)

	(
		assert_float(bounds.size.x) \
		. append_failure_message("Tiny polygon should have measurable width") \
		. is_equal_approx(EDGE_CASE_SIZE, EDGE_CASE_TOLERANCE)
	)
	(
		assert_float(bounds.size.y) \
		. append_failure_message("Tiny polygon should have measurable height") \
		. is_equal_approx(EDGE_CASE_SIZE, EDGE_CASE_TOLERANCE)
	)


func test_debug_edge_case_degenerate_shapes() -> void:
	# Test line segment (degenerate polygon)
	var line_segment: PackedVector2Array = PackedVector2Array(
		[TEST_ORIGIN, Vector2(LINE_SEGMENT_LENGTH, 0)]
	)
	var line_bounds: Rect2 = CollisionGeometryCalculator._get_polygon_bounds(line_segment)

	assert_float(line_bounds.size.x).is_equal(LINE_SEGMENT_LENGTH)
	assert_float(line_bounds.size.y).is_equal(0.0)

	# Test single point boundary
	var boundary_point: PackedVector2Array = PackedVector2Array([BOUNDARY_POINT_POS])
	var point_bounds: Rect2 = CollisionGeometryCalculator._get_polygon_bounds(boundary_point)

	assert_vector(point_bounds.position).is_equal_approx(BOUNDARY_POINT_POS, BOUNDARY_TOLERANCE)


# ===== COLLISION RULES TESTS =====


func test_collisions_check_rule_validation() -> void:
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()

	# Test validation before setup (should fail)
	var pre_setup_result: RuleResult = rule.validate_placement()
	assert_object(pre_setup_result).is_not_null()
	(
		assert_bool(pre_setup_result.is_successful()) \
		. append_failure_message("Collision rule should fail validation before setup") \
		. is_false()
	)
