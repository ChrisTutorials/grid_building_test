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
	tile_map_layer.tile_set.tile_size = Vector2(16, 16)

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
	poly.polygon = PackedVector2Array([
		Vector2(-16, -12), Vector2(16, -12), Vector2(32, 12), Vector2(-32, 12)
	])
	positioner.add_child(trapezoid_body)
	
	return trapezoid_body

func test_trapezoid_coverage_matches_geometry() -> void:
	var poly_body : StaticBody2D = _create_parent_trapezoid_static_body_parented_to_positioner()
	# Access the CollisionPolygon2D child directly so we can use the polygon mapping path.
	# The generic test setup path returned empty offsets because a StaticBody2D with a CollisionPolygon2D
	# child isn't processed by the shape processor (it looks for CollisionShape2D owners).
	var poly: CollisionPolygon2D = poly_body.get_child(0)
	assert_bool(poly is CollisionPolygon2D).append_failure_message("Expected first child of trapezoid body to be CollisionPolygon2D").is_true()
	# Use internal polygon processor for precise trapezoid coverage.
	var dict = mapper._polygon_processor.get_tile_offsets_for_collision_polygon(poly, targeting_state.target_map)
	var offsets: Array[Vector2i] = []
	for k in dict.keys(): offsets.append(k)
	assert_bool(offsets.size() > 0).append_failure_message("No offsets computed for trapezoid").is_true()

	# Analyze the actual coverage pattern
	var by_row: Dictionary = {}
	for o in offsets:
		if not by_row.has(o.y): by_row[o.y] = []
		by_row[o.y].append(o.x)
	
	# Sort rows by Y coordinate  
	var ys: Array[int] = []
	for y in by_row.keys(): ys.append(y)
	ys.sort()

	# Guard: if zero rows, report and exit to avoid index error
	if ys.is_empty():
		assert_bool(false).append_failure_message("Expected at least 2 rows for trapezoid but got 0; offsets=%s" % [offsets]).is_true()
		return
	
	# Verify we have at least 2 rows for a trapezoid
	assert_bool(ys.size() >= 2).append_failure_message("Expected at least 2 rows for trapezoid, got %d rows at y=%s" % [ys.size(), str(ys)]).is_true()
	
	# Get bottom row coverage
	var bottom_y = ys[ys.size() - 1]
	var bottom_xs: Array = by_row[bottom_y].duplicate()
	bottom_xs.sort()
	
	# Based on geometric analysis: the corrected trapezoid should have 4 tiles on bottom row
	# Verify the actual coverage matches the trapezoid geometry (not the rigid expansion pattern)
	var expected_bottom_count = 4
	var expected_bottom_xs = [-2, -1, 0, 1]
	
	assert_int(bottom_xs.size()).append_failure_message("Expected %d bottom-row tiles at y=%d, got %d: %s (all offsets: %s)" % [expected_bottom_count, bottom_y, bottom_xs.size(), bottom_xs, offsets]).is_equal(expected_bottom_count)
	
	for x in expected_bottom_xs:
		assert_bool(bottom_xs.has(x)).append_failure_message("Missing expected bottom-row tile x=%d at y=%d; actual xs=%s" % [x, bottom_y, bottom_xs]).is_true()
	
	# Verify the trapezoid doesn't have the problematic x=2 tile that doesn't geometrically overlap
	assert_bool(not bottom_xs.has(2)).append_failure_message("Bottom row should not include x=2 as it has zero geometric overlap; xs=%s" % [bottom_xs]).is_true()
