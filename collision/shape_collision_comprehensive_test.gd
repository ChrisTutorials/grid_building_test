extends GdUnitTestSuite

## Comprehensive test for all shape collision detection
## Replaces debug tests with proper validation
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
		["Medium Capsule", "capsule", 14.0, 60.0, PackedVector2Array(), Rect2(-14, -46, 28, 60)],
		["Large Capsule", "capsule", 48.0, 128.0, PackedVector2Array(), Rect2(-48, -112, 96, 128)],
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

## Test shape tile coverage calculation
@warning_ignore("unused_parameter")
func test_shape_tile_coverage(
	shape_data: Dictionary,
	test_parameters := [
		{
			"name": "Small Capsule",
			"type": "capsule",
			"radius": 7.0,
			"height": 22.0,
			"expected_tiles": Vector2i(1, 2)
		},
		{
			"name": "Medium Capsule",
			"type": "capsule",
			"radius": 14.0,
			"height": 60.0,
			"expected_tiles": Vector2i(2, 4)
		},
		{
			"name": "Large Capsule",
			"type": "capsule",
			"radius": 48.0,
			"height": 128.0,
			"expected_tiles": Vector2i(6, 8)
		},
		{
			"name": "Standard Trapezoid",
			"type": "trapezoid",
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			]),
			"expected_tiles": Vector2i(4, 2)
		}
	]
):
	var bounds: Rect2
	
	if shape_data["type"] == "capsule":
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = shape_data["radius"]
		capsule_shape.height = shape_data["height"]
		
		var transform = Transform2D()
		var polygon = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
		bounds = GBGeometryMath.get_polygon_bounds(polygon)
	elif shape_data["type"] == "trapezoid":
		var trapezoid = shape_data["points"]
		bounds = GBGeometryMath.get_polygon_bounds(trapezoid)
	
	var tile_size = Vector2(16, 16)
	var tiles_wide = int(ceil(bounds.size.x / tile_size.x))
	var tiles_high = int(ceil(bounds.size.y / tile_size.y))

	(
		assert_int(tiles_wide)
		.append_failure_message("%s width tile count mismatch" % shape_data["name"])
		.is_equal(shape_data["expected_tiles"].x)
	)

	(
		assert_int(tiles_high)
		.append_failure_message("%s height tile count mismatch" % shape_data["name"])
		.is_equal(shape_data["expected_tiles"].y)
	)

## Test shape collision detection with tiles
@warning_ignore("unused_parameter")
func test_shape_tile_collision_detection(
	test_data: Dictionary,
	test_parameters := [
		{
			"name": "Capsule Center Tile",
			"type": "capsule",
			"radius": 14.0,
			"height": 60.0,
			"tile_offset": Vector2i(0, 0),
			"expected_overlap": true
		},
		{
			"name": "Capsule Edge Tile",
			"type": "capsule",
			"radius": 14.0,
			"height": 60.0,
			"tile_offset": Vector2i(1, 0),
			"expected_overlap": true
		},
		{
			"name": "Capsule Corner Tile",
			"type": "capsule",
			"radius": 14.0,
			"height": 60.0,
			"tile_offset": Vector2i(1, 1),
			"expected_overlap": false
		},
		{
			"name": "Trapezoid Center Tile",
			"type": "trapezoid",
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			]),
			"tile_offset": Vector2i(0, 0),
			"expected_overlap": true
		},
		{
			"name": "Trapezoid Edge Tile",
			"type": "trapezoid",
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			]),
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
	
	var overlaps: bool
	
	if test_data["type"] == "capsule":
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = test_data["radius"]
		capsule_shape.height = test_data["height"]
		
		overlaps = GBGeometryMath.does_shape_overlap_tile_optimized(
			capsule_shape, Transform2D(), tile_pos, tile_size, 0.01
		)
	elif test_data["type"] == "trapezoid":
		var trapezoid = test_data["points"]
		var tile_area = tile_size.x * tile_size.y
		var epsilon = tile_area * 0.05
		
		overlaps = GBGeometryMath.does_polygon_overlap_tile_optimized(
			trapezoid, tile_pos, tile_size, 0, epsilon
		)

	(
		assert_bool(overlaps)
		.append_failure_message("%s should %s overlap" % [
			test_data["name"],
			"have" if test_data["expected_overlap"] else "not have"
		])
		.is_equal(test_data["expected_overlap"])
	)

## Test shape positioning and transformation
@warning_ignore("unused_parameter")
func test_shape_positioning_validation(
	shape_data: Dictionary,
	test_parameters := [
		{
			"name": "Capsule at Origin",
			"type": "capsule",
			"radius": 14.0,
			"height": 60.0,
			"position": Vector2(0, 0),
			"expected_center": Vector2(0, 0)
		},
		{
			"name": "Capsule at Position",
			"type": "capsule",
			"radius": 14.0,
			"height": 60.0,
			"position": Vector2(400, 300),
			"expected_center": Vector2(400, 300)
		},
		{
			"name": "Trapezoid at Position",
			"type": "trapezoid",
			"points": PackedVector2Array([
				Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
			]),
			"position": Vector2(800, 600),
			"expected_center": Vector2(800, 600)
		}
	]
):
	var transform = Transform2D()
	transform.origin = shape_data["position"]
	
	var bounds: Rect2
	
	if shape_data["type"] == "capsule":
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = shape_data["radius"]
		capsule_shape.height = shape_data["height"]
		
		var polygon = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
		bounds = GBGeometryMath.get_polygon_bounds(polygon)
	elif shape_data["type"] == "trapezoid":
		var trapezoid = shape_data["points"]
		var transformed_points = PackedVector2Array()
		for point in trapezoid:
			transformed_points.append(transform * point)
		bounds = GBGeometryMath.get_polygon_bounds(transformed_points)
	
	var actual_center = bounds.position + bounds.size / 2.0
	var tolerance = 1.0

	(
		assert_float(actual_center.x)
		.append_failure_message("%s center X mismatch" % shape_data["name"])
		.is_equal_approx(shape_data["expected_center"].x, tolerance)
	)

	(
		assert_float(actual_center.y)
		.append_failure_message("%s center Y mismatch" % shape_data["name"])
		.is_equal_approx(shape_data["expected_center"].y, tolerance)
	)
