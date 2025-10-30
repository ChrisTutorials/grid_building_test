extends GdUnitTestSuite

## Refactored indicator manager tests using AllSystemsTestEnvironment

var env: AllSystemsTestEnvironment


func before_test() -> void:
	# Use the all systems test environment
	env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV)

	# Set up targeting state with default target for indicator tests
	_setup_targeting_state_for_tests()


## Sets up the GridTargetingState with a default target for indicator tests
func _setup_targeting_state_for_tests() -> void:
	var targeting_state: GridTargetingState = env.get_container().get_targeting_state()

	# Create a default target for the targeting state if none exists
	if targeting_state.get_target() == null:
		var default_target: Node2D = auto_free(Node2D.new())
		default_target.position = Vector2(64, 64)
		default_target.name = "DefaultTarget"
		add_child(default_target)
		targeting_state.set_manual_target(default_target)


func test_indicator_manager_creation() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	assert_that(indicator_manager).is_not_null()
	assert_that(indicator_manager.get_parent()).is_not_null()


func test_indicator_setup_basic() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager

	# Create and setup test area
	var area: Area2D = _create_test_area()
	_setup_test_area(area)

	var rules: Array[TileCheckRule] = _create_test_rules()
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules)
	assert_that(report).is_not_null()


func test_indicator_cleanup() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	var manipulation_parent: Node2D = env.manipulation_parent

	# Create and setup test indicators first
	var area: Area2D = _create_test_area()
	_setup_test_area(area)

	var rules: Array[TileCheckRule] = _create_test_rules()
	indicator_manager.setup_indicators(area, rules)

	# Test cleanup
	indicator_manager.tear_down()

	# Count remaining indicators (should only have test objects, not indicators)
	var indicator_count: int = _count_indicators(manipulation_parent)
	var indicator_names: Array[String] = _get_indicator_names()
	(
		assert_int(indicator_count) \
		. append_failure_message(
			(
				"Indicator cleanup failed - expected 0 indicators, found %d. Remaining: %s"
				% [indicator_count, str(indicator_names)]
			)
		) \
		. is_equal(0)
	)


func test_indicator_positioning() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	var positioner: Node2D = env.positioner
	var manipulation_parent: Node2D = env.manipulation_parent

	# Position positioner at specific location
	positioner.position = Vector2(32, 32)

	# Create and setup test object
	var area: Area2D = _create_test_area()
	_setup_test_area(area)

	var rules: Array[TileCheckRule] = _create_test_rules()
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules)

	assert_that(report).is_not_null()
	# Verify indicators are positioned (basic check)
	for child: Node in manipulation_parent.get_children():
		assert_that(child.global_position).is_not_equal(Vector2.ZERO)


func test_multiple_setup_calls() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	var manipulation_parent: Node2D = env.manipulation_parent

	# Create and setup test object
	var area: Area2D = _create_test_area()
	_setup_test_area(area)

	var rules: Array[TileCheckRule] = _create_test_rules()

	# First setup
	indicator_manager.setup_indicators(area, rules)
	await get_tree().process_frame
	var first_count: int = _count_indicators(manipulation_parent)
	var first_names: Array[String] = _get_indicator_names()

	# Second setup should replace, not duplicate
	indicator_manager.setup_indicators(area, rules)
	await get_tree().process_frame
	var second_count: int = _count_indicators(manipulation_parent)
	var second_names: Array[String] = _get_indicator_names()

	(
		assert_int(first_count) \
		. append_failure_message(
			"First setup produced no indicators. Names: %s" % [str(first_names)]
		) \
		. is_greater(0)
	)
	(
		assert_int(second_count) \
		. append_failure_message(
			(
				"Second setup should replace, not duplicate - expected %d, got %d. First: %s | Second: %s"
				% [first_count, second_count, str(first_names), str(second_names)]
			)
		) \
		. is_equal(first_count)
	)


