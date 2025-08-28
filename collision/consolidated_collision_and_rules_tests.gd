extends GdUnitTestSuite

## Consolidated Collision and Rules Test Suite
## Consolidates: collision_geometry_calculator_test.gd, collision_geometry_calculator_debug_test.gd,
## collisions_check_rule_test.gd, tile_check_rule_test.gd, collision_mapper_test.gd components

## MARK FOR REMOVAL - collision_geometry_calculator_test.gd, collision_geometry_calculator_debug_test.gd,
## test_collisions_check_rule.gd, tile_check_rule_test.gd

var test_env: Dictionary

func before_test() -> void:
	test_env = UnifiedTestFactory.create_placement_system_test_environment(self)
	test_env.rule_validation_parameters = UnifiedTestFactory.create_rule_validation_parameters(self)
	test_env.merge(UnifiedTestFactory.create_collision_mapper_setup(self))

# ===== COLLISION GEOMETRY CALCULATOR TESTS =====

func test_collision_calculator_tile_overlap_empty() -> void:
	var empty_polygon: PackedVector2Array = PackedVector2Array()
	var tile_size: Vector2 = Vector2(16, 16)
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		empty_polygon, tile_size, GBEnums.TileType.SQUARE
	)
	
	assert_array(overlapped_tiles).append_failure_message(
		"Empty polygon should produce no overlapped tiles"
	).is_empty()

func test_collision_calculator_single_point() -> void:
	var single_point: PackedVector2Array = PackedVector2Array([Vector2(8, 8)])
	var tile_size: Vector2 = Vector2(16, 16)
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		single_point, tile_size, GBEnums.TileType.SQUARE
	)
	
	assert_int(overlapped_tiles.size()).append_failure_message(
		"Single point cannot form valid polygon (need 3+ vertices)"
	).is_equal(0)

func test_collision_calculator_rectangle_overlap() -> void:
	var rectangle: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)
	])
	var tile_size: Vector2 = Vector2(16, 16)
	
	var overlapped_tiles = CollisionGeometryCalculator.calculate_tile_overlap(
		rectangle, tile_size, GBEnums.TileType.SQUARE
	)
	
	assert_int(overlapped_tiles.size()).append_failure_message(
		"32x32 rectangle should overlap 4 tiles (2x2), got %d" % overlapped_tiles.size()
	).is_equal(4)
	
	# Verify specific tile positions
	assert_bool(overlapped_tiles.has(Vector2i(0, 0))).is_true()
	assert_bool(overlapped_tiles.has(Vector2i(1, 0))).is_true()
	assert_bool(overlapped_tiles.has(Vector2i(0, 1))).is_true()
	assert_bool(overlapped_tiles.has(Vector2i(1, 1))).is_true()

func test_collision_detection_no_collision() -> void:
	var shape1: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
	var shape2: PackedVector2Array = PackedVector2Array([Vector2(32, 32), Vector2(48, 32), Vector2(48, 48), Vector2(32, 48)])
	
	var collision = CollisionGeometryCalculator.detect_collisions(shape1, shape2)
	
	assert_bool(collision).append_failure_message(
		"Separated rectangles should not collide"
	).is_false()

func test_collision_detection_with_collision() -> void:
	var shape1: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
	var shape2: PackedVector2Array = PackedVector2Array([Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)])
	
	var collision = CollisionGeometryCalculator.detect_collisions(shape1, shape2)
	
	assert_bool(collision).append_failure_message(
		"Overlapping rectangles should collide"
	).is_true()

# ===== POLYGON BOUNDS TESTS =====

func test_get_polygon_bounds_empty() -> void:
	var empty_polygon: PackedVector2Array = PackedVector2Array()
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(empty_polygon)
	
	assert_vector(bounds.position).is_equal(Vector2.ZERO)
	assert_vector(bounds.size).is_equal(Vector2.ZERO)

func test_get_polygon_bounds_single_point() -> void:
	var single_point: PackedVector2Array = PackedVector2Array([Vector2(5, 5)])
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(single_point)
	
	assert_vector(bounds.position).append_failure_message(
		"Single point bounds position should be the point itself"
	).is_equal(Vector2(5, 5))

func test_get_polygon_bounds_rectangle() -> void:
	var rectangle: PackedVector2Array = PackedVector2Array([Vector2(1, 2), Vector2(5, 2), Vector2(5, 6), Vector2(1, 6)])
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(rectangle)
	
	assert_vector(bounds.position).append_failure_message(
		"Rectangle bounds position should be top-left corner"
	).is_equal(Vector2(1, 2))
	assert_vector(bounds.size).append_failure_message(
		"Rectangle bounds size should be width x height"
	).is_equal(Vector2(4, 4))

# ===== POLYGON OVERLAP TESTS =====

