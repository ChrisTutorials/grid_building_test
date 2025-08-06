extends GdUnitTestSuite

## Tests for private helper functions in CollisionMapper performance caching system

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var collision_mapper: CollisionMapper
var targeting_state: GridTargetingState
var logger: GBLogger

func before_test():
	# Create test dependencies
	var owner_context: GBOwnerContext = auto_free(GBOwnerContext.new())
	var user: Node2D = auto_free(Node2D.new())
	add_child(user)
owner_context.set_owner(user)
	targeting_state = auto_free(GridTargetingState.new(owner_context))

	# Create tile map with known tile size
	var tile_map_layer: TileMapLayer = auto_free(TileMapLayer.new())
	var tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_map_layer.tile_set = tile_set
	add_child(tile_map_layer)

	# Create positioner at known position
	var positioner: Node2D = auto_free(Node2D.new())
	positioner.global_position = Vector2(100, 100)
	add_child(positioner)

	# Set up targeting state
	targeting_state.positioner = positioner
	targeting_state.target_map = tile_map_layer

	# Create logger and collision mapper
	logger = GBLogger.new(GBDebugSettings.new())
	collision_mapper = auto_free(CollisionMapper.new(targeting_state, logger))

## Test _get_cached_polygon_bounds helper method with various polygon shapes
func test_get_cached_polygon_bounds_helper(polygon: PackedVector2Array, expected_bounds: Rect2, _test_parameters := [
	[PackedVector2Array([Vector2(10, 5), Vector2(30, 5), Vector2(30, 25), Vector2(10, 25)]), Rect2(10, 5, 20, 20)],
	[PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)]), Rect2(0, 0, 16, 16)],
	[PackedVector2Array([Vector2(-8, -4), Vector2(8, -4), Vector2(8, 4), Vector2(-8, 4)]), Rect2(-8, -4, 16, 8)],
	[PackedVector2Array([Vector2(100, 200), Vector2(150, 200), Vector2(150, 250), Vector2(100, 250)]), Rect2(100, 200, 50, 50)],
]):
	var bounds = collision_mapper._get_cached_polygon_bounds(polygon)
	assert_vector(bounds.position).is_equal_approx(expected_bounds.position, Vector2.ONE)
	assert_vector(bounds.size).is_equal_approx(expected_bounds.size, Vector2.ONE)
	
	# Verify caching by checking cache size increases
	var initial_cache_size = collision_mapper._polygon_bounds_cache.size()
	var cached_bounds = collision_mapper._get_cached_polygon_bounds(polygon)
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(initial_cache_size)
	assert_vector(cached_bounds.position).is_equal(bounds.position)
	assert_vector(cached_bounds.size).is_equal(bounds.size)

## Test _get_cached_tile_polygon helper method with different tile configurations
func test_get_cached_tile_polygon_helper(tile_pos: Vector2, tile_size: Vector2, tile_type: int, expected_vertices: int, _test_parameters := [
	[Vector2(0, 0), Vector2(16, 16), 0, 4],      # Square tile at origin
	[Vector2(32, 32), Vector2(16, 16), 0, 4],    # Square tile offset
	[Vector2(64, 64), Vector2(32, 32), 0, 4],    # Larger square tile
	[Vector2(16, 8), Vector2(8, 8), 1, 4],       # Isometric tile (diamond shape)
]):
	var polygon = collision_mapper._get_cached_tile_polygon(tile_pos, tile_size, tile_type)
	assert_int(polygon.size()).is_equal(expected_vertices)
	
	# Verify polygon is not empty and has reasonable bounds
	if polygon.size() > 0:
		var bounds = GBGeometryMath.get_polygon_bounds(polygon)
		assert_float(bounds.size.x).is_greater(0.0)
		assert_float(bounds.size.y).is_greater(0.0)
	
	# Verify caching behavior
	var initial_cache_size = collision_mapper._tile_polygon_cache.size()
	var cached_polygon = collision_mapper._get_cached_tile_polygon(tile_pos, tile_size, tile_type)
	assert_int(collision_mapper._tile_polygon_cache.size()).is_equal(initial_cache_size)
	assert_int(cached_polygon.size()).is_equal(polygon.size())

## Test _get_cached_geometry_result helper with different calculation functions
func test_get_cached_geometry_result_helper():
	var expensive_calculation = func() -> Dictionary:
		# Simulate expensive calculation
		return {"result": "expensive_value", "calculated_at": Time.get_ticks_msec()}
	
	var cache_key = "expensive_operation"
	
	# First call should execute calculation
	var result1 = collision_mapper._get_cached_geometry_result(cache_key, expensive_calculation)
	assert_object(result1).is_not_null()
	assert_str(result1["result"]).is_equal("expensive_value")
	var first_time = result1["calculated_at"]
	
	# Second call should return cached result (same timestamp proves no recalculation)
	var result2 = collision_mapper._get_cached_geometry_result(cache_key, expensive_calculation)
	assert_str(result2["result"]).is_equal("expensive_value")
	assert_int(result2["calculated_at"]).is_equal(first_time)
	
	# Different cache key should trigger new calculation
	var result3 = collision_mapper._get_cached_geometry_result("different_key", expensive_calculation)
	assert_int(result3["calculated_at"]).is_greater_equal(first_time)

