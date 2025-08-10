extends GdUnitTestSuite


func test_resource_stack_init():
	var resource_stack = ResourceStack.new()

	assert_object(resource_stack).is_not_null()


func test_building_system_init():
	var building_system = BuildingSystem.new()

	assert_object(building_system).is_not_null()

	building_system.free()


func test_grid_targeter_system_init():
	var grid_targeter_system = GridTargetingSystem.new()

	assert_object(grid_targeter_system).is_not_null()

	grid_targeter_system.free()


func test_rule_check_indicator_init():
	var rule_check_indicator = RuleCheckIndicator.new()

	assert_object(rule_check_indicator).is_not_null()

	rule_check_indicator.free()


func test_rule_check_indicator_manager_init():
	var placement_manager = PlacementManager.new()

	assert_object(placement_manager).is_not_null()

	placement_manager.free()


func test_node_locator_init():
	var node_locator = NodeLocator.new()

	assert_object(node_locator).is_not_null()
