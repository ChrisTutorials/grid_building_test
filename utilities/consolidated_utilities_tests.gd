extends GdUnitTestSuite

## Consolidated utilities tests combining geometry, collision, string, and search utilities
## Demonstrates layered factory pattern usage with shared environment setup

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_env: Dictionary

func before_test() -> void:
	test_env = UnifiedTestFactory.create_utilities_test_environment(self, TEST_CONTAINER)

func after_test() -> void:
	test_env.clear()

# ================================
# GEOMETRY MATHEMATICS TESTS
# ================================

@warning_ignore("unused_parameter")
func test_geometry_math_polygon_intersection() -> void:
	var poly_a: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var poly_b: PackedVector2Array = PackedVector2Array([Vector2(5, 5), Vector2(15, 5), Vector2(15, 15), Vector2(5, 15)])
	
	var intersection_area = GBGeometryMath.polygon_intersection_area(poly_a, poly_b)
	assert_that(intersection_area).is_equal(25.0)  # 5x5 intersection

@warning_ignore("unused_parameter") 
func test_geometry_math_tile_operations() -> void:
	var tile_pos: Vector2 = Vector2(0, 0)
	var tile_size: Vector2 = Vector2(16, 16)
	var tile_polygon = GBGeometryMath.get_tile_polygon(tile_pos, tile_size, TileSet.TILE_SHAPE_SQUARE)
	
	assert_that(tile_polygon.size()).is_equal(4)
	assert_that(tile_polygon[0]).is_equal(Vector2(0, 0))

@warning_ignore("unused_parameter")
func test_geometry_math_polygon_overlap() -> void:
	var polygon: PackedVector2Array = PackedVector2Array([Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)])
	var tile_pos: Vector2 = Vector2(0, 0) 
	var tile_size: Vector2 = Vector2(16, 16)
	
	var overlaps = GBGeometryMath.does_polygon_overlap_tile(polygon, tile_pos, tile_size, TileSet.TILE_SHAPE_SQUARE, 0.01)
	assert_that(overlaps).is_true()

# ================================
# GEOMETRY UTILITIES TESTS  
# ================================

@warning_ignore("unused_parameter")
func test_geometry_utils_collision_shapes() -> void:
	# Test the actual static methods available in GBGeometryUtils
	var test_obj = Node2D.new()
	auto_free(test_obj)
	add_child(test_obj)
	
	var static_body = StaticBody2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	collision_shape.shape = rect_shape
	static_body.add_child(collision_shape)
	test_obj.add_child(static_body)
	
	var shapes_by_owner = GBGeometryUtils.get_all_collision_shapes_by_owner(test_obj)
	assert_that(shapes_by_owner.size()).is_greater(0)

# ================================
# COLLISION GEOMETRY TESTS
# ================================

@warning_ignore("unused_parameter")
func test_collision_geometry_utils_transform_building() -> void:
	var test_obj = Node2D.new()
	auto_free(test_obj)
	add_child(test_obj)
	
	var static_body = StaticBody2D.new()
	static_body.position = Vector2(10, 10)
	test_obj.add_child(static_body)
	
	var transform = CollisionGeometryUtils.build_shape_transform(static_body, test_obj)
	assert_that(transform.origin).is_equal(Vector2(10, 10))

@warning_ignore("unused_parameter") 
func test_collision_geometry_polygon_operations() -> void:
	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	auto_free(collision_polygon)
	add_child(collision_polygon)
	
	var world_polygon = CollisionGeometryUtils.to_world_polygon(collision_polygon)
	assert_that(world_polygon.size()).is_equal(4)

@warning_ignore("unused_parameter")
func test_collision_geometry_convex_check() -> void:
	var convex_polygon: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var concave_polygon: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 5), Vector2(10, 10), Vector2(0, 10)])
	
	assert_that(CollisionGeometryUtils.is_polygon_convex(convex_polygon)).is_true()
	assert_that(CollisionGeometryUtils.is_polygon_convex(concave_polygon)).is_false()

