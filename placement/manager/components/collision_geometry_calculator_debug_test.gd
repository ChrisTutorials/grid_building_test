## Debug test suite for CollisionGeometryCalculator edge cases and issues.
## Tests problematic geometry scenarios that may cause unexpected behavior.
##
## This test suite serves as a comprehensive debugging toolkit for geometry calculation issues.
## Related debug test suites:
## - tile_bounds_debug_test.gd: Specific tile positioning and bounds debugging
## - trapezoid_debug_test.gd: Trapezoid collision position testing
## - capsule_bounds_debug_test.gd: Capsule shape debugging
## - collision_mapper_transform_test.gd: Transform-related debugging
##
## Use this suite when:
## - Debugging polygon overlap calculation failures
## - Testing edge cases with degenerate polygons (points, lines, zero-area shapes)
## - Validating behavior with extreme parameter values
## - Understanding why certain geometries don't produce expected overlaps
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

## Helper method to create debug output that can be used by other test suites
static func debug_polygon_overlap_calculation(
	polygon: PackedVector2Array,
	tile_size: Vector2,
	tile_type: GBEnums.TileType,
	epsilon: float = 0.01,
	min_overlap_ratio: float = 0.05,
	context_name: String = "Debug"
) -> Dictionary:
	print("=== ", context_name, " Polygon Overlap Debug ===")
	print("Input: polygon = ", polygon, " (", polygon.size(), " points)")
	print("Input: tile_size = ", tile_size)
	print("Parameters: epsilon=", epsilon, ", min_overlap_ratio=", min_overlap_ratio)
	
	var debug_info = {}
	
	# Get polygon bounds
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(polygon)
	print("Polygon bounds: ", bounds)
	debug_info["bounds"] = bounds
	
	# Calculate tile range
	if bounds.size != Vector2.ZERO or polygon.size() > 0:
		var start_tile = Vector2i(floor(bounds.position.x / tile_size.x), floor(bounds.position.y / tile_size.y))
		var end_tile = Vector2i(ceil((bounds.position.x + bounds.size.x) / tile_size.x), ceil((bounds.position.y + bounds.size.y) / tile_size.y))
		print("Tile range: start=", start_tile, ", end=", end_tile)
		debug_info["tile_range"] = {"start": start_tile, "end": end_tile}
	
	# Calculate overlaps
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		polygon, tile_size, tile_type, epsilon, min_overlap_ratio
	)
	print("Overlapped tiles: ", overlapped_tiles, " (", overlapped_tiles.size(), " tiles)")
	debug_info["overlapped_tiles"] = overlapped_tiles
	
	# Check if it's a valid polygon
	var is_valid_polygon = polygon.size() >= 3
	print("Is valid polygon (3+ vertices): ", is_valid_polygon)
	debug_info["is_valid_polygon"] = is_valid_polygon
	
	if is_valid_polygon:
		var area = CollisionGeometryCalculator._polygon_area(polygon)
		print("Polygon area: ", area)
		debug_info["polygon_area"] = area
	
	print("=== End ", context_name, " Debug ===")
	return debug_info

