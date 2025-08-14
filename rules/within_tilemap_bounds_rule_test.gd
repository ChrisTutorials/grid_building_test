extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var rule : WithinTilemapBoundsRule
var tile_map : TileMapLayer
var targeting_state : GridTargetingState
var rule_validation_params : RuleValidationParameters


func before_test():
	# Create a smaller populated tile map for faster tests
	tile_map = GodotTestFactory.create_tile_map_layer(self, 40)

	# Targeting state with our specific map
	targeting_state = UnifiedTestFactory.create_targeting_state(self)
	targeting_state.target_map = tile_map
	targeting_state.maps = [tile_map]

	# Rule under test
	rule = WithinTilemapBoundsRule.new()
	
	# Create placer/target nodes (RuleValidationParameters expects (placer, target, state))
	var placer: Node2D = GodotTestFactory.create_node2d(self)
	var target: Node2D = GodotTestFactory.create_node2d(self)
	
	# Get logger from test container and pass it through RuleValidationParameters
	var logger = TEST_CONTAINER.get_logger()
	rule_validation_params = RuleValidationParameters.new(placer, target, targeting_state, logger)

	var setup_issues: Array[String] = rule.setup(rule_validation_params)
	assert_array(setup_issues).append_failure_message(str(setup_issues)).is_empty()

# Updated test_validate_condition
@warning_ignore("unused_parameter")
func test_validate_condition(indicator_setup: Array[Dictionary], expected_success: bool, test_parameters := [
	[[], true],
	[[{"pos": Vector2.ZERO}], true],
	[[{"pos": Vector2(7000, 7000), "valid": false}], false] # Way out of bounds
]) -> void:
	var test_indicators := _create_indicators(indicator_setup, [rule])
	# TODO: Manual investigation needed - rule.indicators not being populated properly
	# The rule.indicators should be populated by add_rule() calls in _create_indicators
	# but tests are failing with tile set errors and indicator population issues
	var result: RuleResult = rule.validate_condition()
	assert_bool(result.is_successful).append_failure_message(result.reason).is_equal(expected_success)

# Updated test__get_failing_indicators (mostly unchanged, already correct)
@warning_ignore("unused_parameter")
func test__get_failing_indicators(indicator_setup: Array[Dictionary], expected_failing_count: int, test_parameters := [
	[[], 0],                                       # No indicators = no failures
	[[{"pos": Vector2.ZERO}], 0],                        # One at 0 passes
	[[{"pos": Vector2i(-1000, -1000)}], 1],               # Distant off of tilemap = fail
	[[{"pos": Vector2i(1000, 0)}], 1],                    # Distant one direction = fail
	[[null], 0],                                            # Null indicator is ignored
	[[{"pos": Vector2.ZERO}, {"pos": Vector2(32,32)}], 0],   # Adjacent in-bounds tiles
	[[{"pos": Vector2.ZERO}, {"pos": Vector2(320,320)}], 1]  # Out-of-bounds second indicator
]) -> void:
	var test_indicators := _create_indicators(indicator_setup, [rule])
	# The rule.indicators should be populated by add_rule() calls in _create_indicators
	var failing := rule._get_failing_indicators(test_indicators)
	assert_int(failing.size()).is_equal(expected_failing_count)
	for ind in failing:
		assert_object(ind).is_not_null()

# Updated test__is_over_valid_tile
@warning_ignore("unused_parameter")
func test__is_over_valid_tile(indicator_setup: Array[Dictionary], p_map_obj : Node2D, tile_data_exists: bool, expected_result: bool, test_parameters := [
	[[], tile_map, false, false],  # Empty setup for null indicator
	[[{"pos": Vector2.ZERO}], null, false, false],  # Null map
	[[{"pos": Vector2.ZERO}], GodotTestFactory.create_empty_tile_map_layer(self), false, false],  # No tile data
]) -> void:
	var test_indicators := _create_indicators(indicator_setup, [rule])
	var indicator: RuleCheckIndicator = test_indicators[0] if not test_indicators.is_empty() else null
	var result: ValidationResults = rule._is_over_valid_tile(indicator, p_map_obj)
	assert_bool(result.is_successful).append_failure_message("Were the indicators able to validate").is_equal(expected_result)

#region Helper Functions
# Updated _create_indicators to handle null cases and optional validity
func _create_indicators(p_setup: Array[Dictionary], p_rules : Array[TileCheckRule]) -> Array[RuleCheckIndicator]:
	var indicators: Array[RuleCheckIndicator] = []
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.extents = Vector2(16,16)
	for case in p_setup:
		if case == null or not case.has("pos"):
			continue
		var indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
		indicator.shape = rect_shape
		indicator.global_position = case["pos"]
		add_child(indicator)
		for r in p_rules:
			indicator.add_rule(r)
		indicators.append(indicator)
		assert_array(indicator.validate()).is_empty()
	return indicators
#endregion
