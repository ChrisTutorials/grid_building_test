# GdUnit generated TestSuite
class_name ManipulationDataTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/manipulation_system/manipulation_data.gd'

func test_queue_free_manipulation_objects() -> void:
	var data = create_manipulation(GBEnums.Action.MOVE)
	data.target = Manipulatable.new()
	add_child(data.target)
	assert_that(data.target).is_not_null()
	data.queue_free_manipulation_objects()
	assert_that(data.target).is_null()

## Creates a manipulation where the generated object is both the source and the target
func create_manipulation(p_action : GBEnums.Action) -> ManipulationData:
	var root = auto_free(Node2D.new())
	add_child(root)
	var source = auto_free(Manipulatable.new())
	root.add_child(source)
	var manipulator = auto_free(Node.new())
	add_child(manipulator)
	var data : ManipulationData = auto_free(ManipulationData.new(manipulator, source, source, p_action))
	return data
