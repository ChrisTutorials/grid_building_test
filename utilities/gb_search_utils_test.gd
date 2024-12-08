# GdUnit generated TestSuite
class_name GbSearchUtilsTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/building_system/utilities/gb_search_utils.gd'

func test_find_first_when_parent_null() -> void:
	var parent = null
	var result = GBSearchUtils.find_first(parent, Node)
	assert_that(result).is_null()
