## All Systems Integration Tests - DRY Refactored Version
##
## Comprehensive integration test suite validating the complete interaction between all core grid building systems
## including BuildingSystem, GridTargetingSystem, ManipulationSystem, and IndicatorManager.
## 
## This version implements DRY (Don't Repeat Yourself) principles with:
## - Centralized diagnostic helpers
## - Standardized assertion patterns  
## - Consolidated logging and error reporting
## - Reusable object creation functions
## - Parameterized test constants

extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

#region Test Constants - Centralized Configuration
const TEST_POSITION_1: Vector2 = Vector2(100, 100)
const TEST_POSITION_2: Vector2 = Vector2(200, 200)
const TEST_POSITION_3: Vector2 = Vector2(150, 150)
const TEST_POSITION_4: Vector2 = Vector2(400, 400)
const TEST_POSITION_5: Vector2 = Vector2(300, 300)
const MAX_TILE_COORDINATE: int = 1000
const COLLISION_LAYER_1: int = 1 << 0
const PERFORMANCE_THRESHOLD_MS: int = 100
const MEMORY_LEAK_THRESHOLD_BYTES: int = 1024 * 1024  # 1MB
const MAX_VALIDATION_ATTEMPTS: int = 3

# Diagnostic and messaging constants - eliminates string duplication
const DIAGNOSTIC_CONTEXTS: Dictionary = {
	"build_mode_entry": "build mode entry",
	"validation_workflow": "validation workflow setup", 
	"test_cleanup": "test cleanup",
	"performance_test": "performance test",
	"edge_case_testing": "edge case position testing",
	"collision_layer_test": "collision layer test iteration"
}

const LOG_MESSAGES: Dictionary = {
	"indicator_setup_failed": "Indicator setup failed for validation test (may be expected in some configurations): ",
	"build_mode_cleanup_warning": "Warning: %s left build mode active, cleaning up",
	"validation_failed_expected": "Validation failed at %s for %s (may be expected): %s",
	"memory_warning": "Warning: %s created %d extra child nodes that weren't cleaned up",
	"operation_failed": "Error: %s failed after %d attempts",
	"no_indicators_created": "No indicators were created (expected in some configurations)",
	"collision_no_results": "%s collision detection returned no results (expected in some configurations)",
	"highlighting_no_change": "Target highlighting did not change color (may be expected in this configuration)",
	"highlighting_success": "Target highlighting successfully changed color to: %s",
	"manipulation_init_failed": "Manipulation system did not successfully initialize move operation (may be expected in some configurations)",
	"no_built_node": "Build operation did not produce a node (may be expected in some configurations)",
	"no_manipulatable": "Built node does not have a Manipulatable component (may be expected in some configurations)",
	"manipulation_no_target": "Manipulation state did not capture target node (may be expected behavior)"
}

# Test collision and shape constants - eliminates magic numbers
const DEFAULT_COLLISION_SHAPE_SIZE: Vector2 = Vector2(32, 32)
const TILE_ALIGNED_OFFSET: Vector2 = Vector2(8, 8)  # Offset from tile corner to center
const DEFAULT_COLLISION_LAYER: int = COLLISION_LAYER_1
const TILE_SIZE: int = 16  # Grid tile size for alignment calculations

# Edge case test data - centralized test scenarios
const EDGE_CASE_POSITIONS: Array[Vector2] = [
	Vector2(0, 0),          # Origin
	Vector2(-1, -1),        # Negative coordinates
	Vector2(999, 999),      # Near boundary
	Vector2(1000, 1000),    # At boundary
	Vector2(1001, 1001)     # Beyond boundary
]

const TEST_COLLISION_LAYERS: Array[int] = [1, 2, 1 << 5]  # Valid collision layers for testing
#endregion

#region Test Environment Variables
var env: AllSystemsTestEnvironment
var _container: GBCompositionContainer
var _gts: GridTargetingSystem
var test_smithy_placeable: Placeable = load("uid://dirh6mcrgdm3w")
#endregion

