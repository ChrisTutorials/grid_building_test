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
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID)
	test_env = runner.scene()

	# Get systems from environment using AllSystemsTestEnvironment API
	container = test_env.injector.composition_container
	var systems_context := container.get_systems_context()
	manipulation_system = systems_context.get_manipulation_system()
	manipulation_state = container.get_states().manipulation

	# Create initial test object - tests will recreate as needed
	_create_test_object()

	await get_tree().process_frame

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
	# Arrange: Start move manipulation
	var move_data: ManipulationData = manipulation_system.try_move(test_object)

	# Verify manipulation started successfully
 assert_object(move_data)
 	.append_failure_message( "Expected move_data to be created" ) assert_int(move_data.status)
 	.is_equal(GBEnums.Status.STARTED)
 	.append_failure_message( "Expected manipulation to start with STARTED status, got: %d" % move_data.status ) # Verify manipulation data is active assert_object(manipulation_state.data)
 	.is_not_null()
 	.append_failure_message( "Expected active manipulation data to be set" ) # Act: Delete the source object (simulating external deletion) test_object.queue_free() await get_tree().process_frame # Assert: Manipulation should be auto-canceled assert_object(manipulation_state.data)
 	.is_null()
 	.append_failure_message( "Expected manipulation data to be cleared after source deletion" ) # Verify no manipulation is active - use manipulation_state.data instead of is_manipulating() var is_manipulating: bool = manipulation_state.data != null assert_bool(is_manipulating)
 	.is_false()
 	.append_failure_message( "Expected manipulation system to report no active manipulation after source deletion" ) ## Test: Multiple deletions don't cause crashes ## Setup: Start manipulation and track initial state ## Act: Delete source multiple times (defensive test) ## Assert: No crashes, manipulation canceled cleanly func test_multiple_source_deletions_handled_safely() -> void: # Arrange: Create fresh test object _create_test_object() await get_tree().process_frame # Start move manipulation var move_data: ManipulationData = manipulation_system.try_move(test_object) assert_int(move_data.status)
 	.is_equal(GBEnums.Status.STARTED)
 	.append_failure_message( "Expected manipulation to start successfully" ) # Act: Delete source and wait for processing test_object.queue_free() await get_tree().process_frame # Assert: Manipulation canceled assert_object(manipulation_state.data)
 	.is_null()
 	.append_failure_message( "Expected manipulation to be canceled after first deletion" ) # Act again: Attempt to trigger signal again (shouldn't crash) # The signal should already be disconnected await get_tree().process_frame # Assert: Still no active manipulation, no crashes assert_object(manipulation_state.data)
 	.is_null()
 	.append_failure_message( "Expected manipulation to remain canceled" ) ## Test: Source deletion during different manipulation phases ## Setup: Track manipulation phases (started, in-progress) ## Act: Delete source at different times ## Assert: Always cancels cleanly without errors func test_source_deletion_at_various_manipulation_phases() -> void: # Phase 1: Delete immediately after start _create_test_object() await get_tree().process_frame var move_data1: ManipulationData = manipulation_system.try_move(test_object) assert_int(move_data1.status)
 	.is_equal(GBEnums.Status.STARTED) test_object.queue_free() await get_tree().process_frame assert_object(manipulation_state.data)
 	.is_null()
 	.append_failure_message( "Expected immediate deletion to cancel manipulation" ) # Setup for phase 2: Recreate test object test_object = auto_free(Node2D.new()) test_object.name = "TestObject2" add_child(test_object) manipulatable = auto_free(Manipulatable.new()) manipulatable.root = test_object manipulatable.settings = ManipulatableSettings.new() manipulatable.settings.movable = true test_object.add_child(manipulatable) manipulatable.resolve_gb_dependencies(container) await get_tree().process_frame # Phase 2: Delete after some processing time _create_test_object() # Create fresh object for phase 2 await get_tree().process_frame var move_data2: ManipulationData = manipulation_system.try_move(test_object) assert_int(move_data2.status)
 	.is_equal(GBEnums.Status.STARTED) # Let some frames pass for i in range(3): await get_tree().process_frame # Now delete test_object.queue_free() await get_tree().process_frame assert_object(manipulation_state.data)
 	.is_null()
 	.append_failure_message( "Expected delayed deletion to cancel manipulation" )
 	.is_not_null()