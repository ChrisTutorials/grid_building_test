extends GdUnitTestSuite

## Comprehensive parameterized test suite for collision detection
## Consolidates functionality from multiple debug tests into a single, maintainable test file

## Test data for different collision shapes
var capsule_test_data := [
	{
		"name": "Small Capsule",
		"radius": 7.0,
		"height": 22.0,
		"expected_bounds": Rect2(-7, -11, 14, 22),
		"expected_tiles": Vector2i(1, 1)
	},
	{
		"name": "Medium Capsule", 
		"radius": 14.0,
		"height": 60.0,
		"expected_bounds": Rect2(-14, -30, 28, 60),
		"expected_tiles": Vector2i(2, 4)
	},
	{
		"name": "Large Capsule",
		"radius": 48.0,
		"height": 128.0,
		"expected_bounds": Rect2(-48, -64, 96, 128),
		"expected_tiles": Vector2i(6, 8)
	}
]

var trapezoid_test_data := [
	{
		"name": "Standard Trapezoid",
		"points": PackedVector2Array([
			Vector2(-32, 12),   # Bottom-left
			Vector2(-16, -12),  # Top-left
			Vector2(17, -12),   # Top-right
			Vector2(32, 12)     # Bottom-right
		]),
		"expected_bounds": Rect2(-32, -12, 64, 24),
		"expected_tiles": Vector2i(4, 2)
	},
	{
		"name": "Wide Trapezoid",
		"points": PackedVector2Array([
			Vector2(-48, 16),   # Bottom-left
			Vector2(-24, -16),  # Top-left
			Vector2(24, -16),   # Top-right
			Vector2(48, 16)     # Bottom-right
		]),
		"expected_bounds": Rect2(-48, -16, 96, 32),
		"expected_tiles": Vector2i(6, 2)
	}
]

## Test capsule shape bounds and tile coverage
@warning_ignore("unused_parameter")
func test_capsule_shape_validation(
	capsule_data: Dictionary,
	test_parameters := capsule_test_data
):
	var capsule_shape = CapsuleShape2D.new()
	capsule_shape.radius = capsule_data["radius"]
	capsule_shape.height = capsule_data["height"]

	# Test bounds calculation
	var transform = Transform2D()
	var polygon = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
	var bounds = GBGeometryMath.get_polygon_bounds(polygon)
	var expected = capsule_data["expected_bounds"]

	var tolerance = 1.0  # Allow floating point tolerance
	
	(
		assert_float(bounds.position.x)
		.append_failure_message("Left bound mismatch for %s" % capsule_data["name"])
		.is_equal_approx(expected.position.x, tolerance)
	)
	
	(
		assert_float(bounds.position.y)
		.append_failure_message("Top bound mismatch for %s" % capsule_data["name"])
		.is_equal_approx(expected.position.y, tolerance)
	)
	
	(
		assert_float(bounds.size.x)
		.append_failure_message("Width mismatch for %s" % capsule_data["name"])
		.is_equal_approx(expected.size.x, tolerance)
	)
	
	(
		assert_float(bounds.size.y)
		.append_failure_message("Height mismatch for %s" % capsule_data["name"])
		.is_equal_approx(expected.size.y, tolerance)
	)

	# Test tile coverage calculation
	var tile_size = Vector2(16, 16)
	var tiles_wide = int(ceil(bounds.size.x / tile_size.x))
	var tiles_high = int(ceil(bounds.size.y / tile_size.y))
	
	(
		assert_int(tiles_wide)
		.append_failure_message("%s width tile count mismatch" % capsule_data["name"])
		.is_equal(capsule_data["expected_tiles"].x)
	)
	
	(
		assert_int(tiles_high)
		.append_failure_message("%s height tile count mismatch" % capsule_data["name"])
		.is_equal(capsule_data["expected_tiles"].y)
	)

## Test trapezoid shape bounds and tile coverage
@warning_ignore("unused_parameter")
func test_trapezoid_shape_validation(
	trapezoid_data: Dictionary,
	test_parameters := trapezoid_test_data
):
	var trapezoid = trapezoid_data["points"]
	var bounds = GBGeometryMath.get_polygon_bounds(trapezoid)
	var expected = trapezoid_data["expected_bounds"]

	var tolerance = 1.0  # Allow floating point tolerance

	(
		assert_float(bounds.position.x)
		.append_failure_message("%s left bound mismatch" % trapezoid_data["name"])
		.is_equal_approx(expected.position.x, tolerance)
	)

	(
		assert_float(bounds.position.y)
		.append_failure_message("%s top bound mismatch" % trapezoid_data["name"])
		.is_equal_approx(expected.position.y, tolerance)
	)

	(
		assert_float(bounds.size.x)
		.append_failure_message("%s width mismatch" % trapezoid_data["name"])
		.is_equal_approx(expected.size.x, tolerance)
	)

	(
		assert_float(bounds.size.y)
		.append_failure_message("%s height mismatch" % trapezoid_data["name"])
		.is_equal_approx(expected.size.y, tolerance)
	)

	# Test tile coverage calculation
	var tile_size = Vector2(16, 16)
	var tiles_wide = int(ceil(bounds.size.x / tile_size.x))
	var tiles_high = int(ceil(bounds.size.y / tile_size.y))

	(
		assert_int(tiles_wide)
		.append_failure_message("%s width tile count mismatch" % trapezoid_data["name"])
		.is_equal(trapezoid_data["expected_tiles"].x)
	)

	(
		assert_int(tiles_high)
		.append_failure_message("%s height tile count mismatch" % trapezoid_data["name"])
		.is_equal(trapezoid_data["expected_tiles"].y)
	)

