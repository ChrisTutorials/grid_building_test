## Unit test to validate BuildingTestEnvironment scene integrity
## Tests that building-specific systems are properly initialized and connected
class_name BuildingTestEnvironmentValidationTest
extends GdUnitTestSuite

var test_env: BuildingTestEnvironment
var runner: GdUnitSceneRunner

func before_test() -> void:
	# Load the BuildingTestEnvironment scene using scene_runner pattern
	runner = scene_runner(GBTestConstants.BUILDING_TEST_ENV_UID)
	test_env = runner.scene() as BuildingTestEnvironment

func after_test() -> void:
	# scene_runner handles cleanup automatically
	pass

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

## Test: Building-specific systems are present  
func test_building_systems_present() -> void:
	assert_that(test_env.building_system).is_not_null().override_failure_message("BuildingSystem should be present")
	assert_that(test_env.gb_owner).is_not_null().override_failure_message("GBOwner should be present")
	assert_that(test_env.manipulation_parent).is_not_null().override_failure_message("ManipulationParent should be present")
	assert_that(test_env.indicator_manager).is_not_null().override_failure_message("IndicatorManager should be present")

## Test: Environment integrity check
func test_environment_has_no_issues() -> void:
	var issues: Array[String] = test_env.get_issues()
	assert_array(issues).is_empty().override_failure_message("BuildingTestEnvironment should have no issues: " + str(issues))

## Test: Dependency injection is working
func test_dependency_injection_setup() -> void:
	var injector_issues: Array[String] = test_env.injector.get_runtime_issues()
	assert_array(injector_issues).is_empty().override_failure_message("Injector should have no runtime issues: " + str(injector_issues))
	
	var container: GBCompositionContainer = test_env.get_container()
	assert_that(container).is_not_null().override_failure_message("Composition container should exist")

## Test: BuildingSystem is properly connected
func test_building_system_connectivity() -> void:
	var building_issues: Array[String] = test_env.building_system.get_runtime_issues()
	assert_array(building_issues).is_empty().override_failure_message("BuildingSystem should have no runtime issues: " + str(building_issues))

## Test: IndicatorManager is available and registered
func test_indicator_manager_registration() -> void:
	# IndicatorManager should be accessible directly
	assert_that(test_env.indicator_manager).is_not_null().override_failure_message("IndicatorManager should be accessible")
	
	# IndicatorManager should be registered with BuildingSystem's context
	var indicator_context: Variant = test_env.building_system._indicator_context
	if indicator_context != null:
		assert_that(indicator_context.has_manager()).is_true().override_failure_message("IndicatorContext should have IndicatorManager registered")

## Test: Scene hierarchy is correct
func test_scene_node_structure() -> void:
	# Validate key building test environment paths
	assert_that(test_env.get_node_or_null("World")).is_not_null().override_failure_message("World node should exist")
	assert_that(test_env.get_node_or_null("World/GridPositioner2D")).is_not_null().override_failure_message("GridPositioner2D should exist")
	assert_that(test_env.get_node_or_null("World/GridPositioner2D/ManipulationParent")).is_not_null().override_failure_message("ManipulationParent should exist")
	assert_that(test_env.get_node_or_null("World/GridPositioner2D/ManipulationParent/IndicatorManager")).is_not_null().override_failure_message("IndicatorManager should exist at expected path")

## Test: Grid targeting system has proper setup
func test_grid_targeting_system_setup() -> void:
	var targeting_issues: Array[String] = test_env.grid_targeting_system.get_runtime_issues()
	assert_array(targeting_issues).is_empty().override_failure_message("GridTargetingSystem should have no runtime issues: " + str(targeting_issues))
	
	# The positioner should be available for targeting system
	assert_that(test_env.positioner).is_not_null().override_failure_message("Positioner should be available for targeting system")

## Test: Level context validation
func test_level_context_validation() -> void:
	var level_issues: Array[String] = test_env.level_context.get_runtime_issues()
	assert_array(level_issues).is_empty().override_failure_message("LevelContext should have no runtime issues: " + str(level_issues))

## Test: Owner root is accessible
func test_owner_root_access() -> void:
	var owner_root: Node = test_env.get_owner_root()
	assert_that(owner_root).is_not_null().override_failure_message("Owner root should be accessible through environment")
