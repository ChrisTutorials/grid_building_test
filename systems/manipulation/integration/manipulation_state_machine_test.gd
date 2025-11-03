## Unit Tests: ManipulationStateMachine - Pure Cancellation Logic
##
## Tests verify the pure state machine logic without any dependencies.
## No mocking, no environment setup, no scene runner.
## Input: ManipulationData or null
## Output: ManipulationCancellationCommands
extends GdUnitTestSuite


func _create_test_data(p_action: int = GBEnums.Action.MOVE) -> ManipulationData:
	var manipulator: Node = Node.new()
	var source: Manipulatable = Manipulatable.new()
	var move_copy: Manipulatable = Manipulatable.new()

	return auto_free(ManipulationData.new(manipulator, source, move_copy, p_action))


## Test: Valid manipulation data returns all cancellation commands
func test_cancel_with_valid_move_data_returns_all_commands() -> void:
	var data: ManipulationData = _create_test_data(GBEnums.Action.MOVE)

	var commands := ManipulationStateMachine.cancel_manipulation(data)

	# All commands should be set for cancellation
	(
		assert_bool(commands.emit_signal)
		. append_failure_message("Should emit signal on valid data")
		. is_true()
	)
	assert_bool(commands.clear_data).append_failure_message("Should clear data").is_true()
	(
		assert_bool(commands.clear_manipulatable)
		. append_failure_message("Should clear active manipulatable")
		. is_true()
	)
	assert_bool(commands.clear_targeting).append_failure_message("Should clear targeting").is_true()


## Test: Null data is safe and returns no-op commands
func test_cancel_with_null_data_returns_no_op_commands() -> void:
	var commands := ManipulationStateMachine.cancel_manipulation(null)

	# No commands should execute
	(
		assert_bool(commands.emit_signal)
		. append_failure_message("Should not emit signal on null data")
		. is_false()
	)
	(
		assert_bool(commands.clear_data)
		. append_failure_message("Should not clear data on null input")
		. is_false()
	)
	(
		assert_bool(commands.clear_manipulatable)
		. append_failure_message("Should not clear manipulatable on null")
		. is_false()
	)


## Test: Signal data is preserved for listeners
## Critical: data reference must stay valid so signal handlers receive it
func test_cancel_preserves_data_reference_for_signal() -> void:
	var data: ManipulationData = _create_test_data(GBEnums.Action.MOVE)
	data.status = GBEnums.Status.STARTED

	var commands := ManipulationStateMachine.cancel_manipulation(data)

	# The commands PRESERVE the data reference so signal handlers can access it
	(
		assert_object(commands.signal_data)
		. append_failure_message("Signal data should be set to original data object")
		. is_equal(data)
	)


## Test: Different action types (DEMOLISH) are handled
func test_cancel_with_demolish_action_returns_commands() -> void:
	var data: ManipulationData = _create_test_data(GBEnums.Action.DEMOLISH)

	var commands := ManipulationStateMachine.cancel_manipulation(data)

	# Cancellation is consistent regardless of action type
	(
		assert_bool(commands.emit_signal)
		. append_failure_message("Demolish action should still emit signal")
		. is_true()
	)
	(
		assert_bool(commands.clear_data)
		. append_failure_message("Demolish action should clear data")
		. is_true()
	)


## Test: Rotation action cancellation also produces commands
func test_cancel_with_rotate_action_returns_commands() -> void:
	var data: ManipulationData = _create_test_data(GBEnums.Action.ROTATE)

	var commands := ManipulationStateMachine.cancel_manipulation(data)

	(
		assert_bool(commands.emit_signal)
		. append_failure_message("Rotate action should emit signal")
		. is_true()
	)


## Test: Targeting is always cleared on cancel
func test_cancel_always_clears_targeting() -> void:
	var data: ManipulationData = _create_test_data(GBEnums.Action.MOVE)

	var commands := ManipulationStateMachine.cancel_manipulation(data)

	(
		assert_bool(commands.clear_targeting)
		. append_failure_message("Targeting should always be cleared")
		. is_true()
	)


## Test: Processing is stopped to prevent further updates
func test_cancel_stops_processing() -> void:
	var data: ManipulationData = _create_test_data(GBEnums.Action.MOVE)

	var commands := ManipulationStateMachine.cancel_manipulation(data)

	(
		assert_bool(commands.stop_processing)
		. append_failure_message("Processing should be stopped")
		. is_true()
	)


## Test: Command object is always returned (never null)
func test_cancel_always_returns_valid_command_object() -> void:
	var commands1 := ManipulationStateMachine.cancel_manipulation(null)
	var commands2: ManipulationData = _create_test_data(GBEnums.Action.MOVE)
	var commands2_result := ManipulationStateMachine.cancel_manipulation(commands2)

	(
		assert_object(commands1)
		. append_failure_message("Should return command object even for null input")
		. is_not_null()
	)
	(
		assert_object(commands2_result)
		. append_failure_message("Should return command object for valid input")
		. is_not_null()
	)


## Test: Multiple calls with different data produce independent commands
func test_cancel_multiple_calls_are_independent() -> void:
	var data1: ManipulationData = _create_test_data(GBEnums.Action.MOVE)
	var data2: ManipulationData = _create_test_data(GBEnums.Action.DEMOLISH)

	var commands1 := ManipulationStateMachine.cancel_manipulation(data1)
	var commands2 := ManipulationStateMachine.cancel_manipulation(data2)

	# Each call returns independent commands
	(
		assert_object(commands1.signal_data)
		. append_failure_message("First command should reference first data")
		. is_equal(data1)
	)
	(
		assert_object(commands2.signal_data)
		. append_failure_message("Second command should reference second data")
		. is_equal(data2)
	)
	(
		assert_object(commands1.signal_data)
		. append_failure_message("Commands should be independent")
		. is_not_equal(commands2.signal_data)
	)
