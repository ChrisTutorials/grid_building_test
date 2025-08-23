# Test for ensuring only one placement attempt per tile switch during drag building
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

var system: BuildingSystem
var targeting_state: GridTargetingState
var mode_state: ModeState
var grid_positioner: Node2D
var map_layer: TileMapLayer
var placer: Node2D
var placed_parent: Node2D
var _container: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var placeable_no_rules: Placeable
var placement_attempts: int = 0
var placed_objects: Array[Node2D] = []

func before_test():
	placement_attempts = 0
	placed_objects.clear()
	
	placer = GodotTestFactory.create_node2d(self)
	placed_parent = GodotTestFactory.create_node2d(self)
	grid_positioner = GodotTestFactory.create_node2d(self)
	# Tile map layer used for targeting
	map_layer = GodotTestFactory.create_empty_tile_map_layer(self)

	var states := _container.get_states()
	targeting_state = states.targeting
	targeting_state.positioner = grid_positioner
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	mode_state = states.mode

	# Proper owner: create GBOwner node and inject so BuildingState can resolve owner_root
	var gb_owner := GBOwner.new(placer)
	add_child(gb_owner)
	gb_owner.resolve_gb_dependencies(_container)

	# Create building system via factory (injects dependencies & ensures placement manager)
	system = auto_free(BuildingSystem.create_with_injection(_container))
	add_child(system)

	states.building.placed_parent = placed_parent
	
	# Connect to success signal to track placement attempts
	states.building.success.connect(_on_build_success)
	
	# Create a placeable with NO rules (this allows unlimited placement without validation)
	placeable_no_rules = auto_free(Placeable.new())
	placeable_no_rules.packed_scene = load("uid://c5tpn1q8rr5u2") # Simple box scene
	placeable_no_rules.placement_rules = [] # No collision or tile check rules

func _on_build_success(build_action: BuildActionData):
	placement_attempts += 1
	if build_action.placed:
		placed_objects.append(build_action.placed)

func test_setup_validation():
	assert_object(system).is_not_null()
	assert_object(placeable_no_rules).is_not_null()
	assert_array(placeable_no_rules.placement_rules).is_empty()

func test_drag_building_single_placement_per_tile_switch():
	# Enter build mode with placeable that has no rules
	var success = system.enter_build_mode(placeable_no_rules)
	assert_bool(success).is_true()
	
	# Enable drag multi-build
	system._building_settings.drag_multi_build = true
	
	# Position positioner at tile (0,0)
	grid_positioner.global_position = Vector2(8, 8) # Center of tile (0,0) assuming 16x16 tiles
	
	# Start drag building
	var drag_manager = system._get_lazy_drag_manager()
	var drag_data = drag_manager.start_drag()
	assert_object(drag_data).is_not_null()
	assert_bool(drag_manager.is_drag_building()).is_true()
	
	# First placement attempt at tile (0,0) - this should succeed
	var first_placed = system.try_build()
	assert_object(first_placed).is_not_null()
	assert_int(placement_attempts).is_equal(1)
	assert_int(placed_objects.size()).is_equal(1)
	
	# Now move to the same tile but trigger tile switch event manually
	# This simulates the drag system firing targeting_new_tile for the same tile
	# (which can happen due to rounding or other precision issues)
	system._on_drag_targeting_new_tile(drag_data, Vector2i(0, 0), Vector2i(0, 0))
	
	# This should NOT create another placement at the same tile
	# But currently it will because there's no check to prevent multiple placements per tile
	assert_int(placement_attempts).is_equal(1) # WILL FAIL - this is the regression
	assert_int(placed_objects.size()).is_equal(1) # WILL FAIL - this is the regression
	
	# Now move to a different tile (1,0)
	grid_positioner.global_position = Vector2(24, 8) # Center of tile (1,0)
	drag_data.update(0.016) # Update drag data
	
	# Trigger tile switch to new tile
	system._on_drag_targeting_new_tile(drag_data, Vector2i(1, 0), Vector2i(0, 0))
	
	# This should create ONE placement at the new tile
	assert_int(placement_attempts).is_equal(2)
	assert_int(placed_objects.size()).is_equal(2)
	
	# Moving within the same tile should not create additional placements
	grid_positioner.global_position = Vector2(20, 12) # Still within tile (1,0)
	drag_data.update(0.016)
	
	# Trigger same tile event again (simulating multiple events on same tile)
	system._on_drag_targeting_new_tile(drag_data, Vector2i(1, 0), Vector2i(1, 0))
	
	# Should still only be 2 placements total
	assert_int(placement_attempts).is_equal(2) # WILL FAIL - this is the regression
	assert_int(placed_objects.size()).is_equal(2) # WILL FAIL - this is the regression
	
	# Move to third tile (0,1)
	grid_positioner.global_position = Vector2(8, 24) # Center of tile (0,1)
	drag_data.update(0.016)
	
	# Trigger tile switch to third tile
	system._on_drag_targeting_new_tile(drag_data, Vector2i(0, 1), Vector2i(1, 0))
	
	# Should now be 3 placements total
	assert_int(placement_attempts).is_equal(3)
	assert_int(placed_objects.size()).is_equal(3)
	
	# Verify all placed objects are at different positions
	assert_vector(placed_objects[0].global_position).append_failure_message("Position 0 is not equal to Position 1").is_not_equal(placed_objects[1].global_position)
	assert_vector(placed_objects[1].global_position).append_failure_message("Position 1 is not equal to Position 2").is_not_equal(placed_objects[2].global_position)
	assert_vector(placed_objects[0].global_position).append_failure_message("Position 0 is not equal to Position 2").is_not_equal(placed_objects[2].global_position)

	# Stop drag
	drag_manager.stop_drag()
	assert_bool(drag_manager.is_drag_building()).is_false()

func test_tile_tracking_prevents_duplicate_placements():
	# This test validates the fix by ensuring the building system tracks
	# which tiles have already been built on during the current drag operation
	
	# Enter build mode
	var success = system.enter_build_mode(placeable_no_rules)
	assert_bool(success).is_true()
	
	# Enable drag multi-build
	system._building_settings.drag_multi_build = true
	
	# Start drag
	var drag_manager = system._get_lazy_drag_manager()
	var drag_data = drag_manager.start_drag()
	
	# Multiple rapid tile switch events to same tile should only place once
	for i in range(5):
		system._on_drag_targeting_new_tile(drag_data, Vector2i(0, 0), Vector2i(-1, -1))
	
	# Should only have one placement despite multiple events
	assert_int(placement_attempts).is_equal(1)
	assert_int(placed_objects.size()).is_equal(1)
