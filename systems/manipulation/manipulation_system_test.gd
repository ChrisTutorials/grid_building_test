# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# TestSuite generated from

var system: ManipulationSystem
var manipulation_state: ManipulationState
var targeting_state: GridTargetingState
var owner_context: GBOwnerContext
var placement_validator: PlacementValidator
var positioner: Node2D
var manipulator: Node

var all_manipulatable: Manipulatable
var _container: GBCompositionContainer


func before_test():
	_container = load("uid://dy6e5p5d6ax6n").duplicate(true)
	# Use GodotTestFactory for all node creation
	manipulator = GodotTestFactory.create_node(self)

	# Create a GBOwner and set it up properly
	var gb_owner = GBOwner.new(manipulator)
	gb_owner = auto_free(gb_owner)

	# Connect the owner to the container's context
	owner_context = _container.get_contexts().owner
	owner_context.set_owner(gb_owner)

	# Setup manipulation test system using static factory methods
	var states = _container.get_states()
	manipulation_state = states.manipulation
	var manipulation_parent = GodotTestFactory.create_node2d(self)
	manipulation_state.parent = manipulation_parent

	targeting_state = states.targeting
	targeting_state.target_map = GodotTestFactory.create_empty_tile_map_layer(self)
	targeting_state.maps = [targeting_state.target_map]

	# PlacementManager: instantiate and inject dependencies
	var placement_manager: PlacementManager = PlacementManager.new()
	placement_manager.resolve_gb_dependencies(_container)
	add_child(placement_manager)
	_container.get_contexts().placement.set_manager(placement_manager)

	system = auto_free(ManipulationSystem.create_with_injection(_container))
	add_child(system)

	# Set targeting_state dependencies
	positioner = GodotTestFactory.create_node2d(self)
	targeting_state.positioner = positioner

	var validate_result = system.get_dependency_issues()
	assert_array(validate_result).is_empty()

	all_manipulatable = create_manipulatable_object(
		TestSceneLibrary.manipulatable_settings_all_allowed
	)


@warning_ignore("unused_parameter")


func test_start_move(
	p_data: ManipulationData,
	p_expected: bool,
	test_parameters := [
		[create_move_data(null), true],
		[create_move_data(TestSceneLibrary.rules_2_rules_1_tile_check), true],
		[create_move_data(TestSceneLibrary.manipulatable_settings_all_allowed), true]
	]
) -> void:
	# Use the public try_move method instead of private _start_move
	var result_data = system.try_move(p_data.source.root)
	var result: bool = result_data.status == GBEnums.Status.STARTED
	assert_bool(result).is_equal(p_expected)

	# TODO: Find public API to verify rules were properly set up
	# Cannot access placement_validator.active_rules as it accesses private properties

	assert_vector(p_data.source.root.global_position).is_equal(p_data.target.root.global_position)


@warning_ignore("unused_parameter")


func test_move_already_moving(
	p_data: ManipulationData,
	p_expected,
	test_parameters := [
		[create_move_data(TestSceneLibrary.manipulatable_settings_all_allowed), true]
	]
) -> void:
	var results_first_move = system.try_move(p_data.source.root)
	var first_move_success: bool = results_first_move.status == GBEnums.Status.STARTED
	assert_bool(first_move_success).is_equal(p_expected)

	var result_second_move = system.try_move(p_data.source.root)
	var second_move_success: bool = result_second_move.status == GBEnums.Status.STARTED
	assert_bool(second_move_success).is_equal(p_expected)


func test_cancel() -> void:
	# Start a move via the public API; this sets up _states.manipulation.data with
	# a source and generated target copy.
	var source = create_manipulatable_object(TestSceneLibrary.manipulatable_settings_all_allowed)
	var move_result = system.try_move(source.root)
	var valid_move: bool = move_result.status == GBEnums.Status.STARTED
	assert_bool(valid_move).is_true()

	var active_data: ManipulationData = _container.get_states().manipulation.data
	assert_object(active_data).is_not_null()
	assert_object(active_data.source).is_not_null()
	assert_object(active_data.target).is_not_null()
	assert_object(active_data.source).is_not_same(active_data.target)
	assert_object(active_data.source.root).is_not_same(active_data.target.root)

	# Move the duplicate and confirm cancel resets data and source position
	active_data.target.root.global_position = Vector2i(100, -100)
	var origin = active_data.source.root.global_transform.origin
	assert_float(origin.x).is_equal_approx(0, 0.01)
	assert_float(origin.y).is_equal_approx(0, 0.01)

	system.cancel()
	assert_object(_container.get_states().manipulation.data).is_null()
	assert_vector(active_data.source.root.global_position).is_equal(Vector2.ZERO)


@warning_ignore("unused_parameter")


func test_demolish(
	p_demolish_target: Manipulatable,
	p_expected: bool,
	test_parameters := [
		[create_manipulatable_object(TestSceneLibrary.manipulatable_settings_none_allowed), false],  # Manipulatable that denies all test
		[all_manipulatable, true]  # Manipulatable that allows all test
	]
) -> void:
	monitor_signals(manipulation_state)  # Needed for assert_signal
	var result: bool = await system.demolish(p_demolish_target)
	assert_bool(result).is_equal(p_expected)


