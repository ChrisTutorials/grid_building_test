# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# TestSuite generated from

var rule: ValidPlacementTileRule
var no_setup_indicator: RuleCheckIndicator
var valid_indicator: RuleCheckIndicator
var map_layer: TileMapLayer

# TileData instances for test cases
var tile_data_extra: TileData
var tile_data_partial_match: TileData
var tile_data_missing_key: TileData
var tile_data_full_match: TileData
var tile_data_none: TileData
var _container: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")
var _gts: GridTargetingState


func before_test():
	var injector = UnifiedTestFactory.create_test_injector(self, _container)
	_gts = _container.get_states().targeting
	# Rule and indicator setup. Rule requires the tile data to be grass and Green
	rule = ValidPlacementTileRule.new()
	rule.expected_tile_custom_data = {"type": "grass", "color": Color.GREEN}
	no_setup_indicator = auto_free(TestSceneLibrary.indicator.instantiate()) as RuleCheckIndicator
	no_setup_indicator.add_rule(rule)
	add_child(no_setup_indicator)

	valid_indicator = auto_free(TestSceneLibrary.indicator.instantiate()) as RuleCheckIndicator
	valid_indicator.add_rule(rule)
	add_child(valid_indicator)

	# Map and targeting state setup
	map_layer = auto_free(TestSceneLibrary.tile_map_layer_buildable.instantiate()) as TileMapLayer
	add_child(map_layer)
	var targeting_state := _container.get_states().targeting
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]

	var placer: Node = auto_free(Node.new())
	var placement_node: Node2D = GodotTestFactory.create_node2d(self)

	## This must validate successfully
	var setup_issues := rule.setup(_gts)
	assert_array(setup_issues).is_empty()

	# Assign the TileSet to the TileMap
	map_layer.tile_set = TestSceneLibrary.custom_data_tile_set

	# Initialize TileData objects for test cases using different tile positions
	tile_data_full_match = _create_tile_data.call(
		Vector2i(0, 0), {"type": "grass", "color": Color.GREEN}
	)
	tile_data_partial_match = _create_tile_data.call(
		Vector2i(0, 1), {"type": "grass", "color": Color.BLUE}
	)
	tile_data_missing_key = _create_tile_data.call(Vector2i(0, 2), {"missing": "key"})
	tile_data_none = _create_tile_data.call(Vector2i(0, 3), {})
	tile_data_extra = _create_tile_data.call(
		Vector2i(0, 4), {"type": "grass", "color": Color.GREEN, "height": 10}
	)


# Existing test (kept for context)
@warning_ignore("unused_parameter")


func test_does_tile_have_valid_data(
	p_indicator: RuleCheckIndicator,
	p_expected: bool,
	test_parameters := [[null, false], [no_setup_indicator, true], [valid_indicator, true]]
) -> void:
	var result = rule.does_tile_have_valid_data(p_indicator, [map_layer])
	assert_bool(result).is_equal(p_expected)


# Parameterized test using pre-initialized TileData objects
@warning_ignore("unused_parameter")


func test_test_tile_data_for_all_matches(
	p_tile_data: TileData,
	p_expected: bool,
	test_parameters := [
		[tile_data_extra, true],  # Full match
		[tile_data_partial_match, false],  # Partial match (color mismatch)
		[tile_data_missing_key, false],  # Missing key
		[tile_data_full_match, true],  # Matches 2 of 2
		[tile_data_none, false],  # Empty required data
		[null, false],  # Null tile data
	]
) -> void:
	var result = rule._test_tile_data_for_all_matches(p_tile_data, rule.expected_tile_custom_data)
	assert_bool(result).is_equal(p_expected)


func after_test():
	# Clean up any resources created during the test
	pass


func after():
	# Clean up TestSceneLibrary
	pass


# Helper function to create TileData at a specific tile position
func _create_tile_data(coords: Vector2i, custom_data: Dictionary) -> TileData:
	map_layer.set_cell(coords, 0, coords)
	var tile_data = map_layer.get_cell_tile_data(coords)
	for key in custom_data:
		tile_data.set_custom_data(key, custom_data[key])
	return tile_data
