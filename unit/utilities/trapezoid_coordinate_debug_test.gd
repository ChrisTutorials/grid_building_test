## Debug test specifically for the trapezoid coordinate calculation issue
## The runtime shows missing tile coverage in bottom corners, but collision geometry
## calculation is returning completely wrong tile coordinates
extends GdUnitTestSuite

const TRAPEZOID_POSITION: Vector2 = Vector2(440, 552)
const TILE_SIZE: Vector2 = Vector2(16, 16)

func test_trapezoid_coordinate_calculation() -> void:
	print("=== TRAPEZOID COORDINATE DEBUG TEST ===")
	
	# The trapezoid polygon from runtime analysis
	var trapezoid_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12),   # Bottom left vertex
		Vector2(-16, -12),  # Top left vertex
		Vector2(17, -12),   # Top right vertex
		Vector2(32, 12)     # Bottom right vertex
	])
	
	print("Trapezoid polygon (local space): %s" % str(trapezoid_polygon))
	print("Position: %s" % str(TRAPEZOID_POSITION))
	print("Tile size: %s" % str(TILE_SIZE))
	
	# Calculate center tile manually
	var center_tile: Vector2i = Vector2i(
		int(TRAPEZOID_POSITION.x / TILE_SIZE.x),
		int(TRAPEZOID_POSITION.y / TILE_SIZE.y)
	)
	print("Calculated center tile: %s" % str(center_tile))
	print("Should be around: (%d, %d)" % [440.0/16.0, 552.0/16.0])  # ~(27, 34)
	
	# Convert polygon to world space manually
	var world_polygon: PackedVector2Array = PackedVector2Array()
	for point in trapezoid_polygon:
		world_polygon.append(point + TRAPEZOID_POSITION)
	
	print("World polygon: %s" % str(world_polygon))
	
	# Test CollisionGeometryUtils calculation
	var tile_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		world_polygon, TILE_SIZE, center_tile
	)
	print("CollisionGeometryUtils tile offsets: %s" % str(tile_offsets))
	
	# Validate the calculated offsets make sense
	print("Checking offset validity:")
	for offset in tile_offsets:
		var actual_tile: Vector2i = center_tile + offset
		print("  Offset %s -> Tile %s" % [offset, actual_tile])
		
		# Offsets should be small relative to center (within reasonable range)
		assert_int(abs(offset.x)).append_failure_message(
			"X offset %d is too large - suggests coordinate calculation error" % offset.x
		).is_less_equal(5)
		
		assert_int(abs(offset.y)).append_failure_message(
			"Y offset %d is too large - suggests coordinate calculation error" % offset.y
		).is_less_equal(5)
	
	print("=== Expected trapezoid coverage pattern ===")
	# For a trapezoid at position (440, 552) with local points [(-32,12), (-16,-12), (17,-12), (32,12)]
	# World points would be: [(408,564), (424,540), (457,540), (472,564)]
	# This spans roughly tiles from (25,33) to (29,35)
	# So relative to center tile (27,34), expected offsets might be around:
	# [(-2,-1), (-1,-1), (0,-1), (1,-1), (2,-1), (-2,0), (-1,0), (0,0), (1,0), (2,0), (-1,1), (0,1), (1,1)]
	
	print("Manual world space calculation:")
	for i in range(trapezoid_polygon.size()):
		var local_point: Vector2 = trapezoid_polygon[i]
		var world_point: Vector2 = local_point + TRAPEZOID_POSITION
		var tile_coord: Vector2i = Vector2i(int(world_point.x / TILE_SIZE.x), int(world_point.y / TILE_SIZE.y))
		var offset_from_center: Vector2i = tile_coord - center_tile
		print("  Vertex %d: Local %s -> World %s -> Tile %s -> Offset %s" % [
			i, local_point, world_point, tile_coord, offset_from_center
		])