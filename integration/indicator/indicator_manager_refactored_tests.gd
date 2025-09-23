extends GdUnitTestSuite

## Refactored indicator manager tests using AllSystemsTestEnvironment

var env: AllSystemsTestEnvironment

func before_test() -> void:
	# Use the all systems test environment
	env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)
	
	# Set up targeting state with default target for indicator tests
	_setup_targeting_state_for_tests()

## Sets up the GridTargetingState with a default target for indicator tests
func _setup_targeting_state_for_tests() -> void:
	var targeting_state: GridTargetingState = env.get_container().get_targeting_state()
	
	# Create a default target for the targeting state if none exists
	if targeting_state.target == null:
		var default_target: Node2D = auto_free(Node2D.new())
		default_target.position = Vector2(64, 64)
		default_target.name = "DefaultTarget"
		add_child(default_target)
		targeting_state.target = default_target

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
	assert_int(indicator_count).append_failure_message(
		"Indicator cleanup failed - expected 0 indicators, found %d. Remaining: %s" % [indicator_count, str(indicator_names)]
	).is_equal(0)

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
	for child in manipulation_parent.get_children():
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
	
	assert_int(first_count).append_failure_message(
		"First setup produced no indicators. Names: %s" % [str(first_names)]
	).is_greater(0)
	assert_int(second_count).append_failure_message(
		"Second setup should replace, not duplicate - expected %d, got %d. First: %s | Second: %s" % [first_count, second_count, str(first_names), str(second_names)]
	).is_equal(first_count)

func _create_test_area() -> Area2D:
	var area: Area2D = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(16, 16)
	area.add_child(collision_shape)
	return area

func _create_test_rules() -> Array[TileCheckRule]:
	var rules : Array[TileCheckRule] = []
	# Base tile check to keep pipeline consistent
	rules.append(TileCheckRule.new())
	# Add a collisions rule to ensure indicators are generated for the test area
	var collisions_rule := CollisionsCheckRule.new()
	# Set up with the environment's targeting state to avoid null context
	var setup_issues: Array[String] = collisions_rule.setup(env.get_container().get_targeting_state())
	assert_array(setup_issues).append_failure_message("CollisionsCheckRule.setup returned issues: %s" % [str(setup_issues)]).is_empty()
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
				# Optional debug
				var names: Array[String] = []
				for ind: RuleCheckIndicator in indicators:
					names.append(ind.name)
				print("_count_indicators via API found %d indicators: %s" % [indicators.size(), str(names)])
			return indicators.size()

	# Fallback: name-based scan if API unavailable
	var count: int = 0
	var child_names: Array[String] = []
	for child in parent.get_children():
		if typeof(child.name) == TYPE_STRING and String(child.name).begins_with("RuleCheckIndicator"):
			count += 1
			child_names.append(child.name + "(" + child.get_class() + ")")
	if count > 0:
		print("_count_indicators via fallback found %d indicators: %s" % [count, str(child_names)])
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
			if typeof(child.name) == TYPE_STRING and String(child.name).begins_with("RuleCheckIndicator"):
				names.append(String(child.name))
		return names
	return names
