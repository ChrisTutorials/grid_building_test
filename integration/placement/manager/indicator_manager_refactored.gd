extends GdUnitTestSuite

## Refactored indicator manager tests using consolidated factory

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test() -> void:
	# Use the indicator test hierarchy factory
	test_hierarchy = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER)

func test_indicator_manager_creation() -> void:
	var indicator_manager: IndicatorManager = test_hierarchy.indicator_manager
	assert_that(indicator_manager).is_not_null()
	assert_that(indicator_manager.get_parent()).is_not_null()

func test_indicator_setup_basic() -> void:
	var indicator_manager: IndicatorManager = test_hierarchy.indicator_manager
	
	# Create and setup test area
	var area: Area2D = _create_test_area()
	_setup_test_area(area)
	
	var rules: Array[TileCheckRule] = _create_test_rules()
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules)
	assert_that(report).is_not_null()

func test_indicator_cleanup() -> void:
	var indicator_manager: IndicatorManager = test_hierarchy.indicator_manager
	var manipulation_parent: Node2D = test_hierarchy.manipulation_parent
	
	# Create and setup test indicators first
	var area: Area2D = _create_test_area()
	_setup_test_area(area)
	
	var rules: Array[TileCheckRule] = _create_test_rules()
	indicator_manager.setup_indicators(area, rules)
	
	# Test cleanup
	indicator_manager.tear_down()
	
	# Count remaining indicators (should only have test objects, not indicators)
	var indicator_count: int = _count_indicators(manipulation_parent)
	assert_int(indicator_count).is_equal(0)

func test_indicator_positioning() -> void:
	var indicator_manager: IndicatorManager = test_hierarchy.indicator_manager
	var positioner: Node2D = test_hierarchy.positioner
	var manipulation_parent: Node2D = test_hierarchy.manipulation_parent
	
	# Position positioner at specific location
	positioner.position = Vector2(32, 32)
	
	# Create and setup test object
	var area: Area2D = _create_test_area()
	_setup_test_area(area)
	
	var rules: Array[TileCheckRule] = _create_test_rules()
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules)

	assert_that(report).is_not_null()
	# Verify indicators are positioned (basic check)
	for child in manipulation_parent.get_children():
		if child.has_method("get_rules"):
			assert_that(child.global_position).is_not_equal(Vector2.ZERO)

func test_multiple_setup_calls() -> void:
	var indicator_manager: IndicatorManager = test_hierarchy.indicator_manager
	var manipulation_parent: Node2D = test_hierarchy.manipulation_parent
	
	# Create and setup test object
	var area: Area2D = _create_test_area()
	_setup_test_area(area)
	
	var rules: Array[TileCheckRule] = _create_test_rules()
	
	# First setup
	indicator_manager.setup_indicators(area, rules)
	var first_count: int = _count_indicators(manipulation_parent)
	
	# Second setup should replace, not duplicate
	indicator_manager.setup_indicators(area, rules)
	var second_count: int = _count_indicators(manipulation_parent)
	
	assert_int(first_count).is_greater(0)
	assert_int(second_count).is_equal(first_count)

func _create_test_area() -> Area2D:
	var area: Area2D = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(16, 16)
	area.add_child(collision_shape)
	return area

func _create_test_rules() -> Array[TileCheckRule]:
	return [TileCheckRule.new()]

func _setup_test_area(area: Area2D) -> void:
	var manipulation_parent: Node2D = test_hierarchy.manipulation_parent
	manipulation_parent.add_child(area)
	auto_free(area)

func _count_indicators(parent: Node) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child.has_method("get_rules"):
			count += 1
	return count
