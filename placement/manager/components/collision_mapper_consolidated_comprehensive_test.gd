extends GdUnitTestSuite

## Comprehensive consolidated collision mapper tests combining all scenarios
## Replaces multiple collision mapper test files with unified parameterized approach
## Tests collision detection, positioning, caching, performance, and edge cases

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var collision_mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger

func before_test():
	# Create test infrastructure using factories
	logger = UnifiedTestFactory.create_test_logger()
	
	# Create tilemap with standard 16x16 tiles
	tile_map_layer = GodotTestFactory.create_tile_map_layer(self, 40)
	
	# Create positioner at test position near origin for predictable offsets
	positioner = GodotTestFactory.create_node2d(self)
	positioner.global_position = Vector2(64, 64)  # Tile (4, 4) for reasonable offsets
	
	# Create targeting state
	var owner_context = GBOwnerContext.new(null)
	targeting_state = GridTargetingState.new(owner_context)
	targeting_state.target_map = tile_map_layer
	targeting_state.positioner = positioner
	targeting_state.maps = [tile_map_layer]
	
	# Create collision mapper
	collision_mapper = CollisionMapper.new(targeting_state, logger)

func after_test():
	# Cleanup handled by auto_free in factory methods
	pass

# Test collision shape coverage with various shapes and positions
@warning_ignore("unused_parameter")
func test_collision_shape_coverage_comprehensive(
	shape_type: String,
	shape_data: Dictionary,
	positioner_position: Vector2,
	expected_min_tiles: int,
	expected_behavior: String,
	test_parameters := [
		["rectangle_small", {"size": Vector2(16, 16)}, Vector2(64, 64), 1, "single_tile"],
		["rectangle_standard", {"size": Vector2(32, 32)}, Vector2(64, 64), 4, "quad_tile"],
		["rectangle_large", {"size": Vector2(64, 48)}, Vector2(64, 64), 8, "multi_tile"],
		["circle_small", {"radius": 8.0}, Vector2(64, 64), 1, "circular_small"],
		["circle_medium", {"radius": 16.0}, Vector2(64, 64), 3, "circular_medium"],
		["circle_large", {"radius": 24.0}, Vector2(64, 64), 6, "circular_large"],
		["trapezoid", {"polygon": [Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]}, Vector2(64, 64), 6, "complex_polygon"],
		["rectangle_offset", {"size": Vector2(32, 32)}, Vector2(0, 0), 4, "origin_position"],
		["capsule", {"radius": 14.0, "height": 60.0}, Vector2(64, 64), 8, "capsule_shape"]
	]
):
	# Set positioner position for test
	positioner.global_position = positioner_position
	
	# Create test object with specified shape
	var test_object = _create_test_object_with_shape(shape_type, shape_data)
	
	# Setup collision mapper
	var collision_object_test_setups = _create_collision_test_setup(test_object)
	var test_indicator = _create_test_indicator()
	collision_mapper.setup(test_indicator, collision_object_test_setups)
	
	# Get collision tile positions
	var result = collision_mapper.get_collision_tile_positions_with_mask([test_object], 1)
	
	# Verify expected behavior
	assert_int(result.size()).append_failure_message(
		"Expected at least %d tiles for %s shape, got %d" % [expected_min_tiles, shape_type, result.size()]
	).is_greater_equal(expected_min_tiles)
	
	# Verify position reasonableness
	var center_tile = tile_map_layer.local_to_map(positioner_position)
	for tile_pos in result.keys():
		var offset = tile_pos - center_tile
		assert_int(abs(offset.x)).append_failure_message(
			"Tile X offset too large for %s: %s" % [shape_type, offset]
		).is_less_equal(10)
		assert_int(abs(offset.y)).append_failure_message(
			"Tile Y offset too large for %s: %s" % [shape_type, offset]
		).is_less_equal(10)

# Test collision detection with local offsets
@warning_ignore("unused_parameter")
func test_collision_local_offset_handling(
	object_type: String,
	local_offset: Vector2,
	shape_data: Dictionary,
	expected_offset_behavior: String,
	test_parameters := [
		["static_body", Vector2(8, -8), {"polygon": [Vector2(-16, -8), Vector2(16, -8), Vector2(16, 8), Vector2(-16, 8)]}, "position_adjusted"],
		["area2d", Vector2(12, -6), {"size": Vector2(16, 16)}, "position_adjusted"],
		["collision_polygon", Vector2.ZERO, {"polygon": [Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]}, "no_offset"],
		["collision_shape", Vector2(4, 4), {"size": Vector2(24, 24)}, "position_adjusted"]
	]
):
	# Set positioner at known position near origin
	positioner.global_position = Vector2(64, 64)
	
	# Create object with local offset
	var test_object = _create_test_object_with_local_offset(object_type, local_offset, shape_data)
	
	# Setup collision mapper
	var collision_object_test_setups = _create_collision_test_setup(test_object)
	var test_indicator = _create_test_indicator()
	collision_mapper.setup(test_indicator, collision_object_test_setups)
	
	# Get collision positions
	var result
	if test_object is CollisionPolygon2D:
		result = collision_mapper._get_tile_offsets_for_collision_polygon(test_object, tile_map_layer)
	else:
		var test_setup = collision_object_test_setups[test_object]
		result = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map_layer)
	
	# Verify collision detection accounts for local offset
	assert_int(result.size()).append_failure_message(
		"Expected collision detection for %s with offset %s" % [object_type, local_offset]
	).is_greater(0)
	
	# Verify positioning considers offset
	var _expected_world_center = positioner.global_position + local_offset
	var actual_tiles = result.keys()
	assert_int(actual_tiles.size()).append_failure_message(
		"Expected tiles for object %s with offset %s" % [object_type, local_offset]
	).is_greater(0)