## Test collision detection with tiles for different shapes
@warning_ignore("unused_parameter")
func test_shape_tile_collision_detection(
	test_data: Dictionary,
	test_parameters := [
		{
			"name": "Capsule Center Tile",
			"shape_type": "capsule",
			"shape_data": {"radius": 14.0, "height": 60.0},
			"tile_offset": Vector2i(0, 0),
			"expected_overlap": true
		},
		{
			"name": "Capsule Edge Tile",
			"shape_type": "capsule", 
			"shape_data": {"radius": 14.0, "height": 60.0},
			"tile_offset": Vector2i(1, 0),
			"expected_overlap": true
		},
		{
			"name": "Trapezoid Center Tile",
			"shape_type": "trapezoid",
			"shape_data": {
				"points": PackedVector2Array([
					Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
				])
			},
			"tile_offset": Vector2i(0, 0),
			"expected_overlap": true
		},
		{
			"name": "Trapezoid Edge Tile",
			"shape_type": "trapezoid",
			"shape_data": {
				"points": PackedVector2Array([
					Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
				])
			},
			"tile_offset": Vector2i(2, 0),
			"expected_overlap": true
		}
	]
):
	var tile_size = Vector2(16, 16)
	var tile_pos = Vector2(
		test_data["tile_offset"].x * tile_size.x,
		test_data["tile_offset"].y * tile_size.y
	)
	
	var overlaps = false
	
	if test_data["shape_type"] == "capsule":
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = test_data["shape_data"]["radius"]
		capsule_shape.height = test_data["shape_data"]["height"]
		
		overlaps = GBGeometryMath.does_shape_overlap_tile_optimized(
			capsule_shape, Transform2D(), tile_pos, tile_size, 0.01
		)
	elif test_data["shape_type"] == "trapezoid":
		var trapezoid = test_data["shape_data"]["points"]
		var tile_area = tile_size.x * tile_size.y
		var epsilon = tile_area * 0.05
		
		var area = GBGeometryMath.intersection_area_with_tile(
			trapezoid, tile_pos, tile_size, 0
		)
		overlaps = area > epsilon

	(
		assert_bool(overlaps)
		.append_failure_message("%s should %s overlap" % [
			test_data["name"],
			"have" if test_data["expected_overlap"] else "not have"
		])
		.is_equal(test_data["expected_overlap"])
	)

## Test shape symmetry properties
@warning_ignore("unused_parameter")
func test_shape_symmetry_validation(
	shape_data: Dictionary,
	test_parameters := [
		{
			"name": "Small Capsule",
			"type": "capsule",
			"data": {"radius": 7.0, "height": 22.0}
		},
		{
			"name": "Medium Capsule",
			"type": "capsule", 
			"data": {"radius": 14.0, "height": 60.0}
		},
		{
			"name": "Standard Trapezoid",
			"type": "trapezoid",
			"data": {
				"points": PackedVector2Array([
					Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
				])
			}
		}
	]
):
	var bounds: Rect2
	
	if shape_data["type"] == "capsule":
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = shape_data["data"]["radius"]
		capsule_shape.height = shape_data["data"]["height"]
		
		var transform = Transform2D()
		var polygon = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
		bounds = GBGeometryMath.get_polygon_bounds(polygon)
	elif shape_data["type"] == "trapezoid":
		bounds = GBGeometryMath.get_polygon_bounds(shape_data["data"]["points"])

	# Check horizontal symmetry
	var left_extent = -bounds.position.x
	var right_extent = bounds.position.x + bounds.size.x
	var horizontal_difference = abs(left_extent - right_extent)
	
	(
		assert_float(horizontal_difference)
		.append_failure_message("%s should have symmetric horizontal bounds" % shape_data["name"])
		.is_less(1.0)
	)
	
	# Check vertical symmetry
	var top_extent = -bounds.position.y
	var bottom_extent = bounds.position.y + bounds.size.y
	var vertical_difference = abs(top_extent - bottom_extent)
	
	(
		assert_float(vertical_difference)
		.append_failure_message("%s should have symmetric vertical bounds" % shape_data["name"])
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
