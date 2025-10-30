
## Test Suite: Manipulation System Integration Tests
##
## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern
## for better reliability and deterministic frame control.
##
## Validates the ManipulationSystem's core functionality for grid building operations
## including move, cancel, demolish, flip, rotate, and placement operations.
## Tests integration with manipulation state, targeting state, and validation systems
## to ensure proper manipulation workflows and state management.
##
## Coverage:
## - Movement operations (try_move, cancel) - tests state transitions and data validation
## - Transform operations (flip horizontal/vertical, rotate) - tests geometry transformations
## - Placement operations (try_placement, demolish) - tests validation and finalization
## - State management and validation - tests proper cleanup and error handling
## - Edge cases and null safety - prevents null reference crashes

extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

#region Test Constants
const ROTATION_INCREMENT: float = 45.0
const ROTATION_PRECISION: float = 0.0001
const SCALE_PRECISION: float = 0.01
const POSITION_PRECISION: float = 0.01
const NEGATIVE_ROTATION_INCREMENT: float = -33.3333
const ROTATION_RANGE_MIN: float = -360.0
const ROTATION_RANGE_MAX: float = 360.0
## TEST CONFIGURATION
const TEST_POSITION: Vector2 = Vector2(8.0, 8.0)
const CANCEL_TEST_POSITION: Vector2i = Vector2i(100, -100)
const ROTATION_ITERATIONS: int = 10

# ManipulatableSettings - use preloaded resources directly
var manipulatable_settings_all_allowed: ManipulatableSettings = GBTestConstants.MANIPULATABLE_SETTINGS_ALL_ALLOWED
var manipulatable_settings_none_allowed: ManipulatableSettings = GBTestConstants.MANIPULATABLE_SETTINGS_NONE_ALLOWED
var rules_2_rules_1_tile_check: ManipulatableSettings = GBTestConstants.RULES_2_RULES_1_TILE_CHECK
#endregion

#region Test Environment Variables
var runner: GdUnitSceneRunner
var test_hierarchy: AllSystemsTestEnvironment
var system: ManipulationSystem
var manipulation_state: ManipulationState
var all_manipulatable: Manipulatable
var manipulation_hierarchy : Dictionary[String, Node]
var _container: GBCompositionContainer
#endregion

#region Setup and Teardown
func before_test() -> void:
	# Use the premade AllSystemsTestEnvironment scene
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV)
	test_hierarchy = runner.scene() as AllSystemsTestEnvironment

	assert_object(test_hierarchy).append_failure_message(
		"Failed to load AllSystemsTestEnvironment scene"
	).is_not_null()

	# Extract environment components for test access
	_container = test_hierarchy.get_container()
	system = test_hierarchy.manipulation_system
	manipulation_state = _container.get_manipulation_state()
	manipulation_hierarchy = _instance_manipulatable_hierarchy()
	all_manipulatable = manipulation_hierarchy.get("manipulatable", null)

	# Fix: Set up targeting state with a default target
	_setup_targeting_state()

	# Fix: Set up manipulation state with the test manipulatable
	if all_manipulatable != null:
		manipulation_state.active_manipulatable = all_manipulatable

## Sets up the GridTargetingState with a default target for manipulation system tests
func _setup_targeting_state() -> void:
	var targeting_state: GridTargetingState = _container.get_states().targeting

	# Create a default target for the targeting state if none exists
	if targeting_state.get_target() == null:
		var default_target: Node2D = auto_free(Node2D.new())
		default_target.position = Vector2(64, 64)
		default_target.name = "DefaultTarget"
		add_child(default_target)
		targeting_state.set_manual_target(default_target)
#endregion

func _instance_manipulatable_hierarchy() -> Dictionary[String, Node]:
	var root : Node2D = auto_free(Node2D.new())  # Fix: Use Node2D instead of Node
	add_child(root)
	var manipulatable : Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = root  # Fix: Set the root property
	# Fix: Set manipulatable settings to prevent validation errors
	manipulatable.settings = manipulatable_settings_all_allowed
	root.add_child(manipulatable)

	return {
		"null": null,
		"root": root,
		"manipulatable": manipulatable,
		"manipulatable_root": manipulatable.root
	}

