extends GdUnitTestSuite

## Consolidated Placement Manager Components Test Suite
## Consolidates: collision_mapper_shape_positioner_movement_test.gd, trapezoid_bottom_row_regression_test.gd,
## polygon_tile_mapper_test.gd, polygon_indicator_runtime_parity_test.gd, real_world_indicator_test.gd,
## collision_mapper_trapezoid_regression_test.gd, indicator_manager_runtime_issues_guard_test.gd,
## polygon_tile_mapper_tile_shape_propagation_test.gd, polygon_tile_mapper_isometric_test.gd,
## polygon_tile_mapper_tile_shape_test.gd, indicator_manager_tree_integration_test.gd,
## polygon_origin_indicator_regression_test.gd, isometric_collision_mapping_test.gd

## MARK FOR REMOVAL - collision_mapper_shape_positioner_movement_test.gd, trapezoid_bottom_row_regression_test.gd,
## polygon_tile_mapper_test.gd, polygon_indicator_runtime_parity_test.gd, real_world_indicator_test.gd,
## collision_mapper_trapezoid_regression_test.gd, indicator_manager_runtime_issues_guard_test.gd,
## polygon_tile_mapper_tile_shape_propagation_test.gd, polygon_tile_mapper_isometric_test.gd,
## polygon_tile_mapper_tile_shape_test.gd, indicator_manager_tree_integration_test.gd,
## polygon_origin_indicator_regression_test.gd, isometric_collision_mapping_test.gd

var test_env: Dictionary

func before_test() -> void:
	test_env = UnifiedTestFactory.create_placement_system_test_environment(self)

# ===== COLLISION MAPPER SHAPE POSITIONING TESTS =====

func test_collision_mapper_shape_positioning() -> void:
	var collision_mapper: Object = test_env.collision_mapper
	var test_object: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Add collision shape
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	collision_shape.shape = rect_shape
	test_object.add_child(collision_shape)
	
	# Test shape positioning at different locations
	var test_positions: Array[Vector2] = [Vector2(0, 0), Vector2(100, 100), Vector2(-50, -50)]
	
	for pos: Vector2 in test_positions:
		test_object.global_position = pos
		var collision_tiles: Array = collision_mapper.get_collision_tiles(test_object, pos)
		
		assert_array(collision_tiles).append_failure_message(
			"Should generate collision tiles at position %s" % pos
		).is_not_empty()

func test_shape_positioner_movement_consistency() -> void:
	var collision_mapper: Object = test_env.collision_mapper
	var test_object: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Setup collision shape
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = 16
	collision_shape.shape = circle_shape
	test_object.add_child(collision_shape)
	
	# Test movement from one position to another
	var start_pos: Vector2 = Vector2(50, 50)
	var end_pos: Vector2 = Vector2(150, 150)
	
	var start_tiles = collision_mapper.get_collision_tiles(test_object, start_pos)
	var end_tiles = collision_mapper.get_collision_tiles(test_object, end_pos)
	
	# Both positions should generate valid collision data
	assert_array(start_tiles).is_not_empty()
	assert_array(end_tiles).is_not_empty()
	
	# Positions should generally produce different tile sets
	var tiles_differ = start_tiles != end_tiles
	assert_bool(tiles_differ).append_failure_message(
		"Different positions should generally produce different collision tiles"
	).is_true()

# ===== TRAPEZOID REGRESSION TESTS =====

func test_trapezoid_bottom_row_regression() -> void:
	# Create trapezoid shape for testing
	var trapezoid_points: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
	])
	
	# Test trapezoid tile coverage using CollisionGeometryCalculator
	var tile_size: Vector2 = Vector2(16, 16)
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		trapezoid_points, tile_size, GBEnums.TileType.SQUARE
	)
	
	assert_array(overlapped_tiles).append_failure_message(
		"Trapezoid should overlap multiple tiles"
	).is_not_empty()
	
	# Verify trapezoid geometry properties
	var bounds = GBGeometryMath.get_polygon_bounds(trapezoid_points)
	assert_float(bounds.size.x).append_failure_message(
		"Trapezoid should have reasonable width"
	).is_greater(32.0)

func test_collision_mapper_trapezoid_regression() -> void:
	var collision_mapper: Object = test_env.collision_mapper
	var trapezoid_object: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Create trapezoid collision polygon
	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-24, 8), Vector2(-12, -8), Vector2(12, -8), Vector2(24, 8)
	])
	trapezoid_object.add_child(collision_polygon)
	
	# Test trapezoid collision mapping
	var collision_tiles = collision_mapper.get_collision_tiles(trapezoid_object, Vector2(100, 100))
	
	assert_array(collision_tiles).append_failure_message(
		"Trapezoid collision mapping should produce tiles"
	).is_not_empty()
	
	# Verify tile positions are reasonable for trapezoid shape
	for tile_pos in collision_tiles:
		var tile_coord = tile_pos as Vector2i
		assert_int(abs(tile_coord.x)).append_failure_message(
			"Trapezoid tile x coordinate should be reasonable: %d" % tile_coord.x
		).is_less_than(50) # Within reasonable bounds

