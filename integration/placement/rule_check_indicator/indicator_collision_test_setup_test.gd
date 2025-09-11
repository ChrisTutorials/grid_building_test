# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

const TILE_SIZE = Vector2TILE_SIZE

var eclipse_obj
var rect_8_tiles_obj
var test_skew_rotation_rect_obj
var pillar_obj
var tile_map_16px : TileMap

func before_test():
	tile_map_16px = auto_free(TileMap.new())
	add_child(tile_map_16px)
	tile_map_16px.tile_set = TileSet.new()
	tile_map_16px.tile_set.tile_size = Vector2tile_size
	
	eclipse_obj = UnifiedTestFactory.create_eclipse_test_object(self)
	add_child(eclipse_obj)
	
	# Create simple rectangular objects for the other test cases
	rect_8_tiles_obj = auto_free(Node2D.new())
	rect_8_tiles_obj.name = "RectTestObject"
	var static_body := StaticBody2D.new()
	static_body.collision_layer = 1
	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2size  # 8x8 tiles at 16px each
	collision_shape.shape = rect_shape
	static_body.add_child(collision_shape)
	rect_8_tiles_obj.add_child(static_body)
	add_child(rect_8_tiles_obj)

	test_skew_rotation_rect_obj = auto_free(Node2D.new())
	test_skew_rotation_rect_obj.name = "SkewRotationTestObject"
	var skew_static_body := StaticBody2D.new()
	skew_static_body.collision_layer = 1
	var skew_collision_shape := CollisionShape2D.new()
	var skew_rect_shape := RectangleShape2D.new()
	skew_rect_shape.size = Vector2size
	skew_collision_shape.shape = skew_rect_shape
	skew_static_body.add_child(skew_collision_shape)
	test_skew_rotation_rect_obj.add_child(skew_static_body)
	add_child(test_skew_rotation_rect_obj)
	
	pillar_obj = auto_free(load("uid://enlg28ry7lxk").instantiate())
	add_child(pillar_obj)
	
	create_test_setups(eclipse_obj)
	create_test_setups(rect_8_tiles_obj)
	create_test_setups(test_skew_rotation_rect_obj)
	create_test_setups(pillar_obj)

## Tests to make sure that calling adjust_rect_to_testing_size
## returns rects with the correct size 
## Expected adjusted size to be original rect + TileSize * 1
@warning_ignore("unused_parameter")
func test_adjust_rect_to_testing_size(p_setups : Array[IndicatorCollisionTestSetup], test_parameters := [
	[create_test_setups(eclipse_obj)],
	[create_test_setups(rect_8_tiles_obj)],
	[create_test_setups(test_skew_rotation_rect_obj)],
	[create_test_setups(pillar_obj)]
]):
	for setup in p_setups:
		var rect_tests : Array[RectCollisionTestingSetup] = setup.rect_collision_test_setups

		for rect_test in rect_tests:
			rect: Node = rect_test.rect_shape.get_rect()
			var result_rect : Rect2 = setup._adjust_rect_to_testing_size(rect, setup.collision_object.global_transform)
			var result_rect_size = result_rect.size
			var minimum_expected_size = rect.size + TILE_SIZE * 1
			assert_vector(result_rect_size).is_not_equal(rect.size)
			assert_float(result_rect_size.x).is_greater_equal(minimum_expected_size.x)
			assert_float(result_rect.size.y).is_greater_equal(minimum_expected_size.y)
	

func create_test_setups(p_container : Node) -> Array[IndicatorCollisionTestSetup]:
	var test_setups : Array[IndicatorCollisionTestSetup] = []
	
	if(p_container is CollisionObject2D):
		test_setups.append(IndicatorCollisionTestSetup.new(p_container, Vector2(16,16)))
	
	for collision_object in p_container.find_children("", "CollisionObject2D"):
		test_setups.append(IndicatorCollisionTestSetup.new(collision_object, Vector2(16,16)))

	return test_setups
