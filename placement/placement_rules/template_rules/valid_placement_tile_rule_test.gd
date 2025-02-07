# GdUnit generated TestSuite
class_name ValidPlacementTileRuleTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/placement/placement_rules/template_rules/valid_placement_tile_rule.gd'

var library : TestSceneLibrary
var rule : ValidPlacementTileRule
var no_setup_indicator : RuleCheckIndicator
var valid_indicator : RuleCheckIndicator

var map : Node2D

func before():
	library = auto_free(load("res://test/grid_building_test/scenes/test_scene_library.tscn").instantiate())

func before_test():
	rule = ValidPlacementTileRule.new()
	no_setup_indicator = auto_free(library.indicator.instantiate())
	add_child(no_setup_indicator)
	
	valid_indicator = auto_free(library.indicator.instantiate())
	add_child(valid_indicator)
	
	map = auto_free(library.tile_map_buildable.instantiate())
	add_child(map)

@warning_ignore("unused_parameter")
func test_does_tile_have_valid_data(p_indicator : RuleCheckIndicator, p_expected : bool, test_parameters = [
	[null, false],
	[no_setup_indicator, true],
	[valid_indicator, true]
]) -> void:
	var result = rule.does_tile_have_valid_data(p_indicator, [map])
	assert_bool(result).is_equal(p_expected)
