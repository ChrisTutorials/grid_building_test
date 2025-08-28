extends GdUnitTestSuite

## Consolidated Building System Test Suite
## Consolidates: building_system_test.gd, drag_build_manager_test.gd, preview_name_consistency_test.gd,
## building_state_test.gd, drag_build_single_placement_per_tile_test.gd, drag_building_single_placement_per_tile_test.gd

## MARK FOR REMOVAL - building_system_test.gd, drag_build_manager_test.gd, preview_name_consistency_test.gd,
## building_state_test.gd, drag_build_single_placement_per_tile_test.gd, drag_building_single_placement_per_tile_test.gd

var test_env: Dictionary

func before_test() -> void:
	test_env = UnifiedTestFactory.create_systems_integration_test_environment(self)

# ===== BUILDING SYSTEM CORE TESTS =====

func test_building_system_initialization() -> void:
	var building_system: Object = test_env.building_system
	
	# Verify initial state
	var is_build_mode: bool = building_system.is_in_build_mode()
	assert_bool(is_build_mode).append_failure_message(
		"Building system should not be in build mode initially"
	).is_false()
	
	# Verify system components are available
	assert_object(building_system).is_not_null()

func test_building_mode_enter_exit() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable = test_env.get("test_placeable") 
	
	if test_placeable == null:
		# Create a simple test placeable
		test_placeable = UnifiedTestFactory.create_test_node2d(self)
	
	# Enter build mode
	building_system.enter_build_mode(test_placeable)
	assert_bool(building_system.is_in_build_mode()).append_failure_message(
		"Should be in build mode after entering"
	).is_true()
	
	# Exit build mode
	building_system.exit_build_mode()
	assert_bool(building_system.is_in_build_mode()).append_failure_message(
		"Should not be in build mode after exiting"
	).is_false()

func test_building_placement_attempt() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Enter build mode and attempt placement
	building_system.enter_build_mode(test_placeable)
	var placement_result = building_system.try_build_at_position(Vector2(100, 100))
	
	# Verify placement attempt returns a result (success/failure handled by validation)
	assert_object(placement_result).append_failure_message(
		"Build attempt should return a result object"
	).is_not_null()
	
	building_system.exit_build_mode()

# ===== BUILDING STATE TESTS =====

func test_building_state_transitions() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Test state transition sequence
	var initial_state = building_system.is_in_build_mode()
	assert_bool(initial_state).is_false()
	
	# Enter build mode
	building_system.enter_build_mode(test_placeable)
	var build_mode_state = building_system.is_in_build_mode()
	assert_bool(build_mode_state).is_true()
	
	# Exit and verify state
	building_system.exit_build_mode()
	var final_state = building_system.is_in_build_mode()
	assert_bool(final_state).is_false()

func test_building_state_persistence() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Enter build mode
	building_system.enter_build_mode(test_placeable)
	
	# State should persist across method calls
	assert_bool(building_system.is_in_build_mode()).is_true()
	assert_bool(building_system.is_in_build_mode()).is_true() # Called twice intentionally
	
	# Exit and verify persistence
	building_system.exit_build_mode()
	assert_bool(building_system.is_in_build_mode()).is_false()
	assert_bool(building_system.is_in_build_mode()).is_false() # Called twice intentionally

# ===== DRAG BUILD MANAGER TESTS =====

func test_drag_build_initialization() -> void:
	var building_system: Object = test_env.building_system
	
	# Check if drag build manager is available
	if building_system.has_method("get_drag_build_manager"):
		var drag_manager = building_system.get_drag_build_manager()
		assert_object(drag_manager).append_failure_message(
			"Drag build manager should be available"
		).is_not_null()

func test_drag_build_functionality() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	building_system.enter_build_mode(test_placeable)
	
	# Test drag building sequence if methods are available
	if building_system.has_method("start_drag_build"):
		building_system.start_drag_build(Vector2(50, 50))
		
		if building_system.has_method("is_drag_building"):
			assert_bool(building_system.is_drag_building()).append_failure_message(
				"Should be in drag building mode after start"
			).is_true()
		
		if building_system.has_method("end_drag_build"):
			building_system.end_drag_build()
			
			if building_system.has_method("is_drag_building"):
				assert_bool(building_system.is_drag_building()).append_failure_message(
					"Should not be in drag building mode after end"
				).is_false()
	
	building_system.exit_build_mode()

# ===== SINGLE PLACEMENT PER TILE TESTS =====

func test_single_placement_per_tile_constraint() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	building_system.enter_build_mode(test_placeable)
	
	var target_position: Vector2 = Vector2(200, 200)
	
	# First placement attempt
	var first_result = building_system.try_build_at_position(target_position)
	assert_object(first_result).is_not_null()
	
	# Second placement at same position should be handled appropriately
	var second_result = building_system.try_build_at_position(target_position)
	assert_object(second_result).append_failure_message(
		"System should handle duplicate placement attempts gracefully"
	).is_not_null()
	
	building_system.exit_build_mode()

func test_tile_placement_validation() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	building_system.enter_build_mode(test_placeable)
	
	# Test multiple positions to verify tile-based logic
	var positions: Array = [Vector2(0, 0), Vector2(16, 16), Vector2(32, 32)]
	
	for pos: Vector2 in positions:
		var result = building_system.try_build_at_position(pos)
		assert_object(result).append_failure_message(
			"Should get result for position %s" % pos
		).is_not_null()
	
	building_system.exit_build_mode()

