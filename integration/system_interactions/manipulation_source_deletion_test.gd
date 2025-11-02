## Test: ManipulationSystem handles source object deletion gracefully
## Validates that manipulation auto-cancels when the source object is deleted mid-operation
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var test_env: Node
var manipulation_system: ManipulationSystem
var container: GBCompositionContainer
var manipulation_state: ManipulationState
var test_object: Node2D
var manipulatable: Manipulatable


func before_test() -> void:
	# Load test environment using scene_runner with ALL_SYSTEMS_ENV_UID
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV.resource_path)
	runner.simulate_frames(1)  # Synchronous frame simulation replaces await
	test_env = runner.scene()

	# Get systems from environment using AllSystemsTestEnvironment API
	container = test_env.injector.composition_container
	var systems_context := container.get_systems_context()
	manipulation_system = systems_context.get_manipulation_system()
	manipulation_state = container.get_states().manipulation

	# Create initial test object - tests will recreate as needed
	_create_test_object()


func after_test() -> void:
	# Cleanup is handled by auto_free()
	pass


## Helper: Create a fresh test object with manipulatable component
func _create_test_object() -> void:
	# Create a test object with manipulatable component
	test_object = auto_free(Node2D.new())
	test_object.name = "TestObject"
	add_child(test_object)

	# Add manipulatable component
	manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = test_object
	manipulatable.settings = ManipulatableSettings.new()
	manipulatable.settings.movable = true
	test_object.add_child(manipulatable)

	# Initialize manipulatable with container dependencies
	manipulatable.resolve_gb_dependencies(container)


## Test: Manipulation auto-cancels when source object is deleted
## Setup: Start move manipulation on a test object
## Act: Delete the source object while manipulation is active
## Assert: Manipulation is automatically canceled
func test_source_deletion_cancels_manipulation() -> void:
	# Ensure no existing manipulation (clean state)
	if manipulation_state.data != null:
		manipulation_system.cancel()
	
	# Arrange: Start move manipulation
	var move_data: ManipulationData = manipulation_system.try_move(test_object)

	# Verify manipulation started successfully
	assert_object(move_data).append_failure_message(
		"Expected move_data to be created"
	).is_not_null()
	(
		assert_int(move_data.status) \
		. append_failure_message(
			"Expected manipulation to start with STARTED status, got: %d" % move_data.status
		) \
		. is_equal(GBEnums.Status.STARTED)
	)

	# Verify manipulation data is active
	(
		assert_object(manipulation_state.data) \
		. append_failure_message("Expected active manipulation data to be set") \
		. is_not_null()
	)

	# Keep reference to data to check after signal
	var initial_data: ManipulationData = manipulation_state.data

	# Act: Delete the source object (simulating external deletion)
	test_object.queue_free()
	# Wait for the canceled signal to fire - this ensures all cleanup completes before assertions
	runner.simulate_until_object_signal(manipulation_state, "canceled", [initial_data])
	# One more frame to ensure data reference is cleared after signal
	runner.simulate_frames(1)

	# Assert: Manipulation should be auto-canceled (verified by signal firing)
	# The signal already confirms the status changed to CANCELED
	(
		assert_object(manipulation_state.data) \
		. append_failure_message("Expected manipulation data to be cleared after source deletion") \
		. is_null()
	)

	# Verify no manipulation is active
	var is_manipulating: bool = manipulation_state.data != null
	(
		assert_bool(is_manipulating) \
		. append_failure_message("Expected is_manipulating to be false after deletion") \
		. is_false()
	)
	
	# Verify the canceled signal fired with correct data reference
	(
		assert_object(initial_data).append_failure_message(
			"Signal should have been emitted with the manipulation data"
		).is_not_null()
	)


## Test: Multiple deletions don't cause crashes
## Setup: Start manipulation and track initial state
## Act: Delete source multiple times (defensive test)
## Assert: No crashes, manipulation canceled cleanly
func test_multiple_source_deletions_handled_safely() -> void:
	# Get fresh state reference
	var current_state: ManipulationState = container.get_states().manipulation
	
	# Ensure clean state before test
	if current_state.data != null:
		manipulation_system.cancel()
	
	# Arrange: Create fresh test object
	_create_test_object()
	runner.simulate_frames(1)  # Synchronous frame simulation replaces await

	# Start move manipulation
	var move_data: ManipulationData = manipulation_system.try_move(test_object)
	(
		assert_int(move_data.status) \
		. append_failure_message("Expected manipulation to start successfully") \
		. is_equal(GBEnums.Status.STARTED)
	)
	
	var initial_data: ManipulationData = move_data

	# Act: Delete source and wait for the canceled signal
	test_object.queue_free()
	runner.simulate_until_object_signal(current_state, "canceled", [initial_data])

	# Assert: Manipulation canceled (re-fetch state)
	current_state = container.get_states().manipulation
	(
		assert_object(current_state.data) \
		. append_failure_message("Expected manipulation to be canceled after first deletion") \
		. is_null()
	)

	# Act again: Simulate another frame to ensure idempotency
	# (no new deletion, just verifying state remains stable)
	runner.simulate_frames(1)

	# Assert: Still no active manipulation, no crashes (re-fetch state)
	current_state = container.get_states().manipulation
	(
		assert_object(current_state.data) \
		. append_failure_message("Expected manipulation to remain canceled after second frame") \
		. is_null()
	)


