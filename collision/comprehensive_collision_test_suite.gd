extends GBTestBase

## Comprehensive parameterized test suite for collision detection
## Consolidates functionality from multiple debug tests into a single, maintainable test file

## Test data for different collision shapes

func before_test():
	setup_common_container()

## Test capsule shape bounds and tile coverage (parameterized)
## Parameters: name, radius, height, expected_bounds, expected_tiles
@warning_ignore("unused_parameter")
func test_capsule_shape_validation(
	case_name: String,
	radius: float,
	height: float,
	expected_bounds: Rect2,
	expected_tiles: Vector2i,
	test_parameters := [
		["Small Capsule", 7.0, 22.0, Rect2(-7, -11, 14, 22), Vector2i(1, 1)],
		["Medium Capsule", 14.0, 60.0, Rect2(-14, -30, 28, 60), Vector2i(2, 4)],
		["Large Capsule", 48.0, 128.0, Rect2(-48, -64, 96, 128), Vector2i(6, 8)]
	]
):
	var capsule_shape := CapsuleShape2D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height

	# Bounds
	var polygon := GBGeometryMath.convert_shape_to_polygon(capsule_shape, Transform2D())
	var bounds := GBGeometryMath.get_polygon_bounds(polygon)
	var tolerance := 1.0

	(assert_float(bounds.position.x)
		.append_failure_message("Left bound mismatch for %s" % case_name)
		.is_equal_approx(expected_bounds.position.x, tolerance))
	(assert_float(bounds.position.y)
		.append_failure_message("Top bound mismatch for %s" % case_name)
		.is_equal_approx(expected_bounds.position.y, tolerance))
	(assert_float(bounds.size.x)
		.append_failure_message("Width mismatch for %s" % case_name)
		.is_equal_approx(expected_bounds.size.x, tolerance))
	(assert_float(bounds.size.y)
		.append_failure_message("Height mismatch for %s" % case_name)
		.is_equal_approx(expected_bounds.size.y, tolerance))

	# Tile coverage
	var tile_size := Vector2(16, 16)
	var tiles_wide := int(ceil(bounds.size.x / tile_size.x))
	var tiles_high := int(ceil(bounds.size.y / tile_size.y))

	(assert_int(tiles_wide)
		.append_failure_message("%s width tile count mismatch" % case_name)
		.is_equal(expected_tiles.x))
	(assert_int(tiles_high)
		.append_failure_message("%s height tile count mismatch" % case_name)
		.is_equal(expected_tiles.y))

## Test trapezoid shape bounds and tile coverage (parameterized)
## Parameters: name, points, expected_bounds, expected_tiles
@warning_ignore("unused_parameter")
func test_trapezoid_shape_validation(
	case_name: String,
	points: PackedVector2Array,
	expected_bounds: Rect2,
	expected_tiles: Vector2i,
	test_parameters := [
		["Standard Trapezoid", PackedVector2Array([
			Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
		]), Rect2(-32, -12, 64, 24), Vector2i(4, 2)],
		["Wide Trapezoid", PackedVector2Array([
			Vector2(-48, 16), Vector2(-24, -16), Vector2(24, -16), Vector2(48, 16)
		]), Rect2(-48, -16, 96, 32), Vector2i(6, 2)]
	]
):
	var bounds := GBGeometryMath.get_polygon_bounds(points)
	var tolerance := 1.0

	(assert_float(bounds.position.x)
		.append_failure_message("%s left bound mismatch" % case_name)
		.is_equal_approx(expected_bounds.position.x, tolerance))
	(assert_float(bounds.position.y)
		.append_failure_message("%s top bound mismatch" % case_name)
		.is_equal_approx(expected_bounds.position.y, tolerance))
	(assert_float(bounds.size.x)
		.append_failure_message("%s width mismatch" % case_name)
		.is_equal_approx(expected_bounds.size.x, tolerance))
	(assert_float(bounds.size.y)
		.append_failure_message("%s height mismatch" % case_name)
		.is_equal_approx(expected_bounds.size.y, tolerance))

	var tile_size := Vector2(16, 16)
	var tiles_wide := int(ceil(bounds.size.x / tile_size.x))
	var tiles_high := int(ceil(bounds.size.y / tile_size.y))

	(assert_int(tiles_wide)
		.append_failure_message("%s width tile count mismatch" % case_name)
		.is_equal(expected_tiles.x))
	(assert_int(tiles_high)
		.append_failure_message("%s height tile count mismatch" % case_name)
		.is_equal(expected_tiles.y))

## Test collision detection with tiles for different shapes (parameterized)
## Parameters: name, shape_type, radius, height, points, tile_offset, expected_overlap
## For trapezoid rows radius/height are 0; for capsule rows points is empty
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
		["Capsule Edge Tile", "capsule", 14.0, 60.0, PackedVector2Array(), Vector2i(1,0), true],
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
		var area := GBGeometryMath.intersection_area_with_tile(points, tile_pos, tile_size, 0)
		overlaps = area > epsilon

	(assert_bool(overlaps)
		.append_failure_message("%s should %s overlap" % [
			case_name,
			"have" if expected_overlap else "not have"
		])
		.is_equal(expected_overlap))

## Test shape symmetry properties (parameterized)
## Parameters: name, shape_type, radius, height, points
@warning_ignore("unused_parameter")
func test_shape_symmetry_validation(
	case_name: String,
	shape_type: String,
	radius: float,
	height: float,
	points: PackedVector2Array,
	test_parameters := [
		["Small Capsule", "capsule", 7.0, 22.0, PackedVector2Array()],
		["Medium Capsule", "capsule", 14.0, 60.0, PackedVector2Array()],
		["Standard Trapezoid", "trapezoid", 0.0, 0.0, PackedVector2Array([
			Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
		])]
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

	var left_extent := -bounds.position.x
	var right_extent := bounds.position.x + bounds.size.x
	var horizontal_difference: float = abs(left_extent - right_extent)
	(assert_float(horizontal_difference)
		.append_failure_message("%s should have symmetric horizontal bounds" % case_name)
		.is_less(1.0))

	var top_extent := -bounds.position.y
	var bottom_extent := bounds.position.y + bounds.size.y
	var vertical_difference: float = abs(top_extent - bottom_extent)
	(assert_float(vertical_difference)
		.append_failure_message("%s should have symmetric vertical bounds" % case_name)
		.is_less(1.0))

## Test performance of collision detection methods
func test_collision_detection_performance():
	var capsule_shape = CapsuleShape2D.new()
	capsule_shape.radius = 48.0
	capsule_shape.height = 128.0
	
	var tile_size = Vector2(16, 16)
	var test_positions = []
	
	# Generate test positions in a grid
	for x in range(-10, 11):
		for y in range(-10, 11):
			test_positions.append(Vector2(x * tile_size.x, y * tile_size.y))
	
	var start_time = Time.get_ticks_msec()
	
	# Test optimized collision detection
	for pos in test_positions:
		GBGeometryMath.does_shape_overlap_tile_optimized(
			capsule_shape, Transform2D(), pos, tile_size, 0.01
		)
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Performance assertion - should complete within reasonable time
	(
		assert_int(duration)
		.append_failure_message("Collision detection took %dms for %d positions" % [duration, test_positions.size()])
		.is_less(100)  # Should complete in under 100ms
	)
