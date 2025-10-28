# -----------------------------------------------------------------------------
# Test Suite: Consolidated Geometry Tests
# -----------------------------------------------------------------------------
# This test suite consolidates multiple geometry-related test files to validate
# polygon operations, tile overlap calculations, collision geometry utilities,
# and spatial transformations. It tests intersection areas, bounds calculations,
# tile shape handling, and geometry math edge cases across different tile types.
# -----------------------------------------------------------------------------

extends GdUnitTestSuite

# Shared test TileMapLayer for tile-overlap tests
var _test_tile_map_layer: TileMapLayer = null


func before_test() -> void:
	if _test_tile_map_layer == null:
		_test_tile_map_layer = GodotTestFactory.create_empty_tile_map_layer(self)


# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const TILE_SIZE: Vector2 = Vector2(16, 16)
const TILE_SIZE_LARGE: Vector2 = Vector2(32, 32)
const OVERLAP_THRESHOLD: float = 0.01
const AREA_THRESHOLD: float = 0.05
const MIN_POLYGON_POINTS: int = 3
const MIN_AREA_THRESHOLD: float = 0.001
const POSITION_OFFSET: Vector2 = Vector2(32, 48)
const PROBLEMATIC_TILE_COORD: Vector2i = Vector2i(49, 41)
const TILE_WORLD_POS: Vector2 = Vector2(784, 656)  # 49*16, 41*16
const POSITIONER_OFFSET: Vector2 = Vector2(800, 672)
const COLLISION_POLYGON_OFFSET: Vector2 = Vector2(0, 0)

# -----------------------------------------------------------------------------
# Test Variables
# -----------------------------------------------------------------------------
var trapezoid_points: PackedVector2Array = PackedVector2Array(
	[Vector2(-16, 8), Vector2(-8, -8), Vector2(8, -8), Vector2(16, 8)]
)

# -----------------------------------------------------------------------------
# Geometry Tests
# -----------------------------------------------------------------------------
#region Geometry Tests

