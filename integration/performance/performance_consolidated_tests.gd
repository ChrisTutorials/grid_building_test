extends GdUnitTestSuite

## Consolidated performance tests using factory patterns

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test():
	test_hierarchy = UnifiedTestFactory.create_full_integration_test_scene(self, TEST_CONTAINER)

#region COLLISION MAPPING

func test_collision_mapping_performance():
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	var positioner = test_hierarchy.positioner
	
	# Create multiple collision objects
	var collision_objects = []
	var test_setups = []
	for i in range(10):
		var area = Area2D.new()
		var shape = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(32, 32)
		area.add_child(shape)
		area.position = Vector2(i * 32, 0)
		positioner.add_child(area)
		collision_objects.append(area)
		auto_free(area)
		
		# Create proper test setup for each collision object
		var test_setup = UnifiedTestFactory.create_test_indicator_collision_setup(self, area)
		test_setups.append(test_setup)
	
	# Measure collision mapping performance
	var start_time = Time.get_ticks_msec()
	
	for test_setup in test_setups:
		var offsets = collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
		assert_dict(offsets).is_not_empty()
	
	var end_time = Time.get_ticks_msec()
	var elapsed = end_time - start_time
	
	# Should complete within reasonable time (< 100ms for 10 objects)
	assert_int(elapsed).is_less(100)

func test_indicator_update_performance():
	var indicator_manager = test_hierarchy.indicator_manager
	var positioner = test_hierarchy.positioner
	
	# Create multiple indicators
	var indicators = []
	for i in range(20):
		var indicator = ColorRect.new()
		indicator.size = Vector2(16, 16)
		indicator.position = Vector2(i * 20, 0)
		indicators.append(indicator)
		positioner.add_child(indicator)
		auto_free(indicator)
	
	# Measure indicator update performance
	var start_time = Time.get_ticks_msec()
	
	for i in range(5):  # Multiple update cycles
		# Use apply_rules method directly (it's available on IndicatorManager)
		indicator_manager.apply_rules()
	
	var end_time = Time.get_ticks_msec()
	var elapsed = end_time - start_time
	
	# Should handle bulk updates efficiently (< 50ms for 5 update cycles)
	assert_int(elapsed).is_less(50)

#endregion

#region RULE CHECKING

func test_rule_checking_performance():
	var indicator_manager = test_hierarchy.indicator_manager
	var positioner = test_hierarchy.positioner
	
	# Test multiple rule checks
	var positions = []
	for i in range(15):
		positions.append(Vector2(i * 32, 0))
	
	var start_time = Time.get_ticks_msec()
	
	for pos in positions:
		positioner.position = pos
		# Use validate_placement method from IndicatorManager
		var result = indicator_manager.validate_placement()
		assert_that(result).is_not_null()
	
	var end_time = Time.get_ticks_msec()
	var elapsed = end_time - start_time
	
	# Rule checking should be fast (< 75ms for 15 checks)
	assert_int(elapsed).is_less(75)

func test_full_system_integration_performance():
	var building_system = test_hierarchy.building_system
	var targeting_system = test_hierarchy.targeting_system
	
	# Test full workflow performance
	var test_positions = [
		Vector2(32, 32), Vector2(64, 32), Vector2(96, 32),
		Vector2(32, 64), Vector2(64, 64), Vector2(96, 64)
	]
	
	var start_time = Time.get_ticks_msec()
	
	for pos in test_positions:
		# Simulate full interaction workflow
		if targeting_system:
			var targeting_state = targeting_system.get_state()
			targeting_state.target.position = pos
		
		if building_system:
			# Use try_build method which is available on BuildingSystem
			building_system.try_build()
	
	var end_time = Time.get_ticks_msec()
	var elapsed = end_time - start_time
	
	# Full workflow should complete efficiently (< 100ms for 6 operations)
	assert_int(elapsed).is_less(100)

func test_memory_usage_stability():
	var indicator_manager = test_hierarchy.indicator_manager
	var positioner = test_hierarchy.positioner
	
	# Create and destroy objects to test memory stability
	var initial_objects = positioner.get_child_count()
	
	for cycle in range(3):
		# Create temporary objects
		var temp_objects = []
		for i in range(10):
			var obj = ColorRect.new()
			positioner.add_child(obj)
			temp_objects.append(obj)
		
		# Process them - use tear_down method which is available on IndicatorManager
		indicator_manager.tear_down()
		
		# Clean up
		for obj in temp_objects:
			obj.queue_free()
	
	# Wait for cleanup
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Object count should return to initial state
	var final_objects = positioner.get_child_count()
	assert_int(final_objects).is_less_equal(initial_objects + 5)  # Allow small variance

func test_concurrent_operations_performance():
	var collision_mapper = test_hierarchy.collision_mapper
	var indicator_manager = test_hierarchy.indicator_manager
	var positioner = test_hierarchy.positioner
	
	# Create test objects
	var test_area = Area2D.new()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(24, 24)
	test_area.add_child(shape)
	positioner.add_child(test_area)
	auto_free(test_area)
	
	# Create proper test setup for collision mapping
	var test_setup = UnifiedTestFactory.create_test_indicator_collision_setup(self, test_area)
	
	var start_time = Time.get_ticks_msec()
	
	# Simulate concurrent operations
	for i in range(10):
		positioner.position = Vector2(i * 16, 0)
		
		# Multiple system operations
		var collision_result = collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
		var rule_result = indicator_manager.validate_placement()
		
		# Use tear_down method which is available on IndicatorManager
		indicator_manager.tear_down()
		
		assert_dict(collision_result).is_not_empty()
		assert_that(rule_result).is_not_null()
	
	var end_time = Time.get_ticks_msec()
	var elapsed = end_time - start_time
	
	# Concurrent operations should complete efficiently (< 120ms for 10 iterations)
	assert_int(elapsed).is_less(120)

#endregion