## Integration: indicator_manager should reuse reconciled indicators between setup calls
## Verifies that for identical tile positions, IndicatorService reconciliation reuses
## the same RuleCheckIndicator nodes (instance IDs unchanged) and updates their rules
## rather than clearing and recreating all indicators.
func test_indicators_are_reused_via_reconciliation_between_setups() -> void:
	# Arrange
	var indicator_manager: IndicatorManager = env.indicator_manager
	var gts: GridTargetingState = env.get_container().get_targeting_state()
	(
		assert_object(gts.target_map) \
		. append_failure_message("GridTargetingState.target_map must be set by environment") \
		. is_not_null()
	)

	var area1: Area2D = _create_test_area()
	_setup_test_area(area1)

	var rules_first: Array[TileCheckRule] = _create_test_rules()

	# First setup
	var report1: IndicatorSetupReport = indicator_manager.setup_indicators(area1, rules_first)
	assert_object(report1).append_failure_message("First setup report is null").is_not_null()
	await get_tree().process_frame

	var indicators_first: Array[RuleCheckIndicator] = indicator_manager.get_indicators()
	(
		assert_int(indicators_first.size()) \
		. append_failure_message("First setup produced no indicators") \
		. is_greater(0)
	)

	var map_first: Dictionary = _map_indicators_by_tile(indicators_first)
	var tiles_first: Array = map_first.keys()
	(
		assert_int(tiles_first.size()) \
		. append_failure_message("No tiles mapped in first setup") \
		. is_greater(0)
	)

	# Capture a sample indicator's rules to check they change on second setup
	var sample_tile: Vector2i = tiles_first[0]
	var sample_ind_first: RuleCheckIndicator = map_first[sample_tile]
	var sample_rules_first: Array = []
	for r: TileCheckRule in sample_ind_first.get_rules():
		sample_rules_first.append(r)

	# Create a second rules array with different rule instances to force rules-update path
	var rules_second: Array[TileCheckRule] = _create_test_rules()
	# Intentionally tweak one property if available to ensure identity differs and path exercised
	for r: TileCheckRule in rules_second:
		if r.has_method("set_pass_on_collision"):
			r.call(
				"set_pass_on_collision",
				(
					not r.call("get_pass_on_collision")
					if r.has_method("get_pass_on_collision")
					else true
				)
			)

	# Act: second setup with same area (same tiles), different rule instances
	var report2: IndicatorSetupReport = indicator_manager.setup_indicators(area1, rules_second)
	assert_object(report2).append_failure_message("Second setup report is null").is_not_null()
	await get_tree().process_frame

	# Assert: the indicators are reused per tile (same instance IDs)
	var indicators_second: Array[RuleCheckIndicator] = indicator_manager.get_indicators()
	(
		assert_int(indicators_second.size()) \
		. append_failure_message(
			"Second setup produced different count; expected reuse to keep count stable"
		) \
		. is_equal(indicators_first.size())
	)

	var map_second: Dictionary = _map_indicators_by_tile(indicators_second)
	var tiles_second: Array = map_second.keys()

	(
		assert_array(tiles_second) \
		. append_failure_message(
			"Tile sets differ between setups; expected identical tiles for same area"
		) \
		. contains_exactly(tiles_first)
	)

	# Per-tile identity check: verify object identity (instance ID) is unchanged
	for tile: Vector2i in tiles_first:
		var ind1: RuleCheckIndicator = map_first[tile]
		var ind2: RuleCheckIndicator = map_second[tile]
		(
			assert_int(ind2.get_instance_id()) \
			. append_failure_message(
				(
					"Indicator at tile %s was recreated. Before: %s(%d) After: %s(%d)"
					% [
						str(tile),
						ind1.name,
						ind1.get_instance_id(),
						ind2.name,
						ind2.get_instance_id()
					]
				)
			) \
			. is_equal(ind1.get_instance_id())
		)

	# Also assert that rules on the reused indicator at sample tile were updated to the new rule instances
	var sample_ind_second: RuleCheckIndicator = map_second[sample_tile]
	var sample_rules_second: Array = []
	for r2: TileCheckRule in sample_ind_second.get_rules():
		sample_rules_second.append(r2)

	# None of the original rule instances should remain attached after reconciliation
	var lingering: Array = sample_rules_second.filter(
		func(new_rule: TileCheckRule) -> bool:
			return sample_rules_first.any(
				func(old_rule: TileCheckRule) -> bool:
					return old_rule.get_instance_id() == new_rule.get_instance_id()
			)
	)
	(
		assert_int(lingering.size()) \
		. append_failure_message(
			(
				"Reused indicator still contains old rule instances; expected rules to be replaced. Old: %s New: %s"
				% [str(sample_rules_first), str(sample_rules_second)]
			)
		) \
		. is_equal(0)
	)

	# Cleanup to avoid polluting other tests
	indicator_manager.tear_down()
	await get_tree().process_frame