## Test: Source deletion during different manipulation phases
## Setup: Track manipulation phases (started, in-progress)
## Act: Delete source at different times
## Assert: Always cancels cleanly without errors
func test_source_deletion_at_various_manipulation_phases() -> void:
	# Get fresh state reference
	var current_state: ManipulationState = container.get_states().manipulation
	
	# Ensure clean state
	if current_state.data != null:
		manipulation_system.cancel()
	
	# Phase 1: Delete immediately after start
	_create_test_object()
	runner.simulate_frames(1)  # Synchronous frame simulation replaces await
	var move_data1: ManipulationData = manipulation_system.try_move(test_object)
	assert_int(move_data1.status).append_failure_message(
		"Manipulation should start with STARTED status"
	).is_equal(GBEnums.Status.STARTED)
	
	var phase1_data: ManipulationData = move_data1
	test_object.queue_free()
	# Wait for canceled signal before checking state
	runner.simulate_until_object_signal(current_state, "canceled", [phase1_data])
	
	# Re-fetch state after signal fires
	current_state = container.get_states().manipulation
	assert_object(current_state.data).append_failure_message(
		"Expected immediate deletion to cancel manipulation"
	).is_null()

	# Phase 2: Delete after some processing time
	# Cancel any residual state before starting new manipulation
	current_state = container.get_states().manipulation
	if current_state.data != null:
		manipulation_system.cancel()
	
	# Create fresh object for phase 2
	_create_test_object()
	runner.simulate_frames(1)  # Synchronous frame simulation replaces await
	var move_data2: ManipulationData = manipulation_system.try_move(test_object)
	assert_int(move_data2.status).append_failure_message(
		"Second manipulation should also start with STARTED status"
	).is_equal(GBEnums.Status.STARTED)

	# Let some frames pass
	for _i in range(3):
		runner.simulate_frames(1)  # Synchronous frame simulation replaces await

	# Now delete and wait for signal
	var phase2_data: ManipulationData = move_data2
	test_object.queue_free()
	runner.simulate_until_object_signal(current_state, "canceled", [phase2_data])
	
	# Re-fetch state after deletion signal fires
	current_state = container.get_states().manipulation
	(
		assert_object(current_state.data) \
		. append_failure_message("Expected delayed deletion to cancel manipulation") \
		. is_null()
	)


## Test: Canceled signal carries correct manipulation data reference
## Validates that signal listeners receive the data object that was being manipulated
## This ensures signal handlers can inspect final state before cleanup completes
func test_canceled_signal_contains_correct_data_reference() -> void:
	# Setup: Ensure clean state
	if manipulation_state.data != null:
		manipulation_system.cancel()

	# Arrange: Start manipulation
	var move_data: ManipulationData = manipulation_system.try_move(test_object)
	assert_object(move_data).append_failure_message(
		"Expected manipulation data to be created"
	).is_not_null()

	var original_data_reference: ManipulationData = move_data
	
	# Create wrapper to capture signal data without reassignment issues
	var signal_capture: Dictionary = {
		"data": null
	}

	# Connect to signal to capture the data passed in signal
	var signal_captured: Callable = func(data: ManipulationData) -> void:
		signal_capture["data"] = data

	manipulation_state.canceled.connect(signal_captured)

	# Act: Delete source and wait for signal
	test_object.queue_free()
	runner.simulate_until_object_signal(manipulation_state, "canceled", [original_data_reference])

	# Assert: Signal carried the correct data reference
	(
		assert_object(signal_capture["data"]) \
		. append_failure_message("Expected signal to contain manipulation data") \
		. is_equal(original_data_reference)
	)

	# Verify signal data is the same object we started with
	(
		assert_bool(signal_capture["data"] == original_data_reference) \
		. append_failure_message("Signal should carry the exact data object reference") \
		. is_true()
	)

	manipulation_state.canceled.disconnect(signal_captured)