func test_polygon_overlaps_rect_no_overlap() -> void:
	var polygon: PackedVector2Array = PackedVector2Array([Vector2(32, 32), Vector2(48, 32), Vector2(48, 48), Vector2(32, 48)])
	var rect = Rect2(0, 0, 16, 16)
	
	var overlap = CollisionGeometryCalculator._polygon_overlaps_rect(polygon, rect, 0.01, 0.05)
	
	assert_bool(overlap).append_failure_message(
		"Separated polygon and rect should not overlap"
	).is_false()

func test_polygon_overlaps_rect_with_overlap() -> void:
	var polygon: PackedVector2Array = PackedVector2Array([Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)])
	var rect = Rect2(0, 0, 16, 16)
	
	var overlap = CollisionGeometryCalculator._polygon_overlaps_rect(polygon, rect, 0.01, 0.05)
	
	assert_bool(overlap).append_failure_message(
		"Overlapping polygon and rect should overlap"
	).is_true()

# ===== POINT IN POLYGON TESTS =====

func test_point_in_polygon_inside() -> void:
	var polygon: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var point: Vector2 = Vector2(5, 5)
	
	var inside = CollisionGeometryCalculator._point_in_polygon(point, polygon)
	
	assert_bool(inside).append_failure_message(
		"Point (5,5) should be inside rectangle (0,0)-(10,10)"
	).is_true()

func test_point_in_polygon_outside() -> void:
	var polygon: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var point: Vector2 = Vector2(15, 15)
	
	var inside = CollisionGeometryCalculator._point_in_polygon(point, polygon)
	
	assert_bool(inside).append_failure_message(
		"Point (15,15) should be outside rectangle (0,0)-(10,10)"
	).is_false()

# ===== LINE INTERSECTION TESTS =====

func test_lines_intersect_crossing() -> void:
	var line1_start: Vector2 = Vector2(0, 5)
	var line1_end: Vector2 = Vector2(10, 5)
	var line2_start: Vector2 = Vector2(5, 0)
	var line2_end: Vector2 = Vector2(5, 10)
	
	var intersection = CollisionGeometryCalculator._lines_intersect(line1_start, line1_end, line2_start, line2_end)
	
	assert_bool(intersection).append_failure_message(
		"Perpendicular crossing lines should intersect"
	).is_true()

func test_lines_intersect_parallel() -> void:
	var line1_start: Vector2 = Vector2(0, 0)
	var line1_end: Vector2 = Vector2(10, 0)
	var line2_start: Vector2 = Vector2(0, 5)
	var line2_end: Vector2 = Vector2(10, 5)
	
	var intersection = CollisionGeometryCalculator._lines_intersect(line1_start, line1_end, line2_start, line2_end)
	
	assert_bool(intersection).append_failure_message(
		"Parallel lines should not intersect"
	).is_false()

# ===== POLYGON INTERSECTION TESTS =====

func test_polygons_intersect_overlapping() -> void:
	var poly1: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var poly2: PackedVector2Array = PackedVector2Array([Vector2(5, 5), Vector2(15, 5), Vector2(15, 15), Vector2(5, 15)])
	
	var intersection = CollisionGeometryCalculator._polygons_intersect(poly1, poly2, 0.01)
	
	assert_bool(intersection).append_failure_message(
		"Overlapping rectangles should intersect"
	).is_true()

func test_polygons_intersect_separate() -> void:
	var poly1: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var poly2: PackedVector2Array = PackedVector2Array([Vector2(20, 20), Vector2(30, 20), Vector2(30, 30), Vector2(20, 30)])
	
	var intersection = CollisionGeometryCalculator._polygons_intersect(poly1, poly2, 0.01)
	
	assert_bool(intersection).append_failure_message(
		"Separated rectangles should not intersect"
	).is_false()

# ===== DEBUG EDGE CASE TESTS =====

func test_debug_edge_case_tiny_polygon() -> void:
	var tiny_polygon: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0.1), Vector2(0, 0.1)])
	var bounds = CollisionGeometryCalculator._get_polygon_bounds(tiny_polygon)
	
	assert_float(bounds.size.x).append_failure_message(
		"Tiny polygon should have measurable width"
	).is_equal_approx(0.1, 0.01)
	assert_float(bounds.size.y).append_failure_message(
		"Tiny polygon should have measurable height"
	).is_equal_approx(0.1, 0.01)

func test_debug_edge_case_degenerate_shapes() -> void:
	# Test line segment (degenerate polygon)
	var line_segment: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])
	var line_bounds = CollisionGeometryCalculator._get_polygon_bounds(line_segment)
	
	assert_float(line_bounds.size.x).is_equal(10.0)
	assert_float(line_bounds.size.y).is_equal(0.0)
	
	# Test single point boundary
	var boundary_point: PackedVector2Array = PackedVector2Array([Vector2(15.9, 15.9)])
	var point_bounds = CollisionGeometryCalculator._get_polygon_bounds(boundary_point)
	
	assert_vector(point_bounds.position).is_equal_approx(Vector2(15.9, 15.9), Vector2(0.01, 0.01))

