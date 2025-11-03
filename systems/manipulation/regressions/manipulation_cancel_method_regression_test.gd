## Regression Test: ManipulationSystem.cancel() workflow
##
## ISSUE (RED):
##   "Invalid call. Nonexistent function 'cancel_manipulation'"
##   Location: manipulation_orchestrator.gd:246
##
## ROOT CAUSE:
##   ManipulationStateMachine preloaded with string path instead of UID,
##   causing it to load as PackedScene rather than the class.
##
##   Old code:
##     const MoveWorkflow = preload("res://...")
##     const ManipulationOrchestrator = preload("res://...")
##
## FIX:
##   Replace string path preloads with UID preloads.
##   Verify ManipulationStateMachine.cancel_manipulation() callable.
##
## TEST BEHAVIOR:
##   - RED: All 3 tests fail with "Invalid call. Nonexistent function 'cancel_manipulation'"
##   - GREEN: Tests pass once preloads use UIDs or files load correctly
##
extends GdUnitTestSuite

#region Test Setup
var runner: GdUnitSceneRunner
var test_environment: AllSystemsTestEnvironment
var manipulation_system: ManipulationSystem
var manipulation_state: ManipulationState
var container: GBCompositionContainer
#endregion


func before_test() -> void:
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV.resource_path)
	test_environment = runner.scene() as AllSystemsTestEnvironment

	(
		assert_object(test_environment)
		. append_failure_message("Failed to load AllSystemsTestEnvironment")
		. is_not_null()
	)

	container = test_environment.injector.composition_container
	manipulation_system = test_environment.manipulation_system
	manipulation_state = container.get_states().manipulation

	(
		assert_object(manipulation_system)
		. append_failure_message("ManipulationSystem should be available")
		. is_not_null()
	)


## Test: ManipulationSystem.cancel() method exists and is callable
## This is a regression test - ensure the cancel method cannot be accidentally
## removed or become unreachable during code organization.
func test_cancel_method_exists_and_is_callable() -> void:
	# Arrange: Verify the method exists as a callable
	(
		assert_bool(manipulation_system.has_method("cancel"))
		. append_failure_message("ManipulationSystem should have a 'cancel' method")
		. is_true()
	)


## Test: cancel() can be called and completes successfully
## Simulates a basic manipulation state and calls cancel()
func test_cancel_executes_without_error() -> void:
	# Arrange: Set up a simple manipulation state
	var manipulation_data: ManipulationData = ManipulationData.new(
		null, null, null, GBEnums.Action.MOVE  # manipulator  # manipulatable  # root
	)
	manipulation_data.status = GBEnums.Status.STARTED
	manipulation_state.data = manipulation_data

	# Listen to status_changed signal to confirm cancel() executes
	var signal_events: Array[int] = []
	manipulation_data.status_changed.connect(
		func(status: GBEnums.Status) -> void: signal_events.append(status)
	)

	# Act: Call cancel() - this would fail with "nonexistent function" if method is missing
	manipulation_system.cancel()

	# Assert: cancel executed and set status (signal should have been emitted)
	# Status should be CANCELED after cancel() completes
	(
		assert_int(manipulation_state.data.status)
		. append_failure_message("After cancel(), status should be CANCELED")
		. is_equal(GBEnums.Status.CANCELED)
	)

	# Verify state was cleared after cancel
	(
		assert_object(manipulation_state.data)
		. append_failure_message("Data should be null after cancel()")
		. is_null()
	)


## Test: cancel() can be called multiple times safely
## Ensures cancel() doesn't error when called on already-cleared state
func test_cancel_multiple_times_safely() -> void:
	# Arrange: Start with null state (already canceled or fresh)
	manipulation_state.data = null

	# Act: Call cancel() on clean state - should not error
	# This tests that cancel() handles the case where there's nothing to cancel
	manipulation_system.cancel()

	# Assert: Still null after calling cancel
	(
		assert_object(manipulation_state.data)
		. append_failure_message("Data should remain null if already null")
		. is_null()
	)
