# GdUnit generated TestSuite
class_name ManipulationSystemTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

var system : ManipulationSystem
var manipulation_state : ManipulationState
var targeting_state : GridTargetingState
var owner_context : GBOwnerContext
var placement_validator : PlacementValidator
var positioner : Node2D
var manipulator : Node

var test_system = load("uid://wh23y2c2nv8s")

var all_manipulatable : Manipulatable
var _placement_context : PlacementContext
var _container : GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")


func before_test():
	# Setup user state
	owner_context = GBOwnerContext.new()
	manipulator = auto_free(Node.new())
	add_child(manipulator)
	owner_context.user = manipulator
	
	# Setup manipulation test system
	system = test_system.instantiate()
	var states = _container.get_states()
	manipulation_state = states.manipulation
	var manipulation_parent = auto_free(Node2D.new())
	add_child(manipulation_parent)
	manipulation_state.parent = manipulation_parent
	manipulation_state.manipulator_state = owner_context
	
	targeting_state = states.targeting
	targeting_state.target_map = auto_free(TileMapLayer.new())
	targeting_state.maps = [targeting_state.target_map]
	targeting_state.origin_state = owner_context
	
	system.state = manipulation_state
	system.targeting_state = targeting_state
	system.placement_validator = placement_validator
	system.mode_state = ModeState.new()
	add_child(system)
	
	var placement_manager = auto_free(PlacementManager.new(null, _placement_context,targeting_state))
	add_child(placement_manager)
	
	## Set targeting_state dependencies
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	targeting_state.positioner = positioner
	
	var validate_result = system.validate()
	assert_array(validate_result).append_failure_message("System must validate true for tests to pass").is_empty()
	
	all_manipulatable = create_manipulatable_object(TestSceneLibrary.manipulatable_settings_all_allowed)


@warning_ignore("unused_parameter")
func test__start_move(p_data : ManipulationData, p_expected : bool, test_parameters := [
	[create_move_data(null), true],
	[create_move_data(TestSceneLibrary.rules_2_rules_1_tile_check), true],
	[create_move_data(TestSceneLibrary.manipulatable_settings_all_allowed), true]
] ) -> void:
	var result : bool = system._start_move(p_data)
	assert_bool(result).append_failure_message("[%s] With a root and a source Manipulatable found on the root, move should start and _start_move returns true" % p_data).is_equal(p_expected)
	
	for rule in placement_validator.active_rules:
		assert_object(rule).is_instanceof(TileCheckRule)
		
	assert_vector(p_data.source.root.global_position).is_equal(p_data.target.root.global_position)


@warning_ignore("unused_parameter")
func test_move_already_moving(p_data : ManipulationData, p_expected, test_parameters := [
	[create_move_data(TestSceneLibrary.manipulatable_settings_all_allowed), true]
	]) -> void:
	var results_first_move = system._start_move(p_data)
	assert_bool(results_first_move).append_failure_message("Move should have started?").is_equal(p_expected)
	
	var result_second_move = system._start_move(p_data)
	assert_bool(result_second_move).is_equal(p_expected)

func test_cancel() -> void:
	var data = create_move_data(TestSceneLibrary.manipulatable_settings_all_allowed)
	var valid_move : bool = system._start_move(data)
	assert_bool(valid_move).is_true()
	assert_object(system.state.data).is_not_null()
	assert_object(data.source).append_failure_message("When moving, a target should be a temporary object copy of the source and NOT the same object.").is_not_same(data.target)
	assert_object(data.source.root).append_failure_message("Source and target should have different roots.").is_not_same(data.target.root)
	
	var move_data : ManipulationData = system.state.data
	move_data.target.root.global_position = Vector2i(100,-100)
	var origin = move_data.source.root.global_transform.origin
	assert_float(origin.x).append_failure_message("Source root should not have changed position.").is_equal_approx(0, 0.01)
	assert_float(origin.y).append_failure_message("Source root should not have changed position.").is_equal_approx(0, 0.01)
	 
	system.cancel()
	assert_object(system.state.data).is_null()
	assert_vector(data.source.root.global_position).is_equal(Vector2.ZERO)


@warning_ignore("unused_parameter")
func test_demolish(p_demolish_target : Manipulatable, p_expected : bool, test_parameters := [
	[create_manipulatable_object(TestSceneLibrary.manipulatable_settings_none_allowed), false], # Manipulatable that denies all test
	[all_manipulatable, true]	  # Manipulatable that allows all test
]) -> void:
	monitor_signals(manipulation_state) # Needed for assert_signal
	var result : bool = await system.demolish(p_demolish_target)
	assert_bool(result).append_failure_message("Result of demolish does not match expected boolean value").is_equal(p_expected)
	#if p_expected == false:
	#	await assert_signal(manipulation_state).append_failure_message("Expected failed signal in test_demolish in ManipulationSystemTest").wait_until(200).is_emitted(manipulation_state.failed.get_name(), [any(), any()])


