extends GdUnitTestSuite

func test_tile_shape_preference_from_map():
	# Create a minimal TargetingState mock with positioner and settings
	var owner = GBOwnerContext.new()
	var targeting = GridTargetingState.new(owner)
	
	# Create a TileSet resource and set it to ISOMETRIC
	var tileset = TileSet.new()
	tileset.tile_shape = TileSet.TileShape.ISOMETRIC
	# Create a TileMapLayer and assign tileset and tile_size
	var map := TileMapLayer.new()
	map.tile_set = tileset
	map.tile_set.tile_size = Vector2(32, 32)
	
	# Create a simple CollisionPolygon2D in world space near origin
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	poly.global_position = Vector2(0,0)
	
	# Mock positioner (centered over origin)
	var pos = Node2D.new()
	pos.global_position = Vector2(0,0)
	targeting.positioner = pos
	targeting.target_map = map
	
	# Use a real logger for diagnostics
	var logger = GBLogger.new()
	
	var mapper = PolygonTileMapper.new(targeting, logger)
	var offsets = mapper.compute_tile_offsets(poly, map)
	# Expect some offsets to be returned for this small square-shaped polygon on isometric tiles
	assert_true(offsets.size() > 0, "Expected offsets to be non-empty when map specifies isometric tile_shape")
