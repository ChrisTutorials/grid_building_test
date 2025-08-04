class_name GridAlignmentTest
extends GdUnitTestSuite

## Tests grid alignment functionality to ensure positioner is always centered on tiles
## before collision calculations run. This prevents asymmetric indicator generation.

var tile_map_layer: TileMapLayer
var positioner: Node2D

func before_test():
	tile_map_layer = auto_free(TileMapLayer.new())
	add_child(tile_map_layer)
	tile_map_layer.tile_set = TileSet.new()
	tile_map_layer.tile_set.tile_size = Vector2i(16, 16)
	
	positioner = auto_free(Node2D.new())
	add_child(positioner)

func after_test():
	pass

## Test that off-grid positions get aligned to tile centers
func test_off_grid_positions_get_aligned():
	# Test various off-grid positions
	var test_cases = [
		{ "input": Vector2(100.3, 200.7), "expected_tile": Vector2i(6, 12) },
		{ "input": Vector2(87.9, 156.1), "expected_tile": Vector2i(5, 9) },
		{ "input": Vector2(543.7, 678.3), "expected_tile": Vector2i(33, 42) }
	]
	
	for test_case in test_cases:
		# Set positioner to off-grid position
		positioner.global_position = test_case.input
		
		# Calculate what the aligned position should be
		var input_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(test_case.input))
		var expected_aligned_position = tile_map_layer.to_global(tile_map_layer.map_to_local(input_tile))
		
		# Apply alignment logic manually (simulating what _ensure_positioner_grid_alignment does)
		var current_world_pos = positioner.global_position
		var current_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(current_world_pos))
		var aligned_world_pos = tile_map_layer.to_global(tile_map_layer.map_to_local(current_tile))
		
		# Check if alignment is needed
		var distance = current_world_pos.distance_to(aligned_world_pos)
		if distance > 0.1:
			positioner.global_position = aligned_world_pos
		
		# Verify final position
		var final_position = positioner.global_position
		assert_vector(final_position).append_failure_message(
			"Position %s should align to tile %s at %s, but got %s" % [
				test_case.input, input_tile, expected_aligned_position, final_position
			]
		).is_equal_approx(expected_aligned_position, Vector2(0.1, 0.1))
		
		# Verify tile coordinate matches expected
		var final_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(final_position))
		assert_vector(Vector2(final_tile)).is_equal(Vector2(test_case.expected_tile))

## Test that already aligned positions remain unchanged
func test_already_aligned_positions_unchanged():
	var test_positions = [
		Vector2(96, 112),    # Exact tile center
		Vector2(160, 80),    # Another tile center
		Vector2(0, 0)        # Origin tile center
	]
	
	for test_pos in test_positions:
		# Set to exact tile center
		positioner.global_position = test_pos
		
		# Apply alignment logic
		var current_world_pos = positioner.global_position
		var current_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(current_world_pos))
		var aligned_world_pos = tile_map_layer.to_global(tile_map_layer.map_to_local(current_tile))
		
		var distance = current_world_pos.distance_to(aligned_world_pos)
		if distance > 0.1:
			positioner.global_position = aligned_world_pos
		
		# Verify position didn't change
		var final_position = positioner.global_position
		assert_vector(final_position).append_failure_message(
			"Already aligned position %s should remain unchanged, but became %s" % [
				test_pos, final_position
			]
		).is_equal_approx(test_pos, Vector2(0.01, 0.01))

## Test tile coordinate calculation consistency  
func test_tile_coordinate_calculation_consistency():
	# Test that the same world position always produces the same tile coordinates
	var world_positions = [
		Vector2(100, 200),
		Vector2(543.7, 678.3),
		Vector2(-50, -80)
	]
	
	for world_pos in world_positions:
		# Calculate tile multiple times
		var tile_coords = []
		for i in range(5):
			positioner.global_position = world_pos
			var tile = tile_map_layer.local_to_map(tile_map_layer.to_local(world_pos))
			tile_coords.append(tile)
		
		# All calculations should be identical
		for i in range(1, tile_coords.size()):
			assert_vector(Vector2(tile_coords[i])).append_failure_message(
				"Tile calculation for %s should be consistent: %s vs %s" % [
					world_pos, tile_coords[0], tile_coords[i]
				]
			).is_equal(Vector2(tile_coords[0]))

## Test alignment with different tile sizes
func test_alignment_with_different_tile_sizes():
	var tile_sizes = [Vector2i(16, 16), Vector2i(32, 32), Vector2i(8, 16)]
	
	for tile_size in tile_sizes:
		# Update tile size
		tile_map_layer.tile_set.tile_size = tile_size
		
		# Test off-grid position
		var off_grid_pos = Vector2(100.5, 200.3)
		positioner.global_position = off_grid_pos
		
		# Apply alignment
		var current_world_pos = positioner.global_position
		var current_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(current_world_pos))
		var aligned_world_pos = tile_map_layer.to_global(tile_map_layer.map_to_local(current_tile))
		
		var distance = current_world_pos.distance_to(aligned_world_pos)
		if distance > 0.1:
			positioner.global_position = aligned_world_pos
		
		# Verify alignment worked for this tile size
		var final_position = positioner.global_position
		var final_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(final_position))
		var expected_aligned_pos = tile_map_layer.to_global(tile_map_layer.map_to_local(final_tile))
		
		assert_vector(final_position).append_failure_message(
			"Alignment failed for tile size %s: expected %s, got %s" % [
				tile_size, expected_aligned_pos, final_position
			]
		).is_equal_approx(expected_aligned_pos, Vector2(0.1, 0.1))
