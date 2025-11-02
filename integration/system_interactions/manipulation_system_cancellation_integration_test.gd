## Integration Tests: ManipulationSystem Cancellation
##
## Verifies system-level behavior when cancel() is called:
## - Signals emit with valid data reference
## - Data is properly cleared post-signal
## - State transitions occur in correct order
## - No orphaned objects remain
##
## Uses AllSystemsTestEnvironment for full system integration
extends GdUnitTestSuite

#region Test Setup
var runner: GdUnitSceneRunner
var env: AllSystemsTestEnvironment
var system: ManipulationSystem
var manipulation_state: ManipulationState
var targeting_state: GridTargetingState
var manipulatable_settings: ManipulatableSettings = GBTestConstants.MANIPULATABLE_SETTINGS_ALL_ALLOWED
#endregion


func before_test() -> void:
	# Load full system environment for integration testing
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV.resource_path)
	env = runner.scene() as AllSystemsTestEnvironment
	
	var container: GBCompositionContainer = env.get_container()
	system = env.manipulation_system
	manipulation_state = container.get_manipulation_state()
	targeting_state = container.get_states().targeting
	
	# Set up default target for targeting state
	var default_target: Node2D = auto_free(Node2D.new())
	default_target.position = Vector2(64, 64)
	default_target.name = "CancelTestTarget"
	add_child(default_target)
	targeting_state.set_manual_target(default_target)


func after_test() -> void:
	# All nodes cleaned up by auto_free()
	pass


## Helper: Creates a test manipulatable with proper configuration
func _create_test_manipulatable() -> Manipulatable:
	var root: Node2D = auto_free(Node2D.new())
	add_child(root)
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = root
	manipulatable.settings = manipulatable_settings
	root.add_child(manipulatable)
	return manipulatable


## Test: Cancel with active manipulation emits signal with valid data
func test_cancel_emits_signal_with_valid_data() -> void:
	# Create and activate manipulation
	var target: Manipulatable = _create_test_manipulatable()
	manipulation_state.active_manipulatable = target
	
	# Start move manipulation
	var move_data: ManipulationData = system.try_move(target)
	
	# Verify manipulation active
	assert_object(manipulation_state.data) \
		.append_failure_message("Should have active manipulation data") \
		.is_equal(move_data)
	
	# Cancel manipulation (should emit signal and change status)
	system.cancel()
	
	# Verify status changed to CANCELED (proves signal was emitted)
	assert_int(move_data.status) \
		.append_failure_message("Status should change to CANCELED via signal") \
		.is_equal(GBEnums.Status.CANCELED)
	
	# Verify data cleared after signal
	assert_object(manipulation_state.data) \
		.append_failure_message("Data should be cleared after signal") \
		.is_null()


## Test: Cancel clears data reference after signal emission
func test_cancel_clears_data_after_signal() -> void:
	# Create and activate manipulation
	var target: Manipulatable = _create_test_manipulatable()
	manipulation_state.active_manipulatable = target
	var _move_data: ManipulationData = system.try_move(target)
	
	# Verify manipulation active
	assert_object(manipulation_state.data) \
		.append_failure_message("Should have active manipulation") \
		.is_not_null()
	
	# Cancel manipulation
	system.cancel()
	
	# Verify data is cleared
	assert_object(manipulation_state.data) \
		.append_failure_message("Data should be cleared after cancel") \
		.is_null()


## Test: Cancel stops processing loop
func test_cancel_stops_processing() -> void:
	# Create and activate manipulation
	var target: Manipulatable = _create_test_manipulatable()
	manipulation_state.active_manipulatable = target
	var _move_data: ManipulationData = system.try_move(target)
	
	# Verify processing active
	assert_bool(system.is_processing()) \
		.append_failure_message("Should be processing during manipulation") \
		.is_true()
	
	# Cancel manipulation
	system.cancel()
	
	# Verify processing stopped
	assert_bool(system.is_processing()) \
		.append_failure_message("Should stop processing after cancel") \
		.is_false()


## Test: Cancel without active manipulation is safe
func test_cancel_without_active_manipulation_is_safe() -> void:
	# Verify no active manipulation
	assert_object(manipulation_state.data) \
		.append_failure_message("Should start without manipulation") \
		.is_null()
	
	# Cancel without manipulation (should not crash)
	system.cancel()
	
	# Verify state remains clean
	assert_object(manipulation_state.data) \
		.append_failure_message("Should remain null") \
		.is_null()


## Test: Multiple cancellations are safe
func test_multiple_cancellations_are_safe() -> void:
	# Create, activate, and cancel manipulation
	var target: Manipulatable = _create_test_manipulatable()
	manipulation_state.active_manipulatable = target
	var _move_data: ManipulationData = system.try_move(target)
	system.cancel()
	
	# Verify cancelled
	assert_object(manipulation_state.data) \
		.append_failure_message("Should be cancelled") \
		.is_null()
	
	# Cancel again (should be safe)
	system.cancel()
	
	# Verify still clean
	assert_object(manipulation_state.data) \
		.append_failure_message("Should remain null after double cancel") \
		.is_null()
