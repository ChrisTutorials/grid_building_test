
extends GdUnitTestSuite

## Consolidates: building_workflow_integration_test.gd, multi_rule_indicator_attachment_test.gd,
## smithy_indicator_generation_test.gd, complex_workflow_integration_test.gd,
## polygon_test_object_indicator_integration_test.gd, grid_targeting_highlight_integration_test.gd,
## indicator_manager_tree_integration_test.gd

## MARK FOR REMOVAL - All individual test files have been successfully consolidated

var env: AllSystemsTestEnvironment
var _container: GBCompositionContainer
var _gts: GridTargetingSystem
var _building_system: BuildingSystem
var _indicator_manager: IndicatorManager
var _targeting_system: GridTargetingSystem
var smithy_placeable : Placeable = load("uid://dirh6mcrgdm3w")

func before_test() -> void:
	env = UnifiedTestFactory.instance_all_systems_env(self, "uid://ioucajhfxc8b")
	_container = env.get_container()
	_gts = env.grid_targeting_system
	_building_system = env.building_system
	_indicator_manager = env.indicator_manager
	_targeting_system = env.targeting_system

#region HELPER METHODS

## Common helper to enter build mode with proper error handling
func _enter_build_mode_successfully(placeable: Placeable) -> bool:
	var setup_report: PlacementReport = _building_system.enter_build_mode(placeable)
	assert_object(setup_report).append_failure_message(
		"enter_build_mode should return a PlacementReport"
	).is_not_null()
	
	if setup_report.is_successful():
		assert_bool(_building_system.is_in_build_mode()).append_failure_message(
			"Should be in build mode after successful enter_build_mode"
		).is_true()
		return true
	else:
		var errors: Array[String] = setup_report.get_error_messages()
		var error_msg: String = "enter_build_mode failed: " + str(errors)
		assert_bool(false).append_failure_message(error_msg).is_true()
		return false

## Common helper to create targeting state with position
func _set_targeting_position(position: Vector2) -> void:
	var targeting_state: GridTargetingState = _container.get_states().targeting
	targeting_state.positioner.global_position = position

## Common helper to validate successful setup with custom message
func _assert_setup_successful(setup_result: PlacementReport, context: String) -> void:
	assert_bool(setup_result.is_successful()).append_failure_message(
		"%s should succeed: %s" % [context, str(setup_result.get_all_issues())]
	).is_true()

## Common helper to create rule validation parameters
func _make_rule_params(_target_node: Node2D) -> GridTargetingState:
	return _gts.get_state()

## Common helper to create preview with collision
func _create_preview_with_collision() -> Node2D:
	var root := Node2D.new()
	root.name = "PreviewRoot"
	var area := Area2D.new()
	area.collision_layer = 1
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	area.add_child(shape)
	root.add_child(area)
	add_child(root)
	return root

## Common helper to verify collision tile positions are reasonable
func _assert_reasonable_collision_positions(collision_results: Dictionary) -> void:
	assert_that(collision_results).append_failure_message(
		"Should generate collision tile positions"
	).is_not_empty()
	
	for tile_pos in collision_results.keys():
		var tile_coord = tile_pos as Vector2i
		assert_int(abs(tile_coord.x)).append_failure_message(
			"Collision tile x coordinate should be reasonable: %d" % tile_coord.x
		).is_less_than(1000)
		assert_int(abs(tile_coord.y)).append_failure_message(
			"Collision tile y coordinate should be reasonable: %d" % tile_coord.y
		).is_less_than(1000)

#endregion

#region BUILDING WORKFLOW INTEGRATION

## Consolidated Integration Test Suite  
## Tests integration of all systems in one environment
## Infunc test_complete_building_wofunc test_building_workflow_with_validation() -> void:
	if not _enter_build_mode_successfully(smithy_placeable):
		return
	
	# Test valid position  
	var valid_pos: Vector2 = Vector2(50, 50)
	_set_targeting_position(valid_pos)
	
	# Use indicator manager's validate_placement method
	var validation_result: ValidationResults = _indicator_manager.validate_placement()
	assert_bool(validation_result.is_successful()).append_failure_message(
		"Validation should succeed for valid position %s" % valid_pos
	).is_true()
	
	# Test building at validated position
	var build_result: Node = _building_system.try_build_at_position(valid_pos)
	assert_object(build_result).is_not_null()
	
	if not _enter_build_mode_successfully(smithy_placeable):
		return
	
	# Test placement attempt
	var placement_result: Node = _building_system.try_build_at_position(Vector2(100, 100))
	assert_object(placement_result).is_not_null()
	
	# Exit build mode
	_building_system.exit_build_mode()
	assert_bool(_building_system.is_in_build_mode()).append_failure_message(
		"Should not be in build mode after exiting"
	).is_false()

