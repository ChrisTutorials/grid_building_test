# Renamed from test_collisions_check_rule.gd
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var rule: CollisionsCheckRule
var indicator: RuleCheckIndicator
var logger: GBLogger

func before_test():
	# Use the test container to create a logger with proper dependency injection
	logger = TEST_CONTAINER.get_logger()
	rule = CollisionsCheckRule.new()
	# Remove the non-existent initialize method call - the rule will get the logger through setup()
	indicator = auto_free(RuleCheckIndicator.new())
	indicator.add_rule(rule)

func test_rule_initial_state():
	# Cannot call guard_ready() before setup() since it requires a logger
	# The rule should not be ready before setup
	assert_bool(rule._ready).is_false()

func test_rule_validate_condition_without_setup():
	var result := rule.validate_condition()
	assert_bool(result.is_successful).is_false()
