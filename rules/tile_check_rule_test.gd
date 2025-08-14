# Renamed from test_tile_check_rule.gd
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var rule: TileCheckRule
var logger: GBLogger

func before_test():
	rule = TileCheckRule.new()
	logger = TEST_CONTAINER.get_logger()
	# Remove the non-existent initialize method call - the rule will get the logger through setup()

func test_not_ready_before_setup():
	# Cannot call guard_ready() before setup() since it requires a logger
	# The rule should not be ready before setup
	assert_bool(rule._ready).is_false()

func test_setup_sets_ready():
	var params := RuleValidationParameters.new(null, null, null, logger)
	var issues = rule.setup(params)
	# Expect issues because params invalid
	assert_array(issues).is_not_empty()
	assert_bool(rule.guard_ready()).is_false()
