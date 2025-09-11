extends GdUnitTestSuite

## Comprehensive test suite for GBGeometryMath functions across all tile shapes
## Tests square, isometric, and half-offset square tile shapes with parameterized test cases

#endregion
#region TILE POLYGON GENERATION TESTS

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
		["square_rectangular", TileSet.TILE_SHAPE_SQUARE, Vector2(0, 0), Vector2(24, 16), 4],
		
		# Isometric tiles
		["isometric_origin", TileSet.TILE_SHAPE_ISOMETRIC, Vector2(0, 0), Vector2(16, 16), 4],
		["isometric_offset", TileSet.TILE_SHAPE_ISOMETRIC, Vector2(32, 48), Vector2(16, 16), 4],
		["isometric_large", TileSet.TILE_SHAPE_ISOMETRIC, Vector2(0, 0), Vector2(32, 32), 4],
		["isometric_rectangular", TileSet.TILE_SHAPE_ISOMETRIC, Vector2(0, 0), Vector2(24, 16), 4],
		
		# Half-offset square tiles
		["half_offset_origin", TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, Vector2(0, 0), Vector2(16, 16), 4],
		["half_offset_offset", TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, Vector2(32, 48), Vector2(16, 16), 4],
		["half_offset_large", TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, Vector2(0, 0), Vector2(32, 32), 4],
		["half_offset_rectangular", TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, Vector2(0, 0), Vector2(24, 16), 4],
	]
) -> void:
	var tile_polygon: PackedVector2Array = GBGeometryMath.get_tile_polygon(tile_pos, tile_size, tile_shape)
	
	# Validate vertex count
	assert_int(tile_polygon.size()).append_failure_message(
		"Tile shape %s should have %d vertices, got %d" % [tile_shape_name, expected_vertex_count, tile_polygon.size()]
	).is_equal(expected_vertex_count)
	
	# Validate tile polygon is not empty
	assert_array(tile_polygon).append_failure_message(
		"Tile polygon for %s should not be empty" % tile_shape_name
	).is_not_empty()
	
	# Validate polygon bounds encompass expected area
	var bounds: Rect2 = GBGeometryMath.get_polygon_bounds(tile_polygon)
	if tile_shape == TileSet.TILE_SHAPE_ISOMETRIC:
		# Isometric diamonds should fit within the tile size bounding box
		assert_float(bounds.size.x).append_failure_message(
			"Isometric tile width should be tile_size.x, got %.2f" % bounds.size.x
		).is_equal_approx(tile_size.x, 0.1)
		assert_float(bounds.size.y).append_failure_message(
			"Isometric tile height should be tile_size.y, got %.2f" % bounds.size.y
		).is_equal_approx(tile_size.y, 0.1)
	else:
		# Square and half-offset square should exactly match tile size
		assert_float(bounds.size.x).append_failure_message(
			"Square/half-offset tile width should match tile_size.x, got %.2f" % bounds.size.x
		).is_equal_approx(tile_size.x, 0.1)
		assert_float(bounds.size.y).append_failure_message(
			"Square/half-offset tile height should match tile_size.y, got %.2f" % bounds.size.y
		).is_equal_approx(tile_size.y, 0.1)

