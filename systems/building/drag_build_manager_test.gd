# Single GdUnitTestSuite extension
extends GdUnitTestSuite


# Test for DragBuildManager to ensure only one event per tile location

var manager: DragBuildManager
var events: Array[Vector2i] = []

func before_test():
	events = []
	# Create targeting state with proper positioner setup using GodotTestFactory
	var targeting_state = auto_free(GridTargetingState.new(auto_free(GBOwnerContext.new())))
	
	# Create positioner using GodotTestFactory - it automatically adds as child
	var positioner = GodotTestFactory.create_node2d(self)
	targeting_state.positioner = positioner
	
	# Create target map with proper setup
	var target_map = GodotTestFactory.create_tile_map_layer(self)
	targeting_state.target_map = target_map
	
	# Create manager with targeting state
	manager = auto_free(DragBuildManager.new(targeting_state))
	
	# Create DragPathData with proper positioner
	var data = DragPathData.new(positioner, targeting_state)
	manager.drag_data = data
	
	# Listen to tile change events
	manager.connect("targeting_new_tile", Callable(self, "_on_targeting_new_tile"))
	add_child(manager)

func _on_targeting_new_tile(_drag_data, new_tile: Vector2i, _old_tile: Vector2i) -> void:
	events.append(new_tile)

func test_single_emit_per_tile() -> void:
	# No change in tile -> no events
	manager._process(0.1)
	assert_int(events.size()).is_equal(0)
	manager._process(0.1)
	assert_int(events.size()).is_equal(0)

	# Change to new tile -> one event
	var data = manager.drag_data
	data.next_tile = Vector2i(1, 2)
	manager._process(0.1)
	assert_int(events.size()).is_equal(1)
	assert_that(events[0]).is_equal(Vector2i(1, 2))

	# Same tile again -> still one event
	manager._process(0.1)
	assert_int(events.size()).is_equal(1)

	# Change to another tile -> second event
	data.next_tile = Vector2i(3, 4)
	manager._process(0.1)
	assert_int(events.size()).is_equal(2)
	assert_that(events[1]).is_equal(Vector2i(3, 4))
