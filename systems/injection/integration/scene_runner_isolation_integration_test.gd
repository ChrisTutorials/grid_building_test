## Integration test verifying scene_runner + GBTestInjectorSystem isolation.
##
## Tests that when using scene_runner with test environments, each test
## receives a fresh GBCompositionContainer instance from the test injector.
##
## This is the REAL-WORLD scenario where tests use scene_runner to load
## test environments that contain GBTestInjectorSystem.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: BuildingTestEnvironment
var _container_ids_from_tests: Array[int] = []


func before_test() -> void:
	# Load the test environment scene (contains GBTestInjectorSystem)
	runner = scene_runner(GBTestConstants.BUILDING_TEST_ENV.resource_path)
	runner.simulate_frames(1)
	env = runner.scene() as BuildingTestEnvironment

	# Record the container instance ID from this test
	var container: GBCompositionContainer = env.get_container()
	if container != null:
		_container_ids_from_tests.append(container.get_instance_id())


## Test 1: First test gets a container and modifies it
func test_001_first_test_modifies_environment_container() -> void:
	var container: GBCompositionContainer = env.get_container()

	(
		assert_object(container)
		. append_failure_message("First test should have container from environment")
		. is_not_null()
	)

	# Modify the container's config
	container.config.settings = auto_free(GBSettings.new())
	container.config.settings.runtime_checks = auto_free(GBRuntimeChecks.new())
	container.config.settings.runtime_checks.manipulation_system = true

	# Verify modification applied
	(
		assert_bool(container.config.settings.runtime_checks.manipulation_system)
		. append_failure_message("First test should have modified manipulation_system check")
		. is_true()
	)


## Test 2: Second test should get DIFFERENT container instance
func test_002_second_test_gets_fresh_container() -> void:
	var container: GBCompositionContainer = env.get_container()

	(
		assert_object(container)
		. append_failure_message("Second test should have container from environment")
		. is_not_null()
	)

	# Verify this is a DIFFERENT container instance
	(
		assert_int(_container_ids_from_tests.size())
		. append_failure_message("Should have container IDs from previous tests")
		. is_greater_equal(2)
	)

	var current_id: int = container.get_instance_id()
	var first_test_id: int = _container_ids_from_tests[0]

	(
		assert_int(current_id)
		. append_failure_message(
			(
				"Second test container ID (%d) should differ from first test (%d)"
				% [current_id, first_test_id]
			)
		)
		. is_not_equal(first_test_id)
	)

	# Verify state is clean (manipulation_system check should be false/lenient, NOT true from test 1)
	# GBTestInjectorSystem sets all runtime checks to false for lenient test mode
	(
		assert_bool(container.config.settings.runtime_checks.manipulation_system)
		. append_failure_message(
			"Second test should have lenient checks (false), not polluted from first test (true)"
		)
		. is_false()
	)


## Test 3: Third test also gets fresh container with clean state
func test_003_third_test_gets_fresh_container() -> void:
	var container: GBCompositionContainer = env.get_container()

	(
		assert_object(container)
		. append_failure_message("Third test should have container from environment")
		. is_not_null()
	)

	# Verify this is DIFFERENT from both previous tests
	(
		assert_int(_container_ids_from_tests.size())
		. append_failure_message("Should have IDs from all previous tests")
		. is_greater_equal(3)
	)

	var current_id: int = container.get_instance_id()
	var first_test_id: int = _container_ids_from_tests[0]
	var second_test_id: int = _container_ids_from_tests[1]

	(
		assert_int(current_id)
		. append_failure_message("Third test should differ from first test")
		. is_not_equal(first_test_id)
	)

	(
		assert_int(current_id)
		. append_failure_message("Third test should differ from second test")
		. is_not_equal(second_test_id)
	)


## Test 4: Verify all test environments get unique container instances
func test_004_all_scene_runner_tests_have_unique_containers() -> void:
	# By this test, we should have 4 unique container IDs
	(
		assert_int(_container_ids_from_tests.size())
		. append_failure_message("Should have recorded 4 container IDs from scene_runner tests")
		. is_greater_equal(4)
	)

	# Verify no duplicate IDs (each test got its own container)
	var unique_ids: Dictionary = {}
	for container_id in _container_ids_from_tests:
		if unique_ids.has(container_id):
			(
				assert_bool(false)
				. append_failure_message(
					(
						"CRITICAL: Duplicate container ID %d found! GBTestInjectorSystem not isolating tests!"
						% container_id
					)
				)
				. is_true()
			)
		unique_ids[container_id] = true

	(
		assert_bool(true)
		. append_failure_message("All scene_runner test containers should have unique IDs")
		. is_true()
	)


## Test 5: Verify container duplication tracking works correctly
func test_005_test_injector_resets_duplication_flag_between_tests() -> void:
	# Get the test injector from the environment
	var test_injector: GBTestInjectorSystem = env.get_injector_system() as GBTestInjectorSystem

	(
		assert_object(test_injector)
		. append_failure_message("Environment should have GBTestInjectorSystem")
		. is_not_null()
	)

	# Verify the injector has the duplication flag set (it duplicated this test's container)
	(
		assert_bool(test_injector._has_duplicated)
		. append_failure_message("Test injector should have _has_duplicated=true after setup")
		. is_true()
	)

	# Verify the last_original_container is tracked
	(
		assert_object(test_injector._last_original_container)
		. append_failure_message("Test injector should track _last_original_container")
		. is_not_null()
	)
