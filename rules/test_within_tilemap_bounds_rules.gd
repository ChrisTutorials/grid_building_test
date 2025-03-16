extends GdUnitTestSuite

var rule : WithinTilemapBoundsRule
var tile_map : TileMap
var tile_map_layer : TileMapLayer
var params : RuleValidationParameters
var targeting_state : GridTargetingState
var test_parameters : RuleValidationParameters

var library : TestSceneLibrary
var library_scene : PackedScene = load("uid://ct16sdntvm8ow")

func before():
	library = auto_free(library_scene.instantiate()) as TestSceneLibrary

func before_test():
	tile_map = library.tile_map_buildable.instantiate()
	add_child(tile_map)
	
	targeting_state = GridTargetingState.new()
	
	rule = WithinTilemapBoundsRule.new()
	var target : Node2D = auto_free(Node2D.new())
	add_child(target)
	test_parameters = RuleValidationParameters.new(self, target, targeting_state)
	
	## Setup & Assert Check!
	var results : Array[String] = rule.setup(test_parameters)
	assert_array(results).append_failure_message(str(results)).is_empty()
	
# Updated test_validate_condition
@warning_ignore("unused_parameter")
func test_validate_condition(indicator_setup: Array[Dictionary], expected_success: bool, test_parameters := [
	[[], true],
	[[{"pos": Vector2.ZERO}], true],
	[[{"pos": Vector2(7000, 7000), "valid": false}], false] # Way out of bounds
]) -> void:
	targeting_state.target_map = tile_map
	
	# Create indicators using create_indicators
	var test_indicators := create_indicators(indicator_setup)
	rule.indicators = test_indicators
	
	var result = rule.validate_condition()
	assert_bool(result.is_successful).append_failure_message(result.reason).is_equal(expected_success)

# Updated test__get_failing_indicators (mostly unchanged, already correct)
@warning_ignore("unused_parameter")
func test__get_failing_indicators(indicator_setup: Array[Dictionary], target_map: Node2D, expected_failing_count: int, test_parameters := [
	[[], null, 0],
	[[{"pos": Vector2.ZERO}], null, 1],
	[[{"pos": Vector2.ZERO}], auto_free(TileMapLayer.new()), 0],
	[[{"pos": Vector2.ZERO}], auto_free(TileMapLayer.new()), 1],
	[[null], auto_free(TileMapLayer.new()), 0],
	[[{"pos": Vector2.ZERO}, {"pos": Vector2(32,32)}], auto_free(TileMapLayer.new()), 1]
]) -> void:
	targeting_state.target_map = target_map
	
	var test_indicators := create_indicators(indicator_setup)
	var failing := rule._get_failing_indicators(test_indicators)
	assert_int(failing.size()).is_equal(expected_failing_count)
	
	for ind in failing:
		assert_object(ind).is_not_null()

# Updated test__is_over_valid_tile
@warning_ignore("unused_parameter")
func test__is_over_valid_tile(indicator_setup: Array[Dictionary], target_map: Node2D, tile_data_exists: bool, expected_result: bool, test_parameters := [
	[[], auto_free(TileMapLayer.new()), false, false],  # Empty setup for null indicator
	[[{"pos": Vector2.ZERO}], null, false, false],  # Null map
	[[{"pos": Vector2.ZERO}], auto_free(TileMapLayer.new()), false, false],  # No tile data
	[[{"pos": Vector2.ZERO}], tile_map, true, true],  # Tile data exists
	[[{"pos": Vector2.ZERO, "valid": false}], auto_free(TileMapLayer.new()), false, false]  # Invalid indicator
]) -> void:
	if tile_data_exists and target_map is TileMap:
		target_map.set_cell(0, Vector2i.ZERO, 0, Vector2i.ZERO)
	
	# Create indicators using create_indicators, take first one or null if empty
	var test_indicators := create_indicators(indicator_setup)
	var indicator = test_indicators[0] if not test_indicators.is_empty() else null
	
	var result = rule._is_over_valid_tile(indicator, target_map)
	assert_bool(result).is_equal(expected_result)

# Updated create_indicators to handle null cases and optional validity
func create_indicators(p_setup: Array[Dictionary]) -> Array[RuleCheckIndicator]:
	var indicators: Array[RuleCheckIndicator] = []
	var test_shape : Shape2D = RectangleShape2D.new()
	test_shape.size = Vector2i(16,16)
	
	for case in p_setup:
		if case != null and case.has("pos"):  # Check for valid dictionary
			var indicator : RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
			indicator.shape = test_shape
			indicator.global_position = case["pos"]
			add_child(indicator)
			indicators.append(indicator)
	
	return indicators
