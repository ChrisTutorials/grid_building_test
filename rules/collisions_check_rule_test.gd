# Renamed from test_collisions_check_rule.gd
extends GdUnitTestSuite

const UnifiedTestFactory = preload("res://test/grid_building_test/factories/unified_test_factory.gd")

var rule: CollisionsCheckRule
var indicator: RuleCheckIndicator
var logger: GBLogger
var injector: GBInjectorSystem

func before_test():
	var container = UnifiedTestFactory.create_test_composition_container(self)
	injector = UnifiedTestFactory.create_test_injector(self, container)
	logger = container.get_logger()
	
	rule = CollisionsCheckRule.new()
	# The rule gets its dependencies via the setup method, which is called
	# by the indicator when the rule is added.
	indicator = auto_free(RuleCheckIndicator.new())
	
	# Setup the indicator with the necessary dependencies from the container
	var owner_context := GBOwnerContext.new()
	var targeting_state := GridTargetingState.new(owner_context)
	indicator.setup(targeting_state, container)
	
	indicator.add_rule(rule)


func test_rule_initial_state():
	# Cannot call guard_ready() before setup() since it requires a logger
	# The rule should not be ready before setup
	assert_bool(rule._ready).is_false()

func test_rule_validate_condition_without_setup():
	var result := rule.validate_condition()
	assert_bool(result.is_successful).is_false()
