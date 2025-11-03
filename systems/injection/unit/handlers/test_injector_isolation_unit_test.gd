## Unit tests for GBTestInjectorSystem to verify automatic test isolation.
##
## Tests that the test injector system properly:
## - Automatically duplicates containers
## - Maintains isolation between test runs
## - Resets duplication state when container changes
## - Configures lenient runtime checks for tests
extends GdUnitTestSuite

var _original_container: GBCompositionContainer
var _test_injector: GBTestInjectorSystem


func before_test() -> void:
	# Create a fresh original container for each test
	_original_container = auto_free(GBCompositionContainer.new())
	_original_container.config = auto_free(GBConfig.new())
	_original_container.config.settings = auto_free(GBSettings.new())
	_original_container.config.settings.runtime_checks = auto_free(GBRuntimeChecks.new())

	# Create test injector
	_test_injector = auto_free(GBTestInjectorSystem.new())


func after_test() -> void:
	_original_container = null
	_test_injector = null


## Tests that test injector auto-duplicates container on assignment
func test_test_injector_auto_duplicates_container() -> void:
	# Assign container
	_test_injector.composition_container = _original_container

	# Trigger duplication
	_test_injector._duplicate_container_if_needed()

	# Verify container was duplicated (should be different instance)
	(
		assert_object(_test_injector.composition_container)
		. append_failure_message("Test injector should have duplicated container")
		. is_not_equal(_original_container)
	)


## Tests that duplication only happens once per container
func test_duplication_happens_only_once_per_container() -> void:
	# First duplication
	_test_injector.composition_container = _original_container
	_test_injector._duplicate_container_if_needed()
	var first_duplicate: GBCompositionContainer = _test_injector.composition_container

	# Try to duplicate again
	_test_injector._duplicate_container_if_needed()
	var second_check: GBCompositionContainer = _test_injector.composition_container

	# Verify no new duplication occurred
	(
		assert_object(second_check)
		. append_failure_message("Second call should not re-duplicate (same instance expected)")
		. is_equal(first_duplicate)
	)


## Tests that duplication resets when container changes
func test_duplication_resets_when_container_changes() -> void:
	# First container
	_test_injector.composition_container = _original_container
	_test_injector._duplicate_container_if_needed()
	var first_duplicate: GBCompositionContainer = _test_injector.composition_container

	# New container (simulating new test)
	var new_container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	new_container.config = auto_free(GBConfig.new())

	_test_injector.composition_container = new_container
	_test_injector._duplicate_container_if_needed()
	var second_duplicate: GBCompositionContainer = _test_injector.composition_container

	# Verify new duplication occurred
	(
		assert_object(second_duplicate)
		. append_failure_message("New container should trigger new duplication")
		. is_not_equal(first_duplicate)
	)

	(
		assert_object(second_duplicate)
		. append_failure_message("New duplicate should not equal new original")
		. is_not_equal(new_container)
	)


## Tests that duplicated container has lenient runtime checks
func test_duplicated_container_has_lenient_runtime_checks() -> void:
	# Set up strict checks on original
	_original_container.config.settings.runtime_checks.building_system = true
	_original_container.config.settings.runtime_checks.manipulation_system = true
	_original_container.config.settings.runtime_checks.targeting_system = true

	# Assign and duplicate
	_test_injector.composition_container = _original_container
	_test_injector._duplicate_container_if_needed()

	var duplicated: GBCompositionContainer = _test_injector.composition_container

	# Verify runtime checks were made lenient
	(
		assert_bool(duplicated.config.settings.runtime_checks.building_system)
		. append_failure_message("Duplicated container should have lenient building_system check")
		. is_false()
	)

	(
		assert_bool(duplicated.config.settings.runtime_checks.manipulation_system)
		. append_failure_message(
			"Duplicated container should have lenient manipulation_system check"
		)
		. is_false()
	)

	(
		assert_bool(duplicated.config.settings.runtime_checks.targeting_system)
		. append_failure_message("Duplicated container should have lenient targeting_system check")
		. is_false()
	)


