extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

func test_generate_indicators_with_valid_map() -> void:
	var position_rules_map := {
		Vector2i(1, 2): [TileCheckRule.new()],
		Vector2i(3, 4): [TileCheckRule.new(), TileCheckRule.new()]
	}
	var indicator_template := preload("uid://dhox8mb8kuaxa")
	var parent_node: Node2D = auto_free(Node2D.new())

	var indicators = IndicatorFactory.generate_indicators(
		position_rules_map,
		indicator_template,
		parent_node
	)

	assert_int(indicators.size()).is_equal(2)
	for indicator in indicators:
		assert_int(indicator.get_rules().size()).is_greater(0)
