extends GdUnitTestSuite

## TDD failing test for Issue #27: Area2D rotation should change indicator tile offsets.
## Currently CollisionMapper/_get_tile_offsets_for_collision_object does NOT apply the parent (Area2D) rotation
## to the shape polygon when converting shapes, so a rotated non-square rectangle still produces horizontal offsets.
## This test encodes the expected behavior: a 48x16 rectangle rotated 90 degrees should occupy vertical tile offsets
## instead of horizontal ones. It should FAIL until the rotation is applied in the collision mapping logic.

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var targeting_state: GridTargetingState
var tile_map: TileMapLayer
var positioner: Node2D
var indicator_parent: Node2D
var indicator_manager: IndicatorManager
var logger: GBLogger

func before_test():
	# Set up targeting state and map identical to other component tests
	targeting_state = auto_free(GridTargetingState.new(GBOwnerContext.new()))
	positioner = GodotTestFactory.create_node2d(self) # factory already parents node
	targeting_state.positioner = positioner

	tile_map = GodotTestFactory.create_empty_tile_map_layer(self) # already parented
	tile_map.tile_set.tile_size = Vector2i(16, 16)
	targeting_state.target_map = tile_map
	targeting_state.maps = [tile_map]

	# Inject targeting state into container singleton state (mirrors other tests' pattern)
	TEST_CONTAINER.get_states().targeting = targeting_state

	logger = TEST_CONTAINER.get_logger()
	indicator_parent = GodotTestFactory.create_node2d(self) # already parented
	UnifiedTestFactory.create_test_injector(self, TEST_CONTAINER)
	indicator_manager = IndicatorManager.create_with_injection(TEST_CONTAINER, indicator_parent)

func _create_area2d_rect(width: float, height: float, layer: int) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = layer
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	cs.shape = rect
	area.add_child(cs)
	return area

func _gather_indicator_offsets() -> Array[Vector2i]:
	var center_tile = tile_map.local_to_map(tile_map.to_local(positioner.global_position))
	var offsets: Array[Vector2i] = []
	for ind in indicator_manager.get_indicators():
		var tile_pos = tile_map.local_to_map(tile_map.to_local(ind.global_position))
		offsets.append(tile_pos - center_tile)
	return offsets

func _rule(mask: int) -> TileCheckRule:
	var r := TileCheckRule.new()
	r.apply_to_objects_mask = mask
	return r

func test_area2d_rotation_changes_indicator_tile_offsets():
	# Unrotated: 48x16 rectangle (3 tiles wide, 1 tile tall) should yield horizontal offsets (-1,0),(0,0),(1,0)
	var area := _create_area2d_rect(48, 16, 1)
	positioner.add_child(area) # preview object must be child of positioner

	var rules: Array[TileCheckRule] = [_rule(1)]
	# Configure mapper before setup
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, area, TEST_CONTAINER, indicator_parent)
	var report_h: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules, indicator_parent)
	assert_int(report_h.indicators.size()).append_failure_message("Expected 3 horizontal indicators for unrotated rectangle").is_equal(3)
	var offsets_h: Array[Vector2i] = _gather_indicator_offsets()
	offsets_h.sort_custom(func(a,b): return a.x < b.x if a.y == b.y else a.y < b.y)
	var expected_h = [Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)]
	assert_that(offsets_h).append_failure_message("Horizontal offsets mismatch: %s" % [offsets_h]).is_equal(expected_h)

	# Reset manager (clears indicators & internal setups)
	indicator_manager.reset(indicator_parent)

	# Rotate area 90 degrees (PI/2). Expect vertical offsets (0,-1),(0,0),(0,1)
	area.rotation = PI/2
	# Reconfigure mapper after reset
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, area, TEST_CONTAINER, indicator_parent)
	var report_v: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules, indicator_parent)
	assert_int(report_v.indicators.size()).append_failure_message("Expected 3 vertical indicators for rotated rectangle").is_equal(3)
	var offsets_v: Array[Vector2i] = _gather_indicator_offsets()
	offsets_v.sort_custom(func(a,b): return a.y < b.y if a.x == b.x else a.x < b.x)
	var expected_v = [Vector2i(0,-1), Vector2i(0,0), Vector2i(0,1)]

	# Failing expectation for current implementation (will incorrectly still produce horizontal offsets)
	assert_that(offsets_v).append_failure_message("Rotated Area2D should yield vertical tile offsets; got %s" % [offsets_v]).is_equal(expected_v)

	# Cleanup preview object
	area.queue_free()
