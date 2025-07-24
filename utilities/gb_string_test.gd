# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

var project_name_num_seperator : int

func before_test():
	project_name_num_seperator = ProjectSettings.get_setting("editor/naming/node_name_num_separator")

func after_test():
	ProjectSettings.set_setting("editor/naming/node_name_num_separator", project_name_num_seperator)

@warning_ignore('unused_parameter')
func test_convert_name_to_readable_underscore(p_name : String, p_expected : String, test_parameters := [
	["Smithy", "Smithy"],
	["HelloFriend", "Hello Friend"],
	["SadBearBearFish", "Sad Bear Bear Fish"],
	["Smithy_55", "Smithy"]
]):
	ProjectSettings.set_setting("editor/naming/node_name_num_separator", 2)
	var result : String = GBString.convert_name_to_readable(p_name)
	assert_str(result).is_equal(p_expected)
	
@warning_ignore('unused_parameter')
func test_match_num_seperator(p_test_char : String, p_seperator : int, p_expected : bool, test_parameters := [
	[" ", 0, false],
	["_", 0, false],
	[" ", 1, true],
	["_", 2, true],
	["-", 3, true]
]):
	var matches : bool = GBString.match_num_seperator(p_test_char, p_seperator)
	assert_bool(matches).is_equal(p_expected)
