## Manipulation Rotation Workflow Test
##
## REGRESSION TEST: Validates that rotation doesn't break manipulation workflow.
## Tests that placement succeeds after rotation, proving indicator generation works correctly.
##
## HISTORICAL BUG (NOW FIXED): Rotating buildings caused indicator loss which broke placement.
## This test verifies the workflow remains functional through rotation cycles.
##
## ROOT CAUSE (FIXED): AABB expansion on rotation caused tile range calculation issues.
## Fixed by using polygon normalization during indicator calculation.
##
## TESTING APPROACH: Follows proven patterns from manipulation_system_test.gd
## Tests BEHAVIOR (placement success) rather than INTERNAL STATE (indicator count).
## This is more robust and matches best practices.
##
## See: WORKING_TEST_PATTERNS_ANALYSIS.md, TEST_INVESTIGATION_SUMMARY.md

extends GdUnitTestSuite

#region CONSTANTS

## Test position for placing objects (tile center, away from edges)
const TEST_POSITION: Vector2 = Vector2(128, 128)

## Manipulatable settings allowing all operations
var manipulatable_settings_all_allowed: ManipulatableSettings = load("uid://dn881lunp3lrm")

#endregion

#region TEST ENVIRONMENT

var runner: GdUnitSceneRunner
var test_environment: AllSystemsTestEnvironment
var _container: GBCompositionContainer
var _manipulation_system: ManipulationSystem
var _manipulation_state: ManipulationState
var _indicator_manager: IndicatorManager


func before_test() -> void:
	# Use ALL_SYSTEMS test environment (matches working test patterns)
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID)
	test_environment = runner.scene() as AllSystemsTestEnvironment

	(
		assert_object(test_environment) \
		. append_failure_message("Failed to load AllSystemsTestEnvironment scene") \
		. is_not_null()
	)

	# Extract systems from environment
	_container = test_environment.injector.composition_container
	_manipulation_system = test_environment.manipulation_system
	_manipulation_state = _container.get_manipulation_state()
	_indicator_manager = test_environment.indicator_manager

	# Setup targeting state for manipulation
	_setup_targeting_state()


## Sets up targeting state with default target (required for manipulation)
func _setup_targeting_state() -> void:
	var targeting_state: GridTargetingState = _container.get_states().targeting

	if targeting_state.get_target() == null:
		var default_target: Node2D = auto_free(Node2D.new())
		default_target.position = Vector2(64, 64)
		default_target.name = "DefaultTarget"
		add_child(default_target)
		targeting_state.set_manual_target(default_target)


func after_test() -> void:
	# Cancel any active manipulation
	if _manipulation_system:
		_manipulation_system.cancel()

	# CRITICAL: Clear indicators to prevent orphaned indicator pollution
	# Without this, indicators persist and contaminate subsequent tests in suite runs
	if _indicator_manager:
		_indicator_manager.clear()

	# Clean up any created nodes
	for child in get_children():
		if child.name == "SmithyRoot":
			child.queue_free()


#endregion

#region HELPER METHODS


## Creates a manipulatable with collision shapes for indicator generation
## CRITICAL: Collision shapes are REQUIRED for indicator generation during placement
## Follows pattern from manipulation_system_test.gd
func _create_test_manipulatable() -> Manipulatable:
	var root: Node2D = Node2D.new()
	root.name = "SmithyRoot"
	root.global_position = TEST_POSITION
	add_child(root)

	var manipulatable: Manipulatable = Manipulatable.new()
	manipulatable.name = "Manipulatable"
	manipulatable.root = root
	manipulatable.settings = manipulatable_settings_all_allowed
	root.add_child(manipulatable)

	# CRITICAL: Add collision shape for indicator generation
	# 64x64 pixels = 5x5 tiles at 16px tile size
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect_shape: RectangleShape2D = auto_free(RectangleShape2D.new())
	rect_shape.size = Vector2(64, 64)
	collision_shape.shape = rect_shape
	collision_body.add_child(collision_shape)
	root.add_child(collision_body)

	return manipulatable


## Starts manipulation (pickup) - returns true if successful
func _start_manipulation(manipulatable: Manipulatable) -> bool:
	# CRITICAL: Set targeting state BEFORE calling try_move()
	# targeting_state is the single source of truth for which object to manipulate
	var targeting_state: GridTargetingState = _container.get_states().targeting
	targeting_state.set_manual_target(manipulatable.root)

	var move_data: ManipulationData = _manipulation_system.try_move(manipulatable.root)

	if move_data == null:
		return false

	var started: bool = move_data.status == GBEnums.Status.STARTED
	_indicator_manager.force_indicators_validity_evaluation()

	return started


## Rotates the manipulation using system method (correct approach)
func _rotate_manipulation(degrees: float) -> bool:
	var move_data: ManipulationData = _manipulation_state.data

	if move_data == null or move_data.source == null:
		return false

	var success: bool = _manipulation_system.rotate(move_data.source.root, degrees)
	_indicator_manager.force_indicators_validity_evaluation()

	return success