@warning_ignore("unused_parameter")
func test_geometry_debug_scenarios_with_tile_shapes(
	test_name: String,
	polygon_name: String,
	polygon_data: PackedVector2Array,
	tile_pos: Vector2,
	tile_shape: TileSet.TileShape,
	expected_overlap: bool,
	test_parameters := [
		# Square tile tests
		[
			"trapezoid_square",
			"trapezoid",
			PackedVector2Array(
				[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
			),
			Vector2(0, 8),
			TileSet.TILE_SHAPE_SQUARE,
			true
		],
		[
			"rectangle_square",
			"rectangle",
			PackedVector2Array(
				[Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
			),
			Vector2(0, 0),
			TileSet.TILE_SHAPE_SQUARE,
			true
		],
		[
			"triangle_square",
			"triangle",
			PackedVector2Array([Vector2(0, -20), Vector2(20, 20), Vector2(-20, 20)]),
			Vector2(0, 0),
			TileSet.TILE_SHAPE_SQUARE,
			true
		],
		[
			"small_square_square",
			"small_square",
			PackedVector2Array([Vector2(5, 5), Vector2(10, 5), Vector2(10, 10), Vector2(5, 10)]),
			Vector2(8, 8),
			TileSet.TILE_SHAPE_SQUARE,
			true
		],
		# Isometric tile tests
		[
			"trapezoid_isometric",
			"trapezoid",
			PackedVector2Array(
				[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
			),
			Vector2(0, 8),
			TileSet.TILE_SHAPE_ISOMETRIC,
			true
		],
		[
			"rectangle_isometric",
			"rectangle",
			PackedVector2Array(
				[Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
			),
			Vector2(0, 0),
			TileSet.TILE_SHAPE_ISOMETRIC,
			true
		],
		[
			"triangle_isometric",
			"triangle",
			PackedVector2Array([Vector2(0, -20), Vector2(20, 20), Vector2(-20, 20)]),
			Vector2(0, 0),
			TileSet.TILE_SHAPE_ISOMETRIC,
			true
		],
		[
			"diamond_isometric",
			"diamond",
			PackedVector2Array([Vector2(8, 0), Vector2(16, 8), Vector2(8, 16), Vector2(0, 8)]),
			Vector2(0, 0),
			TileSet.TILE_SHAPE_ISOMETRIC,
			true
		],
		# Half-offset square tile tests
		[
			"trapezoid_half_offset",
			"trapezoid",
			PackedVector2Array(
				[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
			),
			Vector2(0, 8),
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			true
		],
		[
			"rectangle_half_offset",
			"rectangle",
			PackedVector2Array(
				[Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
			),
			Vector2(0, 0),
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			true
		],
		[
			"triangle_half_offset",
			"triangle",
			PackedVector2Array([Vector2(0, -20), Vector2(20, 20), Vector2(-20, 20)]),
			Vector2(0, 0),
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			true
		],
	]
) -> void:
	var tile_size: Vector2 = GodotTestFactory.create_tile_size()

	# Calculate bounds and overlap
	var polygon_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(polygon_data)
	var intersection_area: float = GBGeometryMath.intersection_area_with_tile(
		polygon_data, tile_pos, tile_size, tile_shape
	)
	var has_overlap: bool = intersection_area > OVERLAP_THRESHOLD

	# Validate expected behavior
	(
		assert_bool(has_overlap)
		. append_failure_message(
			(
				"Geometry %s with %s tiles: expected overlap %s but got %s (area: %.4f)"
				% [
					polygon_name,
					_tile_shape_name(tile_shape),
					expected_overlap,
					has_overlap,
					intersection_area
				]
			)
		)
		. is_equal(expected_overlap)
	)

	# Validate bounds are valid
	assert_object(polygon_bounds).is_not_null()
	if polygon_data.size() > 0:
		assert_float(polygon_bounds.size.x).is_greater_equal(0.0)
		assert_float(polygon_bounds.size.y).is_greater_equal(0.0)


# Keep the original test for backward compatibility
@warning_ignore("unused_parameter")
func test_geometry_debug_scenarios(
	polygon_name: String,
	polygon_data: PackedVector2Array,
	tile_pos: Vector2,
	expected_overlap: bool,
	test_parameters := [
		[
			"trapezoid",
			PackedVector2Array(
				[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
			),
			Vector2(0, 8),
			true
		],
		[
			"rectangle",
			PackedVector2Array(
				[Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
			),
			Vector2(0, 0),
			true
		],
		[
			"triangle",
			PackedVector2Array([Vector2(0, -20), Vector2(20, 20), Vector2(-20, 20)]),
			Vector2(0, 0),
			true
		],
		[
			"small_square",
			PackedVector2Array([Vector2(5, 5), Vector2(10, 5), Vector2(10, 10), Vector2(5, 10)]),
			Vector2(8, 8),
			true
		],
		[
			"offset_triangle",
			PackedVector2Array([Vector2(100, 100), Vector2(120, 100), Vector2(110, 120)]),
			Vector2(110, 110),
			true
		]
	]
) -> void:
	var tile_size: Vector2 = GodotTestFactory.create_tile_size()

	# Calculate bounds and overlap (use square tiles for backward compatibility)
	var polygon_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(polygon_data)
	var intersection_area: float = GBGeometryMath.intersection_area_with_tile(
		polygon_data, tile_pos, tile_size, TileSet.TILE_SHAPE_SQUARE
	)
	var has_overlap: bool = intersection_area > OVERLAP_THRESHOLD

	# Validate expected behavior
	(
		assert_bool(has_overlap)
		. append_failure_message(
			(
				"Geometry %s: expected overlap %s but got %s (area: %.4f)"
				% [polygon_name, expected_overlap, has_overlap, intersection_area]
			)
		)
		. is_equal(expected_overlap)
	)

	# Validate bounds are valid
	assert_object(polygon_bounds).is_not_null()
	if polygon_data.size() > 0:
		assert_float(polygon_bounds.size.x).is_greater_equal(0.0)
		assert_float(polygon_bounds.size.y).is_greater_equal(0.0)


func _tile_shape_name(tile_shape: TileSet.TileShape) -> String:
	match tile_shape:
		TileSet.TILE_SHAPE_SQUARE:
			return "square"
		TileSet.TILE_SHAPE_ISOMETRIC:
			return "isometric"
		TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE:
			return "half_offset"
		_:
			return "unknown"


# Helper: pretty-print polygon points for diagnostics
func _format_polygon(polygon: PackedVector2Array) -> String:
	var parts: Array = []
	for p in polygon:
		# Use explicit str() to avoid format tokens which may be unsupported
		parts.append("(" + str(p.x) + ", " + str(p.y) + ")")
	var s := ""
	for j in range(parts.size()):
		s += parts[j]
		if j < parts.size() - 1:
			s += ", "
	return "[" + s + "]"


#endregion
#region Polygon Tile Overlap Threshold Tests


func test_polygon_below_threshold_excluded() -> void:
	# 16x16 tile => area 256. 5% threshold => 12.8. Use 2x2 square (area=4)
	var poly: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)]
	)
	var tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		poly,
		TILE_SIZE,
		TileSet.TILE_SHAPE_SQUARE,
		_test_tile_map_layer,
		OVERLAP_THRESHOLD,
		AREA_THRESHOLD
	)
	var tile_count: int = tiles.size()
	(
		assert_int(tile_count)
		. append_failure_message(
			"Expected no tiles for area 4 (<5%% of 256), got %d tiles" % tile_count
		)
		. is_equal(0)
	)


func test_polygon_above_threshold_included() -> void:
	# 4x4 square (area=16) > 12.8 threshold
	var poly: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)]
	)
	var tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		poly,
		TILE_SIZE,
		TileSet.TILE_SHAPE_SQUARE,
		_test_tile_map_layer,
		OVERLAP_THRESHOLD,
		AREA_THRESHOLD
	)
	var tile_count: int = tiles.size()
	(
		assert_int(tile_count)
		. append_failure_message(
			"Expected 1 tile for area 16 (>5%% threshold), got %d: %s" % [tile_count, tiles]
		)
		. is_equal(1)
	)


