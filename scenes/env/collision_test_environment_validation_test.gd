## Name: CollisionTestEnvironmentValidationTest
## Unit test to validate CollisionTestEnvironment scene integrity
## Tests that collision-specific systems are properly initialized and connected
extends GdUnitTestSuite

var test_env: CollisionTestEnvironment

func before_test() -> void:
	# Use EnvironmentTestFactory for validation tests - provides guaranteed initialization
	# and automatic container duplication for test isolation
	test_env = EnvironmentTestFactory.create_collision_test_environment(self)

func after_test() -> void:
	# EnvironmentTestFactory handles cleanup automatically
	pass

## Test: Core systems from GBTestEnvironment are present
func test_core_systems_present() -> void:
	assert_that(test_env.injector).append_failure_message("GBInjectorSystem should be present").is_not_null()
	assert_that(test_env.grid_targeting_system).append_failure_message("GridTargetingSystem should be present").is_not_null()
	assert_that(test_env.positioner).append_failure_message("GridPositioner2D should be present").is_not_null()
	assert_that(test_env.world).append_failure_message("World node should be present").is_not_null()
	assert_that(test_env.level).append_failure_message("Level node should be present").is_not_null()
	assert_that(test_env.level_context).append_failure_message("GBLevelContext should be present").is_not_null()
	assert_that(test_env.tile_map_layer).append_failure_message("TileMapLayer should be present").is_not_null()
	assert_that(test_env.objects_parent).append_failure_message("Objects parent should be present").is_not_null()
	assert_that(test_env.placer).append_failure_message("Placer should be present").is_not_null()

## Test: Environment integrity check
func test_environment_has_no_issues() -> void:
	var issues: Array[String] = test_env.get_issues()
	assert_array(issues).append_failure_message("CollisionTestEnvironment should have no issues: " + str(issues)).is_empty()

## Test: Dependency injection is working
func test_dependency_injection_setup() -> void:
	var injector_issues: Array[String] = test_env.injector.get_runtime_issues()
	assert_array(injector_issues).append_failure_message("Injector should have no runtime issues: " + str(injector_issues)).is_empty()

	var container: GBCompositionContainer = test_env.get_container()
	assert_that(container).append_failure_message("Composition container should exist").is_not_null()

## Test: Grid targeting system setup (important for collision testing)
func test_grid_targeting_system_setup() -> void:
	var targeting_issues: Array[String] = test_env.grid_targeting_system.get_runtime_issues()
	assert_array(targeting_issues).append_failure_message("GridTargetingSystem should have no runtime issues: " + str(targeting_issues)).is_empty()

	# The positioner should be available for collision testing
	assert_that(test_env.positioner).append_failure_message("Positioner should be available for collision testing").is_not_null()

## Test: Level context validation
func test_level_context_validation() -> void:
	var level_issues: Array[String] = test_env.level_context.get_runtime_issues()
	assert_array(level_issues).append_failure_message("LevelContext should have no runtime issues: " + str(level_issues)).is_empty()

## Test: Collision-specific functionality
func test_collision_environment_specific() -> void:
	# CollisionTestEnvironment should provide basic collision testing capabilities
	# The positioner should be ready for collision queries
	assert_that(test_env.positioner).append_failure_message("Positioner should be ready for collision queries").is_not_null()

	# Level context should be set up for collision validation
	assert_that(test_env.level_context).append_failure_message("LevelContext should be available for collision validation").is_not_null()

## Test: Container accessibility
func test_container_access() -> void:
	var container: GBCompositionContainer = test_env.get_container()
	assert_that(container).append_failure_message("Composition container should be accessible").is_not_null()
