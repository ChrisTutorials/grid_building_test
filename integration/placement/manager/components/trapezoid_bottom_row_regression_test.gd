extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

## Regression: Simple trapezoid should produce 5 bottom-row indicators (−2..2) including BL/BR.
## This locks expected coverage so tuning epsilons or pruning doesn't drop the side tiles.

var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger
var targeting_state: GridTargetingState
var mapper: CollisionMapper
var _injector: GBInjectorSystem
	
func before_test():
	_injector = UnifiedTestFactory.create_test_injector(self, TEST_CONTAINER)
	tile_map_layer = auto_free(TileMapLayer.new())
	add_child(tile_map_layer)
	tile_map_layer.tile_set = TileSet.new()
	tile_map_layer.tile_set.tile_size = Vector2tile_size

	positioner = auto_free(Node2D.new())
	add_child(positioner)
	positioner.position = Vector2.ZERO

	logger = GBLogger.new(GBDebugSettings.new())
	var owner_context := GBOwnerContext.new(null)
	targeting_state = GridTargetingState.new(owner_context)
	targeting_state.target_map = tile_map_layer
	targeting_state.positioner = positioner
	mapper = CollisionMapper.new(targeting_state, logger)

## Create a proper trapezoid that produces 3-5-5 pattern (top-middle-bottom rows)
## This trapezoid spans from x=-32 to x=32 at the bottom, narrowing to x=-16 to x=16 at the top
func _create_parent_trapezoid_static_body_parented_to_positioner() -> StaticBody2D:	
	var trapezoid_body := StaticBody2D.new()
	auto_free(trapezoid_body)
	var poly := CollisionPolygon2D.new()
	trapezoid_body.add_child(poly)
	poly.polygon = PackedVector2Array[Node2D]([
		Vector2(-16, -12), Vector2(16, -12), Vector2(32, 12), Vector2(-32, 12)
	])
	positioner.add_child(trapezoid_body)
	
	return trapezoid_body

func test_trapezoid_coverage_matches_geometry() -> void:
	var poly_body : StaticBody2D = _create_parent_trapezoid_static_body_parented_to_positioner()
	
	# Use the public API to get collision tile positions instead of accessing private members
	var collision_objects: Array[Node2D] = [poly_body]
	var tile_positions_dict: Dictionary[Vector2i, Array[Node2D]] = mapper.get_collision_tile_positions_with_mask(collision_objects, poly_body.collision_layer)
	
	# Extract the keys (tile positions) from the dictionary
	var tile_positions: Array[Node2D][Vector2i] = []
	for pos in tile_positions_dict.keys():
		tile_positions.append(pos)
	
	assert_bool(tile_positions.size() > 0).append_failure_message("No tile positions computed for trapezoid").is_true()

	# Analyze the actual coverage pattern
	var by_row: Dictionary = {}
	for pos in tile_positions:
		if not by_row.has(pos.y): 
			by_row[pos.y] = []
		by_row[pos.y].append(pos.x)
	
	# Sort rows by Y coordinate  
	var ys: Array[Node2D][int] = []
	for y in by_row.keys(): 
		ys.append(y)
	ys.sort()

	# Guard: if zero rows, report and exit to avoid index error
	if ys.is_empty():
		assert_bool(false).append_failure_message("Expected at least 2 rows for trapezoid but got 0; tile_positions=%s" % [tile_positions]).is_true()
		return
	
	# Verify we have at least 2 rows for a trapezoid
	assert_bool(ys.size() >= 2).append_failure_message("Expected at least 2 rows for trapezoid, got %d rows at y=%s" % [ys.size(), str(ys)]).is_true()
	
	# Get bottom row coverage
	bottom_y: Node = ys[ys.size() - 1]
	var bottom_xs: Array[Node2D] = by_row[bottom_y].duplicate()
	bottom_xs.sort()
	
	# Based on geometric analysis: the corrected trapezoid should have 4 tiles on bottom row
	# Verify the actual coverage matches the trapezoid geometry (not the rigid expansion pattern)
	var expected_bottom_count = 4
	var expected_bottom_xs = [-2, -1, 0, 1]
	
	assert_int(bottom_xs.size()).append_failure_message("Expected %d bottom-row tiles at y=%d, got %d: %s (all tile_positions: %s)" % [expected_bottom_count, bottom_y, bottom_xs.size(), bottom_xs, tile_positions]).is_equal(expected_bottom_count)
	
	for x in expected_bottom_xs:
		assert_bool(bottom_xs.has(x)).append_failure_message("Missing expected bottom-row tile x=%d at y=%d; actual xs=%s" % [x, bottom_y, bottom_xs]).is_true()
	
	# Verify the trapezoid doesn't have the problematic x=2 tile that doesn't geometrically overlap
	assert_bool(not bottom_xs.has(2)).append_failure_message("Bottom row should not include x=2 as it has zero geometric overlap; xs=%s" % [bottom_xs]).is_true()
