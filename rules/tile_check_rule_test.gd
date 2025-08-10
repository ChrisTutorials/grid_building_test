# Renamed from test_tile_check_rule.gd
extends GdUnitTestSuite

var rule: TileCheckRule
var logger: GBLogger

func before_test():
	rule = TileCheckRule.new()
	logger = GBLogger.new()
	rule.initialize(logger)

func test_not_ready_before_setup():
	assert_bool(rule.guard_ready()).is_false()

func test_setup_sets_ready():
	var params := RuleValidationParameters.new(null, null, null)
	var issues = rule.setup(params)
	# Expect issues because params invalid
	assert_array(issues).is_not_empty()
	assert_bool(rule.guard_ready()).is_false()
