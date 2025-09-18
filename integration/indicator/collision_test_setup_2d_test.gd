# GdUnit generated TestSuite
# TestSuite for CollisionTestSetup2D class functionality
# Tests the _adjust_rect_to_testing_size method to ensure collision rectangles
# are properly adjusted for testing scenarios with expected size increases
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

const TILE_SIZE: Vector2 = Vector2(16, 16)

var eclipse_obj: Node2D
var rect_8_tiles_obj: Node2D
var test_skew_rotation_rect_obj: Node2D
var pillar_obj: Node2D
var tile_map_16px: TileMap

func before_test() -> void:
	tile_map_16px = auto_free(TileMap.new())
	add_child(tile_map_16px)
	tile_map_16px.tile_set = TileSet.new()
	tile_map_16px.tile_set.tile_size = TILE_SIZE
	
	eclipse_obj = UnifiedTestFactory.create_eclipse_test_object(self)
	add_child(eclipse_obj)
	
	# Create simple rectangular objects for the other test cases
	rect_8_tiles_obj = _create_rectangular_collision_object("RectTestObject", Vector2(128, 128))
	add_child(rect_8_tiles_obj)

	test_skew_rotation_rect_obj = _create_rectangular_collision_object("SkewRotationTestObject", Vector2(128, 128))
	add_child(test_skew_rotation_rect_obj)
	
	pillar_obj = auto_free(load("uid://enlg28ry7lxk").instantiate())
	add_child(pillar_obj)
	
	create_test_setups(eclipse_obj)
	create_test_setups(rect_8_tiles_obj)
	create_test_setups(test_skew_rotation_rect_obj)
	create_test_setups(pillar_obj)

# region Helper functions
# Helper function to create rectangular collision objects for testing
func _create_rectangular_collision_object(object_name: String, size: Vector2) -> Node2D:
	var container: Node2D = auto_free(Node2D.new())
	container.name = object_name
	var static_body := StaticBody2D.new()
	static_body.collision_layer = 1
	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	static_body.add_child(collision_shape)
	container.add_child(static_body)
	return container
# endregion

## Tests to make sure that calling adjust_rect_to_testing_size
## returns rects with the correct size 
## Expected adjusted size to be original rect + TileSize * 1
@warning_ignore("unused_parameter")
func test_adjust_rect_to_testing_size(p_setups : Array[CollisionTestSetup2D], test_parameters := [
	[create_test_setups(eclipse_obj)],
	[create_test_setups(rect_8_tiles_obj)],
	[create_test_setups(test_skew_rotation_rect_obj)],
	[create_test_setups(pillar_obj)]
]) -> void:
	for setup in p_setups:
		var rect_tests : Array[RectCollisionTestingSetup] = setup.rect_collision_test_setups

		for rect_test in rect_tests:
			var rect: Rect2 = rect_test.rect_shape.get_rect()
			var result_rect : Rect2 = setup._adjust_rect_to_testing_size(rect, setup.collision_object.global_transform)
			var result_rect_size: Vector2 = result_rect.size
			var minimum_expected_size: Vector2 = rect.size + TILE_SIZE * 1
			assert_vector(result_rect_size).is_not_equal(rect.size)
			assert_float(result_rect_size.x).is_greater_equal(minimum_expected_size.x)
			assert_float(result_rect.size.y).is_greater_equal(minimum_expected_size.y)
	

func create_test_setups(p_container : Node) -> Array[CollisionTestSetup2D]:
	var test_setups : Array[CollisionTestSetup2D] = []
	
	if(p_container is CollisionObject2D):
		test_setups.append(CollisionTestSetup2D.new(p_container, Vector2(16,16)))
	
	for collision_object in p_container.find_children("", "CollisionObject2D"):
		test_setups.append(CollisionTestSetup2D.new(collision_object, Vector2(16,16)))

	return test_setups
