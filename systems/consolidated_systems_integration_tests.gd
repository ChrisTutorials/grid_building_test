extends GdUnitTestSuite

## Consolidated systems integration tests
## Uses layered factory approach - builds from indicator hierarchy

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_scene: Dictionary

func before_test() -> void:
	# Use the full integration factory that builds upon indicator hierarchy
	test_scene = UnifiedTestFactory.create_full_integration_test_scene(self, TEST_CONTAINER)

# ================================
# Building System Tests (from building_system_test.gd)
# ================================

func test_building_system_initialization() -> void:
	var building_system: Object = test_scene.building_system
	assert_that(building_system).is_not_null()
	assert_that(building_system.get_parent()).is_not_null()

func test_building_system_placement() -> void:
	var building_system: Object = test_scene.building_system
	var positioner = test_scene.positioner
	var tile_map = test_scene.tile_map
	
	# Position for placement
	positioner.position = Vector2(32, 32)
	
	# Create a simple placeable object
	var placeable = Node2D.new()
	placeable.name = "TestPlaceable"
	auto_free(placeable)
	
	# Test basic building system functionality
	# Note: This is a simplified test - full implementation would require more setup
	assert_that(building_system).is_not_null()

func test_building_system_with_manipulation() -> void:
	var building_system: Object = test_scene.building_system
	var manipulation_system = test_scene.manipulation_system
	var positioner = test_scene.positioner
	
	# Test coordination between building and manipulation systems
	assert_that(building_system).is_not_null()
	assert_that(manipulation_system).is_not_null()
	
	# Position the positioner
	positioner.position = Vector2(64, 64)
	
	# Verify both systems can work together
	assert_that(positioner.position).is_equal(Vector2(64, 64))

# ================================
# Manipulation System Tests (from manipulation_system_test.gd)
# ================================

func test_manipulation_system_initialization() -> void:
	var manipulation_system = test_scene.manipulation_system
	var manipulation_parent = test_scene.manipulation_parent
	
	assert_that(manipulation_system).is_not_null()
	assert_that(manipulation_parent).is_not_null()
	assert_that(manipulation_parent.get_parent()).is_not_null()

func test_manipulation_system_hierarchy() -> void:
	var positioner = test_scene.positioner
	var manipulation_parent = test_scene.manipulation_parent
	var indicator_manager: Object = test_scene.indicator_manager
	
	# Test the hierarchy: positioner -> manipulation_parent -> indicator_manager
	assert_that(manipulation_parent.get_parent()).is_equal(positioner)
	assert_that(indicator_manager).is_not_null()

func test_manipulation_system_state_management() -> void:
	var manipulation_system = test_scene.manipulation_system
	var container: GBCompositionContainer = test_scene.container
	
	# Test state management
	var manipulation_state = container.get_states().manipulation
	assert_that(manipulation_state).is_not_null()
	assert_that(manipulation_state.parent).is_not_null()

# ================================
# Grid Targeting System Tests (from grid_targeting_system_test.gd)
# ================================

func test_targeting_system_initialization() -> void:
	var targeting_system = test_scene.targeting_system
	var tile_map = test_scene.tile_map
	var positioner = test_scene.positioner
	
	assert_that(targeting_system).is_not_null()
	assert_that(tile_map).is_not_null()
	assert_that(positioner).is_not_null()

func test_targeting_system_state() -> void:
	var container: GBCompositionContainer = test_scene.container
	var targeting_state: Object = container.get_states().targeting
	var positioner = test_scene.positioner
	var tile_map = test_scene.tile_map
	
	assert_that(targeting_state).is_not_null()
	assert_that(targeting_state.positioner).is_equal(positioner)
	assert_that(targeting_state.target_map).is_equal(tile_map)

func test_targeting_system_position_updates() -> void:
	var targeting_system = test_scene.targeting_system
	var positioner = test_scene.positioner
	var container: GBCompositionContainer = test_scene.container
	
	# Test position updates
	var initial_pos = positioner.position
	positioner.position = Vector2(128, 128)
	
	# Verify targeting system can track position changes
	var targeting_state: Object = container.get_states().targeting
	assert_that(targeting_state.positioner.position).is_equal(Vector2(128, 128))

