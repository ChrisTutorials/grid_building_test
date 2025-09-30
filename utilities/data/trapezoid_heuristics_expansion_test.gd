## Unit test to isolate and fix the trapezoid collision calculation bug
extends GdUnitTestSuite

func test_trapezoid_collision_calculation_diagnostic() -> void:
	# Arrange: The exact runtime trapezoid coordinates that fail
	var trapezoid_points: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
	])
	var tile_size: Vector2 = Vector2(16, 16)
	var center_tile: Vector2i = Vector2i(27, 34)  # Runtime position (440, 544) / 16
	
	# Debug: Step through the collision calculation process
	print("\n=== DIAGNOSTIC: TRAPEZOID COLLISION CALCULATION ===")
	print("Trapezoid points: ", trapezoid_points)
	print("Tile size: ", tile_size)
	print("Center tile: ", center_tile)
	
	# Step 1: Check bounds calculation
	var bounds: Rect2 = CollisionGeometryCalculator._get_polygon_bounds(trapezoid_points)
	print("Polygon bounds: ", bounds)
	
	# Step 2: Calculate expected tile range
	var start_tile: Vector2i = Vector2i(floor(bounds.position.x / tile_size.x), floor(bounds.position.y / tile_size.y))
	var end_tile: Vector2i = Vector2i(ceil((bounds.position.x + bounds.size.x) / tile_size.x), ceil((bounds.position.y + bounds.size.y) / tile_size.y))
	print("Expected tile range: ", start_tile, " to ", end_tile)
	print("Tile range size: ", (end_tile.x - start_tile.x) * (end_tile.y - start_tile.y), " tiles")
	
	# Step 3: Test overlap detection for each tile in range
	var overlapping_tiles: Array[Vector2i] = []
	for x in range(start_tile.x, end_tile.x):
		for y in range(start_tile.y, end_tile.y):
			var tile_pos: Vector2i = Vector2i(x, y)
			var tile_rect: Rect2 = Rect2(Vector2(x * tile_size.x, y * tile_size.y), tile_size)
			
			# Test with different overlap thresholds
			var overlaps_strict: bool = CollisionGeometryCalculator.polygon_overlaps_rect(trapezoid_points, tile_rect, 0.01, 0.05)  # 5% threshold
			var overlaps_loose: bool = CollisionGeometryCalculator.polygon_overlaps_rect(trapezoid_points, tile_rect, 0.01, 0.01)  # 1% threshold
			
			if overlaps_strict or overlaps_loose:
				var clipped: PackedVector2Array = CollisionGeometryCalculator.clip_polygon_to_rect(trapezoid_points, tile_rect)
				var area: float = CollisionGeometryCalculator.polygon_area(clipped)
				var tile_area: float = tile_rect.size.x * tile_rect.size.y
				var overlap_ratio: float = area / tile_area if tile_area > 0 else 0.0
				
				print("Tile [%d,%d] rect=%s: area=%.2f/%.2f (%.1f%%) strict=%s loose=%s" % 
					[x, y, tile_rect, area, tile_area, overlap_ratio * 100, overlaps_strict, overlaps_loose])
				
				if overlaps_strict:
					overlapping_tiles.append(tile_pos)
	
	print("Total overlapping tiles (5% threshold): ", overlapping_tiles.size())
	
	# Act: Call the actual collision utility function  
	var core_result: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		trapezoid_points, tile_size, center_tile
	)
	
	# Assert: Should find overlapping tiles, not return 0
	assert_int(core_result.size()).append_failure_message(
		"Expected core calculation to find %d overlapping tiles, got %d tiles: %s" % 
		[overlapping_tiles.size(), core_result.size(), core_result]
	).is_greater(0)

## Helper function to analyze offset patterns (copied from PolygonTileMapper)
func _analyze_offset_pattern(offsets: Array[Vector2i]) -> Dictionary:
	var ys: Array[int] = []
	var xs_by_y: Dictionary = {}
	
	for offset in offsets:
		if offset.y not in ys:
			ys.append(offset.y)
		if not xs_by_y.has(offset.y):
			xs_by_y[offset.y] = []
		xs_by_y[offset.y].append(offset.x)
	
	return {"ys": ys, "xs_by_y": xs_by_y}