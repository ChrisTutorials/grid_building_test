# Renamed from test_tile_check_rule.gd
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var rule: TileCheckRule
var logger: GBLogger
var targeting_state : GridTargetingState
var target : Node2D
var placer : Node2D

func before_test():
	rule = TileCheckRule.new()
	logger = TEST_CONTAINER.get_logger()
	var owner_context := UnifiedTestFactory.create_owner_context(self)
	targeting_state = GridTargetingState.new(owner_context)
	target = GodotTestFactory.create_node2d(self)
	placer = GodotTestFactory.create_node2d(self)

func test_not_ready_before_setup():
	# Cannot call guard_ready() before setup() since it requires a logger
	# The rule should not be ready before setup
	assert_bool(rule._ready).is_false()
	
func test_valid_setup():
	var params := RuleValidationParameters.new(target, placer, targeting_state, logger)
	var issues = rule.setup(params)
	assert_array(issues).is_empty()
	assert_bool(rule.guard_ready()).is_true()
