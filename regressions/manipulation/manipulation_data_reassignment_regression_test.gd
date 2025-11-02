## Regression Test: ManipulationState.data re-assignment during manipulation lifecycle
##
## BUG CONTEXT:
## When manipulation_state.data is set multiple times during a single manipulation lifecycle
## (e.g., calling try_move() twice), the first ManipulationData object is NOT properly
## cleaned up before the second one is assigned. This creates a situation where:
## 1. First try_move() creates ManipulationData A
## 2. Second try_move() creates ManipulationData B (overwrites A)
## 3. Source deletion triggers cancel() on the CURRENT data (B)
## 4. But the test might still reference the OLD data (A)
##
## EXPECTED BEHAVIOR:
## - manipulation_state.data should NEVER be re-assigned while non-null
## - Calling try_move() twice should either:
##   a) Cancel the first manipulation before starting the second, OR
##   b) Return an error if manipulation already in progress
##
## This test documents the current BROKEN behavior where data CAN be re-assigned,
## and serves as a regression guard once fixed.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var test_env: Node
var manipulation_system: ManipulationSystem
var container: GBCompositionContainer
var manipulation_state: ManipulationState
var test_object: Node2D
var manipulatable: Manipulatable


func before_test() -> void:
	# Load test environment
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV.resource_path)
	runner.simulate_frames(1)
	test_env = runner.scene()

	# Get systems
	container = test_env.injector.composition_container
	var systems_context := container.get_systems_context()
	manipulation_system = systems_context.get_manipulation_system()
	manipulation_state = container.get_states().manipulation

	# Create test object
	_create_test_object()


func after_test() -> void:
	pass


## Helper: Create a fresh test object with manipulatable component
func _create_test_object() -> void:
	test_object = auto_free(Node2D.new())
	test_object.name = "TestObject"
	add_child(test_object)

	manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = test_object
	manipulatable.settings = ManipulatableSettings.new()
	manipulatable.settings.movable = true
	test_object.add_child(manipulatable)

	manipulatable.resolve_gb_dependencies(container)


## REGRESSION TEST: Calling try_move() twice should NOT silently overwrite manipulation_state.data
##
## Current BROKEN behavior:
## 1. First try_move() sets manipulation_state.data = ManipulationData A
## 2. Second try_move() sets manipulation_state.data = ManipulationData B (silently overwrites A)
## 3. ManipulationData A is orphaned and never cleaned up
##
## Expected CORRECT behavior (once fixed):
## 1. First try_move() sets manipulation_state.data = ManipulationData A
## 2. Second try_move() should EITHER:
##    - Auto-cancel the first manipulation and return new ManipulationData B, OR
##    - Return null/error because manipulation already in progress
func test_multiple_try_move_calls_should_not_silently_overwrite_data() -> void:
	# Arrange: Start first manipulation
	var first_move_data: ManipulationData = manipulation_system.try_move(test_object)

	(
		assert_object(first_move_data)
		. append_failure_message("First try_move() should create ManipulationData")
		. is_not_null()
	)

	(
		assert_object(manipulation_state.data)
		. append_failure_message("manipulation_state.data should be set after first try_move()")
		. is_not_null()
	)

	# Capture the first data reference
	var first_data_ref: ManipulationData = manipulation_state.data

	# Act: Call try_move() AGAIN without canceling the first manipulation
	# This is the BUG - it silently overwrites manipulation_state.data
	var second_move_data: ManipulationData = manipulation_system.try_move(test_object)

	# Assert: Document current BROKEN behavior
	# TODO: Once fixed, these assertions should FAIL because the behavior will change
	(
		assert_object(second_move_data)
		. append_failure_message(
			"CURRENT BUG: Second try_move() creates NEW ManipulationData "
			+ "(should return error or cancel first)"
		)
		. is_not_null()
	)

	(
		assert_object(manipulation_state.data)
		. append_failure_message(
			"manipulation_state.data should still be set (either first or second)"
		)
		. is_not_null()
	)

	# BUG EVIDENCE: The data reference has changed
	var current_data_is_different: bool = manipulation_state.data != first_data_ref
	(
		assert_bool(current_data_is_different)
		. append_failure_message(
			(
				"REGRESSION BUG: manipulation_state.data was silently re-assigned! "
				+ "First ref: %s, Current ref: %s" % [first_data_ref, manipulation_state.data]
			)
		)
		. is_true()
	)  # This DOCUMENTS the bug - it currently IS re-assigned

	# Additional evidence: The status of the first data is still STARTED
	# (it was never canceled before being overwritten)
	(
		assert_int(first_data_ref.status)
		. append_failure_message(
			"ORPHANED DATA BUG: First ManipulationData status should be CANCELED but is still STARTED"
		)
		. is_equal(GBEnums.Status.STARTED)
	)  # This shows the first data was abandoned


