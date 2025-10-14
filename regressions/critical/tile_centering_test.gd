## Debug test to isolate the GridPositioner2D centering issue
extends GdUnitTestSuite

var grid_positioner: GridPositioner2D
var target_map: TileMapLayer

func before_test() -> void:
	# Create test components manually
	grid_positioner = GridPositioner2D.new()
	# Ensure ownership and proper teardown
	add_child(grid_positioner)
	auto_free(grid_positioner)
	target_map = GodotTestFactory.create_tile_map_layer(self)

func after_test() -> void:
	# Cleanup
	pass

func test_debug_tile_centering_issue() -> void:
	# Use the manually created components
	assert_object(grid_positioner).append_failure_message("GridPositioner2D should exist after factory creation").is_not_null()
	assert_object(target_map).append_failure_message("Target map should exist after factory creation").is_not_null()
	assert_object(target_map.tile_set).append_failure_message("TileSet should exist on target map after factory creation").is_not_null()
	
	# Check tile size - should be 16x16 for standard Grid Building
	var tile_size: Vector2i = target_map.tile_set.tile_size
	print("DEBUG: TileSet tile_size = ", tile_size)
	
	# Test direct tile centering with utilities
	var test_tile: Vector2i = Vector2i(5, 3)  # Arbitrary test tile
	var expected_center: Vector2 = target_map.map_to_local(test_tile)  # map_to_local already returns center
	var expected_center_global: Vector2 = target_map.to_global(expected_center)
	
	print("DEBUG: Test tile = ", test_tile)
	print("DEBUG: Expected center local = ", expected_center)
	print("DEBUG: Expected center global = ", expected_center_global)
	
	# Use the positioning utility directly
	var result_tile: Vector2i = GBPositioning2DUtils.move_to_tile_center(grid_positioner, test_tile, target_map)
	
	print("DEBUG: Actual position after move = ", grid_positioner.global_position)
	print("DEBUG: Result tile = ", result_tile)
	
	# Check if the positioning is correct
	var position_delta: Vector2 = grid_positioner.global_position - expected_center_global
	print("DEBUG: Position delta = ", position_delta)
	
	assert_vector(grid_positioner.global_position).append_failure_message(
		"GridPositioner should be centered on tile. Expected: %s, Got: %s, Delta: %s, TileSize: %s" % [
			str(expected_center_global), str(grid_positioner.global_position), str(position_delta), str(tile_size)
		]
	).is_equal_approx(expected_center_global, Vector2(1.0, 1.0))

func test_debug_map_to_local_behavior() -> void:
	# Test map_to_local behavior to understand coordinate conversion
	var tile_size: Vector2i = target_map.tile_set.tile_size
	
	print("DEBUG: Starting map_to_local behavior test with tile_size = ", tile_size)
	
	# Test several tiles
	var test_tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	
	for test_tile in test_tiles:
		var map_local: Vector2 = target_map.map_to_local(test_tile)
		var expected_top_left: Vector2 = Vector2(test_tile.x * tile_size.x, test_tile.y * tile_size.y)
		var expected_center: Vector2 = expected_top_left + Vector2(tile_size) * 0.5
		
		print("DEBUG: Tile %s -> map_to_local = %s (type: %s), expected_center = %s (type: %s)" % [
			str(test_tile), str(map_local), typeof(map_local), str(expected_center), typeof(expected_center)
		])
		
		# Enhanced diagnostics: check if map_local is actually a Vector2
		assert_object(map_local).append_failure_message("map_to_local should return non-null value for tile: %s" % str(test_tile)).is_not_null()
		
		# Verify the types are correct
		assert_bool(map_local is Vector2).append_failure_message("map_to_local should return Vector2, got type: %s with value: %s" % [typeof(map_local), str(map_local)]).is_true()
		
		assert_bool(expected_center is Vector2).append_failure_message("expected_center should be Vector2, got type: %s with value: %s" % [typeof(expected_center), str(expected_center)]).is_true()
		
		# Verify map_to_local gives expected position (should be center, not top-left)
		assert_vector(map_local).append_failure_message(
			"map_to_local should return tile center. Tile: %s, Expected center: %s, Got: %s, Expected top-left: %s, Tile size: %s" % [
				str(test_tile), str(expected_center), str(map_local), str(expected_top_left), str(tile_size)
			]
		).is_equal_approx(expected_center, Vector2(1.0, 1.0))
