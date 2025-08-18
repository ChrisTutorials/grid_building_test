extends GdUnitTestSuite

## Regression coverage: When a collisions rule targets a layer with no applicable collision objects,
## setup should succeed (no parameter issues) and validation should PASS with the no_indicators_message.
## Previously this path produced silent or readiness errors because a mismatched targeting state was used.

const TestUnifiedFactory = preload("res://test/grid_building_test/factories/unified_test_factory.gd")
func test_rule_setup_no_indicators_pass_path():
	# Arrange
	var container := TestUnifiedFactory.create_test_composition_container(self)
	var _injector := TestUnifiedFactory.create_test_injector(self, container) # ensure dependencies/loggers configured
	var targeting_state := container.get_states().targeting

	# Provide full ready targeting state (positioner, target_map, maps)
	var positioner := GodotTestFactory.create_node2d(self)
	var tile_map := GodotTestFactory.create_tile_map_layer(self, 4)
	targeting_state.positioner = positioner
	targeting_state.set_map_objects(tile_map, [tile_map])

	# Static body (preview/target) on a different layer than rule mask (mask=1024, body layer=1)
	var static_body := GodotTestFactory.create_static_body_with_rect_shape(self)
	static_body.collision_layer = 1
	# Reparent under positioner (factory already parented to test root)
	if static_body.get_parent() != positioner:
		static_body.get_parent().remove_child(static_body)
		positioner.add_child(static_body)
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1024
	rule.collision_mask = 1024
	rule.pass_on_collision = false

	var logger := container.get_logger()
	var params := RuleValidationParameters.new(static_body, static_body, targeting_state, logger)

	# Act: direct rule setup
	var issues := rule.setup(params)
	assert_array(issues).is_empty()

	# Validate directly: zero indicators => PASS with message
	var direct_result := rule.validate_condition()
	assert_bool(direct_result.is_successful).is_true()
	assert_str(direct_result.reason).contains(rule.no_indicators_message)
	# PlacementManager path: uses same container + targeting state; should not log readiness errors now
	# Ensure container has indicator template configured before creating placement manager
	var templates := container.get_templates()
	if templates.rule_check_indicator == null:
		# Try known candidate template UIDs and pick one whose root is a RuleCheckIndicator
		var candidate_uids := ["uid://dhox8mb8kuaxa", "uid://nhlp6ks003fp"]
		for uid in candidate_uids:
			var scene := load(uid)
			if scene != null and scene is PackedScene:
				var inst = scene.instantiate()
				if inst is RuleCheckIndicator:
					templates.rule_check_indicator = scene
					inst.queue_free()
					break
				inst.queue_free()
		# As a last resort, create a minimal indicator instance wrapped in a new scene
		if templates.rule_check_indicator == null:
			var indicator := RuleCheckIndicator.new()
			var ps := PackedScene.new()
			ps.pack(indicator)
			templates.rule_check_indicator = ps
	# Create placement manager with injection now that template is present
	var placement_manager := PlacementManager.create_with_injection(container)
	add_child(placement_manager)
	auto_free(placement_manager)
	var pm_result := placement_manager.try_setup([rule], params)
	assert_bool(pm_result).is_true()
	# Validate via placement validator for completeness
	var validation_results := placement_manager.validate_placement()
	assert_bool(validation_results.is_successful).is_true()
	assert_array(validation_results.rule_results).has_size(1)
	assert_str(validation_results.rule_results[0].reason).contains(rule.no_indicators_message)

	# Ensures regression: no readiness error "_targeting_state is not ready" should have been emitted (implicit pass)
