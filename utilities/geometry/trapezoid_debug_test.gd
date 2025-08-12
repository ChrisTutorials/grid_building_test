extends GdUnitTestSuite


## Test specific trapezoid collision positions using parameterized testing.
@warning_ignore("unused_parameter")
func test_trapezoid_collision_at_position(
	pos: Vector2,
	expected: bool,
	description: String,
	test_parameters := [
		# NOTE (2025-08-09): pos denotes the TILE'S TOP-LEFT. Earlier failures used y=16 
		# while trapezoid max y=12, so only point/edge contact (area=0). Corrected to y=8 
		# so tile vertical span (8..24) overlaps trapezoid ( -12..12 ) with positive area.
		[Vector2(-32, 8), true, "Lower row left corner should overlap"],
		[Vector2(-16, 8), true, "Lower row left-mid should overlap"],
		[Vector2(0, 8), true, "Lower row center should overlap"],
		[Vector2(16, 8), true, "Lower row right should overlap"],
		[Vector2(0, 0), true, "Center tile should overlap"],
		[Vector2(-48, 0), false, "Far left should not overlap"],
		[Vector2(48, 0), false, "Far right should not overlap"],
	]
):
	var trapezoid = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)
	var tile_size = GodotTestFactory.create_tile_size()

	# Calculate intersection area
	var area = GBGeometryMath.intersection_area_with_tile(trapezoid, pos, tile_size, 0)
	var tile_area = tile_size.x * tile_size.y  # 256 for 16x16
	var epsilon_5_percent = tile_area * 0.05  # 12.8
	var overlaps = area > epsilon_5_percent

	(
		assert_bool(overlaps)
		. append_failure_message(
			"%s - area: %.2f, epsilon: %.2f" % [description, area, epsilon_5_percent]
		)
		. is_equal(expected)
	)