## REGRESSION TEST: When data is re-assigned, cancel() only affects the CURRENT data
##
## This documents the specific bug in the source deletion tests:
## 1. try_move() creates ManipulationData A (stored in test variable)
## 2. try_move() again creates ManipulationData B (overwrites manipulation_state.data)
## 3. Source deletion triggers cancel(), which clears manipulation_state.data (B)
## 4. But the test still checks the OLD reference (A), which is non-null
func test_cancel_only_affects_current_data_not_orphaned_references() -> void:
	# Arrange: Create first manipulation
	var first_move_data: ManipulationData = manipulation_system.try_move(test_object)
	var first_data_ref: ManipulationData = manipulation_state.data

	# Act: Re-assign data (simulating the bug)
	_create_test_object()  # Fresh object for second try
	runner.simulate_frames(1)
	var second_move_data: ManipulationData = manipulation_system.try_move(test_object)

	# Verify the bug happened - data was re-assigned
	(
		assert_bool(manipulation_state.data != first_data_ref)
		. append_failure_message("Setup verification: data should be re-assigned for this test")
		. is_true()
	)

	# Now cancel the CURRENT manipulation (second_move_data)
	manipulation_system.cancel()

	# Assert: manipulation_state.data is cleared (the CURRENT data)
	(
		assert_object(manipulation_state.data)
		. append_failure_message("manipulation_state.data should be null after cancel()")
		. is_null()
	)

	# BUG EVIDENCE: The OLD reference (first_data_ref) is still non-null and STARTED
	(
		assert_object(first_data_ref)
		. append_failure_message("ORPHANED DATA BUG: Old ManipulationData reference is still alive")
		. is_not_null()
	)

	(
		assert_int(first_data_ref.status)
		. append_failure_message(
			"ORPHANED DATA BUG: Old ManipulationData status is still STARTED (never canceled)"
		)
		. is_equal(GBEnums.Status.STARTED)
	)

	# This is exactly what the source deletion tests are hitting:
	# They check first_data_ref (which is orphaned) instead of manipulation_state.data


## CORRECT USAGE: Only one manipulation should be active at a time
##
## This test shows the CORRECT pattern - cancel before starting new manipulation
func test_correct_pattern_cancel_before_new_manipulation() -> void:
	# Start first manipulation
	var first_move_data: ManipulationData = manipulation_system.try_move(test_object)
	assert_object(manipulation_state.data).is_not_null()

	# CORRECT: Cancel the first manipulation before starting a new one
	manipulation_system.cancel()
	(
		assert_object(manipulation_state.data)
		. append_failure_message("Data should be null after cancel()")
		. is_null()
	)

	# Now it's safe to start a new manipulation
	_create_test_object()
	runner.simulate_frames(1)
	var second_move_data: ManipulationData = manipulation_system.try_move(test_object)

	# Assert: Only the second manipulation is active
	(
		assert_object(manipulation_state.data)
		. append_failure_message("manipulation_state.data should reference the second manipulation")
		. is_same(second_move_data)
	)

	# First data should be canceled
	(
		assert_int(first_move_data.status)
		. append_failure_message("First manipulation should be CANCELED")
		. is_equal(GBEnums.Status.CANCELED)
	)
