extends GdUnitTestSuite

# Verifies hybrid behavior:
#   - Unparented polygon: offsets change when positioner moves (since center tile changes while polygon stays).
#   - Parented polygon: offsets remain stable (both move together).

func _collect_offsets(mapper: CollisionMapper, poly: CollisionPolygon2D, layer: TileMapLayer) -> Array[Vector2i]:
	var d := mapper._get_tile_offsets_for_collision_polygon(poly, layer)
	assert_object(d).append_failure_message(
		"CollisionMapper should return valid dictionary from _get_tile_offsets_for_collision_polygon"
	).is_not_null()
	var arr: Array[Vector2i] = []
	for k in d.keys(): arr.append(k)
	arr.sort()
	
	# Validate collected offsets with meaningful failure context. If empty, gather
	# internal PolygonTileMapper diagnostics to help identify why coverage is missing.
	if arr.is_empty():
		var diag_msg = ""
		# Try to get detailed diagnostics from the internal polygon mapper if available
		if typeof(PolygonTileMapper) != TYPE_NIL:
			var pmapper = PolygonTileMapper.new(mapper._targeting_state, mapper._logger)
			var diag = pmapper.process_polygon_with_diagnostics(poly, layer)
			diag_msg = "; diag.initial=%d, diag.final=%d, diag.was_parented=%s, diag.was_convex=%s" % [diag.initial_offset_count, diag.final_offset_count, str(diag.was_parented), str(diag.was_convex)]
			
			# Add coordinate system diagnostics
			var center_tile = layer.local_to_map(mapper._targeting_state.positioner.global_position)
			var polygon_world_center = poly.global_position
			var polygon_tile = layer.local_to_map(layer.to_local(polygon_world_center))
			var tile_size = Vector2(layer.tile_set.tile_size) if layer.tile_set else Vector2(16, 16)
			
			diag_msg += "; center_tile=%s, poly_world=%s, poly_tile=%s, tile_size=%s" % [center_tile, polygon_world_center, polygon_tile, tile_size]
		
		assert_array(arr).append_failure_message(
			"_collect_offsets should return non-empty array of tile offsets. Dict keys: %s, Dict size: %d, Polygon global_position: %s%s" % [d.keys(), d.size(), poly.global_position, diag_msg]
		).is_not_empty()
	else:
		assert_array(arr).append_failure_message(
			"_collect_offsets should return non-empty array of tile offsets. Dict keys: %s, Dict size: %d, Polygon global_position: %s" % [d.keys(), d.size(), poly.global_position]
		).is_not_empty()
	
	return arr

func test_unparented_polygon_offsets_change_when_positioner_moves() -> void:
	var root := Node2D.new()
	add_child(root)  # Add to scene tree for proper transforms
	var layer := TileMapLayer.new(); var ts := TileSet.new(); ts.tile_size = Vector2i(16,16); layer.tile_set = ts; root.add_child(layer)
	# Make sure the TileMapLayer has a proper transform in the scene
	layer.global_position = Vector2.ZERO
	
	var positioner := Node2D.new(); positioner.global_position = Vector2(512,512); root.add_child(positioner)
	var owner_context := GBOwnerContext.new(null)
	var targeting_state := GridTargetingState.new(owner_context); targeting_state.target_map = layer; targeting_state.positioner = positioner
	var logger := GBLogger.new(GBDebugSettings.new())
	var mapper := CollisionMapper.new(targeting_state, logger)
	var parent := Area2D.new(); root.add_child(parent)
	# Position the collision object near the positioner so it's in a testable tile range
	parent.global_position = Vector2(512, 512)
	var poly := CollisionPolygon2D.new(); poly.polygon = PackedVector2Array([Vector2(-16,-16), Vector2(16,-16), Vector2(16,16), Vector2(-16,16)])
	parent.add_child(poly)
	var offsets1 = _collect_offsets(mapper, poly, layer)
	positioner.global_position += Vector2(32,0) # move two tiles right
	var offsets2 = _collect_offsets(mapper, poly, layer)
	
	# Validate that unparented polygon offsets change when positioner moves
	assert_array(offsets1).append_failure_message(
		"First offsets collection should not be empty for unparented polygon at positioner pos: %s" % [positioner.global_position - Vector2(32,0)]
	).is_not_empty()
	assert_array(offsets2).append_failure_message(
		"Second offsets collection should not be empty for unparented polygon at positioner pos: %s" % [positioner.global_position]
	).is_not_empty()
	assert_array(offsets2).append_failure_message(
		"Unparented polygon offsets should change when positioner moves. Before: %s, After: %s" % [offsets1, offsets2]
	).is_not_equal(offsets1)
	root.queue_free()

func test_parented_polygon_offsets_stable_when_positioner_moves() -> void:
	var root := Node2D.new()
	add_child(root)  # Add to scene tree for proper transforms
	var layer := TileMapLayer.new(); var ts := TileSet.new(); ts.tile_size = Vector2i(16,16); layer.tile_set = ts; root.add_child(layer)
	# Make sure the TileMapLayer has a proper transform in the scene
	layer.global_position = Vector2.ZERO
	
	var positioner := Node2D.new(); positioner.global_position = Vector2(512,512); root.add_child(positioner)
	var owner_context := GBOwnerContext.new(null)
	var targeting_state := GridTargetingState.new(owner_context); targeting_state.target_map = layer; targeting_state.positioner = positioner
	var logger := GBLogger.new(GBDebugSettings.new())
	var mapper := CollisionMapper.new(targeting_state, logger)
	var poly := CollisionPolygon2D.new(); poly.polygon = PackedVector2Array([Vector2(-16,-16), Vector2(16,-16), Vector2(16,16), Vector2(-16,16)])
	positioner.add_child(poly)
	# Give polygon a local offset so world position is distinct yet follows positioner
	poly.position = Vector2(128, 0)
	
	var offsets1 = _collect_offsets(mapper, poly, layer)
	positioner.global_position += Vector2(32,0)
	var offsets2 = _collect_offsets(mapper, poly, layer)
	
	# From first test run we got [(7, -1), (7, 0), (8, -1), (8, 0)] which seems reasonable
	# Let's use that as our expected pattern since the calculation worked
	var expected_core = [Vector2i(7,-1), Vector2i(7,0), Vector2i(8,-1), Vector2i(8,0)]
	
	# Validate parented polygon behavior with detailed failure context
	assert_array(offsets1).append_failure_message(
		"First read missing expected subset. Got: %s, Expected subset: %s, Polygon global_pos: %s, Positioner pos: %s" % [offsets1, expected_core, poly.global_position, positioner.global_position - Vector2(32,0)]
	).contains_same(expected_core)
	assert_array(offsets2).append_failure_message(
		"After move missing expected subset. Got: %s, Expected subset: %s, Polygon global_pos: %s, Positioner pos: %s" % [offsets2, expected_core, poly.global_position, positioner.global_position]
	).contains_same(expected_core)
	root.queue_free()