func test_concave_polygon_void_handling() -> void:
	# C-shaped polygon with internal void
	var poly: PackedVector2Array = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(12, 0),
			Vector2(12, 4),
			Vector2(4, 4),
			Vector2(4, 12),
			Vector2(12, 12),
			Vector2(12, 16),
			Vector2(0, 16)
		]
	)
	var tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		poly,
		TILE_SIZE,
		TileSet.TILE_SHAPE_SQUARE,
		_test_tile_map_layer,
		OVERLAP_THRESHOLD,
		AREA_THRESHOLD
	)
	# Ensure void isn't filled with phantom tiles
	assert_int(tiles.size()).is_less_equal(1)


#endregion
#region TRAPEZOID ANALYSIS TESTS


func test_trapezoid_top_left_overlap() -> void:
	# Simple trapezoid from runtime analysis
	var trapezoid: PackedVector2Array = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)
	var tile_size: Vector2 = GodotTestFactory.create_tile_size()

	# Position at runtime location
	var positioner_offset: Vector2 = POSITIONER_OFFSET
	var collision_polygon_offset: Vector2 = COLLISION_POLYGON_OFFSET

	# Transform to world coordinates
	var world_trapezoid: PackedVector2Array = PackedVector2Array()
	for point in trapezoid:
		world_trapezoid.append(positioner_offset + collision_polygon_offset + point)

	# Test problematic tile from runtime
	var problematic_tile_coord: Vector2i = PROBLEMATIC_TILE_COORD
	var tile_world_pos: Vector2 = TILE_WORLD_POS

	var epsilon: float = tile_size.x * tile_size.y * AREA_THRESHOLD
	var overlaps: bool = GBGeometryMath.does_polygon_overlap_tile_optimized(
		world_trapezoid, tile_world_pos, tile_size, TileSet.TILE_SHAPE_SQUARE, epsilon
	)

	# Validate overlap detection
	(
		assert_bool(overlaps)
		. append_failure_message(
			(
				"Trapezoid should overlap tile %s at world pos %s"
				% [str(problematic_tile_coord), str(tile_world_pos)]
			)
		)
		. is_true()
	)