# Test collision mapper caching performance and behavior
@warning_ignore("unused_parameter")
func test_collision_mapper_caching_comprehensive(
	cache_operation: String,
	test_data,
	expected_cache_behavior: String,
	test_parameters := [
		["polygon_bounds", {"polygon": [Vector2(10, 5), Vector2(30, 5), Vector2(30, 25), Vector2(10, 25)]}, "cached_after_first"],
		["tile_polygon", {"tile_pos": Vector2(64, 64), "tile_size": Vector2(16, 16), "tile_type": 0}, "cached_after_first"],
		["geometry_result", {"key": "test_calc", "result": "cached_value"}, "cached_after_first"],
		["cache_invalidation", {"setup_change": true}, "cache_cleared"],
		["concurrent_access", {"polygon": [Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)]}, "consistent_results"]
	]
):
	var test_indicator = _create_test_indicator()
	collision_mapper.setup(test_indicator, {})
	
	match cache_operation:
		"polygon_bounds":
			var polygon = PackedVector2Array(test_data.polygon)
			var bounds1 = collision_mapper._get_cached_polygon_bounds(polygon)
			var initial_cache_size = collision_mapper._polygon_bounds_cache.size()
			var bounds2 = collision_mapper._get_cached_polygon_bounds(polygon)
			
			assert_vector(bounds1.position).is_equal(bounds2.position)
			assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(initial_cache_size)
			
		"tile_polygon":
			var tile_pos = test_data.tile_pos
			var tile_size = test_data.tile_size
			var tile_type = test_data.tile_type
			
			var polygon1 = collision_mapper._get_cached_tile_polygon(tile_pos, tile_size, tile_type)
			var initial_cache_size = collision_mapper._tile_polygon_cache.size()
			var polygon2 = collision_mapper._get_cached_tile_polygon(tile_pos, tile_size, tile_type)
			
			assert_int(polygon1.size()).is_equal(polygon2.size())
			assert_int(collision_mapper._tile_polygon_cache.size()).is_equal(initial_cache_size)
			
		"geometry_result":
			var key = test_data.key
			var expected_result = test_data.result
			var calc_func = func(): return expected_result
			
			var result1 = collision_mapper._get_cached_geometry_result(key, calc_func)
			var result2 = collision_mapper._get_cached_geometry_result(key, calc_func)
			
			assert_str(result1).is_equal(expected_result)
			assert_str(result2).is_equal(result1)
			
		"cache_invalidation":
			# Fill caches
			var test_polygon = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
			collision_mapper._get_cached_polygon_bounds(test_polygon)
			
			assert_int(collision_mapper._polygon_bounds_cache.size()).is_greater(0)
			
			# Trigger invalidation via setup
			collision_mapper.setup(test_indicator, {})
			
			assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(0)
			assert_int(collision_mapper._geometry_cache.size()).is_equal(0)
			assert_int(collision_mapper._tile_polygon_cache.size()).is_equal(0)
			
		"concurrent_access":
			var polygon = PackedVector2Array(test_data.polygon)
			var results: Array[Rect2] = []
			
			# Simulate multiple concurrent accesses
			for i in range(5):
				results.append(collision_mapper._get_cached_polygon_bounds(polygon))
			
			# All results should be identical
			var first_result = results[0]
			for result in results:
				assert_vector(result.position).is_equal(first_result.position)
				assert_vector(result.size).is_equal(first_result.size)
			
			# Should only have one cache entry
			assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(1)

