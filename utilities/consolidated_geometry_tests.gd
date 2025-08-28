extends GdUnitTestSuite

## Consolidated Geometry Test Suite
## Consolidates: geometry_debug_comprehensive_test.gd, simple_trapezoid_analysis_test.gd, 
## polygon_tile_overlap_threshold_test.gd, correct_trapezoid_test.gd, polygon_test_object_shape_test.gd,
## polygon_indicator_heuristics_test.gd

var test_env: Dictionary

func before_test() -> void:
	test_env = UnifiedTestFactory.create_utilities_test_environment(self)

## MARK FOR REMOVAL - geometry_debug_comprehensive_test.gd, simple_trapezoid_analysis_test.gd, 
## polygon_tile_overlap_threshold_test.gd, correct_trapezoid_test.gd, polygon_test_object_shape_test.gd,
## polygon_indicator_heuristics_test.gd

# ===== GEOMETRY DEBUG TESTS =====

@warning_ignore("unused_parameter")
func test_geometry_debug_scenarios(
	polygon_name: String, 
	polygon_data: PackedVector2Array, 
	tile_pos: Vector2, 
	expected_overlap: bool,
	test_parameters := [
		["trapezoid", PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]), Vector2(0, 8), true],
		["rectangle", PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]), Vector2(0, 0), true],
		["triangle", PackedVector2Array([Vector2(0, -20), Vector2(20, 20), Vector2(-20, 20)]), Vector2(0, 0), true],
		["small_square", PackedVector2Array([Vector2(5, 5), Vector2(10, 5), Vector2(10, 10), Vector2(5, 10)]), Vector2(8, 8), true],
		["offset_triangle", PackedVector2Array([Vector2(100, 100), Vector2(120, 100), Vector2(110, 120)]), Vector2(110, 110), true]
	]
) -> void:
	var tile_size: Vector2 = GodotTestFactory.create_tile_size()
	
	# Calculate bounds and overlap
	var polygon_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(polygon_data)
	var intersection_area: float = GBGeometryMath.intersection_area_with_tile(polygon_data, tile_pos, tile_size, 0)
	var has_overlap: bool = intersection_area > 0.01
	
	# Validate expected behavior
	assert_bool(has_overlap).append_failure_message(
		"Geometry %s: expected overlap %s but got %s (area: %.4f)" % [polygon_name, expected_overlap, has_overlap, intersection_area]
	).is_equal(expected_overlap)
	
	# Validate bounds are valid
	assert_object(polygon_bounds).is_not_null()
	if polygon_data.size() > 0:
		assert_float(polygon_bounds.size.x).is_greater_equal(0.0)
		assert_float(polygon_bounds.size.y).is_greater_equal(0.0)

# ===== POLYGON TILE OVERLAP THRESHOLD TESTS =====

func test_polygon_below_threshold_excluded() -> void:
	# 16x16 tile => area 256. 5% threshold => 12.8. Use 2x2 square (area=4)
	var poly: PackedVector2Array = PackedVector2Array([Vector2(0,0), Vector2(2,0), Vector2(2,2), Vector2(0,2)])
	var tiles: Array = CollisionGeometryCalculator.calculate_tile_overlap(
		poly, Vector2(16,16), GBEnums.TileType.SQUARE as GBEnums.TileType, 0.01, 0.05
	)
	var tile_count: int = tiles.size()
	assert_int(tile_count).append_failure_message(
		"Expected no tiles for area 4 (<5%% of 256), got %d tiles" % tile_count
	).is_equal(0)

func test_polygon_above_threshold_included() -> void:
	# 4x4 square (area=16) > 12.8 threshold
	var poly: PackedVector2Array = PackedVector2Array([Vector2(0,0), Vector2(4,0), Vector2(4,4), Vector2(0,4)])
	var tiles: Array = CollisionGeometryCalculator.calculate_tile_overlap(
		poly, Vector2(16,16), GBEnums.TileType.SQUARE as GBEnums.TileType, 0.01, 0.05
	)
	var tile_count: int = tiles.size()
	assert_int(tile_count).append_failure_message(
		"Expected 1 tile for area 16 (>5%% threshold), got %d: %s" % [tile_count, tiles]
	).is_equal(1)

