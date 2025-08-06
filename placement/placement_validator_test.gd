# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

var test_params : RuleValidationParameters
var placement_manager : PlacementManager
var preview_instance : Node2D
var placer : Node
var state : BuildingState
var targeting_state : GridTargetingState
var validator : PlacementValidator
var map_layer : TileMapLayer
var building_state : BuildingState
var building_settings : BuildingSettings
var rule_check_indicator_template : PackedScene
var test_rules : Array[PlacementRule]
var _owner_context : GBOwnerContext
var _placement_context : PlacementContext
var _container : GBCompositionContainer

var empty_rules_array : Array[PlacementRule] = []

func before():
	rule_check_indicator_template = TestSceneLibrary.indicator_min.duplicate(true)
	building_settings = TestSceneLibrary.building_settings.duplicate(true)

func before_test():
	_container = GBCompositionContainer.new()
	var states := _container.get_states()
	placer = auto_free(Node.new())
	targeting_state = states.targeting
	
	map_layer = TileMapLayer.new()
	add_child(map_layer)
	map_layer.tile_set = TileSet.new()
	map_layer.tile_set.tile_size = Vector2i(16, 16)
	
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	targeting_state.positioner = auto_free(Node2D.new())
	add_child(targeting_state.positioner)
	_owner_context = GBOwnerContext.new()
	_owner_context.set_owner(placer)
	targeting_state.origin_state = _owner_context
	
	_placement_context = PlacementContext.new()
	
	preview_instance = TestSceneLibrary.placeable_eclipse.packed_scene.instantiate() as Node2D
	validator.indicator_manager.add_child(preview_instance)
	assert_object(preview_instance).is_not_null()
	
	test_rules = validator.get_combined_rules(TestSceneLibrary.placeable_eclipse.placement_rules)
	
	test_params = RuleValidationParameters.new(
		placer, preview_instance, targeting_state
	)
	
	# Use static factory method with container instead of UnifiedTestFactory
	validator = PlacementValidator.create_with_injection(_container)
	assert_object(validator).is_not_null()
	
func after_test():
	map_layer.free()
	validator.indicator_manager.free()
	
func after():
	pass
	
func test_setup():
	var result : Dictionary[PlacementRule, Array] = validator.setup(test_rules, test_params)
	assert_dict(result).append_failure_message(str(result)).is_empty()

## The rules should receive the validator.debug GBDebugSettings object.
## In this test, debug is set on so the rule.debug.show should be on too
func test_setup_rules_passes_debug_object():
	# Ensure it has a valid debug settings set to on
	validator.debug = _container.get_settings().debug
	validator.setup(test_rules, test_params)
	
	## Assert that the debug object was passed and set true
	for rule in test_rules:
		assert_object(validator.debug).is_equal(rule.debug)
		assert_bool(rule.debug.show).is_true()

@warning_ignore("unused_parameter")
func test_get_combined_rules(p_added_rules : Array[PlacementRule], p_base_rules : Array[PlacementRule], test_parameters := [
	[empty_rules_array, [PlacementRule.new()]],
	[TestSceneLibrary.placeable_smithy.placement_rules, [PlacementRule.new()]]
]) -> void:
	var expected_count = 0
	
	if p_added_rules:
		expected_count += p_added_rules.size()
	
	expected_count += validator.base_rules.size()
	
	var result : Array = validator.get_combined_rules(p_added_rules, false)
	assert_int(result.size()).is_equal(expected_count)
