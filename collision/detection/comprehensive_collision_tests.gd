extends GdUnitTestSuite

## Comprehensive parameterized test suite for collision detection
## Consolidates functionality from multiple debug tests into a single, maintainable test file

## Use centralized GBTestConstants for shared values
const TILE_SIZE: Vector2 = GBTestConstants.DEFAULT_TILE_SIZE
var BOUNDS_TOLERANCE: float = 1.0  # kept as a runtime var for tolerance
const OVERLAP_EPSILON_RATIO: float = 0.05
var PERFORMANCE_TIMEOUT_MS: int = GBTestConstants.TEST_TIMEOUT_MS

## Test data for different collision shapes

enum TestShapeType {
	CAPSULE,
	TRAPEZOID
}

var test_container : GBCompositionContainer

## Helper functions for test maintainability

## Asserts that two Rect2 bounds are approximately equal within tolerance
func _assert_bounds_equal(actual: Rect2, expected: Rect2, case_name: String, tolerance: float = BOUNDS_TOLERANCE) -> void:
	(
		assert_float(actual.position.x)
		.append_failure_message("Left bound mismatch for %s" % case_name)
		.is_equal_approx(expected.position.x, tolerance)
	)
	
	(
		assert_float(actual.position.y)
		.append_failure_message("Top bound mismatch for %s" % case_name)
		.is_equal_approx(expected.position.y, tolerance)
	)
	
	(
		assert_float(actual.size.x)
		.append_failure_message("Width mismatch for %s" % case_name)
		.is_equal_approx(expected.size.x, tolerance)
	)
	
	(
		assert_float(actual.size.y)
		.append_failure_message("Height mismatch for %s" % case_name)
		.is_equal_approx(expected.size.y, tolerance)
	)

## Calculates tile coverage for given bounds
func _calculate_tile_coverage(bounds: Rect2, tile_size: Vector2 = TILE_SIZE) -> Vector2i:
	var tiles_wide: int = int(ceil(bounds.size.x / tile_size.x))
	var tiles_high: int = int(ceil(bounds.size.y / tile_size.y))
	return Vector2i(tiles_wide, tiles_high)

## Asserts tile coverage matches expected values
func _assert_tile_coverage(bounds: Rect2, expected_tiles: Vector2i, case_name: String, tile_size: Vector2 = TILE_SIZE) -> void:
	var actual_tiles: Vector2i = _calculate_tile_coverage(bounds, tile_size)
	
	(
		assert_int(actual_tiles.x)
		.append_failure_message("%s width tile count mismatch" % case_name)
		.is_equal(expected_tiles.x)
	)
	
## Generates a grid of test positions for performance testing
func _generate_test_positions(grid_size: int = 21, tile_size: Vector2 = TILE_SIZE) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var half: int = int(floor((grid_size - 1) / 2.0))  # For grid_size=21, half=10
	for x in range(-half, half + 1):
		for y in range(-half, half + 1):
			positions.append(Vector2(x * tile_size.x, y * tile_size.y))
	return positions

func before_test() -> void:
	# Create test injector to get isolated container for this test
	var temp_injector := GBInjectorSystem.new(GBTestConstants.TEST_COMPOSITION_CONTAINER)
	test_container = temp_injector.get_container()

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
) -> void:
	var capsule_shape := CapsuleShape2D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height

	# Test bounds calculation
	var transform := Transform2D()
	var polygon : PackedVector2Array = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
	var bounds : Rect2 = GBGeometryMath.get_polygon_bounds(polygon)

	var tolerance : float = BOUNDS_TOLERANCE  # Allow floating point tolerance
	
	_assert_bounds_equal(bounds, expected_bounds, case_name, tolerance)

	# Test tile coverage calculation
	_assert_tile_coverage(bounds, expected_tiles, case_name)

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
) -> void:
	var bounds: Rect2 = GBGeometryMath.get_polygon_bounds(points)

	var tolerance: float = BOUNDS_TOLERANCE  # Allow floating point tolerance
	
	_assert_bounds_equal(bounds, expected_bounds, case_name, tolerance)

	_assert_tile_coverage(bounds, expected_tiles, case_name)

