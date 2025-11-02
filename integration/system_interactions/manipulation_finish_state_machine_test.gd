## Tests for pure ManipulationStateMachine.finish_manipulation() logic.
##
## Tests the finish command generation without environment dependencies.
## Verifies:
## - Finish with active data returns proper commands
## - Finish with null data returns empty commands
## - Commands include all cleanup flags
## - Signal data is preserved for listeners
## - Status transitions correctly
extends GdUnitTestSuite


## Helper: Create test data for manipulation finishing tests.
func _create_test_data(p_action: int = GBEnums.Action.MOVE) -> ManipulationData:
	var manipulator: Node = Node.new()
	var source: Manipulatable = Manipulatable.new()
	var move_copy: Manipulatable = Manipulatable.new()
	return auto_free(ManipulationData.new(manipulator, source, move_copy, p_action))


## Test: Finish with null data returns empty commands (safe idempotent behavior).
func test_finish_with_null_data_returns_empty_commands() -> void:
	var commands := ManipulationStateMachine.finish_manipulation(null)
	
	assert_bool(commands.emit_signal).is_false()
	assert_object(commands.signal_data).is_null()
	assert_bool(commands.tear_down_indicators).is_false()
	assert_bool(commands.queue_free_objects).is_false()
	assert_bool(commands.clear_data).is_false()
	assert_bool(commands.clear_manipulatable).is_false()
	assert_bool(commands.clear_targeting).is_false()


## Test: Finish with active data returns full cleanup commands.
func test_finish_with_active_data_returns_cleanup_commands() -> void:
	var data := _create_test_data()
	var commands := ManipulationStateMachine.finish_manipulation(data)
	
	assert_bool(commands.emit_signal).is_true()
	assert_object(commands.signal_data).is_equal(data)
	assert_bool(commands.tear_down_indicators).is_true()
	assert_bool(commands.queue_free_objects).is_true()
	assert_bool(commands.clear_data).is_true()
	assert_bool(commands.clear_manipulatable).is_true()
	assert_bool(commands.clear_targeting).is_true()


## Test: Finish sets status to FINISHED by default.
func test_finish_sets_status_to_finished() -> void:
	var data := _create_test_data()
	var commands := ManipulationStateMachine.finish_manipulation(data)
	
	assert_int(commands.signal_status).is_equal(GBEnums.Status.FINISHED)


## Test: Finish preserves signal data reference for listeners.
func test_finish_preserves_signal_data_reference() -> void:
	var data := _create_test_data()
	var commands := ManipulationStateMachine.finish_manipulation(data)
	
	# Signal data must be the same reference (not a copy)
	assert_bool(commands.signal_data == data).is_true()


## Test: Multiple finish calls with same data return same commands (deterministic).
func test_finish_is_deterministic() -> void:
	var data := _create_test_data()
	var commands1 := ManipulationStateMachine.finish_manipulation(data)
	var commands2 := ManipulationStateMachine.finish_manipulation(data)
	
	assert_bool(commands1.emit_signal).is_equal(commands2.emit_signal)
	assert_bool(commands1.tear_down_indicators).is_equal(commands2.tear_down_indicators)
	assert_bool(commands1.queue_free_objects).is_equal(commands2.queue_free_objects)
	assert_int(commands1.signal_status).is_equal(commands2.signal_status)


## Test: Finish works with all action types (MOVE, DEMOLISH, BUILD).
func test_finish_works_with_all_action_types() -> void:
	var actions: Array[int] = [GBEnums.Action.MOVE, GBEnums.Action.DEMOLISH, GBEnums.Action.BUILD]
	
	for action in actions:
		var data := _create_test_data(action)
		var commands := ManipulationStateMachine.finish_manipulation(data)
		
		assert_bool(commands.emit_signal).append_failure_message(
			"Action %d should emit signal" % action
		).is_true()
		assert_object(commands.signal_data).append_failure_message(
			"Action %d should preserve data" % action
		).is_equal(data)


## Test: Finish commands include all required cleanup flags.
func test_finish_includes_all_cleanup_flags() -> void:
	var data := _create_test_data()
	var commands := ManipulationStateMachine.finish_manipulation(data)
	
	# All cleanup flags should be true for complete cleanup
	var required_cleanups: Array[bool] = [
		commands.tear_down_indicators,
		commands.queue_free_objects,
		commands.clear_data,
		commands.clear_manipulatable,
		commands.clear_targeting
	]
	
	for cleanup_flag in required_cleanups:
		assert_bool(cleanup_flag).is_true()
