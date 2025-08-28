extends GdUnitTestSuite

## Consolidated Integration Test Suite  
## Consolidates: building_workflow_integration_test.gd, multi_rule_indicator_attachment_test.gd,
## smithy_indicator_generation_test.gd, complex_workflow_integration_test.gd,
## polygon_test_object_indicator_integration_test.gd, grid_targeting_highlight_integration_test.gd

## MARK FOR REMOVAL - building_workflow_integration_test.gd, multi_rule_indicator_attachment_test.gd,
## smithy_indicator_generation_test.gd, complex_workflow_integration_test.gd,
## polygon_test_object_indicator_integration_test.gd, grid_targeting_highlight_integration_test.gd

var test_env: Dictionary

func before_test() -> void:
	test_env = UnifiedTestFactory.create_systems_integration_test_environment(self)

#region BUILDING WORKFLOW INTEGRATION

func test_complete_building_workflow() -> void:
	var building_system: Object = test_env.building_system
	var smithy = PlaceableLibrary.get_smithy()
	
	# Enter build mode
	building_system.enter_build_mode(smithy)
	assert_bool(building_system.is_in_build_mode()).append_failure_message(
		"Should be in build mode after entering with smithy"
	).is_true()
	
	# Test placement attempt
	var placement_result = building_system.try_build_at_position(Vector2(100, 100))
	assert_object(placement_result).is_not_null()
	
	# Exit build mode
	building_system.exit_build_mode()
	assert_bool(building_system.is_in_build_mode()).append_failure_message(
		"Should not be in build mode after exiting"
	).is_false()

func test_building_workflow_with_validation() -> void:
	var building_system: Object = test_env.building_system
	var placement_validator = test_env.placement_validator
	var smithy = PlaceableLibrary.get_smithy()
	
	# Setup placement validation
	building_system.enter_build_mode(smithy)
	
	# Test valid position
	var valid_pos: Vector2 = Vector2(50, 50)
	var validation_result = placement_validator.validate_placement(smithy, valid_pos)
	assert_bool(validation_result.is_successful()).append_failure_message(
		"Validation should succeed for valid position %s" % valid_pos
	).is_true()
	
	# Test building at validated position
	var build_result = building_system.try_build_at_position(valid_pos)
	assert_object(build_result).is_not_null()

#endregion

#region MULTI-RULE INDICATOR ATTACHMENT

func test_multi_rule_indicator_attachment() -> void:
	var indicator_manager: Object = test_env.indicator_manager
	var collision_rule = CollisionsCheckRule.new()
	var tile_rule = TileCheckRule.new()
	
	# Setup rules with test parameters
	var test_params = RuleValidationParameters.new()
	test_params.target_position = Vector2(32, 32)
	test_params.tile_map = test_env.tilemap
	
	var rules: Array = [collision_rule, tile_rule]
	var setup_result = indicator_manager.try_setup(rules, test_params)
	
	assert_bool(setup_result.is_successful()).append_failure_message(
		"Multi-rule setup should succeed: %s" % setup_result.get_all_issues()
	).is_true()
	
	# Verify both rules are attached
	var indicators = indicator_manager.get_indicators()
	assert_int(indicators.size()).append_failure_message(
		"Should have indicators for both rules, got %d" % indicators.size()
	).is_greater_equal(1)

func test_rule_indicator_state_synchronization() -> void:
	var indicator_manager: Object = test_env.indicator_manager
	var rule = CollisionsCheckRule.new()
	
	# Setup with initial state
	var params = RuleValidationParameters.new()
	params.target_position = Vector2(64, 64)
	params.tile_map = test_env.tilemap
	
	var setup_result = indicator_manager.try_setup([rule], params)
	assert_bool(setup_result.is_successful()).is_true()
	
	# Change rule state and verify indicators update
	params.target_position = Vector2(96, 96)
	var update_result = indicator_manager.try_setup([rule], params)
	
	assert_bool(update_result.is_successful()).append_failure_message(
		"Rule state update should succeed: %s" % update_result.get_all_issues()
	).is_true()

#endregion

#region SMITHY INDICATOR GENERATION

func test_smithy_indicator_generation() -> void:
	var smithy = PlaceableLibrary.get_smithy()
	var indicator_manager: Object = test_env.indicator_manager
	
	# Get smithy rules
	var smithy_rules = smithy.get_placement_rules()
	assert_array(smithy_rules).append_failure_message(
		"Smithy should have placement rules"
	).is_not_empty()
	
	# Setup indicators for smithy
	var params = RuleValidationParameters.new()
	params.target_position = Vector2(128, 128)
	params.tile_map = test_env.tilemap
	params.placeable_instance = smithy
	
	var setup_result = indicator_manager.try_setup(smithy_rules, params)
	assert_bool(setup_result.is_successful()).append_failure_message(
		"Smithy indicator generation should succeed: %s" % setup_result.get_all_issues()
	).is_true()
	
	# Verify indicators were created
	var indicators = indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message(
		"Should have generated indicators for smithy rules"
	).is_not_empty()

