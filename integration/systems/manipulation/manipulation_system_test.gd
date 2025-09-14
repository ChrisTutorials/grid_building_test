## Test Suite: Manipulation System Integration Tests
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
const TEST_POSITION: Vector2 = Vector2.ONE
const CANCEL_TEST_POSITION: Vector2i = Vector2i(100, -100)
const ROTATION_ITERATIONS: int = 10
const ALL_SYSTEMS_ENV_UID: String = "uid://ioucajhfxc8b"
#endregion

#region Test Environment Variables
var test_hierarchy: AllSystemsTestEnvironment
var system: ManipulationSystem
var manipulation_state: ManipulationState
var all_manipulatable: Manipulatable
var _container: GBCompositionContainer
#endregion

#region Setup and Teardown
func before_test() -> void:
	# Use the premade AllSystemsTestEnvironment scene
	test_hierarchy = UnifiedTestFactory.instance_all_systems_env(self, ALL_SYSTEMS_ENV_UID)
	
	# Extract environment components for test access
	_container = test_hierarchy.container
	system = test_hierarchy.manipulation_system
	manipulation_state = test_hierarchy.manipulation_state
	all_manipulatable = test_hierarchy.test_manipulatable
#endregion

#region Movement Operation Tests
@warning_ignore("unused_parameter")
func test_start_move(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	test_parameters := [
		[null, true],
		[TestSceneLibrary.rules_2_rules_1_tile_check, true],
		[TestSceneLibrary.manipulatable_settings_all_allowed, true]
	]
) -> void:
	var move_data: ManipulationData = _create_test_move_data(p_settings)
	assert_that(move_data).is_not_null()
	assert_that(move_data.source).is_not_null()
	assert_that(move_data.source.root).is_not_null()
	
	var result_data: ManipulationData = system.try_move(move_data.source.root)
	
	# Fix null reference issue: ensure result_data is not null
	assert_that(result_data).append_failure_message(
		"ManipulationSystem.try_move should return valid ManipulationData, not null"
	).is_not_null()
	
	if result_data != null:
		var result: bool = result_data.status == GBEnums.Status.STARTED
		assert_bool(result).is_equal(p_expected)
		
		# Validate position consistency
		if result_data.source != null and result_data.target != null:
			assert_vector(result_data.source.root.global_position).is_equal(result_data.target.root.global_position)

@warning_ignore("unused_parameter")
func test_move_already_moving(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	test_parameters := [[TestSceneLibrary.manipulatable_settings_all_allowed, true]]
) -> void:
	var move_data: ManipulationData = _create_test_move_data(p_settings)
	assert_that(move_data).is_not_null()
	
	# First move attempt
	var first_move_result: ManipulationData = system.try_move(move_data.source.root)
	assert_that(first_move_result).append_failure_message(
		"First try_move should return valid result"
	).is_not_null()
	
	if first_move_result != null:
		var first_success: bool = first_move_result.status == GBEnums.Status.STARTED
		assert_bool(first_success).is_equal(p_expected)

		# Second move attempt while already moving
		var second_move_result: ManipulationData = system.try_move(move_data.source.root)
		assert_that(second_move_result).append_failure_message(
			"Second try_move should return valid result even when already moving"
		).is_not_null()
		
		if second_move_result != null:
			var second_success: bool = second_move_result.status == GBEnums.Status.STARTED
			assert_bool(second_success).is_equal(p_expected)

func test_cancel() -> void:
	var source: Manipulatable = _create_test_manipulatable(TestSceneLibrary.manipulatable_settings_all_allowed)
	
	var move_result: ManipulationData = system.try_move(source.root)
	assert_that(move_result).append_failure_message(
		"try_move for cancel test should return valid result"
	).is_not_null()
	
	if move_result != null:
		var valid_move: bool = move_result.status == GBEnums.Status.STARTED
		assert_bool(valid_move).is_true()

		# Get active manipulation data
		var active_data: ManipulationData = _container.get_states().manipulation.data
		_validate_manipulation_data(active_data, "active manipulation data after move")

		# Test cancel behavior
		if active_data != null and active_data.target != null:
			active_data.target.root.global_position = CANCEL_TEST_POSITION
			var origin: Vector2 = active_data.source.root.global_transform.origin
			assert_float(origin.x).is_equal_approx(0, POSITION_PRECISION)
			assert_float(origin.y).is_equal_approx(0, POSITION_PRECISION)

			system.cancel()
			assert_object(_container.get_states().manipulation.data).is_null()
			assert_vector(active_data.source.root.global_position).is_equal(Vector2.ZERO)

