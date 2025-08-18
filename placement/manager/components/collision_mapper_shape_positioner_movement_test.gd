extends GdUnitTestSuite

# Verifies CollisionObject2D shape offsets change when only the positioner moves (object not parented)
# and remain stable when object is parented to the positioner.

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var collision_mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var positioner: Node2D

func before_test():
	# Setup targeting state inside container
	var container_states = TEST_CONTAINER.get_states()
	targeting_state = container_states.targeting
	if targeting_state == null:
		targeting_state = GridTargetingState.new(GBOwnerContext.new())
		container_states.targeting = targeting_state

	positioner = GodotTestFactory.create_node2d(self)
	positioner.name = "TestPositioner"
	targeting_state.positioner = positioner
	tile_map_layer = GodotTestFactory.create_tile_map_layer(self, 40)
	targeting_state.target_map = tile_map_layer

	collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)

func _create_rect_area(size: Vector2) -> Area2D:
	var area: Area2D = auto_free(Area2D.new())
	area.collision_layer = 1
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	area.add_child(shape_node)
	add_child(area)
	return area

func _collect_offsets(area: Area2D) -> Array:
	var logger := TEST_CONTAINER.get_logger()
	var setup := IndicatorCollisionTestSetup.new(area, Vector2.ZERO, logger)
	var dict: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(setup)
	return dict.keys()

func test_shape_offsets_do_not_change_when_only_positioner_moves():
	var area := _create_rect_area(Vector2(16,16))
	area.global_position = Vector2(512, 512)
	positioner.global_position = Vector2(0,0)
	var offsets1 = _collect_offsets(area)
	positioner.global_position = Vector2(32,32)
	var offsets2 = _collect_offsets(area)
	assert_that(offsets1).append_failure_message("Offsets should remain the same; shape anchored to its own position").is_equal(offsets2)

## NOTE (Semantics Change): Shape (CollisionObject2D) offsets are anchored to the shape's own tile, not the positioner.
## Therefore moving the unparented shape in world space does NOT change its local tile coverage pattern (offset set).
## This test now verifies that although the shape's center tile changes, the offset pattern remains identical.
func test_shape_offsets_stable_when_object_moves_unparented():
	var area := _create_rect_area(Vector2(16,16))
	area.global_position = Vector2(512, 512)
	positioner.global_position = Vector2(0,0)
	# Capture starting tile position of shape (via its global position converted through map)
	var start_tile : Vector2i = tile_map_layer.local_to_map(tile_map_layer.to_local(area.global_position))
	var offsets1 = _collect_offsets(area)
	# Move shape by more than one tile (assumes tile size from factory >= 32). Using large delta to guarantee tile change.
	var move_delta := Vector2(160,160) # 4 tiles if tile size is 40
	area.global_position += move_delta
	var end_tile : Vector2i = tile_map_layer.local_to_map(tile_map_layer.to_local(area.global_position))
	var offsets2 = _collect_offsets(area)

	# Assert we actually changed tile to make the test meaningful
	assert_that(end_tile).append_failure_message("Shape failed to move to a different tile. start=%s end=%s delta=%s" % [str(start_tile), str(end_tile), str(move_delta)]).is_not_equal(start_tile)
	# Offsets should remain identical under new semantics
	assert_that(offsets2).append_failure_message("Offsets changed unexpectedly after moving shape.\nStart tile=%s End tile=%s\nBefore=%s\nAfter=%s\nSemantic expectation: shape-local coverage remains constant when unparented." % [str(start_tile), str(end_tile), str(offsets1), str(offsets2)]).is_equal(offsets1)

func test_shape_offsets_stable_when_parented_and_positioner_moves():
	var area := _create_rect_area(Vector2(16,16))
	area.name = "RectArea"
	area.position = Vector2(128,128)
	positioner.global_position = Vector2(0,0)
	var offsets1 = _collect_offsets(area)
	positioner.global_position = Vector2(64,64)
	var offsets2 = _collect_offsets(area)
	assert_that(offsets1).append_failure_message("Offsets should remain stable when shape parented to positioner").is_equal(offsets2)
