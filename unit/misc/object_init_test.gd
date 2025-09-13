extends GdUnitTestSuite

# -----------------------------------------------------------------------------
# Test Suite: Object Initialization Tests
# -----------------------------------------------------------------------------
# This test suite verifies that core grid building plugin classes can be
# instantiated correctly without errors. Each test performs direct object
# construction and validates that the resulting object is not null.
# These are unit-level sanity checks for constructor functionality.
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
func _assert_object_initializes(obj: Object) -> void:
	assert_object(obj).is_not_null()


# -----------------------------------------------------------------------------
# Test Functions
# -----------------------------------------------------------------------------
func test_resource_stack_init() -> void:
	var resource_stack: ResourceStack = ResourceStack.new()

	_assert_object_initializes(resource_stack)


func test_building_system_init() -> void:
	var building_system: BuildingSystem = BuildingSystem.new()

	_assert_object_initializes(building_system)
	building_system.free()


func test_grid_targeter_system_init() -> void:
	var grid_targeter_system: GridTargetingSystem = GridTargetingSystem.new()

	_assert_object_initializes(grid_targeter_system)
	grid_targeter_system.free()


func test_rule_check_indicator_init() -> void:
	var rule_check_indicator: RuleCheckIndicator = RuleCheckIndicator.new([])

	_assert_object_initializes(rule_check_indicator)
	rule_check_indicator.free()


func test_rule_check_indicator_manager_init() -> void:
	var indicator_manager: IndicatorManager = IndicatorManager.new()

	_assert_object_initializes(indicator_manager)
	indicator_manager.free()


func test_node_locator_init() -> void:
	var node_locator: NodeLocator = NodeLocator.new()

	_assert_object_initializes(node_locator)
