@tool
extends GdUnitTestSuite

var mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var indicator: RuleCheckIndicator

func before_test():
	targeting_state = GridTargetingState.new(GBOwnerContext.new())
	mapper = CollisionMapper.new(targeting_state)
	indicator = auto_free(RuleCheckIndicator.new())
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.extents = Vector2(16, 16)  # Set a default size for the indicator shape

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
func test_map_tile_positions_to_rules(
	collision_objects_untyped: Array,
	rules_untyped: Array,
	expected: Dictionary,
	test_parameters := [
		[[], [], {}],
		[[], [rule(1)], {}],
		[[_create_area_2d(1)], [], {}],
		[[_create_area_2d(1)], [rule(1)], {}],
	]): 

	var collision_objects: Array[CollisionObject2D] = []
	for obj in collision_objects_untyped:
		collision_objects.append(obj)
		add_child(obj)
		auto_free(obj)


	var rules: Array[TileCheckRule] = []
	for r in rules_untyped:
		rules.append(r)

	var result = mapper.map_tile_positions_to_rules(collision_objects, rules)
	assert_that(result).is_equal(expected)

func _create_area_2d(layer: int) -> Area2D:
	var area_2d : Area2D = auto_free(Area2D.new())
	area_2d.collision_layer = layer
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	area_2d.add_child(shape)
	return area_2d

func test_map_collision_positions_to_rules_returns_expected_map() -> void:
	# Setup: create a StaticBody2D with a CollisionShape2D
	var test_object := Node2D.new()
	var body := StaticBody2D.new()
	test_object.add_child(body)
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	body.add_child(collision_shape)

	# Create a dummy targeting state and collision mapper
	var test_targeting_state := GridTargetingState.new(GBOwnerContext.new())
	var test_collision_mapper := CollisionMapper.new(test_targeting_state)

	# Create a rule
	var test_rule := TileCheckRule.new()
	var rules : Array[TileCheckRule] = [test_rule]

	# Get collision objects
	var col_objects := GBGeometryUtils.get_all_collision_objects(test_object)
	assert_int(col_objects.size()).is_greater(0)

	# Call the mapping function
	var position_rules_map : Dictionary[Vector2i, Array] = test_collision_mapper.map_collision_positions_to_rules(col_objects, rules)

	# Assert the map is not empty and contains expected keys/values
	assert_that(position_rules_map.size()).is_greater(0)
	for key in position_rules_map.keys():
		assert_that(position_rules_map[key].size()).is_greater(0)
