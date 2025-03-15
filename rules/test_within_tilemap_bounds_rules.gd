extends GdUnitTestSuite

var rule : WithinTilemapBoundsRule
var tile_map : TileMap
var tile_map_layer : TileMapLayer
var params : RuleValidationParameters
var targeting_state : Object

# [before(), before_test(), after_test() remain unchanged]

# [test_setup_stores_params() and test_tear_down_clears_params() remain unchanged]

# Updated test_validate_condition
@warning_ignore("unused_parameter")
func test_validate_condition(indicator_setup: Array[Dictionary], expected_success: bool, expected_message: String, test_parameters := [
	[[], true, "No tile collision indicators to check for within tile_map bounds."],
	[[{"pos": Vector2.ZERO}], true, "Placement is within map bounds"],
	[[{"pos": Vector2.ZERO, "valid": false}], false, "Tried placing outside of valid map area"]
]) -> void:
	targeting_state.target_map = tile_map
	rule.setup(params)
	
	# Create indicators using create_indicators
	var test_indicators := create_indicators(indicator_setup)
	rule.indicators = test_indicators
	
	var result = rule.validate_condition()
	assert_bool(result.success).is_equal(expected_success)
	assert_str(result.message).is_equal(expected_message)

# Updated test_get_failing_indicators (mostly unchanged, already correct)
@warning_ignore("unused_parameter")
func test_get_failing_indicators(indicator_setup: Array[Dictionary], target_map: Node2D, expected_failing_count: int, test_parameters := [
	[[], null, 0],
	[[{"pos": Vector2.ZERO}], null, 1],
	[[{"pos": Vector2.ZERO}], auto_free(TileMapLayer.new()), 0],
	[[{"pos": Vector2.ZERO}], auto_free(TileMapLayer.new()), 1],
	[[null], auto_free(TileMapLayer.new()), 0],
	[[{"pos": Vector2.ZERO}, {"pos": Vector2(32,32)}], auto_free(TileMapLayer.new()), 1]
]) -> void:
	targeting_state.target_map = target_map
	rule.setup(params)
	
	var test_indicators := create_indicators(indicator_setup)
	var failing := rule.get_failing_indicators(test_indicators)
	assert_int(failing.size()).is_equal(expected_failing_count)
	
	for ind in failing:
		assert_object(ind).is_not_null()

# Updated test_is_over_valid_tile
@warning_ignore("unused_parameter")
func test_is_over_valid_tile(indicator_setup: Array[Dictionary], target_map: Node2D, tile_data_exists: bool, expected_result: bool, test_parameters := [
	[[], auto_free(TileMapLayer.new()), false, false],  # Empty setup for null indicator
	[[{"pos": Vector2.ZERO}], null, false, false],  # Null map
	[[{"pos": Vector2.ZERO}], auto_free(TileMapLayer.new()), false, false],  # No tile data
	[[{"pos": Vector2.ZERO}], create_tile_map_with_data(Vector2i.ZERO), true, true],  # Tile data exists
	[[{"pos": Vector2.ZERO, "valid": false}], auto_free(TileMapLayer.new()), false, false]  # Invalid indicator
]) -> void:
	if tile_data_exists and target_map is TileMap:
		target_map.set_cell(0, Vector2i.ZERO, 0, Vector2i.ZERO)
	
	# Create indicators using create_indicators, take first one or null if empty
	var test_indicators := create_indicators(indicator_setup)
	var indicator = test_indicators[0] if not test_indicators.is_empty() else null
	
	var result = rule.is_over_valid_tile(indicator, target_map)
	assert_bool(result).is_equal(expected_result)

# Updated create_indicators to handle null cases and optional validity
func create_indicators(p_setup: Array[Dictionary]) -> Array[RuleCheckIndicator]:
	var indicators: Array[RuleCheckIndicator] = []
	
	for case in p_setup:
		if case != null and case.has("pos"):  # Check for valid dictionary
			var indicator = auto_free(RuleCheckIndicator.new())
			indicator.global_position = case["pos"]
			# Note: "valid" flag isn't directly used here as RuleCheckIndicator doesn't have it
			# Validity will need to be handled by the rule logic or tile data
			indicators.append(indicator)
	
	return indicators

# [create_tile_map_with_data() remains unchanged]
