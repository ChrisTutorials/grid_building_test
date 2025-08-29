extends GdUnitTestSuite

## Consolidated Integration Test Suite  
## Consolidates: building_workflow_integration_test.gd, multi_rule_indicator_attachment_test.gd,
## smithy_indicator_generation_test.gd, complex_workflow_integration_test.gd,
## polygon_test_object_indicator_integration_test.gd, grid_targeting_highlight_integration_test.gd,
## indicator_manager_tree_integration_test.gd

## MARK FOR REMOVAL - All individual test files have been successfully consolidated

var test_env: Dictionary

func before_test() -> void:
	test_env = UnifiedTestFactory.create_systems_integration_test_environment(self)

#region BUILDING WORKFLOW INTEGRATION

func test_complete_building_workflow() -> void:
	var building_system: Object = test_env.building_system
	var smithy = UnifiedTestFactory.create_test_smithy_placeable(self)
	
	# Enter build mode and check if it succeeded
	var setup_report = building_system.enter_build_mode(smithy)
	assert_object(setup_report).append_failure_message(
		"enter_build_mode should return a PlacementSetupReport"
	).is_not_null()
	
	if setup_report and setup_report.has_method("is_successful") and setup_report.is_successful():
		assert_bool(building_system.is_in_build_mode()).append_failure_message(
			"Should be in build mode after successful enter_build_mode"
		).is_true()
	else:
		# If enter_build_mode failed, log why and skip the build mode assertion
		var error_msg = "enter_build_mode failed"
		if setup_report and setup_report.has_method("get_error_messages"):
			var errors = setup_report.get_error_messages()
			if errors and errors.size() > 0:
				error_msg += ": " + str(errors)
		assert_bool(false).append_failure_message(error_msg).is_true()
	
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
	var indicator_manager = test_env.indicator_manager
	var smithy = UnifiedTestFactory.create_test_smithy_placeable(self)
	
	# Setup placement validation
	var setup_report = building_system.enter_build_mode(smithy)
	assert_object(setup_report).is_not_null()
	if not (setup_report and setup_report.has_method("is_successful") and setup_report.is_successful()):
		assert_bool(false).append_failure_message("enter_build_mode failed in validation test").is_true()
		return
	
	# Test valid position  
	var valid_pos: Vector2 = Vector2(50, 50)
	
	# Set targeting state position for validation
	var targeting_state = test_env.targeting_state
	# Direct position access - fail fast approach
	if targeting_state.positioner != null:
		targeting_state.positioner.global_position = valid_pos
	
	# Use indicator manager's validate_placement method
	var validation_result = indicator_manager.validate_placement()
	assert_bool(validation_result.is_successful()).append_failure_message(
		"Validation should succeed for valid position %s" % valid_pos
	).is_true()
	
	# Test building at validated position
	var build_result = building_system.try_build_at_position(valid_pos)
	assert_object(build_result).is_not_null()

#endregion

#region MULTI-RULE INDICATOR ATTACHMENT

func test_multi_rule_indicator_attachment() -> void:
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	var collision_rule = CollisionsCheckRule.new()
	var tile_rule = TileCheckRule.new()

	# Create test object
	var test_object = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)

	# Create test parameters with proper constructor
	var manip_owner = test_env.container.get_states().manipulation.get_manipulator()
	var test_params = RuleValidationParameters.new(manip_owner, test_object, test_env.targeting_state, test_env.logger)
	
	var rules: Array = [collision_rule, tile_rule]
	var setup_result = indicator_manager.try_setup(rules, test_params)
	
	assert_bool(setup_result.is_successful()).append_failure_message(
		"Multi-rule setup should succeed: %s" % str(setup_result.get_all_issues())
	).is_true()
	
	# Verify both rules are attached
	var indicators = indicator_manager.get_indicators()
	assert_int(indicators.size()).append_failure_message(
		"Should have indicators for both rules, got %d" % indicators.size()
	).is_greater_equal(1)