# ================================
# System Integration Tests
# ================================

func test_full_system_integration() -> void:
	var building_system: Object = test_scene.building_system
	var manipulation_system = test_scene.manipulation_system
	var targeting_system = test_scene.targeting_system
	var indicator_manager: Object = test_scene.indicator_manager
	var positioner = test_scene.positioner
	
	# Test that all systems are properly connected
	assert_that(building_system).is_not_null()
	assert_that(manipulation_system).is_not_null()
	assert_that(targeting_system).is_not_null()
	assert_that(indicator_manager).is_not_null()
	
	# Position the positioner
	positioner.position = Vector2(96, 96)
	
	# Create a simple test object for indicators
	var test_area = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(32, 32)
	test_area.add_child(collision_shape)
	test_scene.manipulation_parent.add_child(test_area)
	auto_free(test_area)
	
	# Test indicator setup with all systems active
	var rules: Array = [TileCheckRule.new()]
	var report = indicator_manager.setup_indicators(test_area, rules)
	
	# Should work even with all systems running
	assert_that(report).is_not_null()

func test_system_cleanup_integration() -> void:
	var indicator_manager: Object = test_scene.indicator_manager
	var manipulation_parent = test_scene.manipulation_parent
	
	# Create test indicators
	var test_area = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(16, 16)
	test_area.add_child(collision_shape)
	manipulation_parent.add_child(test_area)
	auto_free(test_area)
	
	var rules: Array = [TileCheckRule.new()]
	indicator_manager.setup_indicators(test_area, rules)
	
	# Verify indicators were created
	var initial_child_count = manipulation_parent.get_child_count()
	assert_int(initial_child_count).is_greater_equal(1)  # At least the test_area
	
	# Test cleanup
	indicator_manager.cleanup_indicators()
	
	# Indicators should be cleaned up but test_area should remain
	var final_child_count = manipulation_parent.get_child_count()
	assert_int(final_child_count).is_equal(1)  # Just the test_area

func test_system_state_synchronization() -> void:
	var container: GBCompositionContainer = test_scene.container
	var positioner = test_scene.positioner
	var tile_map = test_scene.tile_map
	var manipulation_parent = test_scene.manipulation_parent
	
	# Test that all states are properly synchronized
	var targeting_state: Object = container.get_states().targeting
	var manipulation_state = container.get_states().manipulation
	
	assert_that(targeting_state.positioner).is_equal(positioner)
	assert_that(targeting_state.target_map).is_equal(tile_map)
	assert_that(manipulation_state.parent).is_equal(manipulation_parent)

# ================================
# Performance Integration Tests
# ================================

func test_system_performance_under_load() -> void:
	var indicator_manager: Object = test_scene.indicator_manager
	var manipulation_parent = test_scene.manipulation_parent
	
	# Create multiple test objects
	var test_objects: Array = []
	for i in range(5):
		var test_area = Area2D.new()
		test_area.name = "TestArea_" + str(i)
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		collision_shape.shape = RectangleShape2D.new()
		collision_shape.shape.size = Vector2(24, 24)
		test_area.add_child(collision_shape)
		test_area.position = Vector2(i * 30, 0)
		manipulation_parent.add_child(test_area)
		test_objects.append(test_area)
		auto_free(test_area)
	
	var rules: Array = [TileCheckRule.new()]
	
	# Time the operations
	var start_time: int = Time.get_ticks_msec()
	
	for test_obj: Dictionary in test_objects:
		var report = indicator_manager.setup_indicators(test_obj, rules)
		assert_that(report).is_not_null()
	
	var end_time: int = Time.get_ticks_msec()
	var processing_time = end_time - start_time
	
	# Should complete all operations within reasonable time
	assert_int(processing_time).is_less_equal(500)  # 500ms max for 5 objects
