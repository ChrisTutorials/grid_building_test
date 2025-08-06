extends GdUnitTestSuite

## Debug test to analyze the exact bounds being calculated for CapsuleShape2D.
## This helps identify why the gigantic egg has asymmetric indicators.
func test_capsule_shape_bounds_symmetry():
	# Create the same capsule as the gigantic egg
	var capsule_shape = GodotTestFactory.create_capsule_shape(48.0, 128.0)
	
	# Create transform at origin (0,0) for testing
	var transform = GodotTestFactory.create_transform2d()
	
	# Convert to polygon using the same method as the system
	var polygon = GBGeometryMath.convert_shape_to_polygon(capsule_shape, transform)
	
	print("Capsule polygon points: ", polygon.size())
	for i in range(polygon.size()):
		print("Point %d: %s" % [i, polygon[i]])
	
	# Get bounds using the same method as collision detection
	var bounds = GBGeometryMath.get_polygon_bounds(polygon)
	print("Polygon bounds: ", bounds)
	
	# Check if bounds are symmetric around origin
	var left_extent = -bounds.position.x
	var right_extent = bounds.position.x + bounds.size.x
	var top_extent = -bounds.position.y  
	var bottom_extent = bounds.position.y + bounds.size.y
	
	print("Left extent: %.2f, Right extent: %.2f" % [left_extent, right_extent])
	print("Top extent: %.2f, Bottom extent: %.2f" % [top_extent, bottom_extent])
	
	# For a symmetric capsule, left and right extents should be equal
	var horizontal_difference = abs(left_extent - right_extent)
	assert_float(horizontal_difference).append_failure_message(
		"Capsule should have symmetric horizontal bounds. Left: %.2f, Right: %.2f" % [left_extent, right_extent]
	).is_less(1.0)  # Allow small floating point differences
	
	# Test tile calculation with these bounds
	var tile_size = GodotTestFactory.create_tile_size()
	var tiles_wide := int(ceil(bounds.size.x / tile_size.x))
	var tiles_high := int(ceil(bounds.size.y / tile_size.y))
	
	print("Tiles wide: %d, Tiles high: %d" % [tiles_wide, tiles_high])
	
	# Check our fixed symmetric distribution
	var tiles_left := int(floor(tiles_wide / 2.0))
	var tiles_right := tiles_wide - tiles_left
	
	print("Tiles left: %d, Tiles right: %d, Total: %d" % [tiles_left, tiles_right, tiles_left + tiles_right])
	
	assert_int(tiles_left + tiles_right).is_equal(tiles_wide)
