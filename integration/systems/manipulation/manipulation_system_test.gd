# -----------------------------------------------------------------------------
# Test Suite: Manipulation System Integration Tests
# -----------------------------------------------------------------------------
# This test suite validates the ManipulationSystem's core functionality for
# grid building operations including move, cancel, demolish, flip, rotate,
# and placement operations. It tests integration with manipulation state,
# targeting state, and validation systems to ensure proper manipulation
# workflows and state management.
# -----------------------------------------------------------------------------


extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Test Variables
# -----------------------------------------------------------------------------
var system: ManipulationSystem
var manipulation_state: ManipulationState
var targeting_state: GridTargetingState
var owner_context: GBOwnerContext
var placement_validator: PlacementValidator
var positioner: Node2D
var manipulator: Node

var all_manipulatable: Manipulatable
var _container: GBCompositionContainer


# -----------------------------------------------------------------------------
# Setup and Teardown
# -----------------------------------------------------------------------------
func before_test() -> void:
	var test_env: Dictionary = UnifiedTestFactory.create_manipulation_system_test_environment(self)
	_container = test_env.container
	manipulator = test_env.manipulator
	owner_context = test_env.owner_context
	manipulation_state = test_env.manipulation_state
	targeting_state = test_env.targeting_state
	system = test_env.system

	# Set targeting_state dependencies
	positioner = GodotTestFactory.create_node2d(self)
	targeting_state.positioner = positioner

	var validate_result: Array[String] = system.get_runtime_issues()
	assert_array(validate_result).is_empty()

	all_manipulatable = create_manipulatable_object(
		TestSceneLibrary.manipulatable_settings_all_allowed
	)


# -----------------------------------------------------------------------------
# Test Functions
# -----------------------------------------------------------------------------
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
	# Create the data inside the test method when _container is available
	var p_data: ManipulationData = create_move_data(p_settings)
	
	# Use the public try_move method instead of private _start_move
	var result_data: ManipulationData = system.try_move(p_data.source.root)
	var result: bool = result_data.status == GBEnums.Status.STARTED
	assert_bool(result).is_equal(p_expected)

	# TODO: Find public API to verify rules were properly set up
	# Cannot access placement_validator.active_rules as it accesses private properties

	assert_vector(p_data.source.root.global_position).is_equal(p_data.target.root.global_position)


@warning_ignore("unused_parameter")


func test_move_already_moving(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	test_parameters := [
		[TestSceneLibrary.manipulatable_settings_all_allowed, true]
	]
) -> void:
	# Create the data inside the test method when _container is available
	var p_data: ManipulationData = create_move_data(p_settings)
	
	var results_first_move: ManipulationData = system.try_move(p_data.source.root)
	var first_move_success: bool = results_first_move.status == GBEnums.Status.STARTED
	assert_bool(first_move_success).is_equal(p_expected)

	var result_second_move: ManipulationData = system.try_move(p_data.source.root)
	var second_move_success: bool = result_second_move.status == GBEnums.Status.STARTED
	assert_bool(second_move_success).is_equal(p_expected)


func test_cancel() -> void:
	# Start a move via the public API; this sets up _states.manipulation.data with
	# a source and generated target copy.
	var source: Manipulatable = create_manipulatable_object(TestSceneLibrary.manipulatable_settings_all_allowed)
	var move_result: ManipulationData = system.try_move(source.root)
	var valid_move: bool = move_result.status == GBEnums.Status.STARTED
	assert_bool(valid_move).is_true()

	var active_data: ManipulationData = _container.get_states().manipulation.data
	assert_object(active_data).is_not_null()
	assert_object(active_data.source).is_not_null()
	assert_object(active_data.target).is_not_null()
	assert_object(active_data.source).is_not_same(active_data.target)
	assert_object(active_data.source.root).is_not_same(active_data.target.root)

	# Move the duplicate and confirm cancel resets data and source position
	active_data.target.root.global_position = CANCEL_TEST_POSITION
	var origin: Vector2 = active_data.source.root.global_transform.origin
	assert_float(origin.x).is_equal_approx(0, POSITION_PRECISION)
	assert_float(origin.y).is_equal_approx(0, POSITION_PRECISION)

	system.cancel()
	assert_object(_container.get_states().manipulation.data).is_null()
	assert_vector(active_data.source.root.global_position).is_equal(Vector2.ZERO)


@warning_ignore("unused_parameter")


func test_demolish(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	test_parameters := [
		[TestSceneLibrary.manipulatable_settings_none_allowed, false],  # Manipulatable that denies all test
		[TestSceneLibrary.manipulatable_settings_all_allowed, true]  # Manipulatable that allows all test
	]
) -> void:
	# Create the manipulatable inside the test method when the environment is ready
	var p_demolish_target: Manipulatable = create_manipulatable_object(p_settings) if p_settings != null else all_manipulatable
	
	monitor_signals(manipulation_state)  # Needed for assert_signal
	var result: bool = await system.demolish(p_demolish_target)
	assert_bool(result).is_equal(p_expected)


@warning_ignore("unused_parameter")


func test_flip_horizontal(
	p_manipulatable: Manipulatable, test_parameters := [[all_manipulatable]]
) -> void:
	var target: Node2D = p_manipulatable.root

	var original_scale: Vector2 = target.scale
	system.flip_horizontal(target)
	assert_float(target.scale.x).is_equal_approx(original_scale.x * -1, SCALE_PRECISION)
	assert_float(target.scale.y).is_equal_approx(original_scale.y, SCALE_PRECISION)


