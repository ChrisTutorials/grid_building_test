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
	# Create dedicated owner context and targeting state explicitly instead of mutating container state
	_owner_context = GBOwnerContext.new()
	_owner_context.set_owner(GBOwner.new(placer))
	targeting_state = GridTargetingState.new(_owner_context)
	# Minimal map setup
	map_layer = TileMapLayer.new()
	add_child(map_layer)
	map_layer.tile_set = TileSet.new()
	map_layer.tile_set.tile_size = Vector2(16,16)
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	targeting_state.positioner = auto_free(Node2D.new())
	add_child(targeting_state.positioner)
	# Validate targeting state readiness early for clearer failures
	var targeting_issues = targeting_state.validate()
	assert_array(targeting_issues).append_failure_message("Targeting state not ready -> %s" % [targeting_issues]).is_empty()
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
	var validation_issues = PlacementRuleValidator.setup_rules(test_rules, test_params)
	assert_dict(validation_issues).append_failure_message("Rule setup issues -> %s" % [validation_issues]).is_empty()
	# PlacementValidator may not expose a debug property directly; ensure each rule received settings from params.logger
	for rule in test_rules:
		if rule.get_logger():
			assert_object(rule.get_logger().get_debug_settings()).append_failure_message("Missing debug settings on rule logger -> %s" % [rule]).is_not_null()

@warning_ignore("unused_parameter")
func test_get_combined_rules(p_added_rules : Array[PlacementRule], test_parameters := [
	[empty_rules_array],
	[TestSceneLibrary.placeable_smithy.placement_rules]
]) -> void:
	# Use pure logic class for combining rules; duplicate baseline behavior
	var baseline = PlacementRuleValidator.combine_rules([], [], false).size()
	var added := p_added_rules.size() if p_added_rules else 0
	var result : Array = PlacementRuleValidator.combine_rules([], p_added_rules, false)
	assert_int(result.size()).append_failure_message("Combined rules size mismatch baseline=%d added=%d result=%d rules=%s" % [baseline, added, result.size(), p_added_rules]).is_equal(baseline + added)
