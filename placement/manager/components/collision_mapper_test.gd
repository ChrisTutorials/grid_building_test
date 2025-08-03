
extends GdUnitTestSuite

const GBDoubleFactory = preload("res://test/grid_building_test/doubles/gb_double_factory.gd")

var mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var indicator: RuleCheckIndicator
var logger : GBLogger

func before_test():
	logger = GBDoubleFactory.create_test_logger()
	targeting_state = GridTargetingState.new(GBOwnerContext.new())
	mapper = CollisionMapper.new(targeting_state)
	indicator = auto_free(RuleCheckIndicator.new())
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.extents = Vector2(16, 16)

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
	var collision_objects: Array[CollisionObject2D] = []
	for obj in collision_objects_untyped:
		collision_objects.append(obj)
		add_child(obj)
		auto_free(obj)

	var rules: Array[TileCheckRule] = []
	for r in rules_untyped:
		rules.append(r)

	var collision_object_test_setups: Dictionary[CollisionObject2D, IndicatorCollisionTestSetup] = {}
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
	rect_shape.extents = Vector2(width / 2.0, height / 2.0)
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
	var test_collision_mapper := CollisionMapper.new(test_targeting_state)
	var owner_col_shapes_map : Dictionary[Node2D, Array] = GBGeometryUtils.get_all_collision_objects(test_object)
	assert_int(col_objects.size()).append_failure_message("Should find at least one collision object").is_greater(0)
	var collision_object_test_setups: Dictionary[CollisionObject2D, IndicatorCollisionTestSetup] = GBDoubleFactory.create_collision_object_test_setups(col_objects)
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
	]
):
	var collision_objects: Array[CollisionObject2D] = []
	for obj in collision_objects_untyped:
		collision_objects.append(obj)
		add_child(obj)
		auto_free(obj)

	var collision_object_test_setups: Dictionary[CollisionObject2D, IndicatorCollisionTestSetup] = {}
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
