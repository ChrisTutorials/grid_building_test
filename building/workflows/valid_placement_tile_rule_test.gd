# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")
## Tests for ValidPlacementTileRule class functionality.
## Validates tile data matching against expected custom data requirements,
## ensuring placement rules correctly identify valid and invalid tile configurations.
const TILE_SOURCE_ID := 0
const TILE_COORD_FULL_MATCH := Vector2i(0, 0)
const TILE_COORD_PARTIAL_MATCH := Vector2i(0, 1)
const TILE_COORD_MISSING_KEY := Vector2i(0, 2)
const TILE_COORD_NONE := Vector2i(0, 3)
const TILE_COORD_EXTRA := Vector2i(0, 4)

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
var _container: GBCompositionContainer
var _env: AllSystemsTestEnvironment
var _gts: GridTargetingState

#region Test setup and teardown


## Initializes test environment with ValidPlacementTileRule and indicator setup.
func before_test() -> void:
	_env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV)
	_container = _env.injector.composition_container
	_gts = _container.get_states().targeting

	# Rule and indicator setup. Rule requires the tile data to be grass and Green
	rule = ValidPlacementTileRule.new()
	rule.expected_tile_custom_data = {"type": "grass", "color": Color.GREEN}

	## Use the standard indicator scene for testing
	var indicator_scene: PackedScene = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	no_setup_indicator = auto_free(indicator_scene.instantiate()) as RuleCheckIndicator
	no_setup_indicator.add_rule(rule)
	no_setup_indicator.resolve_gb_dependencies(_container)
	add_child(no_setup_indicator)

	valid_indicator = auto_free(indicator_scene.instantiate()) as RuleCheckIndicator
	valid_indicator.add_rule(rule)
	valid_indicator.resolve_gb_dependencies(_container)
	add_child(valid_indicator)

	# Map and targeting state setup - override the factory defaults with test constants
	map_layer = (
		auto_free(GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE.instantiate()) as TileMapLayer
	)
	add_child(map_layer)
	_gts.target_map = map_layer
	_gts.maps = [map_layer]

	## This must validate successfully
	var setup_issues := rule.setup(_gts)
	(
		assert_array(setup_issues) \
		. append_failure_message("Rule setup should complete without issues") \
		. is_empty()
	)

	# Assign the TileSet to the TileMap
	map_layer.tile_set = GBTestConstants.TEST_CUSTOM_DATA_TILE_SET

	# Initialize TileData objects for test cases using different tile positions
	tile_data_full_match = _create_tile_data.call(
		TILE_COORD_FULL_MATCH, {"type": "grass", "color": Color.GREEN}
	)
	tile_data_partial_match = _create_tile_data.call(
		TILE_COORD_PARTIAL_MATCH, {"type": "grass", "color": Color.BLUE}
	)
	tile_data_missing_key = _create_tile_data.call(TILE_COORD_MISSING_KEY, {"missing": "key"})
	tile_data_none = _create_tile_data.call(TILE_COORD_NONE, {})
	tile_data_extra = _create_tile_data.call(
		TILE_COORD_EXTRA, {"type": "grass", "color": Color.GREEN, "height": 10}
	)


#endregion
#region Test suite methods

## Tests ValidPlacementTileRule.does_tile_have_valid_data with various indicator setups.
@warning_ignore("unused_parameter")
func test_does_tile_have_valid_data(
	p_indicator: RuleCheckIndicator,
	p_expected: bool,
	test_parameters := [[null, false], [no_setup_indicator, true], [valid_indicator, true]]
) -> void:
	assert_object(rule).append_failure_message("Rule should not be null after setup").is_not_null()
	if not rule:
		fail("Rule is null - cannot test does_tile_have_valid_data")
		return
	var result: bool = rule.does_tile_have_valid_data(p_indicator, [map_layer])
	(
		assert_bool(result) \
		. append_failure_message(
			"Tile data validation should match expected result for indicator: " + str(p_indicator)
		) \
		. is_equal(p_expected)
	)


## Tests ValidPlacementTileRule._test_tile_data_for_all_matches with various tile data scenarios.
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
	assert_object(rule).append_failure_message("Rule should not be null after setup").is_not_null()
	if not rule:
		fail("Rule is null - cannot test _test_tile_data_for_all_matches")
		return
	(
		assert_object(rule.expected_tile_custom_data) \
		. append_failure_message("Rule expected_tile_custom_data should not be null") \
		. is_not_null()
	)
	var result: bool = rule._test_tile_data_for_all_matches(
		p_tile_data, rule.expected_tile_custom_data
	)
	(
		assert_bool(result) \
		. append_failure_message(
			"Tile data matching should match expected result for tile data: " + str(p_tile_data)
		) \
		. is_equal(p_expected)
	)


#endregion
#region Helper methods

## Helper function to create TileData at a specific tile position.
func _create_tile_data(coords: Vector2i, custom_data: Dictionary) -> TileData:
	map_layer.set_cell(coords, TILE_SOURCE_ID, coords)
	var tile_data: TileData = map_layer.get_cell_tile_data(coords)
	for key: String in custom_data.keys():
		tile_data.set_custom_data(key, custom_data[key])
	return tile_data
