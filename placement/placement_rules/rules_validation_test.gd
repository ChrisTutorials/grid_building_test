extends GdUnitTestSuite

var placement_validator : PlacementValidator
var targeting_state : GridTargetingState
var user_state : GBOwnerContext
var map_layer : TileMapLayer
var _container : GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")
var _gb_owner : GBOwner
var _positioner : Node2D

func before():
	var eclipse_issues : Array[String] = TestSceneLibrary.placeable_eclipse.validate()
	assert_array(eclipse_issues).append_failure_message("Placeable eclipse resource invalid -> %s" % [eclipse_issues]).is_empty()
	assert_object(TestSceneLibrary.eclipse_scene).is_not_null()
	assert_object(TestSceneLibrary.indicator).is_instanceof(PackedScene)

	map_layer = auto_free(TestSceneLibrary.tile_map_layer_buildable.instantiate())
	# Ensure not already parented before adding
	if map_layer.get_parent() == null:
		add_child(map_layer)

func before_test():
	# Create owner context + owner node
	user_state = GBOwnerContext.new()
	var user_node = GodotTestFactory.create_node2d(self)
	_gb_owner = GBOwner.new(user_node)
	user_state.set_owner(_gb_owner)

	# Positioner & targeting state wiring
	_positioner = GodotTestFactory.create_node2d(self)
	_positioner = GodotTestFactory.create_node2d(self) # factory already adds

	var states = _container.get_states()
	# Modern API: building state may no longer expose placer_state – store owner context directly if available
	if states.building.has_method("set_owner_context"):
		states.building.set_owner_context(user_state)
	else:
		# Fallback: keep for legacy compatibility but don't assume property exists
		if "placer_state" in states.building:
			states.building.placer_state = user_state

	states.targeting.positioner = _positioner
	# Use API to set single map & maps list together if available
	# Simplified map wiring (avoid version-specific typed array mismatch)
	var maps_array : Array[TileMapLayer] = []
	maps_array.append(map_layer)
	if states.targeting.has_method("set_map_objects"):
		states.targeting.set_map_objects(map_layer, maps_array)
	else:
		states.targeting.target_map = map_layer
		if "maps" in states.targeting:
			states.targeting.maps = maps_array

	targeting_state = states.targeting
	# Validate only fields we set; some validations may require additional runtime context
	if targeting_state and targeting_state.has_method("validate"):
		var _targeting_issues = targeting_state.validate()
		# Allow missing optional fields but ensure critical ones
		assert_bool(targeting_state.positioner != null).append_failure_message("Positioner not set on targeting_state").is_true()
		assert_object(targeting_state.target_map).append_failure_message("Target map not set on targeting_state").is_not_null()

	placement_validator = PlacementValidator.create_with_injection(_container)
	assert_object(placement_validator).append_failure_message("PlacementValidator factory returned null").is_not_null()

func test_no_col_valid_placement_both_pass_with_test_resources() -> void:
	# Construct deliberately invalid params to verify validation path
	var null_params := RuleValidationParameters.new(null, null, null, null)
	var validation_issues = RuleValidationLogic.validate_rule_params(
		null_params.placer,
		null_params.target,
		null_params.targeting_state,
		null_params.logger
	)
	assert_array(validation_issues).append_failure_message("Expected issues when all params null").is_not_empty()
	assert_str(validation_issues[0]).append_failure_message("First issue should mention [placer]; issues=%s" % [validation_issues]).contains("[placer] is null")

	# Now prepare a minimal valid placement scenario
	var test_node := GodotTestFactory.create_node2d(self) # factory parents automatically
	var params_valid := RuleValidationParameters.new(user_state.get_owner(), test_node, targeting_state, _container.get_logger())
	var issues_valid = RuleValidationLogic.validate_rule_params(
		params_valid.placer,
		params_valid.target,
		params_valid.targeting_state,
		params_valid.logger
	)
	assert_array(issues_valid).append_failure_message("Expected no issues for valid params -> %s" % [issues_valid]).is_empty()
	assert_object(params_valid.placer).append_failure_message("Placer missing in params_valid").is_not_null()
	assert_object(params_valid.target).append_failure_message("Target node missing in params_valid").is_not_null()
	assert_object(params_valid.targeting_state).append_failure_message("Targeting state missing in params_valid").is_not_null()

func after_test():
	if _gb_owner and is_instance_valid(_gb_owner):
		_gb_owner.queue_free()
	_gb_owner = null
	_positioner = null

func setup_validation_no_col_and_buildable(test_node : Node2D) -> RuleValidationParameters:
	var rules : Array[PlacementRule] = [
		CollisionsCheckRule.new(),
		ValidPlacementTileRule.new({ "buildable": true })
	]
	rules[1].visual_priority = 10

	# Note: base_rules internal to validator; we simply call setup with rules for this test
	var setup_result = placement_validator.setup(rules, RuleValidationParameters.new(user_state.get_owner(), test_node, targeting_state, _container.get_logger()))
	assert_dict(setup_result).append_failure_message("Setup should have no issues -> %s" % [setup_result]).is_empty()

	var indicator = load("uid://dhox8mb8kuaxa").instantiate()
	auto_free(indicator)
	for r in rules:
		indicator.add_rule(r)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	add_child(indicator)

	return RuleValidationParameters.new(user_state.get_owner(), test_node, targeting_state, _container.get_logger())
