extends GdUnitTestSuite

var tile_map: TileMapLayer

func before_test():
	tile_map = auto_free(TileMapLayer.new())
	add_child(tile_map)
	tile_map.tile_set = TileSet.new()
	tile_map.tile_set.tile_size = Vector2i(16, 16)

# Test different shape collision benchmarks with parameterized data
@warning_ignore("unused_parameter")
func test_benchmark_shape_collision_performance(shape_name: String, polygon: PackedVector2Array, iterations: int, max_time_ms: float, description: String, test_parameters := [
	# [shape_name, polygon_data, iterations, max_time_ms, description]
	["small_2x2", PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)]), 1000, 1.0, "Small shape (2x2 tiles)"],
	["medium_4x4", PackedVector2Array([Vector2(0, 0), Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)]), 1000, 2.0, "Medium shape (4x4 tiles)"],
	["complex_circle", PackedVector2Array(), 1000, 3.0, "Complex polygon (16 vertices)"] # Will create circle in function
]):
	# Handle special case for circle polygon creation
	var actual_polygon = polygon
	if shape_name == "complex_circle" or polygon.is_empty():
		actual_polygon = _create_circle_polygon(Vector2(32, 32), 24.0, 16)
	
	var start_time = Time.get_ticks_usec()
	
	for i in range(iterations):
		var tile_pos = Vector2i(i % 100 * 16, floori(i / 100.0) * 16)
		GBGeometryMath.does_polygon_overlap_tile(actual_polygon, tile_pos, Vector2(16, 16), 0, 0.01)
	
	var end_time = Time.get_ticks_usec()
	var avg_time_ms = (end_time - start_time) / 1000.0 / iterations
	
	print("%s average time: %.3f ms" % [description, avg_time_ms])
	assert_float(avg_time_ms).is_less(max_time_ms)

# Compare different collision detection approaches
@warning_ignore("unused_parameter")
func test_benchmark_collision_approaches(approach_name: String, use_optimized: bool, iterations: int, max_time_ms: float, test_parameters := [
	# [approach_name, use_optimized, iterations, max_time_ms]
	["polygon_approach", false, 10000, 0.1],
	["optimized_approach", true, 10000, 0.003]
]):
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	var rect_transform = Transform2D(0, Vector2(32, 32))
	
	var start_time = Time.get_ticks_usec()
	
	if use_optimized:
		for i in range(iterations):
			var tile_pos = Vector2(i % 100 * 16, floori(i / 100.0) * 16)
			GBGeometryMath.does_shape_overlap_tile_optimized(rect_shape, rect_transform, tile_pos, Vector2(16, 16))
	else:
		var rect_polygon = GBGeometryMath.convert_shape_to_polygon(rect_shape, rect_transform)
		for i in range(iterations):
			var tile_pos = Vector2(i % 100 * 16, floori(i / 100.0) * 16)
			GBGeometryMath.does_polygon_overlap_tile(rect_polygon, tile_pos, Vector2(16, 16), 0, 0.01)
	
	var end_time = Time.get_ticks_usec()
	var avg_time_ms = (end_time - start_time) / 1000.0 / iterations
	
	print("%s: %.4f ms" % [approach_name, avg_time_ms])
	assert_float(avg_time_ms).is_less(max_time_ms)

# Benchmark complete collision mapping workflows
@warning_ignore("unused_parameter")
func test_benchmark_collision_mapping_workflows(workflow_name: String, object_count: int, iterations: int, max_time_ms: float, description: String, test_parameters := [
	# [workflow_name, object_count, iterations, max_time_ms, description]
	["standard_workflow", 3, 100, 15.0, "Full collision mapping (3 objects)"],
	["optimized_workflow", 3, 1000, 1.0, "Optimized full collision mapping (3 objects)"]
]):
	var logger = GBLogger.new(GBDebugSettings.new())
	var targeting_state = GridTargetingState.new(GBOwnerContext.new())
	targeting_state.target_map = tile_map
	
	# Create and set up the positioner node that CollisionMapper expects
	var positioner: Node2D = GodotTestFactory.create_node2d(self)
	positioner.global_position = Vector2.ZERO
	targeting_state.positioner = positioner
	
	var mapper = CollisionMapper.new(targeting_state, logger)
	
	# Create test objects
	var test_objects: Array[Node2D] = []
	for i in range(object_count):
		var area = auto_free(Area2D.new())
		add_child(area)
		area.collision_layer = 1
		
		var shape = auto_free(CollisionShape2D.new())
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(32, 32)
		shape.shape = rect_shape
		area.add_child(shape)
		test_objects.append(area)
	
	# Setup collision mapper
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for obj in test_objects:
		collision_object_test_setups[obj] = IndicatorCollisionTestSetup.new(obj, Vector2.ZERO, logger)
	
	var indicator = auto_free(UnifiedTestFactory.create_test_rule_check_indicator(self))
	if indicator.get_parent() == null:
		add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(32, 32)
	mapper.setup(indicator, collision_object_test_setups)
	
	var start_time = Time.get_ticks_usec()
	
	for i in range(iterations):
		var _result = mapper.get_collision_tile_positions_with_mask(test_objects, 1)
	
	var end_time = Time.get_ticks_usec()
	var avg_time_ms = (end_time - start_time) / 1000.0 / iterations
	
	print("%s average time: %.4f ms" % [description, avg_time_ms])
	assert_float(avg_time_ms).is_less(max_time_ms)

# Comprehensive comparison of native vs polygon collision detection
func test_native_vs_polygon_collision_comparison():
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	var tile_shape = RectangleShape2D.new()
	tile_shape.size = Vector2(16, 16)
	
	var rect_transform = Transform2D(0, Vector2(32, 32))
	var iterations_test = 10000
	
	# Test 1: Native collision detection
	var start_time = Time.get_ticks_usec()
	for i in range(iterations_test):
		var tile_pos = Vector2(i % 100 * 16, floori(i / 100.0) * 16)
		var tile_transform = Transform2D(0, tile_pos)
		rect_shape.collide(rect_transform, tile_shape, tile_transform)
	var native_time = Time.get_ticks_usec() - start_time
	
	# Test 2: Polygon approach
	var rect_polygon = GBGeometryMath.convert_shape_to_polygon(rect_shape, rect_transform)
	start_time = Time.get_ticks_usec()
	for i in range(iterations_test):
		var tile_pos = Vector2(i % 100 * 16, floori(i / 100.0) * 16)
		GBGeometryMath.does_polygon_overlap_tile(rect_polygon, tile_pos, Vector2(16, 16), 0, 0.01)
	var polygon_time = Time.get_ticks_usec() - start_time
	
	var native_avg = native_time / 1000.0 / iterations_test
	var polygon_avg = polygon_time / 1000.0 / iterations_test
	var performance_ratio = polygon_avg / native_avg
	
	print("Native collision: %.4f ms, Polygon approach: %.4f ms" % [native_avg, polygon_avg])
	print("Polygon approach is %.1fx slower" % performance_ratio)
	
	# Basic performance validations
	assert_float(native_avg).is_less(0.01)  # Native should be very fast
	assert_float(polygon_avg).is_less(0.1)  # Polygon should be reasonable
	assert_float(performance_ratio).is_less(50.0)  # Polygon shouldn't be more than 50x slower

# Helper function to create circle polygon
func _create_circle_polygon(center: Vector2, radius: float, vertices: int) -> PackedVector2Array:
	var circle_poly = PackedVector2Array()
	for i in range(vertices):
		var angle = i * PI * 2.0 / vertices
		circle_poly.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return circle_poly
