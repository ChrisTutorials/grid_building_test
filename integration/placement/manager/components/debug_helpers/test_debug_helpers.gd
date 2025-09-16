## class_name TestDebugHelpers
## Debug helpers for placement manager tests to reduce duplication and improve debuggability

## Helper to create and validate an indicator manager with proper error reporting
static func create_indicator_manager_with_validation(test_suite: GdUnitTestSuite, env: AllSystemsTestEnvironment) -> Dictionary:
	var result: Dictionary = {}
	
	# Create indicator manager
	var manager: IndicatorManager = IndicatorManager.create_with_injection(env.injector.composition_container)
	manager.name = "TestIndicatorManager"
	env.manipulation_parent.add_child(manager)
	test_suite.auto_free(manager)
	
	# Validate targeting state
	var issues: Array[String] = env.injector.composition_container.get_targeting_state().get_runtime_issues()
	result.manager = manager
	result.setup_issues = issues
	result.is_valid = issues.is_empty()
	
	return result

## Helper to create a basic collision rule for testing
static func create_basic_collision_rule(collision_layer: int = 1) -> CollisionsCheckRule:
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	rule.apply_to_objects_mask = collision_layer
	rule.collision_mask = collision_layer
	return rule

## Helper to validate indicator setup with detailed reporting
static func validate_indicator_setup(manager: IndicatorManager, test_object: Node2D, rules: Array[TileCheckRule]) -> Dictionary:
	var result: Dictionary = {}
	
	# Attempt setup
	var report: IndicatorSetupReport = manager.setup_indicators(test_object, rules)
	
	# Collect detailed information
	result.report = report
	result.indicators = manager.get_indicators() if manager else []
	result.indicator_count = result.indicators.size()
	result.has_issues = report.has_issues()
	result.issues = report.issues.duplicate()
	result.notes = report.notes.duplicate()
	result.summary = _create_setup_summary(result)
	
	return result

## Helper to create a diagnostic summary for debugging
static func _create_setup_summary(validation_result: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("=== Indicator Setup Validation Summary ===")
	lines.append("Indicators Created: %d" % validation_result.indicator_count)
	lines.append("Has Issues: %s" % str(validation_result.has_issues))
	
	if validation_result.issues.size() > 0:
		lines.append("Issues:")
		for issue : String in validation_result.issues:
			lines.append("  - %s" % issue)
	
	if validation_result.notes.size() > 0:
		lines.append("Notes:")
		for note : String in validation_result.notes:
			lines.append("  - %s" % note)
	
	return "\n".join(lines)

## Helper to verify building system can enter build mode
static func validate_building_system_entry(test_suite: GdUnitTestSuite, env: AllSystemsTestEnvironment, placeable: Placeable) -> Dictionary:
	var result : Dictionary = {}
	
	# Create building system
	var building_system: BuildingSystem = BuildingSystem.create_with_injection(env.injector.composition_container)
	building_system.name = "TestBuildingSystem"
	test_suite.add_child(building_system)
	test_suite.auto_free(building_system)
	
	# Attempt to enter build mode
	var report: PlacementReport = building_system.enter_build_mode(placeable)
	
	result.building_system = building_system
	result.report = report
	result.is_successful = report.is_successful() if report else false
	result.preview = env.injector.composition_container.get_building_state().preview if result.is_successful else null
	result.error_summary = _create_build_mode_summary(result)
	
	return result

## Helper to create build mode diagnostic summary
static func _create_build_mode_summary(validation_result: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("=== Build Mode Entry Summary ===")
	lines.append("Entry Successful: %s" % str(validation_result.is_successful))
	lines.append("Has Preview: %s" % str(validation_result.preview != null))
	
	if not validation_result.is_successful and validation_result.report:
		lines.append("Issues: %s" % str(validation_result.report.get_all_issues()))
	
	return "\n".join(lines)

## Helper to cleanup all test nodes and prevent orphans
static func cleanup_test_environment(_env: AllSystemsTestEnvironment) -> void:
	# The environment itself will be auto-freed by the test suite
	# No additional cleanup needed for the strongly typed environment
	pass