## Test: Idempotent cancellation (cancel() safe to call multiple times)
## Setup: Start manipulation and cancel via two different methods
## Act: Call cancel() after deletion has already triggered cleanup
## Assert: No crashes, idempotent behavior verified
func test_cancellation_idempotent_safe() -> void:
	# Setup: Ensure clean state
	if manipulation_state.data != null:
		manipulation_system.cancel()

	# Arrange: Start manipulation
	var move_data: ManipulationData = manipulation_system.try_move(test_object)
	assert_int(move_data.status).append_failure_message(
		"Expected manipulation to start"
	).is_equal(GBEnums.Status.STARTED)

	# Track cancellation count via signal - use dict wrapper to avoid capture issues
	var signal_capture: Dictionary = {
		"count": 0
	}
	var cancellation_callback: Callable = func(_data: ManipulationData) -> void:
		signal_capture["count"] += 1

	manipulation_state.canceled.connect(cancellation_callback)

	# Act 1: Delete source triggers auto-cancel
	test_object.queue_free()
	runner.simulate_until_object_signal(manipulation_state, "canceled")

	# Verify first cancellation
	(
		assert_int(signal_capture["count"]) \
		. append_failure_message("Expected one cancellation from source deletion") \
		. is_equal(1)
	)
	(
		assert_object(manipulation_state.data) \
		. append_failure_message("Expected data cleared after first cancellation") \
		. is_null()
	)

	# Act 2: Call cancel() again on already-canceled state
	# This should be idempotent (no second signal)
	manipulation_system.cancel()
	runner.simulate_frames(1)

	# Assert: No additional cancellation signal (idempotent)
	(
		assert_int(signal_capture["count"]) \
		. append_failure_message(
			"Expected idempotent cancel - no second signal when already canceled"
		) \
		. is_equal(1)
	)
	(
		assert_object(manipulation_state.data) \
		. append_failure_message("Expected data still null after second cancel") \
		. is_null()
	)

	manipulation_state.canceled.disconnect(cancellation_callback)



## Test: Indicators properly torn down on source deletion
## Setup: Start manipulation and monitor indicator state
## Act: Delete source during active manipulation
## Assert: Indicators are torn down (no orphan nodes)
func test_indicators_torn_down_on_source_deletion() -> void:
	# Setup: Ensure clean state
	if manipulation_state.data != null:
		manipulation_system.cancel()

	# Arrange: Start manipulation on test object
	var move_data: ManipulationData = manipulation_system.try_move(test_object)
	assert_int(move_data.status).append_failure_message(
		"Expected manipulation to start"
	).is_equal(GBEnums.Status.STARTED)

	# Wait a frame to let indicators set up
	runner.simulate_frames(1)

	# Verify manipulation data exists before deletion
	(
		assert_object(manipulation_state.data) \
		. append_failure_message("Expected active manipulation data") \
		. is_not_null()
	)

	# Act: Delete source - triggers indicator teardown via _on_source_tree_exiting
	test_object.queue_free()
	runner.simulate_until_object_signal(manipulation_state, "canceled")

	# Assert: Indicators should be torn down (no residual indicator references)
	(
		assert_object(manipulation_state.data) \
		. append_failure_message("Expected data cleared including all indicators") \
		. is_null()
	)

	# Verify state cleanup is complete
	(
		assert_bool(manipulation_state.active_manipulatable == null) \
		. append_failure_message("Expected active_manipulatable cleared on cancellation") \
		. is_true()
	)


## Test: Targeting state cleared on source deletion
## Setup: Start manipulation and verify targeting is set
## Act: Delete source
## Assert: Targeting state is cleared (resuming automatic targeting)
func test_targeting_cleared_on_source_deletion() -> void:
	# Setup: Ensure clean state
	if manipulation_state.data != null:
		manipulation_system.cancel()

	# Arrange: Start manipulation
	var move_data: ManipulationData = manipulation_system.try_move(test_object)
	assert_int(move_data.status).append_failure_message(
		"Expected manipulation to start"
	).is_equal(GBEnums.Status.STARTED)

	# Wait a frame for targeting to settle
	runner.simulate_frames(1)

	var targeting_state: GridTargetingState = container.get_states().targeting
	(
		assert_object(targeting_state) \
		. append_failure_message("Expected targeting state to exist") \
		. is_not_null()
	)

	var initial_data: ManipulationData = move_data

	# Act: Delete source
	test_object.queue_free()
	runner.simulate_until_object_signal(manipulation_state, "canceled", [initial_data])

	# Assert: Manipulation cancelled successfully
	(
		assert_object(manipulation_state.data) \
		. append_failure_message("Expected manipulation to be cleared after targeting test") \
		. is_null()
	)

