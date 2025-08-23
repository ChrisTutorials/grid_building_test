# Renamed from test_collisions_check_rule.gd
extends GdUnitTestSuite


var rule: CollisionsCheckRule
var indicator: RuleCheckIndicator
var logger: GBLogger
var injector: GBInjectorSystem

func before_test():
	var container = UnifiedTestFactory.create_test_composition_container(self)
	injector = UnifiedTestFactory.create_test_injector(self, container)
	logger = container.get_logger()
	
	rule = CollisionsCheckRule.new()
	# Indicator created but we intentionally do NOT call any setup method (none exists) or rule.setup
	# to validate guard behavior and ensure tests don't invoke nonexistent functions.
	indicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.extents = Vector2(8,8)
	if indicator.get_parent() == null:
		add_child(indicator)
	indicator.add_rule(rule)


func test_rule_initial_state():
	# The rule should not be ready before setup and guard should return false
	assert_bool(rule._ready).append_failure_message("Rule unexpectedly marked ready prior to setup").is_false()
	assert_bool(rule.guard_ready()).append_failure_message("guard_ready should return false without setup").is_false()

func test_rule_validate_condition_without_setup():
	var result := rule.validate_condition()
	assert_bool(result.is_successful).append_failure_message("Validation should fail when rule not setup -> result=%s" % [result]).is_false()
