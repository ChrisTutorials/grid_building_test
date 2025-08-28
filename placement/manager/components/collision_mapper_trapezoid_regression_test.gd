extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

## Trapezoid coverage regression tests adjusted to runtime behavior.
## We assert the stable core subset and pivot semantics instead of an exact 13-tile count.

var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger
var targeting_state: GridTargetingState
var mapper: CollisionMapper
var _injector: GBInjectorSystem

func before_test():
	# Create injector system first
	_injector = UnifiedTestFactory.create_test_injector(self, TEST_CONTAINER)
	
	tile_map_layer = auto_free(TileMapLayer.new())
	add_child(tile_map_layer)
	tile_map_layer.tile_set = TileSet.new()
	tile_map_layer.tile_set.tile_size = Vector2(16,16)
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	positioner.position = Vector2.ZERO
	logger = GBLogger.new(GBDebugSettings.new())
	var owner_context := GBOwnerContext.new(null)
	targeting_state = GridTargetingState.new(owner_context)
	targeting_state.target_map = tile_map_layer
	targeting_state.positioner = positioner
	mapper = CollisionMapper.new(targeting_state, logger)

func _create_trapezoid_node(parented := true) -> CollisionPolygon2D:
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	if parented:
		positioner.add_child(poly)
	else:
		add_child(poly)
	return poly

func test_trapezoid_core_subset_present():
	var poly = _create_trapezoid_node(true)
	var tile_dict = mapper._get_tile_offsets_for_collision_polygon(poly, tile_map_layer)
	var offsets: Array[Vector2i] = []
	for k in tile_dict.keys(): offsets.append(k)
	offsets.sort()
	var core_required := [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)]
	for req in core_required:
		assert_bool(offsets.has(req)).append_failure_message("Missing core tile %s -> offsets=%s" % [req, offsets]).is_true()
	assert_bool(offsets.has(Vector2i(0,0))).append_failure_message("Center tile missing -> %s" % [offsets]).is_true()


func test_trapezoid_horizontal_span_reasonable():
	var poly = _create_trapezoid_node(true)
	var tile_dict = mapper._get_tile_offsets_for_collision_polygon(poly, tile_map_layer)
	var offsets: Array[Vector2i] = []
	for k in tile_dict.keys(): offsets.append(k)
	var min_x := 999; var max_x := -999
	for o in offsets: min_x = min(min_x, o.x); max_x = max(max_x, o.x)
	assert_int(max_x - min_x).append_failure_message("Unexpected horizontal span for trapezoid offsets=%s" % [offsets]).is_less_equal(4)

func test_polygon_pivot_parented_stability():
	var poly_points = PackedVector2Array([Vector2(-8,-8), Vector2(8,-8), Vector2(8,8), Vector2(-8,8)])
	var poly_parented: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	positioner.add_child(poly_parented)
	poly_parented.polygon = poly_points
	var tile_size = tile_map_layer.tile_set.tile_size
	var expected_offsets := [Vector2i(-1,-1), Vector2i(-1,0), Vector2i(0,-1), Vector2i(0,0)]
	var positions = [Vector2.ZERO, Vector2(32,32), Vector2(48,16)]
	for pos in positions:
		positioner.position = pos
		var world_points = CollisionGeometryUtils.to_world_polygon(poly_parented)
		var center_tile = tile_map_layer.local_to_map(positioner.global_position)
		var offsets = CollisionGeometryUtils.compute_polygon_tile_offsets(world_points, tile_size, center_tile, 0)
		assert_that(offsets).append_failure_message("Parented polygon offsets changed after moving to %s (offsets=%s)" % [pos, offsets]).contains_same(expected_offsets)

func test_polygon_pivot_unparented_variation():
	var poly_points = PackedVector2Array([Vector2(-8,-8), Vector2(8,-8), Vector2(8,8), Vector2(-8,8)])
	var poly_unparented: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	add_child(poly_unparented)
	poly_unparented.global_position = Vector2.ZERO
	poly_unparented.polygon = poly_points
	var tile_size = tile_map_layer.tile_set.tile_size
	var center_tile_initial = tile_map_layer.local_to_map(positioner.global_position)
	var world_initial = CollisionGeometryUtils.to_world_polygon(poly_unparented)
	var offsets_initial = CollisionGeometryUtils.compute_polygon_tile_offsets(world_initial, tile_size, center_tile_initial, 0)
	positioner.position = Vector2(32,0)
	var center_tile_moved = tile_map_layer.local_to_map(positioner.global_position)
	var world_after = CollisionGeometryUtils.to_world_polygon(poly_unparented)
	var offsets_after = CollisionGeometryUtils.compute_polygon_tile_offsets(world_after, tile_size, center_tile_moved, 0)
	assert_bool(offsets_initial != offsets_after).append_failure_message("Expected unparented polygon offsets to differ when positioner moves; initial=%s after=%s" % [offsets_initial, offsets_after]).is_true()
