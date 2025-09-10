extends GdUnitTestSuite

# High-value unit tests for IndicatorFactory to catch failures in indicator generation from position maps.
# Focus areas:
#  - IndicatorFactory.generate_indicators creates indicators from valid position maps
#  - IndicatorFactory assigns rules correctly to generated indicators
#  - IndicatorFactory handles empty position maps gracefully

# Test catches: IndicatorFactory failing to create indicators from valid position maps
func test_indicator_factory_creates_indicators_from_position_map() -> void:
	var gts := UnifiedTestFactory.create_minimal_targeting_state(self, true, true)
	var template := UnifiedTestFactory.create_minimal_indicator_template(self)
	var parent := Node2D.new()
	auto_free(parent)
	add_child(parent)

	# Create a simple position-rules map
	var rule := TileCheckRule.new()
	var position_rules_map: Dictionary[Vector2i, Array] = {}
	position_rules_map[Vector2i(0, 0)] = [rule]
	position_rules_map[Vector2i(1, 0)] = [rule]

	var indicators := IndicatorFactory.generate_indicators(position_rules_map, template, parent, gts)
	assert_that(indicators.size() == 2).append_failure_message("Expected 2 indicators for 2 positions in map").is_true()

	# Verify indicators have rules assigned
	for indicator in indicators:
		assert_that(indicator.get_rules().size() > 0).append_failure_message("Expected indicators to have rules assigned").is_true()

# Test catches: IndicatorFactory handling empty position maps gracefully
func test_indicator_factory_handles_empty_position_map() -> void:
	var gts := UnifiedTestFactory.create_minimal_targeting_state(self, true, true)
	var template := UnifiedTestFactory.create_minimal_indicator_template(self)
	var parent := Node2D.new()
	auto_free(parent)
	add_child(parent)

	# Create empty position-rules map
	var position_rules_map: Dictionary[Vector2i, Array] = {}

	var indicators := IndicatorFactory.generate_indicators(position_rules_map, template, parent, gts)
	assert_that(indicators.size() == 0).append_failure_message("Expected 0 indicators for empty position map").is_true()

# Test catches: IndicatorFactory creating indicators with multiple rules per position
func test_indicator_factory_handles_multiple_rules_per_position() -> void:
	var gts := UnifiedTestFactory.create_minimal_targeting_state(self, true, true)
	var template := UnifiedTestFactory.create_minimal_indicator_template(self)
	var parent := Node2D.new()
	auto_free(parent)
	add_child(parent)

	# Create position-rules map with multiple rules per position
	var rule1 := TileCheckRule.new()
	rule1.resource_name = "rule1"
	var rule2 := TileCheckRule.new()
	rule2.resource_name = "rule2"

	var position_rules_map: Dictionary[Vector2i, Array] = {}
	position_rules_map[Vector2i(0, 0)] = [rule1, rule2]

	var indicators := IndicatorFactory.generate_indicators(position_rules_map, template, parent, gts)
	assert_that(indicators.size() == 1).append_failure_message("Expected 1 indicator for 1 position in map").is_true()

	# Verify indicator has both rules assigned
	var indicator := indicators[0]
	assert_that(indicator.get_rules().size() == 2).append_failure_message("Expected indicator to have 2 rules assigned").is_true()