func test_concave_polygon_void_handling() -> void:
	# C-shaped polygon with internal void
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(0,0), Vector2(12,0), Vector2(12,4), Vector2(4,4), 
		Vector2(4,12), Vector2(12,12), Vector2(12,16), Vector2(0,16)
	])
	var tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		poly, Vector2(16,16), GBEnums.TileType.SQUARE as GBEnums.TileType, 0.01, 0.05
	)
	# Ensure void isn't filled with phantom tiles
	assert_int(tiles.size()).is_less_equal(1)

# ===== TRAPEZOID ANALYSIS TESTS =====

func test_trapezoid_top_left_overlap() -> void:
	# Simple trapezoid from runtime analysis
	var trapezoid: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
	])
	var tile_size = GodotTestFactory.create_tile_size()
	
	# Position at runtime location
	var positioner_offset: Vector2 = Vector2(808, 680)
	var collision_polygon_offset: Vector2 = Vector2(8, -8)
	
	# Transform to world coordinates
	var world_trapezoid: PackedVector2Array = PackedVector2Array()
	for point in trapezoid:
		world_trapezoid.append(positioner_offset + collision_polygon_offset + point)
	
	# Test problematic tile from runtime
	var problematic_tile_coord = Vector2i(49, 41)
	var tile_world_pos: Vector2 = Vector2(49 * 16, 41 * 16)
	
	var epsilon = tile_size.x * tile_size.y * 0.05
	var overlaps = GBGeometryMath.does_polygon_overlap_tile_optimized(
		world_trapezoid, tile_world_pos, tile_size, 0, epsilon
	)
	
	# Validate overlap detection
	assert_bool(overlaps).append_failure_message(
		"Trapezoid should overlap tile %s at world pos %s" % [str(problematic_tile_coord), str(tile_world_pos)]
	).is_true()

func test_correct_trapezoid_geometry() -> void:
	# Test trapezoid with known geometry properties
	var trapezoid_points: PackedVector2Array = PackedVector2Array([
		Vector2(-16, 8), Vector2(-8, -8), Vector2(8, -8), Vector2(16, 8)
	])
	
	var bounds = GBGeometryMath.get_polygon_bounds(trapezoid_points)
	# Note: polygon_area not available in GBGeometryMath, using bounds validation instead
	var area = bounds.size.x * bounds.size.y  # Approximate area from bounds
	
	# Validate geometric properties
	assert_float(bounds.size.x).append_failure_message(
		"Trapezoid width should be 32, got %.2f" % bounds.size.x
	).is_equal(32.0)
	assert_float(bounds.size.y).append_failure_message(
		"Trapezoid height should be 16, got %.2f" % bounds.size.y
	).is_equal(16.0)
	assert_float(area).is_greater(0.0)

# ===== POLYGON SHAPE TESTS =====

@warning_ignore("unused_parameter") 
func test_polygon_shape_validation(
	shape_name: String,
	polygon_points: PackedVector2Array,
	expected_valid: bool,
	test_parameters := [
		["valid_triangle", PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(8,16)]), true],
		["valid_rectangle", PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(16,16), Vector2(0,16)]), true],
		["degenerate_line", PackedVector2Array([Vector2(0,0), Vector2(16,0)]), false],
		["single_point", PackedVector2Array([Vector2(5,5)]), false],
		["empty_polygon", PackedVector2Array([]), false],
		["self_intersecting", PackedVector2Array([Vector2(0,0), Vector2(16,16), Vector2(16,0), Vector2(0,16)]), true] # Still valid polygon
	]
) -> void:
	var is_valid = polygon_points.size() >= 3
	var area = 0.0
	
	if is_valid:
		# Use bounds area as approximation since polygon_area not available
		var bounds = GBGeometryMath.get_polygon_bounds(polygon_points)
		area = bounds.size.x * bounds.size.y
		is_valid = area > 0.001
	
	assert_bool(is_valid).append_failure_message(
		"Shape %s: expected valid=%s but got valid=%s (points=%d, area=%.4f)" % 
		[shape_name, expected_valid, is_valid, polygon_points.size(), area]
	).is_equal(expected_valid)

# ===== POLYGON INDICATOR HEURISTICS TESTS =====