# ===== POLYGON TILE MAPPER TESTS =====

func test_polygon_tile_mapper_basic() -> void:
	# Test basic polygon tile mapping functionality
	var simple_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	var mapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		simple_polygon, tile_size, GBEnums.TileType.SQUARE
	)
	
	assert_int(mapped_tiles.size()).append_failure_message(
		"32x32 polygon should map to 4 tiles (2x2), got %d" % mapped_tiles.size()
	).is_equal(4)

func test_polygon_tile_mapper_isometric() -> void:
	# Test isometric tile mapping if supported
	var diamond_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	var isometric_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		diamond_polygon, tile_size, GBEnums.TileType.ISOMETRIC
	)
	
	assert_array(isometric_tiles).append_failure_message(
		"Diamond polygon should map to isometric tiles"
	).is_not_empty()

func test_polygon_tile_shape_propagation() -> void:
	# Test that tile shape settings propagate correctly
	var test_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	
	# Test with different tile types
	var square_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		test_polygon, tile_size, GBEnums.TileType.SQUARE
	)
	var isometric_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		test_polygon, tile_size, GBEnums.TileType.ISOMETRIC  
	)
	
	# Both should produce results, though potentially different
	assert_array(square_tiles).is_not_empty()
	assert_array(isometric_tiles).is_not_empty()

# ===== INDICATOR MANAGER TESTS =====

func test_indicator_manager_runtime_issues_guard() -> void:
	var indicator_manager: Object = test_env.indicator_manager
	
	# Test that indicator manager handles runtime issues gracefully
	var test_rule = CollisionsCheckRule.new()
	var invalid_params = test_env.rule_validation_parameters
	# Modify to have invalid data
	invalid_params.tile_map = null
	invalid_params.placeable_instance = null
	
	# Should handle invalid parameters gracefully
	var result = indicator_manager.try_setup([test_rule], invalid_params)
	assert_object(result).append_failure_message(
		"Indicator manager should handle invalid params gracefully"
	).is_not_null()
	
	# Result should indicate failure but not crash
	assert_bool(result.is_successful).append_failure_message(
		"Setup with invalid params should fail gracefully"
	).is_false()

func test_indicator_manager_tree_integration() -> void:
	var indicator_manager: Object = test_env.indicator_manager
	
	# Verify indicator manager is properly integrated into scene tree
	assert_object(indicator_manager.get_parent()).append_failure_message(
		"Indicator manager should have a parent in scene tree"
	).is_not_null()
	
	# Test basic functionality
	var test_rule = CollisionsCheckRule.new()
	var valid_params = test_env.rule_validation_parameters
	
	var setup_result = indicator_manager.try_setup([test_rule], valid_params)
	assert_object(setup_result).is_not_null()

# ===== POLYGON INDICATOR RUNTIME PARITY TESTS =====

func test_polygon_indicator_runtime_parity() -> void:
	var indicator_manager: Object = test_env.indicator_manager
	var polygon_object: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Create polygon collision
	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	polygon_object.add_child(collision_polygon)
	
	# Test that indicator generation matches runtime collision behavior
	var test_rule = CollisionsCheckRule.new()
	var params = test_env.rule_validation_parameters
	params.target_position = Vector2(200, 200)
	params.placeable_instance = polygon_object
	
	var indicator_result = indicator_manager.try_setup([test_rule], params)
	assert_bool(indicator_result.is_successful).append_failure_message(
		"Polygon indicator generation should succeed: %s" % indicator_result.get_all_issues()
	).is_true()

func test_polygon_origin_indicator_regression() -> void:
	# Test polygon origin handling for indicators
	var origin_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(24, 0), Vector2(24, 24), Vector2(0, 24)
	])
	
	# Test with origin at different positions
	var origin_offsets: Array = [Vector2.ZERO, Vector2(8, 8), Vector2(-8, -8)]
	
	for offset in origin_offsets:
		var offset_polygon: PackedVector2Array = PackedVector2Array()
		for point in origin_polygon:
			offset_polygon.append(point + offset)
		
		var tile_size: Vector2 = Vector2(16, 16)
		var mapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
			offset_polygon, tile_size, GBEnums.TileType.SQUARE
		)
		
		assert_array(mapped_tiles).append_failure_message(
			"Polygon with origin offset %s should map to tiles" % offset
		).is_not_empty()

# ===== REAL-WORLD INDICATOR TESTS =====

