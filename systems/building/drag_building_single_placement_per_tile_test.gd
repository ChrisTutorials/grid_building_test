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
var placeable_no_rules: Placeable
var placement_attempts: int = 0
var placed_objects: Array[Node2D] = []
var indicator_manager : IndicatorManager

var _container: GBCompositionContainer
var _injector : GBInjectorSystem

## Helper: build a compact validation summary string for failure messages
func _validation_summary(validation: ValidationResults) -> String:
	if validation == null:
		return "validation=null"
	var parts: Array = []
	if validation.rule_results:
		for rr in validation.rule_results:
			var rule_name = rr.rule.get_class() if rr.rule else "<no-rule>"
			parts.append("%s:%s" % [rule_name, rr.reason])
	return "is_successful=%s issues=%s rule_results=%s" % [str(validation.is_successful()), str(validation.get_issues()), str(parts)]

func before_test():
	var test_env = UnifiedTestFactory.create_building_system_test_environment(self)
	_container = test_env.container
	_injector = test_env.injector
	placement_attempts = 0
	placed_objects.clear()
	placer = test_env.placer
	placed_parent = test_env.placed_parent
	grid_positioner = test_env.grid_positioner
	indicator_manager = test_env.indicator_manager
	map_layer = test_env.map_layer
	targeting_state = test_env.targeting_state
	mode_state = test_env.mode_state
	system = test_env.system

	# Connect to success signal to track placement attempts (avoid duplicate connections)
	var states = _container.get_states()
	if not states.building.success.is_connected(_on_build_success):
		states.building.success.connect(_on_build_success)

	# Create a placeable with NO rules (this allows unlimited placement without validation)
	placeable_no_rules = auto_free(Placeable.new())
	# Use the unified test factory to create a valid packed scene for previews in tests.
	placeable_no_rules.packed_scene = UnifiedTestFactory.create_test_eclipse_packed_scene(self)
	# Give a minimal within-tilemap-bounds rule so the validator has at least one active rule
	# This preserves original intent (no collision rules) but allows validation to proceed.
	placeable_no_rules.placement_rules = [UnifiedTestFactory.create_test_within_tilemap_bounds_rule()]

func _on_build_success(build_action: BuildActionData):
	placement_attempts += 1
	if build_action.placed:
		placed_objects.append(build_action.placed)

func test_setup_validation():
	assert_object(system).is_not_null()
	assert_object(placeable_no_rules).is_not_null()
	# The placeable in tests now includes a minimal WithinTilemapBoundsRule to allow validator processing
	assert_array(placeable_no_rules.placement_rules).is_not_empty()