# ===== COLLISION RULES TESTS =====

func test_collisions_check_rule_validation() -> void:
	var rule = CollisionsCheckRule.new()
	
	# Test validation before setup (should fail)
	var pre_setup_result = rule.validate_condition()
	assert_object(pre_setup_result).is_not_null()
	assert_bool(pre_setup_result.is_successful).append_failure_message(
		"Collision rule should fail validation before setup"
	).is_false()

func test_collisions_check_rule_setup() -> void:
	var rule = CollisionsCheckRule.new()
	
	# Create setup parameters
	var params = test_env.rule_validation_parameters
	
	# Setup rule
	var setup_issues = rule.setup(params)
	
	# After setup, validation should succeed (assuming valid environment)
	assert_array(setup_issues).append_failure_message(
		"Rule setup should succeed with valid parameters: %s" % str(setup_issues)
	).is_empty()

func test_tile_check_rule_basic() -> void:
	var rule = TileCheckRule.new()
	var params = test_env.rule_validation_parameters
	
	# Setup and validate
	var setup_issues = rule.setup(params)
	assert_array(setup_issues).append_failure_message(
		"Tile rule setup should succeed: %s" % str(setup_issues)
	).is_empty()
	
	var validation_result = rule.validate_condition()
	assert_object(validation_result).is_not_null()

# ===== COMPREHENSIVE COLLISION MAPPING TESTS =====

func test_collision_mapper_shape_processing() -> void:
	var collision_mapper: Object = test_env.collision_mapper
	var test_object: Node2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)

	# Set up collision mapper with test object
	var test_parent: Node2D = Node2D.new()
	test_parent.name = "TestParent"
	add_child(test_parent)
	auto_free(test_parent)

	# Manually create collision test setup for the StaticBody2D
	var test_setup = IndicatorCollisionTestSetup.new(test_object, Vector2(16, 16), test_env.logger)
	var collision_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {test_object: test_setup}

	# Create a test indicator
	var test_indicator = RuleCheckIndicator.new([])
	test_indicator.name = "TestIndicator"
	test_parent.add_child(test_indicator)
	auto_free(test_indicator)

	# Setup collision mapper directly
	collision_mapper.setup(test_indicator, collision_setups)

	# Test collision shape processing
	var test_objects: Array[Node2D] = [test_object]
	var collision_results = collision_mapper.get_collision_tile_positions_with_mask(test_objects, 1)

	# Should return some collision tiles for test object
	assert_dict(collision_results).append_failure_message(
		"Test collision object should generate collision tiles"
	).is_not_empty()

func test_collision_mapper_caching() -> void:
	var collision_mapper: Object = test_env.collision_mapper
	
	# Test caching mechanism if available
	if collision_mapper.has_method("_get_cached_geometry_result"):
		var test_key: String = "test_cache_key"
		var calc_func = func(): return "test_result"
		
		var result1 = collision_mapper._get_cached_geometry_result(test_key, calc_func)
		var result2 = collision_mapper._get_cached_geometry_result(test_key, calc_func)
		
		assert_str(result1).append_failure_message(
			"First cache result should be from calculation"
		).is_equal("test_result")
		assert_str(result2).append_failure_message(
			"Second cache result should be from cache (same value)"
		).is_equal("test_result")

# ===== INTEGRATION VALIDATION TESTS =====

func test_rules_and_collision_integration() -> void:
	var collision_mapper: Object = test_env.collision_mapper  
	var rule = CollisionsCheckRule.new()
	var params = test_env.rule_validation_parameters
	
	# Setup rule with collision context
	var setup_issues = rule.setup(params)
	assert_array(setup_issues).is_empty()
	
	# Test that collision mapper and rules work together
	var test_object: Node2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
	
	# Set up collision mapper with test object
	var indicator_manager = UnifiedTestFactory.create_test_indicator_manager(self)
	var test_parent: Node2D = Node2D.new()
	test_parent.name = "TestParent2"
	add_child(test_parent)
	auto_free(test_parent)
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, test_object, null, test_parent)
	
	var test_objects: Array[Node2D] = [test_object]
	var collision_tiles = collision_mapper.get_collision_tile_positions_with_mask(test_objects, 1)
	
	# Validate integration produces reasonable results
	assert_dict(collision_tiles).append_failure_message(
		"Collision mapping should produce tiles for rule validation"
	).is_not_empty()
	
	var validation_result = rule.validate_condition()
	assert_object(validation_result).append_failure_message(
		"Rule validation should complete with collision context"
	).is_not_null()
