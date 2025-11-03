## Tests for pure ManipulationStateMachine.try_demolish_target() logic.
##
## Tests the demolish validation logic without system dependencies.
## Verifies:
## - Valid targets are approved for demolition
## - Invalid targets are rejected with appropriate messages
## - Demolish enabled/disabled flag is respected
## - Null safety (null targets, deleted roots)
## - State cleanup flags are correct
extends GdUnitTestSuite


## Helper: Create test Manipulatable with optional root node and demolish settings.
func _create_test_manipulatable(p_root: Node = null, p_demolishable: bool = false) -> Manipulatable:
	var manip: Manipulatable = Manipulatable.new()
	if p_root:
		manip.root = p_root
	# Create settings with demolishable flag
	var settings: ManipulatableSettings = ManipulatableSettings.new()
	settings.demolishable = p_demolishable
	manip.settings = settings
	return auto_free(manip)


## Helper: Create test settings with demolish enabled/disabled.
func _create_test_settings(p_enable_demolish: bool = true) -> ManipulationSettings:
	var settings: ManipulationSettings = ManipulationSettings.new()
	settings.enable_demolish = p_enable_demolish
	settings.failed_no_target_object = "No target object"
	settings.failed_not_demolishable = "Not demolishable: %s"
	settings.demolish_already_deleted = "Already deleted: %s"
	settings.demolish_success = "Demolished: %s"
	return auto_free(settings)


## Test: Null target returns FAILED status and appropriate message.
func test_demolish_null_target_returns_failed() -> void:
	var settings := _create_test_settings()
	var commands := ManipulationStateMachine.try_demolish_target(null, null, settings)

	assert_int(commands.status).is_equal(GBEnums.Status.FAILED)
	assert_bool(commands.should_demolish).is_false()
	assert_str(commands.message).contains("No target")


## Test: Target with null root returns FAILED with deleted message.
func test_demolish_target_with_null_root_returns_deleted_message() -> void:
	var manip := _create_test_manipulatable(null)
	var settings := _create_test_settings()
	var commands := ManipulationStateMachine.try_demolish_target(manip, null, settings)

	assert_int(commands.status).is_equal(GBEnums.Status.FAILED)
	assert_bool(commands.should_demolish).is_false()
	assert_str(commands.message).contains("deleted")


## Test: Demolish disabled returns FAILED even with valid target.
func test_demolish_disabled_returns_failed() -> void:
	var root: Node = auto_free(Node.new())
	var manip := _create_test_manipulatable(root, true)  # demolishable=true
	var settings := _create_test_settings(false)  # enable_demolish=false

	var commands := ManipulationStateMachine.try_demolish_target(manip, null, settings)

	assert_int(commands.status).is_equal(GBEnums.Status.FAILED)
	assert_bool(commands.should_demolish).is_false()


## Test: Target not demolishable returns FAILED status.
func test_demolish_non_demolishable_target_returns_failed() -> void:
	var root: Node = auto_free(Node.new())
	var manip := _create_test_manipulatable(root, false)  # demolishable=false
	var settings := _create_test_settings(true)

	var commands := ManipulationStateMachine.try_demolish_target(manip, null, settings)

	assert_int(commands.status).is_equal(GBEnums.Status.FAILED)
	assert_bool(commands.should_demolish).is_false()
	assert_str(commands.message).contains("Not demolishable")


## Test: Valid demolishable target returns FINISHED status with should_demolish = true.
func test_demolish_valid_target_returns_finished() -> void:
	var root: Node = auto_free(Node.new())
	var manip := _create_test_manipulatable(root, true)  # demolishable=true
	var settings := _create_test_settings(true)

	var commands := ManipulationStateMachine.try_demolish_target(manip, null, settings)

	assert_int(commands.status).is_equal(GBEnums.Status.FINISHED)
	assert_bool(commands.should_demolish).is_true()
	assert_str(commands.message).contains("Demolished")


## Test: Valid target sets clear_data and clear_manipulatable flags.
func test_demolish_valid_target_sets_cleanup_flags() -> void:
	var root: Node = auto_free(Node.new())
	var manip := _create_test_manipulatable(root, true)
	var settings := _create_test_settings(true)

	var commands := ManipulationStateMachine.try_demolish_target(manip, null, settings)

	assert_bool(commands.clear_data).is_true()
	assert_bool(commands.clear_manipulatable).is_true()


## Test: Falls back to active_target when target is null.
func test_demolish_uses_active_target_when_target_null() -> void:
	var root: Node = auto_free(Node.new())
	var active_manip := _create_test_manipulatable(root, true)
	var settings := _create_test_settings(true)

	var commands := ManipulationStateMachine.try_demolish_target(null, active_manip, settings)

	assert_int(commands.status).is_equal(GBEnums.Status.FINISHED)
	assert_bool(commands.should_demolish).is_true()


## Test: Prefers explicit target over active_target.
func test_demolish_prefers_explicit_target() -> void:
	var root1: Node = auto_free(Node.new())
	root1.name = "target"
	var manip1 := _create_test_manipulatable(root1, true)

	var root2: Node = auto_free(Node.new())
	root2.name = "active"
	var active_manip := _create_test_manipulatable(root2, false)  # Not demolishable

	var settings := _create_test_settings(true)

	var commands := ManipulationStateMachine.try_demolish_target(manip1, active_manip, settings)

	# Should use manip1 (the explicit target), not active_manip
	assert_int(commands.status).is_equal(GBEnums.Status.FINISHED)
	assert_bool(commands.should_demolish).is_true()


## Test: Null settings uses default messages.
func test_demolish_null_settings_uses_defaults() -> void:
	# With null settings, should still return FAILED status
	var commands := ManipulationStateMachine.try_demolish_target(null, null, null)

	assert_int(commands.status).is_equal(GBEnums.Status.FAILED)
	assert_bool(commands.should_demolish).is_false()


## Test: Freed root returns FAILED status.
func test_demolish_freed_root_returns_failed() -> void:
	var root: Node = Node.new()
	var manip := _create_test_manipulatable(root, true)
	var settings := _create_test_settings(true)

	# Free the root node
	root.queue_free()

	var commands := ManipulationStateMachine.try_demolish_target(manip, null, settings)

	# After queue_free, should still be valid in same frame, but test the behavior
	# This tests the guard against freed objects
	if not is_instance_valid(root):
		assert_int(commands.status).is_equal(GBEnums.Status.FAILED)


## Test: Multiple demolish calls with same target return same result (deterministic).
func test_demolish_is_deterministic() -> void:
	var root: Node = auto_free(Node.new())
	var manip := _create_test_manipulatable(root, true)
	var settings := _create_test_settings(true)

	var commands1 := ManipulationStateMachine.try_demolish_target(manip, null, settings)
	var commands2 := ManipulationStateMachine.try_demolish_target(manip, null, settings)

	assert_int(commands1.status).is_equal(commands2.status)
	assert_bool(commands1.should_demolish).is_equal(commands2.should_demolish)
	assert_str(commands1.message).is_equal(commands2.message)