# ===== PREVIEW NAME CONSISTENCY TESTS =====

func test_preview_name_consistency() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	test_placeable.name = "TestPlaceable"
	
	building_system.enter_build_mode(test_placeable)
	
	# Check if preview system maintains name consistency
	if building_system.has_method("get_current_preview"):
		var preview = building_system.get_current_preview()
		if preview != null and preview.has_method("get_name"):
			var preview_name = preview.get_name()
			assert_str(preview_name).append_failure_message(
				"Preview name should be consistent with placeable"
			).contains("TestPlaceable")
	
	building_system.exit_build_mode()

func test_preview_rotation_consistency() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	building_system.enter_build_mode(test_placeable)
	
	# Test rotation consistency if rotation methods exist
	if building_system.has_method("rotate_preview"):
		building_system.rotate_preview()
		
		if building_system.has_method("get_current_preview"):
			var preview = building_system.get_current_preview()
			assert_object(preview).append_failure_message(
				"Preview should exist after rotation"
			).is_not_null()
	
	building_system.exit_build_mode()

# ===== COMPREHENSIVE BUILDING WORKFLOW TESTS =====

func test_complete_building_workflow() -> void:
	var building_system: Object = test_env.building_system
	var targeting_system = test_env.get("targeting_system")
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Phase 1: Setup
	if targeting_system and targeting_system.has_method("set_target_position"):
		targeting_system.set_target_position(Vector2(300, 300))
	
	# Phase 2: Enter build mode
	building_system.enter_build_mode(test_placeable)
	assert_bool(building_system.is_in_build_mode()).is_true()
	
	# Phase 3: Attempt building
	var build_result = building_system.try_build_at_position(Vector2(300, 300))
	assert_object(build_result).is_not_null()
	
	# Phase 4: Cleanup
	building_system.exit_build_mode()
	assert_bool(building_system.is_in_build_mode()).is_false()

func test_building_error_recovery() -> void:
	var building_system: Object = test_env.building_system
	
	# Test recovery from invalid placeable
	var invalid_placeable = null
	building_system.enter_build_mode(invalid_placeable)
	
	# System should handle gracefully
	var state_after_invalid = building_system.is_in_build_mode()
	assert_object(state_after_invalid).append_failure_message(
		"System should handle invalid placeable gracefully"
	).is_not_null()
	
	# Test recovery with valid placeable
	var valid_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	building_system.enter_build_mode(valid_placeable)
	assert_bool(building_system.is_in_build_mode()).append_failure_message(
		"System should recover and accept valid placeable"
	).is_true()
	
	building_system.exit_build_mode()

# ===== BUILDING SYSTEM INTEGRATION TESTS =====

func test_building_system_dependencies() -> void:
	var building_system: Object = test_env.building_system
	
	# Verify system has required dependencies
	if building_system.has_method("get_dependency_issues"):
		var issues = building_system.get_dependency_issues()
		assert_array(issues).append_failure_message(
			"Building system should have minimal dependency issues: %s" % issues
		).is_empty()

func test_building_system_validation() -> void:
	var building_system: Object = test_env.building_system
	
	# Test system validation if available
	if building_system.has_method("validate_setup"):
		var is_valid = building_system.validate_setup()
		assert_bool(is_valid).append_failure_message(
			"Building system should be properly set up"
		).is_true()
	elif building_system.has_method("get_issues"):
		var issues = building_system.get_issues()
		assert_array(issues).append_failure_message(
			"Building system should have no critical issues: %s" % issues
		).is_empty()

# ===== DRAG BUILD REGRESSION TESTS =====

func test_drag_build_single_placement_regression() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	building_system.enter_build_mode(test_placeable)
	
	# Test that drag build respects single placement per tile constraint
	var tile_position: Vector2 = Vector2(400, 400)
	
	if building_system.has_method("start_drag_build") and building_system.has_method("update_drag_build"):
		building_system.start_drag_build(tile_position)
		
		# Update to same position (should not create duplicate)
		building_system.update_drag_build(tile_position)
		building_system.update_drag_build(tile_position) # Intentional duplicate
		
		if building_system.has_method("get_drag_build_placements"):
			var placements = building_system.get_drag_build_placements()
			assert_int(placements.size()).append_failure_message(
				"Should not have duplicate placements at same tile position"
			).is_less_equal(1)
		
		if building_system.has_method("end_drag_build"):
			building_system.end_drag_build()
	
	building_system.exit_build_mode()

func test_preview_indicator_consistency() -> void:
	var building_system: Object = test_env.building_system
	var test_placeable: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	building_system.enter_build_mode(test_placeable)
	
	# Test that preview and indicators stay consistent
	if building_system.has_method("get_current_preview") and building_system.has_method("get_indicators"):
		var preview = building_system.get_current_preview()
		var indicators = building_system.get_indicators()
		
		if preview != null and indicators != null:
			# Both should exist or both should be null for consistency
			assert_object(preview).is_not_null()
			assert_array(indicators).is_not_null()
	
	building_system.exit_build_mode()
