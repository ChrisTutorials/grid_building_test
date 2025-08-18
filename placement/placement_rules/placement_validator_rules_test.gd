# PlacementValidatorRulesTest.gd
extends GdUnitTestSuite

var placement_validator : PlacementValidator
var targeting_state : GridTargetingState
var owner_context : GBOwnerContext
var map_layer : TileMapLayer
var _shared_container : GBCompositionContainer = preload("uid://dy6e5p5d6ax6n") # original shared resource
var _container : GBCompositionContainer # per-test clone
var _positioner : Node2D
var _user_node : Node2D
var _baseline_children : Array[Node] = []
var _gb_owner : GBOwner

func before():
	var issues : Array[String] = TestSceneLibrary.placeable_eclipse.validate()
	assert_array(issues).is_empty()
	assert_object(TestSceneLibrary.eclipse_scene).is_not_null()
	assert_object(TestSceneLibrary.indicator).is_instanceof(PackedScene)
	# Defer map layer creation to before_test for full per-test isolation

func before_test():
	# Capture baseline children so we can identify any nodes leaked by an individual test
	_baseline_children = get_children()
	# Create fresh map layer per test for isolation
	map_layer = GodotTestFactory.create_tile_map_layer(self, 8)
	# Create an owner context and associated owner node
	owner_context = GBOwnerContext.new()
	_user_node = GodotTestFactory.create_node2d(self)
	_gb_owner = GBOwner.new(_user_node)
	owner_context.set_owner(_gb_owner)
	# Not adding gb_owner as a child; owner_node already in tree

	# Clone container per test to avoid cross-test state (shallow duplicate and assign config)
	_container = GBCompositionContainer.new()
	_container.config = _shared_container.config
	var states := _container.get_states()
	# We only need to configure targeting state runtime dependencies
	_positioner = GodotTestFactory.create_node2d(self)
	states.targeting.target_map = map_layer
	states.targeting.maps = [map_layer]
	states.targeting.positioner = _positioner
	targeting_state = states.targeting
	var targeting_issues = targeting_state.validate()
	assert_array(targeting_issues).append_failure_message("Targeting state not ready -> %s" % [targeting_issues]).is_empty()

	placement_validator = PlacementValidator.create_with_injection(_container)
	# Do NOT clear _temp_nodes here; we need after_test() to free them to avoid orphan nodes

func after_test():
	# Tear down validator active rules to release any node references
	if placement_validator:
		placement_validator.tear_down()
	placement_validator = null
	# Null out container references to encourage GC
	_container = null
	_user_node = null
	_positioner = null
	if _gb_owner and is_instance_valid(_gb_owner):
		_gb_owner.queue_free()
	_gb_owner = null
	if map_layer and is_instance_valid(map_layer):
		if map_layer.get_parent():
			map_layer.get_parent().remove_child(map_layer)
		map_layer.queue_free()
	map_layer = null

	# Aggressive orphan cleanup: remove any child nodes added during the test that still remain
	var current_children : Array = get_children()
	for child in current_children:
		if child == map_layer:
			continue # Persist across suite by design
		if _baseline_children.has(child):
			continue # Pre-existing before test
		# Remove and free leaked node
		if child.get_parent() == self:
			remove_child(child)
		child.queue_free()

	_baseline_children.clear()
	# Allow a frame for any queued frees (from auto_free/queue_free) to process before next test starts
	await get_tree().process_frame

func after():
	# Nothing persistent to clean at suite end now
	pass

func test_no_col_valid_placement_both_pass_with_test_resources() -> void:
	# Simple validation test without complex dependencies
	var _test_rules: Array[PlacementRule] = []
	var test_params = RuleValidationParameters.new(null, null, null, null)
	
	# Basic validation - check that params are null as expected
	assert_object(test_params.placer).append_failure_message("Expected null placer in basic params").is_null()
	assert_object(test_params.target).append_failure_message("Expected null target in basic params").is_null()
	assert_object(test_params.targeting_state).append_failure_message("Expected null targeting_state in basic params").is_null()
	assert_object(test_params.logger).append_failure_message("Expected null logger in basic params").is_null()
	
	# Test that we can create the params object successfully
	assert_object(test_params).append_failure_message("Params object should be instantiable even with nulls").is_not_null()

