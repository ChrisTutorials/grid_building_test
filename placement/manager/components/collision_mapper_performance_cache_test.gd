extends GdUnitTestSuite

## Tests for CollisionMapper performance caching system to ensure geometry calculations are cached properly

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var collision_mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger

func before_test():
	# Create test dependencies
	var owner_context: GBOwnerContext = auto_free(GBOwnerContext.new())
	var user: Node2D = auto_free(Node2D.new())
	add_child(user)
	var gb_owner: GBOwner = auto_free(GBOwner.new(user))
	owner_context.set_owner(gb_owner)
	targeting_state = auto_free(GridTargetingState.new(owner_context))	# Create tile map with known tile size (16x16)
	tile_map_layer = auto_free(TileMapLayer.new())
	var tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_map_layer.tile_set = tile_set
	add_child(tile_map_layer)

	# Create positioner at known position
	positioner = auto_free(Node2D.new())
	positioner.global_position = Vector2(100, 100)
	add_child(positioner)

	# Set up targeting state
	targeting_state.positioner = positioner
	targeting_state.target_map = tile_map_layer

	# Create logger and collision mapper
	logger = GBLogger.new(GBDebugSettings.new())
	collision_mapper = auto_free(CollisionMapper.new(targeting_state, logger))

## Test that cache is properly invalidated when setup changes
func test_cache_invalidation_on_setup():
	# Create test indicator and setup
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	test_indicator.shape = RectangleShape2D.new()
	test_indicator.shape.size = Vector2(16, 16)
	add_child(test_indicator)

	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	
	# Initial setup
	collision_mapper.setup(test_indicator, collision_object_test_setups)
	
	# Cache some data by calling polygon bounds
	var test_polygon = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
	var _bounds1 = collision_mapper._get_cached_polygon_bounds(test_polygon)
	
	# Verify cache has data
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_greater(0)
	
	# Change setup - this should invalidate cache
	collision_mapper.setup(test_indicator, collision_object_test_setups)
	
	# Cache should be cleared
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(0)
	assert_int(collision_mapper._geometry_cache.size()).is_equal(0)
	assert_int(collision_mapper._tile_polygon_cache.size()).is_equal(0)

## Test polygon bounds caching functionality
func test_polygon_bounds_caching():
	var test_polygon = PackedVector2Array([Vector2(10, 5), Vector2(30, 5), Vector2(30, 25), Vector2(10, 25)])
	
	# First call should calculate and cache
	var bounds1 = collision_mapper._get_cached_polygon_bounds(test_polygon)
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(1)
	assert_vector(bounds1.position).is_equal(Vector2(10, 5))
	assert_vector(bounds1.size).is_equal(Vector2(20, 20))
	
	# Second call should return cached result
	var bounds2 = collision_mapper._get_cached_polygon_bounds(test_polygon)
	assert_vector(bounds2.position).is_equal(bounds1.position)
	assert_vector(bounds2.size).is_equal(bounds1.size)
	
	# Cache size should remain the same
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(1)

## Test tile polygon caching functionality
func test_tile_polygon_caching():
	var tile_pos = Vector2(64, 64)
	var tile_size = Vector2(16, 16)
	var tile_type = 0  # SQUARE
	
	# First call should calculate and cache
	var polygon1 = collision_mapper._get_cached_tile_polygon(tile_pos, tile_size, tile_type)
	assert_int(collision_mapper._tile_polygon_cache.size()).is_equal(1)
	assert_int(polygon1.size()).is_equal(4)  # Square has 4 vertices
	
	# Second call should return cached result
	var polygon2 = collision_mapper._get_cached_tile_polygon(tile_pos, tile_size, tile_type)
	assert_int(polygon2.size()).is_equal(4)
	
	# Cache size should remain the same
	assert_int(collision_mapper._tile_polygon_cache.size()).is_equal(1)
	
	# Different parameters should create new cache entry
	var _polygon3 = collision_mapper._get_cached_tile_polygon(Vector2(80, 80), tile_size, tile_type)
	assert_int(collision_mapper._tile_polygon_cache.size()).is_equal(2)