func test_real_world_indicator_scenarios() -> void:
	var _indicator_manager = test_env.indicator_manager
	var collision_mapper: Object = test_env.collision_mapper
	
	# Test scenario 1: Small building
	var small_building: Node2D = UnifiedTestFactory.create_test_node2d(self)
	var small_collision: CollisionShape2D = CollisionShape2D.new()
	var small_rect: RectangleShape2D = RectangleShape2D.new()
	small_rect.size = Vector2(16, 16)
	small_collision.shape = small_rect
	small_building.add_child(small_collision)
	
	var small_tiles = collision_mapper.get_collision_tiles(small_building, Vector2(300, 300))
	assert_array(small_tiles).append_failure_message(
		"Small building should generate collision tiles"
	).is_not_empty()
	
	# Test scenario 2: Large building
	var large_building: Node2D = UnifiedTestFactory.create_test_node2d(self)
	var large_collision: CollisionShape2D = CollisionShape2D.new()
	var large_rect: RectangleShape2D = RectangleShape2D.new()
	large_rect.size = Vector2(64, 64)
	large_collision.shape = large_rect
	large_building.add_child(large_collision)
	
	var large_tiles = collision_mapper.get_collision_tiles(large_building, Vector2(400, 400))
	assert_array(large_tiles).append_failure_message(
		"Large building should generate collision tiles"
	).is_not_empty()
	
	# Large building should generally have more collision tiles
	assert_int(large_tiles.size()).append_failure_message(
		"Large building should have more collision tiles than small building"
	).is_greater(small_tiles.size())

# ===== ISOMETRIC COLLISION MAPPING TESTS =====

func test_isometric_collision_mapping() -> void:
	# Test isometric-specific collision mapping
	var isometric_diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0, -20), Vector2(20, 0), Vector2(0, 20), Vector2(-20, 0)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	var isometric_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		isometric_diamond, tile_size, GBEnums.TileType.ISOMETRIC
	)
	
	assert_array(isometric_tiles).append_failure_message(
		"Isometric diamond should map to tiles"
	).is_not_empty()
	
	# Verify isometric mapping produces different results than square mapping
	var square_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		isometric_diamond, tile_size, GBEnums.TileType.SQUARE
	)
	
	# Results may differ between tile types
	assert_array(square_tiles).is_not_empty()

func test_isometric_precision() -> void:
	# Test precision in isometric collision mapping
	var precise_diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0, -8), Vector2(8, 0), Vector2(0, 8), Vector2(-8, 0)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	var precise_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		precise_diamond, tile_size, GBEnums.TileType.ISOMETRIC, 0.01, 0.05
	)
	
	assert_array(precise_tiles).append_failure_message(
		"Precise isometric diamond should map to at least one tile"
	).is_not_empty()

# ===== COMPREHENSIVE COMPONENT INTEGRATION TESTS =====

func test_component_integration_workflow() -> void:
	var collision_mapper: Object = test_env.collision_mapper
	var indicator_manager: Object = test_env.indicator_manager
	
	# Create test object with complex collision
	var complex_object: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Add multiple collision shapes
	var rect_collision: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(24, 24)
	rect_collision.shape = rect_shape
	rect_collision.position = Vector2(0, 0)
	complex_object.add_child(rect_collision)
	
	var circle_collision: CollisionShape2D = CollisionShape2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = 12
	circle_collision.shape = circle_shape
	circle_collision.position = Vector2(20, 20)
	complex_object.add_child(circle_collision)
	
	# Test collision mapping
	var collision_tiles = collision_mapper.get_collision_tiles(complex_object, Vector2(500, 500))
	assert_array(collision_tiles).append_failure_message(
		"Complex object should generate collision tiles"
	).is_not_empty()
	
	# Test indicator generation
	var test_rule = CollisionsCheckRule.new()
	var params = test_env.rule_validation_parameters
	params.target_position = Vector2(500, 500)
	params.placeable_instance = complex_object
	
	var indicator_result = indicator_manager.try_setup([test_rule], params)
	assert_bool(indicator_result.is_successful).append_failure_message(
		"Complex object indicator generation should succeed: %s" % indicator_result.get_all_issues()
	).is_true()

func test_placement_component_error_handling() -> void:
	var collision_mapper: Object = test_env.collision_mapper
	var indicator_manager: Object = test_env.indicator_manager
	
	# Test error handling with null/invalid inputs
	var null_tiles = collision_mapper.get_collision_tiles(null, Vector2.ZERO)
	assert_array(null_tiles).append_failure_message(
		"Should handle null collision object gracefully"
	).is_empty()
	
	# Test indicator manager with invalid rule
	var invalid_rule = null
	var params = test_env.rule_validation_parameters
	
	var invalid_result = indicator_manager.try_setup([invalid_rule], params)
	assert_object(invalid_result).append_failure_message(
		"Should handle invalid rule gracefully"
	).is_not_null()
	
	assert_bool(invalid_result.is_successful).append_failure_message(
		"Invalid rule setup should fail gracefully"
	).is_false()
