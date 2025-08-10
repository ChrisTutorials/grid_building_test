extends GdUnitTestSuite


func test_capsule_corner_tiles():
	# Gigantic Egg uses CapsuleShape2D with radius 48 and height 128
	var capsule_shape = CapsuleShape2D.new()
	capsule_shape.radius = 48
	capsule_shape.height = 128

	# Place at positioner position (840, 680)
	var positioner_pos = Vector2(840, 680)
	var shape_transform = Transform2D(0, positioner_pos)

	# Tile size is 16x16
	var tile_size = Vector2(16, 16)

	# Convert to polygon to get bounds
	var polygon = GBGeometryMath.convert_shape_to_polygon(capsule_shape, shape_transform)
	var bounds = GBGeometryMath.get_polygon_bounds(polygon)

	print("Capsule at position %s" % positioner_pos)
	print("Capsule bounds: %s to %s" % [bounds.position, bounds.position + bounds.size])
	print("Bounds size: %s" % bounds.size)

	# Calculate tile range based on bounds
	var min_tile_x = int(floor(bounds.position.x / tile_size.x))
	var min_tile_y = int(floor(bounds.position.y / tile_size.y))
	var max_tile_x = int(floor((bounds.position.x + bounds.size.x) / tile_size.x))
	var max_tile_y = int(floor((bounds.position.y + bounds.size.y) / tile_size.y))

	# Check if max bounds are on tile boundaries
	var max_x_on_boundary = abs(fmod(bounds.position.x + bounds.size.x, tile_size.x)) < 0.01
	var max_y_on_boundary = abs(fmod(bounds.position.y + bounds.size.y, tile_size.y)) < 0.01

	if not max_x_on_boundary:
		max_tile_x += 1
	if not max_y_on_boundary:
		max_tile_y += 1

	print("Tile range: (%d,%d) to (%d,%d)" % [min_tile_x, min_tile_y, max_tile_x, max_tile_y])

	# Check specific corner tiles that shouldn't overlap
	var corner_tiles = [
		Vector2i(min_tile_x, min_tile_y),  # Top-left corner
		Vector2i(max_tile_x - 1, min_tile_y),  # Top-right corner
		Vector2i(min_tile_x, max_tile_y - 1),  # Bottom-left corner
		Vector2i(max_tile_x - 1, max_tile_y - 1)  # Bottom-right corner
	]

	print("\nChecking corner tiles for actual overlap:")
	for corner_tile in corner_tiles:
		var tile_pos = Vector2(corner_tile.x * tile_size.x, corner_tile.y * tile_size.y)
		var tile_center = tile_pos + tile_size / 2.0

		# Check if the shape actually overlaps using native collision
		var overlaps = GBGeometryMath.does_shape_overlap_tile_optimized(
			capsule_shape, shape_transform, tile_pos, tile_size, 0.01
		)

		# Also check distance from capsule center to tile center
		var dist_to_center = tile_center.distance_to(positioner_pos)
		var capsule_radius = 48

		print(
			(
				"  Tile %s: overlaps=%s, dist_to_center=%.1f (radius=%.1f)"
				% [corner_tile, overlaps, dist_to_center, capsule_radius]
			)
		)

	# The issue: Corner tiles are included in the range but don't actually overlap
	# This happens because we're using the polygon bounds (rectangular) for a curved shape
	print("\nProblem: Using polygon bounds for tile range calculation includes corners")
	print("that the actual capsule shape doesn't overlap.")

	# Solution: For CapsuleShape2D, we should use a more sophisticated tile range
	# calculation that accounts for the curved nature of the shape

	pass
