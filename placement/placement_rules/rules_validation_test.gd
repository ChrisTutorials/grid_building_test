# rule_validation_test.gd
extends GdUnitTestSuite

var eclipse_placeable : Placeable
var eclipse_scene : PackedScene
var rule_check_indicator_template : PackedScene

var building_state : BuildingState
var targeting_state : GridTargetingState
var user_state : GBOwnerContext
var building_settings : BuildingSettings
var placement_validator : PlacementValidator
var object_placer : Node2D
var positioner : Node2D
var test_instance : Node2D
var map_layer : TileMapLayer
var tile_set : TileSet
var placement_manager : PlacementManager

func before():
	# Loading Setup
	assert_bool(TestSceneLibrary.placeable_eclipse.validate()).is_true()
	assert_object(TestSceneLibrary.eclipse_scene).is_not_null()
	assert_object(TestSceneLibrary.indicator).is_instanceof(PackedScene)
	building_settings = BuildingSettings.new()
	targeting_state = GridTargetingState.new()
	placement_validator = PlacementValidator.new()
	
	#region Setup Tile Map
	map_layer = auto_free(TestSceneLibrary.tile_map_layer_buildable.instantiate())
	add_child(map_layer)
	#endregion

func before_test():
	object_placer = auto_free(Node2D.new())
	add_child(object_placer)
	test_instance = auto_free(Node2D.new())
	add_child(test_instance)
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	
	user_state = GBOwnerContext.new()
	user_state.user = object_placer
	
	building_state = BuildingState.new()
	building_state.placer_state = user_state
	building_state.placer_state.user = object_placer
	
	targeting_state = GridTargetingState.new()
	targeting_state.origin_state = user_state
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	targeting_state.positioner = positioner
	assert_array(targeting_state.validate()).append_failure_message("Targeting state is not set up to be valid. Check warnings.").is_empty()
	
	placement_validator = PlacementValidator.new()
	placement_manager = auto_free(PlacementManager.new(rule_check_indicator_template, targeting_state, placement_validator))
	add_child(placement_manager)

##  I would like to report a possible bug in the grid building addon,
## unless I am missing something.. but I can't have two rules in the 
## same Placeable resource... if I put NoCollisionRule and 
## ValidPlacementTileRule together, only the first in the array is
## considered. The Indicator displays correct, it goes red, but
## when I click the item is added to the world. Looks like if the first
## rule passes the object is allowed to be placed
func test_no_col_valid_placement_both_pass_with_test_resources():
	var test_obj = auto_free(Node2D.new())
	var _test_params = setup_validation_no_col_and_buildable(test_obj)
	
	var validation_results = placement_validator.validate()
	assert_object(validation_results).append_failure_message("Placement validator %s failed validation." % placement_validator.resource_path).is_not_null()
	
	for result in validation_results.rule_results:
		assert_bool(result.is_successful).append_failure_message("Fail Rule Reason: %s" % result.reason).is_true()
	
	assert_bool(validation_results.is_successful).append_failure_message("One or more rules failed validation.").is_true()

func create_indicator(p_rules_to_evaluate : Array[TileCheckRule]) -> RuleCheckIndicator:
	var indicator : RuleCheckIndicator = auto_free(load("res://test/grid_building_test/scenes/indicators/test_indicator.tscn").instantiate())
	indicator.rules = p_rules_to_evaluate
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16,16)
	placement_manager.add_child(indicator)
	return indicator

## Sets up the placement validator and rules
## Creates 1 Test Indicator
## Creates Collision Check Rule & Valid Placement expecting "buildable" tile data
func setup_validation_no_col_and_buildable(p_test_object : Node2D) -> RuleValidationParameters:
	var test_rules : Array[PlacementRule] = [
		CollisionsCheckRule.new(),  
		ValidPlacementTileRule.new({
			"buildable": true
		})
	]
	
	# Set visual priority to control which shows first
	test_rules[1].visual_priority = 10

	placement_validator.base_rules = test_rules
	var tile_check_rules : Array[TileCheckRule] = []
	tile_check_rules.append_array(test_rules)
	assert_int(tile_check_rules.size()).append_failure_message("Expect both rules as TileCheckRules to be in array").is_equal(2)
	
	var test_params = RuleValidationParameters.new(
		object_placer,
		p_test_object,
		targeting_state
	)

	var valid_setup : Dictionary[PlacementRule, Array] = placement_validator.setup(test_rules,test_params)
	assert_dict(valid_setup).append_failure_message("Placement validator failed to setup rules properly. %s" % valid_setup).is_empty()
	
	# Create indicator AFTER test setup so that rules are ready to evaluate immediately
	var _test_indicator = create_indicator(tile_check_rules)

	return test_params