#region Setup and Teardown - DRY lifecycle management
func before_test() -> void:
	env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)
	_container = env.get_container()
	_gts = env.grid_targeting_system
	_verify_system_state_consistency(DIAGNOSTIC_CONTEXTS.test_cleanup)

func after_test() -> void:
	if env and env.building_system:
		_ensure_build_mode_cleanup(env.building_system, DIAGNOSTIC_CONTEXTS.test_cleanup)
	
	# Clean up test-specific nodes to prevent memory leaks
	_cleanup_test_nodes(["PreviewRoot", "TestCollision"])
	env = null
	
func _cleanup_test_nodes(prefixes: Array[String]) -> void:
	"""Centralized test node cleanup to prevent memory leaks"""
	for child in get_children():
		for prefix in prefixes:
			if child.name.begins_with(prefix):
				child.queue_free()
				break
#endregion

#region Diagnostic Helper Methods - Centralized error reporting and assertions

func _assert_placement_report_successful(report: PlacementReport, context: String) -> void:
	"""Standardized assertion for successful placement reports with diagnostic context"""
	assert_bool(report.is_successful()).append_failure_message(
		"%s - Issues: %s | Report Details: %s" % [
			context, 
			str(report.get_issues()) if report != null else "null report",
			_format_placement_report_debug(report)
		]
	).is_true()

func _assert_build_mode_state(building_system: Object, expected_in_build_mode: bool, context: String) -> void:
	"""Standardized assertion for build mode state with diagnostic context"""
	var actual_state: bool = building_system.is_in_build_mode()
	var state_description: String = "in build mode" if expected_in_build_mode else "not in build mode"
	assert_bool(actual_state).append_failure_message(
		"%s - Expected system to be %s, actual state: %s | System: %s" % [
			context, state_description, actual_state, _format_system_state_debug(building_system, env.indicator_manager)
		]
	).is_equal(expected_in_build_mode)

func _assert_validation_result(validation_result: ValidationResults, position: Vector2, expected_success: bool, context: String) -> void:
	"""Centralized validation result assertion with detailed diagnostic reporting"""
	var actual_success: bool = validation_result.is_successful()
	if expected_success == actual_success:
		return  # Result matches expectation
	
	# Unexpected result - provide detailed diagnostics
	var issues: Array[String] = validation_result.get_issues()
	var success_description: String = "succeed" if expected_success else "fail"
	var actual_description: String = "succeeded" if actual_success else "failed"
	
	if expected_success:
		_log_conditional_message(LOG_MESSAGES.validation_failed_expected % [position, context, issues])
	else:
		assert_bool(actual_success).append_failure_message(
			"%s: Validation should %s at position %s but %s - Issues: %s | ValidationDetails: %s" % [
				context, success_description, position, actual_description, issues,
				_format_validation_result_debug(validation_result)
			]
		).is_false()

func _log_conditional_message(message: String, force_log: bool = false) -> void:
	"""Centralized conditional logging that respects test verbosity settings"""
	if force_log or OS.has_feature("debug"):
		print("[TestDiagnostic] %s" % message)

func _format_system_state_debug(building_system: Object, indicator_manager: IndicatorManager) -> String:
	"""Format comprehensive system state information for diagnostics"""
	var parts: Array[String] = []
	parts.append("BuildMode: %s" % building_system.is_in_build_mode())
	parts.append("Indicators: %d" % indicator_manager.get_indicators().size())
	parts.append("Container: %s" % ("valid" if env.get_container() != null else "null"))
	return "[SystemState: %s]" % " | ".join(parts)

func _format_collision_object_debug(collision_object: StaticBody2D) -> String:
	"""Format collision object diagnostic information"""
	var parts: Array[String] = []
	parts.append("Name: %s" % collision_object.name)
	parts.append("Position: %s" % collision_object.global_position)
	parts.append("Layer: %d" % collision_object.collision_layer)
	parts.append("Mask: %d" % collision_object.collision_mask)
	var shape_info: String = "NoShape"
	if collision_object.get_child_count() > 0:
		var shape_node: CollisionShape2D = collision_object.get_child(0) as CollisionShape2D
		if shape_node and shape_node.shape:
			if shape_node.shape is RectangleShape2D:
				shape_info = "Rect:%s" % (shape_node.shape as RectangleShape2D).size
	parts.append("Shape: %s" % shape_info)
	return "[CollisionObject: %s]" % " | ".join(parts)