## Helper: build a tile->indicator map using GridTargetingState.target_map
func _map_indicators_by_tile(indicators: Array[RuleCheckIndicator]) -> Dictionary:
	var result: Dictionary = {}
	var tm: TileMapLayer = env.get_container().get_targeting_state().target_map
	for ind in indicators:
		var tile := _get_indicator_tile(ind, tm)
		result[tile] = ind
	return result


## Helper: compute the tile for a given indicator
func _get_indicator_tile(indicator: RuleCheckIndicator, tm: TileMapLayer) -> Vector2i:
	return tm.local_to_map(tm.to_local(indicator.global_position))


func _create_test_area() -> Area2D:
	var area: Area2D = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(16, 16)
	area.add_child(collision_shape)
	return area


func _create_test_rules() -> Array[TileCheckRule]:
	var rules: Array[TileCheckRule] = []
	# Base tile check to keep pipeline consistent
	rules.append(TileCheckRule.new())
	# Add a collisions rule to ensure indicators are generated for the test area
	var collisions_rule := CollisionsCheckRule.new()
	# Set up with the environment's targeting state to avoid null context
	var setup_issues: Array[String] = collisions_rule.setup(
		env.get_container().get_targeting_state()
	)
	(
		assert_array(setup_issues) \
		. append_failure_message(
			"CollisionsCheckRule.setup returned issues: %s" % [str(setup_issues)]
		) \
		. is_empty()
	)
	rules.append(collisions_rule)
	return rules


func _setup_test_area(area: Area2D) -> void:
	var manipulation_parent: Node2D = env.manipulation_parent
	manipulation_parent.add_child(area)
	auto_free(area)


func _count_indicators(parent: Node) -> int:
	var manager: IndicatorManager = env.indicator_manager
	if manager != null and is_instance_valid(manager):
		# Prefer public API: returns Array[RuleCheckIndicator]
		var indicators: Array[RuleCheckIndicator] = manager.get_indicators()
		if indicators != null:
			if indicators.size() > 0:
				# Optional debug - removed print, use assertions for debugging
				var names: Array[String] = []
				for ind: RuleCheckIndicator in indicators:
					names.append(ind.name)
			return indicators.size()

	# Fallback: name-based scan if API unavailable
	var count: int = 0
	var child_names: Array[String] = []
	for child in parent.get_children():
		if (
			typeof(child.name) == TYPE_STRING
			and String(child.name).begins_with("RuleCheckIndicator")
		):
			count += 1
			child_names.append(child.name + "(" + child.get_class() + ")")
	return count


## Returns the names of the currently managed indicators for diagnostics
func _get_indicator_names() -> Array[String]:
	var names: Array[String] = []
	var manager: IndicatorManager = env.indicator_manager
	if manager != null and is_instance_valid(manager):
		var indicators: Array[RuleCheckIndicator] = manager.get_indicators()
		if indicators != null:
			for ind: RuleCheckIndicator in indicators:
				if typeof(ind.name) == TYPE_STRING:
					names.append(String(ind.name))
			return names
		# Fallback to child scan if API not available
		for child in manager.get_children():
			if (
				typeof(child.name) == TYPE_STRING
				and String(child.name).begins_with("RuleCheckIndicator")
			):
				names.append(String(child.name))
		return names
	return names