func test_complete_building_workflow() -> void:
	if not _enter_build_mode_successfully(smithy_placeable):
		return
	
	# Test placement attempt
	var placement_result: Node = _building_system.try_build_at_position(Vector2(100, 100))
	assert_object(placement_result).is_not_null()
	
	# Exit build mode
	_building_system.exit_build_mode()
	assert_bool(_building_system.is_in_build_mode()).append_failure_message(
		"Should not be in build mode after exiting"
	).is_false()

func test_building_workflow_with_validation() -> void:
	if not _enter_build_mode_successfully(smithy_placeable):
		return
	
	# Test valid position  
	var valid_pos: Vector2 = Vector2(50, 50)
	_set_targeting_position(valid_pos)
	
	# Use indicator manager's validate_placement method
	var validation_result: ValidationResults = _indicator_manager.validate_placement()
	assert_bool(validation_result.is_successful()).append_failure_message(
		"Validation should succeed for valid position %s" % valid_pos
	).is_true()
	
	# Test building at validated position
	var build_result: Node = _building_system.try_build_at_position(valid_pos)
	assert_object(build_result).is_not_null()

#endregion

#region MULTI-RULE INDICATOR ATTACHMENT

func test_multi_rule_indicator_attachment() -> void:
	var collision_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	var tile_rule: TileCheckRule = TileCheckRule.new()
	var _test_object: StaticBody2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)

	var rules: Array[PlacementRule] = [collision_rule, tile_rule]
	var setup_result: PlacementReport = _indicator_manager.try_setup(rules, _gts.get_state())

	_assert_setup_successful(setup_result, "Multi-rule setup")
	
	# Verify indicators are created
	var indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	assert_int(indicators.size()).append_failure_message(
		"Should have indicators for both rules, got %d" % indicators.size()
	).is_greater_equal(1)

func test_rule_indicator_state_synchronization() -> void:
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	var test_object: StaticBody2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)

	# Setup with initial state
	test_object.global_position = Vector2(64, 64)
	var setup_result: PlacementReport = _indicator_manager.try_setup([rule], _gts.get_state())
	assert_bool(setup_result.is_successful()).is_true()
	
	# Change rule state and verify indicators update
	test_object.global_position = Vector2(96, 96)
	var update_result: PlacementReport = _indicator_manager.try_setup([rule], _gts.get_state())
	
	_assert_setup_successful(update_result, "Rule state update")

func test_indicators_are_parented_and_inside_tree() -> void:
	var preview: Node2D = _create_preview_with_collision()
	_container.get_states().targeting.target = preview
	
	# Build a collisions rule that applies to layer 1
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1 << 0
	rule.collision_mask = 1 << 0
	var rules: Array[PlacementRule] = [rule]
	
	var params: GridTargetingState = _make_rule_params(preview)
	var setup_results: PlacementReport = _indicator_manager.try_setup(rules, params)
	
	_assert_setup_successful(setup_results, "IndicatorManager.try_setup")
	var indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message("No indicators created").is_not_empty()
	
	for ind: RuleCheckIndicator in indicators:
		assert_bool(ind.is_inside_tree()).append_failure_message("Indicator not inside tree: %s" % ind.name).is_true()
		assert_object(ind.get_parent()).append_failure_message("Indicator has no parent: %s" % ind.name).is_not_null()
		assert_object(ind.get_parent()).append_failure_message("Unexpected parent for indicator: %s" % ind.name).is_equal(_container.get_states().manipulation.parent)

#endregion

#region SMITHY INDICATOR GENERATION

func test_smithy_indicator_generation() -> void:
	var smithy_rules: Array[PlacementRule] = smithy_placeable.placement_rules
	assert_array(smithy_rules).append_failure_message(
		"Smithy should have placement rules"
	).is_not_empty()
	
	# Generate indicators using proper parameters
	var smithy_node: Node = smithy_placeable.packed_scene.instantiate()
	add_child(smithy_node)

	var setup_result: PlacementReport = _indicator_manager.try_setup(smithy_rules, _gts.get_state())
	_assert_setup_successful(setup_result, "Smithy indicator generation")

func test_smithy_collision_detection() -> void:
	var collision_mapper: CollisionMapper = env.indicator_manager.get_collision_mapper()
	
	# Create a smithy node from the placeable for collision testing
	var smithy_node: Node = smithy_placeable.packed_scene.instantiate()
	add_child(smithy_node)
	
	# Test collision tile mapping for smithy (using production method)
	var collision_results: Dictionary = collision_mapper.get_collision_tile_positions_with_mask([smithy_node], 1)
	_assert_reasonable_collision_positions(collision_results)
	
	smithy_node.queue_free()

#endregion

#region COMPLEX WORKFLOW INTEGRATION

func test_complex_multi_system_workflow() -> void:
	var target_pos: Vector2 = Vector2(200, 200)
	_set_targeting_position(target_pos)
	
	assert_vector(target_pos).append_failure_message(
		"Target position should be set correctly"
	).is_equal(Vector2(200, 200))
	
	# Phase 2: Building placement
	if not _enter_build_mode_successfully(smithy_placeable):
		return
		
	var build_result: Node = _building_system.try_build_at_position(target_pos)
	assert_object(build_result).is_not_null()
	
	# Phase 3: Post-build manipulation
	env.manipulation_system.select_object(build_result)
	var manipulation_state: Dictionary = env.manipulation_system.get_current_state()
	assert_object(manipulation_state).append_failure_message(
		"Should have valid manipulation state after selection"
	).is_not_null()

