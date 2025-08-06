extends GdUnitTestSuite

## Test specific trapezoid collision positions using parameterized testing.
func test_trapezoid_collision_at_position(pos: Vector2, expected: bool, description: String, test_parameters := [
	[Vector2(-32, 16), true, "Bottom-left corner should overlap"],
	[Vector2(-16, 16), true, "Bottom-left should overlap"],
	[Vector2(0, 16), true, "Bottom-center should overlap"],
	[Vector2(16, 16), true, "Bottom-right should overlap"],
	[Vector2(0, 0), true, "Center should overlap"],
	[Vector2(-48, 0), false, "Far left should not overlap"],
	[Vector2(48, 0), false, "Far right should not overlap"],
]):
	var trapezoid = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	var tile_size = GodotTestFactory.create_tile_size()
	
	# Calculate intersection area
	var area = GBGeometryMath.intersection_area_with_tile(trapezoid, pos, tile_size, 0)
	var tile_area = tile_size.x * tile_size.y  # 256 for 16x16
	var epsilon_5_percent = tile_area * 0.05  # 12.8
	var overlaps = area > epsilon_5_percent
	
	assert_bool(overlaps).append_failure_message(
		"%s - area: %.2f, epsilon: %.2f" % [description, area, epsilon_5_percent]
	).is_equal(expected)
