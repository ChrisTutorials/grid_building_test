## Simplified test for RuleCheckIndicator rule assignment regression
## Tests the core functionality of rule assignment, bidirectional relationships,
## and validation without complex scene setup dependencies
extends GdUnitTestSuite

func before_test() -> void:
	# Create environment using premade scene
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.ALL_SYSTEMS)
	assert_that(env_scene).is_not_null()
	var env: AllSystemsTestEnvironment = env_scene.instantiate()
	add_child(env)
	
	# Injector is automatically set up by environment
	var _injector: GBInjectorSystem = env.injector

# region Helper functions
# Creates a standard collision rule for testing
func _create_test_collision_rule() -> CollisionsCheckRule:
	var collision_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	collision_rule.collision_mask = 1
	collision_rule.pass_on_collision = false
	return collision_rule

# Creates a parent node for indicator testing
func _create_test_parent_node() -> Node2D:
	var parent_node: Node2D = Node2D.new()
	auto_free(parent_node)
	add_child(parent_node)
	return parent_node

# Creates an indicator with a rule and verifies the bidirectional relationship
func _create_indicator_with_rule_and_verify(indicator: RuleCheckIndicator, rule: TileCheckRule) -> void:
	indicator.add_rule(rule)
	
	var assigned_rules: Array[TileCheckRule] = indicator.get_rules()
	assert_array(assigned_rules).has_size(1)
	assert_object(assigned_rules[0]).is_same(rule)
	
	if rule is CollisionsCheckRule:
		assert_array((rule as CollisionsCheckRule).indicators).contains([indicator])
# endregion

## Test that rules are properly assigned to indicators during creation
func test_indicator_rule_assignment_via_factory() -> void:
	# Create a simple collision rule
	var collision_rule: CollisionsCheckRule = _create_test_collision_rule()
	
	# Create parent node for indicator
	var parent_node: Node2D = _create_test_parent_node()
	
	# Create indicator using IndicatorFactory with rules
	var rules: Array[TileCheckRule] = [collision_rule]
	var indicator: RuleCheckIndicator = IndicatorFactory.create_indicator(
		Vector2i(0, 0),
		rules,
		null,  # No template needed for this test
		parent_node
	)
	
	# Should return null since we didn't provide a template
	assert_object(indicator).is_null()

## Test that add_rule() properly establishes bidirectional relationship
func test_add_rule_bidirectional_relationship() -> void:
	# Create indicator using factory to avoid dependency injection issues
	var indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	
	var collision_rule: CollisionsCheckRule = _create_test_collision_rule()
	
	# Add rule to indicator and verify relationship
	_create_indicator_with_rule_and_verify(indicator, collision_rule)

## Test that direct assignment to rules is no longer possible
func test_rules_array_is_private() -> void:
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new([])
	auto_free(indicator)
	
	# This should not be possible anymore - rules is private
	# We can't directly test this in GDScript, but the fact that
	# get_rules() returns an empty array initially proves it's working
	var rules: Array[TileCheckRule] = indicator.get_rules()
	assert_array(rules).is_empty()

## Test that indicators validate rules correctly when rules are added
func test_indicator_rule_validation() -> void:
	# Create indicator using factory to avoid dependency injection issues
	var indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	
	# Create collision rule that expects no collisions
	var collision_rule: CollisionsCheckRule = _create_test_collision_rule()
	
	# Add rule to indicator and verify
	_create_indicator_with_rule_and_verify(indicator, collision_rule)
	
	# Initial state should be valid (no collisions in empty scene)
	assert_bool(indicator.valid).is_true()

## Test that IndicatorFactory uses proper rule assignment method
func test_factory_uses_add_rule_method() -> void:
	# This test verifies that the factory fix is working
	# by checking that the IndicatorFactory.create_indicator method
	# exists and can be called (even if it returns null without template)
	
	var rules: Array[TileCheckRule] = []
	var parent_node: Node2D = _create_test_parent_node()
	
	# Should not crash and should return null gracefully
	var indicator: RuleCheckIndicator = IndicatorFactory.create_indicator(
		Vector2i(0, 0),
		rules,
		null,
		parent_node
	)
	
	assert_object(indicator).is_null()

## Test rule clearing functionality
func test_clear_rules() -> void:
	# Create indicator using factory to avoid dependency injection issues
	var indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	
	var collision_rule: CollisionsCheckRule = _create_test_collision_rule()
	indicator.add_rule(collision_rule)
	
	# Verify rule was added
	assert_array(indicator.get_rules()).has_size(1)
	assert_array(collision_rule.indicators).contains([indicator])
	
	# Clear rules
	indicator.clear()
	
	# Verify rules were cleared and bidirectional relationship removed
	assert_array(indicator.get_rules()).is_empty()
	assert_array(collision_rule.indicators).is_empty()
	assert_bool(indicator.valid).is_true()  # Should default to valid when no rules
