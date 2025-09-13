extends GdUnitTestSuite

## Consolidated performance tests using factory patterns

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test() -> void:
	test_hierarchy = UnifiedTestFactory.create_full_integration_test_scene(self, TEST_CONTAINER)

#region COLLISION MAPPING

func test_collision_mapping_performance() -> void:
	var collision_mapper: CollisionMapper = test_hierarchy.indicator_manager.get_collision_mapper()
	var _tile_map: TileMapLayer = test_hierarchy.tile_map
	var positioner: Node2D = test_hierarchy.positioner
	
	# Create multiple collision objects
	var collision_objects: Array[Area2D] = []
	var test_setups: Array = []
	for i in range(10):
		var area: Area2D = Area2D.new()
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(32, 32)
		area.add_child(shape)
		area.position = Vector2(64, 64)
		positioner.add_child(area)
		collision_objects.append(area)
		auto_free(area)
		
		# Create proper test setup for each collision object
		var test_setup: Variant = UnifiedTestFactory.create_test_indicator_collision_setup(self, area)
		test_setups.append(test_setup)
	
	# Measure collision mapping performance
	var start_time: int = Time.get_ticks_msec()
	
	for test_setup: Variant in test_setups:
		var offsets: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
		assert_dict(offsets).is_not_empty()
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (< 100ms for 10 objects)
	assert_int(elapsed).is_less(100)

func test_indicator_update_performance() -> void:
	var indicator_manager: Variant = test_hierarchy.indicator_manager
	var positioner: Node2D = test_hierarchy.positioner
	
	# Create multiple indicators
	var indicators: Array[ColorRect] = []
	for i in range(20):
		var indicator: ColorRect = ColorRect.new()
		indicator.size = Vector2(32, 32)
		indicator.position = Vector2(64, 64)
		indicators.append(indicator)
		positioner.add_child(indicator)
		auto_free(indicator)
	
	# Measure indicator update performance
	var start_time: int = Time.get_ticks_msec()
	
	for i in range(5):  # Multiple update cycles
		# Use apply_rules method directly (it's available on IndicatorManager)
		indicator_manager.apply_rules()
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should handle bulk updates efficiently (< 50ms for 5 update cycles)
	assert_int(elapsed).is_less(50)

#endregion

#region RULE CHECKING

func test_rule_checking_performance() -> void:
	var indicator_manager: Variant = test_hierarchy.indicator_manager
	var positioner: Node2D = test_hierarchy.positioner
	
	# Test multiple rule checks
	var positions: Array[Vector2] = []
	for i in range(15):
		positions.append(Vector2(i * 32, 0))
	
	var start_time: int = Time.get_ticks_msec()
	
	for pos: Vector2 in positions:
		positioner.position = pos
		# Use validate_placement method from IndicatorManager
		var result: PlacementReport = indicator_manager.validate_placement()
		assert_that(result).is_not_null()
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Rule checking should be fast (< 75ms for 15 checks)
	assert_int(elapsed).is_less(75)

func test_full_system_integration_performance() -> void:
	var building_system: BuildingSystem = test_hierarchy.building_system
	var targeting_system: GridTargetingSystem = test_hierarchy.targeting_system
	
	# Test full workflow performance
	var test_positions: Array[Vector2] = [
		Vector2(32, 32), Vector2(64, 32), Vector2(96, 32),
		Vector2(32, 64), Vector2(64, 64), Vector2(96, 64)
	]
	
	var start_time: int = Time.get_ticks_msec()
	
	for pos: Vector2 in test_positions:
		# Simulate full interaction workflow
		if targeting_system:
			var targeting_state: GridTargetingState = targeting_system.get_state()
			targeting_state.target.position = pos
		
		if building_system:
			# Use try_build method which is available on BuildingSystem
			building_system.try_build()
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Full workflow should complete efficiently (< 100ms for 6 operations)
	assert_int(elapsed).is_less(100)

func test_memory_usage_stability() -> void:
	var indicator_manager: Variant = test_hierarchy.indicator_manager
	var positioner: Node2D = test_hierarchy.positioner
	
	# Create and destroy objects to test memory stability
	var initial_objects: int = positioner.get_child_count()
	
	for cycle in range(3):
		# Create temporary objects
		var temp_objects: Array[ColorRect] = []
		for i in range(10):
			var obj: ColorRect = ColorRect.new()
			positioner.add_child(obj)
			temp_objects.append(obj)
		
		# Process them - use tear_down method which is available on IndicatorManager
		indicator_manager.tear_down()
		
		# Clean up
		for obj: ColorRect in temp_objects:
			obj.queue_free()
	
	# Wait for cleanup
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Object count should return to initial state
	var final_objects: int = positioner.get_child_count()
	assert_int(final_objects).is_less_equal(initial_objects + 5)  # Allow small variance

func test_concurrent_operations_performance() -> void:
	var collision_mapper: Variant = test_hierarchy.collision_mapper
	var indicator_manager: Variant = test_hierarchy.indicator_manager
	var positioner: Node2D = test_hierarchy.positioner
	
	# Create test objects
	var test_area: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(32, 32)
	test_area.add_child(shape)
	positioner.add_child(test_area)
	auto_free(test_area)
	
	# Create proper test setup for collision mapping
	var test_setup: Variant = UnifiedTestFactory.create_test_indicator_collision_setup(self, test_area)
	
	var start_time: int = Time.get_ticks_msec()
	
	# Simulate concurrent operations
	for i in range(10):
		positioner.position = Vector2(64, 64)
		
		# Multiple system operations
		var collision_result: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
		var rule_result: Variant = indicator_manager.validate_placement()
		
		# Use tear_down method which is available on IndicatorManager
		indicator_manager.tear_down()
		
		assert_dict(collision_result).is_not_empty()
		assert_that(rule_result).is_not_null()
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Concurrent operations should complete efficiently (< 120ms for 10 iterations)
	assert_int(elapsed).is_less(120)

#endregion
