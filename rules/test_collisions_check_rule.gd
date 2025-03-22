extends GdUnitTestSuite

var rule : CollisionsCheckRule

func before_test():
	rule = CollisionsCheckRule.new()
	
func test_validate_condition():
	var rule_result := rule.validate_condition()
	assert_object(rule_result).is_instanceof(TileCheckRuleResult)