#region Movement Operation Tests
@warning_ignore("unused_parameter")
func test_start_move(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	test_parameters := [
		[null, true],
		[rules_2_rules_1_tile_check, true],
		[manipulatable_settings_all_allowed, true]
	]
) -> void:
	# Use default value when p_settings is null
	if p_settings == null:
		p_settings = manipulatable_settings_all_allowed
		p_expected = true

	# Set positioner to TEST_POSITION to ensure consistent behavior
	_container.get_states().targeting.positioner.global_position = TEST_POSITION

	var source_manipulatable: Manipulatable = _create_test_manipulatable(p_settings)
	assert_that(source_manipulatable).append_failure_message("Source manipulatable should not be null").is_not_null()
	assert_that(source_manipulatable.root).append_failure_message("Source manipulatable root should not be null").is_not_null()

	# Set the targeting state to target this manipulatable's root
	_container.get_states().targeting.set_manual_target(source_manipulatable.root)

	var result_data: ManipulationData = system.try_move(source_manipulatable.root)

	# Fix null reference issue: ensure result_data is not null
	assert_that(result_data).append_failure_message(
		"ManipulationSystem.try_move should return valid ManipulationData, not null"
	).is_not_null()

	if result_data != null:
		var result: bool = result_data.status == GBEnums.Status.STARTED
		assert_bool(result).append_failure_message("Move operation result should match expected value %s" % p_expected)\
			.is_equal(p_expected)

		# During manipulation, the move copy should follow the positioner position, not the source position
		# This provides visual feedback to the user about where the object will be placed
		if result_data.source != null and result_data.move_copy != null and _container.get_states().targeting.positioner != null:
			var positioner_pos: Vector2 = _container.get_states().targeting.positioner.global_position
			assert_vector(result_data.move_copy.root.global_position).append_failure_message("Move copy position should match positioner position during move").is_equal(positioner_pos)

func test_cancel() -> void:
	var source: Manipulatable = _create_test_manipulatable(manipulatable_settings_all_allowed)

	# Set the targeting state to target this manipulatable's root
	_container.get_states().targeting.set_manual_target(source.root)

	var move_result: ManipulationData = system.try_move(source.root)
	assert_that(move_result).append_failure_message(
		"try_move for cancel test should return valid result"
	).is_not_null()

	if move_result != null:
		var valid_move: bool = move_result.status == GBEnums.Status.STARTED
		assert_bool(valid_move).append_failure_message("Move should be successfully started for cancel test").is_true()

		# Get active manipulation data
		var active_data: ManipulationData = _container.get_states().manipulation.data
		_validate_manipulation_data(active_data, "active manipulation data after move")

		# Test cancel behavior
		if active_data != null and active_data.move_copy != null:
			active_data.move_copy.root.global_position = CANCEL_TEST_POSITION
			var origin: Vector2 = active_data.source.root.global_transform.origin
			assert_float(origin.x).append_failure_message("Origin x position should be approximately %f" % TEST_POSITION.x)\
				.is_equal_approx(TEST_POSITION.x, POSITION_PRECISION)
			assert_float(origin.y).append_failure_message("Origin y position should be approximately %f" % TEST_POSITION.y)\
				.is_equal_approx(TEST_POSITION.y, POSITION_PRECISION)

			system.cancel()
			assert_object(_container.get_states().manipulation.data).append_failure_message("Manipulation data should be null after cancel").is_null()
			assert_vector(active_data.source.root.global_position).append_failure_message("Source position should return to original after cancel").is_equal(TEST_POSITION)