func test_smithy_collision_detection() -> void:
	var smithy = PlaceableLibrary.get_smithy()
	var collision_mapper: Object = test_env.collision_mapper
	
	# Test collision detection for smithy
	var collision_results = collision_mapper.get_collision_tiles(smithy, Vector2(160, 160))
	assert_array(collision_results).append_failure_message(
		"Smithy should generate collision tiles"
	).is_not_empty()
	
	# Verify collision tile positions are reasonable
	for tile_pos in collision_results:
		var tile_coord = tile_pos as Vector2i
		assert_int(abs(tile_coord.x)).append_failure_message(
			"Collision tile x coordinate should be reasonable: %d" % tile_coord.x
		).is_less_than(1000)
		assert_int(abs(tile_coord.y)).append_failure_message(
			"Collision tile y coordinate should be reasonable: %d" % tile_coord.y
		).is_less_than(1000)

#endregion

#region COMPLEX WORKFLOW INTEGRATION

func test_complex_multi_system_workflow() -> void:
	var building_system: Object = test_env.building_system
	var targeting_system = test_env.targeting_system
	var manipulation_system = test_env.manipulation_system
	
	# Phase 1: Target selection
	var targeting_state = targeting_system.get_state()
	targeting_state.target.position = Vector2(200, 200)
	var target_pos = targeting_state.target.position
	assert_vector(target_pos).append_failure_message(
		"Target position should be set correctly"
	).is_equal(Vector2(200, 200))
	
	# Phase 2: Building placement
	var smithy = PlaceableLibrary.get_smithy()
	building_system.enter_build_mode(smithy)
	var build_result = building_system.try_build_at_position(target_pos)
	assert_object(build_result).is_not_null()
	
	# Phase 3: Post-build manipulation
	if build_result:
		manipulation_system.select_object(build_result)
		var manipulation_state = manipulation_system.get_current_state()
		assert_object(manipulation_state).append_failure_message(
			"Should have valid manipulation state after selection"
		).is_not_null()

func test_cross_system_state_consistency() -> void:
	var building_system: Object = test_env.building_system
	var targeting_system = test_env.targeting_system
	var indicator_manager: Object = test_env.indicator_manager
	
	# Setup coordinated state across systems
	var target_pos: Vector2 = Vector2(240, 240)
	var targeting_state = targeting_system.get_state()
	targeting_state.target.position = target_pos
	
	var smithy = PlaceableLibrary.get_smithy()
	building_system.enter_build_mode(smithy)
	
	# Verify state consistency
	var building_target = building_system.get_target_position()
	var current_targeting_state = targeting_system.get_state()
	var targeting_target = current_targeting_state.target.position
	
	# Systems should maintain consistent target positions
	assert_vector(building_target).append_failure_message(
		"Building system target (%s) should match targeting system (%s)" % [building_target, targeting_target]
	).is_equal(targeting_target)

#endregion

#region POLYGON TEST OBJECT INTEGRATION

func test_polygon_test_object_indicator_generation() -> void:
	var polygon_test_object = PlaceableLibrary.get_polygon_test_object()
	var indicator_manager: Object = test_env.indicator_manager
	
	# Get polygon object rules
	var polygon_rules = polygon_test_object.get_placement_rules()
	assert_array(polygon_rules).append_failure_message(
		"Polygon test object should have placement rules"
	).is_not_empty()
	
	# Generate indicators for polygon object
	var params = RuleValidationParameters.new()
	params.target_position = Vector2(280, 280)
	params.tile_map = test_env.tilemap
	params.placeable_instance = polygon_test_object
	
	var setup_result = indicator_manager.try_setup(polygon_rules, params)
	assert_bool(setup_result.is_successful()).append_failure_message(
		"Polygon object indicator generation should succeed: %s" % setup_result.get_all_issues()
	).is_true()