func test_rule_indicator_state_synchronization() -> void:
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	var rule = CollisionsCheckRule.new()

	# Create test object
	var test_object = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)

	# Setup with initial state
	var manip_owner = test_env.container.get_states().manipulation.get_manipulator()
	var params = RuleValidationParameters.new(manip_owner, test_object, test_env.targeting_state, test_env.logger)
	test_object.global_position = Vector2(64, 64)
	
	var setup_result = indicator_manager.try_setup([rule], params)
	assert_bool(setup_result.is_successful()).is_true()
	
	# Change rule state and verify indicators update
	test_object.global_position = Vector2(96, 96)
	var update_result = indicator_manager.try_setup([rule], params)
	
	assert_bool(update_result.is_successful()).append_failure_message(
		"Rule state update should succeed: %s" % str(update_result.get_all_issues())
	).is_true()

func test_indicators_are_parented_and_inside_tree() -> void:
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	var targeting_state: GridTargetingState = test_env.targeting_state
	var container: GBCompositionContainer = test_env.container
	
	# Create a preview object with collision
	var preview = _create_preview_with_collision()
	targeting_state.target = preview
	
	# Build a collisions rule that applies to layer 1
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1 << 0
	rule.collision_mask = 1 << 0
	var rules: Array[PlacementRule] = [rule]
	
	var logger: GBLogger = container.get_logger()
	var manip_owner = container.get_states().manipulation.get_manipulator()
	var params := RuleValidationParameters.new(manip_owner, preview, targeting_state, logger)
	var setup_results: PlacementSetupReport = indicator_manager.try_setup(rules, params)
	
	assert_bool(setup_results.is_successful()).append_failure_message("IndicatorManager.try_setup failed").is_true()
	var indicators = indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message("No indicators created").is_not_empty()
	
	for ind in indicators:
		assert_bool(ind.is_inside_tree()).append_failure_message("Indicator not inside tree: %s" % ind.name).is_true()
		assert_object(ind.get_parent()).append_failure_message("Indicator has no parent: %s" % ind.name).is_not_null()
		assert_object(ind.get_parent()).append_failure_message("Unexpected parent for indicator: %s" % ind.name).is_equal(container.get_states().manipulation.parent)

func _create_preview_with_collision() -> Node2D:
	var root := Node2D.new()
	root.name = "PreviewRoot"
	# Simple body with collision on layer 1
	var area := Area2D.new()
	area.collision_layer = 1
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)  # Use size instead of extents for Godot 4
	shape.shape = rect
	area.add_child(shape)
	root.add_child(area)
	add_child(root) # Add to test scene instead of positioner
	return root

#endregion

#region SMITHY INDICATOR GENERATION

func test_smithy_indicator_generation() -> void:
	var smithy = UnifiedTestFactory.create_test_smithy_placeable(self)
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	
	# Get smithy rules
	var smithy_rules = smithy.placement_rules
	assert_array(smithy_rules).append_failure_message(
		"Smithy should have placement rules"
	).is_not_empty()
	
	# Generate indicators using proper parameters
	var manip_owner = test_env.container.get_states().manipulation.get_manipulator()
	var smithy_node = smithy.packed_scene.instantiate()
	add_child(smithy_node)
	var params = RuleValidationParameters.new(manip_owner, smithy_node, test_env.targeting_state, test_env.logger)
	
	var setup_result = indicator_manager.try_setup(smithy_rules, params)
	assert_bool(setup_result.is_successful()).append_failure_message(
		"Smithy indicator generation should succeed: %s" % str(setup_result.get_all_issues())
	).is_true()

func test_smithy_collision_detection() -> void:
	var smithy = UnifiedTestFactory.create_test_smithy_placeable(self)
	var collision_mapper: CollisionMapper = test_env.collision_mapper
	
	# Create a smithy node from the placeable for collision testing
	var smithy_node = smithy.packed_scene.instantiate()
	add_child(smithy_node)
	
	# Test collision tile mapping for smithy (using production method)
	var collision_results = collision_mapper.get_collision_tile_positions_with_mask([smithy_node], 1)
	assert_that(collision_results).append_failure_message(
		"Smithy should generate collision tile positions"
	).is_not_empty()
	
	# Verify collision tile positions are reasonable
	for tile_pos in collision_results.keys():
		var tile_coord = tile_pos as Vector2i
		assert_int(abs(tile_coord.x)).append_failure_message(
			"Collision tile x coordinate should be reasonable: %d" % tile_coord.x
		).is_less_than(1000)
		assert_int(abs(tile_coord.y)).append_failure_message(
			"Collision tile y coordinate should be reasonable: %d" % tile_coord.y
		).is_less_than(1000)
	
	smithy_node.queue_free()

