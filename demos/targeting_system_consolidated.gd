extends GdUnitTestSuite

## Consolidated targeting system tests using factory patterns

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test():
	test_hierarchy = UnifiedTestFactory.create_systems_test_hierarchy(self, ["targeting", "building"], TEST_CONTAINER)

func test_targeting_basic():
	var targeting_system = test_hierarchy.targeting_system
	
	assert_object(targeting_system).is_not_null()
	
	# Test basic targeting
	var target_position = Vector2(64, 64)
	targeting_system.set_target_position(target_position)
	
	var current_target = targeting_system.get_current_target()
	assert_vector(current_target).is_equal(target_position)

func test_targeting_grid_alignment():
	var targeting_system = test_hierarchy.targeting_system
	var _tile_map = test_hierarchy.tile_map
	
	# Test grid-aligned targeting
	var world_pos = Vector2(50, 50)  # Not grid-aligned
	targeting_system.set_target_position_world(world_pos)
	
	var grid_target = targeting_system.get_grid_aligned_target()
	var tile_size = _tile_map.tile_set.tile_size
	
	# Should be aligned to grid
	assert_int(int(grid_target.x) % int(tile_size.x)).is_equal(0)
	assert_int(int(grid_target.y) % int(tile_size.y)).is_equal(0)

func test_targeting_validation():
	var targeting_system = test_hierarchy.targeting_system
	var tile_map = test_hierarchy.tile_map
	
	# Test valid position
	var valid_pos = Vector2(32, 32)
	targeting_system.set_target_position(valid_pos)
	assert_bool(targeting_system.is_target_valid()).is_true()
	
	# Test invalid position (out of bounds)
	var invalid_pos = Vector2(-100, -100)
	targeting_system.set_target_position(invalid_pos)
	assert_bool(targeting_system.is_target_valid()).is_false()

func test_targeting_with_rules():
	var targeting_system = test_hierarchy.targeting_system
	var _rule_checker = test_hierarchy.rule_checker
	
	var target_pos = Vector2(64, 32)
	targeting_system.set_target_position(target_pos)
	
	# Test targeting with rule validation
	var rule_result = targeting_system.validate_target_with_rules()
	assert_dict(rule_result).is_not_empty()

func test_targeting_area_selection():
	var targeting_system = test_hierarchy.targeting_system
	
	# Test area targeting
	var start_pos = Vector2(32, 32)
	var end_pos = Vector2(96, 64)
	
	targeting_system.set_area_selection(start_pos, end_pos)
	var selected_area = targeting_system.get_selected_area()
	
	assert_object(selected_area).is_not_null()
	assert_vector(selected_area.position).is_equal(start_pos)

func test_targeting_multiple_objects():
	var targeting_system = test_hierarchy.targeting_system
	var positioner = test_hierarchy.positioner
	
	# Add multiple objects
	var objects = []
	for i in range(3):
		var obj = Area2D.new()
		obj.position = Vector2(i * 32, 0)
		positioner.add_child(obj)
		objects.append(obj)
		auto_free(obj)
	
	# Test multi-target selection
	targeting_system.set_multi_target_mode(true)
	for obj in objects:
		targeting_system.add_target(obj.global_position)
	
	var targets = targeting_system.get_all_targets()
	assert_array(targets).size().is_equal(3)

func test_targeting_system_integration():
	var targeting_system = test_hierarchy.targeting_system
	var building_system = test_hierarchy.building_system
	
	# Test integration with building system
	var build_pos = Vector2(64, 64)
	targeting_system.set_target_position(build_pos)
	
	if building_system and building_system.has_method("set_target_from_targeting"):
		building_system.set_target_from_targeting(targeting_system)
		var build_target = building_system.get_current_target()
		assert_vector(build_target).is_equal(build_pos)

func test_targeting_cursor_tracking():
	var targeting_system = test_hierarchy.targeting_system
	
	# Test cursor position tracking
	var mock_cursor_pos = Vector2(128, 96)
	targeting_system.update_cursor_position(mock_cursor_pos)
	
	var tracked_pos = targeting_system.get_cursor_target()
	assert_vector(tracked_pos).is_equal(mock_cursor_pos)

func test_targeting_precision_modes():
	var targeting_system = test_hierarchy.targeting_system
	
	# Test different precision modes
	targeting_system.set_precision_mode(targeting_system.PrecisionMode.GRID_SNAP)
	var snap_pos = targeting_system.process_target_position(Vector2(50, 50))
	
	targeting_system.set_precision_mode(targeting_system.PrecisionMode.FREE_FORM)
	var free_pos = targeting_system.process_target_position(Vector2(50, 50))
	
	# Grid snap should be different from free-form
	assert_vector(snap_pos).is_not_equal(free_pos)