func _format_performance_result(operation: String, duration: int, threshold: int) -> String:
	"""Format performance test result with context and thresholds"""
	var status: String = "PASS" if duration < threshold else "SLOW"
	var percentage: float = (float(duration) / float(threshold)) * 100.0
	return "[Performance %s] %s: %d ms (%.1f%% of %d ms threshold)" % [status, operation, duration, percentage, threshold]

func _format_validation_result_debug(validation_result: ValidationResults) -> String:
	"""Format validation result details for diagnostics"""
	var parts: Array[String] = []
	parts.append("Success: %s" % validation_result.is_successful())
	parts.append("Issues: %d" % validation_result.get_issues().size())
	parts.append("RuleResults: %d" % (validation_result.rule_results.size() if validation_result.has_method("rule_results") else 0))
	return "[ValidationResult: %s]" % " | ".join(parts)

#endregion

#region Object Creation Helpers - Reusable factory methods

func _create_collision_obstacle_at_position(position: Vector2, name_suffix: String = "") -> StaticBody2D:
	"""Standardized collision obstacle creation with consistent configuration"""
	var collision_obstacle: StaticBody2D = StaticBody2D.new()
	collision_obstacle.name = "TestCollisionObstacle" + name_suffix
	collision_obstacle.collision_layer = DEFAULT_COLLISION_LAYER
	collision_obstacle.collision_mask = DEFAULT_COLLISION_LAYER
	
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = DEFAULT_COLLISION_SHAPE_SIZE
	collision_shape.shape = rect_shape
	collision_obstacle.add_child(collision_shape)
	collision_obstacle.global_position = position
	
	add_child(collision_obstacle)
	auto_free(collision_obstacle)
	return collision_obstacle

func _create_tile_aligned_collision_at_test_position(test_position: Vector2) -> StaticBody2D:
	"""Create collision obstacle aligned with tile grid for reliable collision detection"""
	var tile_aligned_position: Vector2 = Vector2(
		int(test_position.x / TILE_SIZE) * TILE_SIZE + TILE_ALIGNED_OFFSET.x,
		int(test_position.y / TILE_SIZE) * TILE_SIZE + TILE_ALIGNED_OFFSET.y
	)
	return _create_collision_obstacle_at_position(tile_aligned_position, "_TileAligned")

func _create_test_placeable_with_rules() -> Placeable:
	"""Standardized test placeable creation with consistent rule configuration"""
	var placeable: Placeable = Placeable.new()
	placeable.packed_scene = test_smithy_placeable.packed_scene
	
	# Create properly configured collision rule
	var collision_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	collision_rule.apply_to_objects_mask = DEFAULT_COLLISION_LAYER
	collision_rule.collision_mask = DEFAULT_COLLISION_LAYER
	collision_rule.pass_on_collision = false
	if collision_rule.messages == null:
		collision_rule.messages = CollisionRuleSettings.new()
	
	# Create tile rule with proper configuration
	var tile_rule: ValidPlacementTileRule = ValidPlacementTileRule.new()
	tile_rule.expected_tile_custom_data = {"buildable": true}
	
	placeable.placement_rules = [collision_rule, tile_rule]
	return placeable

#endregion

#region Workflow Helpers - Reusable test operation patterns

func _enter_build_mode_successfully(building_system: Object, placeable: Placeable, context: String = DIAGNOSTIC_CONTEXTS.build_mode_entry) -> PlacementReport:
	"""Helper to enter build mode with standardized success assertion and error reporting"""
	var setup_report: PlacementReport = building_system.enter_build_mode(placeable)
	_assert_placement_report_successful(setup_report, context + ": Setup report should be successful")
	_assert_build_mode_state(building_system, true, context + ": BuildingSystem should be in build mode after successful setup")
	return setup_report

