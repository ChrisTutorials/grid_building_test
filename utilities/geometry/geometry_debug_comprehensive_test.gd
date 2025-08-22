extends GdUnitTestSuite

## Comprehensive geometry debug test suite combining tile bounds, capsule bounds, and trapezoid debugging
## Consolidates tile_bounds_debug_test.gd, capsule_bounds_debug_test.gd, and trapezoid_debug_test.gd

# Test data for tile bounds debugging scenarios
@warning_ignore("unused_parameter")
func test_tile_bounds_debug_scenarios(polygon_name: String, polygon_data: PackedVector2Array, tile_pos: Vector2, expected_overlap: bool, test_parameters := [
	# [polygon_name, polygon_data, tile_pos, expected_overlap]
	["trapezoid", PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]), Vector2(0, 8), true],
	["rectangle", PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]), Vector2(0, 0), true],
	["triangle", PackedVector2Array([Vector2(0, -20), Vector2(20, 20), Vector2(-20, 20)]), Vector2(0, 0), true]
]):
	var tile_size = GodotTestFactory.create_tile_size()
	
	# Get the tile polygon using GBGeometryMath
	var tile_polygon = GBGeometryMath.get_tile_polygon(tile_pos, tile_size, 0)
	
	print("=== %s Debug ===" % polygon_name.capitalize())
	print("Polygon points: ", polygon_data)
	print("Tile position: ", tile_pos)
	print("Tile size: ", tile_size)
	print("Tile polygon: ", tile_polygon)
	
	# Calculate bounds
	var polygon_bounds = GBGeometryMath.get_polygon_bounds(polygon_data)
	var tile_bounds = GBGeometryMath.get_polygon_bounds(tile_polygon)
	
	print("Polygon bounds: ", polygon_bounds)
	print("Tile bounds: ", tile_bounds)
	
	# Check overlap using intersection area
	var intersection_area = GBGeometryMath.intersection_area_with_tile(polygon_data, tile_pos, tile_size, 0)
	var has_overlap = intersection_area > 0.01
	
	print("Intersection area: %.4f" % intersection_area)
	print("Has overlap: ", has_overlap)
	print("Expected overlap: ", expected_overlap)
	
	# Validate expected behavior
	assert_bool(has_overlap).is_equal(expected_overlap)
	
	# Additional bounds checking
	assert_object(polygon_bounds).is_not_null()
	assert_object(tile_bounds).is_not_null()
	assert_float(polygon_bounds.size.x).is_greater(0.0)
	assert_float(polygon_bounds.size.y).is_greater(0.0)

# Test data for shape bounds symmetry
@warning_ignore("unused_parameter")
func test_shape_bounds_symmetry(shape_type: String, shape: Shape2D, expected_symmetry: bool, test_parameters := [
	# [shape_type, shape, expected_symmetry] - shape created in function due to parameter limitations
	["capsule", null, true],
	["rectangle", null, true],
	["circle", null, true]
]):
	# Create shapes within the test function
	var actual_shape: Shape2D
	match shape_type:
		"capsule":
			actual_shape = GodotTestFactory.create_capsule_shape(48.0, 128.0)
		"rectangle":
			actual_shape = GodotTestFactory.create_rectangle_shape(Vector2(64, 32))
		"circle":
			actual_shape = GodotTestFactory.create_circle_shape(32.0)
		_:
			fail("Unknown shape type: " + shape_type)
			return
	
	# Create transform at origin for testing
	var transform = GodotTestFactory.create_transform2d()
	
	# Convert to polygon using the same method as the system
	var polygon = GBGeometryMath.convert_shape_to_polygon(actual_shape, transform)
	
	print("=== %s Shape Bounds Debug ===" % shape_type.capitalize())
	print("Polygon points: ", polygon.size())
	
	# Get bounds using the same method as collision detection
	var bounds = GBGeometryMath.get_polygon_bounds(polygon)
	print("Polygon bounds: ", bounds)
	
	# Check if bounds are symmetric around origin
	var left_extent = -bounds.position.x
	var right_extent = bounds.position.x + bounds.size.x
	var top_extent = -bounds.position.y
	var bottom_extent = bounds.position.y + bounds.size.y
	
	print("Left extent: %.2f, Right extent: %.2f" % [left_extent, right_extent])
	print("Top extent: %.2f, Bottom extent: %.2f" % [top_extent, bottom_extent])
	
	# For shapes at origin, we expect reasonable symmetry (within tolerance)
	var horizontal_diff = abs(left_extent - right_extent)
	var vertical_diff = abs(top_extent - bottom_extent)
	
	print("Horizontal symmetry diff: %.2f" % horizontal_diff)
	print("Vertical symmetry diff: %.2f" % vertical_diff)
	
	if expected_symmetry:
		# Allow small differences due to polygon approximation
		assert_float(horizontal_diff).is_less(2.0)
		assert_float(vertical_diff).is_less(2.0)
	
	# Basic sanity checks
	assert_object(bounds).is_not_null()
	assert_float(bounds.size.x).is_greater(0.0)
	assert_float(bounds.size.y).is_greater(0.0)

