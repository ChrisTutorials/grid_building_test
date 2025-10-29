## Unit test for IndicatorFactory positioning regression
##
## Tests that indicators are positioned correctly at tile coordinates
## instead of all being placed at (0,0).
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var container: GBCompositionContainer
var test_targeting_state: GridTargetingState
var test_indicator_template: PackedScene
var test_parent: Node2D
var test_tile_map: TileMapLayer
var test_object: Node2D


func before_test() -> void:
	container = auto_free(TEST_CONTAINER.duplicate(true))
	# Create test environment
	test_parent = Node2D.new()
	add_child(test_parent)
	auto_free(test_parent)

	# Create a minimal tile map for testing
	test_tile_map = TileMapLayer.new()
	test_tile_map.tile_set = TileSet.new()
	test_parent.add_child(test_tile_map)
	auto_free(test_tile_map)

	# Create targeting state - need GBOwnerContext
	test_targeting_state = container.get_states().targeting
	test_targeting_state.target_map = test_tile_map
	test_targeting_state.positioner = Node2D.new()
	test_targeting_state.positioner.position = Vector2(100, 100)  # Position at tile (10,10) assuming 10px tiles
	test_parent.add_child(test_targeting_state.positioner)
	auto_free(test_targeting_state.positioner)

	# Create test object for positioning
	test_object = Node2D.new()
	test_object.global_position = Vector2(80, 80)  # Position for test object
	add_child(test_object)
	auto_free(test_object)

	# Load indicator template
	test_indicator_template = load("uid://bs3xba0ifer7b")  # Isometric indicator
	if not test_indicator_template:
		test_indicator_template = load("uid://dhox8mb8kuaxa")  # Top-down indicator


func after_test() -> void:
	pass


## Test that indicators are positioned correctly at different tile offsets
func test_indicator_positioning_at_multiple_offsets() -> void:
	# Create position-rules map with multiple positions
	var position_rules_map: Dictionary[Vector2i, Array] = {}
	var test_setup: Dictionary = PlaceableTestFactory.create_polygon_test_setup(self)
	var test_rule: TileCheckRule = null
	for rule: TileCheckRule in test_setup.rules:
		if rule is TileCheckRule:
			test_rule = rule
			break
	(
		assert_that(test_rule) \
		. append_failure_message("Should find a TileCheckRule in the test setup") \
		. is_not_null()
	)

	# Add indicators at different offsets
	position_rules_map[Vector2i(0, 0)] = [test_rule]
	position_rules_map[Vector2i(1, 0)] = [test_rule]
	position_rules_map[Vector2i(0, 1)] = [test_rule]
	position_rules_map[Vector2i(2, 2)] = [test_rule]

	# Generate indicators
	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map, test_indicator_template, test_parent, test_targeting_state, test_object
	)

	# Verify we got the expected number of indicators
	assert_that(indicators.size()).is_equal(4).append_failure_message(
		"Should generate 4 indicators for 4 positions"
	)

	# Verify each indicator is positioned correctly
	var positioner_tile_pos: Vector2i = test_tile_map.local_to_map(
		test_tile_map.to_local(test_targeting_state.positioner.global_position)
	)

	for indicator: RuleCheckIndicator in indicators:
		assert_that(indicator).append_failure_message("Indicator should not be null").is_not_null()

		# Extract offset from indicator name (format: "RuleCheckIndicator-Offset(X,Y)")
		var name_parts: PackedStringArray = indicator.name.split("-Offset(")
		if name_parts.size() >= 2:
			var offset_str: String = name_parts[1].split(")")[0]
			var offset_parts: PackedStringArray = offset_str.split(",")
			if offset_parts.size() >= 2:
				var offset_x := int(offset_parts[0])
				var offset_y := int(offset_parts[1])
				var expected_offset := Vector2i(offset_x, offset_y)

				# Calculate expected world position
				var expected_tile: Vector2i = positioner_tile_pos + expected_offset
				var expected_world_pos: Vector2 = test_tile_map.to_global(
					test_tile_map.map_to_local(expected_tile)
				)

				(
					assert_that(indicator.global_position) \
					. append_failure_message(
						(
							"Indicator at offset %s should be positioned at %s but is at %s"
							% [expected_offset, expected_world_pos, indicator.global_position]
						)
					) \
					. is_equal(expected_world_pos)
				)


## Test that indicators without targeting state are positioned at (0,0)
func test_indicators_without_targeting_state_position_at_origin() -> void:
	var position_rules_map: Dictionary[Vector2i, Array] = {}
	var test_setup: Dictionary = PlaceableTestFactory.create_polygon_test_setup(self)
	var test_rule: TileCheckRule = null
	for rule: TileCheckRule in test_setup.rules:
		if rule is TileCheckRule:
			test_rule = rule
			break
	(
		assert_that(test_rule) \
		. append_failure_message("Should find a TileCheckRule in the test setup") \
		. is_not_null()
	)

	position_rules_map[Vector2i(1, 1)] = [test_rule]

	# Generate indicators without targeting state
	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map, test_indicator_template, test_parent, null, test_object  # No targeting state
	)

	assert_that(indicators.size()).is_equal(1).append_failure_message("Should generate 1 indicator")

	var indicator: RuleCheckIndicator = indicators[0]
	assert_that(indicator.global_position).is_equal(Vector2(0, 0)).append_failure_message(
		"Indicator without targeting state should be at origin (0,0)"
	)


## Test that null targeting state components don't break positioning
func test_null_targeting_state_components_handled_gracefully() -> void:
	# Create targeting state with null components
	var owner_context: GBOwnerContext = GBOwnerContext.new()
	var broken_targeting_state: GridTargetingState = GridTargetingState.new(owner_context)
	broken_targeting_state.target_map = null
	broken_targeting_state.positioner = null

	var position_rules_map: Dictionary[Vector2i, Array] = {}
	var test_setup: Dictionary = PlaceableTestFactory.create_polygon_test_setup(self)
	var test_rule: TileCheckRule = null
	for rule: TileCheckRule in test_setup.rules:
		if rule is TileCheckRule:
			test_rule = rule
			break
	(
		assert_that(test_rule) \
		. append_failure_message("Should find a TileCheckRule in the test setup") \
		. is_not_null()
	)

	position_rules_map[Vector2i(1, 1)] = [test_rule]

	# This should not crash and should position at (0,0)
	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map,
		test_indicator_template,
		test_parent,
		broken_targeting_state,
		test_object
	)

	assert_that(indicators.size()).is_equal(1).append_failure_message(
		"Should generate 1 indicator despite null components"
	)

	var indicator: RuleCheckIndicator = indicators[0]
	assert_that(indicator.global_position).is_equal(Vector2(0, 0)).append_failure_message(
		"Indicator with null targeting components should be at origin (0,0)"
	)
