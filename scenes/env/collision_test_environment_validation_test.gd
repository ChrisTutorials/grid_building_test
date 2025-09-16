## Name: CollisionTestEnvironmentValidationTest 
## Unit test to validate CollisionTestEnvironment scene integrity
## Tests that collision-specific systems are properly initialized and connected
extends GdUnitTestSuite

var test_env: CollisionTestEnvironment

func before_test() -> void:
	# Load the CollisionTestEnvironment scene directly
	test_env = UnifiedTestFactory.instance_collision_test_env(self, "uid://cdrtd538vrmun")

func after_test() -> void:
	if test_env != null:
		test_env.queue_free()

## Test: Core systems from GBTestEnvironment are present
func test_core_systems_present() -> void:
	assert_that(test_env.injector).is_not_null().override_failure_message("GBInjectorSystem should be present")
	assert_that(test_env.grid_targeting_system).is_not_null().override_failure_message("GridTargetingSystem should be present") 
	assert_that(test_env.positioner).is_not_null().override_failure_message("GridPositioner2D should be present")
	assert_that(test_env.world).is_not_null().override_failure_message("World node should be present")
	assert_that(test_env.level).is_not_null().override_failure_message("Level node should be present")
	assert_that(test_env.level_context).is_not_null().override_failure_message("GBLevelContext should be present")
	assert_that(test_env.tile_map_layer).is_not_null().override_failure_message("TileMapLayer should be present")
	assert_that(test_env.objects_parent).is_not_null().override_failure_message("Objects parent should be present")
	assert_that(test_env.placer).is_not_null().override_failure_message("Placer should be present")

## Test: Environment integrity check
func test_environment_has_no_issues() -> void:
	var issues: Array[String] = test_env.get_issues()
	assert_array(issues).is_empty().override_failure_message("CollisionTestEnvironment should have no issues: " + str(issues))

## Test: Dependency injection is working
func test_dependency_injection_setup() -> void:
	var injector_issues: Array[String] = test_env.injector.get_runtime_issues()
	assert_array(injector_issues).is_empty().override_failure_message("Injector should have no runtime issues: " + str(injector_issues))

	var container: GBCompositionContainer = test_env.get_container()
	assert_that(container).is_not_null().override_failure_message("Composition container should exist")

## Test: Grid targeting system setup (important for collision testing)
func test_grid_targeting_system_setup() -> void:
	var targeting_issues: Array[String] = test_env.grid_targeting_system.get_runtime_issues()
	assert_array(targeting_issues).is_empty().override_failure_message("GridTargetingSystem should have no runtime issues: " + str(targeting_issues))
	
	# The positioner should be available for collision testing
	assert_that(test_env.positioner).is_not_null().override_failure_message("Positioner should be available for collision testing")

## Test: Level context validation
func test_level_context_validation() -> void:
	var level_issues: Array[String] = test_env.level_context.get_runtime_issues()
	assert_array(level_issues).is_empty().override_failure_message("LevelContext should have no runtime issues: " + str(level_issues))

## Test: Collision-specific functionality
func test_collision_environment_specific() -> void:
	# CollisionTestEnvironment should provide basic collision testing capabilities
	# The positioner should be ready for collision queries
	assert_that(test_env.positioner).is_not_null().override_failure_message("Positioner should be ready for collision queries")
	
	# Level context should be set up for collision validation
	assert_that(test_env.level_context).is_not_null().override_failure_message("LevelContext should be available for collision validation")

## Test: Container accessibility
func test_container_access() -> void:
	var container: GBCompositionContainer = test_env.get_container()
	assert_that(container).is_not_null().override_failure_message("Composition container should be accessible")