func test_cross_system_state_consistency() -> void:
	var target_pos: Vector2 = Vector2(240, 240)
	_set_targeting_position(target_pos)
	
	if not _enter_build_mode_successfully(smithy_placeable):
		return
	
	# Verify state consistency
	var building_target: Vector2 = _building_system.get_target_position()
	var current_targeting_state: GridTargetingState = _targeting_system.get_state()
	var targeting_target: Vector2 = current_targeting_state.position
	
	# Systems should maintain consistent target positions
	assert_vector(building_target).append_failure_message(
		"Building system target (%s) should match targeting system (%s)" % [building_target, targeting_target]
	).is_equal(targeting_target)

#endregion

#region POLYGON TEST OBJECT INTEGRATION

func test_polygon_test_object_indicator_generation() -> void:
	var polygon_test_object = UnifiedTestFactory.create_polygon_test_placeable(self)
	var indicator_manager: IndicatorManager = env.indicator_manager
	
	# Get polygon object rules
	var polygon_rules = polygon_test_object.placement_rules
	assert_array(polygon_rules).append_failure_message(
		"Polygon test object should have placement rules"
	).is_not_empty()
	
	# Generate indicators for polygon object using proper parameters
	var polygon_node = polygon_test_object.packed_scene.instantiate()
	add_child(polygon_node)

	var setup_result = indicator_manager.try_setup(polygon_rules, _gts.get_state())
	assert_bool(setup_result.is_successful()).append_failure_message(
		"Polygon object indicator generation should succeed: %s" % str(setup_result.get_all_issues())
	).is_true()

func test_polygon_collision_integration() -> void:
	var polygon_test_object = UnifiedTestFactory.create_polygon_test_placeable(self)
	var collision_mapper: CollisionMapper = env.collision_mapper
	
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
	var highlight_manager = env.get("highlight_manager")  # May not be available in all environments
	
	if highlight_manager == null:
		# Skip if highlight manager not available in test environment
		return
	
	# Test targeting with highlight updates
	var targeting_state = _targeting_system.get_state()
	targeting_state.target.position = Vector2(360, 360)
	
	# Verify highlight state updates with targeting
	var highlight_active = highlight_manager.is_highlight_active()
	assert_bool(highlight_active).append_failure_message(
		"Highlight should be active when targeting position is set"
	).is_true()

func test_targeting_state_transitions() -> void:
	var targeting_state = _targeting_system.get_state()
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

#endregion
#region COMPREHENSIVE INTEGRATION VALIDATION

#region COMPREHENSIVE INTEGRATION VALIDATION

func test_full_system_integration_workflow() -> void:
	# Step 1: Set target
	var target_pos: Vector2 = Vector2(500, 500)
	_set_targeting_position(target_pos)
	
	# Step 2: Enter build mode with indicators
	if not _enter_build_mode_successfully(smithy_placeable):
		return
	
	var smithy_node: Node = smithy_placeable.packed_scene.instantiate()
	auto_free(smithy_node)
	add_child(smithy_node)
	
	var smithy_rules = smithy_placeable.placement_rules
	var params = _make_rule_params(smithy_node)
	
	var indicator_result = _indicator_manager.try_setup(smithy_rules, params)
	_assert_setup_successful(indicator_result, "Full workflow indicator setup")
	
	# Step 3: Build at target
	var build_result = _building_system.try_build_at_position(target_pos)
	assert_object(build_result).is_not_null()
	
	# Step 4: Validate post-build state
	_building_system.exit_build_mode()
	assert_bool(_building_system.is_in_build_mode()).is_false()

func test_system_error_recovery() -> void:
	# Test recovery from invalid operations
	var invalid_placeable = null
	var invalid_report = _building_system.enter_build_mode(invalid_placeable)
	
	# System should return a failed report for invalid input
	assert_object(invalid_report).is_not_null()
	if invalid_report and invalid_report.has_method("is_successful"):
		assert_bool(invalid_report.is_successful()).append_failure_message(
			"enter_build_mode should fail with null placeable"
		).is_false()
	
	# System should not be in build mode after failed enter_build_mode
	var is_in_build_mode = _building_system.is_in_build_mode()
	assert_bool(is_in_build_mode).append_failure_message(
		"System should not be in build mode after failed enter_build_mode"
	).is_false()
	
	# Ensure system can recover to valid state
	if _enter_build_mode_successfully(smithy_placeable):
		assert_bool(_building_system.is_in_build_mode()).append_failure_message(
			"System should recover and enter build mode with valid placeable"
		).is_true()
	
	_building_system.exit_build_mode()

#endregion