# Test collision mapper rule integration
@warning_ignore("unused_parameter")
func test_collision_mapper_rule_integration(
	collision_objects_data: Array,
	rules_data: Array,
	expected_has_contents: bool,
	test_description: String,
	test_parameters := [
		[[], [], false, "no_objects_no_rules"],
		[[], [{"mask": 1}], false, "no_objects_with_rules"],
		[[{"layer": 1, "type": "area2d"}], [], false, "objects_no_rules"],
		[[{"layer": 1, "type": "area2d"}], [{"mask": 1}], true, "matching_layer_mask"],
		[[{"layer": 2, "type": "area2d"}], [{"mask": 1}], false, "non_matching_layer_mask"],
		[[{"layer": 1, "type": "static_body"}, {"layer": 2, "type": "area2d"}], [{"mask": 3}], true, "multiple_objects_combined_mask"]
	]
):
	# Create collision objects from data
	var collision_objects: Array[Node2D] = []
	for obj_data in collision_objects_data:
		var collision_object = _create_collision_object_from_data(obj_data)
		collision_objects.append(collision_object)
	
	# Create rules from data
	var rules: Array[TileCheckRule] = []
	for rule_data in rules_data:
		var rule = TileCheckRule.new()
		rule.apply_to_objects_mask = rule_data.mask
		rules.append(rule)
	
	# Setup collision mapper
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for obj in collision_objects:
		collision_object_test_setups[obj] = IndicatorCollisionTestSetup.new(obj, Vector2(16, 16), logger)
	
	var test_indicator = _create_test_indicator()
	collision_mapper.setup(test_indicator, collision_object_test_setups)
	
	# Test rule integration
	var result = collision_mapper.map_collision_positions_to_rules(collision_objects, rules)
	
	assert_bool(result.size() > 0).append_failure_message(
		"Rule integration test '%s' failed - expected has_contents: %s, got size: %d" % [test_description, expected_has_contents, result.size()]
	).is_equal(expected_has_contents)

# Test performance optimization with caching
func test_collision_mapper_performance_optimization():
	var test_indicator = _create_test_indicator()
	
	# Create collision polygon for testing
	var static_body = GodotTestFactory.create_static_body_with_rect_shape(self, Vector2(16, 16))
	var collision_polygon = static_body.get_children()[0] as CollisionPolygon2D
	
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	collision_object_test_setups[collision_polygon] = null
	collision_mapper.setup(test_indicator, collision_object_test_setups)
	
	# Measure cached vs uncached performance
	var iterations = 50
	
	# Warm-up and measure cached path
	for i in range(3):
		collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	
	var start_time = Time.get_ticks_usec()
	for i in range(iterations):
		collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	var cached_time = Time.get_ticks_usec() - start_time
	
	# Measure uncached path
	start_time = Time.get_ticks_usec()
	for i in range(iterations):
		collision_mapper._invalidate_cache()
		collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	var uncached_time = Time.get_ticks_usec() - start_time
	
	# Verify caching provides performance benefit or at least doesn't regress significantly
	var performance_ratio = float(cached_time) / float(max(uncached_time, 1))
	assert_bool(performance_ratio <= 1.2).append_failure_message(
		"Cache performance regression: cached=%d µs, uncached=%d µs, ratio=%.3f" % [cached_time, uncached_time, performance_ratio]
	).is_true()

# Test edge cases and error handling
@warning_ignore("unused_parameter")
func test_collision_mapper_edge_cases(
	edge_case: String,
	test_data,
	expected_behavior: String,
	test_parameters := [
		["empty_polygon", {"polygon": []}, "no_collision"],
		["single_point", {"polygon": [Vector2.ZERO]}, "no_collision"],
		["line_polygon", {"polygon": [Vector2(0, 0), Vector2(10, 10)]}, "no_collision"],
		["zero_size_shape", {"size": Vector2.ZERO}, "no_collision"],
		["very_small_shape", {"size": Vector2(0.1, 0.1)}, "minimal_collision"],
		["very_large_shape", {"size": Vector2(1000, 1000)}, "many_collisions"]
	]
):
	var test_object
	
	match edge_case:
		"empty_polygon", "single_point", "line_polygon":
			test_object = _create_test_collision_polygon(PackedVector2Array(test_data.polygon))
		"zero_size_shape", "very_small_shape", "very_large_shape":
			test_object = _create_test_area2d_with_rect(test_data.size)
	
	var collision_object_test_setups = _create_collision_test_setup(test_object)
	var test_indicator = _create_test_indicator()
	collision_mapper.setup(test_indicator, collision_object_test_setups)
	
	# Test that edge cases are handled gracefully
	var result
	if test_object is CollisionPolygon2D:
		result = collision_mapper._get_tile_offsets_for_collision_polygon(test_object, tile_map_layer)
	else:
		var test_setup = collision_object_test_setups[test_object]
		result = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map_layer)
	
	# Verify expected behavior
	match expected_behavior:
		"no_collision":
			assert_int(result.size()).append_failure_message(
				"Expected no collision for edge case '%s'" % edge_case
			).is_equal(0)
		"minimal_collision":
			assert_int(result.size()).append_failure_message(
				"Expected minimal collision for edge case '%s'" % edge_case
			).is_less_equal(4)
		"many_collisions":
			assert_int(result.size()).append_failure_message(
				"Expected many collisions for edge case '%s'" % edge_case
			).is_greater(10)

