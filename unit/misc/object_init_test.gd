extends GdUnitTestSuite

# NOTE: This file intentionally performs direct instantiation of objects from the
# grid_building plugin (for example, RuleCheckIndicator). These tests verify
# that plugin classes construct cleanly without relying on test factory helpers.
# Do NOT replace these direct `.new()` calls with `UnifiedTestFactory` helpers.
# The factory helpers are intended for higher-level integration tests that need
# injected loggers, auto_free management, or parented nodes. This file's goal
# is simple constructor sanity checks.


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
	var rule_check_indicator = RuleCheckIndicator.new([])

	assert_object(rule_check_indicator).is_not_null()

	rule_check_indicator.free()


func test_rule_check_indicator_manager_init():
	var indicator_manager = IndicatorManager.new()

	assert_object(indicator_manager).is_not_null()

	indicator_manager.free()


func test_node_locator_init():
	var node_locator = NodeLocator.new()

	assert_object(node_locator).is_not_null()
