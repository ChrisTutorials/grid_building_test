# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

var test_params : RuleValidationParameters
var validator : PlacementValidator
var placer : Node
var targeting_state : GridTargetingState
var map_layer : TileMapLayer
var test_rules : Array[PlacementRule]
var _owner_context : GBOwnerContext
var _container : GBCompositionContainer
var preview_instance : Node2D

var empty_rules_array : Array[PlacementRule] = []

func before():
	pass

func before_test():
	_container = preload("uid://dy6e5p5d6ax6n")
	placer = auto_free(Node2D.new())
	var states = _container.get_states()
	targeting_state = states.targeting
	# Minimal map setup
	map_layer = TileMapLayer.new()
	add_child(map_layer)
	map_layer.tile_set = TileSet.new()
	map_layer.tile_set.tile_size = Vector2(16,16)
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	targeting_state.positioner = auto_free(Node2D.new())
	add_child(targeting_state.positioner)
	_owner_context = GBOwnerContext.new()
	_owner_context.set_owner(GBOwner.new(placer))
	targeting_state.origin_state = _owner_context
	validator = PlacementValidator.create_with_injection(_container)
	assert_object(validator).is_not_null()
	preview_instance = TestSceneLibrary.placeable_eclipse.packed_scene.instantiate() as Node2D
	add_child(preview_instance)
	test_rules = validator.get_combined_rules(TestSceneLibrary.placeable_eclipse.placement_rules)
	test_params = RuleValidationParameters.new(placer, preview_instance, targeting_state, _container.get_logger())
	
func after_test():
	if is_instance_valid(map_layer):
		map_layer.queue_free()
	if is_instance_valid(preview_instance):
		preview_instance.queue_free()
	
func after():
	pass
	
func test_setup():
	# Use pure logic class for validation
	var validation_issues = PlacementRuleValidator.setup_rules(test_rules, test_params)
	assert_dict(validation_issues).append_failure_message(str(validation_issues)).is_empty()

## The rules should receive the validator.debug GBDebugSettings object.
## In this test, debug is set on so the rule.debug.show should be on too
func test_setup_rules_passes_debug_object():
	validator.debug = _container.get_settings().debug
	
	# Use pure logic class for setup
	var validation_issues = PlacementRuleValidator.setup_rules(test_rules, test_params)
	assert_dict(validation_issues).is_empty()
	
	# Now test that rules have debug property set
	for rule in test_rules:
		assert_object(rule.debug).is_not_null()
		assert_bool(rule.debug.show).is_true()

@warning_ignore("unused_parameter")
func test_get_combined_rules(p_added_rules : Array[PlacementRule], p_unused : Array[PlacementRule], test_parameters := [
	[empty_rules_array, [PlacementRule.new()]],
	[TestSceneLibrary.placeable_smithy.placement_rules, [PlacementRule.new()]]
]) -> void:
	# Use pure logic class for combining rules
	var baseline = PlacementRuleValidator.combine_rules([], [], false).size()
	var added = 0
	if p_added_rules:
		added = p_added_rules.size()
	var result : Array = PlacementRuleValidator.combine_rules([], p_added_rules, false)
	assert_int(result.size()).is_equal(baseline + added)