@warning_ignore("unused_parameter")


func test_flip_horizontal(
	p_manipulatable: Manipulatable, test_parameters := [[all_manipulatable]]
) -> void:
	var target = p_manipulatable.root

	var original_scale = target.scale
	system.flip_horizontal(target)
	assert_float(target.scale.x).is_equal_approx(original_scale.x * -1, 0.01)
	assert_float(target.scale.y).is_equal_approx(original_scale.y, 0.01)


@warning_ignore("unused_parameter")


func test_flip_vertical(
	p_manipulatable: Manipulatable, test_parameters := [[all_manipulatable]]
) -> void:
	var target = p_manipulatable.root

	var original_scale = target.scale
	system.flip_vertical(target)
	assert_float(target.scale.x).is_equal_approx(original_scale.x, 0.01)
	assert_float(target.scale.y).is_equal_approx(original_scale.y * -1, 0.01)


## Tests that rotating a Node2D target successfully updates its global_rotation_degrees.
@warning_ignore("unused_parameter")


func test_rotate_node2d_target_rotates_correctly(
	p_manipulatable: Manipulatable, test_parameters := [[all_manipulatable]]
) -> void:
	var target: Node2D = p_manipulatable.root
	# target is already added by the factory; avoid re-adding to prevent duplicate parent error

	var rotation_increment = 45.0
	var expected_rotation_degrees = 0.0
	var precision = 0.0001

	for i in range(0, 10, 1):
		var success = system.rotate(target, rotation_increment)
		assert_bool(success).is_true()

		expected_rotation_degrees += rotation_increment
		var normalized_expected = fmod(expected_rotation_degrees, 360.0)
		if normalized_expected < 0:
			normalized_expected += 360.0

		var actual_target_rotation = fmod(target.global_rotation_degrees, 360.0)
		if actual_target_rotation < 0:
			actual_target_rotation += 360.0

		assert_float(actual_target_rotation).is_equal_approx(normalized_expected, precision)


@warning_ignore("unused_parameter")


func test_rotate_negative(
	p_manipulatable: Manipulatable, 
	p_expected: bool, 
	test_parameters := [[all_manipulatable, true]]
):
	var preview = Node2D.new()
	var placement_manager = PlacementManager.new()
	var target = p_manipulatable.root

	var rotation_per_time = -33.3333
	var total_rotation = 0.0

	for i in range(0, 10, 1):
		total_rotation = total_rotation + rotation_per_time
		assert_bool(system.rotate(target, rotation_per_time)).is_equal(p_expected)
		var remainder_preview = fmod(preview.rotation_degrees, rotation_per_time)
		var remainder_rci = fmod(placement_manager.rotation_degrees, rotation_per_time)
		assert_float(remainder_preview).is_between(-360.0, 360.0)
		assert_float(remainder_rci).is_between(-360.0, 360.0)

	preview.free()
	placement_manager.free()


@warning_ignore("unused_parameter")


func test_try_placement(
	p_settings: ManipulatableSettings,
	p_expected: bool,
	test_parameters := [[TestSceneLibrary.manipulatable_settings_all_allowed, true]]
) -> void:
	# Create a manipulatable and start move via system (creates proper ManipulationData with target)
	var source = create_manipulatable_object(p_settings)
	var move_result = system.try_move(source.root)
	var started: bool = move_result.status == GBEnums.Status.STARTED
	assert_bool(started).is_true()

	var move_data: ManipulationData = _container.get_states().manipulation.data
	assert_object(move_data).is_not_null()
	assert_object(move_data.target).is_not_null()

	var test_location = Vector2(1000, 1000)
	move_data.target.root.global_position = test_location
	var placement_results: ValidationResults = await system.try_placement(move_data)
	assert_bool(placement_results.is_successful).is_equal(p_expected)
	# After successful placement target copy should be freed (move_data.target becomes null in _finish)
	assert_object(move_data.target).is_null()
	assert_vector(source.root.global_position).is_equal(test_location)


@warning_ignore("unused_parameter")


func test_try_move(
	p_target_root: Variant,
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


## Creates a root with a [Manipulatable] attached
## and returns a reference to the [Manipulatable]
func create_manipulatable_object(p_settings: ManipulatableSettings) -> Manipulatable:
	var root = GodotTestFactory.create_node2d(self)
	root.name = "ManipulatableRoot"
	var manipulatable = auto_free(Manipulatable.new())
	manipulatable.name = "Manipulatable"
	manipulatable.root = root
	manipulatable.settings = p_settings
	root.add_child(manipulatable)
	return manipulatable


func create_move_data(p_settings: ManipulatableSettings) -> ManipulationData:
	var source_obj = create_manipulatable_object(p_settings)
	var data = ManipulationData.new(
		_container.get_states().manipulation.get_manipulator(),
		source_obj,
		auto_free(source_obj.duplicate()),
		GBEnums.Action.MOVE
	)
	add_child(data.target)
	return data
