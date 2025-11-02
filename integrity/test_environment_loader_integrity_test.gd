## Test Environment Loader Integrity Test
##
## Validates that all test environments can be loaded without errors.
## This catches environment setup issues immediately rather than having them
## fail in dozens of actual tests.
##
## Uses single test with loop to avoid parameterization complexity.
## Each environment is validated for: loading, instantiation, type casting, and zero issues.

extends GdUnitTestSuite

#region Test Data

## Environment test configurations
const ENVIRONMENTS: Array[Dictionary] = [
	{"name": "AllSystemsTestEnvironment", "scene": GBTestConstants.ALL_SYSTEMS_ENV},
	{"name": "BuildingTestEnvironment", "scene": GBTestConstants.BUILDING_TEST_ENV},
	{"name": "CollisionTestEnvironment", "scene": GBTestConstants.COLLISION_TEST_ENV},
]

#endregion

## Test all environments load without issues
## Iterates through all test environments validating each one
func test_all_environments_load_without_issues() -> void:
	for env_config in ENVIRONMENTS:
		var env_name: String = env_config.name
		var env_scene: PackedScene = env_config.scene
		
		# Load environment using standard GdUnitSceneRunner pattern
		var runner: GdUnitSceneRunner = scene_runner(env_scene.resource_path)
		runner.simulate_frames(2)
		var env: Node = runner.scene()
		
		# Validate environment loaded
		assert_that(env).append_failure_message(
			"%s failed to load" % env_name
		).is_not_null()
		
		# Validate environment is correct type and has get_issues() method
		var test_env := env as GBTestEnvironment
		assert_that(test_env).append_failure_message(
			"%s is not a GBTestEnvironment" % env_name
		).is_not_null()
		
		# Validate environment has no issues
		var issues: Array[String] = test_env.get_issues()
		assert_that(issues).append_failure_message(
			"%s has issues: %s" % [env_name, issues]
		).is_empty()
