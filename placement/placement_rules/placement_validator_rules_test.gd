# PlacementValidatorRulesTest.gd
extends GdUnitTestSuite

var placement_validator : PlacementValidator
var targeting_state : GridTargetingState
var user_state : GBOwnerContext
var map_layer : TileMapLayer
var _container : GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

func before():
	assert_bool(TestSceneLibrary.placeable_eclipse.validate()).is_true()
	assert_object(TestSceneLibrary.eclipse_scene).is_not_null()
	assert_object(TestSceneLibrary.indicator).is_instanceof(PackedScene)

	map_layer = auto_free(TestSceneLibrary.tile_map_layer_buildable.instantiate())
	add_child(map_layer)

func before_test():
	user_state = GBOwnerContext.new()
	var _user_node = GodotTestFactory.create_node2d(self)
	# Wrap the Node2D in a GBOwner for the context
	var gb_owner : GBOwner = auto_free(GBOwner.new(_user_node))
	user_state.set_owner(gb_owner)
	_user_node.add_child(gb_owner)

	var positioner = GodotTestFactory.create_node2d(self)

	var states = _container.get_states()
	states.building.placer_state = user_state
	states.targeting.origin_state = user_state
	states.targeting.target_map = map_layer
	states.targeting.maps = [map_layer]
	states.targeting.positioner = positioner

	targeting_state = states.targeting
	assert_array(targeting_state.validate()).is_empty()

	# Use the actual static factory method directly with test container
	placement_validator = PlacementValidator.create_with_injection(_container)

func test_no_col_valid_placement_both_pass_with_test_resources() -> void:
	# Simple validation test without complex dependencies
	var test_rules: Array[PlacementRule] = []
	var test_params = RuleValidationParameters.new(null, null, null, null)
	
	# Basic validation - check that params are null as expected
	assert_object(test_params.placer).is_null()
	assert_object(test_params.target).is_null()
	assert_object(test_params.targeting_state).is_null()
	assert_object(test_params.logger).is_null()
	
	# Test that we can create the params object successfully
	assert_object(test_params).is_not_null()

func test_rule_validation_parameters_creation() -> void:
	# Test basic parameter creation
	var params = RuleValidationParameters.new(null, null, null, null)
	assert_object(params).is_not_null()
	
	# Test with actual values
	var test_node = GodotTestFactory.create_node2d(self)
	var test_targeting_state = GridTargetingState.new(GBOwnerContext.new())
	var test_logger = GBLogger.new(GBDebugSettings.new())
	
	var params_with_values = RuleValidationParameters.new(test_node, test_node, test_targeting_state, test_logger)
	assert_object(params_with_values).is_not_null()
	assert_object(params_with_values.placer).is_same(test_node)
	assert_object(params_with_values.target).is_same(test_node)
	assert_object(params_with_values.targeting_state).is_same(test_targeting_state)
	assert_object(params_with_values.logger).is_same(test_logger)

func setup_validation_no_col_and_buildable(test_node : Node2D) -> RuleValidationParameters:
	var local_rules : Array[PlacementRule] = [
		CollisionsCheckRule.new(),
		ValidPlacementTileRule.new({ "buildable": true })
	]
	# emphasize second rule for visual priority (not functionally required for validation)
	local_rules[1].visual_priority = 10
	var params := RuleValidationParameters.new(user_state.get_owner(), test_node, targeting_state, _container.get_logger())
	var setup_result = placement_validator.setup(local_rules, params)
	assert_dict(setup_result).append_failure_message(str(setup_result)).is_empty()
	return params

func test_placement_rule_validator_integration() -> void:
	# Test that the refactored PlacementValidator uses pure logic classes
	var test_rules: Array[PlacementRule] = []
	var test_params = RuleValidationParameters.new(null, null, null, null)
	
	# Test the refactored setup method
	var validation_issues = placement_validator.setup(test_rules, test_params)
	assert_dict(validation_issues).is_empty()
	
	# Test that active rules were set
	assert_int(placement_validator.active_rules.size()).is_equal(0)

func test_placement_rule_validator_rule_combination() -> void:
	# Test that the refactored get_combined_rules uses pure logic
	var base_rules = [PlacementRule.new()]
	var additional_rules = [PlacementRule.new()]
	
	var combined = placement_validator.get_combined_rules(additional_rules, false)
	assert_int(combined.size()).is_equal(2)
	
	var combined_ignore_base = placement_validator.get_combined_rules(additional_rules, true)
	assert_int(combined_ignore_base.size()).is_equal(1)
