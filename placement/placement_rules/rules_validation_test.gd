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
	user_state.set_owner(_user_node)

	var positioner = GodotTestFactory.create_node2d(self)
	add_child(positioner)

	var states = _container.get_states()
	states.building.placer_state = user_state
	states.targeting.origin_state = user_state
	states.targeting.target_map = map_layer
	states.targeting.maps = [map_layer]
	states.targeting.positioner = positioner

	targeting_state = states.targeting
	assert_array(targeting_state.validate()).is_empty()

	# Use static factory method with container instead of UnifiedTestFactory
	placement_validator = PlacementValidator.create_with_injection(_container)

func test_no_col_valid_placement_both_pass_with_test_resources():
	var test_node = auto_free(Node2D.new())
	var validation_params = setup_validation_no_col_and_buildable(test_node)

	var validation_results = placement_validator.validate()
	assert_object(validation_results).is_not_null()

	for result in validation_results.rule_results:
		assert_bool(result.is_successful).append_failure_message("Fail Rule Reason: %s" % result.reason).is_true()

	assert_bool(validation_results.is_successful).append_failure_message("One or more rules failed validation.").is_true()

func setup_validation_no_col_and_buildable(test_node : Node2D) -> RuleValidationParameters:
	var rules : Array[PlacementRule] = [
		CollisionsCheckRule.new(),
		ValidPlacementTileRule.new({ "buildable": true })
	]
	rules[1].visual_priority = 10

	placement_validator.base_rules = rules
	var setup_result = placement_validator.setup(rules, RuleValidationParameters.new(user_state.get_owner(), test_node, targeting_state))
	assert_dict(setup_result).is_empty()

	var indicator = auto_free(load("res://test/grid_building_test/scenes/indicators/test_indicator.tscn").instantiate())
	indicator.rules = rules
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	placement_manager.add_child(indicator)

	return RuleValidationParameters.new(user_state.get_owner(), test_node, targeting_state)