func test_correct_trapezoid_geometry() -> void:
	# Test trapezoid with known geometry properties
	var local_trapezoid_points: PackedVector2Array = PackedVector2Array(
		[Vector2(-16, 8), Vector2(-8, -8), Vector2(8, -8), Vector2(16, 8)]
	)

	var bounds: Rect2 = GBGeometryMath.get_polygon_bounds(local_trapezoid_points)
	# Note: polygon_area not available in GBGeometryMath, using bounds validation instead
	var area: float = bounds.size.x * bounds.size.y  # Approximate area from bounds

	# Validate geometric properties
	(
		assert_float(bounds.size.x)
		. append_failure_message("Trapezoid width should be 32, got %.2f" % bounds.size.x)
		. is_equal(32.0)
	)
	(
		assert_float(bounds.size.y)
		. append_failure_message("Trapezoid height should be 16, got %.2f" % bounds.size.y)
		. is_equal(16.0)
	)
	assert_float(area).is_greater(0.0)


#endregion
#region POLYGON SHAPE TESTS =====

@warning_ignore("unused_parameter")
func test_polygon_shape_validation(
	shape_name: String,
	polygon_points: PackedVector2Array,
	expected_valid: bool,
	test_parameters := [
		[
			"valid_triangle",
			PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(8, 16)]),
			true
		],
		[
			"valid_rectangle",
			PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)]),
			true
		],
		["degenerate_line", PackedVector2Array([Vector2(0, 0), Vector2(16, 0)]), false],
		["single_point", PackedVector2Array([Vector2(5, 5)]), false],
		["empty_polygon", PackedVector2Array([]), false],
		[
			"self_intersecting",
			PackedVector2Array([Vector2(0, 0), Vector2(16, 16), Vector2(16, 0), Vector2(0, 16)]),
			true
		]  # Still valid polygon
	]
) -> void:
	var is_valid: bool = polygon_points.size() >= 3
	var area: float = 0.0

	if is_valid:
		# Use bounds area as approximation since polygon_area not available
		var bounds: Rect2 = GBGeometryMath.get_polygon_bounds(polygon_points)
		area = bounds.size.x * bounds.size.y
		is_valid = area > MIN_AREA_THRESHOLD

	(
		assert_bool(is_valid)
		. append_failure_message(
			(
				"Shape %s: expected valid=%s but got valid=%s (points=%d, area=%.4f)"
				% [shape_name, expected_valid, is_valid, polygon_points.size(), area]
			)
		)
		. is_equal(expected_valid)
	)


#endregion
#region POLYGON INDICATOR HEURISTICS TESTS


func test_indicator_polygon_heuristics() -> void:
	# Test various polygon types for indicator generation
	var test_polygons: Array[Dictionary] = [
		{
			"name": "simple_rect",
			"points":
			PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)]),
			"expected_tiles": 1
		},
		{
			"name": "large_rect",
			"points":
			PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)]),
			"expected_tiles": 4
		},
		{
			"name": "thin_line",
			"points":
			PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 1), Vector2(0, 1)]),
			"expected_tiles": 2
		}
	]

	for polygon_data: Dictionary in test_polygons:
		var points: PackedVector2Array = polygon_data["points"] as PackedVector2Array
		var expected_tiles: int = polygon_data["expected_tiles"] as int
		var polygon_name: String = polygon_data["name"] as String

		var tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
			points,
			TILE_SIZE,
			TileSet.TILE_SHAPE_SQUARE,
			_test_tile_map_layer,
			OVERLAP_THRESHOLD,
			OVERLAP_THRESHOLD
		)

		(
			assert_int(tiles.size())
			. append_failure_message(
				(
					"Polygon %s: expected %d tiles but got %d: %s"
					% [polygon_name, expected_tiles, tiles.size(), tiles]
				)
			)
			. is_equal(expected_tiles)
		)


