extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

func test_generate_indicators_with_valid_map() -> void:
	var position_rules_map := {
		Vector2i(1, 2): [TileCheckRule.new()],
		Vector2i(3, 4): [TileCheckRule.new(), TileCheckRule.new()]
	}
	var indicator_template := preload("uid://dhox8mb8kuaxa")
	var logger := GBLogger.create_with_injection(TEST_CONTAINER)
	var parent_node: Node2D = auto_free(Node2D.new())
	# Only add indicator if position is not null or not Vector2i.ZERO
	var setup_child_func := func(indicator, pos, parent):
		if pos != null and pos != Vector2i.ZERO:
			parent.add_child(auto_free(indicator))

	var indicators = IndicatorFactory.generate_indicators(
		position_rules_map,
		indicator_template,
		logger,
		parent_node,
		setup_child_func
	)

	assert_int(indicators.size()).is_equal(2)
	for indicator in indicators:
		assert_int(indicator.get_rules().size()).is_greater(0)
