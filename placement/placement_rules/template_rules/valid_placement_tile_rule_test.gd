# GdUnit generated TestSuite
class_name ValidPlacementTileRuleTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

var library : TestSceneLibrary
var rule : ValidPlacementTileRule
var no_setup_indicator : RuleCheckIndicator
var valid_indicator : RuleCheckIndicator
var map : TileMap  # Explicitly typed as TileMap for clarity

# TileData instances for test cases
var tile_data_extra : TileData
var tile_data_partial_match : TileData
var tile_data_missing_key : TileData
var tile_data_full_match : TileData
var tile_data_none : TileData

func before():
	library = auto_free(load("res://test/grid_building_test/scenes/test_scene_library.tscn").instantiate())

func before_test():
	# Rule and indicator setup. Rule requires the tile data to be grass and Green
	rule = ValidPlacementTileRule.new()
	rule.expected_tile_custom_data = {"type": "grass", "color": Color.GREEN}
	no_setup_indicator = auto_free(library.indicator.instantiate()) as RuleCheckIndicator
	no_setup_indicator.add_rule(rule)
	add_child(no_setup_indicator)
	
	valid_indicator = auto_free(library.indicator.instantiate()) as RuleCheckIndicator
	valid_indicator.add_rule(rule)
	add_child(valid_indicator)
	
	# Map and targeting state setup
	map = auto_free(library.tile_map_buildable.instantiate()) as TileMap
	add_child(map)
	var targeting_state := GridTargetingState.new()
	targeting_state.target_map = map
	targeting_state.maps = [map]
	
	var placer : Node = auto_free(Node.new())
	var placement_node : Node2D =  auto_free(Node2D.new())
	
	## This must validate successfully
	var problems := rule.setup(RuleValidationParameters.new(placer, placement_node, targeting_state))
	assert_array(problems).is_empty()
	
	# Assign the TileSet to the TileMap
	map.tile_set = library.custom_data_tile_set

	# Initialize TileData objects for test cases using different tile positions
	tile_data_full_match = _create_tile_data.call(Vector2i(0, 0), {"type": "grass", "color": Color.GREEN})
	tile_data_partial_match = _create_tile_data.call(Vector2i(0, 1), {"type": "grass", "color": Color.BLUE})
	tile_data_missing_key = _create_tile_data.call(Vector2i(0, 2), {"missing": "key"})
	tile_data_none = _create_tile_data.call(Vector2i(0, 3), {})
	tile_data_extra = _create_tile_data.call(Vector2i(0, 4), {"type": "grass", "color": Color.GREEN, "height": 10})

# Existing test (kept for context)
@warning_ignore("unused_parameter")
func test_does_tile_have_valid_data(p_indicator : RuleCheckIndicator, p_expected : bool, test_parameters := [
	[null, false],
	[no_setup_indicator, true],
	[valid_indicator, true]
]) -> void:
	var result = rule.does_tile_have_valid_data(p_indicator, [map])
	assert_bool(result).is_equal(p_expected)

# Parameterized test using pre-initialized TileData objects
@warning_ignore("unused_parameter")
func test_test_tile_data_for_all_matches(p_tile_data : TileData, p_expected : bool, test_parameters := [
	[tile_data_extra, true],      	   # Full match
	[tile_data_partial_match, false],  # Partial match (color mismatch)
	[tile_data_missing_key, false],    # Missing key
	[tile_data_full_match, true],      # Matches 2 of 2
	[tile_data_none, false],   		   # Empty required data
	[null, false],        			   # Null tile data
]) -> void:
	var result = rule._test_tile_data_for_all_matches(p_tile_data, rule.expected_tile_custom_data)
	assert_bool(result).is_equal(p_expected)

func after_test():
	# Clean up any resources created during the test
	pass

func after():
	# Clean up library
	pass

# Helper function to create TileData at a specific tile position
func _create_tile_data(coords: Vector2i, custom_data: Dictionary) -> TileData:
	map.set_cell(0, coords, 0, coords)
	var tile_data = map.get_cell_tile_data(0, coords)
	for key in custom_data:
		tile_data.set_custom_data(key, custom_data[key])
	return tile_data
