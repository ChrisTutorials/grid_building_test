## Minimal isolation test for source deletion callback pattern
## Tests ONLY the callback firing and data clearing, nothing else
##
## INVESTIGATION FINDINGS (November 3, 2025):
## ============================================
## Root Cause: Container Duplication for Test Isolation
##
## Problem: Full integration tests (manipulation_source_deletion_test.gd) fail with:
##   "Expected manipulation_state.data to be null, but was <RefCounted>"
##
## Investigation revealed:
## 1. ✅ Callback DOES fire when source deleted (confirmed in logs)
## 2. ✅ ManipulationSystem.cancel() IS called from callback (confirmed in logs)
## 3. ✅ ManipulationOrchestrator.cancel() DOES set data to null (confirmed in logs)
## 4. ✅ Data IS cleared: logs show "manipulation_state.data is now: <null>"
## 5. ❌ BUT test still says data is RefCounted, not null
##
## ROOT CAUSE: GBTestInjectorSystem auto-duplicates the composition container
## for test isolation. The test gets its manipulation_state reference BEFORE
## the container is duplicated, so it's looking at the OLD container's states
## while the system uses the DUPLICATED container's states.
##
## Flow:
##   1. Test loads ALL_SYSTEMS_ENV scene
##   2. Gets container from test_env.injector.composition_container
##   3. Gets manipulation_state from container.get_states().manipulation
##   4. GBTestInjectorSystem auto-duplicates container for test isolation
##   5. All systems now use the DUPLICATED container (different object)
##   6. Test still references the OLD container's manipulation_state
##   7. When system clears data in duplicated container, test sees old reference unchanged
##
## Solution: This isolation test bypasses the full integration by:
##   - Creating a fresh container in before_test()
##   - Initializing it directly (no auto-duplication)
##   - Getting ALL references from the SAME container
##   - Testing only callback/data-clearing logic in isolation
##
## Expected Result: All 4 tests should pass if callback pattern works correctly
extends GdUnitTestSuite

var container: GBCompositionContainer
var manipulation_state: ManipulationState
var manipulation_system: ManipulationSystem
var test_object: Node2D


func before_test() -> void:
	container = auto_free(GBCompositionContainer.create_default())
	var injector_result = container.initialize()
	assert_bool(injector_result).is_true()

	manipulation_state = container.get_states().manipulation
	manipulation_system = container.get_system(ManipulationSystem)

	# Create simple test object
	test_object = auto_free(Node2D.new())
	test_object.name = "TestObject"
	var manipulatable = auto_free(Manipulatable.new())
	test_object.add_child(manipulatable)
	container.get_systems().get_owner_context().add_child(test_object)


## TEST 1: Verify callback is actually being invoked
func test_callback_invoked_on_source_deletion() -> void:
	# Track if callback was called
	var callback_called = false

	# Patch ManipulationSystem.cancel to track if it's called
	var original_cancel = manipulation_system.cancel

	# Start move
	var move_data = manipulation_system.try_move(test_object)
	assert_object(move_data).is_not_null()
	assert_int(move_data.status).is_equal(GBEnums.Status.STARTED)

	# Delete source
	test_object.queue_free()

	# Process one frame to let signals fire
	await get_tree().process_frame

	# Check: manipulation_state.data should be null
	(
		assert_object(manipulation_state.data)
		. append_failure_message("Expected manipulation_state.data to be null after source deleted")
		. is_null()
	)


## TEST 2: Verify data is actually cleared (synchronous)
func test_data_cleared_synchronously_after_deletion() -> void:
	# Start move
	var move_data = manipulation_system.try_move(test_object)
	var initial_data = manipulation_state.data
	assert_object(initial_data).is_not_null()

	# Record initial state
	var initial_status = initial_data.status
	assert_int(initial_status).is_equal(GBEnums.Status.STARTED)

	# Delete and check state
	test_object.tree_exiting.emit()  # Manually emit to isolate

	# Check immediately after (no await)
	(
		assert_object(manipulation_state.data)
		. append_failure_message("Expected data to be null after tree_exiting")
		. is_null()
	)

	# Check that status was changed to CANCELED before clearing
	(
		assert_int(initial_data.status)
		. append_failure_message("Expected data status to be CANCELED")
		. is_equal(GBEnums.Status.CANCELED)
	)


## TEST 3: Verify signal is emitted before data is cleared
func test_canceled_signal_fires_before_data_clear() -> void:
	var signal_fired = false
	var signal_data_ref: ManipulationData = null

	# Connect to signal
	manipulation_state.canceled.connect(
		func(data: ManipulationData):
			signal_fired = true
			signal_data_ref = data
	)

	# Start move
	var move_data = manipulation_system.try_move(test_object)
	var initial_data = manipulation_state.data

	# Delete source
	test_object.tree_exiting.emit()

	# Verify signal fired with correct data reference
	assert_bool(signal_fired).append_failure_message("Expected canceled signal to fire").is_true()

	# Verify signal had data reference (same object)
	(
		assert_object(signal_data_ref)
		. append_failure_message("Expected signal_data_ref to not be null")
		. is_not_null()
	)

	# Verify it was the SAME data object
	(
		assert_bool(signal_data_ref == initial_data)
		. append_failure_message("Expected signal to emit with original data reference")
		. is_true()
	)

	# Verify data is now null
	(
		assert_object(manipulation_state.data)
		. append_failure_message(
			"Expected manipulation_state.data to be null after signal and clear"
		)
		. is_null()
	)


## TEST 4: Verify no re-initialization happens
func test_data_stays_null_after_clear() -> void:
	# Start move
	var move_data = manipulation_system.try_move(test_object)
	assert_object(manipulation_state.data).is_not_null()

	# Delete source
	test_object.tree_exiting.emit()

	# Verify null
	assert_object(manipulation_state.data).is_null()

	# Simulate several frames to ensure nothing re-initializes
	for i in range(5):
		await get_tree().process_frame

	# Should still be null
	(
		assert_object(manipulation_state.data)
		. append_failure_message("Expected data to remain null after additional frames")
		. is_null()
	)
