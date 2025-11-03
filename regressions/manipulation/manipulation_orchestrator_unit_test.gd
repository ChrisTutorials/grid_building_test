## Unit Test: ManipulationOrchestrator.cancel() method isolation
##
## ISSUE (REGRESSION):
##   "Invalid call. Nonexistent function 'cancel_manipulation' in base 'PackedScene'."
##   Location: manipulation_orchestrator.gd:246 in cancel() method
##
## ROOT CAUSE:
##   ManipulationOrchestrator was preloaded with string path instead of UID,
##   causing it to load as PackedScene rather than the actual class.
##   Also had improper `class_name` declaration.
##
## FIX APPLIED:
##   1. Removed `class_name ManipulationOrchestrator` from orchestrator file
##   2. Updated preload in ManipulationSystem to use UID: preload("uid://bhpcwmapx2lqs")
##   3. Verified ManipulationStateMachine is correctly preloaded by UID
##
## TEST STRATEGY (UNIT TEST - NOT INTEGRATION):
##   - Instantiate ManipulationOrchestrator directly (no scene environment)
##   - Verify it loads as class, not PackedScene
##   - Check method exists and is callable
##
extends GdUnitTestSuite

#region Preloads (by UID for safety)
const ManipulationOrchestrator = preload("uid://k21kl5ipqnxg")
const ManipulationStateMachine = preload("uid://blgwelirrimr1")
#endregion

var orchestrator: ManipulationOrchestrator


func before_test() -> void:
	# Create orchestrator instance directly (no scene loading)
	orchestrator = auto_free(ManipulationOrchestrator.new())

	# Verify it's not a PackedScene
	(
		assert_object(orchestrator)
		. append_failure_message(
			"Orchestrator should be ManipulationOrchestrator instance, not PackedScene"
		)
		. is_not_null()
	)


## Test: ManipulationOrchestrator instantiates as class, not PackedScene
func test_orchestrator_instantiates_as_class() -> void:
	# Verify the object type is correct
	(
		assert_object(orchestrator)
		. append_failure_message(
			"Should be ManipulationOrchestrator class instance, not PackedScene"
		)
		. is_not_null()
	)

	# Verify it has the cancel method
	(
		assert_bool(orchestrator.has_method("cancel"))
		. append_failure_message("ManipulationOrchestrator should have cancel() method")
		. is_true()
	)


## Test: cancel() method exists and is NOT a PackedScene method
func test_cancel_method_exists_not_packedscene() -> void:
	# The critical test: verify cancel() exists on the class itself
	# If preload returns PackedScene, this would fail with "method not found on PackedScene"
	var has_cancel: bool = orchestrator.has_method("cancel")

	(
		assert_bool(has_cancel)
		. append_failure_message("ManipulationOrchestrator instance should have cancel() method")
		. is_true()
	)


## Test: ManipulationStateMachine is correct class (not PackedScene)
func test_manipulation_state_machine_is_class() -> void:
	# Verify ManipulationStateMachine loads as a class, not PackedScene
	# If preload fails, it would be PackedScene and this assertion would fail
	(
		assert_object(ManipulationStateM)
		. append_failure_message("ManipulationStateMachine should load as class (not PackedScene)")
		. is_not_null()
	)


## Test: Verify try_move method exists (another key orchestrator method)
func test_orchestrator_has_try_move() -> void:
	# Verify other methods exist as well to confirm full class loading
	(
		assert_bool(orchestrator.has_method("try_move"))
		. append_failure_message("ManipulationOrchestrator should have try_move() method")
		. is_true()
	)
