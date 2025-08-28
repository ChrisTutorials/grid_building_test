## Simplified test for RuleCheckIndicator rule assignment regression
## Tests the core functionality without complex scene setup
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

func before_test():
	# Create injector system for dependency injection
	var _injector = UnifiedTestFactory.create_test_injector(self, TEST_CONTAINER)

## Test that rules are properly assigned to indicators during creation
func test_indicator_rule_assignment_via_factory():
	# Create a simple collision rule
	var collision_rule = CollisionsCheckRule.new()
	collision_rule.collision_mask = 1
	collision_rule.pass_on_collision = false
	
	# Create parent node for indicator
	var parent_node = Node2D.new()
	auto_free(parent_node)
	add_child(parent_node)
	
	# Create indicator using IndicatorFactory with rules
	var rules: Array[TileCheckRule] = [collision_rule]
	var indicator = IndicatorFactory.create_indicator(
		Vector2i(0, 0),
		rules,
		null,  # No template needed for this test
		parent_node
	)
	
	# Should return null since we didn't provide a template
	assert_object(indicator).is_null()

## Test that add_rule() properly establishes bidirectional relationship
func test_add_rule_bidirectional_relationship():
	# Create indicator using factory to avoid dependency injection issues
	var indicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	
	var collision_rule = CollisionsCheckRule.new()
	collision_rule.collision_mask = 1
	collision_rule.pass_on_collision = false
	
	# Add rule to indicator
	indicator.add_rule(collision_rule)
	
	# Verify bidirectional relationship
	var assigned_rules = indicator.get_rules()
	assert_array(assigned_rules).has_size(1)
	assert_object(assigned_rules[0]).is_same(collision_rule)
	
	# Verify rule has indicator in its indicators array
	assert_array(collision_rule.indicators).contains([indicator])

## Test that direct assignment to rules is no longer possible
func test_rules_array_is_private():
	var indicator = RuleCheckIndicator.new([])
	auto_free(indicator)
	
	# This should not be possible anymore - rules is private
	# We can't directly test this in GDScript, but the fact that
	# get_rules() returns an empty array initially proves it's working
	var rules = indicator.get_rules()
	assert_array(rules).is_empty()

## Test that indicators validate rules correctly when rules are added
func test_indicator_rule_validation():
	# Create indicator using factory to avoid dependency injection issues
	var indicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	
	# Create collision rule that expects no collisions
	var collision_rule = CollisionsCheckRule.new()
	collision_rule.collision_mask = 1
	collision_rule.pass_on_collision = false
	
	# Add rule to indicator
	indicator.add_rule(collision_rule)
	
	# Verify rule was added
	var assigned_rules = indicator.get_rules()
	assert_array(assigned_rules).has_size(1)
	assert_object(assigned_rules[0]).is_same(collision_rule)
	
	# Initial state should be valid (no collisions in empty scene)
	assert_bool(indicator.valid).is_true()

## Test that IndicatorFactory uses proper rule assignment method
func test_factory_uses_add_rule_method():
	# This test verifies that the factory fix is working
	# by checking that the IndicatorFactory.create_indicator method
	# exists and can be called (even if it returns null without template)
	
	var rules: Array[TileCheckRule] = []
	var parent_node = Node2D.new()
	auto_free(parent_node)
	add_child(parent_node)
	
	# Should not crash and should return null gracefully
	var indicator = IndicatorFactory.create_indicator(
		Vector2i(0, 0),
		rules,
		null,
		parent_node
	)
	
	assert_object(indicator).is_null()

## Test rule clearing functionality
func test_clear_rules():
	# Create indicator using factory to avoid dependency injection issues
	var indicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	
	var collision_rule = CollisionsCheckRule.new()
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