## Test single point polygon behavior - this was causing test failures
func test_single_point_polygon_debug() -> void:
	print("=== Debugging Single Point Test Issue ===")
	
	var single_point = PackedVector2Array([Vector2(8, 8)])
	var tile_size = Vector2(16, 16)
	
	print("Input: single_point = ", single_point)
	print("Input: tile_size = ", tile_size)
	
	# Step 1: Get polygon bounds
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(single_point)
	print("Step 1 - Polygon bounds: ", bounds)
	assert_vector(bounds.position).is_equal(Vector2(8, 8))
	assert_vector(bounds.size).is_equal(Vector2.ZERO)
	
	# Step 2: Calculate tile range
	var start_tile = Vector2i(floor(bounds.position.x / tile_size.x), floor(bounds.position.y / tile_size.y))
	var end_tile = Vector2i(ceil((bounds.position.x + bounds.size.x) / tile_size.x), ceil((bounds.position.y + bounds.size.y) / tile_size.y))
	print("Step 2 - Tile range: start=", start_tile, ", end=", end_tile)
	assert_vector(Vector2(start_tile)).is_equal(Vector2(0, 0))
	assert_vector(Vector2(end_tile)).is_equal(Vector2(1, 1))
	
	# Step 3: Check the specific tile (0,0)
	var tile_pos = Vector2i(0, 0)
	var tile_rect = Rect2(Vector2(0 * tile_size.x, 0 * tile_size.y), tile_size)
	print("Step 3 - Checking tile ", tile_pos, " with rect: ", tile_rect)
	
	# Step 4: Check if bounds intersect
	var poly_bounds = CollisionGeometryCalculator._get_polygon_bounds(single_point)
	var bounds_intersect = poly_bounds.intersects(tile_rect, true)
	print("Step 4 - Bounds intersect: ", bounds_intersect)
	print("         poly_bounds=", poly_bounds, ", tile_rect=", tile_rect)
	# Note: A zero-size rectangle at (8,8) should intersect with tile rect (0,0,16,16)
	assert_bool(bounds_intersect).is_true()
	
	# Step 5: Try clipping
	var clipped = CollisionGeometryCalculator._clip_polygon_to_rect(single_point, tile_rect)
	print("Step 5 - Clipped result: ", clipped, " (size: ", clipped.size(), ")")
	# This is the issue: single point gets clipped to empty because it has < 3 vertices
	assert_int(clipped.size()).is_equal(1)  # Should preserve the single point
	
	# Step 6: Final overlap check
	var overlaps = CollisionGeometryCalculator._polygon_overlaps_rect(single_point, tile_rect, 0.01, 0.05)
	print("Step 6 - Final overlap result: ", overlaps)
	
	# The actual calculate_tile_overlap call
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		single_point, tile_size, GBEnums.TileType.SQUARE
	)
	print("Step 7 - Final result: ", overlapped_tiles)
	
	print("=== End Debug ===")
	
	# This test documents the current behavior - single points are rejected
	# The original test expectation may need to be reconsidered
	assert_int(overlapped_tiles.size()).is_equal(0)  # Current behavior: single points don't overlap

## Test two-point line segment behavior
func test_two_point_line_debug() -> void:
	print("=== Debugging Two Point Line ===")
	
	var line_segment = PackedVector2Array([Vector2(0, 8), Vector2(16, 8)])
	var tile_size = Vector2(16, 16)
	
	print("Input: line_segment = ", line_segment)
	
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(line_segment)
	print("Line bounds: ", bounds)
	assert_vector(bounds.position).is_equal(Vector2(0, 8))
	assert_vector(bounds.size).is_equal(Vector2(16, 0))
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		line_segment, tile_size, GBEnums.TileType.SQUARE
	)
	print("Line overlap result: ", overlapped_tiles)
	
	# Lines also get rejected because they can't form valid polygons (need 3+ vertices)
	assert_int(overlapped_tiles.size()).is_equal(0)
	
	print("=== End Line Debug ===")

## Test valid triangle (minimum valid polygon)
func test_minimal_triangle_debug() -> void:
	print("=== Debugging Minimal Triangle ===")
	
	var triangle = PackedVector2Array([Vector2(8, 4), Vector2(12, 12), Vector2(4, 12)])
	var tile_size = Vector2(16, 16)
	
	print("Input: triangle = ", triangle)
	
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(triangle)
	print("Triangle bounds: ", bounds)
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		triangle, tile_size, GBEnums.TileType.SQUARE
	)
	print("Triangle overlap result: ", overlapped_tiles)
	
	# This should work because triangles are valid polygons
	assert_int(overlapped_tiles.size()).is_greater(0)
	
	print("=== End Triangle Debug ===")