## Test generic geometry result caching
func test_generic_geometry_caching():
	var calculation_result = "test_result"
	var calculation_func = func():
		return calculation_result
	
	var cache_key = "test_calculation"
	
	# First call should execute calculation and cache
	var result1 = collision_mapper._get_cached_geometry_result(cache_key, calculation_func)
	assert_str(result1).is_equal("test_result")
	assert_int(collision_mapper._geometry_cache.size()).is_equal(1)
	
	# Change the expected result to test if cache is being used
	calculation_result = "different_result"
	var result2 = collision_mapper._get_cached_geometry_result(cache_key, calculation_func)
	
	# Should return cached result, not the new calculation result
	assert_str(result2).is_equal("test_result")
	assert_int(collision_mapper._geometry_cache.size()).is_equal(1)

## Test performance improvement with caching
func test_performance_improvement_with_caching():
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	test_indicator.shape = RectangleShape2D.new()
	test_indicator.shape.size = Vector2(32, 32)
	add_child(test_indicator)

	# Create collision polygon for testing
	var static_body = auto_free(StaticBody2D.new())
	add_child(static_body)
	static_body.collision_layer = 1

	var collision_polygon = CollisionPolygon2D.new()
	static_body.add_child(collision_polygon)
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])

	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	collision_object_test_setups[collision_polygon] = null
	collision_mapper.setup(test_indicator, collision_object_test_setups)

	# Measure performance with caching
	var iterations = 100
	var start_time = Time.get_ticks_usec()
	
	for i in range(iterations):
		var _result = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	
	var cached_time = Time.get_ticks_usec() - start_time
	
	# Clear cache and measure without caching (simulate no cache by clearing before each call)
	start_time = Time.get_ticks_usec()
	
	for i in range(iterations):
		collision_mapper._polygon_bounds_cache.clear()
		var _result = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	
	var uncached_time = Time.get_ticks_usec() - start_time
	
	print("Cached time: %.2f ms, Uncached time: %.2f ms" % [cached_time / 1000.0, uncached_time / 1000.0])
	
	# Cached version should be significantly faster (at least 10% improvement expected)
	assert_bool(cached_time < uncached_time * 0.9).is_true()

## Test cache behavior with different polygon shapes
func test_caching_with_different_shapes():
	var square_polygon = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
	var triangle_polygon = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(8, 16)])
	var complex_polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(8, 0), Vector2(16, 4), Vector2(16, 12), 
		Vector2(8, 16), Vector2(0, 16), Vector2(-4, 8)
	])
	
	# Cache bounds for different shapes
	var bounds1 = collision_mapper._get_cached_polygon_bounds(square_polygon)
	var bounds2 = collision_mapper._get_cached_polygon_bounds(triangle_polygon)
	var bounds3 = collision_mapper._get_cached_polygon_bounds(complex_polygon)
	
	# Should have 3 different cache entries
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(3)
	
	# Each should have correct bounds
	assert_vector(bounds1.size).is_equal(Vector2(16, 16))
	assert_vector(bounds2.size).is_equal(Vector2(16, 16))
	assert_vector(bounds3.size).is_equal(Vector2(20, 16))

## Test cache memory management doesn't grow unbounded
func test_cache_memory_management():
	# Generate many different polygons to test cache growth
	var initial_cache_size = collision_mapper._polygon_bounds_cache.size()
	
	for i in range(50):
		var test_polygon = PackedVector2Array([
			Vector2(i, i), Vector2(i + 16, i), Vector2(i + 16, i + 16), Vector2(i, i + 16)
		])
		collision_mapper._get_cached_polygon_bounds(test_polygon)
	
	# Cache should grow but not excessively
	var final_cache_size = collision_mapper._polygon_bounds_cache.size()
	assert_int(final_cache_size).is_greater(initial_cache_size)
	assert_int(final_cache_size).is_equal(50)  # Should have one entry per unique polygon

## Test that cache works correctly with concurrent access patterns
func test_cache_concurrent_access():
	var test_polygon = PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)])
	
	# Simulate multiple systems accessing the same cached data
	var results: Array[Rect2] = []
	
	for i in range(10):
		results.append(collision_mapper._get_cached_polygon_bounds(test_polygon))
	
	# All results should be identical
	var first_result = results[0]
	for result in results:
		assert_vector(result.position).is_equal(first_result.position)
		assert_vector(result.size).is_equal(first_result.size)
	
	# Should only have one cache entry despite multiple calls
	assert_int(collision_mapper._polygon_bounds_cache.size()).is_equal(1)