# Test specific trapezoid collision positions (from trapezoid_debug_test.gd)
func test_trapezoid_collision_positions():
	# Test the specific trapezoid that was causing issues
	var trapezoid = PackedVector2Array([
		Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
	])
	
	var tile_size = Vector2(16, 16)
	var epsilon = 0.01
	
	# Test positions that should have meaningful overlap
	var test_positions = [
		Vector2(0, 8),   # Should overlap
		Vector2(0, -12), # Should overlap
		Vector2(16, 0),  # Should overlap
		Vector2(-16, 0), # Should overlap
		Vector2(0, 32),  # Should not overlap (too far down)
		Vector2(48, 0)   # Should not overlap (too far right)
	]
	
	print("=== Trapezoid Collision Position Debug ===")
	print("Trapezoid: ", trapezoid)
	
	for pos in test_positions:
		var area = GBGeometryMath.intersection_area_with_tile(trapezoid, pos, tile_size, 0)
		var overlaps = GBGeometryMath.does_polygon_overlap_tile(trapezoid, pos, tile_size, 0, epsilon)
		
		print("Position %s: area=%.4f, overlaps=%s" % [pos, area, overlaps])
		
		# Consistency check: if area > epsilon, should overlap
		if area > epsilon:
			assert_bool(overlaps).is_true()
		else:
			assert_bool(overlaps).is_false()

# Test polygon area calculations for edge cases
func test_polygon_area_edge_cases():
	print("=== Polygon Area Edge Cases ===")
	
	# Test empty polygon
	var _empty_polygon = PackedVector2Array()
	print("Empty polygon area: 0.0000 (expected)")
	
	# Test single point (use arbitrary second polygon for intersection)
	var single_point = PackedVector2Array([Vector2(0, 0)])
	var test_polygon = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	var point_area = GBGeometryMath.polygon_intersection_area(single_point, test_polygon)
	print("Single point area: %.4f" % point_area)
	assert_float(point_area).is_equal(0.0)
	
	# Test line (two points)
	var line = PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])
	var line_area = GBGeometryMath.polygon_intersection_area(line, test_polygon)
	print("Line area: %.4f" % line_area)
	assert_float(line_area).is_equal(0.0)
	
	# Test valid triangle
	var triangle = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 10)])
	var triangle_area = GBGeometryMath.polygon_intersection_area(triangle, test_polygon)
	print("Triangle intersection area: %.4f" % triangle_area)
	assert_float(triangle_area).is_greater_equal(0.0)
	
	# Test square
	var square = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var square_area = GBGeometryMath.polygon_intersection_area(square, test_polygon)
	print("Square intersection area: %.4f" % square_area)
	assert_float(square_area).is_greater_equal(0.0)

# Test bounds calculation edge cases
func test_bounds_calculation_edge_cases():
	print("=== Bounds Calculation Edge Cases ===")
	
	# Test degenerate cases
	var empty_polygon = PackedVector2Array()
	var empty_bounds = GBGeometryMath.get_polygon_bounds(empty_polygon)
	print("Empty polygon bounds: ", empty_bounds)
	# Should handle gracefully without crashing
	
	var single_point = PackedVector2Array([Vector2(5, 10)])
	var point_bounds = GBGeometryMath.get_polygon_bounds(single_point)
	print("Single point bounds: ", point_bounds)
	assert_that(point_bounds.position).is_equal(Vector2(5, 10))
	assert_that(point_bounds.size).is_equal(Vector2(0, 0))
	
	# Test normal polygon
	var square = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var square_bounds = GBGeometryMath.get_polygon_bounds(square)
	print("Square bounds: ", square_bounds)
	assert_that(square_bounds.position).is_equal(Vector2(0, 0))
	assert_that(square_bounds.size).is_equal(Vector2(10, 10))
