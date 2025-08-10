# Renamed from test_collisions_check_rule.gd
extends GdUnitTestSuite

var rule: CollisionsCheckRule
var indicator: RuleCheckIndicator
var logger: GBLogger

func before_test():
	rule = CollisionsCheckRule.new()
	logger = GBLogger.new()
	rule.initialize(logger)
	indicator = auto_free(RuleCheckIndicator.new())
	indicator.add_rule(rule)

func test_rule_initial_state():
	assert_bool(rule.guard_ready()).is_false()

func test_rule_validate_condition_without_setup():
	var result := rule.validate_condition()
	assert_bool(result.is_successful).is_false()
