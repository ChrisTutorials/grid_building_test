extends GdUnitTestSuite

## Regression test for pre-v4.5.1 collision layer rule setup failures
## Ensures that rule setup failures are now reported and do not fail silently

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")


func test_rule_setup_failure_is_reported():
	# Create a rule that expects a layer not present in the scene
	var collisions_rule = CollisionsCheckRule.new()
	collisions_rule.apply_to_objects_mask = 1024  # Layer 11 (not present)
	collisions_rule.collision_mask = 1024  # Layer 11 (not present)
	collisions_rule.pass_on_collision = false

	# Create a PlacementManager and inject dependencies
	var placement_manager = PlacementManager.create_with_injection(TEST_CONTAINER)

	# Set up a minimal scene with no objects on layer 11
	var static_body = GodotTestFactory.create_static_body_with_rect_shape(self)
	static_body.collision_layer = 1  # Only on layer 1

	# Prepare targeting state for RuleValidationParameters
	var targeting_state = TEST_CONTAINER.get_states().targeting
	targeting_state.target_map = null
	targeting_state.positioner = null
	var params = RuleValidationParameters.new(static_body, static_body, targeting_state, UnifiedTestFactory.create_test_logger())

	var issues = collisions_rule.setup(params)
	assert_array(issues).is_not_empty()
	var found = false
	for issue in issues:
		if "No collision objects found" in issue:
			found = true
			break
	(
		assert_bool(found)
		. append_failure_message("Expected error message not found in issues: " + str(issues))
		. is_true()
	)

	# PlacementManager should also report setup failure (returns false)
	var pm_result = placement_manager.try_setup([collisions_rule], params)
	assert_bool(pm_result).is_false()