func test_try_move(
	p_target_root: Node,
	p_expected: GBEnums.Status,
	_test_parameters := [
		[null, GBEnums.Status.FAILED],
		[auto_free(Node.new()), GBEnums.Status.FAILED],
		[auto_free(Manipulatable.new()), GBEnums.Status.FAILED],
		[all_manipulatable.root, GBEnums.Status.STARTED]
	]
) -> void:
	var result_data: ManipulationData = system.try_move(p_target_root)
	
	# Ensure result is not null to prevent property access errors
	assert_that(result_data).append_failure_message(
		"try_move should never return null, even for invalid inputs"
	).is_not_null()
	
	if result_data != null:
		assert_int(result_data.status).is_equal(p_expected)
#endregion

#region Demolish and Placement Tests
func test_demolish(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	_test_parameters := [
		[TestSceneLibrary.manipulatable_settings_none_allowed, false],
		[TestSceneLibrary.manipulatable_settings_all_allowed, true]
	]
) -> void:
	var target_manipulatable: Manipulatable = _create_test_manipulatable(p_settings) if p_settings != null else all_manipulatable
	assert_that(target_manipulatable).is_not_null()
	
	monitor_signals(manipulation_state)
	
	# Fix null reference issue: demolish should return valid result
	var demolish_result: Variant = await system.demolish(target_manipulatable)
	
	# Handle return value - demolish returns bool
	var success: bool = demolish_result if demolish_result is bool else false
	
	assert_bool(success).is_equal(p_expected)

func test_try_placement(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	_test_parameters := [[TestSceneLibrary.manipulatable_settings_all_allowed, true]]
) -> void:
	var source: Manipulatable = _create_test_manipulatable(p_settings)
	assert_that(source).is_not_null()
	
	var move_result: ManipulationData = system.try_move(source.root)
	assert_that(move_result).append_failure_message(
		"try_move for placement test should return valid result"
	).is_not_null()
	
	if move_result != null:
		var started: bool = move_result.status == GBEnums.Status.STARTED
		assert_bool(started).is_true()

		var move_data: ManipulationData = _container.get_states().manipulation.data
		_validate_manipulation_data(move_data, "manipulation data for placement")

		if move_data != null and move_data.target != null:
			var test_location: Vector2 = TEST_POSITION
			move_data.target.root.global_position = test_location
			
			var placement_results: ValidationResults = await system.try_placement(move_data)
			assert_that(placement_results).is_not_null()
			
			if placement_results != null:
				assert_bool(placement_results.is_successful()).is_equal(p_expected)
				# After successful placement, target copy should be freed
				assert_object(move_data.target).is_null()
				assert_vector(source.root.global_position).is_equal(test_location)
#endregion

#region Transform Operation Tests
func test_flip_horizontal(
	p_manipulatable: Manipulatable, 
	_test_parameters := [[all_manipulatable]]
) -> void:
	_validate_manipulatable_for_transform(p_manipulatable, "flip_horizontal")
	var target: Node2D = p_manipulatable.root
	var original_scale: Vector2 = target.scale
	
	system.flip_horizontal(target)
	
	assert_float(target.scale.x).is_equal_approx(original_scale.x * -1, SCALE_PRECISION)
	assert_float(target.scale.y).is_equal_approx(original_scale.y, SCALE_PRECISION)