@warning_ignore("unused_parameter")
func test_try_move(
	p_move_target: String,
	p_expected: GBEnums.Status,
	test_parameters := [
		["null", GBEnums.Status.FAILED],
		["root", GBEnums.Status.STARTED],
		["manipulatable", GBEnums.Status.FAILED],
		["manipulatable_root", GBEnums.Status.STARTED]
	]
) -> void:
	var target_node: Node = manipulation_hierarchy.get(p_move_target, null)

	# For valid target nodes, set up the targeting state
	if target_node != null and target_node is Node2D:
		_container.get_states().targeting.set_manual_target(target_node as Node2D)

	var result_data: ManipulationData = system.try_move(target_node)

	# Ensure result is not null to prevent property access errors
	assert_that(result_data).append_failure_message(
		"try_move should never return null, even for invalid inputs"
	).is_not_null()

	if result_data != null:
		assert_int(result_data.status).append_failure_message(
			"try_move status should be %s for target '%s', but got %s" % [p_expected, p_move_target, result_data.status]
		).is_equal(p_expected)
#endregion

#region Demolish and Placement Tests
@warning_ignore("unused_parameter")
func test_demolish(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	# Temporarily disabled parameterized test to fix GdUnit4 parsing issue
	# Resource objects in test_parameters cause str_to_var() to return null
	test_parameters := [
		[manipulatable_settings_none_allowed, false],
		[manipulatable_settings_all_allowed, true]
	]
) -> void:
	# Use default value when p_settings is null
	if p_settings == null:
		p_settings = manipulatable_settings_all_allowed
		p_expected = true
	var target_manipulatable: Manipulatable = _create_test_manipulatable(p_settings) if p_settings != null else all_manipulatable
	assert_that(target_manipulatable).append_failure_message("Target manipulatable should not be null for demolish test").is_not_null()

	monitor_signals(manipulation_state)

	# Fix null reference issue: demolish should return valid result
	var demolish_result: Variant = system.demolish(target_manipulatable)

	# Handle return value - demolish returns bool
	var success: bool = demolish_result if demolish_result is bool else false

	assert_bool(success).append_failure_message("Demolish operation should have expected success status %s" % p_expected)\
		.is_equal(p_expected)

@warning_ignore("unused_parameter")
func test_try_placement(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	test_parameters := [[manipulatable_settings_all_allowed, true]]  # Changed: Expect TRUE because factory creates collision shapes
) -> void:
	var source: Manipulatable = _create_test_manipulatable(p_settings)
	assert_that(source).append_failure_message("Source manipulatable should not be null for placement test").is_not_null()

	# Set the targeting state to target this manipulatable's root
	_container.get_states().targeting.set_manual_target(source.root)

	var move_result: ManipulationData = system.try_move(source.root)
	assert_that(move_result).append_failure_message(
		"try_move for placement test should return valid result"
	).is_not_null()

	if move_result != null:
		var started: bool = move_result.status == GBEnums.Status.STARTED
		assert_bool(started).append_failure_message("Move should be successfully started for placement test").is_true()

		var move_data: ManipulationData = _container.get_states().manipulation.data
		_validate_manipulation_data(move_data, "manipulation data for placement")

		if move_data != null and move_data.move_copy != null:
			var test_location: Vector2 = TEST_POSITION
			move_data.move_copy.root.global_position = test_location

			var placement_results: ValidationResults = system.try_placement(move_data)
			assert_that(placement_results).append_failure_message("Placement results should not be null").is_not_null()

			if placement_results != null:
				# Enhanced diagnostic: Show why placement succeeded/failed
				var success_status: bool = placement_results.is_successful()

				assert_bool(success_status).append_failure_message(
					"Placement expected: %s - Got: %s, Validation: %s, Position: %s" % [
						p_expected,
						success_status,
						placement_results.get_summary_string(),
						test_location
					]
				).is_equal(p_expected)

				# After successful placement, verify state changes
				if success_status:
					assert_object(move_data.move_copy).append_failure_message("Move copy should be null after successful placement").is_null()
					assert_vector(source.root.global_position).append_failure_message("Source position should match test location after placement").is_equal(test_location)

