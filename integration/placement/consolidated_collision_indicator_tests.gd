extends GdUnitTestSuite

## Consolidated collision and indicator tests
## Combines multiple similar test files into one comprehensive suite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test() -> void:
	# Use the comprehensive factory method
	test_hierarchy = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER)

# ================================
# Collision Mapper Tests (from collision_mapper_test.gd)
# ================================

func test_collision_mapper_basic_functionality() -> void:
	var collision_mapper: Object = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	
	# Create a collision object using DRY pattern
	var collision_object = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
	
	# Create IndicatorCollisionTestSetup using DRY pattern
	var test_setup = UnifiedTestFactory.create_test_indicator_collision_setup(self, collision_object)
	
	# Test collision mapping with proper test setup
	var offsets = collision_mapper.get_tile_offsets_for_test_collisions(test_setup, tile_map)
	assert_dict(offsets).is_not_empty()

func test_collision_mapper_multiple_shapes() -> void:
	var collision_mapper: Object = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map

	# Create an object with multiple collision shapes using factory methods
	var area = GodotTestFactory.create_area2d_with_circle_shape(self, 16.0)

	# Remove from test root and add to positioner
	if area.get_parent() != null:
		area.get_parent().remove_child(area)
	test_hierarchy.positioner.add_child(area)
	auto_free(area)

	# Add additional collision shapes using factory methods
	var rect_shape: RectangleShape2D = GodotTestFactory.create_rectangle_shape(Vector2(16, 16))
	var collision_shape2: CollisionShape2D = CollisionShape2D.new()
	collision_shape2.shape = rect_shape
	collision_shape2.position = Vector2(32, 0)
	area.add_child(collision_shape2)

	# Create proper test setup for collision mapping
	var test_setup = UnifiedTestFactory.create_test_indicator_collision_setup(self, area)

	var offsets = collision_mapper.get_tile_offsets_for_test_collisions(test_setup, tile_map)
	assert_dict(offsets).is_not_empty()

# ================================
# Indicator Manager Tests (from indicator_manager_test.gd)
# ================================

func test_indicator_manager_setup_basic() -> void:
	var indicator_manager: Object = test_hierarchy.indicator_manager
	var manipulation_parent = test_hierarchy.manipulation_parent

	# Create simple rules
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]

	# Create area with collision shape using factory methods
	var rect_shape: RectangleShape2D = GodotTestFactory.create_rectangle_shape(Vector2(32, 32))
	var area = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	manipulation_parent.add_child(area)

	auto_free(area)

	# Test indicator setup
	var report = indicator_manager.setup_indicators(area, rules)
	assert_that(report).is_not_null()

func test_indicator_manager_cleanup() -> void:
	var indicator_manager: Object = test_hierarchy.indicator_manager
	
	# Test cleanup functionality
	indicator_manager.tear_down()
	
	# Verify indicators are cleaned up
	var indicator_count = 0
	for child in test_hierarchy.manipulation_parent.get_children():
		# Direct type checking - RuleCheckIndicator assumed to exist
		if child is RuleCheckIndicator:
			indicator_count += 1
	
	assert_int(indicator_count).is_equal(0)

# ================================
# Collision Performance Tests (from collision_performance_comprehensive_test.gd)
# ================================

func test_collision_performance_large_tilemap() -> void:
	var collision_mapper: Object = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map

	# Create a larger collision object using factory methods
	var rect_shape: RectangleShape2D = GodotTestFactory.create_rectangle_shape(Vector2(128, 128))
	var area = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	test_hierarchy.positioner.add_child(area)

	auto_free(area)

	# Create proper test setup for collision mapping
	var test_setup = UnifiedTestFactory.create_test_indicator_collision_setup(self, area)

	# Measure performance (basic timing)
	var start_time: int = Time.get_ticks_msec()
	var offsets = collision_mapper.get_tile_offsets_for_test_collisions(test_setup, tile_map)
	var end_time: int = Time.get_ticks_msec()

	var processing_time = end_time - start_time
	assert_int(processing_time).is_less_equal(100)  # Should complete within 100ms
	assert_dict(offsets).is_not_empty()