func test_drag_building_single_placement_per_tile_switch():
	# Enter build mode with placeable that has no rules
	var success = system.enter_build_mode(placeable_no_rules)
	assert_bool(success.is_successful()).is_true()
	
	# Enable drag multi-build
	system._building_settings.drag_multi_build = true
	
	# Position positioner at a safe start tile well inside the populated map
	# Compute a start tile with margin so indicator offsets won't be out of bounds
	var used_rect = map_layer.get_used_rect()
	var start_tile := Vector2i(8, 8)
	# Ensure start_tile is inside used_rect (add small margin)
	start_tile.x = clamp(start_tile.x, int(used_rect.position.x) + 2, int(used_rect.position.x + used_rect.size.x) - 3)
	start_tile.y = clamp(start_tile.y, int(used_rect.position.y) + 2, int(used_rect.position.y + used_rect.size.y) - 3)
	grid_positioner.global_position = map_layer.to_global(map_layer.map_to_local(start_tile))
	
	# Start drag building
	var drag_manager = system.get_lazy_drag_manager()
	var drag_data = drag_manager.start_drag()
	assert_object(drag_data).is_not_null()
	assert_bool(drag_manager.is_drag_building()).is_true()
	
	# First placement attempt at tile (0,0) - this should succeed
	# Validate placement state before attempting build and fail with appended diagnostics if invalid
	var pre_validation = indicator_manager.validate_placement()
	assert_bool(pre_validation.is_successful()).append_failure_message(_validation_summary(pre_validation)).is_true()
	var first_placed = system.try_build()
	assert_object(first_placed).is_not_null()
	assert_int(placement_attempts).append_failure_message(_validation_summary(indicator_manager.validate_placement())).is_equal(1)
	assert_int(placed_objects.size()).append_failure_message(_validation_summary(indicator_manager.validate_placement())).is_equal(1)
	
	# Now move to the same tile but trigger tile switch event manually
	# This simulates the drag system firing targeting_new_tile for the same tile
	# (which can happen due to rounding or other precision issues)
	system._on_drag_targeting_new_tile(drag_data, Vector2i(0, 0), Vector2i(0, 0))
	
	# This should NOT create another placement at the same tile
	# But currently it will because there's no check to prevent multiple placements per tile
	assert_int(placement_attempts).is_equal(1) # WILL FAIL - this is the regression
	assert_int(placed_objects.size()).is_equal(1) # WILL FAIL - this is the regression
	
	# Now move to a different tile (start_tile + (1,0))
	grid_positioner.global_position = map_layer.to_global(map_layer.map_to_local(start_tile + Vector2i(1, 0)))
	drag_data.update(0.016) # Update drag data
	
	# Trigger tile switch to new tile
	system._on_drag_targeting_new_tile(drag_data, Vector2i(1, 0), Vector2i(0, 0))
	
	# Validate before attempting the second placement
	var second_validation = indicator_manager.validate_placement()
	assert_bool(second_validation.is_successful()).append_failure_message(_validation_summary(second_validation)).is_true()
	# This should create ONE placement at the new tile
	assert_int(placement_attempts).append_failure_message(_validation_summary(indicator_manager.validate_placement())).is_equal(2)
	assert_int(placed_objects.size()).append_failure_message(_validation_summary(indicator_manager.validate_placement())).is_equal(2)
	
	# Moving within the same tile should not create additional placements (slight offset inside same tile)
	grid_positioner.global_position = map_layer.to_global(map_layer.map_to_local(start_tile + Vector2i(1, 0))) + Vector2(4, 4)
	drag_data.update(0.016)
	
	# Trigger same tile event again (simulating multiple events on same tile)
	system._on_drag_targeting_new_tile(drag_data, Vector2i(1, 0), Vector2i(1, 0))
	
	# Should still only be 2 placements total
	assert_int(placement_attempts).append_failure_message(_validation_summary(indicator_manager.validate_placement())).is_equal(2) # WILL FAIL - this is the regression
	assert_int(placed_objects.size()).append_failure_message(_validation_summary(indicator_manager.validate_placement())).is_equal(2) # WILL FAIL - this is the regression
	
	# Move to third tile (start_tile + (0,1))
	grid_positioner.global_position = map_layer.to_global(map_layer.map_to_local(start_tile + Vector2i(0, 1)))
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
	assert_bool(success.is_successful()).is_true()
	
	# Enable drag multi-build
	system._building_settings.drag_multi_build = true
	
	# Position positioner at a safe start tile inside the populated map so placement hits valid cells
	var used_rect = map_layer.get_used_rect()
	var start_tile := Vector2i(8, 8)
	start_tile.x = clamp(start_tile.x, int(used_rect.position.x) + 2, int(used_rect.position.x + used_rect.size.x) - 3)
	start_tile.y = clamp(start_tile.y, int(used_rect.position.y) + 2, int(used_rect.position.y + used_rect.size.y) - 3)
	grid_positioner.global_position = map_layer.to_global(map_layer.map_to_local(start_tile))

	# Start drag
	var drag_manager = system.get_lazy_drag_manager()
	var drag_data = drag_manager.start_drag()
	
	# Multiple rapid tile switch events to same tile should only place once
	for i in range(5):
		system._on_drag_targeting_new_tile(drag_data, Vector2i(0, 0), Vector2i(-1, -1))
	
	# Should only have one placement despite multiple events
	assert_int(placement_attempts).is_equal(1)
	assert_int(placed_objects.size()).is_equal(1)
