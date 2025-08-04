extends GdUnitTestSuite

var mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var indicator: RuleCheckIndicator
var logger : GBLogger

func before_test():
	logger = GBDoubleFactory.create_test_logger()
	targeting_state = GridTargetingState.new(GBOwnerContext.new())
	mapper = CollisionMapper.new(targeting_state, logger)
	indicator = auto_free(RuleCheckIndicator.new())
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(32, 32)  # Updated from extents to size

	tile_map_layer = auto_free(TileMapLayer.new())
	add_child(tile_map_layer)
	tile_map_layer.tile_set = TileSet.new()
	targeting_state.target_map = tile_map_layer

	assert(indicator.shape != null, "Indicator shape must not be null before tests")

func rule(mask: int) -> TileCheckRule:
	var r := TileCheckRule.new()
	r.apply_to_objects_mask = mask
	return r

@warning_ignore("unused_parameter")
func test_map_collision_positions_to_rules_param(
	collision_objects_untyped: Array,
	rules_untyped: Array,
	expected_has_contents: bool,
	test_parameters := [
		[[], [], false],
		[[], [rule(1)], false],
		[[_create_area_2d(1)], [], false],
		[[_create_area_2d(1)], [rule(1)], true],
	]):
	var collision_objects: Array[Node2D] = []
	for obj in collision_objects_untyped:
		collision_objects.append(obj)
		add_child(obj)
		auto_free(obj)

	var rules: Array[TileCheckRule] = []
	for r in rules_untyped:
		rules.append(r)

	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for obj in collision_objects:
		collision_object_test_setups[obj] = IndicatorCollisionTestSetup.new(obj, indicator.position, logger)
	mapper.setup(indicator, collision_object_test_setups)

	var result = mapper.map_collision_positions_to_rules(collision_objects, rules)
	assert_that(result.size() > 0).is_equal(expected_has_contents)

func _create_area_2d(layer: int) -> Area2D:
	return _create_area_2d_custom_size(layer, 16, 16)

func _create_area_2d_custom_size(layer: int, width: int, height: int) -> Area2D:
	var area_2d : Area2D = auto_free(Area2D.new())
	area_2d.collision_layer = layer
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(width, height)  # Updated from extents to size
	shape.shape = rect_shape
	area_2d.add_child(shape)
	return area_2d

func test_map_collision_positions_to_rules_returns_expected_map() -> void:
	var test_object: Node2D = GBDoubleFactory.create_test_object_with_circle_shape(self)
	var test_rule := TileCheckRule.new()
	test_rule.apply_to_objects_mask = 1
	var rules : Array[TileCheckRule] = [test_rule]
	var test_targeting_state := GridTargetingState.new(GBOwnerContext.new())
	test_targeting_state.target_map = GBDoubleFactory.create_test_tile_map_layer(self)
	var test_collision_mapper := CollisionMapper.new(test_targeting_state, logger)
	var _owner_col_shapes_map : Dictionary[Node2D, Array] = GBGeometryUtils.get_all_collision_shapes_by_owner(test_object)
	var col_objects: Array[Node2D] = _owner_col_shapes_map.keys()
	assert_int(col_objects.size()).append_failure_message("Should find at least one collision object").is_greater(0)
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for col_obj in col_objects:
		collision_object_test_setups[col_obj] = IndicatorCollisionTestSetup.new(col_obj as CollisionObject2D, Vector2.ZERO, logger)
	var test_indicator: RuleCheckIndicator = GBDoubleFactory.create_test_indicator_rect(self, 16)
	test_collision_mapper.setup(test_indicator, collision_object_test_setups)
	var position_rules_map : Dictionary[Vector2i, Array] = test_collision_mapper.map_collision_positions_to_rules(col_objects, rules)
	assert_that(position_rules_map.size()).append_failure_message("Should map at least one tile position").is_greater(0)
	for key in position_rules_map.keys():
		assert_that(position_rules_map[key].size()).append_failure_message("Each mapped tile should have at least one rule").is_greater(0)

@warning_ignore("unused_parameter")
func test_get_collision_tile_positions_with_mask_param(
	collision_objects_untyped: Array,
	collision_mask: int,
	expected_tile_count: int,
	expected_object_counts: Array,
	test_parameters := [
		[[], 1, 0, []],
		[[_create_area_2d(1)], 1, 1, [1]],
		# Additional test: 15x15 rectangle should only overlap one tile
		[[_create_area_2d_custom_size(1, 15, 15)], 1, 1, [1]],
		[[_create_area_2d(2)], 1, 0, []],
		[[_create_area_2d(1), _create_area_2d(1)], 1, 1, [2]],
	]):
	var collision_objects: Array[Node2D] = []
	for obj in collision_objects_untyped:
		collision_objects.append(obj)
		add_child(obj)
		auto_free(obj)

	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for obj in collision_objects:
		collision_object_test_setups[obj] = IndicatorCollisionTestSetup.new(obj, indicator.position, logger)
	mapper.setup(indicator, collision_object_test_setups)

	var result = mapper.get_collision_tile_positions_with_mask(collision_objects, collision_mask)
	assert_int(result.size()).append_failure_message("Unexpected tile count").is_equal(expected_tile_count)
	var keys := result.keys()
	if keys.size() != expected_object_counts.size():
		assert_int(keys.size()).append_failure_message("Tile count mismatch: expected %d, got %d" % [expected_object_counts.size(), keys.size()]).is_equal(expected_object_counts.size())
		return
	for i in range(keys.size()):
		assert_int(result[keys[i]].size()).append_failure_message("Unexpected object count for tile").is_equal(expected_object_counts[i])

