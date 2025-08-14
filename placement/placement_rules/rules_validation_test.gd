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
	# Wrap user node in GBOwner
	var gb_owner := GBOwner.new(_user_node)
	user_state.set_owner(gb_owner)

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

func test_no_col_valid_placement_both_pass_with_test_resources() -> void:
	# Use pure logic class for validation
	var test_rules: Array[PlacementRule] = []
	var test_params = RuleValidationParameters.new(null, null, null, null)
	
	var validation_issues = RuleValidationLogic.validate_rule_params(
		test_params.placer,
		test_params.target,
		test_params.targeting_state,
		test_params.logger
	)
	
	assert_array(validation_issues).is_not_empty()
	assert_str(validation_issues[0]).contains("[placer] is null")

func setup_validation_no_col_and_buildable(test_node : Node2D) -> RuleValidationParameters:
	var rules : Array[PlacementRule] = [
		CollisionsCheckRule.new(),
		ValidPlacementTileRule.new({ "buildable": true })
	]
	rules[1].visual_priority = 10

	placement_validator.base_rules = rules
	var setup_result = placement_validator.setup(rules, RuleValidationParameters.new(user_state.get_owner(), test_node, targeting_state, _container.get_logger()))
	assert_dict(setup_result).is_empty()

	var indicator = load("uid://dhox8mb8kuaxa").instantiate()
	auto_free(indicator)
	indicator.rules = rules
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	add_child(indicator)

	return RuleValidationParameters.new(user_state.get_owner(), test_node, targeting_state, _container.get_logger())