@warning_ignore("unused_parameter")
func test_flip_horizontal(p_manipulatable : Manipulatable, test_parameters := [
	[all_manipulatable]
]) -> void:
	var target = p_manipulatable.root
	
	var original_scale = target.scale
	system.flip_horizontal(target)
	assert_float(target.scale.x).is_equal_approx(original_scale.x * -1, 0.01)
	assert_float(target.scale.y).is_equal_approx(original_scale.y, 0.01)
	

@warning_ignore("unused_parameter")
func test_flip_vertical(p_manipulatable : Manipulatable, test_parameters := [
	[all_manipulatable]
]) -> void:
	var target = p_manipulatable.root
	
	var original_scale = target.scale
	system.flip_vertical(target)
	assert_float(target.scale.x).is_equal_approx(original_scale.x, 0.01)
	assert_float(target.scale.y).is_equal_approx(original_scale.y * -1, 0.01)


## Tests that rotating a Node2D target successfully updates its global_rotation_degrees.
@warning_ignore("unused_parameter")
func test_rotate_node2d_target_rotates_correctly(p_manipulatable : Manipulatable, test_parameters := [
	[all_manipulatable]
]) -> void:
	var target : Node2D = p_manipulatable.root
	add_child(target)

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
func test_rotate_negative(p_manipulatable : Manipulatable, p_expected : bool, test_parameters := [
	[all_manipulatable, true]
]):
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
func test_try_placement(p_settings : ManipulatableSettings, p_expected : bool, test_parameters := [
	[TestSceneLibrary.manipulatable_settings_all_allowed, true]
]) -> void:
	var source = create_manipulatable_object(p_settings)
	var copy : Manipulatable = source.create_copy("Placement")
	add_child(copy.root)
	var copy_root = copy.root
	# Careful to duplicate the entire root and not the manipulatable component directly
	assert_object(source).append_failure_message("The [Manipulatable] components must be different between the duplicate and original").is_not_same(copy)
	assert_object(source.root).append_failure_message("Root should be different.").is_not_same(copy.root)
	
	var move_data = ManipulationData.new(manipulator, source, copy, GBEnums.Action.MOVE)
	system.state.data = move_data
	var test_location = Vector2(1000, 1000)
	
	# Move copy to new location and try placement which should move original source.root to the new location and
	# then free the copy.root from the scene
	copy.root.global_position = test_location
	var placement_results : ValidationResults = await system.try_placement(move_data)
	
	assert_bool(placement_results.is_successful).append_failure_message(placement_results.message).is_equal(p_expected)
	assert_that(copy_root).append_failure_message("Should have been freed after placement").is_null()
	assert_that(copy).append_failure_message("Copied manipulatable is null").is_null()
	assert_object(source).append_failure_message("Should still exist after placement").is_not_null()
	assert_object(source.root).append_failure_message("Should still exist after placement").is_not_null()
	assert_vector(source.root.global_position).append_failure_message("Should have moved to test location").is_equal(test_location)

@warning_ignore("unused_parameter")
func test_try_move(p_target_root : Variant, p_expected : GBEnums.Status, test_parameters := [
	[null, GBEnums.Status.FAILED],
	[auto_free(Node.new()), GBEnums.Status.FAILED],
	[auto_free(Manipulatable.new()), GBEnums.Status.FAILED],
	[all_manipulatable, GBEnums.Status.FAILED],
	[all_manipulatable.root, GBEnums.Status.STARTED]
]) -> void:
	var data : ManipulationData = system.try_move(p_target_root)
	assert_int(data.status).append_failure_message("Actual Status: %s" % str(GBEnums.Status.find_key(data.status))).is_equal(p_expected)

## Creates a root with a [Manipulatable] attached
## and returns a reference to the [Manipulatable]
func create_manipulatable_object(p_settings : ManipulatableSettings) -> Manipulatable:
	var root = auto_free(Node2D.new()) 
	root.name = "ManipulatableRoot"
	add_child(root)
	var manipulatable = auto_free(Manipulatable.new())
	manipulatable.name = "Manipulatable"
	manipulatable.root = root
	manipulatable.settings = p_settings
	root.add_child(manipulatable)
	return manipulatable

func create_move_data(p_settings : ManipulatableSettings) -> ManipulationData:
	var source_obj = create_manipulatable_object(p_settings)
	var data = ManipulationData.new(system.state.get_manipulator(), source_obj, auto_free(source_obj.duplicate()), GBEnums.Action.MOVE)
	add_child(data.target)
	return data