## Formats ManipulationData for diagnostic output
func _format_manipulation_data(data: ManipulationData) -> String:
	if data == null:
		return "ManipulationData: null"

	var source_root: String = "null"
	if data.source != null and data.source.root != null:
		source_root = "%s@%s" % [data.source.root.name, str(data.source.root.global_position)]

	var move_copy_root: String = "null"
	if data.move_copy != null and data.move_copy.root != null:
		move_copy_root = (
			"%s@%s" % [data.move_copy.root.name, str(data.move_copy.root.global_position)]
		)

	return (
		"ManipulationData{status=%s, action=%s, source=%s, move_copy=%s}"
		% [
			GBEnums.Status.keys()[data.status],
			GBEnums.Action.keys()[data.action],
			source_root,
			move_copy_root
		]
	)  ## Formats ValidationResults for diagnostic output


func _format_validation_results(results: ValidationResults) -> String:
	if results == null:
		return "ValidationResults: null"

	var issues := results.get_issues()
	var errors := results.get_errors() if results.has_method("get_errors") else []

	return (
		"ValidationResults[success=%s, message='%s', issues=%d, errors=%d, details=%s]"
		% [
			str(results.is_successful()),
			results.message,
			issues.size(),
			errors.size(),
			str(issues) if not issues.is_empty() else "[]"
		]
	)


## Places the manipulated object - returns true if successful
func _place_manipulated_object() -> ValidationResults:
	var move_data: ManipulationData = _manipulation_state.data

	if move_data == null or move_data.move_copy == null:
		return null

	# Position for placement
	move_data.move_copy.root.global_position = TEST_POSITION

	# Try placement
	var placement_results: ValidationResults = _manipulation_system.try_placement(move_data)
	_indicator_manager.force_indicators_validity_evaluation()

	return placement_results


#endregion

#region REGRESSION TESTS


func test_manipulation_workflow_succeeds_after_rotation() -> void:
	## REGRESSION TEST: Verifies that rotation doesn't break manipulation workflow
	## If placement succeeds after rotation, indicator generation MUST be working correctly
	## (Placement internally uses indicators for validation)
	##
	## HISTORICAL BUG: Rotation caused indicator loss → placement failures
	## EXPECTED NOW: Placement succeeds after rotation → indicators work correctly

	# STEP 1: Create test manipulatable with collision shapes
	var manipulatable: Manipulatable = _create_test_manipulatable()

	# STEP 2: Start manipulation (pickup)
	var pickup_success: bool = _start_manipulation(manipulatable)
	var move_data: ManipulationData = _manipulation_state.data
	var targeting_state: GridTargetingState = _container.get_states().targeting
	var grid_target: Node = targeting_state.get_target()
	var grid_target_info: String = "null"
	if grid_target != null:
		grid_target_info = "%s@%s" % [grid_target.name, str(grid_target.global_position)]

	(
		assert_bool(pickup_success) \
		. append_failure_message(
			(
				"Pickup failed - Expected: true, Actual: false | %s | GridTarget: %s"
				% [_format_manipulation_data(move_data), grid_target_info]
			)
		) \
		. is_true()
	)

	# STEP 3: Rotate 90 degrees
	var rotation_success: bool = _rotate_manipulation(90.0)
	var root_rotation: float = 0.0
	if is_instance_valid(manipulatable.root):
		root_rotation = manipulatable.root.rotation_degrees

	(
		assert_bool(rotation_success) \
		. append_failure_message(
			(
				"Rotation failed - Expected: true, Actual: false, Rotation: %.1f° | %s"
				% [root_rotation, _format_manipulation_data(move_data)]
			)
		) \
		. is_true()
	)

	# STEP 4: Place the rotated object
	var placement_results: ValidationResults = _place_manipulated_object()

	(
		assert_object(placement_results) \
		. append_failure_message(
			(
				"Placement returned null - Expected: ValidationResults, Actual: null | %s | GridTarget: %s"
				% [_format_manipulation_data(move_data), grid_target_info]
			)
		) \
		. is_not_null()
	)

	if placement_results != null:
		(
			assert_bool(placement_results.is_successful()) \
			. append_failure_message(
				(
					"REGRESSION: Placement failed after rotation - Expected: success, Actual: failed | %s"
					% _format_validation_results(placement_results)
				)
			) \
			. is_true()
		)

	# STEP 5: Verify we can pick up again (proves no state corruption)
	var pickup_again_success: bool = _start_manipulation(manipulatable)
	var move_data2: ManipulationData = _manipulation_state.data

	(
		assert_bool(pickup_again_success) \
		. append_failure_message(
			(
				"Second pickup failed - Expected: true, Actual: false | %s"
				% _format_manipulation_data(move_data2)
			)
		) \
		. is_true()
	)


