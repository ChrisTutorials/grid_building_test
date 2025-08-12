extends GdUnitTestSuite

## Comprehensive test for shape collision detection and tile coverage
## Tests various collision shapes and verifies their tile coverage calculations

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

func before_test():
	# No setup needed for this test - it only tests geometry math functions
	pass

@warning_ignore("unused_parameter")
func test_shape_bounds_validation(
	shape_name: String,
	shape_type: String,
	radius: float,
	height: float,
	points: PackedVector2Array,
	expected_bounds: Rect2,
	test_parameters := [
		["Small Capsule", "capsule", 7.0, 22.0, PackedVector2Array(), Rect2(-7, -11, 14, 22)],
		["Medium Capsule", "capsule", 14.0, 60.0, PackedVector2Array(), Rect2(-14, -30, 28, 60)],
		["Large Capsule", "capsule", 48.0, 128.0, PackedVector2Array(), Rect2(-48, -64, 96, 128)],
		["Standard Trapezoid", "trapezoid", 0.0, 0.0, PackedVector2Array([
			Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
		]), Rect2(-32, -12, 64, 24)],
		["Wide Trapezoid", "trapezoid", 0.0, 0.0, PackedVector2Array([
			Vector2(-48, 16), Vector2(-24, -16), Vector2(24, -16), Vector2(48, 16)
		]), Rect2(-48, -16, 96, 32)]
	]
):
	var bounds: Rect2
	
	if shape_type == "capsule":
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = radius
		capsule_shape.height = height
		
		var transform = Transform2D()
		var polygon = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
		bounds = GBGeometryMath.get_polygon_bounds(polygon)
	elif shape_type == "trapezoid":
		bounds = GBGeometryMath.get_polygon_bounds(points)
	
	var expected = expected_bounds
	var tolerance = 1.0

	(
		assert_float(bounds.position.x)
		.append_failure_message("%s left bound mismatch" % shape_name)
		.is_equal_approx(expected.position.x, tolerance)
	)

	(
		assert_float(bounds.position.y)
		.append_failure_message("%s top bound mismatch" % shape_name)
		.is_equal_approx(expected.position.y, tolerance)
	)

	(
		assert_float(bounds.size.x)
		.append_failure_message("%s width mismatch" % shape_name)
		.is_equal_approx(expected.size.x, tolerance)
	)

	(
		assert_float(bounds.size.y)
		.append_failure_message("%s height mismatch" % shape_name)
		.is_equal_approx(expected.size.y, tolerance)
	)

## Test shape tile coverage calculation (parameterized)
## Parameters: case_name, shape_type, radius, height, points, expected_tiles
@warning_ignore("unused_parameter")
func test_shape_tile_coverage(
	case_name: String,
	shape_type: String,
	radius: float,
	height: float,
	points: PackedVector2Array,
	expected_tiles: Vector2i,
	test_parameters := [
		["Small Capsule", "capsule", 7.0, 22.0, PackedVector2Array(), Vector2i(1, 2)],
		["Medium Capsule", "capsule", 14.0, 60.0, PackedVector2Array(), Vector2i(2, 4)],
		["Large Capsule", "capsule", 48.0, 128.0, PackedVector2Array(), Vector2i(6, 8)],
		["Standard Trapezoid", "trapezoid", 0.0, 0.0, PackedVector2Array([
			Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
		]), Vector2i(4, 2)]
	]
):
	var bounds: Rect2
	if shape_type == "capsule":
		var capsule_shape := CapsuleShape2D.new()
		capsule_shape.radius = radius
		capsule_shape.height = height
		bounds = GBGeometryMath.get_polygon_bounds(GBGeometryMath.convert_shape_to_polygon(capsule_shape, Transform2D()))
	elif shape_type == "trapezoid":
		bounds = GBGeometryMath.get_polygon_bounds(points)

	var tile_size := Vector2(16, 16)
	var tiles_wide := int(ceil(bounds.size.x / tile_size.x))
	var tiles_high := int(ceil(bounds.size.y / tile_size.y))

	(assert_int(tiles_wide)
		.append_failure_message("%s width tile count mismatch" % case_name)
		.is_equal(expected_tiles.x))
	(assert_int(tiles_high)
		.append_failure_message("%s height tile count mismatch" % case_name)
		.is_equal(expected_tiles.y))

