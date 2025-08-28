extends GdUnitTestSuite

## Comprehensive parameterized test suite for collision detection
## Consolidates functionality from multiple debug tests into a single, maintainable test file

## Test data for different collision shapes

var test_container : GBCompositionContainer = load("uid://dy6e5p5d6ax6n")

func before_test():
	# Use the unified test factory to get a proper test container
	test_container = UnifiedTestFactory.TEST_CONTAINER.duplicate(true)

## Test capsule shape bounds and tile coverage
@warning_ignore("unused_parameter")
func test_capsule_shape_validation(
	case_name: String,
	radius: float,
	height: float,
	expected_bounds: Rect2,
	expected_tiles: Vector2i,
	test_parameters := [
		["Small Capsule", 7.0, 22.0, Rect2(-7, -11, 14, 22), Vector2i(1, 2)],
		["Medium Capsule", 14.0, 60.0, Rect2(-14, -30, 28, 60), Vector2i(2, 4)],
		["Large Capsule", 48.0, 128.0, Rect2(-48, -64, 96, 128), Vector2i(6, 8)]
	]
):
	var capsule_shape = CapsuleShape2D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height

	# Test bounds calculation
	var transform = Transform2D()
	var polygon = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
	var bounds = GBGeometryMath.get_polygon_bounds(polygon)

	var tolerance = 1.0  # Allow floating point tolerance
	
	(
		assert_float(bounds.position.x)
		.append_failure_message("Left bound mismatch for %s" % case_name)
		.is_equal_approx(expected_bounds.position.x, tolerance)
	)
	
	(
		assert_float(bounds.position.y)
		.append_failure_message("Top bound mismatch for %s" % case_name)
		.is_equal_approx(expected_bounds.position.y, tolerance)
	)
	
	(
		assert_float(bounds.size.x)
		.append_failure_message("Width mismatch for %s" % case_name)
		.is_equal_approx(expected_bounds.size.x, tolerance)
	)
	
	(
		assert_float(bounds.size.y)
		.append_failure_message("Height mismatch for %s" % case_name)
		.is_equal_approx(expected_bounds.size.y, tolerance)
	)

	# Test tile coverage calculation
	var tile_size = Vector2(16, 16)
	var tiles_wide = int(ceil(bounds.size.x / tile_size.x))
	var tiles_high = int(ceil(bounds.size.y / tile_size.y))
	
	(
		assert_int(tiles_wide)
		.append_failure_message("%s width tile count mismatch" % case_name)
		.is_equal(expected_tiles.x)
	)
	
	(
		assert_int(tiles_high)
		.append_failure_message("%s height tile count mismatch" % case_name)
		.is_equal(expected_tiles.y)
	)

## Test trapezoid shape bounds and tile coverage
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
	var bounds = GBGeometryMath.get_polygon_bounds(points)

	var tolerance = 1.0  # Allow floating point tolerance
	
	(
		assert_float(bounds.position.x)
		.append_failure_message("%s left bound mismatch" % case_name)
		.is_equal_approx(expected_bounds.position.x, tolerance)
	)
	
	(
		assert_float(bounds.position.y)
		.append_failure_message("%s top bound mismatch" % case_name)
		.is_equal_approx(expected_bounds.position.y, tolerance)
	)
	
	(
		assert_float(bounds.size.x)
		.append_failure_message("%s width mismatch" % case_name)
		.is_equal_approx(expected_bounds.size.x, tolerance)
	)
	
	(
		assert_float(bounds.size.y)
		.append_failure_message("%s height mismatch" % case_name)
		.is_equal_approx(expected_bounds.size.y, tolerance)
	)

	var tile_size = Vector2(16, 16)
	var tiles_wide = int(ceil(bounds.size.x / tile_size.x))
	var tiles_high = int(ceil(bounds.size.y / tile_size.y))

	(
		assert_int(tiles_wide)
		.append_failure_message("%s width tile count mismatch" % case_name)
		.is_equal(expected_tiles.x)
	)
	
	(
		assert_int(tiles_high)
		.append_failure_message("%s height tile count mismatch" % case_name)
		.is_equal(expected_tiles.y)
	)

## Test collision detection with tiles for different shapes
@warning_ignore("unused_parameter")
func test_shape_tile_collision_detection(
	case_name: String,
	shape_type: String,
	shape_data: Dictionary,
	tile_offset: Vector2i,
	expected_overlap: bool,
	test_parameters := [
		["Capsule Center Tile", "capsule", {"radius": 14.0, "height": 60.0}, Vector2i(0, 0), true],
		["Capsule Edge Tile", "capsule", {"radius": 14.0, "height": 60.0}, Vector2i(0, 1), true],
		["Trapezoid Center Tile", "trapezoid", {
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			])
		}, Vector2i(0, 0), true],
		["Trapezoid Edge Tile", "trapezoid", {
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			])
		}, Vector2i(1, 0), true]
	]
):
	var tile_size = Vector2(16, 16)
	var tile_pos = Vector2(
		tile_offset.x * tile_size.x,
		tile_offset.y * tile_size.y
	)
	
	var overlaps = false
	
	if shape_type == "capsule":
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = shape_data["radius"]
		capsule_shape.height = shape_data["height"]
		
		overlaps = GBGeometryMath.does_shape_overlap_tile_optimized(
			capsule_shape, Transform2D(), tile_pos, tile_size, 0.01
		)
	elif shape_type == "trapezoid":
		var trapezoid = shape_data["points"]
		var tile_area = tile_size.x * tile_size.y
		var epsilon = tile_area * 0.05
		
		var area = GBGeometryMath.intersection_area_with_tile(
			trapezoid, tile_pos, tile_size, 0
		)
		overlaps = area > epsilon

	(
		assert_bool(overlaps)
		.append_failure_message("%s should %s overlap" % [
			case_name,
			"have" if expected_overlap else "not have"
		])
		.is_equal(expected_overlap)
	)

## Test shape symmetry properties
@warning_ignore("unused_parameter")
func test_shape_symmetry_validation(
	case_name: String,
	shape_type: String,
	shape_data: Dictionary,
	test_parameters := [
		["Small Capsule", "capsule", {"radius": 7.0, "height": 22.0}],
		["Medium Capsule", "capsule", {"radius": 14.0, "height": 60.0}],
		["Standard Trapezoid", "trapezoid", {
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			])
		}]
	]
):
	var bounds: Rect2
	
	if shape_type == "capsule":
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = shape_data["radius"]
		capsule_shape.height = shape_data["height"]
		
		var transform = Transform2D()
		var polygon = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
		bounds = GBGeometryMath.get_polygon_bounds(polygon)
	elif shape_type == "trapezoid":
		bounds = GBGeometryMath.get_polygon_bounds(shape_data["points"])

	# Check horizontal symmetry
	var left_extent = -bounds.position.x
	var right_extent = bounds.position.x + bounds.size.x
	var horizontal_difference = abs(left_extent - right_extent)
	
	(
		assert_float(horizontal_difference)
		.append_failure_message("%s should have symmetric horizontal bounds" % case_name)
		.is_less(1.0)
	)
	
	# Check vertical symmetry
	var top_extent = -bounds.position.y
	var bottom_extent = bounds.position.y + bounds.size.y
	var vertical_difference = abs(top_extent - bottom_extent)
	
	(
		assert_float(vertical_difference)
		.append_failure_message("%s should have symmetric vertical bounds" % case_name)
		.is_less(1.0)
	)

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