#endregion
#region Comprehensive Geometry Validation Tests


func test_geometry_math_edge_cases() -> void:
	# Test edge cases for geometry calculations
	var empty_polygon: PackedVector2Array = PackedVector2Array([])
	var single_point: PackedVector2Array = PackedVector2Array([Vector2(5, 5)])
	var line_segment: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])

	# Test bounds calculations
	var empty_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(empty_polygon)
	var point_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(single_point)
	var line_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(line_segment)

	assert_vector(empty_bounds.size).is_equal(Vector2.ZERO)
	assert_vector(point_bounds.position).is_equal(Vector2(5, 5))
	assert_float(line_bounds.size.x).is_equal(10.0)
	assert_float(line_bounds.size.y).is_equal(0.0)


func test_polygon_area_calculations() -> void:
	# Test area calculations using bounds approximation
	var unit_square: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	)
	var triangle: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(2, 0), Vector2(1, 2)]
	)

	var square_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(unit_square)
	var triangle_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(triangle)

	var square_area: float = square_bounds.size.x * square_bounds.size.y
	var triangle_area: float = triangle_bounds.size.x * triangle_bounds.size.y

	assert_float(square_area).is_equal_approx(1.0, 0.01)
	assert_float(triangle_area).is_equal_approx(4.0, 0.01)  # Bounding box area, not exact


func test_tile_overlap_comprehensive() -> void:
	# Test comprehensive tile overlap scenarios
	var test_cases: Array[Dictionary] = [
		{
			"polygon":
			PackedVector2Array([Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)]),
			"expected_count": 4
		},
		{
			"polygon":
			PackedVector2Array([Vector2(0, 0), Vector2(15, 0), Vector2(15, 15), Vector2(0, 15)]),  # 2x2 overlap
			"expected_count": 1
		},
		{
			"polygon":
			PackedVector2Array([Vector2(1, 1), Vector2(17, 1), Vector2(17, 17), Vector2(1, 17)]),  # Single tile
			"expected_count": 3
		}  # 16x16 polygon offset by 1 pixel - overlaps 3 tiles
	]

	for i: int in test_cases.size():
		var test_case: Dictionary = test_cases[i]
		var polygon: PackedVector2Array = test_case["polygon"] as PackedVector2Array
		var expected: int = test_case["expected_count"] as int

		var tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
			polygon,
			TILE_SIZE,
			TileSet.TILE_SHAPE_SQUARE,
			_test_tile_map_layer,
			OVERLAP_THRESHOLD,
			AREA_THRESHOLD
		)

		# Enhanced diagnostics on failure: polygon points, expected vs actual, overlapped tiles,
		# polygon bounds, and a hint for enabling verbose clipping debug in the calculator.
		var poly_str: String = _format_polygon(polygon)
		var poly_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(polygon)
		var failure_msg: String = (
			"Test case "
			+ str(i)
			+ ": expected "
			+ str(expected)
			+ " tiles but got "
			+ str(tiles.size())
			+ "\n"
		)
		failure_msg += "Polygon points: " + poly_str + "\n"
		failure_msg += "Overlapped tiles: " + str(tiles) + "\n"
		failure_msg += (
			"Polygon bounds: pos="
			+ str(poly_bounds.position)
			+ " size="
			+ str(poly_bounds.size)
			+ "\n"
		)
		failure_msg += "Note: enable CollisionGeometryCalculator.debug_polygon_overlap = true for per-tile clipping logs\n"
		assert_int(tiles.size()).append_failure_message(failure_msg).is_equal(expected)


#endregion
#region Comprehensive Geometry Math Tests