func test_multiple_rotations_maintain_workflow() -> void:
	## Extended test: Verify workflow stays functional through multiple rotation cycles
	## Tests 90° → 180° → 270° → 360° (full rotation)
	##
	## Each cycle: pickup → rotate → place
	## If any placement fails, indicator generation is broken at that angle

	# Create test manipulatable
	var manipulatable: Manipulatable = _create_test_manipulatable()
	var targeting_state: GridTargetingState = _container.get_states().targeting

	# Test 4 rotations (full circle)
	var rotation_angles: Array[int] = [90, 180, 270, 360]

	for angle in rotation_angles:
		# Pickup
		var pickup_success: bool = _start_manipulation(manipulatable)
		var move_data: ManipulationData = _manipulation_state.data
		var grid_target: Node = targeting_state.get_target()
		var grid_target_info: String = "null"
		if grid_target != null:
			grid_target_info = "%s@%s" % [grid_target.name, str(grid_target.global_position)]

		(
			assert_bool(pickup_success) \
			. append_failure_message(
				(
					"Pickup failed at %d° - Expected: true, Actual: false | %s | GridTarget: %s"
					% [angle, _format_manipulation_data(move_data), grid_target_info]
				)
			) \
			. is_true()
		)

		# Rotate
		var rotation_success: bool = _rotate_manipulation(90.0)
		var root_rotation: float = 0.0
		if is_instance_valid(manipulatable.root):
			root_rotation = manipulatable.root.rotation_degrees

		(
			assert_bool(rotation_success) \
			. append_failure_message(
				(
					"Rotation to %d° failed - Expected: true, Actual: false, Current: %.1f° | %s"
					% [angle, root_rotation, _format_manipulation_data(move_data)]
				)
			) \
			. is_true()
		)

		# Place - this PROVES indicators work at this rotation angle
		var placement_results: ValidationResults = _place_manipulated_object()

		(
			assert_object(placement_results) \
			. append_failure_message(
				(
					"Placement returned null at %d° - Expected: ValidationResults, Actual: null | %s | GridTarget: %s"
					% [angle, _format_manipulation_data(move_data), grid_target_info]
				)
			) \
			. is_not_null()
		)

		if placement_results != null:
			(
				assert_bool(placement_results.is_successful()) \
				. append_failure_message(
					(
						"REGRESSION at %d°: Placement failed - Expected: success, Actual: failed | %s"
						% [angle, _format_validation_results(placement_results)]
					)
				) \
				. is_true()
			)


func test_rotate_then_flip_workflow() -> void:
	## Tests combined transformations: rotation + flip
	## Ensures indicator generation works with multiple transform types

	var manipulatable: Manipulatable = _create_test_manipulatable()
	var targeting_state: GridTargetingState = _container.get_states().targeting

	# Pickup
	var pickup_success: bool = _start_manipulation(manipulatable)
	var move_data: ManipulationData = _manipulation_state.data
	var grid_target: Node = targeting_state.get_target()
	var grid_target_info: String = "null"
	if grid_target != null:
		grid_target_info = "%s@%s" % [grid_target.name, str(grid_target.global_position)]

	(
		assert_bool(pickup_success) \
		. append_failure_message(
			(
				"Pickup failed - Expected: true, Actual: false | %s | GridTarget: %s"
				% [_format_manipulation_data(move_data), grid_target_info]
			)
		) \
		. is_true()
	)

	# Rotate 45 degrees
	var rotation_success: bool = _rotate_manipulation(45.0)
	var root_rotation: float = 0.0
	if is_instance_valid(manipulatable.root):
		root_rotation = manipulatable.root.rotation_degrees

	(
		assert_bool(rotation_success) \
		. append_failure_message(
			(
				"Rotation to 45° failed - Expected: true, Actual: false, Current: %.1f° | %s"
				% [root_rotation, _format_manipulation_data(move_data)]
			)
		) \
		. is_true()
	)

	# Flip horizontal
	_manipulation_system.flip_horizontal(manipulatable.root)
	_indicator_manager.force_indicators_validity_evaluation()
	var root_scale: Vector2 = Vector2.ZERO
	if is_instance_valid(manipulatable.root):
		root_scale = manipulatable.root.scale

	# Place - should succeed with combined transforms
	var placement_results: ValidationResults = _place_manipulated_object()

	(
		assert_object(placement_results) \
		. append_failure_message(
			(
				"Placement returned null after rotation+flip - Expected: ValidationResults, Actual: null | Rotation: %.1f°, Scale: %s | %s | GridTarget: %s"
				% [
					root_rotation,
					str(root_scale),
					_format_manipulation_data(move_data),
					grid_target_info
				]
			)
		) \
		. is_not_null()
	)

	if placement_results != null:
		(
			assert_bool(placement_results.is_successful()) \
			. append_failure_message(
				(
					"Placement failed after rotation+flip - Expected: success, Actual: failed | Rotation: %.1f°, Scale: %s | %s"
					% [
						root_rotation,
						str(root_scale),
						_format_validation_results(placement_results)
					]
				)
			) \
			. is_true()
		)

#endregion

#endregion
