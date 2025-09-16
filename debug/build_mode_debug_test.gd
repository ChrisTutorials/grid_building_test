## Debug test to figure out why enter_build_mode is failing
class_name BuildModeDebugTest
extends GdUnitTestSuite

var test_env: AllSystemsTestEnvironment
var placeable : Placeable = preload("uid://cqknt0ejxvq4m")

func before_test() -> void:
	test_env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)

func after_test() -> void:
	if test_env != null:
		test_env.queue_free()

## Test: Debug enter_build_mode failure step by step
func test_debug_enter_build_mode_failure() -> void:
	var building_system: BuildingSystem = test_env.building_system
	var smithy_placeable: Resource = load("uid://dirh6mcrgdm3w")
	
	# Check preconditions first
	assert_that(building_system).append_failure_message("BuildingSystem should be initialized").is_not_null()
	assert_that(smithy_placeable).append_failure_message("Smithy placeable should load successfully").is_not_null()
	
	# Check if IndicatorManager is properly registered
	var container: GBCompositionContainer = test_env.get_container()
	assert_that(container).append_failure_message("Composition container should exist").is_not_null()
	
	var indicator_context: IndicatorContext = container.get_contexts().indicator
	assert_that(indicator_context).append_failure_message("Indicator context should be available").is_not_null()
	assert_that(indicator_context.has_manager()).is_true().append_failure_message("Indicator manager should be registered")
	
	var indicator_manager: IndicatorManager = indicator_context.get_manager()
	assert_that(indicator_manager).append_failure_message("Indicator manager instance should exist").is_not_null()

	# Check building system runtime issues
	var building_issues: Array[String] = building_system.get_runtime_issues()
	assert_that(building_issues).append_failure_message("Building system should have no runtime issues, but found: " + str(building_issues)).is_empty()
	
	# Check if BuildingSystem thinks it's ready. Placeable must be set to pass ready check
	building_system.selected_placeable = placeable
	var ready_check: bool = building_system.is_ready_to_place()
	assert_that(ready_check).append_failure_message("Building system should be ready to build. Issues: %s" % str(building_issues)).is_true()
	# Try enter_build_mode and verify success
	var setup_report: PlacementReport = building_system.enter_build_mode(smithy_placeable)
	assert_that(setup_report).append_failure_message("Setup report should exist").is_not_null()
	assert_that(setup_report.is_successful()).append_failure_message("Enter build mode should succeed. Issues: " + str(setup_report.get_all_issues())).is_true()