## Test: Failed placement due to collision should NOT execute move and should clean up target
## REGRESSION TEST: Verify that try_placement() properly cleans up when ManipulationData is invalid.
##
## Bug: Both failure paths in try_placement() were missing cleanup logic:
## 1. p_move.is_valid() == false (invalid ManipulationData)
## 2. validation_results.is_successful == false (collision/rule failures)
##
## Before fix: Failed placements would leave target copies in scene and status would be wrong.
## After fix: Both paths call tear_down() and queue_free_manipulation_objects()
##
## NOTE: This test checks path #1 (invalid ManipulationData). Path #2 (collision failures)
## is tested implicitly by other manipulation tests that use the validation system.
func test_failed_placement_with_invalid_move_data_cleans_up() -> void:
	# Setup: Create a manipulatable source object
	var source: Manipulatable = _create_test_manipulatable(manipulatable_settings_all_allowed)
	var original_source_position: Vector2 = source.root.global_position
	assert_vector(original_source_position).is_equal(TEST_POSITION)

	# Set the targeting state to target this manipulatable's root
	_container.get_states().targeting.set_manual_target(source.root)

	# Act: Start a move operation
	var move_result: ManipulationData = system.try_move(source.root)
	assert_bool(move_result.status == GBEnums.Status.STARTED).append_failure_message(
		"Move should start successfully"
	).is_true()

	var move_data: ManipulationData = _container.get_states().manipulation.data
	assert_that(move_data).append_failure_message("Move data should exist").is_not_null()
	assert_that(move_data.move_copy).append_failure_message("Move copy should exist").is_not_null()

	# Store reference to move copy for later verification
	var move_copy_root: Node = move_data.get_move_copy_root()

	# CRITICAL: Make ManipulationData invalid by nulling source
	# This triggers the p_move.is_valid() == false path in try_placement()
	var saved_source: Manipulatable = move_data.source
	move_data.source = null

	# Act: Try placement with invalid move data (should fail and cleanup)
	var placement_results: ValidationResults = system.try_placement(move_data)

	# Restore source reference so we can verify it wasn't moved
	move_data.source = saved_source

	# Assert: Status should be FAILED (not STARTED or FINISHED)
	assert_int(move_data.status).append_failure_message(
		"Move data status should be FAILED after invalid move data"
	).is_equal(GBEnums.Status.FAILED)

	# Assert: CRITICAL - Source object should NOT have moved
	assert_vector(source.root.global_position).append_failure_message(
		"Source position should remain unchanged after failed placement - was %s, now %s" % [
			str(original_source_position),
			str(source.root.global_position)
		]
	).is_equal(original_source_position)

	# Assert: CRITICAL - Move copy should be cleaned up (freed or removed from tree)
	# After failed placement, the move copy should be cleaned up to prevent orphaned objects
	# Wait a frame for queue_free() to process
	await get_tree().process_frame
	if is_instance_valid(move_copy_root):
		assert_bool(move_copy_root.is_inside_tree()).append_failure_message(
			"Move copy should be removed from scene tree after failed placement"
		).is_false()
	# If move copy was freed, that's also acceptable (even better)

	# Assert: ManipulationData should be cleared or marked invalid
	# The system should not retain invalid manipulation data
	var current_data: ManipulationData = _container.get_states().manipulation.data
	if current_data != null:
		# If data still exists, it should be marked as failed
		assert_int(current_data.status).append_failure_message(
			"Manipulation data should be FAILED status"
		).is_equal(GBEnums.Status.FAILED)

#endregion

#region Transform Operation Tests
func test_flip_horizontal() -> void:
	_validate_manipulatable_for_transform(all_manipulatable, "flip_horizontal")
	var target: Node2D = all_manipulatable.root
	# Test uses ManipulationParent architecture - transforms are applied to manipulation parent
	var manipulation_parent: ManipulationParent = manipulation_state.parent
	var original_scale: Vector2 = manipulation_parent.scale

	system.flip_horizontal(target)

	# Test ManipulationParent scale instead of target scale (correct architecture)
	assert_float(manipulation_parent.scale.x).append_failure_message("Horizontal flip should invert ManipulationParent X scale")\
		.is_equal_approx(original_scale.x * -1, SCALE_PRECISION)
	assert_float(manipulation_parent.scale.y).append_failure_message("Horizontal flip should preserve ManipulationParent Y scale")\
		.is_equal_approx(original_scale.y, SCALE_PRECISION)