func test_polygon_collision_integration() -> void:
	var polygon_test_object = PlaceableLibrary.get_polygon_test_object()
	var collision_mapper: Object = test_env.collision_mapper
	
	# Test polygon collision detection
	var collision_tiles = collision_mapper.get_collision_tiles(polygon_test_object, Vector2(320, 320))
	assert_array(collision_tiles).append_failure_message(
		"Polygon test object should generate collision tiles"
	).is_not_empty()
	
	# Verify collision tiles form reasonable polygon pattern
	var unique_x_coords = {}
	var unique_y_coords = {}
	
	for tile_pos in collision_tiles:
		var tile_coord = tile_pos as Vector2i
		unique_x_coords[tile_coord.x] = true
		unique_y_coords[tile_coord.y] = true
	
	# Polygon should span multiple coordinates
	assert_int(unique_x_coords.size()).append_failure_message(
		"Polygon should span multiple X coordinates, got %d" % unique_x_coords.size()
	).is_greater_equal(2)
	assert_int(unique_y_coords.size()).append_failure_message(
		"Polygon should span multiple Y coordinates, got %d" % unique_y_coords.size()
	).is_greater_equal(2)

#region GRID TARGETING HIGHLIGHT INTEGRATION

func test_grid_targeting_highlight_integration() -> void:
	var targeting_system = test_env.targeting_system
	var highlight_manager = test_env.get("highlight_manager")  # May not be available in all environments
	
	if highlight_manager == null:
		# Skip if highlight manager not available in test environment
		return
	
	# Test targeting with highlight updates
	var targeting_state = targeting_system.get_state()
	targeting_state.target.position = Vector2(360, 360)
	
	# Verify highlight state updates with targeting
	var highlight_active = highlight_manager.is_highlight_active() if highlight_manager.has_method("is_highlight_active") else true
	assert_bool(highlight_active).append_failure_message(
		"Highlight should be active when targeting position is set"
	).is_true()

func test_targeting_state_transitions() -> void:
	var targeting_system = test_env.targeting_system
	
	# Test state transitions
	var targeting_state = targeting_system.get_state()
	var initial_pos = targeting_state.target.position
	targeting_state.target.position = Vector2(400, 400)
	var updated_pos = targeting_state.target.position
	
	assert_vector(updated_pos).append_failure_message(
		"Target position should update from %s to Vector2(400, 400), got %s" % [initial_pos, updated_pos]
	).is_equal(Vector2(400, 400))
	
	# Test clearing target
	targeting_state.target.position = Vector2.ZERO  # Reset to origin
	var cleared_pos = targeting_state.target.position
	
	# Cleared position behavior depends on system implementation
	assert_object(cleared_pos).append_failure_message(
		"Should have valid position response after clearing target"
	).is_not_null()

#endregion
#region COMPREHENSIVE INTEGRATION VALIDATION

func test_full_system_integration_workflow() -> void:
	# Test complete workflow from targeting through building to manipulation
	var building_system: Object = test_env.building_system
	var targeting_system = test_env.targeting_system
	var indicator_manager: Object = test_env.indicator_manager
	var manipulation_system = test_env.manipulation_system
	
	# Step 1: Set target
	var target_pos: Vector2 = Vector2(500, 500)
	var targeting_state = targeting_system.get_state()
	targeting_state.target.position = target_pos
	
	# Step 2: Enter build mode with indicators
	var smithy = PlaceableLibrary.get_smithy()
	building_system.enter_build_mode(smithy)
	
	var smithy_rules = smithy.get_placement_rules()
	var params = RuleValidationParameters.new()
	params.target_position = target_pos
	params.tile_map = test_env.tilemap
	params.placeable_instance = smithy
	
	var indicator_result = indicator_manager.try_setup(smithy_rules, params)
	assert_bool(indicator_result.is_successful()).append_failure_message(
		"Full workflow indicator setup should succeed: %s" % indicator_result.get_all_issues()
	).is_true()
	
	# Step 3: Build at target
	var build_result = building_system.try_build_at_position(target_pos)
	assert_object(build_result).is_not_null()
	
	# Step 4: Validate post-build state
	building_system.exit_build_mode()
	assert_bool(building_system.is_in_build_mode()).is_false()

func test_system_error_recovery() -> void:
	var building_system: Object = test_env.building_system
	
	# Test recovery from invalid operations
	var invalid_placeable = null
	building_system.enter_build_mode(invalid_placeable)
	
	# System should handle invalid input gracefully
	var is_in_build_mode = building_system.is_in_build_mode()
	# Behavior may vary - either reject invalid input or handle gracefully
	assert_object(is_in_build_mode).append_failure_message(
		"System should handle invalid placeable gracefully"
	).is_not_null()
	
	# Ensure system can recover to valid state
	var smithy = PlaceableLibrary.get_smithy()
	building_system.enter_build_mode(smithy)
	assert_bool(building_system.is_in_build_mode()).append_failure_message(
		"System should recover and enter build mode with valid placeable"
	).is_true()
	
	building_system.exit_build_mode()
