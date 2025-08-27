extends GdUnitTestSuite

func test_tile_shape_drives_mapping():
	var map_layer: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	# Set tile_shape on tileset to isometric (1)
	map_layer.tile_set.tile_shape = GBEnums.TileType.ISOMETRIC

	# Simple square polygon centered at origin
	var poly: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))

	var targeting_state = GridTargetingState.new()
	targeting_state.positioner = GodotTestFactory.create_node2d(self)
	targeting_state.positioner.global_position = Vector2.ZERO

	var logger = GBLogger.new()
	var mapper = PolygonTileMapper.new(targeting_state, logger)
	var offsets = mapper.compute_tile_offsets(poly, map_layer)
	assert_array(offsets).is_not_empty()