@warning_ignore("unused_parameter")
func test_flip_vertical(
	p_manipulatable: Manipulatable,
	test_parameters := [[all_manipulatable]]  # Disabled for GdUnit4 parsing
) -> void:
	_validate_manipulatable_for_transform(p_manipulatable, "flip_vertical")
	var target: Node2D = p_manipulatable.root
	# Test uses ManipulationParent architecture - transforms are applied to manipulation parent
	var manipulation_parent: ManipulationParent = manipulation_state.parent
	var original_scale: Vector2 = manipulation_parent.scale

	system.flip_vertical(target)

	# Test ManipulationParent scale instead of target scale (correct architecture)
	assert_float(manipulation_parent.scale.x).append_failure_message("Vertical flip should preserve ManipulationParent X scale")\
		.is_equal_approx(original_scale.x, SCALE_PRECISION)
	assert_float(manipulation_parent.scale.y).append_failure_message("Vertical flip should invert ManipulationParent Y scale")\
		.is_equal_approx(original_scale.y * -1, SCALE_PRECISION)

@warning_ignore("unused_parameter")
func test_rotate_node2d_target_rotates_correctly(
	p_manipulatable: Manipulatable,
	test_parameters := [[all_manipulatable]]  # Disabled for GdUnit4 parsing
) -> void:
	_validate_manipulatable_for_transform(p_manipulatable, "rotate")
	var target: Node2D = p_manipulatable.root
	# Test uses ManipulationParent architecture - rotation is applied to manipulation parent
	var manipulation_parent: ManipulationParent = manipulation_state.parent
	var expected_rotation_degrees: float = manipulation_parent.global_rotation_degrees

	for i in range(ROTATION_ITERATIONS):
		var success: bool = system.rotate(target, ROTATION_INCREMENT)
		assert_bool(success).append_failure_message("Rotate operation should succeed on iteration %d" % i).is_true()

		expected_rotation_degrees += ROTATION_INCREMENT
		var normalized_expected: float = _normalize_rotation(expected_rotation_degrees)
		# Test ManipulationParent rotation instead of target rotation (correct architecture)
		var actual_rotation: float = _normalize_rotation(manipulation_parent.global_rotation_degrees)

		assert_float(actual_rotation).append_failure_message("Rotation should match expected degrees on iteration %d (expected: %f, actual: %f)" % [i, normalized_expected, actual_rotation])\
			.is_equal_approx(normalized_expected, ROTATION_PRECISION)

@warning_ignore("unused_parameter")
func test_rotate_negative(
	p_manipulatable: Manipulatable,
	p_expected: bool,
	test_parameters := [[all_manipulatable, true]]  # Disabled for GdUnit4 parsing
) -> void:
	_validate_manipulatable_for_transform(p_manipulatable, "rotate_negative")

	var preview: Node2D = auto_free(Node2D.new())
	var placement_manager: IndicatorManager = auto_free(IndicatorManager.new())
	var target: Node2D = p_manipulatable.root

	var rotation_per_time: float = NEGATIVE_ROTATION_INCREMENT
	var total_rotation: float = 0.0

	for i in range(ROTATION_ITERATIONS):
		_total_rotation += rotation_per_time
		assert_bool(system.rotate(target, rotation_per_time)).is_equal(p_expected)

		var remainder_preview: float = fmod(preview.rotation_degrees, rotation_per_time)
		var remainder_rci: float = fmod(placement_manager.rotation_degrees, rotation_per_time)

		assert_float(remainder_preview).append_failure_message("Preview rotation remainder should be within expected range")\
			.is_between(ROTATION_RANGE_MIN, ROTATION_RANGE_MAX)
		assert_float(remainder_rci).append_failure_message("RCI rotation remainder should be within expected range")\
			.is_between(ROTATION_RANGE_MIN, ROTATION_RANGE_MAX)
