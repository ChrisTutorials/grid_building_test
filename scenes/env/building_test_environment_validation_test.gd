## Unit test to validate BuildingTestEnvironment scene integrity
## Tests that building-specific systems are properly initialized and connected
extends GdUnitTestSuite

var test_env: BuildingTestEnvironment

func before_test() -> void:
	# Use EnvironmentTestFactory for validation tests - provides guaranteed initialization
	# and automatic container duplication for test isolation
	test_env = EnvironmentTestFactory.create_building_system_test_environment(self)

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

## Test: Building-specific systems are present
func test_building_systems_present() -> void:
 assert_that(test_env.building_system).append_failure_message("BuildingSystem should be present").is_not_null()
 assert_that(test_env.gb_owner).append_failure_message("GBOwner should be present").is_not_null()
 assert_that(test_env.manipulation_parent).append_failure_message("ManipulationParent should be present").is_not_null()
 assert_that(test_env.indicator_manager).append_failure_message("IndicatorManager should be present").is_not_null()

## Test: Environment integrity check
func test_environment_has_no_issues() -> void:
	var issues: Array[String] = test_env.get_issues()
 assert_array(issues).append_failure_message("BuildingTestEnvironment should have no issues: " + str(issues).is_empty()

## Test: Dependency injection is working
func test_dependency_injection_setup() -> void:
	var injector_issues: Array[String] = test_env.injector.get_runtime_issues()
 assert_array(injector_issues).append_failure_message("Injector should have no runtime issues: " + str(injector_issues).is_empty()

	var container: GBCompositionContainer = test_env.get_container()
 assert_that(container).append_failure_message("Composition container should exist").is_not_null()

## Test: BuildingSystem is properly connected
func test_building_system_connectivity() -> void:
	var building_issues: Array[String] = test_env.building_system.get_runtime_issues()
 assert_array(building_issues).append_failure_message("BuildingSystem should have no runtime issues: " + str(building_issues).is_empty()

## Test: IndicatorManager is available and registered
func test_indicator_manager_registration() -> void:
	# IndicatorManager should be accessible directly
 assert_that(test_env.indicator_manager).append_failure_message("IndicatorManager should be accessible").is_not_null()

	# IndicatorManager should be registered with BuildingSystem's context
	var indicator_context: Variant = test_env.building_system._indicator_context
	if indicator_context != null:
		assert_that(indicator_context.has_manager()).is_true().append_failure_message("IndicatorContext should have IndicatorManager registered")

## Test: Scene hierarchy is correct
func test_scene_node_structure() -> void:
	# Validate key building test environment paths
	assert_that(test_env.get_node_or_null("World")).is_not_null().append_failure_message("World node should exist")
	assert_that(test_env.get_node_or_null("World/GridPositioner2D")).is_not_null().append_failure_message("GridPositioner2D should exist")
	assert_that(test_env.get_node_or_null("World/GridPositioner2D/ManipulationParent")).is_not_null().append_failure_message("ManipulationParent should exist")
	assert_that(test_env.get_node_or_null("World/GridPositioner2D/ManipulationParent/IndicatorManager")).is_not_null().append_failure_message("IndicatorManager should exist at expected path")

## Test: Grid targeting system has proper setup
func test_grid_targeting_system_setup() -> void:
	var targeting_issues: Array[String] = test_env.grid_targeting_system.get_runtime_issues()
 assert_array(targeting_issues).append_failure_message("GridTargetingSystem should have no runtime issues: " + str(targeting_issues).is_empty()

	# The positioner should be available for targeting system
 assert_that(test_env.positioner).append_failure_message("Positioner should be available for targeting system").is_not_null()

## Test: Level context validation
func test_level_context_validation() -> void:
	var level_issues: Array[String] = test_env.level_context.get_runtime_issues()
 assert_array(level_issues).append_failure_message("LevelContext should have no runtime issues: " + str(level_issues).is_empty()

## Test: Owner root is accessible
func test_owner_root_access() -> void:
	var owner_root: Node = test_env.get_owner_root()
 assert_that(owner_root).append_failure_message("Owner root should be accessible through environment").is_not_null()
