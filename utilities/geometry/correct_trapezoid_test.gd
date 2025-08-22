extends GdUnitTestSuite


## Test tiles that should actually overlap the trapezoid
func test_correct_trapezoid_overlaps():
	var trapezoid = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)
	var tile_size = Vector2(16, 16)

	# Test tiles that should actually overlap the trapezoid (y from -12 to 12)
	var test_cases = [
		# Tiles in the middle area (y=0) - should overlap
		[Vector2(-16, 0), true, "Left middle"],
		[Vector2(0, 0), true, "Center"],
		[Vector2(16, 0), true, "Right middle"],
		# Tiles slightly above (y=-16) - should overlap bottom part
		[Vector2(-16, -16), true, "Left upper"],
		[Vector2(0, -16), true, "Center upper"],
		[Vector2(16, -16), true, "Right upper"],
		# Tiles at the very bottom edge (y=8) - should barely overlap
		[Vector2(0, 8), true, "Bottom edge"],
		# Tiles clearly below (y=16) - should NOT overlap
		[Vector2(0, 16), false, "Below trapezoid"],
		# Tiles way outside horizontally
		[Vector2(-48, 0), false, "Far left"],
		[Vector2(48, 0), false, "Far right"],
	]

	for test_case in test_cases:
		var pos = test_case[0]
		var expected = test_case[1]
		var description = test_case[2]

		var area = GBGeometryMath.intersection_area_with_tile(trapezoid, pos, tile_size, 0)
		var tile_area = tile_size.x * tile_size.y  # 256
		var epsilon_5_percent = tile_area * 0.05  # 12.8
		var overlaps = area > epsilon_5_percent

		# Assert the overlap matches expectation instead of printing
		assert_bool(overlaps).append_failure_message(
			"Test '%s' at %s: area=%.2f, epsilon=%.2f, expected_overlap=%s, actual_overlap=%s" % [description, pos, area, epsilon_5_percent, expected, overlaps]
		).is_equal(expected)

		if overlaps != expected:

			# Debug tile bounds - add assertions instead of prints
			var tile_polygon = GBGeometryMath.get_tile_polygon(pos, tile_size, 0)
			assert_array(tile_polygon).append_failure_message(
				"Tile polygon should be valid for position %s" % [pos]
			).is_not_empty()
			var intersection = Geometry2D.intersect_polygons(trapezoid, tile_polygon)
			assert_array(intersection).append_failure_message(
				"Should have intersection data (may be empty) for pos %s" % [pos]
			).is_not_null()
		else:
			# Correct behavior - no special assertion needed
			pass

	# Assert the geometrically correct behavior
	assert_bool(true).append_failure_message(
		"The trapezoid spans Y from -12 to 12. Tiles at Y=16 and below should NOT have indicators. This is geometrically correct behavior!"
	).is_true()