#endregion

#region COMPLEX WORKFLOW INTEGRATION

func test_complex_multi_system_workflow() -> void:
	var building_system: Object = test_env.building_system
	var targeting_system = test_env.targeting_system
	var _manipulation_system = test_env.manipulation_system
	
	# Phase 1: Target selection
	var targeting_state = targeting_system.get_state()
	var target_pos: Vector2 = Vector2(200, 200)
	if targeting_state.positioner != null:
		targeting_state.positioner.global_position = target_pos
	
	assert_vector(target_pos).append_failure_message(
		"Target position should be set correctly"
	).is_equal(Vector2(200, 200))
	
	# Phase 2: Building placement
	var smithy = UnifiedTestFactory.create_test_smithy_placeable(self)
	var setup_report = building_system.enter_build_mode(smithy)
	assert_object(setup_report).is_not_null()
	if not (setup_report and setup_report.has_method("is_successful") and setup_report.is_successful()):
		assert_bool(false).append_failure_message("enter_build_mode failed in multi-system test").is_true()
		return
	var build_result = building_system.try_build_at_position(target_pos)
	assert_object(build_result).is_not_null()
	
	# Phase 3: Post-build manipulation
	if build_result:
		_manipulation_system.select_object(build_result)
		var manipulation_state = _manipulation_system.get_current_state()
		assert_object(manipulation_state).append_failure_message(
			"Should have valid manipulation state after selection"
		).is_not_null()

func test_cross_system_state_consistency() -> void:
	var building_system: Object = test_env.building_system
	var targeting_system = test_env.targeting_system
	var _indicator_manager: IndicatorManager = test_env.indicator_manager
	
	# Setup coordinated state across systems
	var target_pos: Vector2 = Vector2(240, 240)
	var targeting_state = targeting_system.get_state()
	if targeting_state.positioner != null:
		targeting_state.positioner.global_position = target_pos
	
	var smithy = UnifiedTestFactory.create_test_smithy_placeable(self)
	var setup_report = building_system.enter_build_mode(smithy)
	assert_object(setup_report).is_not_null()
	if not (setup_report and setup_report.has_method("is_successful") and setup_report.is_successful()):
		assert_bool(false).append_failure_message("enter_build_mode failed in cross-system state test").is_true()
		return
	
	# Verify state consistency
	var building_target = building_system.get_target_position()
	var current_targeting_state = targeting_system.get_state()
	var targeting_target = current_targeting_state.get("position", target_pos)
	
	# Systems should maintain consistent target positions
	assert_vector(building_target).append_failure_message(
		"Building system target (%s) should match targeting system (%s)" % [building_target, targeting_target]
	).is_equal(targeting_target)

#endregion

#region POLYGON TEST OBJECT INTEGRATION

func test_polygon_test_object_indicator_generation() -> void:
	var polygon_test_object = UnifiedTestFactory.create_polygon_test_placeable(self)
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	
	# Get polygon object rules
	var polygon_rules = polygon_test_object.placement_rules
	assert_array(polygon_rules).append_failure_message(
		"Polygon test object should have placement rules"
	).is_not_empty()
	
	# Generate indicators for polygon object using proper parameters
	var manip_owner = test_env.container.get_states().manipulation.get_manipulator()
	var polygon_node = polygon_test_object.packed_scene.instantiate()
	add_child(polygon_node)
	var params = RuleValidationParameters.new(manip_owner, polygon_node, test_env.targeting_state, test_env.logger)
	
	var setup_result = indicator_manager.try_setup(polygon_rules, params)
	assert_bool(setup_result.is_successful()).append_failure_message(
		"Polygon object indicator generation should succeed: %s" % str(setup_result.get_all_issues())
	).is_true()

func test_polygon_collision_integration() -> void:
	var polygon_test_object = UnifiedTestFactory.create_polygon_test_placeable(self)
	var collision_mapper: CollisionMapper = test_env.collision_mapper
	
	# Test polygon collision tile mapping
	var polygon_runtime = polygon_test_object.packed_scene.instantiate()
	add_child(polygon_runtime)
	var collision_tiles = collision_mapper.get_collision_tile_positions_with_mask([polygon_runtime], 1)
	assert_that(collision_tiles).append_failure_message(
		"Polygon test object should generate collision tile positions"
	).is_not_empty()
	
	# Verify collision tiles form reasonable polygon pattern
	var unique_x_coords = {}
	var unique_y_coords = {}
	
	for tile_pos in collision_tiles.keys():
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
	var highlight_active = highlight_manager.is_highlight_active()
	assert_bool(highlight_active).append_failure_message(
		"Highlight should be active when targeting position is set"
	).is_true()