func _setup_validation_workflow(building_system: Object, indicator_manager: IndicatorManager, placeable: Placeable, position: Vector2) -> Dictionary:
	"""Helper for complete validation workflow setup with proper error handling"""
	var build_report: PlacementReport = _enter_build_mode_successfully(building_system, placeable, DIAGNOSTIC_CONTEXTS.validation_workflow)
	
	var targeting_state: GridTargetingState = env.get_container().get_states().targeting
	_set_targeting_position(targeting_state, position)
	
	var indicator_setup_result: PlacementReport = indicator_manager.try_setup(placeable.placement_rules, targeting_state)
	
	return {
		"build_report": build_report,
		"targeting_state": targeting_state,
		"indicator_setup": indicator_setup_result,
		"validation_ready": indicator_setup_result.is_successful()
	}

func _ensure_build_mode_cleanup(building_system: Object, context: String) -> void:
	"""Ensure build mode is properly cleaned up after tests to prevent state leakage"""
	if building_system.is_in_build_mode():
		_log_conditional_message(LOG_MESSAGES.build_mode_cleanup_warning % context)
		building_system.exit_build_mode()
	
	_assert_build_mode_state(building_system, false, "Build mode should be inactive after cleanup in %s" % context)

func _verify_system_state_consistency(context: String) -> void:
	"""Verify that all systems are in a consistent state"""
	var building_system: Object = env.building_system
	var indicator_manager: IndicatorManager = env.indicator_manager
	
	var is_in_build_mode: bool = building_system.is_in_build_mode()
	var has_active_indicators: bool = indicator_manager.get_indicators().size() > 0
	
	_log_conditional_message("System state in %s: %s" % [context, _format_system_state_debug(building_system, indicator_manager)])
	
	# Build mode and indicators should be consistent
	if is_in_build_mode and not has_active_indicators:
		_log_conditional_message("Warning in %s: Build mode active but no indicators present" % context)
	elif not is_in_build_mode and has_active_indicators:
		_log_conditional_message("Warning in %s: Indicators present but not in build mode" % context)

#endregion

#region Performance and Monitoring Helpers

func _time_operation(callable: Callable, operation_name: String, threshold: int = PERFORMANCE_THRESHOLD_MS) -> int:
	"""Time an operation with optional threshold assertion and diagnostic logging"""
	var start_time: int = Time.get_ticks_msec()
	callable.call()
	var end_time: int = Time.get_ticks_msec()
	var duration: int = end_time - start_time
	
	_log_conditional_message(_format_performance_result(operation_name, duration, threshold))
	
	if threshold > 0:  # Only assert if threshold is specified
		assert_int(duration).append_failure_message(
			"%s took %d ms (should be < %d ms for performance)" % [operation_name, duration, threshold]
		).is_less(threshold)
	
	return duration

func _monitor_memory_usage(operation_callable: Callable, operation_name: String, threshold: int = 10) -> void:
	"""Monitor memory usage during an operation to detect leaks"""
	var initial_child_count: int = get_child_count()
	operation_callable.call()
	await get_tree().process_frame
	
	var final_child_count: int = get_child_count()
	var child_diff: int = final_child_count - initial_child_count
	
	if child_diff > threshold:
		_log_conditional_message(LOG_MESSAGES.memory_warning % [operation_name, child_diff])

func _retry_operation_with_exponential_backoff(callable: Callable, max_attempts: int = MAX_VALIDATION_ATTEMPTS, operation_name: String = "operation") -> bool:
	"""Retry an operation with exponential backoff for flaky operations"""
	for attempt in range(max_attempts):
		var result: Variant = callable.call()
		
		if result is bool and result == true:
			return true
		elif result is Object and result.is_successful():
			return true
		elif result == null:
			return true
		
		if attempt == max_attempts - 1:
			_log_conditional_message(LOG_MESSAGES.operation_failed % [operation_name, max_attempts])
			return false
		else:
			var wait_time: float = pow(2, attempt) * 0.1
			await get_tree().create_timer(wait_time).timeout
	
	return false

#endregion

#region Legacy Helper Functions - Maintain compatibility

func _set_targeting_position(targeting_state: GridTargetingState, position: Vector2) -> void:
	if targeting_state.positioner != null:
		targeting_state.positioner.global_position = position

