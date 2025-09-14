## class_name TestDebugHelpers
## Debug helpers for placement manager tests to reduce duplication and improve debuggability

## Helper to create a minimal test environment with proper cleanup tracking
static func create_minimal_test_environment(test_suite: GdUnitTestSuite) -> Dictionary:
	var env: Dictionary = {}
	
	# Create container and injector
	var container: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")
	var injector: GBInjectorSystem = UnifiedTestFactory.create_test_injector(test_suite, container)
	
	# Create map with proper cleanup
	var map: TileMapLayer = test_suite.auto_free(TileMapLayer.new())
	map.tile_set = TileSet.new()
	map.tile_set.tile_size = Vector2(16, 16)
	test_suite.add_child(map)
	
	# Create positioner
	var positioner: Node2D = test_suite.auto_free(Node2D.new())
	positioner.name = "TestPositioner"
	test_suite.add_child(positioner)
	positioner.global_position = map.to_global(map.map_to_local(Vector2i.ZERO))
	
	# Set up targeting state
	var targeting_state: GridTargetingState = container.get_targeting_state()
	targeting_state.target_map = map
	targeting_state.maps = [map]
	targeting_state.positioner = positioner
	
	# Set up manipulation parent
	var manipulation_parent: Node2D = test_suite.auto_free(Node2D.new())
	manipulation_parent.name = "ManipulationParent"
	positioner.add_child(manipulation_parent)
	container.get_states().manipulation.parent = manipulation_parent
	
	# Set up owner context
	var owner_context: GBOwnerContext = container.get_contexts().owner
	var owner_node: Node2D = test_suite.auto_free(Node2D.new())
	owner_node.name = "TestOwner"
	test_suite.add_child(owner_node)
	var gb_owner: GBOwner = test_suite.auto_free(GBOwner.new(owner_node))
	owner_context.set_owner(gb_owner)
	
	# Set up placed parent
	var placed_parent: Node2D = test_suite.auto_free(Node2D.new())
	placed_parent.name = "PlacedParent"
	container.get_states().building.placed_parent = placed_parent
	test_suite.add_child(placed_parent)
	
	env.container = container
	env.injector = injector
	env.map = map
	env.positioner = positioner
	env.manipulation_parent = manipulation_parent
	env.targeting_state = targeting_state
	env.owner_context = owner_context
	env.placed_parent = placed_parent
	
	return env

## Helper to create and validate an indicator manager with proper error reporting
static func create_indicator_manager_with_validation(test_suite: GdUnitTestSuite, env: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	
	# Create indicator manager
	var manager: IndicatorManager = IndicatorManager.create_with_injection(env.container)
	manager.name = "TestIndicatorManager"
	env.manipulation_parent.add_child(manager)
	test_suite.auto_free(manager)
	
	# Validate targeting state
	var issues: Array[String] = env.targeting_state.get_runtime_issues()
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
static func validate_building_system_entry(test_suite: GdUnitTestSuite, env: Dictionary, placeable: Placeable) -> Dictionary:
	var result : Dictionary = {}
	
	# Create building system
	var building_system: BuildingSystem = BuildingSystem.create_with_injection(env.container)
	building_system.name = "TestBuildingSystem"
	test_suite.add_child(building_system)
	test_suite.auto_free(building_system)
	
	# Attempt to enter build mode
	var report: PlacementReport = building_system.enter_build_mode(placeable)
	
	result.building_system = building_system
	result.report = report
	result.is_successful = report.is_successful() if report else false
	result.preview = env.container.get_building_state().preview if result.is_successful else null
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
static func cleanup_test_environment(env: Dictionary) -> void:
	# Clear any remaining references
	if env.has("container"):
		env.container = null
	if env.has("injector"):
		env.injector = null
