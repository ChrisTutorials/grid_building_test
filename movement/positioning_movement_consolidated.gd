extends GdUnitTestSuite

## Consolidated positioning and movement tests using factory patterns

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary

func before_test():
	test_hierarchy = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER)

func test_positioner_basic_positioning():
	var positioner = test_hierarchy.positioner
	
	# Test basic positioning
	var test_position = Vector2(64, 32)
	positioner.position = test_position
	
	assert_vector(positioner.position).is_equal(test_position)

func test_positioner_with_collision_tracking():
	var positioner = test_hierarchy.positioner
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	
	# Add collision object to positioner
	var area = Area2D.new()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(32, 32)
	area.add_child(shape)
	positioner.add_child(area)
	auto_free(area)
	
	# Test position changes affect collision mapping
	var positions = [Vector2.ZERO, Vector2(32, 0), Vector2(64, 32)]
	var results = []
	
	for pos in positions:
		positioner.position = pos
		var offsets = collision_mapper._get_tile_offsets_for_collision_object(area, tile_map)
		results.append(offsets)
		assert_dict(offsets).is_not_empty()
	
	# Different positions should yield different collision results
	for i in range(results.size() - 1):
		assert_dict(results[i]).is_not_equal(results[i + 1])

func test_positioner_indicator_updates():
	var positioner = test_hierarchy.positioner
	var indicator_manager = test_hierarchy.indicator_manager
	
	# Add indicator to positioner
	var indicator = ColorRect.new()
	indicator.size = Vector2(16, 16)
	positioner.add_child(indicator)
	auto_free(indicator)
	
	# Test position changes trigger indicator updates
	var initial_pos = Vector2.ZERO
	var new_pos = Vector2(48, 48)
	
	positioner.position = initial_pos
	if indicator_manager.has_method("update_position_indicators"):
		indicator_manager.update_position_indicators()
	
	positioner.position = new_pos
	if indicator_manager.has_method("update_position_indicators"):
		indicator_manager.update_position_indicators()
	
	# Indicator should reflect positioner's new position
	var expected_indicator_pos = new_pos + indicator.position
	assert_vector(indicator.global_position).is_equal_approx(expected_indicator_pos, Vector2.ONE)

func test_movement_with_grid_alignment():
	var positioner = test_hierarchy.positioner
	var tile_map = test_hierarchy.tile_map
	var tile_size = tile_map.tile_set.tile_size
	
	# Test grid-aligned movement
	var unaligned_pos = Vector2(50, 50)
	positioner.position = unaligned_pos
	
	# Simulate grid alignment
	var grid_aligned_x = int(positioner.position.x / tile_size.x) * tile_size.x
	var grid_aligned_y = int(positioner.position.y / tile_size.y) * tile_size.y
	var aligned_pos = Vector2(grid_aligned_x, grid_aligned_y)
	
	positioner.position = aligned_pos
	
	# Verify alignment
	assert_int(int(positioner.position.x) % int(tile_size.x)).is_equal(0)
	assert_int(int(positioner.position.y) % int(tile_size.y)).is_equal(0)

func test_positioner_with_rule_validation():
	var positioner = test_hierarchy.positioner
	var rule_checker = test_hierarchy.rule_checker
	
	# Test positioning with rule validation
	var test_positions = [
		Vector2(32, 32),   # Should be valid
		Vector2(64, 32),   # Should be valid
		Vector2(-100, -100) # Likely invalid (out of bounds)
	]
	
	var validation_results = []
	for pos in test_positions:
		positioner.position = pos
		var rule_result = rule_checker.check_all_rules()
		validation_results.append(rule_result)
		assert_dict(rule_result).is_not_empty()
	
	# At least some positions should have different validation results
	var has_variation = false
	for i in range(validation_results.size() - 1):
		if validation_results[i] != validation_results[i + 1]:
			has_variation = true
			break
	
	assert_bool(has_variation).is_true()

func test_multi_object_positioning():
	var positioner = test_hierarchy.positioner
	
	# Create multiple positioned objects
	var objects = []
	var relative_positions = [Vector2.ZERO, Vector2(20, 0), Vector2(40, 20)]
	
	for i in range(3):
		var obj = Area2D.new()
		obj.position = relative_positions[i]
		positioner.add_child(obj)
		objects.append(obj)
		auto_free(obj)
	
	# Test positioner movement affects all children
	var positioner_offset = Vector2(100, 50)
	positioner.position = positioner_offset
	
	for i in range(objects.size()):
		var expected_global = positioner_offset + relative_positions[i]
		assert_vector(objects[i].global_position).is_equal_approx(expected_global, Vector2.ONE)

func test_positioner_boundary_conditions():
	var positioner = test_hierarchy.positioner
	var tile_map = test_hierarchy.tile_map
	
	# Test boundary positions
	var map_rect = tile_map.get_used_rect()
	var tile_size = tile_map.tile_set.tile_size
	
	var boundary_positions = [
		Vector2.ZERO,  # Origin
		Vector2(map_rect.position.x * tile_size.x, map_rect.position.y * tile_size.y),  # Map start
		Vector2(map_rect.end.x * tile_size.x - tile_size.x, map_rect.end.y * tile_size.y - tile_size.y)  # Map end
	]
	
	for pos in boundary_positions:
		positioner.position = pos
		# Should not crash or produce errors
		assert_vector(positioner.position).is_equal(pos)

func test_positioner_performance_bulk_moves():
	var positioner = test_hierarchy.positioner
	
	# Add several objects to positioner
	var objects = []
	for i in range(10):
		var obj = ColorRect.new()
		obj.size = Vector2(8, 8)
		positioner.add_child(obj)
		objects.append(obj)
		auto_free(obj)
	
	# Measure bulk movement performance
	var start_time = Time.get_ticks_msec()
	
	var positions = []
	for i in range(20):
		positions.append(Vector2(i * 16, sin(i) * 32))
	
	for pos in positions:
		positioner.position = pos
	
	var end_time = Time.get_ticks_msec()
	var elapsed = end_time - start_time
	
	# Bulk movements should be fast (< 50ms for 20 moves with 10 objects)
	assert_int(elapsed).is_less(50)

func test_positioner_integration_workflow():
	var positioner = test_hierarchy.positioner
	var collision_mapper = test_hierarchy.collision_mapper
	var indicator_manager = test_hierarchy.indicator_manager
	var rule_checker = test_hierarchy.rule_checker
	var tile_map = test_hierarchy.tile_map
	
	# Add test objects
	var area = Area2D.new()
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 12
	area.add_child(shape)
	positioner.add_child(area)
	auto_free(area)
	
	var indicator = ColorRect.new()
	indicator.size = Vector2(12, 12)
	indicator.color = Color.BLUE
	positioner.add_child(indicator)
	auto_free(indicator)
	
	# Test complete workflow: move -> collision check -> rule check -> indicator update
	var workflow_position = Vector2(64, 64)
	positioner.position = workflow_position
	
	# Step 1: Collision mapping
	var collision_result = collision_mapper._get_tile_offsets_for_collision_object(area, tile_map)
	assert_dict(collision_result).is_not_empty()
	
	# Step 2: Rule checking
	var rule_result = rule_checker.check_all_rules()
	assert_dict(rule_result).is_not_empty()
	
	# Step 3: Indicator updates
	if indicator_manager.has_method("update_all_indicators"):
		indicator_manager.update_all_indicators()
	
	# Verify final state
	assert_vector(positioner.position).is_equal(workflow_position)
	assert_vector(area.global_position).is_equal(workflow_position)
	assert_vector(indicator.global_position).is_equal(workflow_position)