#endregion
#region POLYGON INTERSECTION AREA TESTS

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
		["small_square_polygon_square_tile", PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, 60.0, 70.0],
		["small_square_polygon_isometric_tile", PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, 40.0, 70.0],
		["small_square_polygon_half_offset_tile", PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, 60.0, 70.0],
		
		# Center square polygon (should fully overlap with all tile types)
		["center_square_polygon_square_tile", PackedVector2Array([Vector2(6, 6), Vector2(10, 6), Vector2(10, 10), Vector2(6, 10)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, 15.0, 17.0],
		["center_square_polygon_isometric_tile", PackedVector2Array([Vector2(6, 6), Vector2(10, 6), Vector2(10, 10), Vector2(6, 10)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, 15.0, 17.0],
		["center_square_polygon_half_offset_tile", PackedVector2Array([Vector2(6, 6), Vector2(10, 6), Vector2(10, 10), Vector2(6, 10)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, 15.0, 17.0],
		
		# Large polygon overlapping multiple logical tiles
		["large_polygon_square_tile", PackedVector2Array([Vector2(-4, -4), Vector2(20, -4), Vector2(20, 20), Vector2(-4, 20)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, 240.0, 260.0],
		["large_polygon_isometric_tile", PackedVector2Array([Vector2(-4, -4), Vector2(20, -4), Vector2(20, 20), Vector2(-4, 20)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, 100.0, 140.0],
		["large_polygon_half_offset_tile", PackedVector2Array([Vector2(-4, -4), Vector2(20, -4), Vector2(20, 20), Vector2(-4, 20)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, 240.0, 260.0],
		
		# No overlap cases
		["no_overlap_square_tile", PackedVector2Array([Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, 0.0, 0.1],
		["no_overlap_isometric_tile", PackedVector2Array([Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, 0.0, 0.1],
		["no_overlap_half_offset_tile", PackedVector2Array([Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, 0.0, 0.1],
	]
) -> void:
	var intersection_area: float = GBGeometryMath.intersection_area_with_tile(polygon, tile_pos, tile_size, tile_shape)
	
	# Validate intersection area is within expected bounds
	assert_float(intersection_area).append_failure_message(
		"Intersection area for %s should be between %.2f and %.2f, got %.2f" % [test_case_name, expected_area_min, expected_area_max, intersection_area]
	).is_between(expected_area_min, expected_area_max)
	
	# Validate area is non-negative
	assert_float(intersection_area).append_failure_message(
		"Intersection area should never be negative, got %.2f for %s" % [intersection_area, test_case_name]
	).is_greater_equal(0.0)

#endregion
#region POLYGON OVERLAP DETECTION TESTS

@warning_ignore("unused_parameter")
func test_does_polygon_overlap_tile_for_all_shapes(
	test_case_name: String,
	polygon: PackedVector2Array,
	tile_pos: Vector2,
	tile_size: Vector2,
	tile_shape: TileSet.TileShape,
	epsilon: float,
	expected_overlap: bool,
	test_parameters := [
		# Overlapping cases
		["overlapping_square_square_tile", PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, 1.0, true],
		["overlapping_square_isometric_tile", PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, 1.0, true],
		["overlapping_square_half_offset_tile", PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, 1.0, true],
		
		# Non-overlapping cases
		["non_overlapping_square_tile", PackedVector2Array([Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, 1.0, false],
		["non_overlapping_isometric_tile", PackedVector2Array([Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, 1.0, false],
		["non_overlapping_half_offset_tile", PackedVector2Array([Vector2(20, 20), Vector2(24, 20), Vector2(24, 24), Vector2(20, 24)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, 1.0, false],
		
		# Edge cases with epsilon threshold
		["small_overlap_below_epsilon_square", PackedVector2Array([Vector2(15, 15), Vector2(17, 15), Vector2(17, 17), Vector2(15, 17)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, 10.0, false],
		["small_overlap_above_epsilon_square", PackedVector2Array([Vector2(12, 12), Vector2(20, 12), Vector2(20, 20), Vector2(12, 20)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, 1.0, true],
		
		# Diamond-shaped polygon with isometric tiles (should align well)
		["diamond_polygon_isometric_tile", PackedVector2Array([Vector2(8, 0), Vector2(16, 8), Vector2(8, 16), Vector2(0, 8)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, 1.0, true],
		["diamond_polygon_square_tile", PackedVector2Array([Vector2(8, 0), Vector2(16, 8), Vector2(8, 16), Vector2(0, 8)]), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, 1.0, true],

		# Additional cases mirroring PolygonTileMapper failing inputs
		["triangle_large_square_tile", PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 32)]), Vector2(0, 0), Vector2(32, 32), TileSet.TILE_SHAPE_SQUARE, 1.0, true],
		["triangle_large_isometric_tile", PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 32)]), Vector2(0, 0), Vector2(32, 32), TileSet.TILE_SHAPE_ISOMETRIC, 1.0, true],
		["rectangle_32x32_centered", PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]), Vector2(0, 0), Vector2(32, 32), TileSet.TILE_SHAPE_SQUARE, 1.0, true],
		["concave_indented_large", PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 16), Vector2(32, 32), Vector2(0, 32)]), Vector2(0, 0), Vector2(32, 32), TileSet.TILE_SHAPE_SQUARE, 1.0, true],
		["complex_star_shaped", PackedVector2Array([Vector2(8, 2), Vector2(12, 12), Vector2(22, 12), Vector2(14, 18), Vector2(18, 28), Vector2(8, 22), Vector2(-2, 28), Vector2(2, 18), Vector2(-6, 12), Vector2(4, 12)]), Vector2(0, 0), Vector2(32, 32), TileSet.TILE_SHAPE_SQUARE, 1.0, true],
	]
) -> void:
	var overlaps: bool = GBGeometryMath.does_polygon_overlap_tile(polygon, tile_pos, tile_size, tile_shape, epsilon)
	
	# Validate overlap detection
	assert_bool(overlaps).append_failure_message(
		"Overlap detection for %s should be %s, got %s" % [test_case_name, expected_overlap, overlaps]
	).is_equal(expected_overlap)

#endregion
#region OPTIMIZED SHAPE OVERLAP TESTS

@warning_ignore("unused_parameter")
func test_does_shape_overlap_tile_optimized_for_all_shapes(
	test_case_name: String,
	shape_type: String,
	shape_size: Vector2,
	shape_transform: Transform2D,
	tile_pos: Vector2,
	tile_size: Vector2,
	tile_shape: TileSet.TileShape,
	expected_overlap: bool,
	test_parameters := [
		# Rectangle overlaps
		["rect_overlap_square_tile", "rectangle", Vector2(8, 8), Transform2D(0, Vector2(8, 8)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, true],
		["rect_overlap_isometric_tile", "rectangle", Vector2(8, 8), Transform2D(0, Vector2(8, 8)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, true],
		["rect_overlap_half_offset_tile", "rectangle", Vector2(8, 8), Transform2D(0, Vector2(8, 8)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, true],
		
		# Rectangle non-overlaps
		["rect_no_overlap_square_tile", "rectangle", Vector2(4, 4), Transform2D(0, Vector2(20, 20)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, false],
		["rect_no_overlap_isometric_tile", "rectangle", Vector2(4, 4), Transform2D(0, Vector2(20, 20)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, false],
		["rect_no_overlap_half_offset_tile", "rectangle", Vector2(4, 4), Transform2D(0, Vector2(20, 20)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, false],
		
		# Circle overlaps
		["circle_overlap_square_tile", "circle", Vector2(6, 6), Transform2D(0, Vector2(8, 8)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, true],
		["circle_overlap_isometric_tile", "circle", Vector2(6, 6), Transform2D(0, Vector2(8, 8)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, true],
		["circle_overlap_half_offset_tile", "circle", Vector2(6, 6), Transform2D(0, Vector2(8, 8)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, true],
		
		# Circle non-overlaps
		["circle_no_overlap_square_tile", "circle", Vector2(2, 2), Transform2D(0, Vector2(20, 20)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_SQUARE, false],
		["circle_no_overlap_isometric_tile", "circle", Vector2(2, 2), Transform2D(0, Vector2(20, 20)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_ISOMETRIC, false],
		["circle_no_overlap_half_offset_tile", "circle", Vector2(2, 2), Transform2D(0, Vector2(20, 20)), Vector2(0, 0), Vector2(16, 16), TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE, false],
	]
) -> void:
	# Create the appropriate shape
	var shape: Shape2D
	match shape_type:
		"rectangle":
			var rect_shape: RectangleShape2D = RectangleShape2D.new()
			rect_shape.size = shape_size
			shape = rect_shape
		"circle":
			var circle_shape: CircleShape2D = CircleShape2D.new()
			circle_shape.radius = shape_size.x  # Use x component as radius
			shape = circle_shape
		_:
			assert_that(false).append_failure_message("Unknown shape type: %s" % shape_type).is_true()
			return
	
	var overlaps: bool = GBGeometryMath.does_shape_overlap_tile_optimized(shape, shape_transform, tile_pos, tile_size, tile_shape, 0.01)
	
	# Validate overlap detection
	assert_bool(overlaps).append_failure_message(
		"Optimized shape overlap for %s should be %s, got %s" % [test_case_name, expected_overlap, overlaps]
	).is_equal(expected_overlap)

#endregion
#region SHAPE TO POLYGON CONVERSION TESTS

@warning_ignore("unused_parameter")
func test_convert_shape_to_polygon_for_all_types(
	shape_description : String,
	shape_type: String,
	shape_size: Vector2,
	transform: Transform2D,
	expected_min_vertices: int,
	test_parameters := [
		# Rectangle shapes
		["rectangle_16x16", "rectangle", Vector2(16, 16), Transform2D.IDENTITY, 4],
		["rectangle_32x16", "rectangle", Vector2(32, 16), Transform2D.IDENTITY, 4],
		["rectangle_rotated", "rectangle", Vector2(16, 16), Transform2D(PI/4, Vector2.ZERO), 4],
		
		# Circle shapes
		["circle_r8", "circle", Vector2(8, 8), Transform2D.IDENTITY, 16],
		["circle_r16", "circle", Vector2(16, 16), Transform2D.IDENTITY, 16],
		["circle_offset", "circle", Vector2(8, 8), Transform2D(0, Vector2(10, 10)), 16],
		
		# Capsule shapes
		["capsule_8x16", "capsule", Vector2(8, 16), Transform2D.IDENTITY, 24],
		["capsule_16x32", "capsule", Vector2(16, 32), Transform2D.IDENTITY, 24],
		["capsule_rotated", "capsule", Vector2(8, 16), Transform2D(PI/2, Vector2.ZERO), 24],
	]
) -> void:
	# Create the appropriate shape
	var shape: Shape2D
	match shape_type:
		"rectangle":
			var rect_shape: RectangleShape2D = RectangleShape2D.new()
			rect_shape.size = shape_size
			shape = rect_shape
		"circle":
			var circle_shape: CircleShape2D = CircleShape2D.new()
			circle_shape.radius = shape_size.x  # Use x component as radius
			shape = circle_shape
		"capsule":
			var capsule_shape: CapsuleShape2D = CapsuleShape2D.new()
			capsule_shape.radius = shape_size.x
			capsule_shape.height = shape_size.y
			shape = capsule_shape
		_:
			assert_that(false).append_failure_message("Unknown shape type: %s" % shape_type).is_true()
			return
	
	var polygon: PackedVector2Array = GBGeometryMath.convert_shape_to_polygon(shape, transform)
	
	# Validate polygon has expected minimum vertices
	assert_int(polygon.size()).append_failure_message(
		"Shape %s should have at least %d vertices, got %d" % [shape_type, expected_min_vertices, polygon.size()]
	).is_greater_equal(expected_min_vertices)
	
	# Validate polygon is not empty
	assert_array(polygon).append_failure_message(
		"Converted polygon for %s should not be empty" % shape_type
	).is_not_empty()
	
	# Validate polygon bounds are reasonable
	var bounds: Rect2 = GBGeometryMath.get_polygon_bounds(polygon)
	assert_float(bounds.size.x).append_failure_message(
		"Polygon bounds width should be positive for %s" % shape_type
	).is_greater(0.0)
	assert_float(bounds.size.y).append_failure_message(
		"Polygon bounds height should be positive for %s" % shape_type
	).is_greater(0.0)

#endregion
#region UTILITY FUNCTION TESTS

@warning_ignore("unused_parameter")
func test_get_polygon_bounds_edge_cases() -> void:
	# Empty polygon
	var empty_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(PackedVector2Array())
	assert_that(empty_bounds).is_equal(Rect2())
	
	# Single point
	var single_point_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(PackedVector2Array([Vector2(5, 10)]))
	assert_that(single_point_bounds.position).is_equal_approx(Vector2(5, 10), Vector2(0.1, 0.1))
	assert_that(single_point_bounds.size).is_equal_approx(Vector2.ZERO, Vector2(0.1, 0.1))
	
	# Multiple points
	var multi_point_bounds: Rect2 = GBGeometryMath.get_polygon_bounds(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]))
	assert_that(multi_point_bounds.position).is_equal_approx(Vector2.ZERO, Vector2(0.1, 0.1))
	assert_that(multi_point_bounds.size).is_equal_approx(Vector2(10, 10), Vector2(0.1, 0.1))

@warning_ignore("unused_parameter")
func test_polygon_intersection_area_edge_cases() -> void:
	# Empty polygons
	var area1: float = GBGeometryMath.polygon_intersection_area(PackedVector2Array(), PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]))
	assert_that(area1).is_equal(0.0)
	
	# Identical polygons
	var poly: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var area2: float = GBGeometryMath.polygon_intersection_area(poly, poly)
	assert_that(area2).is_equal(100.0)
	
	# Non-overlapping polygons
	var poly1: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5, 5), Vector2(0, 5)])
	var poly2: PackedVector2Array = PackedVector2Array([Vector2(10, 10), Vector2(15, 10), Vector2(15, 15), Vector2(10, 15)])
	var area3: float = GBGeometryMath.polygon_intersection_area(poly1, poly2)
	assert_that(area3).is_equal(0.0)
