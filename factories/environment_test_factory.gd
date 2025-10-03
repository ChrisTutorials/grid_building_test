## Environment Test Factory
##
## ⚠️ DEPRECATED: This factory class is deprecated in favor of GdUnitSceneRunner pattern.
##
## ## Migration Guide
##
## **Old pattern (deprecated):**
## [codeblock]
## var env: CollisionTestEnvironment = EnvironmentTestFactory.create_collision_test_environment(self)
## [/codeblock]
##
## **New pattern (recommended):**
## [codeblock]
## var runner: GdUnitSceneRunner
## var env: CollisionTestEnvironment
##
## func before_test() -> void:
##     runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
##     runner.simulate_frames(2)  # Initial setup frames
##     env = runner.scene() as CollisionTestEnvironment
##
## func after_test() -> void:
##     runner = null
## [/codeblock]
##
## ## Why Scene Runner?
##
## - **Deterministic**: Explicit frame control eliminates timing-based flakiness
## - **Reliable**: No dependency on real-time physics or scene tree timing
## - **Maintainable**: Standard GdUnit4 pattern used across the codebase
## - **Clean**: Automatic cleanup through GdUnit lifecycle management
##
## ## Available Test Environments
##
## - [code]GBTestConstants.ALL_SYSTEMS_ENV_UID[/code] - Complete system integration
## - [code]GBTestConstants.BUILDING_TEST_ENV_UID[/code] - Building system focused
## - [code]GBTestConstants.COLLISION_TEST_ENV_UID[/code] - Collision and placement
## - [code]GBTestConstants.ISOMETRIC_TEST_ENV_UID[/code] - Isometric tile testing
##
## See existing tests using scene runner pattern:
## - [code]collisions_check_rule_exclusion_test.gd[/code]
## - [code]preview_self_collision_exclusion_test.gd[/code]
## - [code]drag_building_race_condition_test.gd[/code]
##
## Following GdUnit best practices: DRY principle, centralize common object creation
class_name EnvironmentTestFactory
extends RefCounted

## @deprecated Use scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID) instead
## Creates an AllSystemsTestEnvironment (extracted from UnifiedTestFactory) [br]
## [param test]: Test instance for node management [br]
## [param scene_uid]: Scene UID for environment setup
static func create_all_systems_env(test: GdUnitTestSuite, scene_uid: String = GBTestConstants.ALL_SYSTEMS_ENV_UID) -> AllSystemsTestEnvironment:
	push_warning("EnvironmentTestFactory.create_all_systems_env() is deprecated. Use scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID) instead for deterministic frame control.")
	var env: AllSystemsTestEnvironment = load(scene_uid).instantiate()
	if not _prepare_test_environment(test, env):
		return null
	return env

## @deprecated Use scene_runner(GBTestConstants.BUILDING_TEST_ENV_UID) instead
## Creates a basic building system test environment
## [param test]: Test instance for node management
## [param scene_uid]: Scene UID for environment setup
static func create_building_system_test_environment(test: GdUnitTestSuite, scene_uid: String = GBTestConstants.BUILDING_TEST_ENV_PATH) -> BuildingTestEnvironment:
	push_warning("EnvironmentTestFactory.create_building_system_test_environment() is deprecated. Use scene_runner(GBTestConstants.BUILDING_TEST_ENV_UID) instead for deterministic frame control.")
	var env: BuildingTestEnvironment = load(scene_uid).instantiate()
	# Pass the environment directly; it already extends GBTestEnvironment.
	if not _prepare_test_environment(test, env):
		return null
	return env

## @deprecated Use scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID) instead
## Creates an indicator manager test environment
## [param test]: Test instance for node management
## [param scene_uid]: Scene UID for environment setup
static func create_collision_test_environment(test: GdUnitTestSuite, scene_uid: String = GBTestConstants.COLLISION_TEST_ENV_PATH) -> CollisionTestEnvironment:
	push_warning("EnvironmentTestFactory.create_collision_test_environment() is deprecated. Use scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID) instead for deterministic frame control.")
	var env: CollisionTestEnvironment = load(scene_uid).instantiate()
	_prepare_test_environment(test, env)
	return env

## Add shared test suite setup so it is parented and tears down after test properly.
## Validates environment setup and fails test if issues found.
static func _prepare_test_environment(test: GdUnitTestSuite, env: GBTestEnvironment) -> bool:
	test.add_child(env)
	test.auto_free(env)
	
	# Validate environment setup
	var issues: Array[String] = env.get_issues()
	if not issues.is_empty():
		test.fail("Test environment has issues: %s" % str(issues))
		return false
	
	return true

## Validates that an environment is properly set up without issues
static func _validate_test_environment(env: GBTestEnvironment) -> bool:
	# Validate environment setup
	var issues: Array[String] = env.get_issues()
	if not issues.is_empty():
		var logger : GBLogger = env.get_container().get_logger()
		logger.log_error("Environment has setup issues: %s" % str(issues))

	return issues.is_empty()

## Validates that an environment is properly set up without issues
## @param env: The environment to validate
## @param context: Context string for error messages
static func validate_environment_setup(env: AllSystemsTestEnvironment, context: String = "Test environment") -> bool:
	if env == null:
		push_error("%s: environment is null" % context)
		return false
	
	# Use environment's get_issues method for validation
	var issues: Array = env.get_issues()
	if not issues.is_empty():
		push_error("%s has issues: %s" % [context, str(issues)])
		return false
	
	return true

## Validates that required dependencies are available from environment
## @param env: The environment to validate
## @param required_systems: Array of system names to check
static func validate_required_dependencies(env: AllSystemsTestEnvironment, required_systems: Array[String] = []) -> bool:
	if not validate_environment_setup(env, "Environment dependency validation"):
		return false
	
	# Default system checks
	var default_systems: Array[String] = ["building_system", "indicator_manager", "grid_targeting_system"]
	var systems_to_check: Array[String] = required_systems if not required_systems.is_empty() else default_systems
	
	for system_name: String in systems_to_check:
		var system: Variant = env.get(system_name)
		if system == null:
			push_error("Required system '%s' not available from environment" % system_name)
			return false
	
	return true