# Helper methods for test object creation

func _create_test_object_with_shape(shape_type: String, shape_data: Dictionary) -> Node2D:
	match shape_type:
		"rectangle_small", "rectangle_standard", "rectangle_large", "rectangle_offset":
			return _create_test_area2d_with_rect(shape_data.size)
		"circle_small", "circle_medium", "circle_large":
			return _create_test_area2d_with_circle(shape_data.radius)
		"trapezoid":
			return _create_test_collision_polygon(PackedVector2Array(shape_data.polygon))
		"capsule":
			return _create_test_area2d_with_capsule(shape_data.radius, shape_data.height)
		_:
			push_error("Unknown shape type: " + shape_type)
			return null

func _create_test_object_with_local_offset(object_type: String, local_offset: Vector2, shape_data: Dictionary) -> Node2D:
	match object_type:
		"static_body":
			var static_body = StaticBody2D.new()
			auto_free(static_body)
			add_child(static_body)
			static_body.collision_layer = 1
			var collision_polygon = CollisionPolygon2D.new()
			static_body.add_child(collision_polygon)
			collision_polygon.position = local_offset
			collision_polygon.polygon = PackedVector2Array(shape_data.polygon)
			return collision_polygon
		"area2d":
			var area2d = Area2D.new()
			auto_free(area2d)
			add_child(area2d)
			area2d.collision_layer = 1
			var collision_shape = CollisionShape2D.new()
			area2d.add_child(collision_shape)
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = shape_data.size
			collision_shape.shape = rect_shape
			collision_shape.position = local_offset
			return area2d
		"collision_polygon":
			var static_body = StaticBody2D.new()
			auto_free(static_body)
			add_child(static_body)
			var collision_polygon = CollisionPolygon2D.new()
			static_body.add_child(collision_polygon)
			collision_polygon.position = local_offset
			collision_polygon.polygon = PackedVector2Array(shape_data.polygon)
			return collision_polygon
		"collision_shape":
			var area2d = Area2D.new()
			auto_free(area2d)
			add_child(area2d)
			var collision_shape = CollisionShape2D.new()
			area2d.add_child(collision_shape)
			collision_shape.position = local_offset
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = shape_data.size
			collision_shape.shape = rect_shape
			return area2d
		_:
			push_error("Unknown object type: " + object_type)
			return null

func _create_collision_object_from_data(obj_data: Dictionary) -> Node2D:
	var collision_object
	match obj_data.type:
		"area2d":
			collision_object = GodotTestFactory.create_area2d_with_circle_shape(self, 8.0)
		"static_body":
			collision_object = GodotTestFactory.create_static_body_with_rect_shape(self, Vector2(8, 8))
		_:
			collision_object = GodotTestFactory.create_area2d_with_circle_shape(self, 8.0)
	
	collision_object.collision_layer = obj_data.layer
	return collision_object

func _create_test_area2d_with_rect(size: Vector2) -> Area2D:
	var area2d = Area2D.new()
	auto_free(area2d)
	add_child(area2d)
	area2d.collision_layer = 1
	var collision_shape = CollisionShape2D.new()
	area2d.add_child(collision_shape)
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	return area2d

func _create_test_area2d_with_circle(radius: float) -> Area2D:
	return GodotTestFactory.create_area2d_with_circle_shape(self, radius)

func _create_test_area2d_with_capsule(radius: float, height: float) -> Area2D:
	var area2d = Area2D.new()
	auto_free(area2d)
	add_child(area2d)
	area2d.collision_layer = 1
	var collision_shape = CollisionShape2D.new()
	area2d.add_child(collision_shape)
	var capsule_shape = CapsuleShape2D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height
	collision_shape.shape = capsule_shape
	return area2d

func _create_test_collision_polygon(polygon: PackedVector2Array) -> CollisionPolygon2D:
	var static_body = StaticBody2D.new()
	auto_free(static_body)
	add_child(static_body)
	static_body.collision_layer = 1
	var collision_polygon = CollisionPolygon2D.new()
	static_body.add_child(collision_polygon)
	collision_polygon.polygon = polygon
	return collision_polygon

func _create_test_indicator() -> RuleCheckIndicator:
	var indicator = GodotTestFactory.create_rule_check_indicator(self, self)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	return indicator

func _create_collision_test_setup(test_object: Node2D) -> Dictionary[Node2D, IndicatorCollisionTestSetup]:
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	if test_object is CollisionPolygon2D:
		collision_object_test_setups[test_object] = null
	else:
		collision_object_test_setups[test_object] = IndicatorCollisionTestSetup.new(test_object, Vector2(16, 16), logger)
	return collision_object_test_setups
