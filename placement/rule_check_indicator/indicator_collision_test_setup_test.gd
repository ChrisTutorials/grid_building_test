# GdUnit generated TestSuite
class_name IndicatorCollisionTestSetupTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

const TILE_SIZE = Vector2(16,16)

var eclipse_obj
var rect_8_tiles_obj
var test_skew_rotation_rect_obj
var pillar_obj
var tile_map_16px : TileMap

func before_test():
	tile_map_16px = auto_free(TileMap.new())
	add_child(tile_map_16px)
	tile_map_16px.tile_set = TileSet.new()
	tile_map_16px.tile_set.tile_size = Vector2(16,16)
	
	eclipse_obj = auto_free(load("res://test/grid_building_test/scenes/test_elipse.tscn").instantiate())
	add_child(eclipse_obj)
	
	rect_8_tiles_obj = auto_free(load("res://test/grid_building_test/scenes/test_rect_15_tiles.tscn").instantiate())
	add_child(rect_8_tiles_obj)

	test_skew_rotation_rect_obj = auto_free(load("res://test/grid_building_test/scenes/test_skew_rotation_rect.tscn").instantiate())
	add_child(test_skew_rotation_rect_obj)
	
	pillar_obj = auto_free(load("res://test/grid_building_test/scenes/objects/test_pillar.tscn").instantiate())
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
			var rect = rect_test.rect_shape.get_rect()
			var result_rect : Rect2 = setup._adjust_rect_to_testing_size(rect, setup.collision_object.global_transform)
			var result_rect_size = result_rect.size
			var minimum_expected_size = rect.size + TILE_SIZE * 1
			assert_vector(result_rect_size).is_not_equal(rect.size)
			assert_float(result_rect_size.x).is_greater_equal(minimum_expected_size.x)
			assert_float(result_rect.size.y).is_greater_equal(minimum_expected_size.y)
	

func create_test_setups(p_root : Node) -> Array[IndicatorCollisionTestSetup]:
	var test_setups : Array[IndicatorCollisionTestSetup] = []
	
	if(p_root is CollisionObject2D):
		test_setups.append(IndicatorCollisionTestSetup.new(p_root, Vector2(16,16)))
	
	for collision_object in p_root.find_children("", "CollisionObject2D"):
		test_setups.append(IndicatorCollisionTestSetup.new(collision_object, Vector2(16,16)))

	return test_setups