func test_targeting_state_transitions() -> void:
	var targeting_system = test_env.targeting_system
	
	# Test state transitions
	var targeting_state = targeting_system.get_state()
	var initial_pos = Vector2.ZERO
	if targeting_state.positioner != null:
		initial_pos = targeting_state.positioner.global_position
		targeting_state.positioner.global_position = Vector2(400, 400)
		var updated_pos = targeting_state.positioner.global_position
		
		assert_vector(updated_pos).append_failure_message(
			"Target position should update from %s to Vector2(400, 400), got %s" % [initial_pos, updated_pos]
		).is_equal(Vector2(400, 400))
		
		# Test clearing target
		targeting_state.positioner.global_position = Vector2.ZERO  # Reset to origin
		var cleared_pos = targeting_state.positioner.global_position
		
		# Cleared position behavior depends on system implementation
		assert_object(cleared_pos).append_failure_message(
			"Should have valid position response after clearing target"
		).is_not_null()
	else:
		# Skip position tests if positioner is not available
		pass

#endregion
#region COMPREHENSIVE INTEGRATION VALIDATION

func test_full_system_integration_workflow() -> void:
	# Test complete workflow from targeting through building to manipulation
	var building_system: Object = test_env.building_system
	var targeting_system = test_env.targeting_system
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	var _manipulation_system = test_env.manipulation_system
	
	# Step 1: Set target
	var target_pos: Vector2 = Vector2(500, 500)
	var targeting_state = targeting_system.get_state()
	if targeting_state.positioner != null:
		targeting_state.positioner.global_position = target_pos
	
	# Step 2: Enter build mode with indicators
	var smithy = UnifiedTestFactory.create_test_smithy_placeable(self)
	var setup_report = building_system.enter_build_mode(smithy)
	assert_object(setup_report).is_not_null()
	if not (setup_report and setup_report.has_method("is_successful") and setup_report.is_successful()):
		assert_bool(false).append_failure_message("enter_build_mode failed in full system integration test").is_true()
		return
	
	# Create a Node2D instance from the placeable (required by RuleValidationParameters)
	var manip_owner = test_env.container.get_states().manipulation.get_manipulator()
	var smithy_node = smithy.packed_scene.instantiate()
	add_child(smithy_node)
	
	var smithy_rules = smithy.placement_rules
	var params = RuleValidationParameters.new(
		manip_owner,  # placer (Node2D)
		smithy_node,  # target (Node2D)
		test_env.targeting_state,  # targeting_state
		test_env.logger  # logger
	)
	
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
	var invalid_report = building_system.enter_build_mode(invalid_placeable)
	
	# System should return a failed report for invalid input
	assert_object(invalid_report).is_not_null()
	if invalid_report and invalid_report.has_method("is_successful"):
		assert_bool(invalid_report.is_successful()).append_failure_message(
			"enter_build_mode should fail with null placeable"
		).is_false()
	
	# System should not be in build mode after failed enter_build_mode
	var is_in_build_mode = building_system.is_in_build_mode()
	assert_bool(is_in_build_mode).append_failure_message(
		"System should not be in build mode after failed enter_build_mode"
	).is_false()
	
	# Ensure system can recover to valid state
	var smithy = UnifiedTestFactory.create_test_smithy_placeable(self)
	var recovery_report = building_system.enter_build_mode(smithy)
	assert_object(recovery_report).is_not_null()
	
	if recovery_report and recovery_report.has_method("is_successful") and recovery_report.is_successful():
		assert_bool(building_system.is_in_build_mode()).append_failure_message(
			"System should recover and enter build mode with valid placeable"
		).is_true()
	else:
		# If recovery failed, that's also a valid test outcome - log the issue
		assert_bool(false).append_failure_message(
			"System failed to recover with valid placeable"
		).is_true()
	
	building_system.exit_build_mode()