@warning_ignore("unused_parameter")
func test_get_tile_polygon_for_all_shapes(
	tile_shape_name: String,
	tile_shape: TileSet.TileShape,
	tile_pos: Vector2,
	tile_size: Vector2,
	expected_vertex_count: int,
	test_parameters := [
		# Square tiles
		["square_origin", TileSet.TILE_SHAPE_SQUARE, Vector2(0, 0), Vector2(16, 16), 4],
		["square_offset", TileSet.TILE_SHAPE_SQUARE, Vector2(32, 48), Vector2(16, 16), 4],
		["square_large", TileSet.TILE_SHAPE_SQUARE, Vector2(0, 0), Vector2(32, 32), 4],
		# Isometric tiles
		["isometric_origin", TileSet.TILE_SHAPE_ISOMETRIC, Vector2(0, 0), Vector2(16, 16), 4],
		["isometric_offset", TileSet.TILE_SHAPE_ISOMETRIC, Vector2(32, 48), Vector2(16, 16), 4],
		["isometric_large", TileSet.TILE_SHAPE_ISOMETRIC, Vector2(0, 0), Vector2(32, 32), 4],
		# Half-offset square tiles
		[
			"half_offset_origin",
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			Vector2(0, 0),
			Vector2(16, 16),
			4
		],
		[
			"half_offset_offset",
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			Vector2(32, 48),
			Vector2(16, 16),
			4
		],
		[
			"half_offset_large",
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			Vector2(0, 0),
			Vector2(32, 32),
			4
		],
	]
) -> void:
	var tile_polygon: PackedVector2Array = GBGeometryMath.get_tile_polygon(
		tile_pos, tile_size, tile_shape
	)

	# Validate vertex count
	(
		assert_int(tile_polygon.size())
		. append_failure_message(
			(
				"Tile shape %s should have %d vertices, got %d"
				% [tile_shape_name, expected_vertex_count, tile_polygon.size()]
			)
		)
		. is_equal(expected_vertex_count)
	)

	# Validate tile polygon is not empty
	(
		assert_array(tile_polygon)
		. append_failure_message("Tile polygon for %s should not be empty" % tile_shape_name)
		. is_not_empty()
	)


@warning_ignore("unused_parameter")
func test_intersection_area_with_tile_for_all_shapes(
	test_case_name: String,
	polygon: PackedVector2Array,
	tile_pos: Vector2,
	tile_size: Vector2,
	tile_shape: TileSet.TileShape,
	expected_area_min: float,
	expected_area_max: float,
	test_parameters := [
		# Small square polygon with various tile shapes
		[
			"small_square_square_tile",
			PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_SQUARE,
			60.0,
			70.0
		],
		[
			"small_square_isometric_tile",
			PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_ISOMETRIC,
			40.0,
			70.0
		],
		[
			"small_square_half_offset_tile",
			PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			60.0,
			70.0
		],
		# Center square polygon (should fully overlap with all tile types)
		[
			"center_square_square_tile",
			PackedVector2Array([Vector2(6, 6), Vector2(10, 6), Vector2(10, 10), Vector2(6, 10)]),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_SQUARE,
			15.0,
			17.0
		],
		[
			"center_square_isometric_tile",
			PackedVector2Array([Vector2(6, 6), Vector2(10, 6), Vector2(10, 10), Vector2(6, 10)]),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_ISOMETRIC,
			15.0,
			17.0
		],
		[
			"center_square_half_offset_tile",
			PackedVector2Array([Vector2(6, 6), Vector2(10, 6), Vector2(10, 10), Vector2(6, 10)]),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			15.0,
			17.0
		],
		# No overlap cases
		[
			"no_overlap_square_tile",
			PackedVector2Array(
				[Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]
			),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_SQUARE,
			0.0,
			0.1
		],
		[
			"no_overlap_isometric_tile",
			PackedVector2Array(
				[Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]
			),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_ISOMETRIC,
			0.0,
			0.1
		],
		[
			"no_overlap_half_offset_tile",
			PackedVector2Array(
				[Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]
			),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			0.0,
			0.1
		],
	]
) -> void:
	var intersection_area: float = GBGeometryMath.intersection_area_with_tile(
		polygon, tile_pos, tile_size, tile_shape
	)

	# Validate intersection area is within expected bounds
	(
		assert_float(intersection_area)
		. append_failure_message(
			(
				"Intersection area for %s should be between %.2f and %.2f, got %.2f"
				% [test_case_name, expected_area_min, expected_area_max, intersection_area]
			)
		)
		. is_between(expected_area_min, expected_area_max)
	)

	# Validate area is non-negative
	(
		assert_float(intersection_area)
		. append_failure_message(
			(
				"Intersection area should never be negative, got %.2f for %s"
				% [intersection_area, test_case_name]
			)
		)
		. is_greater_equal(0.0)
	)