## Test cache helper methods with complex geometries
func test_cache_helpers_with_complex_geometry():
	# Test with triangle
	var triangle = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 8)])
	var triangle_bounds = collision_mapper._get_cached_polygon_bounds(triangle)
	assert_vector(triangle_bounds.position).is_equal(Vector2(0, 0))
	assert_vector(triangle_bounds.size).is_equal(Vector2(10, 8))
	
	# Test with complex polygon (hexagon)
	var hexagon = PackedVector2Array()
	var center = Vector2(50, 50)
	var radius = 20.0
	for i in range(6):
		var angle = i * PI * 2.0 / 6
		hexagon.append(center + Vector2(cos(angle), sin(angle)) * radius)
	
	var hexagon_bounds = collision_mapper._get_cached_polygon_bounds(hexagon)
	assert_float(hexagon_bounds.size.x).is_greater(35.0)  # Should be about 40
	assert_float(hexagon_bounds.size.y).is_greater(35.0)  # Should be about 40
	
	# Verify both are cached
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(2)

## Test cache invalidation behavior
func test_cache_invalidation_helper_integration():
	# Add some data to caches
	var test_polygon = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	collision_mapper._get_cached_polygon_bounds(test_polygon)
	collision_mapper._get_cached_tile_polygon(Vector2(16, 16), Vector2(8, 8), 0)
	collision_mapper._get_cached_geometry_result("test_key", func(): return "test_value")
	
	# Verify caches have data
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_greater(0)
	assert_int(collision_mapper._tile_polygon_cache.size()).is_greater(0)
	assert_int(collision_mapper._geometry_cache.size()).is_greater(0)
	
	# Trigger cache invalidation via setup
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	test_indicator.shape = RectangleShape2D.new()
	add_child(test_indicator)
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	
	collision_mapper.setup(test_indicator, collision_object_test_setups)
	
	# Verify all caches are cleared
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(0)
	assert_int(collision_mapper._tile_polygon_cache.size()).is_equal(0)
	assert_int(collision_mapper._geometry_cache.size()).is_equal(0)

## Test edge cases for cache helper methods
func test_cache_helpers_edge_cases():
	# Test with empty polygon
	var empty_polygon = PackedVector2Array()
	var empty_bounds = collision_mapper._get_cached_polygon_bounds(empty_polygon)
	assert_vector(empty_bounds.size).is_equal(Vector2.ZERO)
	
	# Test with single point polygon
	var point_polygon = PackedVector2Array([Vector2(5, 5)])
	var point_bounds = collision_mapper._get_cached_polygon_bounds(point_polygon)
	assert_vector(point_bounds.position).is_equal(Vector2(5, 5))
	assert_vector(point_bounds.size).is_equal(Vector2.ZERO)
	
	# Test with line polygon (2 points)
	var line_polygon = PackedVector2Array([Vector2(0, 0), Vector2(10, 10)])
	var line_bounds = collision_mapper._get_cached_polygon_bounds(line_polygon)
	assert_vector(line_bounds.position).is_equal(Vector2(0, 0))
	assert_vector(line_bounds.size).is_equal(Vector2(10, 10))
	
	# Test with zero-size tile
	var zero_tile = collision_mapper._get_cached_tile_polygon(Vector2.ZERO, Vector2.ZERO, 0)
	assert_int(zero_tile.size()).is_greater_equal(0)  # Should handle gracefully

## Test cache performance improvement measurement
func test_cache_performance_measurement():
	var large_polygon = PackedVector2Array()
	# Create a complex polygon with many vertices
	for i in range(50):
		var angle = i * PI * 2.0 / 50
		large_polygon.append(Vector2(cos(angle), sin(angle)) * 100 + Vector2(200, 200))
	
	# Measure time without cache (first call)
	var start_time = Time.get_ticks_usec()
	var bounds1 = collision_mapper._get_cached_polygon_bounds(large_polygon)
	var first_call_time = Time.get_ticks_usec() - start_time
	
	# Measure time with cache (second call)
	start_time = Time.get_ticks_usec()
	var bounds2 = collision_mapper._get_cached_polygon_bounds(large_polygon)
	var cached_call_time = Time.get_ticks_usec() - start_time
	
	# Cached call should be significantly faster
	assert_int(cached_call_time).is_less(first_call_time)
	assert_vector(bounds1.position).is_equal(bounds2.position)
	assert_vector(bounds1.size).is_equal(bounds2.size)
	
	print("First call: %d microseconds, Cached call: %d microseconds" % [first_call_time, cached_call_time])
	print("Cache speedup: %.2fx" % (float(first_call_time) / max(cached_call_time, 1)))

## Test cache memory usage patterns
func test_cache_memory_usage_patterns():
	var initial_cache_count = collision_mapper._polygon_bounds_cache.size()
	
	# Generate many different polygons
	for i in range(20):
		var rect_polygon = PackedVector2Array([
			Vector2(i * 10, i * 5), 
			Vector2(i * 10 + 15, i * 5),
			Vector2(i * 10 + 15, i * 5 + 12),
			Vector2(i * 10, i * 5 + 12)
		])
		collision_mapper._get_cached_polygon_bounds(rect_polygon)
	
	# Cache should grow but not excessively
	var final_cache_count = collision_mapper._polygon_bounds_cache.size()
	assert_int(final_cache_count).is_greater(initial_cache_count)
	assert_int(final_cache_count).is_equal(initial_cache_count + 20)
	
	# Memory usage should be reasonable (each entry is small)
	# This is more of a documentation test than assertion
	print("Cache entries: %d" % final_cache_count)

## Test concurrent cache access simulation
func test_concurrent_cache_access_simulation():
	var test_polygon = PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 15), Vector2(0, 15)])
	
	# Simulate multiple systems accessing same cached data
	var results: Array[Rect2] = []
	for i in range(10):
		results.append(collision_mapper._get_cached_polygon_bounds(test_polygon))
	
	# All results should be identical
	var first_result = results[0]
	for result in results:
		assert_vector(result.position).is_equal(first_result.position)
		assert_vector(result.size).is_equal(first_result.size)
	
	# Should only create one cache entry despite multiple calls
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(1)
