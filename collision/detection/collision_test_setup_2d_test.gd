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
	# No shared setup needed - tests create their own objects
	tile_map_16px = auto_free(TileMap.new())
	add_child(tile_map_16px)
	tile_map_16px.tile_set = TileSet.new()
	tile_map_16px.tile_set.tile_size = TILE_SIZE


func after_test() -> void:
	# Cleanup is handled by auto_free() in individual tests
	pass

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
func test_adjust_rect_to_testing_size() -> void:
	# Create fresh objects for this test
	# Note: Factory methods already add children to test suite, so no need to call add_child()
	var eclipse: Node2D = CollisionObjectTestFactory.create_static_body_with_capsule(self)
	
	# _create_rectangular_collision_object returns objects with auto_free but NOT added to scene
	var rect_8: Node2D = _create_rectangular_collision_object("RectTestObject", Vector2(128, 128))
	add_child(rect_8)
	
	var skew: Node2D = _create_rectangular_collision_object("SkewRotationTestObject", Vector2(128, 128))
	add_child(skew)
	
	var pillar: Node2D = auto_free(load(GBTestConstants.PILLAR_UID).instantiate())
	add_child(pillar)
	
	# Create test setups
	var all_setups: Array[CollisionTestSetup2D] = []
	all_setups.append_array(create_test_setups(eclipse))
	all_setups.append_array(create_test_setups(rect_8))
	all_setups.append_array(create_test_setups(skew))
	all_setups.append_array(create_test_setups(pillar))
	
	# Run tests on all setups
	for setup in all_setups:
		var rect_tests : Array[RectCollisionTestingSetup] = setup.rect_collision_test_setups

		for rect_test in rect_tests:
			var rect: Rect2 = rect_test.rect_shape.get_rect()
			var result_rect : Rect2 = setup._adjust_rect_to_testing_size(rect, setup.collision_object.global_transform)
			var result_rect_size: Vector2 = result_rect.size
			var minimum_expected_size: Vector2 = rect.size + TILE_SIZE * 1
			assert_vector(result_rect_size).append_failure_message("Adjusted rect size should differ from original rect size").is_not_equal(rect.size)
			assert_float(result_rect_size.x).append_failure_message("Adjusted rect width should meet minimum size requirement").is_greater_equal(minimum_expected_size.x)
			assert_float(result_rect.size.y).append_failure_message("Adjusted rect height should meet minimum size requirement").is_greater_equal(minimum_expected_size.y)

func create_test_setups(p_container : Node) -> Array[CollisionTestSetup2D]:
	var test_setups : Array[CollisionTestSetup2D] = []
	
	if(p_container is CollisionObject2D):
		test_setups.append(CollisionTestSetup2D.new(p_container, Vector2(16,16)))
	
	for collision_object in p_container.find_children("", "CollisionObject2D"):
		test_setups.append(CollisionTestSetup2D.new(collision_object, Vector2(16,16)))

	return test_setups