@warning_ignore("unused_parameter")
func test_does_polygon_overlap_tile_for_all_shapes(
	test_case_name: String,
	polygon: PackedVector2Array,
	tile_pos: Vector2,
	tile_size: Vector2,
	tile_shape: TileSet.TileShape,
	expected_overlap: bool,
	test_parameters := [
		# Overlapping cases
		[
			"overlap_square_tile",
			PackedVector2Array([Vector2(8, 8), Vector2(16, 8), Vector2(16, 16), Vector2(8, 16)]),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_SQUARE,
			true
		],
		[
			"overlap_isometric_tile",
			PackedVector2Array([Vector2(8, 8), Vector2(16, 8), Vector2(16, 16), Vector2(8, 16)]),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_ISOMETRIC,
			true
		],
		[
			"overlap_half_offset_tile",
			PackedVector2Array([Vector2(8, 8), Vector2(16, 8), Vector2(16, 16), Vector2(8, 16)]),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			true
		],
		# Non-overlapping cases
		[
			"no_overlap_square_tile",
			PackedVector2Array(
				[Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]
			),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_SQUARE,
			false
		],
		[
			"no_overlap_isometric_tile",
			PackedVector2Array(
				[Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]
			),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_ISOMETRIC,
			false
		],
		[
			"no_overlap_half_offset_tile",
			PackedVector2Array(
				[Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]
			),
			Vector2(0, 0),
			Vector2(16, 16),
			TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE,
			false
		],
	]
) -> void:
	var overlaps: bool = GBGeometryMath.does_polygon_overlap_tile(
		polygon, tile_pos, tile_size, tile_shape, OVERLAP_THRESHOLD
	)

	# Validate overlap detection
	(
		assert_bool(overlaps)
		. append_failure_message(
			(
				"Overlap detection for %s should be %s, got %s"
				% [test_case_name, expected_overlap, overlaps]
			)
		)
		. is_equal(expected_overlap)
	)


func test_gb_geometry_math_edge_cases() -> void:
	# Test edge cases for geometry math functions
	var tile_size: Vector2 = TILE_SIZE
	var tile_pos: Vector2 = Vector2(0, 0)

	# Empty polygon
	var empty_polygon: PackedVector2Array = PackedVector2Array([])
	var empty_area: float = GBGeometryMath.intersection_area_with_tile(
		empty_polygon, tile_pos, tile_size, TileSet.TILE_SHAPE_SQUARE
	)
	assert_float(empty_area).is_equal(0.0)

	# Single point
	var point_polygon: PackedVector2Array = PackedVector2Array([Vector2(8, 8)])
	var point_area: float = GBGeometryMath.intersection_area_with_tile(
		point_polygon, tile_pos, tile_size, TileSet.TILE_SHAPE_SQUARE
	)
	assert_float(point_area).is_equal(0.0)

	# Zero-size tile
	var zero_tile_area: float = GBGeometryMath.intersection_area_with_tile(
		PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(8, 8), Vector2(0, 8)]),
		Vector2(0, 0),
		Vector2(0, 0),
		TileSet.TILE_SHAPE_SQUARE
	)
	assert_float(zero_tile_area).is_equal(0.0)

#endregion
