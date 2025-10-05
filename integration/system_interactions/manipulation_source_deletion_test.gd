## Test: ManipulationSystem handles source object deletion gracefully
## Validates that manipulation auto-cancels when the source object is deleted mid-operation
extends GdUnitTestSuite

var test_env: Dictionary
var manipulation_system: ManipulationSystem
var container: GBCompositionContainer
var manipulation_state: ManipulationState
var test_object: Node2D
var manipulatable: Manipulatable

func before_test() -> void:
	# Create test environment with manipulation system
	test_env = UnifiedTestFactory.create_systems_integration_test_environment()
	container = test_env.container
	manipulation_system = test_env.manipulation_system
	manipulation_state = container.get_states().manipulation
	
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
	
	await get_tree().process_frame

func after_test() -> void:
	# Cleanup is handled by auto_free()
	pass

## Test: Manipulation auto-cancels when source object is deleted
## Setup: Start move manipulation on a test object
## Act: Delete the source object while manipulation is active
## Assert: Manipulation is automatically canceled
func test_source_deletion_cancels_manipulation() -> void:
	# Arrange: Start move manipulation
	var move_data: ManipulationData = manipulation_system.try_move(manipulatable)
	
	# Verify manipulation started successfully
	assert_object(move_data).is_not_null().append_failure_message(
		"Expected move_data to be created"
	)
	assert_int(move_data.status).is_equal(GBEnums.Status.STARTED).append_failure_message(
		"Expected manipulation to start with STARTED status, got: %d" % move_data.status
	)
	
	# Verify manipulation data is active
	assert_object(manipulation_state.data).is_not_null().append_failure_message(
		"Expected active manipulation data to be set"
	)
	
	# Act: Delete the source object (simulating external deletion)
	test_object.queue_free()
	await get_tree().process_frame
	
	# Assert: Manipulation should be auto-canceled
	assert_object(manipulation_state.data).is_null().append_failure_message(
		"Expected manipulation data to be cleared after source deletion"
	)
	
	# Verify no manipulation is active
	var is_manipulating: bool = manipulation_system.is_manipulating()
	assert_bool(is_manipulating).is_false().append_failure_message(
		"Expected manipulation system to report no active manipulation after source deletion"
	)

## Test: Multiple deletions don't cause crashes
## Setup: Start manipulation and track initial state
## Act: Delete source multiple times (defensive test)
## Assert: No crashes, manipulation canceled cleanly
func test_multiple_source_deletions_handled_safely() -> void:
	# Arrange: Start move manipulation
	var move_data: ManipulationData = manipulation_system.try_move(manipulatable)
	
	assert_int(move_data.status).is_equal(GBEnums.Status.STARTED).append_failure_message(
		"Expected manipulation to start successfully"
	)
	
	# Act: Delete source and wait for processing
	test_object.queue_free()
	await get_tree().process_frame
	
	# Assert: Manipulation canceled
	assert_object(manipulation_state.data).is_null().append_failure_message(
		"Expected manipulation to be canceled after first deletion"
	)
	
	# Act again: Attempt to trigger signal again (shouldn't crash)
	# The signal should already be disconnected
	await get_tree().process_frame
	
	# Assert: Still no active manipulation, no crashes
	assert_object(manipulation_state.data).is_null().append_failure_message(
		"Expected manipulation to remain canceled"
	)

## Test: Source deletion during different manipulation phases
## Setup: Track manipulation phases (started, in-progress)
## Act: Delete source at different times
## Assert: Always cancels cleanly without errors
func test_source_deletion_at_various_manipulation_phases() -> void:
	# Phase 1: Delete immediately after start
	var move_data1: ManipulationData = manipulation_system.try_move(manipulatable)
	assert_int(move_data1.status).is_equal(GBEnums.Status.STARTED)
	
	test_object.queue_free()
	await get_tree().process_frame
	
	assert_object(manipulation_state.data).is_null().append_failure_message(
		"Expected immediate deletion to cancel manipulation"
	)
	
	# Setup for phase 2: Recreate test object
	test_object = auto_free(Node2D.new())
	test_object.name = "TestObject2"
	add_child(test_object)
	
	manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = test_object
	manipulatable.settings = ManipulatableSettings.new()
	manipulatable.settings.movable = true
	test_object.add_child(manipulatable)
	manipulatable.resolve_gb_dependencies(container)
	
	await get_tree().process_frame
	
	# Phase 2: Delete after some processing time
	var move_data2: ManipulationData = manipulation_system.try_move(manipulatable)
	assert_int(move_data2.status).is_equal(GBEnums.Status.STARTED)
	
	# Let some frames pass
	for i in range(3):
		await get_tree().process_frame
	
	# Now delete
	test_object.queue_free()
	await get_tree().process_frame
	
	assert_object(manipulation_state.data).is_null().append_failure_message(
		"Expected delayed deletion to cancel manipulation"
	)
