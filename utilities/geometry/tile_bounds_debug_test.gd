extends GdUnitTestSuite

## Test to debug tile positioning and bounds  
func test_tile_bounds_debug():
	var trapezoid = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	var tile_size = Vector2(16, 16)
	
	# Test tile at (0, 16) - this should overlap the trapezoid slightly
	var tile_pos = Vector2(0, 16)
	
	# Get the tile polygon using GBGeometryMath
	var tile_polygon = GBGeometryMath.get_tile_polygon(tile_pos, tile_size, 0)
	
	print("Trapezoid points: ", trapezoid)
	print("Tile position: ", tile_pos)
	print("Tile size: ", tile_size) 
	print("Tile polygon: ", tile_polygon)
	
	# Calculate bounds
	var trapezoid_bounds = GBGeometryMath.get_polygon_bounds(trapezoid)
	var tile_bounds = GBGeometryMath.get_polygon_bounds(tile_polygon)
	
	print("Trapezoid bounds: ", trapezoid_bounds)
	print("Tile bounds: ", tile_bounds)
	
	# Check if they should overlap
	var trap_top = trapezoid_bounds.position.y
	var trap_bottom = trapezoid_bounds.position.y + trapezoid_bounds.size.y
	var tile_top = tile_bounds.position.y  
	var tile_bottom = tile_bounds.position.y + tile_bounds.size.y
	
	print("Trapezoid Y range: ", trap_top, " to ", trap_bottom)
	print("Tile Y range: ", tile_top, " to ", tile_bottom)
	
	var should_overlap = not (trap_bottom < tile_top or tile_bottom < trap_top)
	print("Should overlap: ", should_overlap)
	
	# Calculate actual intersection
	var area = GBGeometryMath.intersection_area_with_tile(trapezoid, tile_pos, tile_size, 0)
	print("Calculated intersection area: ", area)
	
	# Use Godot's built-in intersection
	var intersection = Geometry2D.intersect_polygons(trapezoid, tile_polygon)
	print("Godot intersection result: ", intersection)
	if not intersection.is_empty():
		# Calculate area manually since get_polygon_area doesn't exist
		var intersection_poly = intersection[0]
		var intersection_area = 0.0
		var n = intersection_poly.size()
		for i in range(n):
			var j = (i + 1) % n
			intersection_area += intersection_poly[i].x * intersection_poly[j].y
			intersection_area -= intersection_poly[j].x * intersection_poly[i].y
		intersection_area = abs(intersection_area) / 2.0
		print("Godot intersection area: ", intersection_area)
	
	assert_bool(should_overlap).is_true()