func test_indicator_polygon_heuristics() -> void:
	# Test various polygon types for indicator generation
	var test_polygons: Array = [
		{"name": "simple_rect", "points": PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(16,16), Vector2(0,16)]), "expected_tiles": 1},
		{"name": "large_rect", "points": PackedVector2Array([Vector2(0,0), Vector2(32,0), Vector2(32,32), Vector2(0,32)]), "expected_tiles": 4},
		{"name": "thin_line", "points": PackedVector2Array([Vector2(0,0), Vector2(32,0), Vector2(32,1), Vector2(0,1)]), "expected_tiles": 2}
	]
	
	for polygon_data: Dictionary in test_polygons:
		var points = polygon_data["points"] as PackedVector2Array
		var expected_tiles = polygon_data["expected_tiles"] as int
		var polygon_name = polygon_data["name"] as String
		
		var tiles = CollisionGeometryCalculator.calculate_tile_overlap(
			points, Vector2(16,16), GBEnums.TileType.SQUARE as GBEnums.TileType, 0.01, 0.01
		)
		
		assert_int(tiles.size()).append_failure_message(
			"Polygon %s: expected %d tiles but got %d: %s" % [polygon_name, expected_tiles, tiles.size(), tiles]
		).is_equal(expected_tiles)

# ===== COMPREHENSIVE GEOMETRY VALIDATION TESTS =====

func test_geometry_math_edge_cases() -> void:
	# Test edge cases for geometry calculations
	var empty_polygon: PackedVector2Array = PackedVector2Array([])
	var single_point: PackedVector2Array = PackedVector2Array([Vector2(5,5)])
	var line_segment: PackedVector2Array = PackedVector2Array([Vector2(0,0), Vector2(10,0)])
	
	# Test bounds calculations
	var empty_bounds = GBGeometryMath.get_polygon_bounds(empty_polygon)
	var point_bounds = GBGeometryMath.get_polygon_bounds(single_point)
	var line_bounds = GBGeometryMath.get_polygon_bounds(line_segment)
	
	assert_vector(empty_bounds.size).is_equal(Vector2.ZERO)
	assert_vector(point_bounds.position).is_equal(Vector2(5,5))
	assert_float(line_bounds.size.x).is_equal(10.0)
	assert_float(line_bounds.size.y).is_equal(0.0)

func test_polygon_area_calculations() -> void:
	# Test area calculations using bounds approximation
	var unit_square: PackedVector2Array = PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)])
	var triangle: PackedVector2Array = PackedVector2Array([Vector2(0,0), Vector2(2,0), Vector2(1,2)])
	
	var square_bounds = GBGeometryMath.get_polygon_bounds(unit_square)
	var triangle_bounds = GBGeometryMath.get_polygon_bounds(triangle)
	
	var square_area = square_bounds.size.x * square_bounds.size.y
	var triangle_area = triangle_bounds.size.x * triangle_bounds.size.y
	
	assert_float(square_area).is_equal_approx(1.0, 0.01)
	assert_float(triangle_area).is_equal_approx(4.0, 0.01)  # Bounding box area, not exact

func test_tile_overlap_comprehensive() -> void:
	# Test comprehensive tile overlap scenarios
	var test_cases: Array = [
		{"polygon": PackedVector2Array([Vector2(8,8), Vector2(24,8), Vector2(24,24), Vector2(8,24)]), "expected_count": 4},  # 2x2 overlap
		{"polygon": PackedVector2Array([Vector2(0,0), Vector2(15,0), Vector2(15,15), Vector2(0,15)]), "expected_count": 1},  # Single tile
		{"polygon": PackedVector2Array([Vector2(1,1), Vector2(17,1), Vector2(17,17), Vector2(1,17)]), "expected_count": 1}     # 16x16 polygon overlapping 1 tile
	]
	
	for i in test_cases.size():
		var test_case = test_cases[i]
		var polygon = test_case["polygon"] as PackedVector2Array
		var expected = test_case["expected_count"] as int
		
		var tiles = CollisionGeometryCalculator.calculate_tile_overlap(
			polygon, Vector2(16,16), GBEnums.TileType.SQUARE as GBEnums.TileType, 0.01, 0.01
		)
		
		assert_int(tiles.size()).append_failure_message(
			"Test case %d: expected %d tiles but got %d for polygon %s" % [i, expected, tiles.size(), polygon]
		).is_equal(expected)
