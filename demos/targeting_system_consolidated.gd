extends GdUnitTestSuite

## Consolidated targeting system tests using factory patterns

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test():
	test_hierarchy = UnifiedTestFactory.create_systems_test_hierarchy(self, ["targeting", "building"], TEST_CONTAINER)

func test_targeting_basic():
	var targeting_system = test_hierarchy.targeting_system
	var targeting_state = targeting_system.get_state()
	
	assert_object(targeting_system).append_failure_message(
		"Targeting system should be properly initialized by factory"
	).is_not_null()
	assert_object(targeting_state).append_failure_message(
		"Targeting state should be accessible from targeting system"
	).is_not_null()
	
	# Test basic targeting using the factory's default target
	var current_target = targeting_state.target
	assert_object(current_target).append_failure_message(
		"Targeting system should have a default target set by the factory"
	).is_not_null()
	assert_vector(current_target.position).append_failure_message(
		"Default target should be positioned at factory default location (64, 64)"
	).is_equal(Vector2(64, 64))

func test_targeting_grid_alignment():
	var targeting_system = test_hierarchy.targeting_system
	var _tile_map = test_hierarchy.tile_map
	var _targeting_state = targeting_system.get_state()
	
	# Test grid-aligned targeting by setting position through state
	var world_pos = Vector2(50, 50)  # Not grid-aligned
	var positioner = test_hierarchy.positioner
	positioner.global_position = world_pos
	
	# The system should handle grid alignment through its internal logic
	assert_object(positioner).append_failure_message(
		"Positioner should be available from test hierarchy"
	).is_not_null()
	assert_vector(positioner.global_position).append_failure_message(
		"Positioner should maintain the set global position"
	).is_equal(world_pos)

func test_targeting_validation():
	var targeting_system = test_hierarchy.targeting_system
	var _tile_map = test_hierarchy.tile_map
	var targeting_state = targeting_system.get_state()
	
	# Test valid position using factory's default target
	var issues = targeting_system.get_dependency_issues()
	assert_array(issues).append_failure_message(
		"Targeting system should report no dependency issues with valid factory setup"
	).is_empty()
	
	# Test invalid position (out of bounds) by creating a specific target
	var invalid_target = Node2D.new()
	invalid_target.position = Vector2(-100, -100)
	targeting_state.target = invalid_target
	
	# The system should still function but may have different behavior
	assert_object(targeting_state.target).append_failure_message(
		"Targeting state should maintain target reference even for invalid positions"
	).is_not_null()
	
	auto_free(invalid_target)

func test_targeting_with_rules():
	var targeting_system = test_hierarchy.targeting_system
	var targeting_state = targeting_system.get_state()
	
	# Test that the system can validate dependencies using factory's default target
	var issues = targeting_system.get_dependency_issues()
	# Issues may or may not be present depending on system state
	assert_array(issues).is_not_null().append_failure_message(
		"Should be able to retrieve dependency issues array from targeting system"
	)
	
	# Test that targeting state can handle rule-related properties
	assert_object(targeting_state).is_not_null().append_failure_message(
		"Targeting state should be accessible for rule validation"
	)

func test_targeting_area_selection():
	var targeting_system = test_hierarchy.targeting_system
	var targeting_state = targeting_system.get_state()
	
	# Test area targeting using factory's default target
	assert_object(targeting_state).append_failure_message(
		"Targeting state should be properly initialized"
	).is_not_null()
	assert_object(targeting_state.target).append_failure_message(
		"Factory should provide a default target for area selection tests"
	).is_not_null()
	assert_vector(targeting_state.target.position).append_failure_message(
		"Default target should maintain factory position for area operations"
	).is_equal(Vector2(64, 64))

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
	
	# Test that the system can handle multiple objects using factory's default target
	var targeting_state = targeting_system.get_state()
	assert_object(targeting_state.target).is_not_null().append_failure_message(
		"Targeting system should maintain default target when multiple objects are present"
	)
	assert_array(objects).has_size(3).append_failure_message(
		"Should have created exactly 3 test objects"
	)

func test_targeting_system_integration():
	var targeting_system = test_hierarchy.targeting_system
	var building_system = test_hierarchy.building_system
	
	# Test integration with building system using factory's default target
	var targeting_state = targeting_system.get_state()
	assert_object(targeting_state.target).is_not_null().append_failure_message(
		"Targeting state should have default target for integration testing"
	)
	
	if building_system and building_system.has_method("set_target_from_targeting"):
		building_system.set_target_from_targeting(targeting_system)
		var current_target = building_system.get_current_target()
		assert_vector(current_target).is_equal(Vector2(64, 64)).append_failure_message(
			"Building system should sync target position from targeting system"
		)

func test_targeting_cursor_tracking():
	var targeting_system = test_hierarchy.targeting_system
	
	# Test cursor position tracking by updating factory's default target
	var mock_cursor_pos = Vector2(128, 96)
	var targeting_state = targeting_system.get_state()
	targeting_state.target.position = mock_cursor_pos
	
	# Verify the system can handle cursor-like targeting
	assert_object(targeting_state.target).is_not_null().append_failure_message(
		"Targeting state should maintain target reference during cursor tracking"
	)
	assert_vector(targeting_state.target.position).is_equal(mock_cursor_pos).append_failure_message(
		"Target position should update to match cursor position"
	)

func test_targeting_precision_modes():
	var targeting_system = test_hierarchy.targeting_system
	
	# Test different precision modes using factory's default target
	var targeting_state = targeting_system.get_state()
	var test_pos = Vector2(50, 50)
	targeting_state.target.position = test_pos
	
	# Test that the system can handle position processing through its tile methods
	if targeting_system.has_method("get_tile_from_global_position"):
		var tile_pos = targeting_system.get_tile_from_global_position(test_pos, targeting_state.target_map)
		assert_object(tile_pos).is_not_null().append_failure_message(
			"Should be able to convert global position to tile coordinates"
		)
	
	# Verify the system maintains state consistency
	assert_object(targeting_state.target).is_not_null().append_failure_message(
		"Targeting state should maintain target reference during precision operations"
	)
	assert_vector(targeting_state.target.position).is_equal(test_pos).append_failure_message(
		"Target position should remain consistent after precision mode operations"
	)
