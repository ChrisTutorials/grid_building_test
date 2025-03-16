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
	targeting_state.target_map = tile_map
	targeting_state.maps = [tile_map]
	
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
	# Create indicators using _create_indicators
	var test_indicators := _create_indicators(indicator_setup)
	rule.indicators = test_indicators
	
	var result = rule.validate_condition()
	assert_bool(result.is_successful).append_failure_message(result.reason).is_equal(expected_success)

# Updated test__get_failing_indicators (mostly unchanged, already correct)
@warning_ignore("unused_parameter")
func test__get_failing_indicators(indicator_setup: Array[Dictionary], expected_failing_count: int, test_parameters := [
	[[], 0],												# No indicators = no failures
	[[{"pos": Vector2.ZERO}], 0], 							# One at 0 passes
	[[{"pos": Vector2i(-1000, -1000)}], 1], 				# Distant off of tilemap = fail
	[[{"pos": Vector2i(1000, 0)}], 1], 						# Distant one direction = fail
	[[null], 0], 											# Null indicator is null, so ignored, no fails
	[[{"pos": Vector2.ZERO}, {"pos": Vector2(32,32)}], 0], 	# Both are within bounds, 0 fails
	[[{"pos": Vector2.ZERO}, {"pos": Vector2(320,320)}], 1] # One is out of bounds, 1 fail 1 pass
]) -> void:
	
	var test_indicators := _create_indicators(indicator_setup)
	var failing := rule._get_failing_indicators(test_indicators)
	assert_int(failing.size()).is_equal(expected_failing_count)
	
	for ind in failing:
		assert_object(ind).is_not_null()

# Updated test__is_over_valid_tile
@warning_ignore("unused_parameter")
func test__is_over_valid_tile(indicator_setup: Array[Dictionary], p_map_obj : Node2D, tile_data_exists: bool, expected_result: bool, test_parameters := [
	[[], tile_map, false, false],  # Empty setup for null indicator
	[[{"pos": Vector2.ZERO}], null, false, false],  # Null map
	[[{"pos": Vector2.ZERO}], _create_empty_tile_map_layer(), false, false],  # No tile data
]) -> void:
	
	# Create indicators using _create_indicators, take first one or null if empty
	var test_indicators := _create_indicators(indicator_setup)
	var indicator = test_indicators[0] if not test_indicators.is_empty() else null
	
	var result = rule._is_over_valid_tile(indicator, p_map_obj)
	assert_bool(result).append_failure_message("Were the indicators able to validate").is_equal(expected_result)


#region Helper Functions
# Updated _create_indicators to handle null cases and optional validity
func _create_indicators(p_setup: Array[Dictionary]) -> Array[RuleCheckIndicator]:
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
	
func _create_empty_tile_map_layer() -> TileMapLayer:
	var layer : TileMapLayer = auto_free(TileMapLayer.new())
	layer.tile_set = TileSet.new()

	return layer
#endregion