#endregion

#region Helper Functions - DRY Patterns and Reusable Logic
## Creates a positioned Node2D for testing - reduces code duplication
func _create_positioned_node(node_name: String, position: Vector2) -> Node2D:
	var node: Node2D = auto_free(Node2D.new())
	node.name = node_name
	node.global_position = position
	add_child(node)  # Add to scene tree for proper searching
	return node

## Creates a test manipulatable with proper validation - used 3+ times
func _create_test_manipulatable(p_settings: ManipulatableSettings) -> Manipulatable:
	var root: Node2D = _create_positioned_node("ManipulatableRoot", TEST_POSITION)
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.name = "Manipulatable"
	manipulatable.root = root
	manipulatable.settings = p_settings
	root.add_child(manipulatable)

	# Add collision shape for indicator generation during placement validation
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect_shape: RectangleShape2D = auto_free(RectangleShape2D.new())
	rect_shape.size = Vector2(32, 32)
	collision_shape.shape = rect_shape
	collision_body.add_child(collision_shape)
	root.add_child(collision_body)

	return manipulatable

## Creates move data for testing - replaces _create_move_data with better validation
func _create_test_move_data(p_settings: ManipulatableSettings) -> ManipulationData:
	assert_that(_container).append_failure_message("Container should not be null when creating test move data").is_not_null()

	var source_obj: Manipulatable = _create_test_manipulatable(p_settings)
	assert_that(source_obj).append_failure_message("Source object should not be null").is_not_null()
	assert_that(source_obj.root).append_failure_message("Source object root should not be null").is_not_null()

	var target_duplicate: Manipulatable = auto_free(source_obj.duplicate())
	assert_that(target_duplicate).append_failure_message("Target duplicate should not be null").is_not_null()

	var manipulator_node: Node = manipulation_state.get_manipulator()
	assert_that(manipulator_node).append_failure_message("Manipulator node should not be null").is_not_null()

	var data: ManipulationData = ManipulationData.new(
		manipulator_node,
		source_obj,
		target_duplicate,
		GBEnums.Action.MOVE
	)
	assert_that(data).append_failure_message("Manipulation data should not be null after creation").is_not_null()
	add_child(data.move_copy)
	return data

## Validates manipulation data to prevent null reference errors - used 3+ times
func _validate_manipulation_data(data: ManipulationData, context: String) -> void:
	assert_that(data).append_failure_message(
		"%s should not be null" % context
	).is_not_null()

	if data != null:
		assert_that(data.source).append_failure_message(
			"%s source should not be null" % context
		).is_not_null()

		assert_that(data.move_copy).append_failure_message(
			"%s move_copy should not be null" % context
		).is_not_null()

		if data.source != null and data.move_copy != null:
			assert_that(data.source).append_failure_message("Source should be different instance from move_copy in %s" % context).is_not_same(data.move_copy)
			assert_that(data.source.root).append_failure_message("Source root should be different instance from move_copy root in %s" % context).is_not_same(data.move_copy.root)

## Validates manipulatable for transform operations - prevents null errors
func _validate_manipulatable_for_transform(p_manipulatable: Manipulatable, operation: String) -> void:
	assert_that(p_manipulatable).append_failure_message(
		"Manipulatable for %s should not be null" % operation
	).is_not_null()

	if p_manipulatable != null:
		assert_that(p_manipulatable.root).append_failure_message(
			"Manipulatable.root for %s should not be null" % operation
		).is_not_null()

## Normalizes rotation degrees to 0-360 range - mathematical utility
func _normalize_rotation(rotation_degrees: float) -> float:
	var normalized: float = fmod(rotation_degrees, 360.0)
	if normalized < 0:
		normalized += 360.0
	return normalized


## Clean up manipulation system state
func after_test() -> void:
	if system:
		system.cancel()
#endregion