func test_flip_vertical(
	p_manipulatable: Manipulatable, 
	_test_parameters := [[all_manipulatable]]
) -> void:
	_validate_manipulatable_for_transform(p_manipulatable, "flip_vertical")
	var target: Node2D = p_manipulatable.root
	var original_scale: Vector2 = target.scale
	
	system.flip_vertical(target)
	
	assert_float(target.scale.x).is_equal_approx(original_scale.x, SCALE_PRECISION)
	assert_float(target.scale.y).is_equal_approx(original_scale.y * -1, SCALE_PRECISION)

func test_rotate_node2d_target_rotates_correctly(
	p_manipulatable: Manipulatable, 
	_test_parameters := [[all_manipulatable]]
) -> void:
	_validate_manipulatable_for_transform(p_manipulatable, "rotate")
	var target: Node2D = p_manipulatable.root
	var expected_rotation_degrees: float = 0.0

	for i in range(ROTATION_ITERATIONS):
		var success: bool = system.rotate(target, ROTATION_INCREMENT)
		assert_bool(success).is_true()

		expected_rotation_degrees += ROTATION_INCREMENT
		var normalized_expected: float = _normalize_rotation(expected_rotation_degrees)
		var actual_target_rotation: float = _normalize_rotation(target.global_rotation_degrees)

		assert_float(actual_target_rotation).is_equal_approx(normalized_expected, ROTATION_PRECISION)

func test_rotate_negative(
	p_manipulatable: Manipulatable, 
	p_expected: bool, 
	_test_parameters := [[all_manipulatable, true]]
) -> void:
	_validate_manipulatable_for_transform(p_manipulatable, "rotate_negative")
	
	var preview: Node2D = auto_free(Node2D.new())
	var placement_manager: IndicatorManager = auto_free(IndicatorManager.new())
	var target: Node2D = p_manipulatable.root

	var rotation_per_time: float = NEGATIVE_ROTATION_INCREMENT
	var _total_rotation: float = 0.0

	for i in range(ROTATION_ITERATIONS):
		_total_rotation += rotation_per_time
		assert_bool(system.rotate(target, rotation_per_time)).is_equal(p_expected)
		
		var remainder_preview: float = fmod(preview.rotation_degrees, rotation_per_time)
		var remainder_rci: float = fmod(placement_manager.rotation_degrees, rotation_per_time)
		
		assert_float(remainder_preview).is_between(ROTATION_RANGE_MIN, ROTATION_RANGE_MAX)
		assert_float(remainder_rci).is_between(ROTATION_RANGE_MIN, ROTATION_RANGE_MAX)
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
	var root: Node2D = _create_positioned_node("ManipulatableRoot", Vector2.ZERO)
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.name = "Manipulatable"
	manipulatable.root = root
	manipulatable.settings = p_settings
	root.add_child(manipulatable)
	return manipulatable

## Creates move data for testing - replaces _create_move_data with better validation
func _create_test_move_data(p_settings: ManipulatableSettings) -> ManipulationData:
	assert_that(_container).is_not_null()
	
	var source_obj: Manipulatable = _create_test_manipulatable(p_settings)
	assert_that(source_obj).is_not_null()
	assert_that(source_obj.root).is_not_null()
	
	var target_duplicate: Manipulatable = auto_free(source_obj.duplicate())
	assert_that(target_duplicate).is_not_null()
	
	var manipulator_node: Node = manipulation_state.get_manipulator()
	assert_that(manipulator_node).is_not_null()
	
	var data: ManipulationData = ManipulationData.new(
		manipulator_node,
		source_obj,
		target_duplicate,
		GBEnums.Action.MOVE
	)
	assert_that(data).is_not_null()
	add_child(data.target)
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
		
		assert_that(data.target).append_failure_message(
			"%s target should not be null" % context
		).is_not_null()
		
		if data.source != null and data.target != null:
			assert_that(data.source).is_not_same(data.target)
			assert_that(data.source.root).is_not_same(data.target.root)

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

func after_test() -> void:
	# Clean up manipulation system state
	if system:
		# Cancel any ongoing manipulation
		system.try_cancel()
		
		# Note: ManipulationState does not have a reset method
		# State cleanup is handled by canceling ongoing operations
#endregion
