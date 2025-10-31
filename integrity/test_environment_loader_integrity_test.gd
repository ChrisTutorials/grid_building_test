## Test Environment Loader Integrity Test
##
## Validates that all test environments can be loaded without errors.
## This catches environment setup issues immediately rather than having them
## fail in dozens of actual tests.
##
## Uses GdUnitSceneRunner directly (standard pattern) to ensure environments
## load, instantiate, and initialize successfully.

extends GdUnitTestSuite

## Test that all systems environment loads without errors
func test_all_systems_environment_loads() -> void:
	var runner: GdUnitSceneRunner = scene_runner(
		GBTestConstants.ALL_SYSTEMS_ENV.resource_path
	)
	runner.simulate_frames(2)
	var env: Node = runner.scene()
	
	assert_that(env).is_not_null().append_failure_message(
		"AllSystemsTestEnvironment failed to load"
	)


## Test that building test environment loads without errors
func test_building_environment_loads() -> void:
	var runner: GdUnitSceneRunner = scene_runner(
		GBTestConstants.BUILDING_TEST_ENV.resource_path
	)
	runner.simulate_frames(2)
	var env: Node = runner.scene()
	
	assert_that(env).is_not_null().append_failure_message(
		"BuildingTestEnvironment failed to load"
	)


## Test that collision test environment loads without errors
func test_collision_environment_loads() -> void:
	var runner: GdUnitSceneRunner = scene_runner(
		GBTestConstants.COLLISION_TEST_ENV.resource_path
	)
	runner.simulate_frames(2)
	var env: Node = runner.scene()
	
	assert_that(env).is_not_null().append_failure_message(
		"CollisionTestEnvironment failed to load"
	)


## Test that environment resources in GBTestConstants are valid
func test_environment_resources_are_valid() -> void:
	var env_scenes: Array[PackedScene] = [
		GBTestConstants.ALL_SYSTEMS_ENV,
		GBTestConstants.BUILDING_TEST_ENV,
		GBTestConstants.COLLISION_TEST_ENV,
	]
	
	for scene in env_scenes:
		assert_that(scene).is_not_null().append_failure_message(
			"Environment PackedScene is null"
		)
		
		# Verify it has a valid resource path
		var path: String = scene.resource_path
		assert_that(path.is_empty()).is_false().append_failure_message(
			"Environment has no resource path"
		)