## Test shape collision detection with tiles (parameterized)
## Parameters: case_name, shape_type, radius, height, points, tile_offset, expected_overlap
@warning_ignore("unused_parameter")
func test_shape_tile_collision_detection(
	case_name: String,
	shape_type: String,
	radius: float,
	height: float,
	points: PackedVector2Array,
	tile_offset: Vector2i,
	expected_overlap: bool,
	test_parameters := [
		["Capsule Center Tile", "capsule", 14.0, 60.0, PackedVector2Array(), Vector2i(0,0), true],
		["Capsule Edge Tile", "capsule", 14.0, 60.0, PackedVector2Array(), Vector2i(1,0), false],
		["Capsule Corner Tile", "capsule", 14.0, 60.0, PackedVector2Array(), Vector2i(1,1), false],
		["Trapezoid Center Tile", "trapezoid", 0.0, 0.0, PackedVector2Array([
			Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
		]), Vector2i(0,0), true],
		["Trapezoid Edge Tile", "trapezoid", 0.0, 0.0, PackedVector2Array([
			Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
		]), Vector2i(2,0), true]
	]
):
	var tile_size := Vector2(16, 16)
	var tile_pos := Vector2(tile_offset.x * tile_size.x, tile_offset.y * tile_size.y)
	var overlaps := false
	if shape_type == "capsule":
		var capsule_shape := CapsuleShape2D.new()
		capsule_shape.radius = radius
		capsule_shape.height = height
		overlaps = GBGeometryMath.does_shape_overlap_tile_optimized(capsule_shape, Transform2D(), tile_pos, tile_size, 0.01)
	elif shape_type == "trapezoid":
		var tile_area := tile_size.x * tile_size.y
		var epsilon := tile_area * 0.05
		overlaps = GBGeometryMath.does_polygon_overlap_tile_optimized(points, tile_pos, tile_size, 0, epsilon)

	(assert_bool(overlaps)
		.append_failure_message("%s should %s overlap" % [
			case_name,
			"have" if expected_overlap else "not have"
		])
		.is_equal(expected_overlap))

## Test shape positioning and transformation (parameterized)
## Parameters: case_name, shape_type, radius, height, points, position, expected_center
@warning_ignore("unused_parameter")
func test_shape_positioning_validation(
	case_name: String,
	shape_type: String,
	radius: float,
	height: float,
	points: PackedVector2Array,
	position: Vector2,
	expected_center: Vector2,
	test_parameters := [
		["Capsule at Origin", "capsule", 14.0, 60.0, PackedVector2Array(), Vector2(0,0), Vector2(0,0)],
		["Capsule at Position", "capsule", 14.0, 60.0, PackedVector2Array(), Vector2(400,300), Vector2(400,300)],
		["Trapezoid at Position", "trapezoid", 0.0, 0.0, PackedVector2Array([
			Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
		]), Vector2(800,600), Vector2(800,600)]
	]
):
	var transform := Transform2D()
	transform.origin = position
	var bounds: Rect2
	if shape_type == "capsule":
		var capsule_shape := CapsuleShape2D.new()
		capsule_shape.radius = radius
		capsule_shape.height = height
		bounds = GBGeometryMath.get_polygon_bounds(GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform))
	elif shape_type == "trapezoid":
		var transformed_points := PackedVector2Array()
		for p in points:
			transformed_points.append(transform * p)
		bounds = GBGeometryMath.get_polygon_bounds(transformed_points)
	var actual_center := bounds.position + bounds.size / 2.0
	var tolerance := 1.0
	(assert_float(actual_center.x)
		.append_failure_message("%s center X mismatch" % case_name)
		.is_equal_approx(expected_center.x, tolerance))
	(assert_float(actual_center.y)
		.append_failure_message("%s center Y mismatch" % case_name)
		.is_equal_approx(expected_center.y, tolerance))
