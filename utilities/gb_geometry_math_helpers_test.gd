## GdUnit TestSuite for GBGeometryMathHelpers
extends GdUnitTestSuite


## Parameterized test for is_exact_polygon_match
@warning_ignore("unused_parameter")
func test_is_exact_polygon_match_param(
	poly_a: PackedVector2Array,
	poly_b: PackedVector2Array,
	expected: bool,
	test_parameters := [
		[
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]),
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]),
			true
		],
		[
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]),
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(2, 1)]),
			false
		],
		[
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0)]),
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]),
			false
		],
	]
):
	assert_bool(GBGeometryMathHelpers.is_exact_polygon_match(poly_a, poly_b)).is_equal(expected)


## Parameterized test for exact_polygon_area
@warning_ignore("unused_parameter")
func test_exact_polygon_area_param(
	poly: PackedVector2Array,
	expected: float,
	test_parameters := [
		[PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 3)]), 6.0],  # Right triangle
		[PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 3), Vector2(0, 3)]), 12.0],  # Rectangle
		[PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]), 0.5],  # Small triangle
		[PackedVector2Array([]), 0.0],  # Empty
	]
):
	assert_float(GBGeometryMathHelpers.exact_polygon_area(poly)).is_equal_approx(expected, 0.01)


## Parameterized test for isometric_floating_point_fallback
@warning_ignore("unused_parameter")
func test_isometric_floating_point_fallback_param(
	tile_poly: PackedVector2Array,
	polygon: PackedVector2Array,
	expected: float,
	test_parameters := [
		[
			PackedVector2Array([Vector2(8, 0), Vector2(16, 8), Vector2(8, 16), Vector2(0, 8)]),
			PackedVector2Array([Vector2(8, 0), Vector2(16, 8), Vector2(8, 16), Vector2(0, 8)]),
			128.0
		],  # Exactly identical
		[
			PackedVector2Array([Vector2(8, 0), Vector2(16, 8), Vector2(8, 16), Vector2(0, 8)]),
			PackedVector2Array([Vector2(12, 4), Vector2(20, 12), Vector2(12, 20), Vector2(4, 12)]),
			0.0
		],  # Not close
	]
):
	(
		assert_float(GBGeometryMathHelpers.isometric_floating_point_fallback(tile_poly, polygon))
		. is_equal_approx(expected, 0.01)
	)


## Parameterized test for square_bounding_box_fallback
@warning_ignore("unused_parameter")
func test_square_bounding_box_fallback_param(
	tile_poly: PackedVector2Array,
	polygon: PackedVector2Array,
	expected: float,
	test_parameters := [
		[
			PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)]),
			PackedVector2Array([Vector2(1, 1), Vector2(3, 1), Vector2(3, 3), Vector2(1, 3)]),
			1.0
		],  # Partial overlap
		[
			PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)]),
			PackedVector2Array([Vector2(3, 3), Vector2(4, 3), Vector2(4, 4), Vector2(3, 4)]),
			0.0
		],  # No overlap
	]
):
	(
		assert_float(GBGeometryMathHelpers.square_bounding_box_fallback(tile_poly, polygon))
		. is_equal_approx(expected, 0.01)
	)
