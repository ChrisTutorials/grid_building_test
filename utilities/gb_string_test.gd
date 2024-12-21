# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/utilities/gb_string.gd'

func before_test():
	var project_num_seperator = ProjectSettings.get_setting("editor/naming/node_name_num_separator")
	assert_int(project_num_seperator).append_failure_message("EXPECTED UNDERSCORE").is_equal(2) 

func test_convert_name_to_readable(p_name : String, p_expected : String, test_parameters = [
	["Smithy", "Smithy"],
	["HelloFriend", "Hello Friend"],
	["SadBearBearFish", "Sad Bear Bear Fish"],
	["Smithy_55", "Smithy"]
]):
	var result : String = GBString.convert_name_to_readable(p_name)
	assert_str(result).is_equal(p_expected)

func test_match_num_seperator(p_test_char : String, p_seperator : int, p_expected : bool, test_parameters = [
	[" ", 0, false],
	["_", 0, false],
	[" ", 1, true],
	["_", 2, true],
	["-", 3, true]
]):
	var matches : bool = GBString.match_num_seperator(p_test_char, p_seperator)
	assert_bool(matches).is_equal(p_expected)
