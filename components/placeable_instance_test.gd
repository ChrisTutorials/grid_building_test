# GdUnit generated TestSuite
class_name PlaceableInstanceTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/components/placeable_instance.gd'

var placeable_path = "res://test/grid_building_test/resources/placeable/test_placeable_rect_15_tiles.tres"

func test_instance_from_save_does_not_duplicate_node():
	var save = {
		PlaceableInstance.Names.INSTANCE_NAME: "ZZZTestInstance",
		PlaceableInstance.Names.PLACEABLE: {
			Placeable.Names.FILE_PATH: placeable_path
		},
		PlaceableInstance.Names.TRANSFORM: var_to_str(Transform2D.IDENTITY)
	}
	
	# Object must have a PlaceableInstance to load save data into a instance
	var instance = PlaceableInstance.instance_from_save(save, self)
	
	var placeable_instances = instance.find_children("", "PlaceableInstance", true, false)
	assert_int(placeable_instances.size()).is_equal(1)
	
	instance.free()
