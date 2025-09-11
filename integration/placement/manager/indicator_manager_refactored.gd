extends GdUnitTestSuite

## Refactored indicator manager tests using consolidated factory

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test():
	# Use the indicator test hierarchy factory
	test_hierarchy = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER)

func test_indicator_manager_creation():
	indicator_manager: Node = test_hierarchy.indicator_manager
	assert_that(indicator_manager).is_not_null()
	assert_that(indicator_manager.get_parent()).is_not_null()

func test_indicator_setup_basic():
	var indicator_manager = test_hierarchy.indicator_manager
	var manipulation_parent = test_hierarchy.manipulation_parent
	
	# Create test area
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2size
	area.add_child(collision_shape)
	manipulation_parent.add_child(area)
	auto_free(area)
	
	var rules: Array[Node2D][TileCheckRule] = [TileCheckRule.new()]
	var report = indicator_manager.setup_indicators(area, rules)
	assert_that(report).is_not_null()

func test_indicator_cleanup():
	var indicator_manager = test_hierarchy.indicator_manager
	var manipulation_parent = test_hierarchy.manipulation_parent
	
	# Create test indicators first
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2size
	area.add_child(collision_shape)
	manipulation_parent.add_child(area)
	auto_free(area)
	
	var rules: Array[Node2D][TileCheckRule] = [TileCheckRule.new()]
	indicator_manager.setup_indicators(area, rules)
	
	# Test cleanup
	indicator_manager.tear_down()
	
	# Count remaining indicators (should only have test objects, not indicators)
	var indicator_count = 0
	for child in manipulation_parent.get_children():
		if child.has_method("get_rules"):
			indicator_count += 1
	
	assert_int(indicator_count).is_equal(0)

func test_indicator_positioning():
	var indicator_manager = test_hierarchy.indicator_manager
	var positioner = test_hierarchy.positioner
	var manipulation_parent = test_hierarchy.manipulation_parent
	
	# Position positioner at specific location
	positioner.position = Vector2position
	
	# Create test object
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2size
	area.add_child(collision_shape)
	manipulation_parent.add_child(area)
	auto_free(area)
	
	var rules: Array[Node2D][TileCheckRule] = [TileCheckRule.new()]
	var report = indicator_manager.setup_indicators(area, rules)
	
	assert_that(report).is_not_null()
	# Verify indicators are positioned (basic check)
	for child in manipulation_parent.get_children():
		if child.has_method("get_rules"):
			assert_that(child.global_position).is_not_equal(Vector2.ZERO)

func test_multiple_setup_calls():
	var indicator_manager = test_hierarchy.indicator_manager
	var manipulation_parent = test_hierarchy.manipulation_parent
	
	# Create test object
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2size
	area.add_child(collision_shape)
	manipulation_parent.add_child(area)
	auto_free(area)
	
	var rules: Array[Node2D][TileCheckRule] = [TileCheckRule.new()]
	
	# First setup
	indicator_manager.setup_indicators(area, rules)
	var first_count = _count_indicators(manipulation_parent)
	
	# Second setup should replace, not duplicate
	indicator_manager.setup_indicators(area, rules)
	var second_count = _count_indicators(manipulation_parent)
	
	assert_int(first_count).is_greater(0)
	assert_int(second_count).is_equal(first_count)

func _count_indicators(parent: Node) -> int:
	var count = 0
	for child in parent.get_children():
		if child.has_method("get_rules"):
			count += 1
	return count