## Test CollisionPolygon2D overlap detection using geometry math
func test_get_tile_offsets_for_collision_polygon() -> void:
	# Create an Area2D parent for the CollisionPolygon2D
	var area_2d: Area2D = auto_free(Area2D.new())
	add_child(area_2d)
	area_2d.collision_layer = 1
	
	var polygon_node: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	area_2d.add_child(polygon_node)
	
	# Create a simple square polygon that should overlap multiple tiles
	polygon_node.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)
	])
	
	var test_setup = IndicatorCollisionTestSetup.new(area_2d, Vector2.ZERO, logger)
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {
		area_2d: test_setup
	}
	mapper.setup(indicator, collision_object_test_setups)
	
	var result = mapper.get_tile_offsets_for_test_collisions(test_setup)
	assert_int(result.size()).append_failure_message("Should find overlapped tiles for polygon").is_greater(0)

## Test CollisionObject2D with RectangleShape2D overlap detection
func test_get_tile_offsets_for_collision_object_rectangle() -> void:
	var area_2d: Area2D = _create_area_2d_custom_size(1, 32, 32)
	add_child(area_2d)
	
	var test_setup = IndicatorCollisionTestSetup.new(area_2d, Vector2.ZERO, logger)
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {
		area_2d: test_setup
	}
	mapper.setup(indicator, collision_object_test_setups)
	
	var result = mapper.get_tile_offsets_for_test_collisions(test_setup)
	assert_int(result.size()).append_failure_message("Should find overlapped tiles for rectangle shape").is_greater(0)

## Test GBGeometryMath.get_polygon_bounds function
func test_geometry_math_get_polygon_bounds() -> void:
	var polygon = PackedVector2Array([
		Vector2(10, 5), Vector2(30, 5), Vector2(30, 25), Vector2(10, 25)
	])
	
	var bounds = GBGeometryMath.get_polygon_bounds(polygon)
	assert_vector(bounds.position).is_equal(Vector2(10, 5))
	assert_vector(bounds.size).is_equal(Vector2(20, 20))
	
	# Test empty polygon
	var empty_bounds = GBGeometryMath.get_polygon_bounds(PackedVector2Array())
	assert_vector(empty_bounds.position).is_equal(Vector2.ZERO)
	assert_vector(empty_bounds.size).is_equal(Vector2.ZERO)

## Test GBGeometryMath.convert_shape_to_polygon function
func test_geometry_math_convert_shape_to_polygon() -> void:
	# Test RectangleShape2D conversion
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 16)
	var transform = Transform2D.IDENTITY
	
	var polygon = GBGeometryMath.convert_shape_to_polygon(rect_shape, transform)
	assert_int(polygon.size()).is_equal(4)  # Rectangle should have 4 vertices
	
	# Test CircleShape2D conversion
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 16.0
	
	var circle_polygon = GBGeometryMath.convert_shape_to_polygon(circle_shape, transform)
	assert_int(circle_polygon.size()).is_equal(16)  # Circle approximated with 16 segments

## Test precise area-based overlap detection with different tile sizes
func test_collision_detection_with_different_tile_sizes() -> void:
	# Create a 15x15 rectangle that should only overlap one 16x16 tile
	var small_area: Area2D = _create_area_2d_custom_size(1, 15, 15)
	add_child(small_area)
	
	# Set tile map to use 16x16 tiles
	tile_map_layer.tile_set.tile_size = Vector2i(16, 16)
	
	var collision_objects: Array[Node2D] = [small_area]
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for obj in collision_objects:
		collision_object_test_setups[obj] = IndicatorCollisionTestSetup.new(obj as CollisionObject2D, Vector2.ZERO, logger)
	mapper.setup(indicator, collision_object_test_setups)
	
	var result = mapper.get_collision_tile_positions_with_mask(collision_objects, 1)
	assert_int(result.size()).append_failure_message("15x15 shape should only overlap one 16x16 tile").is_equal(1)

## Test that different collision layers are properly filtered
func test_collision_layer_filtering() -> void:
	var layer1_area: Area2D = _create_area_2d(1)  # Layer 1
	var layer2_area: Area2D = _create_area_2d(2)  # Layer 2
	add_child(layer1_area)
	add_child(layer2_area)
	
	var collision_objects: Array[Node2D] = [layer1_area, layer2_area]
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for obj in collision_objects:
		collision_object_test_setups[obj] = IndicatorCollisionTestSetup.new(obj as CollisionObject2D, Vector2.ZERO, logger)
	mapper.setup(indicator, collision_object_test_setups)
	
	# Test filtering by layer 1 only
	var layer1_result = mapper.get_collision_tile_positions_with_mask(collision_objects, 1)
	var layer2_result = mapper.get_collision_tile_positions_with_mask(collision_objects, 2)
	
	# Should find layer 1 object but not layer 2
	assert_int(layer1_result.size()).append_failure_message("Should find layer 1 collision").is_greater(0)
	assert_int(layer2_result.size()).append_failure_message("Should find layer 2 collision").is_greater(0)
