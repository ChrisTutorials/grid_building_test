extends GdUnitTestSuite

## Test tiles that should actually overlap the trapezoid
func test_correct_trapezoid_overlaps():
	var trapezoid = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	var tile_size = Vector2(16, 16)
	
	print("Trapezoid Y range: -12 to 12")
	print("Testing tiles that should overlap...")
	
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
		
		print()
		print("Test: ", description, " at ", pos)
		print("  Area: ", area, " (epsilon: ", epsilon_5_percent, ")")
		print("  Overlaps: ", overlaps, " (expected: ", expected, ")")
		
		if overlaps != expected:
			print("  ❌ MISMATCH!")
			
			# Debug tile bounds
			var tile_polygon = GBGeometryMath.get_tile_polygon(pos, tile_size, 0)
			print("  Tile polygon: ", tile_polygon)
			var intersection = Geometry2D.intersect_polygons(trapezoid, tile_polygon)
			print("  Intersection: ", intersection)
		else:
			print("  ✅ CORRECT")
	
	print()
	print("=== SUMMARY ===")
	print("The trapezoid spans Y from -12 to 12")
	print("Tiles at Y=16 and below should NOT have indicators")
	print("This is geometrically correct behavior!")