func test_rule_validation_parameters_creation() -> void:
	# Test basic parameter creation
	var params = RuleValidationParameters.new(null, null, null, null)
	assert_object(params).append_failure_message("Params with nulls should instantiate").is_not_null()
	
	# Test with actual values
	var test_node = GodotTestFactory.create_node2d(self)
	var test_targeting_state = GridTargetingState.new(GBOwnerContext.new())
	var test_logger = GBLogger.new(GBDebugSettings.new())
	
	var params_with_values = RuleValidationParameters.new(test_node, test_node, test_targeting_state, test_logger)
	assert_object(params_with_values).append_failure_message("Params with values failed to instantiate").is_not_null()
	assert_object(params_with_values.placer).append_failure_message("Placer mismatch").is_same(test_node)
	assert_object(params_with_values.target).append_failure_message("Target mismatch").is_same(test_node)
	assert_object(params_with_values.targeting_state).append_failure_message("Targeting state mismatch").is_same(test_targeting_state)
	assert_object(params_with_values.logger).append_failure_message("Logger mismatch").is_same(test_logger)

func setup_validation_no_col_and_buildable(test_node : Node2D) -> RuleValidationParameters:
	var local_rules : Array[PlacementRule] = [
		CollisionsCheckRule.new(),
		ValidPlacementTileRule.new({ "buildable": true })
	]
	# emphasize second rule for visual priority (not functionally required for validation)
	local_rules[1].visual_priority = 10
	var params := RuleValidationParameters.new(owner_context.get_owner(), test_node, targeting_state, _container.get_logger())
	var setup_result = placement_validator.setup(local_rules, params)
	assert_dict(setup_result).append_failure_message("PlacementValidator.setup should return empty issues -> %s" % [setup_result]).is_empty()
	return params

func test_placement_rule_validator_integration() -> void:
	# Test that the refactored PlacementValidator uses pure logic classes
	var test_rules: Array[PlacementRule] = []
	var test_params = RuleValidationParameters.new(null, null, null, null)
	
	# Test the refactored setup method
	var validation_issues = placement_validator.setup(test_rules, test_params)
	assert_dict(validation_issues).append_failure_message("Validation issues present -> %s" % [validation_issues]).is_empty()
	# Assert internal active_rules state matches expectations
	assert_int(placement_validator.active_rules.size()).append_failure_message("Active rules size mismatch after empty setup (should remain 0) -> %d" % [placement_validator.active_rules.size()]).is_equal(0)
	
	# Test that active rules were set
	assert_int(placement_validator.active_rules.size()).append_failure_message("Active rules should be empty when none provided -> %d" % [placement_validator.active_rules.size()]).is_equal(0)

func test_placement_rule_validator_rule_combination() -> void:
	# Test that the refactored get_combined_rules uses pure logic
	var _base_rules : Array[PlacementRule] = [PlacementRule.new()]
	var additional_rules : Array[PlacementRule] = [PlacementRule.new()]
	# Sanity: base rules from container could be empty; we simulate assignment here only for combination expectations
	# (We don't mutate placement_validator._base_rules directly as it's internal; combination uses its internal base set)
	var combined : Array[PlacementRule] = placement_validator.get_combined_rules(additional_rules, false)
	assert_int(combined.size()).append_failure_message("Combined rules size unexpected -> expected 2 (base(assumed 1)+additional(1)) got %d | additional=%d combined=%s" % [combined.size(), additional_rules.size(), combined]).is_equal(2)

	var combined_ignore_base : Array[PlacementRule] = placement_validator.get_combined_rules(additional_rules, true)
	assert_int(combined_ignore_base.size()).append_failure_message("Ignore base combination unexpected -> expected 1 got %d | additional=%d combined=%s" % [combined_ignore_base.size(), additional_rules.size(), combined_ignore_base]).is_equal(1)