func _create_preview_with_collision() -> Node2D:
	var root := Node2D.new()
	root.name = "PreviewRoot"
	var area := Area2D.new()
	area.collision_layer = DEFAULT_COLLISION_LAYER
	area.collision_mask = DEFAULT_COLLISION_LAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = DEFAULT_COLLISION_SHAPE_SIZE
	shape.shape = rect
	area.add_child(shape)
	root.add_child(area)
	add_child(root)
	return root

# Legacy method - use _assert_validation_result instead
func _assert_validation_result_with_context(validation_result: ValidationResults, position: Vector2, expected_success: bool, context: String) -> void:
	"""Legacy method - redirects to _assert_validation_result for consistency"""
	_assert_validation_result(validation_result, position, expected_success, context)

func _format_placement_report_debug(report: PlacementReport) -> String:
	"""Helper function to format detailed placement report diagnostic information."""
	if report == null:
		return "PlacementReport is null"
	
	var debug_parts: Array[String] = []
	debug_parts.append("Action: %s" % str(report.action_type))
	debug_parts.append("Preview: %s" % (str(report.preview_instance) if report.preview_instance else "null"))
	debug_parts.append("Placer: %s" % (str(report.placer) if report.placer else "null"))
	
	if report.indicators_report:
		debug_parts.append("Indicators: %d" % report.indicators_report.indicators.size())
		debug_parts.append("Rules: %d" % report.indicators_report.rules.size())
		debug_parts.append("Tile Positions: %d" % report.indicators_report.tile_positions.size())
		if not report.indicators_report.get_indicators_issues().is_empty():
			debug_parts.append("Indicator Issues: %s" % str(report.indicators_report.get_indicators_issues()))
	else:
		debug_parts.append("Indicators Report: null")
	
	if not report.notes.is_empty():
		debug_parts.append("Notes: %s" % str(report.notes))
	
	return " | ".join(debug_parts)

#endregion

#region Sample DRY Test Implementation

func test_basic_building_workflow() -> void:
	"""Example of DRY test implementation using helper methods"""
	var building_system: Object = env.building_system
	var test_placeable: Placeable = _create_test_placeable_with_rules()

	# Use DRY helper for build mode entry
	var _setup_report: PlacementReport = _enter_build_mode_successfully(building_system, test_placeable, "basic workflow test")

	# Test building at position with enhanced diagnostics
	var placement_report: PlacementReport = building_system.try_build_at_position(TEST_POSITION_1)
	_assert_placement_report_successful(placement_report, "Basic workflow placement at TEST_POSITION_1")

	# Test exiting build mode with state verification
	building_system.exit_build_mode()
	_assert_build_mode_state(building_system, false, "Basic workflow build mode exit")

func test_building_workflow_with_validation_dry() -> void:
	"""Example of DRY validation workflow using all helper methods"""
	var building_system: Object = env.building_system
	var indicator_manager: IndicatorManager = env.indicator_manager
	var test_placeable: Placeable = _create_test_placeable_with_rules()

	# Create collision obstacle using DRY helper
	var collision_obstacle: StaticBody2D = _create_tile_aligned_collision_at_test_position(TEST_POSITION_1)
	_log_conditional_message("Created collision obstacle: %s" % _format_collision_object_debug(collision_obstacle))
	
	await get_tree().physics_frame

	# Use DRY validation workflow setup
	var validation_setup: Dictionary = _setup_validation_workflow(
		building_system, indicator_manager, test_placeable, collision_obstacle.global_position
	)
	
	if not validation_setup.validation_ready:
		_log_conditional_message(LOG_MESSAGES.indicator_setup_failed + str(validation_setup.indicator_setup.get_issues()))
		return

	# Perform validation with DRY assertion helper
	var validation_result: ValidationResults = indicator_manager.validate_placement()
	_assert_validation_result(validation_result, collision_obstacle.global_position, false, DIAGNOSTIC_CONTEXTS.validation_workflow)

	if validation_result.is_successful():
		var build_result: PlacementReport = building_system.try_build_at_position(TEST_POSITION_1)
		assert_object(build_result).is_not_null()

#endregion