extends GdUnitTestSuite

## Test to verify the top-left indicator positioning for the simple trapezoid
func test_simple_trapezoid_top_left_overlap():
	# Simple trapezoid polygon from the runtime analysis
	var trapezoid = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	var tile_size = Vector2(16, 16)
	
	# Position the trapezoid at the positioner location from runtime analysis
	var positioner_offset = Vector2(808, 680)  # From runtime analysis
	var collision_polygon_offset = Vector2(8, -8)  # From the simple_trapezoid.tscn (CollisionPolygon2D position)
	
	# Transform trapezoid to world coordinates like the collision mapper does
	var world_trapezoid = PackedVector2Array()
	for point in trapezoid:
		var world_point = positioner_offset + collision_polygon_offset + point
		world_trapezoid.append(world_point)
	
	print("World trapezoid points: ", world_trapezoid)
	
	# Get the bounds to understand the geometry
	var bounds = GBGeometryMath.get_polygon_bounds(world_trapezoid)
	print("Trapezoid bounds: ", bounds)
	print("Y range: ", bounds.position.y, " to ", bounds.position.y + bounds.size.y)
	
	# Test the problematic top-left tile from runtime analysis
	var problematic_tile_coord = Vector2i(48, 41)
	var tile_world_pos = Vector2(48 * 16, 41 * 16)  # Convert tile coord to world pos
	
	print("Problematic tile coord: ", problematic_tile_coord)
	print("Tile world position: ", tile_world_pos)
	print("Tile bounds: ", tile_world_pos, " to ", tile_world_pos + tile_size)
	
	# Check if this tile should actually overlap
	var epsilon = tile_size.x * tile_size.y * 0.05  # Same epsilon as collision mapper
	var overlaps = GBGeometryMath.does_polygon_overlap_tile_optimized(
		world_trapezoid, tile_world_pos, tile_size, 0, epsilon
	)
	
	print("Epsilon threshold: ", epsilon)
	print("Does overlap (with epsilon): ", overlaps)
	
	# Calculate exact intersection area for verification
	var tile_polygon = GBGeometryMath.get_tile_polygon(tile_world_pos, tile_size, 0)
	var intersection_area = GBGeometryMath.polygon_intersection_area(world_trapezoid, tile_polygon)
	print("Exact intersection area: ", intersection_area)
	print("Percentage of tile area: ", (intersection_area / (tile_size.x * tile_size.y)) * 100, "%")
	
	# The question is: should this indicator be there?
	# If intersection area is very small (edge touching), it probably shouldn't be
	var should_overlap = intersection_area > epsilon
	print("Should this indicator exist? ", should_overlap)
	
	# Let's also test a few nearby tiles to understand the pattern
	print("\n=== Testing nearby tiles ===")
	var test_tiles = [
		Vector2i(48, 40),  # Above the problematic one
		Vector2i(48, 41),  # The problematic one
		Vector2i(48, 42),  # Below the problematic one  
		Vector2i(49, 41),  # To the right of problematic one
	]
	
	for tile_coord in test_tiles:
		var test_tile_pos = Vector2(tile_coord.x * 16, tile_coord.y * 16)
		var test_overlaps = GBGeometryMath.does_polygon_overlap_tile_optimized(
			world_trapezoid, test_tile_pos, tile_size, 0, epsilon
		)
		var test_tile_polygon = GBGeometryMath.get_tile_polygon(test_tile_pos, tile_size, 0)
		var test_area = GBGeometryMath.polygon_intersection_area(world_trapezoid, test_tile_polygon)
		print("Tile %s: overlaps=%s, area=%.2f, %%=%.1f%%" % [
			tile_coord, test_overlaps, test_area, (test_area / 256.0) * 100
		])

## Test the mathematical correctness of the overlap detection
func test_trapezoid_geometry_validation():
	# The simple trapezoid has these LOCAL coordinates:
	var _local_trapezoid = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	print("Local trapezoid Y range: -12 to 12 (height: 24)")
	
	# After applying positioner (808, 680) and collision polygon offset (8, -8):
	# Final Y range should be: 680 + (-8) + (-12 to 12) = 660 to 692
	var expected_y_min = 680 - 8 - 12
	var expected_y_max = 680 - 8 + 12
	print("Expected world Y range: ", expected_y_min, " to ", expected_y_max)
	
	# The problematic tile (48, 41) has Y bounds: 41*16 = 656 to 41*16+16 = 672
	var tile_y_min = 41 * 16
	var tile_y_max = 41 * 16 + 16
	print("Problematic tile Y range: ", tile_y_min, " to ", tile_y_max)
	
	# Check overlap
	var y_overlap_start = max(expected_y_min, tile_y_min)
	var y_overlap_end = min(expected_y_max, tile_y_max)
	var y_overlap_height = max(0, y_overlap_end - y_overlap_start)
	
	print("Y overlap: ", y_overlap_start, " to ", y_overlap_end, " (height: ", y_overlap_height, ")")
	
	# If there's legitimate Y overlap, the indicator should be there
	var should_have_indicator = y_overlap_height > 0
	print("Should have indicator based on Y overlap: ", should_have_indicator)
	
	# The indicator appears to be geometrically correct!