func test_collision_performance_multiple_objects() -> void:
	var collision_mapper: Object = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map

	# Create multiple collision objects using factory methods
	var areas: Array = []
	var test_setups: Array = []
	for i in range(5):
		var rect_shape: RectangleShape2D = GodotTestFactory.create_rectangle_shape(Vector2(32, 32))
		var area = Area2D.new()
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		collision_shape.shape = rect_shape
		area.position = Vector2(i * 40, 0)
		area.add_child(collision_shape)
		test_hierarchy.positioner.add_child(area)
		areas.append(area)
		auto_free(area)

		# Create proper test setup for each collision object
		var test_setup = UnifiedTestFactory.create_test_indicator_collision_setup(self, area)
		test_setups.append(test_setup)

	# Test processing all objects
	var start_time: int = Time.get_ticks_msec()
	var all_offsets = {}
	for i in range(test_setups.size()):
		var test_setup = test_setups[i]
		var offsets = collision_mapper.get_tile_offsets_for_test_collisions(test_setup, tile_map)
		all_offsets[areas[i]] = offsets
	var end_time: int = Time.get_ticks_msec()

	var processing_time = end_time - start_time
	assert_int(processing_time).is_less_equal(200)  # Should complete within 200ms
	assert_int(all_offsets.size()).is_equal(5)

# ================================
# Positioning Tests (from indicator_positioning_comprehensive_test.gd) 
# ================================

func test_indicator_positioning_basic() -> void:
	var indicator_manager: Object = test_hierarchy.indicator_manager
	var positioner = test_hierarchy.positioner
	var manipulation_parent = test_hierarchy.manipulation_parent

	# Position the positioner at a specific location
	positioner.position = Vector2(64, 64)

	# Create object and rules using factory methods
	var rect_shape: RectangleShape2D = GodotTestFactory.create_rectangle_shape(Vector2(32, 32))
	var area = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	manipulation_parent.add_child(area)
	auto_free(area)

	var rules: Array[TileCheckRule] = [TileCheckRule.new()]

	# Setup indicators
	var report = indicator_manager.setup_indicators(area, rules)
	assert_that(report).is_not_null()

	# Verify indicators are positioned relative to positioner
	for child in manipulation_parent.get_children():
		if child is RuleCheckIndicator:  # Direct type check
			# Should be positioned relative to the positioner
			assert_that(child.global_position).is_not_equal(Vector2.ZERO)

func test_indicator_positioning_grid_alignment() -> void:
	var indicator_manager: Object = test_hierarchy.indicator_manager
	var positioner = test_hierarchy.positioner
	var tile_map = test_hierarchy.tile_map

	# Position positioner at grid-aligned location
	var tile_size = tile_map.tile_set.tile_size
	positioner.position = Vector2(tile_size.x * 2, tile_size.y * 2)  # Aligned to grid

	# Create simple test object using factory methods
	var rect_shape: RectangleShape2D = GodotTestFactory.create_rectangle_shape(Vector2(tile_size.x, tile_size.y))
	var area = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	test_hierarchy.manipulation_parent.add_child(area)
	auto_free(area)

	var rules: Array[TileCheckRule] = [TileCheckRule.new()]
	var report = indicator_manager.setup_indicators(area, rules)

	assert_that(report).is_not_null()
	# Verify grid alignment - indicators should snap to tile boundaries
	for child in test_hierarchy.manipulation_parent.get_children():
		if child is RuleCheckIndicator:  # Direct type check
			var pos = child.global_position
			var x_aligned = fmod(pos.x, tile_size.x) < 1.0 or fmod(pos.x, tile_size.x) > tile_size.x - 1.0
			var y_aligned = fmod(pos.y, tile_size.y) < 1.0 or fmod(pos.y, tile_size.y) > tile_size.y - 1.0
			assert_bool(x_aligned or y_aligned).is_true()  # At least one axis should be aligned
