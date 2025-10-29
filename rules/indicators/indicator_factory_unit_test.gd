extends GdUnitTestSuite

# High-value unit tests for IndicatorFactory to catch failures in indicator generation from position maps.
# Focus areas:
#  - IndicatorFactory.generate_indicators creates indicators from valid position maps
#  - IndicatorFactory assigns rules correctly to generated indicators
#  - IndicatorFactory handles empty position maps gracefully


# Test catches: IndicatorFactory failing to create indicators from valid position maps
func test_indicator_factory_creates_indicators_from_position_map() -> void:
	# Use test environment for proper setup
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(
		GBTestConstants.EnvironmentType.ALL_SYSTEMS
	)
	var env: AllSystemsTestEnvironment = env_scene.instantiate()
	add_child(env)
	auto_free(env)

	var template := GBTestConstants.TEST_INDICATOR_TD_PLATFORMER.instantiate()
	auto_free(template)
	add_child(template)

	var parent := Node2D.new()
	auto_free(parent)
	add_child(parent)

	# Create test object for positioning
	var test_object := Node2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.global_position = Vector2(100, 100)  # Set a known position

	# Create a simple position-rules map
	var rule := TileCheckRule.new()
	var position_rules_map: Dictionary[Vector2i, Array] = {}
	position_rules_map[Vector2i(0, 0)] = [rule]
	position_rules_map[Vector2i(1, 0)] = [rule]

	var indicators := IndicatorFactory.generate_indicators(
		position_rules_map,
		GBTestConstants.TEST_INDICATOR_TD_PLATFORMER,
		parent,
		env.get_container().get_states().targeting,
		test_object
	)
	(
		assert_that(indicators.size() == 2)
		. append_failure_message("Expected 2 indicators for 2 positions in map")
		. is_true()
	)

	# Verify indicators have rules assigned
	for indicator in indicators:
		(
			assert_that(indicator.get_rules().size() > 0)
			. append_failure_message("Expected indicators to have rules assigned")
			. is_true()
		)


# Test catches: IndicatorFactory handling empty position maps gracefully
func test_indicator_factory_handles_empty_position_map() -> void:
	# Use test environment for proper setup
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(
		GBTestConstants.EnvironmentType.ALL_SYSTEMS
	)
	var env: AllSystemsTestEnvironment = env_scene.instantiate()
	add_child(env)
	auto_free(env)

	var template := GBTestConstants.TEST_INDICATOR_TD_PLATFORMER.instantiate()
	auto_free(template)
	add_child(template)

	var parent := Node2D.new()
	auto_free(parent)
	add_child(parent)

	# Create test object for positioning
	var test_object := Node2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.global_position = Vector2(50, 50)

	# Create empty position-rules map
	var position_rules_map: Dictionary[Vector2i, Array] = {}

	var indicators := IndicatorFactory.generate_indicators(
		position_rules_map,
		GBTestConstants.TEST_INDICATOR_TD_PLATFORMER,
		parent,
		env.get_container().get_states().targeting,
		test_object
	)
	(
		assert_that(indicators.size() == 0)
		. append_failure_message("Expected 0 indicators for empty position map")
		. is_true()
	)


# Test catches: IndicatorFactory creating indicators with multiple rules per position
func test_indicator_factory_handles_multiple_rules_per_position() -> void:
	# Use test environment for proper setup
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(
		GBTestConstants.EnvironmentType.ALL_SYSTEMS
	)
	var env: AllSystemsTestEnvironment = env_scene.instantiate()
	add_child(env)
	auto_free(env)

	var template := GBTestConstants.TEST_INDICATOR_TD_PLATFORMER.instantiate()
	auto_free(template)
	add_child(template)

	var parent := Node2D.new()
	auto_free(parent)
	add_child(parent)

	# Create test object for positioning
	var test_object := Node2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.global_position = Vector2(200, 200)

	# Create position-rules map with multiple rules per position
	var rule1 := TileCheckRule.new()
	rule1.resource_name = "rule1"
	var rule2 := TileCheckRule.new()
	rule2.resource_name = "rule2"

	var position_rules_map: Dictionary[Vector2i, Array] = {}
	position_rules_map[Vector2i(0, 0)] = [rule1, rule2]

	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map,
		GBTestConstants.TEST_INDICATOR_TD_PLATFORMER,
		parent,
		env.get_container().get_states().targeting,
		test_object
	)
	(
		assert_that(indicators.size() == 1)
		. append_failure_message("Expected 1 indicator for 1 position in map")
		. is_true()
	)

	# Verify indicator has both rules assigned
	var indicator := indicators[0]
	(
		assert_that(indicator.get_rules().size() == 2)
		. append_failure_message("Expected indicator to have 2 rules assigned")
		. is_true()
	)