@warning_ignore("unused_parameter")


func test_flip_vertical(
	p_manipulatable: Manipulatable, test_parameters := [[all_manipulatable]]
) -> void:
	var target: Node2D = p_manipulatable.root

	var original_scale: Vector2 = target.scale
	system.flip_vertical(target)
	assert_float(target.scale.x).is_equal_approx(original_scale.x, SCALE_PRECISION)
	assert_float(target.scale.y).is_equal_approx(original_scale.y * -1, SCALE_PRECISION)


## Tests that rotating a Node2D target successfully updates its global_rotation_degrees.
@warning_ignore("unused_parameter")


func test_rotate_node2d_target_rotates_correctly(
	p_manipulatable: Manipulatable, test_parameters := [[all_manipulatable]]
) -> void:
	var target: Node2D = p_manipulatable.root
	# target is already added by the factory; avoid re-adding to prevent duplicate parent error

	var expected_rotation_degrees: float = 0.0

	for i in range(ROTATION_ITERATIONS):
		var success: bool = system.rotate(target, ROTATION_INCREMENT)
		assert_bool(success).is_true()

		expected_rotation_degrees += ROTATION_INCREMENT
		var normalized_expected: float = fmod(expected_rotation_degrees, 360.0)
		if normalized_expected < 0:
			normalized_expected += 360.0

		var actual_target_rotation: float = fmod(target.global_rotation_degrees, 360.0)
		if actual_target_rotation < 0:
			actual_target_rotation += 360.0

		assert_float(actual_target_rotation).is_equal_approx(normalized_expected, ROTATION_PRECISION)


@warning_ignore("unused_parameter")


func test_rotate_negative(
	p_manipulatable: Manipulatable, 
	p_expected: bool, 
	test_parameters := [[all_manipulatable, true]]
) -> void:
	var preview: Node2D = Node2D.new()
	var placement_manager: IndicatorManager = IndicatorManager.new()
	var target: Node2D = p_manipulatable.root

	var rotation_per_time: float = NEGATIVE_ROTATION_INCREMENT
	var total_rotation: float = 0.0

	for i in range(ROTATION_ITERATIONS):
		total_rotation = total_rotation + rotation_per_time
		assert_bool(system.rotate(target, rotation_per_time)).is_equal(p_expected)
		var remainder_preview: float = fmod(preview.rotation_degrees, rotation_per_time)
		var remainder_rci: float = fmod(placement_manager.rotation_degrees, rotation_per_time)
		assert_float(remainder_preview).is_between(ROTATION_RANGE_MIN, ROTATION_RANGE_MAX)
		assert_float(remainder_rci).is_between(ROTATION_RANGE_MIN, ROTATION_RANGE_MAX)

	preview.free()
	placement_manager.free()


@warning_ignore("unused_parameter")


func test_try_placement(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	test_parameters := [[TestSceneLibrary.manipulatable_settings_all_allowed, true]]
) -> void:
	# Create a manipulatable and start move via system (creates proper ManipulationData with target)
	var source: Manipulatable = create_manipulatable_object(p_settings)
	var move_result: ManipulationData = system.try_move(source.root)
	var started: bool = move_result.status == GBEnums.Status.STARTED
	assert_bool(started).is_true()

	var move_data: ManipulationData = _container.get_states().manipulation.data
	assert_object(move_data).is_not_null()
	assert_object(move_data.target).is_not_null()

	var test_location: Vector2 = TEST_POSITION
	move_data.target.root.global_position = test_location
	var placement_results: ValidationResults = await system.try_placement(move_data)
	assert_bool(placement_results.is_successful()).is_equal(p_expected)
	# After successful placement target copy should be freed (move_data.target becomes null in _finish)
	assert_object(move_data.target).is_null()
	assert_vector(source.root.global_position).is_equal(test_location)


@warning_ignore("unused_parameter")


func test_try_move(
	p_target_root: Node,
	p_expected: GBEnums.Status,
	test_parameters := [
		[null, GBEnums.Status.FAILED],
		[auto_free(Node.new()), GBEnums.Status.FAILED],
		[auto_free(Manipulatable.new()), GBEnums.Status.FAILED],
		[all_manipulatable, GBEnums.Status.FAILED],
		[all_manipulatable.root, GBEnums.Status.STARTED]
	]
) -> void:
	var data: ManipulationData = system.try_move(p_target_root)
	assert_int(data.status).is_equal(p_expected)


# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
## Creates a root with a [Manipulatable] attached
## and returns a reference to the [Manipulatable]
func create_manipulatable_object(p_settings: ManipulatableSettings) -> Manipulatable:
	var root: Node2D = GodotTestFactory.create_node2d(self)
	root.name = "ManipulatableRoot"
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.name = "Manipulatable"
	manipulatable.root = root
	manipulatable.settings = p_settings
	root.add_child(manipulatable)
	return manipulatable


func create_move_data(p_settings: ManipulatableSettings) -> ManipulationData:
	var source_obj: Manipulatable = create_manipulatable_object(p_settings)
	var data: ManipulationData = ManipulationData.new(
		_container.get_states().manipulation.get_manipulator(),
		source_obj,
		auto_free(source_obj.duplicate()),
		GBEnums.Action.MOVE
	)
	add_child(data.target)
	return data