## Test collision detection with tiles for different shapes
@warning_ignore("unused_parameter")
func test_shape_tile_collision_detection(
	case_name: String,
	shape_type: TestShapeType,
	shape_data: Dictionary,
	tile_offset: Vector2i,
	tile_shape: TileSet.TileShape,
	expected_overlap: bool,
	test_parameters := [
		["Capsule Center Tile", TestShapeType.CAPSULE, {"radius": 14.0, "height": 60.0}, Vector2i(0, 0), TileSet.TILE_SHAPE_SQUARE, true],
		["Capsule Edge Tile", TestShapeType.CAPSULE, {"radius": 14.0, "height": 60.0}, Vector2i(0, 1), TileSet.TILE_SHAPE_SQUARE, true],
		["Trapezoid Center Tile", TestShapeType.TRAPEZOID, {
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			])
		}, Vector2i(0, 0), 0, true],
		["Trapezoid Edge Tile", TestShapeType.TRAPEZOID, {
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			])
		}, Vector2i(1, 0), 0, true]
	]
) -> void:
	var tile_size: Vector2 = TILE_SIZE
	var tile_pos: Vector2 = Vector2(tile_offset.x * TILE_SIZE.x, tile_offset.y * TILE_SIZE.y)
	
	var overlaps: bool = false
	
	match shape_type:
		TestShapeType.CAPSULE:
			var capsule_shape: CapsuleShape2D = CapsuleShape2D.new()
			capsule_shape.radius = shape_data["radius"]
			capsule_shape.height = shape_data["height"]
			overlaps = GBGeometryMath.does_shape_overlap_tile_optimized(
				capsule_shape, Transform2D(), tile_pos, tile_size, tile_shape, 0.01
			)
		TestShapeType.TRAPEZOID:
			var trapezoid: PackedVector2Array = shape_data["points"]
			var tile_area: float = tile_size.x * tile_size.y
			var epsilon: float = tile_area * OVERLAP_EPSILON_RATIO

			var area: float = GBGeometryMath.intersection_area_with_tile(
				trapezoid, tile_pos, tile_size, tile_shape
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
	shape_type: TestShapeType,
	shape_data: Dictionary,
	test_parameters := [
		["Small Capsule", TestShapeType.CAPSULE, {"radius": 7.0, "height": 22.0}],
		["Medium Capsule", TestShapeType.CAPSULE, {"radius": 14.0, "height": 60.0}],
		["Standard Trapezoid", TestShapeType.TRAPEZOID, {
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			])
		}]
	]
) -> void:
	var bounds: Rect2
	
	if shape_type == TestShapeType.CAPSULE:
		var capsule_shape: CapsuleShape2D = CapsuleShape2D.new()
		capsule_shape.radius = shape_data["radius"]
		capsule_shape.height = shape_data["height"]
		
		var transform: Transform2D = Transform2D()
		var polygon: PackedVector2Array = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
		bounds = GBGeometryMath.get_polygon_bounds(polygon)
	elif shape_type == TestShapeType.TRAPEZOID:
		bounds = GBGeometryMath.get_polygon_bounds(shape_data["points"])

	# Check horizontal symmetry
	var left_extent: float = -bounds.position.x
	var right_extent: float = bounds.position.x + bounds.size.x
	var horizontal_difference: float = abs(left_extent - right_extent)
	
	(
		assert_float(horizontal_difference)
		.append_failure_message("%s should have symmetric horizontal bounds" % case_name)
		.is_less(1.0)
	)
	
	# Check vertical symmetry
	var top_extent: float = -bounds.position.y
	var bottom_extent: float = bounds.position.y + bounds.size.y
	var vertical_difference: float = abs(top_extent - bottom_extent)
	
	(
		assert_float(vertical_difference)
		.append_failure_message("%s should have symmetric vertical bounds" % case_name)
		.is_less(1.0)
	)

## Test performance of collision detection methods
func test_collision_detection_performance() -> void:
	var capsule_shape: CapsuleShape2D = CapsuleShape2D.new()
	capsule_shape.radius = 48.0
	capsule_shape.height = 128.0
	
	var tile_size: Vector2 = TILE_SIZE
	var test_positions: Array[Vector2] = _generate_test_positions()
	
	var start_time: int = Time.get_ticks_msec()
	
	# Test optimized collision detection
	for pos: Vector2 in test_positions:
		GBGeometryMath.does_shape_overlap_tile_optimized(
			capsule_shape, Transform2D(), pos, tile_size, TileSet.TILE_SHAPE_SQUARE, 0
		)
	
	var end_time: int = Time.get_ticks_msec()
	var duration: int = end_time - start_time
	
	# Performance assertion - should complete within reasonable time
	(
		assert_int(duration)
		.append_failure_message("Collision detection took %dms for %d positions" % [duration, test_positions.size()])
		.is_less(PERFORMANCE_TIMEOUT_MS)  # Should complete in under 100ms
	)
