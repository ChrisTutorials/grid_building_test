extends GdUnitTestSuite

var name_displayer : NameDisplayer
var test_node : Node


var building_node_script = preload("res://addons/grid_building/components/building_node.gd")
var project_name_num_seperator : int

func before_test():
	name_displayer = NameDisplayer.new()
	test_node = auto_free(Node.new())
	add_child(test_node)
	project_name_num_seperator = ProjectSettings.get_setting("editor/naming/node_name_num_separator")
	ProjectSettings.set_setting("editor/naming/node_name_num_separator", 2) 

func after_test():
	ProjectSettings.set_setting("editor/naming/node_name_num_separator", project_name_num_seperator)
	
@warning_ignore("unused_parameter")
func test_get_display_name(p_name : String, p_method_name : String, p_ex : String, p_ex_start_with : bool, test_parameters = [
	["TestNode_500", "", "Test Node", false],
	["TestNode_500", "to_string", "TestNode_500:<Node", true]
]):
	test_node.name = p_name
	name_displayer.custom_name_method = p_method_name
	var display_name = name_displayer.get_display_name(test_node)
	
	if p_ex_start_with:
		assert_str(display_name).starts_with(p_ex)
	else:
		assert_str(display_name).is_equal(p_ex)

# Tests for building_node.gd the default script attached to preview instance root nodes during building preview
@warning_ignore("unused_parameter")
func test_building_node_get_display_name(p_name : String, p_ex : String, test_parameters = [
	["TestNode_500", "Test Node"]
]):
	var building_node : Node = auto_free(building_node_script.new())
	building_node.name = p_name
	var display_name = name_displayer.get_display_name(building_node)
	assert_str(display_name).is_equal(p_ex)
