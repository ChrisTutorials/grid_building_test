## Debug test to figure out why enter_build_mode is failing
class_name BuildModeDebugTest
extends GdUnitTestSuite

var test_env: AllSystemsTestEnvironment

func before_test() -> void:
	test_env = UnifiedTestFactory.instance_all_systems_env(self, "uid://ioucajhfxc8b")

func after_test() -> void:
	if test_env != null:
		test_env.queue_free()

## Test: Debug enter_build_mode failure step by step
func test_debug_enter_build_mode_failure() -> void:
	var building_system: BuildingSystem = test_env.building_system
	var smithy_placeable: Resource = load("uid://dirh6mcrgdm3w")
	
	# Check preconditions first
	print("=== DEBUG enter_build_mode failure ===")
	print("BuildingSystem: ", building_system)
	print("Placeable: ", smithy_placeable)
	
	# Check if IndicatorManager is properly registered
	var container: GBCompositionContainer = test_env.get_container()
	var indicator_context: IndicatorContext = container.get_contexts().indicator
	print("IndicatorContext: ", indicator_context)
	if indicator_context != null:
		print("Has IndicatorManager: ", indicator_context.has_manager())
	else:
		print("IndicatorContext is null")
	
	if indicator_context != null and indicator_context.has_manager():
		print("IndicatorManager: ", indicator_context.get_manager())
	
	# Check building system runtime issues
	var building_issues: Array[String] = building_system.get_runtime_issues()
	print("Building system issues: ", building_issues)
	
	# Check if BuildingSystem thinks it's ready
	var ready_check: bool = building_system.check_ready_to_build()
	print("check_ready_to_build(): ", ready_check)
	
	# Try enter_build_mode and see what happens
	print("\n=== Calling enter_build_mode ===")
	var setup_report: PlacementReport = building_system.enter_build_mode(smithy_placeable)
	print("Setup report: ", setup_report)
	print("Setup report type: ", setup_report.get_class() if setup_report != null else "null")
	
	if setup_report != null:
		print("Is successful: ", setup_report.is_successful())
		print("All issues: ", setup_report.get_all_issues())
		
		if setup_report.has_method("get_error_messages"):
			print("Error messages: ", setup_report.get_error_messages())
		if setup_report.has_method("to_verbose_string"):
			print("Verbose: ", setup_report.to_verbose_string())
	
	# For debugging, don't fail the test, just print info
	assert_that(setup_report).is_not_null().override_failure_message("Setup report should exist for debugging")