## Tests that original container is unaffected by duplication
func test_original_container_unaffected_by_duplication() -> void:
	# Set up original with strict checks
	_original_container.config.settings.runtime_checks.building_system = true

	# Assign and duplicate
	_test_injector.composition_container = _original_container
	_test_injector._duplicate_container_if_needed()

	# Verify original still has strict checks
	(
		assert_bool(_original_container.config.settings.runtime_checks.building_system)
		. append_failure_message("Original container should be unaffected")
		. is_true()
	)


## Tests that test injector maintains state tracking correctly
func test_test_injector_state_tracking() -> void:
	# Initial state
	(
		assert_bool(_test_injector._has_duplicated)
		. append_failure_message("Should start without duplication")
		. is_false()
	)

	# After duplication
	_test_injector.composition_container = _original_container
	_test_injector._duplicate_container_if_needed()

	(
		assert_bool(_test_injector._has_duplicated)
		. append_failure_message("Should track duplication state")
		. is_true()
	)


## Tests that container reset detection works correctly
func test_container_reset_detection() -> void:
	# First assignment
	_test_injector.composition_container = _original_container
	_test_injector._duplicate_container_if_needed()

	(
		assert_object(_test_injector._last_original_container)
		. append_failure_message("Should track last original container")
		. is_equal(_original_container)
	)

	# Reset to new container
	var new_container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	new_container.config = auto_free(GBConfig.new())

	_test_injector.composition_container = new_container
	_test_injector._duplicate_container_if_needed()

	(
		assert_object(_test_injector._last_original_container)
		. append_failure_message("Should update to new original container")
		. is_equal(new_container)
	)

	(
		assert_bool(_test_injector._has_duplicated)
		. append_failure_message("Should allow duplication again after reset")
		. is_true()
	)


## Tests that modifications to duplicated container don't affect original
func test_modifications_dont_leak_to_original() -> void:
	# Assign and duplicate
	_test_injector.composition_container = _original_container
	_test_injector._duplicate_container_if_needed()

	var duplicated: GBCompositionContainer = _test_injector.composition_container

	# Modify duplicated container
	duplicated.config.settings.runtime_checks.building_system = false

	# Verify original is unaffected
	(
		assert_bool(_original_container.config.settings.runtime_checks.building_system)
		. append_failure_message("Original should be unaffected by duplicate modifications")
		. is_true()
	)


## Tests that multiple test runs get independent duplicates
func test_multiple_test_runs_get_independent_duplicates() -> void:
	# First test run
	_test_injector.composition_container = _original_container
	_test_injector._duplicate_container_if_needed()
	var first_duplicate: GBCompositionContainer = _test_injector.composition_container

	# Modify first duplicate
	first_duplicate.config.settings.runtime_checks.building_system = false

	# Second test run (new injector simulating new test)
	var second_injector: GBTestInjectorSystem = auto_free(GBTestInjectorSystem.new())
	var second_original: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	second_original.config = auto_free(GBConfig.new())
	second_original.config.settings = auto_free(GBSettings.new())
	second_original.config.settings.runtime_checks = auto_free(GBRuntimeChecks.new())
	second_original.config.settings.runtime_checks.building_system = true

	second_injector.composition_container = second_original
	second_injector._duplicate_container_if_needed()
	var second_duplicate: GBCompositionContainer = second_injector.composition_container

	# Verify second duplicate is independent
	(
		assert_object(second_duplicate)
		. append_failure_message("Second duplicate should be different instance")
		. is_not_equal(first_duplicate)
	)

	# Verify second duplicate has lenient checks (from fresh duplication)
	(
		assert_bool(second_duplicate.config.settings.runtime_checks.building_system)
		. append_failure_message("Second duplicate should have lenient checks")
		. is_false()
	)


## Tests that null container is handled gracefully
func test_null_container_handled_gracefully() -> void:
	_test_injector.composition_container = null
	_test_injector._duplicate_container_if_needed()

	# Should not crash, just remain null
	(
		assert_object(_test_injector.composition_container)
		. append_failure_message("Null container should remain null")
		. is_null()
	)

	(
		assert_bool(_test_injector._has_duplicated)
		. append_failure_message("Duplication flag should remain false for null")
		. is_false()
	)
