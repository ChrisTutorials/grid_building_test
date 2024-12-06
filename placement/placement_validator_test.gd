# GdUnit generated TestSuite
class_name PlacementValidatorTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/placement/placement_rules/placement_validator.gd'

var library : TestSceneLibrary
var test_params : RuleValidationParameters
var rci_manager : RuleCheckIndicatorManager
var preview_instance : Node2D
var placer : Node
var state : BuildingState
var targeting_state : GridTargetingState
var validator : PlacementValidator
var tile_map : TileMap
var building_state : BuildingState
var building_settings : BuildingSettings
var rule_check_indicator_template : PackedScene
var test_rules : Array[PlacementRule]
var user_state : UserState

var empty_rules_array : Array[PlacementRule] = []

func before():
	library = auto_free(TestSceneLibrary.instance_library())
	rule_check_indicator_template = library.indicator_min.duplicate(true)
	building_state = library.building_state.duplicate(true)
	building_settings = library.building_settings.duplicate(true)

func before_test():
	placer = auto_free(Node.new())
	targeting_state = GridTargetingState.new()
	validator = PlacementValidator.new()
	assert_object(validator).is_not_null()
	
	tile_map = TileMap.new()
	add_child(tile_map)
	tile_map.tile_set = TileSet.new()
	tile_map.tile_set.tile_size = Vector2i(16, 16)
	
	targeting_state.target_map = tile_map
	targeting_state.maps = [tile_map]
	targeting_state.positioner = auto_free(Node2D.new())
	add_child(targeting_state.positioner)
	user_state = UserState.new()
	user_state.user = placer
	targeting_state.origin_state = user_state
	
	
	rci_manager = auto_free(RuleCheckIndicatorManager.new(rule_check_indicator_template, targeting_state, validator))
	add_child(rci_manager)
	rci_manager.placement_validator = validator
	assert_object(validator.indicator_manager).append_failure_message("[indicator_manager] should  be automatically set up when positioner is set on targeting_state").is_not_null()
	
	preview_instance = library.placeable_eclipse.packed_scene.instantiate() as Node2D
	validator.indicator_manager.add_child(preview_instance)
	assert_object(preview_instance).is_not_null()
	
	test_rules = validator.get_combined_rules(library.placeable_eclipse.placement_rules)
	
	test_params = RuleValidationParameters.new(
		placer, preview_instance, targeting_state
	)
	
func after_test():
	tile_map.free()
	validator.indicator_manager.free()
	
func after():
	pass
	
func test_setup():
	var result = validator.setup(test_rules, test_params)
	assert_bool(result).is_true()

func test_setup_rules_with_debug():
	validator.show_debug = true
	validator.setup(test_rules, test_params)
	var rules : Array[PlacementRule] = []
	rules.append_array([mock(CollisionsCheckRule)])
	validator._setup_rules(test_rules, test_params)
	assert_object(validator.indicator_manager.test_setup).is_not_null()
	
	for rule in validator.base_rules:
		verify(rule, 1).setup()

func test_get_combined_rules(p_added_rules : Array[PlacementRule], p_validator : PlacementValidator, test_parameters = [
	[empty_rules_array, library.placement_validator_platformer],
	[library.placeable_smithy.placement_rules, library.placement_validator_platformer]
]) -> void:
	var expected_count = 0
	
	if p_added_rules:
		expected_count += p_added_rules.size()
	
	if p_validator:
		expected_count += p_validator.base_rules.size()
	
	var result : Array = p_validator.get_combined_rules(p_added_rules, false)
	assert_int(result.size()).is_equal(expected_count)