# ================================
# STRING UTILITIES TESTS
# ================================

@warning_ignore("unused_parameter")
func test_string_utilities_name_conversion() -> void:
	# Test actual GBString methods
	var readable_name = GBString.convert_name_to_readable("test_node_name")
	assert_that(readable_name).is_not_equal("test_node_name")  # Should be converted

@warning_ignore("unused_parameter")
func test_string_utilities_separator_matching() -> void:
	# Test separator matching functionality
	assert_that(GBString.match_num_seperator("_", 0)).is_true()
	assert_that(GBString.match_num_seperator("-", 1)).is_true()

# ================================
# SEARCH UTILITIES TESTS
# ================================

@warning_ignore("unused_parameter")
func test_search_utils_find_first() -> void:
	var parent = Node2D.new()
	auto_free(parent)
	add_child(parent)
	
	var static_body = StaticBody2D.new()
	static_body.name = "TestStaticBody"
	parent.add_child(static_body)
	
	# Test actual GBSearchUtils methods
	var found = GBSearchUtils.find_first(parent, StaticBody2D)
	assert_that(found).is_not_null()
	assert_that(found).is_same(static_body)

@warning_ignore("unused_parameter")
func test_search_utils_collision_objects() -> void:
	var parent = Node2D.new()
	auto_free(parent)
	add_child(parent)
	
	var static_body = StaticBody2D.new()
	var area = Area2D.new()
	parent.add_child(static_body)
	parent.add_child(area)
	
	# Test actual GBSearchUtils methods
	var collision_objects = GBSearchUtils.get_collision_object_2ds(parent)
	assert_that(collision_objects.size()).is_equal(2)

# ================================
# INTEGRATION TESTS - Environment Usage
# ================================

@warning_ignore("unused_parameter")
func test_utilities_environment_integration() -> void:
	# Test that shared environment components work together
	assert_that(test_env.injector).is_not_null()
	assert_that(test_env.logger).is_not_null()
	assert_that(test_env.tile_map).is_not_null()
	assert_that(test_env.container).is_equal(TEST_CONTAINER)

@warning_ignore("unused_parameter") 
func test_geometry_collision_integration() -> void:
	# Test geometry and collision utilities working together
	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 20), Vector2(0, 20)])
	auto_free(collision_polygon)
	add_child(collision_polygon)
	
	var world_polygon = CollisionGeometryUtils.to_world_polygon(collision_polygon)
	
	# Use GBGeometryMath for area calculation
	var tile_pos: Vector2 = Vector2(0, 0)
	var tile_size: Vector2 = Vector2(20, 20)
	var intersection_area = GBGeometryMath.intersection_area_with_tile(world_polygon, tile_pos, tile_size, TileSet.TILE_SHAPE_SQUARE)
	
	assert_that(intersection_area).is_equal(400.0)  # Full overlap

@warning_ignore("unused_parameter")
func test_performance_utilities_combined() -> void:
	# Lightweight performance test combining multiple utilities
	var start_time = Time.get_ticks_usec()
	
	for i in range(100):
		var tile_pos: Vector2 = Vector2(i, i)
		var tile_size: Vector2 = Vector2(10, 10)
		var polygon = GBGeometryMath.get_tile_polygon(tile_pos, tile_size, TileSet.TILE_SHAPE_SQUARE)
		
		# Test collision geometry utilities
		var is_convex = CollisionGeometryUtils.is_polygon_convex(polygon)
		assert_that(polygon.size()).is_equal(4)
		assert_that(is_convex).is_true()  # Square polygons are convex
	
	var elapsed = Time.get_ticks_usec() - start_time
	test_env.logger.log_info("Combined utilities performance test completed in " + str(elapsed) + " microseconds")
	assert_that(elapsed).is_less(100000)  # Should complete in under 0.1 seconds