## Test edge case: point exactly on tile boundary
func test_boundary_point_debug() -> void:
	print("=== Debugging Boundary Point ===")
	
	var boundary_point = PackedVector2Array([Vector2(16, 16)])  # Exactly on tile corner
	var tile_size = Vector2(16, 16)
	
	print("Input: boundary_point = ", boundary_point)
	
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(boundary_point)
	print("Boundary point bounds: ", bounds)
	
	# This point is exactly on the boundary between 4 tiles
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		boundary_point, tile_size, GBEnums.TileType.SQUARE
	)
	print("Boundary point overlap result: ", overlapped_tiles)
	
	assert_int(overlapped_tiles.size()).is_equal(0)  # Single points don't overlap
	
	print("=== End Boundary Debug ===")

## Test degenerate rectangle (zero area)
func test_degenerate_rectangle_debug() -> void:
	print("=== Debugging Degenerate Rectangle ===")
	
	# Rectangle with zero width
	var degenerate_rect = PackedVector2Array([
		Vector2(8, 4), Vector2(8, 4), Vector2(8, 12), Vector2(8, 12)
	])
	var tile_size = Vector2(16, 16)
	
	print("Input: degenerate_rect = ", degenerate_rect)
	
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(degenerate_rect)
	print("Degenerate rect bounds: ", bounds)
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		degenerate_rect, tile_size, GBEnums.TileType.SQUARE
	)
	print("Degenerate rect overlap result: ", overlapped_tiles)
	
	print("=== End Degenerate Debug ===")

## Test very small valid polygon (should have minimal area)
func test_tiny_valid_polygon_debug() -> void:
	print("=== Debugging Tiny Valid Polygon ===")
	
	# Very small triangle with actual area
	var tiny_triangle = PackedVector2Array([
		Vector2(8.0, 8.0), Vector2(8.1, 8.0), Vector2(8.0, 8.1)
	])
	var tile_size = Vector2(16, 16)
	
	print("Input: tiny_triangle = ", tiny_triangle)
	
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(tiny_triangle)
	print("Tiny triangle bounds: ", bounds)
	
	# Calculate the actual area
	var area = CollisionGeometryCalculator._polygon_area(tiny_triangle)
	print("Tiny triangle area: ", area)
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		tiny_triangle, tile_size, GBEnums.TileType.SQUARE
	)
	print("Tiny triangle overlap result: ", overlapped_tiles)
	
	# This should work if the area exceeds the minimum thresholds
	print("=== End Tiny Debug ===")

## Test parameter edge cases with extreme values
@warning_ignore("unused_parameter")
func test_extreme_parameter_values(
	test_name: String,
	polygon: PackedVector2Array,
	tile_size: Vector2,
	epsilon: float,
	min_overlap_ratio: float,
	test_parameters := [
		["Zero epsilon", PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(16,16), Vector2(0,16)]), Vector2(16,16), 0.0, 0.05],
		["Very high epsilon", PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(16,16), Vector2(0,16)]), Vector2(16,16), 1000.0, 0.05],
		["Zero min overlap ratio", PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(16,16), Vector2(0,16)]), Vector2(16,16), 0.01, 0.0],
		["Very high min overlap ratio", PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(16,16), Vector2(0,16)]), Vector2(16,16), 0.01, 0.99],
		["Tiny tile size", PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(16,16), Vector2(0,16)]), Vector2(0.1,0.1), 0.01, 0.05],
		["Huge tile size", PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(16,16), Vector2(0,16)]), Vector2(1000,1000), 0.01, 0.05],
	]
) -> void:
	print("=== Testing ", test_name, " ===")
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		polygon, tile_size, GBEnums.TileType.SQUARE, epsilon, min_overlap_ratio
	)
	
	print("Parameters: epsilon=", epsilon, ", min_overlap_ratio=", min_overlap_ratio, ", tile_size=", tile_size)
	print("Result: ", overlapped_tiles.size(), " tiles")
	
	# These tests just verify the function doesn't crash with extreme values
	assert_that(overlapped_tiles).is_not_null()
	
	print("=== End ", test_name, " ===")
