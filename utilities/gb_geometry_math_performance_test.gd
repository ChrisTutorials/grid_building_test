extends GdUnitTestSuite

var iterations := 1000
var tile_map: TileMapLayer

func before_test():
	tile_map = auto_free(TileMapLayer.new())
	add_child(tile_map)
	tile_map.tile_set = TileSet.new()
	tile_map.tile_set.tile_size = Vector2i(16, 16)

## Benchmark small collision shape (2x2 tiles)
func test_benchmark_small_shape():
	var small_rect = PackedVector2Array([
		Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)
	])
	
	var start_time = Time.get_ticks_usec()
	
	for i in range(iterations):
		var tile_pos = Vector2(i % 100 * 16, (i / 100) * 16)
		GBGeometryMath.does_polygon_overlap_tile(small_rect, tile_pos, Vector2(16, 16), 0, 0.01)
	
	var end_time = Time.get_ticks_usec()
	var avg_time_ms = (end_time - start_time) / 1000.0 / iterations
	
	print("Small shape (2x2 tiles) average time: %.3f ms" % avg_time_ms)
	assert_float(avg_time_ms).is_less(1.0)  # Should be under 1ms

## Benchmark medium collision shape (4x4 tiles)  
func test_benchmark_medium_shape():
	var medium_rect = PackedVector2Array([
		Vector2(0, 0), Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)
	])
	
	var start_time = Time.get_ticks_usec()
	
	for i in range(iterations):
		var tile_pos = Vector2(i % 50 * 16, (i / 50) * 16)
		GBGeometryMath.does_polygon_overlap_tile(medium_rect, tile_pos, Vector2(16, 16), 0, 0.01)
	
	var end_time = Time.get_ticks_usec()
	var avg_time_ms = (end_time - start_time) / 1000.0 / iterations
	
	print("Medium shape (4x4 tiles) average time: %.3f ms" % avg_time_ms)
	assert_float(avg_time_ms).is_less(2.0)  # Should be under 2ms

## Benchmark complex polygon (circle approximation)
func test_benchmark_complex_polygon():
	var circle_poly = PackedVector2Array()
	var center = Vector2(32, 32)
	var radius = 24.0
	for i in range(16):  # 16-sided polygon
		var angle = i * PI * 2.0 / 16
		circle_poly.append(center + Vector2(cos(angle), sin(angle)) * radius)
	
	var start_time = Time.get_ticks_usec()
	
	for i in range(iterations):
		var tile_pos = Vector2(i % 50 * 16, (i / 50) * 16)
		GBGeometryMath.does_polygon_overlap_tile(circle_poly, tile_pos, Vector2(16, 16), 0, 0.01)
	
	var end_time = Time.get_ticks_usec()
	var avg_time_ms = (end_time - start_time) / 1000.0 / iterations
	
	print("Complex polygon (16 vertices) average time: %.3f ms" % avg_time_ms)
	assert_float(avg_time_ms).is_less(3.0)  # Should be under 3ms

## Benchmark full collision mapping workflow
func test_benchmark_collision_mapping_workflow():
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
	for i in range(3):  # 3 objects like in your use case
		var area = auto_free(Area2D.new())
		add_child(area)
		area.collision_layer = 1
		
		var shape = auto_free(CollisionShape2D.new())
		var rect_shape = GodotTestFactory.create_rectangle_shape(Vector2(32,32))
		shape.shape = rect_shape
		area.add_child(shape)
		test_objects.append(area)
	
	# Setup collision mapper
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for obj in test_objects:
		collision_object_test_setups[obj] = IndicatorCollisionTestSetup.new(obj, Vector2.ZERO, logger)
	
	var indicator = auto_free(RuleCheckIndicator.new())
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(32, 32)
	mapper.setup(indicator, collision_object_test_setups)
	
	var start_time = Time.get_ticks_usec()
	
	for i in range(100):  # 100 collision checks (more realistic)
		var result = mapper.get_collision_tile_positions_with_mask(test_objects, 1)
	
	var end_time = Time.get_ticks_usec()
	var avg_time_ms = (end_time - start_time) / 1000.0 / 100
	
	print("Full collision mapping (3 objects) average time: %.3f ms" % avg_time_ms)
	assert_float(avg_time_ms).is_less(15.0)  # Should be under 15ms for gameplay

## Compare polygon conversion vs native collision detection
func test_benchmark_native_vs_polygon_collision():
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	var tile_shape = RectangleShape2D.new()
	tile_shape.size = Vector2(16, 16)
	
	var rect_transform = Transform2D(0, Vector2(32, 32))
	var iterations_native = 10000
	
	# Test 1: Native collision detection
	var start_time = Time.get_ticks_usec()
	for i in range(iterations_native):
		var tile_pos = Vector2(i % 100 * 16, (i / 100) * 16)
		var tile_transform = Transform2D(0, tile_pos)
		rect_shape.collide(rect_transform, tile_shape, tile_transform)
	var native_time = Time.get_ticks_usec() - start_time
	
	# Test 2: Your polygon approach
	var rect_polygon = GBGeometryMath.convert_shape_to_polygon(rect_shape, rect_transform)
	start_time = Time.get_ticks_usec()
	for i in range(iterations_native):
		var tile_pos = Vector2(i % 100 * 16, (i / 100) * 16)
		GBGeometryMath.does_polygon_overlap_tile(rect_polygon, tile_pos, Vector2(16, 16), 0, 0.01)
	var polygon_time = Time.get_ticks_usec() - start_time
	
	var native_avg = native_time / 1000.0 / iterations_native
	var polygon_avg = polygon_time / 1000.0 / iterations_native
	
	print("Native collision: %.4f ms, Polygon approach: %.4f ms" % [native_avg, polygon_avg])
	print("Polygon approach is %.1fx slower" % (polygon_avg / native_avg))

## Benchmark optimized collision detection approach
func test_benchmark_optimized_collision():
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	var rect_transform = Transform2D(0, Vector2(32, 32))
	var iterations_optimized = 10000
	
	var start_time = Time.get_ticks_usec()
	for i in range(iterations_optimized):
		var tile_pos = Vector2(i % 100 * 16, (i / 100) * 16)
		GBGeometryMath.does_shape_overlap_tile_optimized(rect_shape, rect_transform, tile_pos, Vector2(16, 16))
	var optimized_time = Time.get_ticks_usec() - start_time
	
	var optimized_avg = optimized_time / 1000.0 / iterations_optimized
	print("Optimized collision detection: %.4f ms" % optimized_avg)
	assert_float(optimized_avg).is_less(0.003)  # Should be very fast

## Benchmark full optimized collision mapping workflow
func test_benchmark_optimized_collision_mapping_workflow():
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
	for i in range(3):  # 3 objects like in your use case
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
	
	var indicator = auto_free(RuleCheckIndicator.new())
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(32, 32)
	mapper.setup(indicator, collision_object_test_setups)
	
	var start_time = Time.get_ticks_usec()
	
	for i in range(1000):  # More iterations to test optimized version
		var result = mapper.get_collision_tile_positions_with_mask(test_objects, 1)
	
	var end_time = Time.get_ticks_usec()
	var avg_time_ms = (end_time - start_time) / 1000.0 / 1000
	
	print("Optimized full collision mapping (3 objects) average time: %.4f ms" % avg_time_ms)
	assert_float(avg_time_ms).is_less(1.0)  # Should be much faster now
