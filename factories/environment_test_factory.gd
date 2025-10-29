## Environment Test Factory
##
## HYBRID APPROACH: Use EnvironmentTestFactory for environment validation tests,
## scene_runner for tests requiring frame simulation.
##
## ## When to Use EnvironmentTestFactory
##
## - **Environment validation tests** that check get_issues() and system initialization
## - Tests that benefit from guaranteed synchronous initialization waits
##
## ## When to Use scene_runner
##
## - **Tests requiring simulate_frames()** for physics/animation testing
## - Tests needing async input processing (await_input_processed())
## - Most integration and interaction tests
##
## ## Migration Pattern
##
## **Environment validation (use EnvironmentTestFactory):**
## [codeblock]
## func before_test() -> void:
##     test_env = EnvironmentTestFactory.create_collision_test_environment(self)
## [/codeblock]
##
## **Frame simulation tests (use scene_runner):**
## [codeblock]
## func before_test() -> void:
##     runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
##     runner.simulate_frames(2)  # For physics initialization
##     env = runner.scene() as CollisionTestEnvironment
## [/codeblock]
##
## ## Isolation Guarantee
##
## Both approaches provide automatic GBCompositionContainer duplication for test isolation
## through GBTestInjectorSystem._duplicate_container_if_needed() during scene initialization.
##
## Following GdUnit best practices: DRY principle, centralize common object creation

class_name EnvironmentTestFactory


## @deprecated Use scene_runner for frame simulation tests, keep EnvironmentTestFactory for validation tests
## Creates an AllSystemsTestEnvironment (extracted from the legacy unified factory implementation) [br]
## [param test]: Test instance for node management [br]
## [param scene_resource]: PackedScene or Scene UID string for environment setup
static func create_all_systems_env(
	test: GdUnitTestSuite, scene_resource: Variant = GBTestConstants.ALL_SYSTEMS_ENV
) -> AllSystemsTestEnvironment:
	var scene: PackedScene
	if scene_resource is PackedScene:
		scene = scene_resource
	else:
		scene = load(scene_resource)
	var env: AllSystemsTestEnvironment = scene.instantiate()
	_prepare_test_environment_sync(test, env)
	return env


## @deprecated Use scene_runner for frame simulation tests, keep EnvironmentTestFactory for validation tests
## Creates a basic building system test environment
## [param test]: Test instance for node management
## [param scene]: Preloaded scene for environment setup
static func create_building_system_test_environment(
	test: GdUnitTestSuite, scene: PackedScene = GBTestConstants.BUILDING_TEST_ENV
) -> BuildingTestEnvironment:
	var env: BuildingTestEnvironment = scene.instantiate()
	# Pass the environment directly; it already extends GBTestEnvironment.
	_prepare_test_environment_sync(test, env)
	return env


## @deprecated Use scene_runner(GBTestConstants.COLLISION_TEST_ENV) instead
## Creates an indicator manager test environment
## [param test]: Test instance for node management
## [param scene]: Preloaded scene for environment setup
static func create_collision_test_environment(
	test: GdUnitTestSuite, scene: PackedScene = GBTestConstants.COLLISION_TEST_ENV
) -> CollisionTestEnvironment:
	var env: CollisionTestEnvironment = scene.instantiate()
	_prepare_test_environment_sync(test, env)
	return env


## Add shared test suite setup so it is parented and tears down after test properly.
## Synchronous version - does not validate, just sets up the node hierarchy
static func _prepare_test_environment_sync(test: GdUnitTestSuite, env: GBTestEnvironment) -> void:
	test.add_child(env)
	test.auto_free(env)


## Add shared test suite setup so it is parented and tears down after test properly.
## Validates environment setup and fails test if issues found.
static func _prepare_test_environment(test: GdUnitTestSuite, env: GBTestEnvironment) -> bool:
	test.add_child(env)
	test.auto_free(env)

	# CRITICAL: Wait for the scene tree to process so _ready() is called on all nodes
	# This ensures the injector and other systems have initialized before validation
	await test.get_tree().process_frame
	await test.get_tree().process_frame  # Extra frame for dependency injection to complete

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
		var logger: GBLogger = env.get_container().get_logger()
		logger.log_error("Environment has setup issues: %s" % str(issues))

	return issues.is_empty()


## Validates that an environment is properly set up without issues
## @param env: The environment to validate
## @param context: Context string for error messages
static func validate_environment_setup(
	env: AllSystemsTestEnvironment, context: String = "Test environment"
) -> bool:
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
static func validate_required_dependencies(
	env: AllSystemsTestEnvironment, required_systems: Array[String] = []
) -> bool:
	if not validate_environment_setup(env, "Environment dependency validation"):
		return false

	# Default system checks
	var default_systems: Array[String] = [
		"building_system", "indicator_manager", "grid_targeting_system"
	]
	var systems_to_check: Array[String] = (
		required_systems if not required_systems.is_empty() else default_systems
	)

	for system_name: String in systems_to_check:
		var system: Variant = env.get(system_name)
		if system == null:
			push_error("Required system '%s' not available from environment" % system_name)
			return false

	return true
