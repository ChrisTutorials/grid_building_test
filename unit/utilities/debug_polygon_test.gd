extends GdUnitTestSuite

func test_debug_polygon_bounds():
	polygon: Node = PackedVector2Array[Node2D]([Vector2(1,1), Vector2(17,1), Vector2(17,17), Vector2(1,17)])
	var tile_size = Vector2tile_size
	
	# Test our understanding of the bounds calculation
	var bounds = Rect2()
	if polygon.size() > 0:
		var min_x = polygon[0].x
		var max_x = polygon[0].x
		var min_y = polygon[0].y  
		var max_y = polygon[0].y
		
		for point in polygon:
			min_x = min(min_x, point.x)
			max_x = max(max_x, point.x)
			min_y = min(min_y, point.y)
			max_y = max(max_y, point.y)
		
		bounds = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
	
	print("Polygon: ", polygon)
	print("Bounds: ", bounds)
	print("bounds.position: ", bounds.position)
	print("bounds.size: ", bounds.size)
	print("bounds.position + bounds.size: ", bounds.position + bounds.size)
	
	var start_tile = Vector2i(floor(bounds.position.x / tile_size.x), floor(bounds.position.y / tile_size.y))
	var end_tile = Vector2i(ceil((bounds.position.x + bounds.size.x) / tile_size.x), ceil((bounds.position.y + bounds.size.y) / tile_size.y))
	
	print("start_tile: ", start_tile)
	print("end_tile: ", end_tile)
	
	var tiles_checked: Array[Node2D][Vector2i] = []
	for x in range(start_tile.x, end_tile.x):
		for y in range(start_tile.y, end_tile.y):
			tiles_checked.append(Vector2i(x, y))
	
	print("Tiles checked: ", tiles_checked)
	print("Number of tiles: ", tiles_checked.size())
	
	# Test actual collision detection
	var tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		polygon, Vector2(16,16), TileSet.TILE_SHAPE_SQUARE, 0.01, 0.01
	)
	print("Actually overlapping tiles: ", tiles)
