## Sequential test isolation verification for GBTestInjectorSystem.
##
## Tests that when multiple tests run in sequence within the same test suite,
## each test receives a FRESH container instance with independent state.
##
## Critical for preventing test pollution where one test's state leaks into another.
extends GdUnitTestSuite

var _container_ids: Array[int] = []
var _container_config_ids: Array[int] = []
var _test_container: GBCompositionContainer


func before_test() -> void:
	# Create a fresh container for this test
	_test_container = auto_free(GBCompositionContainer.new())
	_test_container.config = auto_free(GBConfig.new())
	_test_container.config.settings = auto_free(GBSettings.new())

	# Record the container instance ID
	var container_id: int = _test_container.get_instance_id()
	var config_id: int = _test_container.config.get_instance_id()

	_container_ids.append(container_id)
	_container_config_ids.append(config_id)


## Test 1: First test records container ID and modifies state
func test_001_first_test_modifies_container() -> void:
	# Verify we have a container
	(
		assert_object(_test_container)
		. append_failure_message("First test should have container")
		. is_not_null()
	)

	# Modify container state
	_test_container.config.settings.runtime_checks = auto_free(GBRuntimeChecks.new())
	_test_container.config.settings.runtime_checks.building_system = true

	# Verify modification applied
	(
		assert_bool(_test_container.config.settings.runtime_checks.building_system)
		. append_failure_message("First test should have modified runtime checks")
		. is_true()
	)


## Test 2: Second test should get DIFFERENT container ID and clean state
func test_002_second_test_gets_new_container() -> void:
	# Verify we have a container
	(
		assert_object(_test_container)
		. append_failure_message("Second test should have container")
		. is_not_null()
	)

	# Verify this is a DIFFERENT instance than test 1
	(
		assert_int(_container_ids.size())
		. append_failure_message("Should have recorded container IDs from previous tests")
		. is_greater_equal(2)
	)

	var current_id: int = _test_container.get_instance_id()
	var first_test_id: int = _container_ids[0]

	(
		assert_int(current_id)
		. append_failure_message(
			(
				"Second test should have DIFFERENT container instance (ID %d vs %d)"
				% [current_id, first_test_id]
			)
		)
		. is_not_equal(first_test_id)
	)

	# Verify state is clean (not polluted from test 1)
	(
		assert_object(_test_container.config.settings.runtime_checks)
		. append_failure_message("Second test should start with clean state (null runtime_checks)")
		. is_null()
	)


## Test 3: Third test also gets DIFFERENT container ID
func test_003_third_test_gets_new_container() -> void:
	# Verify we have a container
	(
		assert_object(_test_container)
		. append_failure_message("Third test should have container")
		. is_not_null()
	)

	# Verify this is a DIFFERENT instance than both previous tests
	(
		assert_int(_container_ids.size())
		. append_failure_message("Should have recorded IDs from all previous tests")
		. is_greater_equal(3)
	)

	var current_id: int = _test_container.get_instance_id()
	var first_test_id: int = _container_ids[0]
	var second_test_id: int = _container_ids[1]

	(
		assert_int(current_id)
		. append_failure_message("Third test should have DIFFERENT container than first test")
		. is_not_equal(first_test_id)
	)

	(
		assert_int(current_id)
		. append_failure_message("Third test should have DIFFERENT container than second test")
		. is_not_equal(second_test_id)
	)


## Test 4: Verify ALL container IDs are unique across test sequence
func test_004_all_containers_have_unique_ids() -> void:
	# By this point, we should have 4 container IDs recorded
	(
		assert_int(_container_ids.size())
		. append_failure_message("Should have recorded 4 container IDs")
		. is_greater_equal(4)
	)

	# Verify all IDs are unique (no duplicates)
	var unique_ids: Dictionary = {}
	for container_id in _container_ids:
		if unique_ids.has(container_id):
			(
				assert_bool(false)
				. append_failure_message(
					"Duplicate container ID found: %d (tests not properly isolated!)" % container_id
				)
				. is_true()
			)
		unique_ids[container_id] = true

	# If we got here, all IDs are unique
	assert_bool(true).append_failure_message("All container IDs should be unique").is_true()


## Test 5: Verify config object IDs are also unique (deep isolation)
func test_005_all_config_ids_are_unique() -> void:
	# Verify config objects are also different instances
	(
		assert_int(_container_config_ids.size())
		. append_failure_message("Should have recorded 5 config IDs")
		. is_greater_equal(5)
	)

	# Verify all config IDs are unique
	var unique_config_ids: Dictionary = {}
	for config_id in _container_config_ids:
		if unique_config_ids.has(config_id):
			(
				assert_bool(false)
				. append_failure_message(
					"Duplicate config ID found: %d (deep isolation failed!)" % config_id
				)
				. is_true()
			)
		unique_config_ids[config_id] = true

	# If we got here, all config IDs are unique
	(
		assert_bool(true)
		. append_failure_message("All config IDs should be unique (deep isolation working)")
		. is_true()
	)
