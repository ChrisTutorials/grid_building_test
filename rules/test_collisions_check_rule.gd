extends GdUnitTestSuite

var rule: CollisionsCheckRule


func before_test():
	rule = CollisionsCheckRule.new()


## Check that before proper setup, the ready guard emits an errors
func test_validate_condition_guard():
	assert_error(rule.validate_condition).is_not_null()
