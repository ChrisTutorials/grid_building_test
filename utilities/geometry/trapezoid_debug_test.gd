extends GdUnitTestSuite

## Test to debug specific trapezoid collision issues
func test_trapezoid_debug():
	var trapezoid = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	var tile_size = Vector2(16, 16)
	
	# Test specific positions that should have different behaviors
	var test_cases = [
		# Position, Expected Result, Description
		[Vector2(-32, 16), true, "Bottom-left corner should overlap"],   
		[Vector2(-16, 16), true, "Bottom-left should overlap"],
		[Vector2(0, 16), true, "Bottom-center should overlap"], 
		[Vector2(16, 16), true, "Bottom-right should overlap"],
		[Vector2(0, 0), true, "Center should overlap"],
		[Vector2(-48, 0), false, "Far left should not overlap"],
		[Vector2(48, 0), false, "Far right should not overlap"],
	]
	
	for test_case in test_cases:
		var pos = test_case[0] 
		var expected = test_case[1]
		var description = test_case[2]
		
		# Calculate intersection area
		var area = GBGeometryMath.intersection_area_with_tile(trapezoid, pos, tile_size, 0)
		var tile_area = tile_size.x * tile_size.y  # 256 for 16x16
		var epsilon_5_percent = tile_area * 0.05  # 12.8
		var overlaps = area > epsilon_5_percent
		
		print("Test: ", description)
		print("  Position: ", pos)  
		print("  Area: ", area)
		print("  Tile Area: ", tile_area)
		print("  Epsilon (5%): ", epsilon_5_percent)
		print("  Overlaps: ", overlaps)
		print("  Expected: ", expected)
		print()
		
		assert_bool(overlaps).append_failure_message(description + " - area: " + str(area) + " epsilon: " + str(epsilon_5_percent)).is_equal(expected)
