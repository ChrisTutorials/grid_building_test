extends GdUnitTest

func test_isometric_tile_shape_produces_offsets():
	# Create fake TileMapLayer with a TileSet that exposes tile_shape
	var map_layer = Node.new() as TileMapLayer
	# Create a minimal TileSet resource and attach a tile_shape property
	var ts = TileSet.new()
	# Use integer enum value for isometric if the engine exposes TileSet.TileShape.ISOMETRIC; else assume 1
	# Attempt to set property defensively
	if ts.has_method("set"): # resources accept set
		# Best-effort: some engine versions may not have tile_shape property on TileSet
		# We'll attach it dynamically for the test
		ts.set("tile_shape", TileSet.TileShape.ISOMETRIC if typeof(TileSet.TileShape) == TYPE_OBJECT or true else 1)
	map_layer.tile_set = ts

	# Build a simple polygon around origin (square) as CollisionPolygon2D
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])

	# Create dummy targeting state and positioner
	var targeting_state = GridTargetingState.new()
	targeting_state.positioner = Node2D.new()
	targeting_state.positioner.global_position = Vector2.ZERO

	var logger = GBLogger.new()
	var mapper = PolygonTileMapper.new(targeting_state, logger)
	var offsets = mapper.compute_tile_offsets(poly, map_layer)
	assert_array(offsets).is_not_empty()
